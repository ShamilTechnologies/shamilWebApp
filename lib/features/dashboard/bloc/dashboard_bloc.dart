// lib/features/dashboard/bloc/dashboard_bloc.dart
// MODIFIED FILE

/// File: lib/features/dashboard/bloc/dashboard_bloc.dart
/// --- UPDATED: Added real-time listeners for notifications ---
library;

import 'dart:async'; // Required for Future & StreamSubscription

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import Models
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart'; // Ensure this import is present
import 'package:shamil_web_app/features/dashboard/services/reservation_sync_service.dart';
import 'package:shamil_web_app/features/access_control/service/access_control_repository.dart';
import 'package:shamil_web_app/features/auth/data/provider_repository.dart';
import 'package:shamil_web_app/features/dashboard/data/reservation_repository.dart';
import 'package:shamil_web_app/features/dashboard/data/subscription_repository.dart';

// Use part directives to link event and state files
part 'dashboard_event.dart';
part 'dashboard_state.dart';

/// Bloc that handles dashboard data loading and updates.
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final ProviderRepository _providerRepository;
  final SubscriptionRepository _subscriptionRepository;
  final ReservationRepository _reservationRepository;
  final AccessControlRepository _accessControlRepository;
  final ReservationSyncService _reservationSyncService;

  // Stream Subscriptions for real-time updates
  StreamSubscription? _reservationsSubscription;
  StreamSubscription? _subscriptionsSubscription;

  /// Creates a new DashboardBloc with provided dependencies or defaults.
  DashboardBloc({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    ProviderRepository? providerRepository,
    SubscriptionRepository? subscriptionRepository,
    ReservationRepository? reservationRepository,
    AccessControlRepository? accessControlRepository,
    ReservationSyncService? reservationSyncService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _providerRepository = providerRepository ?? ProviderRepository(),
       _subscriptionRepository =
           subscriptionRepository ?? SubscriptionRepository(),
       _reservationRepository =
           reservationRepository ?? ReservationRepository(),
       _accessControlRepository =
           accessControlRepository ?? AccessControlRepository(),
       _reservationSyncService =
           reservationSyncService ?? ReservationSyncService(),
       super(DashboardInitial()) {
    print("--- DashboardBloc INSTANCE CREATED ---");
    on<LoadDashboardData>(_onLoadDashboardData);
    on<RefreshDashboardData>(_onRefreshDashboardData);
    on<SyncMobileAppData>(_onSyncMobileAppData);
    on<_DashboardReservationReceived>(_onReservationReceived);
    on<_DashboardSubscriptionReceived>(_onSubscriptionReceived);
    on<_DashboardListenerError>(_onListenerError);

    // Initialize services if needed
    _initServices();
  }

  @override
  void onEvent(DashboardEvent event) {
    print("--- DashboardBloc EVENT: ${event.runtimeType} ---");
    super.onEvent(event);
  }

  @override
  void onTransition(Transition<DashboardEvent, DashboardState> transition) {
    print(
      "--- DashboardBloc TRANSITION: ${transition.event.runtimeType} -> ${transition.currentState.runtimeType} to ${transition.nextState.runtimeType} ---",
    );
    super.onTransition(transition);
  }

  /// Initialize any required services
  Future<void> _initServices() async {
    try {
      // Initialize the reservation sync service
      await _reservationSyncService.init();
    } catch (e) {
      print("DashboardBloc: Error initializing services: $e");
    }
  }

  /// Loads all necessary dashboard data for the provider.
  Future<void> _onLoadDashboardData(
    LoadDashboardData event,
    Emitter<DashboardState> emit,
  ) async {
    print("--- DashboardBloc: _onLoadDashboardData event handler called ---");
    await _loadDashboardData(emit);
  }

  Future<void> _onRefreshDashboardData(
    RefreshDashboardData event,
    Emitter<DashboardState> emit,
  ) async {
    print(
      "--- DashboardBloc: _onRefreshDashboardData event handler called ---",
    );
    // We can reuse the same loading logic here
    await _loadDashboardData(emit);
  }

  /// Handler for the SyncMobileAppData event
  Future<void> _onSyncMobileAppData(
    SyncMobileAppData event,
    Emitter<DashboardState> emit,
  ) async {
    print("--- DashboardBloc: _onSyncMobileAppData event handler called ---");

    if (state is DashboardLoading) {
      print("DashboardBloc: Already loading data, skipping mobile app sync");
      return;
    }

    // Emit loading state to show progress
    emit(DashboardLoading());

    try {
      final User? user = _auth.currentUser;
      final String providerId = user?.uid ?? '';

      if (user == null) {
        emit(const DashboardLoadFailure('User not authenticated.'));
        return;
      }

      // First sync reservations
      print("DashboardBloc: Syncing reservations from mobile app structure...");
      final reservations = await _reservationSyncService.syncReservations();

      // Then sync subscriptions
      print(
        "DashboardBloc: Syncing subscriptions from mobile app structure...",
      );
      final subscriptions = await _reservationSyncService.syncSubscriptions();

      print(
        "DashboardBloc: Mobile app sync completed with ${reservations.length} reservations and ${subscriptions.length} subscriptions",
      );

      // Also perform access control sync to ensure consistency
      await _accessControlRepository.refreshMobileAppData();

      // If we're in a loaded state, update the state with new data
      if (state is DashboardLoadSuccess) {
        final currentState = state as DashboardLoadSuccess;

        // Create updated state with new data
        final updatedState = DashboardLoadSuccess(
          providerInfo: currentState.providerInfo,
          reservations:
              reservations.isNotEmpty
                  ? reservations
                  : currentState.reservations,
          subscriptions:
              subscriptions.isNotEmpty
                  ? subscriptions
                  : currentState.subscriptions,
          stats: currentState.stats,
          accessLogs: currentState.accessLogs,
        );

        emit(updatedState);
        emit(
          const DashboardNotificationReceived(
            message: "Data synchronized with mobile app successfully",
          ),
        );
        emit(updatedState); // Return to success state
      } else {
        // If we're not in a loaded state already, load all data
        await _loadDashboardData(emit);
      }
    } catch (e) {
      print("DashboardBloc: Error syncing with mobile app: $e");

      // If we have existing data, don't disrupt the UI
      if (state is DashboardLoadSuccess) {
        final currentState = state as DashboardLoadSuccess;
        emit(currentState);
        emit(
          DashboardNotificationReceived(
            message: "Error syncing with mobile app: ${e.toString()}",
          ),
        );
        emit(currentState); // Return to success state
      } else {
        emit(DashboardLoadFailure(e.toString()));
      }
    }
  }

  Future<void> _loadDashboardData(Emitter<DashboardState> emit) async {
    if (state is DashboardLoading) return; // Prevent duplicate loading
    emit(DashboardLoading());

    print("--- DashboardBloc: Loading dashboard data ---");
    final User? user = _auth.currentUser;
    final String providerId = user?.uid ?? '';

    if (user == null) {
      emit(const DashboardLoadFailure('User not authenticated.'));
      return;
    }

    try {
      // Step 1: Fetch Provider Info FIRST
      final ServiceProviderModel providerInfo = await _providerRepository
          .getProvider(providerId);
      final String? governorateId = providerInfo.governorateId;

      if (governorateId == null || governorateId.isEmpty) {
        emit(
          DashboardLoadFailure(
            'Provider governorate is not configured. Please update your settings.',
          ),
        );
        return;
      }

      // Step 2: Fetch all required data in parallel
      print(
        "--- DashboardBloc: Fetching dashboard data for provider $providerId ---",
      );

      final List<dynamic> results = await Future.wait([
        _fetchReservations(providerId, governorateId),
        _fetchSubscriptions(providerId),
        _fetchStats(providerId, governorateId),
        _fetchAccessLogs(providerId),
      ]);

      final List<Reservation> reservations = results[0];
      final List<Subscription> subscriptions = results[1];
      final DashboardStats stats = results[2];
      final List<AccessLog> accessLogs = results[3];

      emit(
        DashboardLoadSuccess(
          providerInfo: providerInfo,
          reservations: reservations,
          subscriptions: subscriptions,
          stats: stats,
          accessLogs: accessLogs,
        ),
      );

      // --- Step 3: Start Real-time Listeners AFTER initial load ---
      _startListeners(providerId, governorateId);

      // Trigger mobile app integration sync
      _reservationSyncService.syncReservations();
      _reservationSyncService.syncSubscriptions();
    } catch (e, stackTrace) {
      print("!!! DashboardBloc: CATCH - Error loading dashboard data: $e");
      print(stackTrace);
      emit(DashboardLoadFailure(e.toString()));
    }
  }

  // --- Listener Event Handlers ---

  Future<void> _onReservationReceived(
    _DashboardReservationReceived event,
    Emitter<DashboardState> emit,
  ) async {
    print(
      "DashboardBloc: Received reservation update: ${event.reservation.id}",
    );

    if (state is DashboardLoadSuccess) {
      final currentState = state as DashboardLoadSuccess;

      // Find if this reservation already exists in our current list
      final existingIndex = currentState.reservations.indexWhere(
        (res) => res.id == event.reservation.id,
      );

      List<Reservation> updatedReservations = List.from(
        currentState.reservations,
      );

      if (existingIndex >= 0) {
        // Replace existing reservation
        updatedReservations[existingIndex] = event.reservation;
      } else {
        // Add new reservation
        updatedReservations.add(event.reservation);
      }

      // Sort by date
      updatedReservations.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      // Emit updated state with new reservations
      final updatedState = DashboardLoadSuccess(
        providerInfo: currentState.providerInfo,
        reservations: updatedReservations,
        subscriptions: currentState.subscriptions,
        stats: currentState.stats,
        accessLogs: currentState.accessLogs,
      );

      // Emit notification if needed
      if (existingIndex < 0) {
        emit(updatedState);
        emit(
          DashboardNotificationReceived(
            message:
                "New reservation received from ${event.reservation.userName}",
          ),
        );
        // Return to success state to maintain proper state flow
        emit(updatedState);
      } else {
        emit(updatedState);
      }
    }
  }

  Future<void> _onSubscriptionReceived(
    _DashboardSubscriptionReceived event,
    Emitter<DashboardState> emit,
  ) async {
    print(
      "DashboardBloc: Received subscription update: ${event.subscription.id}",
    );

    if (state is DashboardLoadSuccess) {
      final currentState = state as DashboardLoadSuccess;

      // Find if this subscription already exists in our current list
      final existingIndex = currentState.subscriptions.indexWhere(
        (sub) => sub.id == event.subscription.id,
      );

      List<Subscription> updatedSubscriptions = List.from(
        currentState.subscriptions,
      );

      if (existingIndex >= 0) {
        // Replace existing subscription
        updatedSubscriptions[existingIndex] = event.subscription;
      } else {
        // Add new subscription
        updatedSubscriptions.add(event.subscription);
      }

      // Sort by date
      updatedSubscriptions.sort((a, b) => b.startDate.compareTo(a.startDate));

      // Emit updated state with new subscriptions
      final updatedState = DashboardLoadSuccess(
        providerInfo: currentState.providerInfo,
        reservations: currentState.reservations,
        subscriptions: updatedSubscriptions,
        stats: currentState.stats,
        accessLogs: currentState.accessLogs,
      );

      // Emit notification if needed
      if (existingIndex < 0) {
        emit(updatedState);
        emit(
          DashboardNotificationReceived(
            message:
                "New subscription added for ${event.subscription.userName}",
          ),
        );
        // Return to success state to maintain proper state flow
        emit(updatedState);
      } else {
        emit(updatedState);
      }
    }
  }

  Future<void> _onListenerError(
    _DashboardListenerError event,
    Emitter<DashboardState> emit,
  ) async {
    print("!!! DashboardBloc: Listener Error: ${event.error}");
    if (state is DashboardLoadSuccess) {
      // Don't break the UI if we already have data, just log the error
      // Optionally consider emitting a "background error" state or similar
    } else {
      // Only emit failure if we don't already have data
      emit(DashboardLoadFailure(event.error));
    }
  }

  // --- Private Helper Methods ---

  Future<List<Reservation>> _fetchReservations(
    String providerId,
    String governorateId,
  ) async {
    try {
      print("DashboardBloc: Fetching reservations for provider $providerId");

      // First try to get reservations using the updated sync service
      final syncedReservations =
          await _reservationSyncService.syncReservations();

      // If we got reservations from the sync service, use those
      if (syncedReservations.isNotEmpty) {
        print(
          "DashboardBloc: Got ${syncedReservations.length} reservations from sync service",
        );
        return syncedReservations;
      }

      // Fallback to direct Firestore query if sync service returned no results
      print(
        "DashboardBloc: Sync service returned no reservations, falling back to direct query",
      );
      return await _reservationRepository.fetchReservations(
        providerId: providerId,
        governorateId: governorateId,
      );
    } catch (e) {
      print("DashboardBloc: Error fetching reservations: $e");
      return [];
    }
  }

  Future<List<Subscription>> _fetchSubscriptions(String providerId) async {
    print("DashboardBloc: Fetching subscriptions for $providerId");
    try {
      // First try to get subscriptions using the updated sync service
      final syncedSubscriptions =
          await _reservationSyncService.syncSubscriptions();

      // If we got subscriptions from the sync service, use those
      if (syncedSubscriptions.isNotEmpty) {
        print(
          "DashboardBloc: Got ${syncedSubscriptions.length} subscriptions from sync service",
        );
        return syncedSubscriptions;
      }

      // Fallback to direct repository query if sync service returned no results
      print(
        "DashboardBloc: Sync service returned no subscriptions, falling back to direct query",
      );
      // Use repository to fetch subscriptions
      final subscriptions = await _subscriptionRepository.fetchSubscriptions(
        providerId: providerId,
      );

      print("DashboardBloc: Fetched ${subscriptions.length} subscriptions");
      return subscriptions;
    } catch (e) {
      print("DashboardBloc: Error fetching subscriptions: $e");
      return [];
    }
  }

  Future<DashboardStats> _fetchStats(
    String providerId,
    String governorateId,
  ) async {
    print("DashboardBloc: Calculating dashboard stats for $providerId");
    try {
      // Create a placeholder stats object - in a real implementation
      // we would fetch actual data from various sources
      return DashboardStats.empty().copyWith(
        activeSubscriptions: 12,
        upcomingReservations: 8,
        totalRevenue: 1250.0,
        newMembersMonth: 5,
        checkInsToday: 23,
        totalBookingsMonth: 34,
      );
    } catch (e) {
      print("DashboardBloc: Error calculating stats: $e");
      // Return empty stats rather than throwing
      return DashboardStats.empty();
    }
  }

  Future<List<AccessLog>> _fetchAccessLogs(String providerId) async {
    print("DashboardBloc: Fetching recent access logs for $providerId");
    try {
      // Use repository to fetch access logs
      final accessLogs = await _accessControlRepository.getRecentAccessLogs(
        limit: 10, // Only need a small number for dashboard
      );

      print("DashboardBloc: Fetched ${accessLogs.length} access logs");
      return accessLogs;
    } catch (e) {
      print("DashboardBloc: Error fetching access logs: $e");
      return [];
    }
  }

  void _startListeners(String providerId, String governorateId) {
    // Clean up any existing listeners
    _reservationsSubscription?.cancel();
    _subscriptionsSubscription?.cancel();

    try {
      // Listen to the real-time stream for new reservations from sync service
      _reservationsSubscription = _reservationSyncService.onNewReservation.listen(
        (reservation) {
          print(
            "DashboardBloc: New reservation received from sync service - ${reservation.id}",
          );
          add(_DashboardReservationReceived(reservation));
        },
        onError: (error) {
          print("DashboardBloc: Error in reservation stream: $error");
          add(_DashboardListenerError(error.toString()));
        },
      );

      // Ensure the ReservationSyncService is actively listening for changes
      _reservationSyncService.startReservationListener();

      print("DashboardBloc: Started real-time listeners");
    } catch (e) {
      print("DashboardBloc: Error setting up listeners: $e");
    }
  }

  @override
  Future<void> close() {
    print("--- DashboardBloc Closing: Cancelling listeners ---");
    _reservationsSubscription?.cancel();
    _subscriptionsSubscription?.cancel();
    return super.close();
  }
} // End DashboardBloc class

// lib/features/dashboard/bloc/dashboard_bloc.dart
// Updated to work with CentralizedDataService

/// File: lib/features/dashboard/bloc/dashboard_bloc.dart
/// --- UPDATED: Integrated with CentralizedDataService for smarter sync ---
library;

import 'dart:async'; // Required for Future & StreamSubscription

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import Models
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/services/reservation_sync_service.dart';
import 'package:shamil_web_app/features/access_control/service/access_control_repository.dart';
import 'package:shamil_web_app/features/auth/data/provider_repository.dart';
import 'package:shamil_web_app/features/dashboard/data/reservation_repository.dart';
import 'package:shamil_web_app/features/dashboard/data/subscription_repository.dart';
import 'package:shamil_web_app/core/services/centralized_data_service.dart'; // Import the centralized service

// Use part directives to link event and state files
part 'dashboard_event.dart';
part 'dashboard_state.dart';

/// Bloc that handles dashboard data loading and updates with centralized data integration.
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final ProviderRepository _providerRepository;
  final SubscriptionRepository _subscriptionRepository;
  final ReservationRepository _reservationRepository;
  final AccessControlRepository _accessControlRepository;
  final ReservationSyncService _reservationSyncService;
  final CentralizedDataService _centralizedDataService;

  // Stream subscriptions to prevent memory leaks and duplicate listeners
  StreamSubscription? _reservationsSubscription;
  StreamSubscription? _subscriptionsSubscription;
  StreamSubscription? _centralizedReservationsSub;
  StreamSubscription? _centralizedSubscriptionsSub;
  StreamSubscription? _centralizedAccessLogsSub;

  // State tracking
  bool _isRefreshing = false;

  /// Creates a new DashboardBloc with provided dependencies or defaults.
  DashboardBloc({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    ProviderRepository? providerRepository,
    SubscriptionRepository? subscriptionRepository,
    ReservationRepository? reservationRepository,
    AccessControlRepository? accessControlRepository,
    ReservationSyncService? reservationSyncService,
    CentralizedDataService? centralizedDataService,
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
       _centralizedDataService =
           centralizedDataService ?? CentralizedDataService(),
       super(DashboardInitial()) {
    print("--- DashboardBloc INSTANCE CREATED ---");
    on<LoadDashboardData>(_onLoadDashboardData);
    on<RefreshDashboardData>(_onRefreshDashboardData);
    on<SyncMobileAppData>(_onSyncMobileAppData);
    on<_DashboardReservationReceived>(_onReservationReceived);
    on<_DashboardSubscriptionReceived>(_onSubscriptionReceived);
    on<_DashboardDataUpdated>(_onDashboardDataUpdated);
    on<_DashboardListenerError>(_onListenerError);
    on<UpdateReservationStatus>(_onUpdateReservationStatus);

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
      // Check if centralized service is already initialized before initializing
      if (!_centralizedDataService.isInitializedNotifier.value &&
          !_centralizedDataService.isLoadingNotifier.value) {
        print("DashboardBloc: Initializing centralized data service");
        await _centralizedDataService.init();
      } else {
        print(
          "DashboardBloc: Centralized data service already initialized or initializing",
        );
      }

      // Initialize the reservation sync service if needed
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

    // Show loading state while refreshing
    emit(DashboardLoading());

    try {
      // Use the new forceDataRefresh method for a more direct refresh
      _isRefreshing = true;
      await _centralizedDataService.forceDataRefresh();
      _isRefreshing = false;

      // Get fresh data
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        emit(const DashboardLoadFailure('User not authenticated.'));
        return;
      }

      // Re-fetch provider info first
      final providerInfo = await _providerRepository.getProvider(providerId);
      final governorateId = providerInfo.governorateId;

      if (governorateId == null || governorateId.isEmpty) {
        emit(
          DashboardLoadFailure(
            'Provider governorate is not configured. Please update your settings.',
          ),
        );
        return;
      }

      // Fetch data from centralized service - use upcoming reservations for dashboard
      final List<dynamic> results = await Future.wait([
        _centralizedDataService.getUpcomingReservationsForDashboard(
          forceRefresh: true,
        ),
        _centralizedDataService.getSubscriptions(),
        _fetchStats(providerId, governorateId),
        _centralizedDataService.getRecentAccessLogs(limit: 10),
      ]);

      final List<Reservation> reservations = results[0];
      final List<Subscription> subscriptions = results[1];
      final DashboardStats stats = results[2];
      final List<AccessLog> accessLogs = results[3];

      print(
        "DashboardBloc: Loaded ${reservations.length} reservations, ${subscriptions.length} subscriptions, ${accessLogs.length} access logs",
      );

      // Log sample reservation details for debugging
      if (reservations.isNotEmpty) {
        final sample = reservations.first;
        print(
          "DashboardBloc: Sample reservation - ID: ${sample.id}, User: ${sample.userName}, Service: ${sample.serviceName}, Status: ${sample.status}",
        );
      }

      // Convert stats to Map<String, dynamic> for state
      final Map<String, dynamic> statsMap = {
        'activeSubscriptions': stats.activeSubscriptions,
        'upcomingReservations': stats.upcomingReservations,
        'totalRevenue': stats.totalRevenue,
        'newMembersMonth': stats.newMembersMonth,
        'checkInsToday': stats.checkInsToday,
        'totalBookingsMonth': stats.totalBookingsMonth,
      };

      // Emit successful state with refreshed data
      emit(
        DashboardLoadSuccess(
          providerInfo: providerInfo,
          reservations: reservations,
          subscriptions: subscriptions,
          stats: statsMap,
          accessLogs: accessLogs,
        ),
      );

      // Make sure the streams are updated too
      _centralizedDataService.startRealTimeListeners();
    } catch (e) {
      print("DashboardBloc: Error refreshing dashboard data - $e");

      // If we have existing data, don't disrupt the UI
      if (state is DashboardLoadSuccess) {
        final currentState = state as DashboardLoadSuccess;
        emit(currentState);
        emit(
          DashboardNotificationReceived(
            message: "Error refreshing data: ${e.toString()}",
          ),
        );
        emit(currentState); // Return to success state
      } else {
        // Otherwise show failure
        emit(DashboardLoadFailure(e.toString()));
      }
    }
  }

  /// Handler for updating reservation status
  Future<void> _onUpdateReservationStatus(
    UpdateReservationStatus event,
    Emitter<DashboardState> emit,
  ) async {
    print(
      "DashboardBloc: Updating reservation status for ${event.reservationId}",
    );

    if (state is! DashboardLoadSuccess) {
      print("DashboardBloc: Not in success state, can't update");
      return;
    }

    final currentState = state as DashboardLoadSuccess;

    try {
      // Update reservation status in centralized service
      final success = await _updateReservationStatus(
        event.reservationId,
        event.userId,
        event.newStatus,
      );

      if (success) {
        // Get the updated list from centralized service for consistency - use upcoming for dashboard
        final updatedReservations = await _centralizedDataService
            .getUpcomingReservationsForDashboard(forceRefresh: true);

        // Create updated state
        final updatedState = DashboardLoadSuccess(
          providerInfo: currentState.providerInfo,
          reservations: updatedReservations,
          subscriptions: currentState.subscriptions,
          stats: currentState.stats,
          accessLogs: currentState.accessLogs,
        );

        emit(updatedState);
        emit(
          DashboardNotificationReceived(
            message:
                "Reservation ${event.reservationId} updated to ${event.newStatus}",
          ),
        );
        emit(updatedState); // Return to success state
      } else {
        emit(currentState);
        emit(
          const DashboardNotificationReceived(
            message: "Failed to update reservation status",
          ),
        );
        emit(currentState); // Return to success state
      }
    } catch (e) {
      print("DashboardBloc: Error updating reservation status - $e");
      // Maintain current state if error
      emit(currentState);
      emit(
        DashboardNotificationReceived(
          message: "Error updating status: ${e.toString()}",
        ),
      );
      emit(currentState); // Return to success state
    }
  }

  /// Helper method to update reservation status
  Future<bool> _updateReservationStatus(
    String reservationId,
    String userId,
    String newStatus,
  ) async {
    try {
      final User? user = _auth.currentUser;
      final String providerId = user?.uid ?? '';

      if (user == null) {
        throw Exception('User not authenticated');
      }

      final batch = FirebaseFirestore.instance.batch();

      // Update in main reservations collection
      final mainRef = FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId);

      batch.update(mainRef, {'status': newStatus});

      // Update in user's collection
      final userRef = FirebaseFirestore.instance
          .collection('endUsers')
          .doc(userId)
          .collection('reservations')
          .doc(reservationId);

      batch.update(userRef, {'status': newStatus});

      // Update provider reference collections based on status

      // First get current reservation to determine current status
      final reservationDoc = await mainRef.get();
      if (!reservationDoc.exists) {
        throw Exception('Reservation not found');
      }

      final currentStatus = reservationDoc.data()?['status'] as String?;

      if (currentStatus != null && currentStatus != newStatus) {
        // Remove from old status collection
        String oldCollection = '';
        switch (currentStatus) {
          case 'Pending':
            oldCollection = 'pendingReservations';
            break;
          case 'Confirmed':
            oldCollection = 'confirmedReservations';
            break;
          case 'Cancelled':
            oldCollection = 'cancelledReservations';
            break;
          case 'Completed':
          case 'Used':
            oldCollection = 'completedReservations';
            break;
        }

        if (oldCollection.isNotEmpty) {
          final oldRef = FirebaseFirestore.instance
              .collection('serviceProviders')
              .doc(providerId)
              .collection(oldCollection)
              .doc(reservationId);

          batch.delete(oldRef);
        }

        // Add to new status collection
        String newCollection = '';
        switch (newStatus) {
          case 'Pending':
            newCollection = 'pendingReservations';
            break;
          case 'Confirmed':
            newCollection = 'confirmedReservations';
            break;
          case 'Cancelled':
            newCollection = 'cancelledReservations';
            break;
          case 'Completed':
          case 'Used':
            newCollection = 'completedReservations';
            break;
        }

        if (newCollection.isNotEmpty) {
          final newRef = FirebaseFirestore.instance
              .collection('serviceProviders')
              .doc(providerId)
              .collection(newCollection)
              .doc(reservationId);

          batch.set(newRef, {
            'reservationId': reservationId,
            'userId': userId,
            'status': newStatus,
            'dateTime': reservationDoc.data()?['dateTime'],
          });
        }
      }

      // Commit batch
      await batch.commit();

      // Force refresh of centralized data
      await _centralizedDataService.refreshAllData();

      return true;
    } catch (e) {
      print("DashboardBloc: Error in _updateReservationStatus - $e");
      return false;
    }
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

      // Use centralized service for syncing mobile app data
      print(
        "DashboardBloc: Refreshing mobile app data via centralized service",
      );
      // Use refreshAllData which is available in CentralizedDataService
      await _centralizedDataService.refreshAllData();

      // Get fresh data - use upcoming reservations for dashboard
      final reservations = await _centralizedDataService
          .getUpcomingReservationsForDashboard(forceRefresh: true);
      final subscriptions = await _centralizedDataService.getSubscriptions(
        forceRefresh: true,
      );
      final accessLogs = await _centralizedDataService.getRecentAccessLogs(
        limit: 10,
        forceRefresh: true,
      );

      print(
        "DashboardBloc: Mobile app sync completed with ${reservations.length} reservations and ${subscriptions.length} subscriptions",
      );

      // If we're in a loaded state, update the state with new data
      if (state is DashboardLoadSuccess) {
        final currentState = state as DashboardLoadSuccess;

        // Create updated state with new data
        final updatedState = DashboardLoadSuccess(
          providerInfo: currentState.providerInfo,
          reservations: reservations,
          subscriptions: subscriptions,
          stats: currentState.stats, // Keep stats for now
          accessLogs: accessLogs,
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
      // Make sure centralized data service is initialized
      if (!_centralizedDataService.isInitializedNotifier.value) {
        print("DashboardBloc: Initializing centralized data service");
        await _centralizedDataService.init();
      } else {
        // If already initialized, just ensure listeners are active
        print(
          "DashboardBloc: Centralized service already initialized, ensuring listeners are active",
        );
        await _centralizedDataService.startRealTimeListeners();
      }

      // Always ensure real-time listeners are started
      await _centralizedDataService.startRealTimeListeners();

      // Fetch provider info
      final providerInfo = await _providerRepository.getProvider(providerId);
      final governorateId = providerInfo.governorateId;

      if (governorateId == null || governorateId.isEmpty) {
        emit(
          DashboardLoadFailure(
            'Provider governorate is not configured. Please update your settings.',
          ),
        );
        return;
      }

      // Fetch fresh data from centralized service - use upcoming reservations for dashboard
      final List<dynamic> results = await Future.wait([
        _centralizedDataService.getUpcomingReservationsForDashboard(
          forceRefresh: false, // Don't force refresh to prevent conflicts
        ),
        _centralizedDataService.getSubscriptions(forceRefresh: false),
        _fetchStats(providerId, governorateId),
        _centralizedDataService.getRecentAccessLogs(
          limit: 10,
          forceRefresh: false,
        ),
      ]);

      final List<Reservation> reservations = results[0];
      final List<Subscription> subscriptions = results[1];
      final DashboardStats stats = results[2];
      final List<AccessLog> accessLogs = results[3];

      // Convert stats to Map<String, dynamic> for state
      final Map<String, dynamic> statsMap = {
        'activeSubscriptions': stats.activeSubscriptions,
        'upcomingReservations': stats.upcomingReservations,
        'totalRevenue': stats.totalRevenue,
        'newMembersMonth': stats.newMembersMonth,
        'checkInsToday': stats.checkInsToday,
        'totalBookingsMonth': stats.totalBookingsMonth,
      };

      // Emit loaded state
      emit(
        DashboardLoadSuccess(
          providerInfo: providerInfo,
          reservations: reservations,
          subscriptions: subscriptions,
          stats: statsMap,
          accessLogs: accessLogs,
        ),
      );
    } catch (e, stackTrace) {
      print("DashboardBloc: Error loading dashboard data: $e");
      print("Stack trace: $stackTrace");

      // Try to load from cache if available
      try {
        final providerInfo = await _providerRepository.getProvider(providerId);

        final List<Reservation> reservations =
            _centralizedDataService.upcomingReservationsNotifier.value;
        final List<Subscription> subscriptions =
            _centralizedDataService.activeSubscriptionsNotifier.value;
        final List<AccessLog> accessLogs =
            _centralizedDataService.recentAccessLogsNotifier.value;

        // Create basic stats for fallback
        final DashboardStats stats = DashboardStats(
          activeSubscriptions: subscriptions.length,
          upcomingReservations: reservations.length,
          totalRevenue: 0,
          newMembersMonth: 0,
          checkInsToday: 0,
          totalBookingsMonth: 0,
        );

        // Convert stats to Map<String, dynamic> for state
        final Map<String, dynamic> statsMap = {
          'activeSubscriptions': stats.activeSubscriptions,
          'upcomingReservations': stats.upcomingReservations,
          'totalRevenue': stats.totalRevenue,
          'newMembersMonth': stats.newMembersMonth,
          'checkInsToday': stats.checkInsToday,
          'totalBookingsMonth': stats.totalBookingsMonth,
        };

        if (providerInfo != null &&
            (reservations.isNotEmpty || subscriptions.isNotEmpty)) {
          // We have enough data to show something
          emit(
            DashboardLoadSuccess(
              providerInfo: providerInfo,
              reservations: reservations,
              subscriptions: subscriptions,
              stats: statsMap,
              accessLogs: accessLogs,
            ),
          );

          // Also emit a notification about the error
          emit(
            DashboardNotificationReceived(
              message: "Error refreshing data: ${e.toString()}",
            ),
          );

          // Retry getting data in the background
          Future.delayed(Duration(seconds: 2), () {
            if (!_isRefreshing) {
              _centralizedDataService.forceDataRefresh();
            }
          });

          return;
        }
      } catch (fallbackError) {
        print("DashboardBloc: Fallback also failed: $fallbackError");
      }

      // If we reach here, even the fallback failed
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

  Future<void> _onDashboardDataUpdated(
    _DashboardDataUpdated event,
    Emitter<DashboardState> emit,
  ) async {
    print("DashboardBloc: Updating dashboard data from streams");

    if (state is DashboardLoadSuccess) {
      final currentState = state as DashboardLoadSuccess;

      // Create updated state with new data where provided
      final updatedState = DashboardLoadSuccess(
        providerInfo: currentState.providerInfo,
        reservations: event.reservations ?? currentState.reservations,
        subscriptions: event.subscriptions ?? currentState.subscriptions,
        stats: currentState.stats,
        accessLogs: event.accessLogs ?? currentState.accessLogs,
      );

      emit(updatedState);
    }
  }

  Future<void> _onListenerError(
    _DashboardListenerError event,
    Emitter<DashboardState> emit,
  ) async {
    print("!!! DashboardBloc: Listener Error: ${event.errorMessage}");
    if (state is DashboardLoadSuccess) {
      // Don't break the UI if we already have data, just log the error
      // Optionally consider emitting a "background error" state or similar
    } else {
      // Only emit failure if we don't already have data
      emit(DashboardLoadFailure(event.errorMessage));
    }
  }

  // --- Private Helper Methods ---

  Future<DashboardStats> _fetchStats(
    String providerId,
    String governorateId,
  ) async {
    print("DashboardBloc: Calculating dashboard stats for $providerId");
    try {
      // Get current date info for filtering
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startOfMonth = DateTime(now.year, now.month, 1);

      // Get data from centralized service for consistency
      final reservations = await _centralizedDataService.getReservations();
      final subscriptions = await _centralizedDataService.getSubscriptions();
      final accessLogs = await _centralizedDataService.getRecentAccessLogs(
        limit: 100,
      );

      // Count active subscriptions
      final activeSubscriptions = subscriptions.length;

      // Count upcoming reservations (next 7 days)
      final upcomingReservations =
          reservations.where((res) {
            final resDate = DateTime(
              res.dateTime.toDate().year,
              res.dateTime.toDate().month,
              res.dateTime.toDate().day,
            );

            return resDate.isAtSameMomentAs(today) ||
                (resDate.isAfter(today) &&
                    resDate.isBefore(today.add(const Duration(days: 7))));
          }).length;

      // Count today's check-ins
      final checkInsToday =
          accessLogs.where((log) {
            final logDate = DateTime(
              log.timestamp.toDate().year,
              log.timestamp.toDate().month,
              log.timestamp.toDate().day,
            );

            return logDate.isAtSameMomentAs(today) && log.status == 'Granted';
          }).length;

      // Count new subscriptions this month
      final newMembersMonth =
          subscriptions.where((sub) {
            final startDate = sub.startDate.toDate();
            return startDate.isAfter(startOfMonth) ||
                startDate.isAtSameMomentAs(startOfMonth);
          }).length;

      // Count total bookings this month
      final totalBookingsMonth =
          reservations.where((res) {
            final createDate = res.createdAt?.toDate() ?? DateTime(1970);
            return createDate.isAfter(startOfMonth) ||
                createDate.isAtSameMomentAs(startOfMonth);
          }).length;

      // Calculate revenue
      var totalRevenue = 0.0;

      // Sum reservation amounts for this month
      for (var res in reservations) {
        final createDate = res.createdAt?.toDate();
        if (createDate != null &&
            (createDate.isAfter(startOfMonth) ||
                createDate.isAtSameMomentAs(startOfMonth))) {
          totalRevenue += res.amount ?? 0.0;
        }
      }

      // Sum subscription amounts for this month
      for (var sub in subscriptions) {
        final startDate = sub.startDate.toDate();
        if (startDate.isAfter(startOfMonth) ||
            startDate.isAtSameMomentAs(startOfMonth)) {
          totalRevenue += sub.amount ?? 0.0;
        }
      }

      return DashboardStats(
        activeSubscriptions: activeSubscriptions,
        upcomingReservations: upcomingReservations,
        totalRevenue: totalRevenue,
        newMembersMonth: newMembersMonth,
        checkInsToday: checkInsToday,
        totalBookingsMonth: totalBookingsMonth,
      );
    } catch (e) {
      print("DashboardBloc: Error calculating stats: $e");
      // Return empty stats rather than throwing
      return DashboardStats.empty();
    }
  }

  void _startListeners(String providerId, String governorateId) {
    // Prevent setting up duplicate listeners
    if (_centralizedReservationsSub != null ||
        _centralizedSubscriptionsSub != null) {
      print("DashboardBloc: Listeners already active, skipping setup");
      return;
    }

    // Clean up any existing listeners
    _reservationsSubscription?.cancel();
    _subscriptionsSubscription?.cancel();
    _centralizedReservationsSub?.cancel();
    _centralizedSubscriptionsSub?.cancel();
    _centralizedAccessLogsSub?.cancel();

    try {
      // Start the real-time listeners in the CentralizedDataService
      _centralizedDataService.startRealTimeListeners();

      // Listen to centralized data service for consistent data
      _centralizedReservationsSub = _centralizedDataService.reservationsStream.listen(
        (reservations) {
          print(
            "DashboardBloc: Received ${reservations.length} reservations from centralized service",
          );

          // DIRECTLY UPDATE STATE instead of triggering RefreshDashboardData
          if (state is DashboardLoadSuccess) {
            final currentState = state as DashboardLoadSuccess;

            // Create updated state
            final updatedState = DashboardLoadSuccess(
              providerInfo: currentState.providerInfo,
              reservations: reservations,
              subscriptions: currentState.subscriptions,
              stats: currentState.stats,
              accessLogs: currentState.accessLogs,
            );

            // Use emit directly (but need to ensure we're in an event handler)
            // Instead, add a different event that just updates the data
            add(
              _DashboardDataUpdated(
                reservations: reservations,
                subscriptions: null,
                accessLogs: null,
              ),
            );
          }
        },
        onError: (error) {
          print(
            "DashboardBloc: Error in centralized reservations stream: $error",
          );
          add(_DashboardListenerError(error.toString()));
        },
      );

      _centralizedSubscriptionsSub = _centralizedDataService.subscriptionsStream.listen(
        (subscriptions) {
          print(
            "DashboardBloc: Received ${subscriptions.length} subscriptions from centralized service",
          );

          // DIRECTLY UPDATE STATE instead of triggering RefreshDashboardData
          if (state is DashboardLoadSuccess) {
            add(
              _DashboardDataUpdated(
                reservations: null,
                subscriptions: subscriptions,
                accessLogs: null,
              ),
            );
          }
        },
        onError: (error) {
          print(
            "DashboardBloc: Error in centralized subscriptions stream: $error",
          );
          add(_DashboardListenerError(error.toString()));
        },
      );

      _centralizedAccessLogsSub = _centralizedDataService.accessLogsStream.listen(
        (accessLogs) {
          print(
            "DashboardBloc: Received ${accessLogs.length} access logs from centralized service",
          );

          // DIRECTLY UPDATE STATE instead of triggering RefreshDashboardData
          if (state is DashboardLoadSuccess) {
            add(
              _DashboardDataUpdated(
                reservations: null,
                subscriptions: null,
                accessLogs:
                    accessLogs.take(10).toList(), // Take only 10 for dashboard
              ),
            );
          }
        },
        onError: (error) {
          print(
            "DashboardBloc: Error in centralized access logs stream: $error",
          );
          add(_DashboardListenerError(error.toString()));
        },
      );

      // Also listen to the reservation sync service for backwards compatibility
      _reservationsSubscription = _reservationSyncService.onNewReservation.listen(
        (reservation) {
          print(
            "DashboardBloc: New reservation received from sync service - ${reservation.id}",
          );
          add(_DashboardReservationReceived(reservation));
        },
        onError: (dynamic error) {
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
    _centralizedReservationsSub?.cancel();
    _centralizedSubscriptionsSub?.cancel();
    _centralizedAccessLogsSub?.cancel();
    return super.close();
  }
} // End DashboardBloc class

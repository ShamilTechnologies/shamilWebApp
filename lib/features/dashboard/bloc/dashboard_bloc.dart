/// File: lib/features/dashboard/bloc/dashboard_bloc.dart
/// --- UPDATED: Added detailed logging for debugging stuck state ---
library;

import 'dart:async'; // Required for Future

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import Models
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart'; // Ensure this import is present

// Use part directives to link event and state files
part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DashboardBloc() : super(DashboardInitial()) {
    print("--- DashboardBloc INSTANCE CREATED ---");
    on<LoadDashboardData>(_onLoadDashboardData);
    on<RefreshDashboardData>(
      _onLoadDashboardData,
    ); // Refresh re-uses load logic
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

  Future<void> _onLoadDashboardData(
    DashboardEvent event,
    Emitter<DashboardState> emit,
  ) async {
    // Avoid emitting loading if already loading, unless it's a refresh request
    if (state is DashboardLoading && event is! RefreshDashboardData) {
      print(
        "DashboardBloc: Already loading, skipping event ${event.runtimeType}.",
      );
      return;
    }

    print(
      "DashboardBloc: Emitting DashboardLoading (Event: ${event.runtimeType})",
    );
    emit(DashboardLoading()); // <-- Emits Loading

    final User? user = _auth.currentUser;
    if (user == null) {
      print("DashboardBloc: No authenticated user found.");
      emit(
        const DashboardLoadFailure(
          "User not authenticated. Please log in again.",
        ),
      ); // <-- Emits Failure
      return;
    }
    final String providerId = user.uid;
    print("DashboardBloc: User authenticated: $providerId");

    try {
      print("DashboardBloc: Fetching data for provider $providerId...");

      // --- Step 1: Fetch Provider Info FIRST to get governorateId ---
      print("DashboardBloc: START - Fetching Service Provider Info...");
      final ServiceProviderModel providerInfo = await _fetchServiceProvider(
        providerId,
      );
      print("DashboardBloc: END - Fetched Service Provider Info.");
      final String? governorateId =
          providerInfo.governorateId; // Extract governorateId

      if (governorateId == null || governorateId.isEmpty) {
        // Handle critical error: Cannot proceed without governorateId for partitioned data
        print(
          "!!! DashboardBloc: CRITICAL ERROR - Provider $providerId is missing 'governorateId'. Cannot load dashboard data requiring partitioning.",
        );
        print(
          "DashboardBloc: Emitting DashboardLoadFailure (Missing Governorate ID)...",
        );
        emit(
          const DashboardLoadFailure(
            "Provider configuration incomplete (Missing Governorate ID). Please contact support or complete registration.",
          ),
        ); // <-- Emits Failure
        print("DashboardBloc: Finished emitting DashboardLoadFailure.");
        return;
      }
      print(
        "DashboardBloc: Fetched provider info. Governorate ID: $governorateId",
      );

      // --- Step 2: Fetch other data concurrently using governorateId ---
      print(
        "DashboardBloc: START - Fetching other data concurrently (Future.wait)...",
      );
      final results = await Future.wait([
        // Fetch other data that might NOT depend on governorateId first
        _fetchRecentSubscriptions(providerId, limit: 10), // Index 0
        _fetchRecentAccessLogs(providerId, limit: 10), // Index 1
        // Now fetch data requiring governorateId
        _fetchRecentReservations(
          providerId,
          governorateId: governorateId,
          limit: 10,
        ), // Index 2
        _calculateDashboardStats(providerId, governorateId), // Index 3
      ], eagerError: true); // Stop if any essential fetch fails
      print(
        "DashboardBloc: END - Finished concurrent data fetch (Future.wait).",
      );

      // Process results
      print("DashboardBloc: START - Processing fetched results...");
      final List<Subscription> subscriptions = results[0] as List<Subscription>;
      final List<AccessLog> accessLogs = results[1] as List<AccessLog>;
      final List<Reservation> reservations = results[2] as List<Reservation>;
      final DashboardStats stats = results[3] as DashboardStats;
      print("DashboardBloc: END - Finished processing results.");

      print("DashboardBloc: Data fetched and stats calculated successfully.");
      print("DashboardBloc: Emitting DashboardLoadSuccess...");
      emit(
        // <--- Emits Success
        DashboardLoadSuccess(
          providerInfo: providerInfo, // Now contains governorateId
          stats: stats,
          reservations: reservations, // Uses updated ReservationModel
          subscriptions: subscriptions,
          accessLogs: accessLogs,
        ),
      );
      print("DashboardBloc: Finished emitting DashboardLoadSuccess.");
    } catch (e, stackTrace) {
      // <--- Catches errors from ANY awaited future above
      print("!!! DashboardBloc: CATCH - Error loading dashboard data: $e");
      print(stackTrace);
      // Emit specific error from helper if available, otherwise generic
      String errorMessage =
          e is Exception
              ? e.toString().replaceFirst("Exception: ", "")
              : "An unknown error occurred.";
      print("DashboardBloc: Emitting DashboardLoadFailure...");
      emit(
        DashboardLoadFailure("Failed to load dashboard data: $errorMessage"),
      ); // <-- Emits Failure
      print("DashboardBloc: Finished emitting DashboardLoadFailure.");
    }
  }

  // --- Helper: Fetch Service Provider Info ---
  Future<ServiceProviderModel> _fetchServiceProvider(String providerId) async {
    print("DashboardBloc Helper: START _fetchServiceProvider for $providerId");
    try {
      final docSnapshot =
          await _firestore.collection("serviceProviders").doc(providerId).get();
      if (docSnapshot.exists) {
        // *** Uses updated model's fromFirestore ***
        final model = ServiceProviderModel.fromFirestore(docSnapshot);
        print(
          "DashboardBloc Helper: END _fetchServiceProvider successful for $providerId",
        );
        return model;
      } else {
        print(
          "!!! DashboardBloc Helper: Service provider data not found for $providerId.",
        );
        throw Exception(
          "Service provider data not found.",
        ); // More user-friendly
      }
    } catch (e) {
      print(
        "!!! DashboardBloc Helper: Error in _fetchServiceProvider for $providerId: $e",
      );
      throw Exception(
        "Could not load provider information.",
      ); // Re-throw standardized error
    }
  }

  // --- Helper: Fetch Recent/Upcoming Reservations (for display list) ---
  // *** UPDATED: Accepts governorateId and uses partitioned path ***
  Future<List<Reservation>> _fetchRecentReservations(
    String providerId, {
    required String governorateId, // Now required
    int limit = 10,
  }) async {
    // No need for null check here, _onLoadDashboardData handles it
    print(
      "DashboardBloc Helper: START _fetchRecentReservations for $providerId in $governorateId",
    );
    try {
      // *** UPDATED: Query the partitioned path ***
      final querySnapshot =
          await _firestore
              .collection("reservations")
              .doc(governorateId) // Use governorateId
              .collection(providerId) // Use providerId
              .where("status", whereIn: ["Confirmed", "Pending"])
              // Fetch slightly into the past too, in case of near-time access
              .where(
                "dateTime",
                isGreaterThanOrEqualTo: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(hours: 1)),
                ),
              )
              .orderBy("dateTime", descending: false) // Order upcoming first
              .limit(limit)
              .get();

      // *** Uses updated model's fromSnapshot ***
      final reservationsList =
          querySnapshot.docs
              .map((doc) => Reservation.fromSnapshot(doc))
              .toList();
      print(
        "DashboardBloc Helper: END _fetchRecentReservations successful (${reservationsList.length} items) for $providerId",
      );
      return reservationsList;
    } catch (e) {
      print(
        "!!! DashboardBloc Helper: Error fetching Recent Reservations for $providerId: $e",
      );
      // Rethrow or return empty? Rethrowing might be better to fail fast.
      throw Exception("Could not load recent reservations.");
      // return []; /* Return empty on error */
    }
  }

  // --- Helper: Fetch Recent/Active Subscriptions (for display list) ---
  Future<List<Subscription>> _fetchRecentSubscriptions(
    String providerId, {
    int limit = 10,
  }) async {
    print(
      "DashboardBloc Helper: START _fetchRecentSubscriptions for $providerId",
    );
    try {
      final querySnapshot =
          await _firestore
              .collection("subscriptions") // Assuming top-level collection
              .where("providerId", isEqualTo: providerId)
              .where("status", isEqualTo: "Active")
              .orderBy("expiryDate", descending: false) // Use expiryDate field
              .limit(limit)
              .get();
      final subscriptionsList =
          querySnapshot.docs
              .map((doc) => Subscription.fromSnapshot(doc))
              .toList();
      print(
        "DashboardBloc Helper: END _fetchRecentSubscriptions successful (${subscriptionsList.length} items) for $providerId",
      );
      return subscriptionsList;
    } catch (e) {
      print(
        "!!! DashboardBloc Helper: Error fetching Recent Subscriptions for $providerId: $e",
      );
      throw Exception("Could not load recent subscriptions.");
      // return []; /* Return empty on error */
    }
  }

  // --- Helper: Fetch Recent Access Logs (for display list) ---
  Future<List<AccessLog>> _fetchRecentAccessLogs(
    String providerId, {
    int limit = 10,
  }) async {
    print("DashboardBloc Helper: START _fetchRecentAccessLogs for $providerId");
    try {
      final querySnapshot =
          await _firestore
              .collection("accessLogs") // Assuming top-level collection
              .where("providerId", isEqualTo: providerId)
              .orderBy("timestamp", descending: true) // Use timestamp field
              .limit(limit)
              .get();
      final logsList =
          querySnapshot.docs.map((doc) => AccessLog.fromSnapshot(doc)).toList();
      print(
        "DashboardBloc Helper: END _fetchRecentAccessLogs successful (${logsList.length} items) for $providerId",
      );
      return logsList;
    } catch (e) {
      print(
        "!!! DashboardBloc Helper: Error fetching Recent Access Logs for $providerId: $e",
      );
      throw Exception("Could not load recent activity.");
      // return []; /* Return empty on error */
    }
  }

  // --- Helper: Calculate Dashboard Stats ---
  // *** UPDATED: Accepts governorateId and uses partitioned path for reservations ***
  Future<DashboardStats> _calculateDashboardStats(
    String providerId,
    String governorateId, // Now required and assumed non-null
  ) async {
    print(
      "DashboardBloc Helper: START _calculateDashboardStats for $providerId in $governorateId",
    );
    try {
      final now = DateTime.now();
      final startOfMonth = Timestamp.fromDate(DateTime(now.year, now.month, 1));
      final endOfMonth = Timestamp.fromDate(
        DateTime(now.year, now.month + 1, 0, 23, 59, 59),
      );
      final startOfDay = Timestamp.fromDate(
        DateTime(now.year, now.month, now.day),
      );
      final endOfDay = Timestamp.fromDate(
        DateTime(now.year, now.month, now.day, 23, 59, 59),
      );

      // Perform Queries for Stats concurrently
      print("DashboardBloc Helper: START concurrent stats queries...");
      final List<dynamic> statsResults = await Future.wait([
        // Query 1: Active Subscriptions Count
        _firestore
            .collection("subscriptions")
            .where("providerId", isEqualTo: providerId)
            .where("status", isEqualTo: "Active")
            .count()
            .get(),
        // Query 2: Upcoming Reservations Count
        _firestore
            .collection("reservations")
            .doc(governorateId)
            .collection(providerId)
            .where("status", whereIn: ["Confirmed", "Pending"])
            .where("dateTime", isGreaterThanOrEqualTo: Timestamp.now())
            .count()
            .get(),
        // Query 3: Subscriptions This Month (for revenue calc)
        _firestore
            .collection("subscriptions")
            .where("providerId", isEqualTo: providerId)
            .where("startDate", isGreaterThanOrEqualTo: startOfMonth)
            .where("startDate", isLessThanOrEqualTo: endOfMonth)
            .get(),
        // Query 4: New Members This Month Count
        _firestore
            .collection("subscriptions")
            .where("providerId", isEqualTo: providerId)
            .where("startDate", isGreaterThanOrEqualTo: startOfMonth)
            .where("startDate", isLessThanOrEqualTo: endOfMonth)
            .count()
            .get(),
        // Query 5: Check-ins Today Count
        _firestore
            .collection("accessLogs")
            .where("providerId", isEqualTo: providerId)
            .where("timestamp", isGreaterThanOrEqualTo: startOfDay)
            .where("timestamp", isLessThanOrEqualTo: endOfDay)
            .where("status", isEqualTo: "Granted")
            .count()
            .get(),
        // Query 6: Total Bookings This Month Count
        _firestore
            .collection("reservations")
            .doc(governorateId)
            .collection(providerId)
            .where("status", whereIn: ["Confirmed", "Completed"])
            .where("dateTime", isGreaterThanOrEqualTo: startOfMonth)
            .where("dateTime", isLessThanOrEqualTo: endOfMonth)
            .count()
            .get(),
      ], eagerError: true); // Stop if any query fails
      print("DashboardBloc Helper: END concurrent stats queries.");

      // Process Results
      print("DashboardBloc Helper: START processing stats results...");
      final activeSubscriptionsCount =
          (statsResults[0] as AggregateQuerySnapshot?)?.count ?? 0;
      final upcomingReservationsCount =
          (statsResults[1] as AggregateQuerySnapshot?)?.count ?? 0;

      // Calculate Revenue (Client-side sum - use with caution)
      double totalRevenue = 0.0;
      final subsRevenueDocs = (statsResults[2] as QuerySnapshot?)?.docs ?? [];
      for (var doc in subsRevenueDocs) {
        totalRevenue +=
            (doc.data() as Map<String, dynamic>?)?['pricePaid'] as num? ?? 0.0;
      }
      // TODO: Add revenue from completed reservations this month (requires another query)

      final newMembers =
          (statsResults[3] as AggregateQuerySnapshot?)?.count ?? 0;
      final checkIns = (statsResults[4] as AggregateQuerySnapshot?)?.count ?? 0;
      final bookingsMonth =
          (statsResults[5] as AggregateQuerySnapshot?)?.count ?? 0;

      final calculatedStats = DashboardStats(
        activeSubscriptions: activeSubscriptionsCount,
        upcomingReservations: upcomingReservationsCount,
        totalRevenue: totalRevenue, // Note: Accuracy depends on query logic
        newMembersMonth: newMembers,
        checkInsToday: checkIns,
        totalBookingsMonth: bookingsMonth,
      );
      print(
        "DashboardBloc Helper: END processing stats results. Stats: $calculatedStats",
      );
      return calculatedStats;
    } catch (e, stackTrace) {
      print(
        "!!! DashboardBloc Helper: Error calculating Dashboard Stats for $providerId: $e",
      );
      print(stackTrace);
      // Returning empty stats allows the dashboard to load partially
      // return const DashboardStats.empty();
      // Rethrow to trigger DashboardLoadFailure in the main handler
      throw Exception("Could not calculate dashboard statistics.");
    }
  }
} // End DashboardBloc class

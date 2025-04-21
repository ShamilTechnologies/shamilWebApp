import 'dart:async'; // Required for Future

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';

// Adjust paths as necessary for your project structure

// Use part directives to link event and state files
part 'dashboard_event.dart';
part 'dashboard_state.dart';
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DashboardBloc() : super(DashboardInitial()) {
    on<LoadDashboardData>(_onLoadDashboardData);
    on<RefreshDashboardData>(
      _onLoadDashboardData,
    ); // Refresh re-uses load logic
  }

  Future<void> _onLoadDashboardData(
    DashboardEvent event,
    Emitter<DashboardState> emit,
  ) async {
    // Avoid emitting loading if already loading, unless it's a refresh request
    if (state is DashboardLoading && event is! RefreshDashboardData) return;

    print(
      "DashboardBloc: Emitting DashboardLoading (Event: ${event.runtimeType})",
    );
    emit(DashboardLoading());

    final User? user = _auth.currentUser;
    if (user == null) {
      print("DashboardBloc: No authenticated user found.");
      emit(
        const DashboardLoadFailure(
          "User not authenticated. Please log in again.",
        ),
      );
      return;
    }
    final String providerId = user.uid;

    try {
      print("DashboardBloc: Fetching data for provider $providerId...");

      // Fetch base data concurrently
      final results = await Future.wait([
        _fetchServiceProvider(providerId),
        _fetchRecentReservations(providerId, limit: 10),
        _fetchRecentSubscriptions(providerId, limit: 10),
        _fetchRecentAccessLogs(providerId, limit: 10),
        // Calculate stats separately now
      ], eagerError: true); // Stop if any essential fetch fails

      final ServiceProviderModel providerInfo =
          results[0] as ServiceProviderModel;
      final List<Reservation> reservations = results[1] as List<Reservation>;
      final List<Subscription> subscriptions = results[2] as List<Subscription>;
      final List<AccessLog> accessLogs = results[3] as List<AccessLog>;

      // Calculate Stats (now attempts real calculations)
      final DashboardStats stats = await _calculateDashboardStats(providerId);

      print("DashboardBloc: Data fetched and stats calculated successfully.");
      emit(
        DashboardLoadSuccess(
          providerInfo: providerInfo,
          stats: stats,
          reservations: reservations, // Pass limited list for display
          subscriptions: subscriptions, // Pass limited list for display
          accessLogs: accessLogs, // Pass limited list for display
        ),
      );
    } catch (e, stackTrace) {
      print("DashboardBloc: Error loading dashboard data: $e");
      print(stackTrace);
      // Emit specific error from helper if available, otherwise generic
      String errorMessage =
          e is Exception
              ? e.toString().replaceFirst("Exception: ", "")
              : "An unknown error occurred.";
      emit(
        DashboardLoadFailure("Failed to load dashboard data: $errorMessage"),
      );
    }
  }

  // --- Helper: Fetch Service Provider Info ---
  Future<ServiceProviderModel> _fetchServiceProvider(String providerId) async {
    try {
      final docSnapshot =
          await _firestore.collection("serviceProviders").doc(providerId).get();
      if (docSnapshot.exists) {
        return ServiceProviderModel.fromFirestore(docSnapshot);
      } else {
        throw Exception(
          "Service provider data not found.",
        ); // More user-friendly
      }
    } catch (e) {
      print("Error fetching ServiceProvider: $e");
      throw Exception("Could not load provider information.");
    }
  }

  // --- Helper: Fetch Recent/Upcoming Reservations (for display list) ---
  Future<List<Reservation>> _fetchRecentReservations(
    String providerId, {
    int limit = 10,
  }) async {
    try {
      final querySnapshot =
          await _firestore
              .collection("reservations")
              .where("providerId", isEqualTo: providerId)
              .where("status", whereIn: ["Confirmed", "Pending"])
              .where("dateTime", isGreaterThanOrEqualTo: Timestamp.now())
              .orderBy("dateTime", descending: false)
              .limit(limit)
              .get();
      return querySnapshot.docs
          .map((doc) => Reservation.fromSnapshot(doc))
          .toList();
    } catch (e) {
      print("Error fetching Recent Reservations: $e");
      return []; /* Return empty on error */
    }
  }

  // --- Helper: Fetch Recent/Active Subscriptions (for display list) ---
  Future<List<Subscription>> _fetchRecentSubscriptions(
    String providerId, {
    int limit = 10,
  }) async {
    try {
      final querySnapshot =
          await _firestore
              .collection("subscriptions")
              .where("providerId", isEqualTo: providerId)
              .where("status", isEqualTo: "Active")
              .orderBy("expiryDate", descending: false) // Use expiryDate field
              .limit(limit)
              .get();
      return querySnapshot.docs
          .map((doc) => Subscription.fromSnapshot(doc))
          .toList();
    } catch (e) {
      print("Error fetching Recent Subscriptions: $e");
      return []; /* Return empty on error */
    }
  }

  // --- Helper: Fetch Recent Access Logs (for display list) ---
  Future<List<AccessLog>> _fetchRecentAccessLogs(
    String providerId, {
    int limit = 10,
  }) async {
    try {
      final querySnapshot =
          await _firestore
              .collection("accessLogs")
              .where("providerId", isEqualTo: providerId)
              .orderBy("timestamp", descending: true) // Use timestamp field
              .limit(limit)
              .get();
      return querySnapshot.docs
          .map((doc) => AccessLog.fromSnapshot(doc))
          .toList();
    } catch (e) {
      print("Error fetching Recent Access Logs: $e");
      return []; /* Return empty on error */
    }
  }

  // --- Helper: Calculate Dashboard Stats ---
  Future<DashboardStats> _calculateDashboardStats(String providerId) async {
    try {
      final now = DateTime.now();
      final startOfMonth = Timestamp.fromDate(DateTime(now.year, now.month, 1));
      final endOfMonth = Timestamp.fromDate(
        DateTime(now.year, now.month + 1, 0, 23, 59, 59), // Day 0 of next month is last day of current
      );
      final startOfDay = Timestamp.fromDate(
        DateTime(now.year, now.month, now.day),
      );
      final endOfDay = Timestamp.fromDate(
        DateTime(now.year, now.month, now.day, 23, 59, 59),
      );

      // Perform Queries for Stats concurrently
      final List<dynamic> statsResults = await Future.wait([
        // 1. Active Subscriptions Count
        _firestore
            .collection("subscriptions")
            .where("providerId", isEqualTo: providerId)
            .where("status", isEqualTo: "Active")
            .count()
            .get(),
        // 2. Upcoming Reservations Count
        _firestore
            .collection("reservations")
            .where("providerId", isEqualTo: providerId)
            .where("status", whereIn: ["Confirmed", "Pending"])
            .where("dateTime", isGreaterThanOrEqualTo: Timestamp.now())
            .count()
            .get(),
        // 3. Total Revenue This Month (Example - WARNING: Inefficient)
        // Fetches documents to sum 'pricePaid' for subscriptions started this month.
        _firestore
            .collection("subscriptions")
            .where("providerId", isEqualTo: providerId)
            .where("startDate", isGreaterThanOrEqualTo: startOfMonth)
            .where("startDate", isLessThanOrEqualTo: endOfMonth)
            // Add other filters if needed (e.g., only count paid subscriptions)
            .get(),
        // 4. New Members This Month (Example: Count new subscriptions)
        _firestore
            .collection("subscriptions")
            .where("providerId", isEqualTo: providerId)
            .where("startDate", isGreaterThanOrEqualTo: startOfMonth)
            .where("startDate", isLessThanOrEqualTo: endOfMonth)
            .count()
            .get(),
        // 5. Check-ins Today (Requires 'action' field = "CheckIn")
        // Ensure Firestore index exists: providerId ASC, timestamp ASC/DESC, action ASC
         _firestore
             .collection("accessLogs")
             .where("providerId", isEqualTo: providerId)
             .where("timestamp", isGreaterThanOrEqualTo: startOfDay)
             .where("timestamp", isLessThanOrEqualTo: endOfDay)
             .where("action", isEqualTo: "CheckIn") // Ensure 'action' field exists and is indexed
             .count()
             .get(),
        // 6. Total Bookings This Month
        _firestore
            .collection("reservations")
            .where("providerId", isEqualTo: providerId)
            .where("dateTime", isGreaterThanOrEqualTo: startOfMonth)
            .where("dateTime", isLessThanOrEqualTo: endOfMonth)
            // Add status filter if needed (e.g., count only 'Confirmed')
            .count()
            .get(),
      ], eagerError: true); // Stop if any query fails

      // Process Results
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
      // TODO: Add revenue from completed reservations this month if needed

      final newMembers =
          (statsResults[3] as AggregateQuerySnapshot?)?.count ?? 0;
      final checkIns = (statsResults[4] as AggregateQuerySnapshot?)?.count ?? 0;
      final bookingsMonth =
          (statsResults[5] as AggregateQuerySnapshot?)?.count ?? 0;

      print(
        "DashboardBloc: Calculated Stats - ActiveSubs: $activeSubscriptionsCount, UpcomingRes: $upcomingReservationsCount, Revenue: $totalRevenue, NewMembers: $newMembers, CheckIns: $checkIns, BookingsMonth: $bookingsMonth",
      );

      // Use the DashboardStats model defined in dashboard_models.dart
      return DashboardStats(
        activeSubscriptions: activeSubscriptionsCount,
        upcomingReservations: upcomingReservationsCount,
        totalRevenue: totalRevenue, // Note: Accuracy depends on query logic
        newMembersMonth: newMembers,
        checkInsToday: checkIns,
        totalBookingsMonth: bookingsMonth,
      );
    } catch (e, stackTrace) {
      print("Error calculating Dashboard Stats: $e");
      print(stackTrace);
      // Returning empty stats allows the dashboard to load partially
      return const DashboardStats.empty();
      // Alternatively, rethrow to trigger DashboardLoadFailure in the main handler
      // throw Exception("Could not calculate dashboard statistics.");
    }
  }

  // --- _handleAuthError Method Removed ---

} // End DashboardBloc class

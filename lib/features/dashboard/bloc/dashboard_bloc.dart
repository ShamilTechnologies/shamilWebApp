/// File: lib/features/dashboard/bloc/dashboard_bloc.dart
/// --- UPDATED: Uses updated ServiceProviderModel, ReservationModel ---
/// --- UPDATED: Fetches governorateId and uses partitioned queries ---
library;

import 'dart:async'; // Required for Future

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// *** UPDATED: Import the updated models ***
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';

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

      // --- Step 1: Fetch Provider Info FIRST to get governorateId ---
      final ServiceProviderModel providerInfo = await _fetchServiceProvider(
        providerId,
      );
      final String? governorateId =
          providerInfo.governorateId; // Extract governorateId

      if (governorateId == null || governorateId.isEmpty) {
        // Handle critical error: Cannot proceed without governorateId for partitioned data
        print(
          "!!! DashboardBloc: CRITICAL ERROR - Provider $providerId is missing 'governorateId'. Cannot load dashboard data requiring partitioning.",
        );
        emit(
          const DashboardLoadFailure(
            "Provider configuration incomplete (Missing Governorate ID). Please contact support or complete registration.",
          ),
        );
        return;
      }
      print(
        "DashboardBloc: Fetched provider info. Governorate ID: $governorateId",
      );

      // --- Step 2: Fetch other data concurrently using governorateId ---
      final results = await Future.wait([
        // Fetch other data that might NOT depend on governorateId first
        _fetchRecentSubscriptions(providerId, limit: 10), // Assumes top-level
        _fetchRecentAccessLogs(providerId, limit: 10), // Assumes top-level
        // Now fetch data requiring governorateId
        _fetchRecentReservations(
          providerId,
          governorateId: governorateId,
          limit: 10,
        ), // Pass governorateId
        _calculateDashboardStats(
          providerId,
          governorateId,
        ), // Pass governorateId
      ], eagerError: true); // Stop if any essential fetch fails

      // Process results (indexes shifted due to fetching providerInfo separately)
      final List<Subscription> subscriptions = results[0] as List<Subscription>;
      final List<AccessLog> accessLogs = results[1] as List<AccessLog>;
      final List<Reservation> reservations = results[2] as List<Reservation>;
      final DashboardStats stats = results[3] as DashboardStats;

      print("DashboardBloc: Data fetched and stats calculated successfully.");
      emit(
        DashboardLoadSuccess(
          providerInfo: providerInfo, // Now contains governorateId
          stats: stats,
          reservations: reservations, // Uses updated ReservationModel
          subscriptions: subscriptions,
          accessLogs: accessLogs,
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

  // --- Helper: Fetch Service Provider Info --- (No changes needed here)
  Future<ServiceProviderModel> _fetchServiceProvider(String providerId) async {
    try {
      final docSnapshot =
          await _firestore.collection("serviceProviders").doc(providerId).get();
      if (docSnapshot.exists) {
        // *** Uses updated model's fromFirestore ***
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
  // *** UPDATED: Accepts governorateId and uses partitioned path ***
  Future<List<Reservation>> _fetchRecentReservations(
    String providerId, {
    required String governorateId, // Now required
    int limit = 10,
  }) async {
    // No need for null check here, _onLoadDashboardData handles it
    print(
      "DashboardBloc [_fetchRecentReservations]: Fetching from /reservations/$governorateId/$providerId",
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
      return querySnapshot.docs
          .map((doc) => Reservation.fromSnapshot(doc))
          .toList();
    } catch (e) {
      print("Error fetching Recent Reservations: $e");
      // Rethrow or return empty? Rethrowing might be better to fail fast.
      throw Exception("Could not load recent reservations.");
      // return []; /* Return empty on error */
    }
  }

  // --- Helper: Fetch Recent/Active Subscriptions (for display list) --- (No changes)
  Future<List<Subscription>> _fetchRecentSubscriptions(
    String providerId, {
    int limit = 10,
  }) async {
    try {
      final querySnapshot =
          await _firestore
              .collection("subscriptions") // Assuming top-level collection
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
      throw Exception("Could not load recent subscriptions.");
      // return []; /* Return empty on error */
    }
  }

  // --- Helper: Fetch Recent Access Logs (for display list) --- (No changes)
  Future<List<AccessLog>> _fetchRecentAccessLogs(
    String providerId, {
    int limit = 10,
  }) async {
    try {
      final querySnapshot =
          await _firestore
              .collection("accessLogs") // Assuming top-level collection
              .where("providerId", isEqualTo: providerId)
              .orderBy("timestamp", descending: true) // Use timestamp field
              .limit(limit)
              .get();
      return querySnapshot.docs
          .map((doc) => AccessLog.fromSnapshot(doc))
          .toList();
    } catch (e) {
      print("Error fetching Recent Access Logs: $e");
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
      "DashboardBloc [_calculateDashboardStats]: Calculating for /reservations/$governorateId/$providerId",
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
      final List<dynamic> statsResults = await Future.wait([
        // 1. Active Subscriptions Count (Assumes top-level)
        _firestore
            .collection("subscriptions")
            .where("providerId", isEqualTo: providerId)
            .where("status", isEqualTo: "Active")
            .count()
            .get(),
        // 2. Upcoming Reservations Count (Uses Partitioned Path)
        _firestore
            .collection("reservations")
            .doc(governorateId) // Use Partition
            .collection(providerId) // Use Partition
            .where("status", whereIn: ["Confirmed", "Pending"])
            .where("dateTime", isGreaterThanOrEqualTo: Timestamp.now())
            .count()
            .get(),
        // 3. Total Revenue This Month (Example - WARNING: Inefficient)
        // Fetches subscription documents (Assumes top-level)
        // Consider a Cloud Function for accurate, efficient aggregation
        _firestore
            .collection("subscriptions")
            .where("providerId", isEqualTo: providerId)
            .where(
              "startDate",
              isGreaterThanOrEqualTo: startOfMonth,
            ) // Based on when sub STARTED
            .where("startDate", isLessThanOrEqualTo: endOfMonth)
            .get(),
        // 4. New Members This Month (Example: Count new subscriptions - Assumes top-level)
        _firestore
            .collection("subscriptions")
            .where("providerId", isEqualTo: providerId)
            .where("startDate", isGreaterThanOrEqualTo: startOfMonth)
            .where("startDate", isLessThanOrEqualTo: endOfMonth)
            .count()
            .get(),
        // 5. Check-ins Today (Assumes top-level accessLogs)
        _firestore
            .collection("accessLogs")
            .where("providerId", isEqualTo: providerId)
            .where("timestamp", isGreaterThanOrEqualTo: startOfDay)
            .where("timestamp", isLessThanOrEqualTo: endOfDay)
            // Ensure 'status' field indicates successful check-in, e.g., 'Granted'
            .where(
              "status",
              isEqualTo: "Granted",
            ) // Filter for successful check-ins
            // .where("method", whereIn: ["NFC", "QR"]) // Optional: Filter by method
            .count()
            .get(),
        // 6. Total Bookings This Month (Uses Partitioned Path)
        _firestore
            .collection("reservations")
            .doc(governorateId) // Use Partition
            .collection(providerId) // Use Partition
            .where(
              "status",
              whereIn: ["Confirmed", "Completed"],
            ) // Count confirmed/completed
            .where("dateTime", isGreaterThanOrEqualTo: startOfMonth)
            .where("dateTime", isLessThanOrEqualTo: endOfMonth)
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
      // TODO: Add revenue from completed reservations this month (requires partitioned query)
      // Example (inefficient - fetches docs):
      // final resRevenueSnapshot = await _firestore.collection("reservations").doc(governorateId).collection(providerId)
      //    .where("status", isEqualTo: "Completed")
      //    .where("dateTime", isGreaterThanOrEqualTo: startOfMonth)
      //    .where("dateTime", isLessThanOrEqualTo: endOfMonth)
      //    .get();
      // for (var doc in resRevenueSnapshot.docs) {
      //    totalRevenue += (doc.data()?['price'] as num?) ?? 0.0; // Assuming a 'price' field exists
      // }

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
      // return const DashboardStats.empty();
      // Rethrow to trigger DashboardLoadFailure in the main handler
      throw Exception("Could not calculate dashboard statistics.");
    }
  }
} // End DashboardBloc class

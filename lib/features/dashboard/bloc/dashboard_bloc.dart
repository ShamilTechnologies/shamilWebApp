import 'dart:async'; // Required for Future

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart'; // For potential date formatting in stats

// Adjust paths as necessary for your project structure

// Use part directives to link event and state files
part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DashboardBloc() : super(DashboardInitial()) {
    on<LoadDashboardData>(_onLoadDashboardData);
    on<RefreshDashboardData>(_onLoadDashboardData); // Refresh re-uses load logic
    // Add handlers for other dashboard events as needed
  }

  Future<void> _onLoadDashboardData(
    DashboardEvent event, // Can be LoadDashboardData or RefreshDashboardData
    Emitter<DashboardState> emit,
  ) async {
    // Don't show loading indicator again if already loading (e.g., quick refresh)
    // However, allow refresh even if already loaded.
    if (state is! DashboardLoading || event is RefreshDashboardData) {
       print("DashboardBloc: Emitting DashboardLoading (Event: ${event.runtimeType})");
       emit(DashboardLoading());
    }

    final User? user = _auth.currentUser;

    if (user == null) {
      print("DashboardBloc: No authenticated user found.");
      emit(const DashboardLoadFailure("User not authenticated. Please log in again."));
      return;
    }

    final String providerId = user.uid; // Assuming provider UID is the auth UID

    try {
      print("DashboardBloc: Fetching data for provider $providerId...");

      // --- Fetch data concurrently ---
      final results = await Future.wait([
        _fetchServiceProvider(providerId),
        _fetchRecentReservations(providerId, limit: 10), // Fetch recent/upcoming
        _fetchRecentSubscriptions(providerId, limit: 10), // Fetch recent/active
        _fetchRecentAccessLogs(providerId, limit: 10), // Fetch recent logs
        _calculateDashboardStats(providerId), // Calculate stats (basic for now)
      ]);

      // --- Process results ---
      // Type check results carefully
      final ServiceProviderModel providerInfo = results[0] as ServiceProviderModel;
      final List<Reservation> reservations = results[1] as List<Reservation>;
      final List<Subscription> subscriptions = results[2] as List<Subscription>;
      final List<AccessLog> accessLogs = results[3] as List<AccessLog>;
      final DashboardStats stats = results[4] as DashboardStats;

      print("DashboardBloc: Data fetched successfully.");
      emit(DashboardLoadSuccess(
        providerInfo: providerInfo,
        stats: stats,
        reservations: reservations,
        subscriptions: subscriptions,
        accessLogs: accessLogs,
      ));

    } catch (e, stackTrace) {
      print("DashboardBloc: Error loading dashboard data: $e");
      print(stackTrace); // Log stack trace for debugging
      emit(DashboardLoadFailure("Failed to load dashboard data: ${e.toString()}"));
    }
  }

  // --- Helper: Fetch Service Provider Info ---
  Future<ServiceProviderModel> _fetchServiceProvider(String providerId) async {
    try {
      final docSnapshot = await _firestore.collection("serviceProviders").doc(providerId).get();
      if (docSnapshot.exists) {
        return ServiceProviderModel.fromFirestore(docSnapshot); // Use model's factory
      } else {
        throw Exception("Service provider data not found for ID: $providerId");
      }
    } catch (e) {
       print("Error fetching ServiceProvider: $e");
       throw Exception("Could not load provider information."); // Re-throw specific error
    }
  }

  // --- Helper: Fetch Recent/Upcoming Reservations ---
  Future<List<Reservation>> _fetchRecentReservations(String providerId, {int limit = 10}) async {
    try {
      // Example: Fetch upcoming confirmed/pending reservations, ordered by date
      final querySnapshot = await _firestore
          .collection("reservations") // Assuming collection name
          .where("providerId", isEqualTo: providerId)
          .where("status", whereIn: ["Confirmed", "Pending"]) // Example filter
          .where("dateTime", isGreaterThanOrEqualTo: Timestamp.now()) // Fetch future reservations
          .orderBy("dateTime", descending: false) // Show soonest first
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => Reservation.fromSnapshot(doc)) // Use model's factory
          .toList();
    } catch (e) {
       print("Error fetching Reservations: $e");
       // Return empty list or throw, depending on desired behavior
       return [];
       // throw Exception("Could not load reservations.");
    }
  }

  // --- Helper: Fetch Recent/Active Subscriptions ---
  Future<List<Subscription>> _fetchRecentSubscriptions(String providerId, {int limit = 10}) async {
     try {
       // Example: Fetch active subscriptions, ordered by expiry date
       final querySnapshot = await _firestore
           .collection("subscriptions") // Assuming collection name
           .where("providerId", isEqualTo: providerId)
           .where("status", isEqualTo: "Active") // Example filter for active
           // .orderBy("expiryDate", descending: false) // Order by expiry if needed
           .limit(limit)
           .get();

       return querySnapshot.docs
           .map((doc) => Subscription.fromSnapshot(doc)) // Use model's factory
           .toList();
     } catch (e) {
       print("Error fetching Subscriptions: $e");
       return [];
       // throw Exception("Could not load subscriptions.");
     }
  }

  // --- Helper: Fetch Recent Access Logs ---
  Future<List<AccessLog>> _fetchRecentAccessLogs(String providerId, {int limit = 10}) async {
     try {
       // Example: Fetch latest logs first
       final querySnapshot = await _firestore
           .collection("accessLogs") // Assuming collection name
           .where("providerId", isEqualTo: providerId)
           .orderBy("timestamp", descending: true) // Use the correct field name 'timestamp'
           .limit(limit)
           .get();

       return querySnapshot.docs
           .map((doc) => AccessLog.fromSnapshot(doc)) // Use model's factory
           .toList();
     } catch (e) {
       print("Error fetching Access Logs: $e");
       return [];
       // throw Exception("Could not load access logs.");
     }
  }

  // --- Helper: Calculate Dashboard Stats ---
  // This is a basic implementation. Complex stats often require backend aggregation.
  Future<DashboardStats> _calculateDashboardStats(String providerId) async {
    try {
      // Fetch necessary data for calculations (can be optimized)
      // Example: Get count of active subscriptions
      final subsQuery = await _firestore
          .collection("subscriptions")
          .where("providerId", isEqualTo: providerId)
          .where("status", isEqualTo: "Active")
          .count() // Use count aggregation
          .get();
      final activeSubsCount = subsQuery.count ?? 0;

      // TODO: Implement calculation for totalRevenueMonth
      // This might require querying reservations/subscriptions within the date range
      // and summing prices, or reading an aggregated value if calculated elsewhere.
      final double totalRevenue = 0.0; // Placeholder

      // TODO: Implement calculation for newMembersMonth
      // Requires querying subscriptions/users with a creation/start date in the current month.
      final int newMembers = 0; // Placeholder

      // TODO: Implement calculation for checkInsToday
      // Requires querying accessLogs for "CheckIn" actions today.
      final int checkIns = 0; // Placeholder

      // TODO: Implement calculation for totalBookingsMonth
      // Requires querying reservations within the current month.
      final int bookingsMonth = 0; // Placeholder

      print("DashboardBloc: Calculated Stats (Basic) - ActiveSubs: $activeSubsCount");

      return DashboardStats(
        activeSubscriptions: activeSubsCount,
        totalRevenue: totalRevenue, // Placeholder
        newMembersMonth: newMembers, // Placeholder
        checkInsToday: checkIns, // Placeholder
        totalBookingsMonth: bookingsMonth, // Placeholder
      );
    } catch (e) {
      print("Error calculating Dashboard Stats: $e");
      // Return empty stats on error or throw
      return const DashboardStats.empty();
      // throw Exception("Could not calculate dashboard statistics.");
    }
  }

}
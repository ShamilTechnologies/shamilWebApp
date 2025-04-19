import 'dart:async'; // Required for Future

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/features/auth/data/ServiceProviderModel.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart'; // For potential date formatting in stats

// Adjust paths as necessary for your project structure

// Use part directives to link event and state files
part 'dashboard_event.dart';
part 'dashboard_state.dart';

//----------------------------------------------------------------------------//
// Dashboard BLoC Implementation                                            //
//----------------------------------------------------------------------------//

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  // Firebase services instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Define collection names (ADAPT IF YOURS ARE DIFFERENT)
  // Consider moving these to a central constants file.
  final String _providersCollection = "serviceProviders";
  final String _subscriptionsCollection = "subscriptions"; // Assumed collection
  final String _reservationsCollection = "reservations"; // Assumed collection
  final String _accessLogsCollection = "accessLogs"; // Assumed collection

  /// Constructor: Initializes the BLoC with the initial state
  /// and registers event handlers.
  DashboardBloc() : super(DashboardInitial()) {
    // Register handlers for different events
    on<LoadDashboardData>(_onLoadDashboardData);
    on<RefreshDashboardData>(_onRefreshDashboardData); // Handler for refresh

    // TODO: Register handlers for other events as features are added
    // Example: on<CancelSubscription>(_onCancelSubscription);
  }

  /// Handles the initial loading OR explicit refresh of dashboard data.
  Future<void> _onLoadDashboardDataInternal(Emitter<DashboardState> emit) async {
     // Common logic for both initial load and refresh
    emit(DashboardLoading()); // Emit loading state immediately
    final user = _auth.currentUser;

    // Check if user is authenticated
    if (user == null) {
      emit(const DashboardLoadFailure("User not authenticated. Cannot load dashboard."));
      return;
    }

    final String providerId = user.uid; // Use Firebase Auth UID as the provider ID

    try {
      // --- Fetch data concurrently using Future.wait for better performance ---

      // 1. Fetch Service Provider Data Future
      print("DashboardBloc: Fetching provider data for UID: $providerId");
      final providerFuture = _fetchProviderData(providerId);

      // 2. Fetch Subscriptions Future
      print("DashboardBloc: Fetching subscriptions for providerId: $providerId");
      final subscriptionsFuture = _fetchSubscriptions(providerId);

      // 3. Fetch Reservations Future
      print("DashboardBloc: Fetching reservations for providerId: $providerId");
      final reservationsFuture = _fetchReservations(providerId);

      // 4. Fetch Access Logs Future
      print("DashboardBloc: Fetching access logs for providerId: $providerId");
      final accessLogsFuture = _fetchAccessLogs(providerId);

      // --- Wait for all futures to complete ---
      final results = await Future.wait([
         providerFuture,
         subscriptionsFuture,
         reservationsFuture,
         accessLogsFuture,
      ]);

      // --- Process Provider Data Result ---
      final ServiceProviderModel? providerModel = results[0] as ServiceProviderModel?;
      final List<Subscription> subscriptions = results[1] as List<Subscription>;
      final List<Reservation> reservations = results[2] as List<Reservation>;
      final List<AccessLog> accessLogs = results[3] as List<AccessLog>;

      // Check if provider data fetch was successful (critical)
      if (providerModel == null) {
         // Error fetching provider data was handled in _fetchProviderData
         // If _fetchProviderData returns null without emitting error, emit here:
          if (state is! DashboardLoadFailure) {
             emit(const DashboardLoadFailure("Failed to load essential provider data."));
          }
         return;
      }
       print("DashboardBloc: All data fetched. Calculating stats...");

      // Calculate Statistics
      final DashboardStats stats = _calculateStats(subscriptions, reservations);
      print("DashboardBloc: Stats calculated.");

      // Emit Success State
      emit(DashboardLoadSuccess(
        providerModel: providerModel,
        subscriptions: subscriptions,
        reservations: reservations,
        accessLogs: accessLogs,
        stats: stats,
      ));
       print("DashboardBloc: Emitted DashboardLoadSuccess state.");

    } catch (e, s) {
      // Catch errors from Future.wait or other unexpected issues
      print("DashboardBloc: Unhandled error during data loading: $e\n$s");
      emit(DashboardLoadFailure("An unexpected error occurred: ${e.toString()}"));
    }
  }


  /// Handler for the [LoadDashboardData] event.
  /// Prevents reloading if data is already loaded or loading.
  Future<void> _onLoadDashboardData(
      LoadDashboardData event, Emitter<DashboardState> emit) async {
     // Only load initially if state is Initial
     if (state is DashboardInitial) {
        await _onLoadDashboardDataInternal(emit);
     } else {
        print("DashboardBloc: LoadDashboardData ignored, state is not Initial.");
     }
  }

  /// Handler for the [RefreshDashboardData] event.
  /// Always triggers a reload, regardless of the current state (unless already loading).
  Future<void> _onRefreshDashboardData(
      RefreshDashboardData event, Emitter<DashboardState> emit) async {
     if (state is DashboardLoading) return; // Don't refresh if already loading
     print("DashboardBloc: RefreshDashboardData event received. Reloading data...");
     await _onLoadDashboardDataInternal(emit);
  }


  // --- Helper Data Fetching Methods ---

  /// Fetches the core Service Provider data. Returns null on failure.
  Future<ServiceProviderModel?> _fetchProviderData(String providerId) async {
     try {
       final docSnapshot = await _firestore.collection(_providersCollection).doc(providerId).get();
       if (!docSnapshot.exists) {
         print("Error fetching provider data: Document $providerId not found.");
         return null; // Indicate failure
       }
       // Uses the imported ServiceProviderModel
       return ServiceProviderModel.fromFirestore(docSnapshot);
     } catch (e, s) {
       print("Error fetching provider data for $providerId: $e\n$s");
       return null; // Indicate failure
     }
  }


  /// Fetches subscriptions. Returns empty list on failure.
  /// **ASSUMPTION:** Root 'subscriptions' collection with 'providerId' field. Adapt if needed.
  Future<List<Subscription>> _fetchSubscriptions(String providerId) async {
     try {
       final querySnapshot = await _firestore
           .collection(_subscriptionsCollection)
           .where('providerId', isEqualTo: providerId)
           // Example: Order by start date
           .orderBy('startDate', descending: true)
           .get();
       // Uses the imported Subscription model's factory
       return querySnapshot.docs.map((doc) => Subscription.fromSnapshot(doc)).toList();
     } catch (e, s) {
       print("Error fetching subscriptions for provider $providerId: $e\n$s");
       return []; // Return empty list on error
     }
  }

  /// Fetches reservations. Returns empty list on failure.
  /// **ASSUMPTION:** Root 'reservations' collection with 'providerId' field. Adapt if needed.
  Future<List<Reservation>> _fetchReservations(String providerId) async {
     try {
        final now = Timestamp.now();
        final querySnapshot = await _firestore
            .collection(_reservationsCollection)
            .where('providerId', isEqualTo: providerId)
            // Example: Fetch upcoming confirmed or pending reservations
            .where('status', whereIn: ['Confirmed', 'Pending'])
            .where('dateTime', isGreaterThanOrEqualTo: now)
            .orderBy('dateTime', descending: false) // Order chronologically
            .get();
        // Uses the imported Reservation model's factory
        return querySnapshot.docs.map((doc) => Reservation.fromSnapshot(doc)).toList();
     } catch (e, s) {
        print("Error fetching reservations for provider $providerId: $e\n$s");
        return [];
     }
  }

   /// Fetches access logs. Returns empty list on failure.
   /// **ASSUMPTION:** Root 'accessLogs' collection with 'providerId' field. Adapt if needed.
   Future<List<AccessLog>> _fetchAccessLogs(String providerId) async {
     try {
       final querySnapshot = await _firestore
           .collection(_accessLogsCollection)
           .where('providerId', isEqualTo: providerId)
           .orderBy('dateTime', descending: true) // Show most recent first
           .limit(20) // Example limit
           .get();
       // Uses the imported AccessLog model's factory
       return querySnapshot.docs.map((doc) => AccessLog.fromSnapshot(doc)).toList();
     } catch (e, s) {
       print("Error fetching access logs for provider $providerId: $e\n$s");
       return [];
     }
   }

   /// Calculates dashboard statistics based on fetched data.
   /// **PLACEHOLDER:** Implement your specific calculation logic here.
   DashboardStats _calculateStats(List<Subscription> subscriptions, List<Reservation> reservations) {
      // This calculation should be robust against errors in the input lists
      try {
         // Example: Count active subscriptions
         final activeSubs = subscriptions.where((s) => s.status == 'Active').length;

         // Example: Count upcoming confirmed/pending reservations
         final now = Timestamp.now();
         final upcomingRes = reservations.where((r) =>
             ['Confirmed', 'Pending'].contains(r.status) &&
             r.dateTime.compareTo(now) >= 0
         ).length;

         // TODO: Implement actual revenue calculation based on your data
         // This might involve summing 'pricePaid' from subscriptions or reservations
         final double revenue = subscriptions
              .where((s) => s.status == 'Active' && s.pricePaid != null) // Example condition
              .fold(0.0, (sum, sub) => sum + (sub.pricePaid ?? 0.0)); // Example sum


         return DashboardStats(
           activeSubscriptions: activeSubs,
           upcomingReservations: upcomingRes,
           totalRevenue: revenue,
         );
      } catch (e, s) {
         print("Error calculating stats: $e\n$s");
         // Return default/empty stats if calculation fails
         return const DashboardStats.empty();
      }
   }

   // TODO: Add handlers for other events like cancelling subscriptions, confirming reservations etc.
   // These would likely involve writing back to Firestore and potentially reloading data.
   // Example:
   // Future<void> _onCancelSubscription(CancelSubscription event, Emitter<DashboardState> emit) async {
   //    // 1. Update Firestore document for subscriptionId = event.subscriptionId
   //    // 2. Handle potential errors
   //    // 3. Optionally emit a temporary success/failure state OR reload all data
   //    add(RefreshDashboardData()); // Reload data after modification
   // }
}

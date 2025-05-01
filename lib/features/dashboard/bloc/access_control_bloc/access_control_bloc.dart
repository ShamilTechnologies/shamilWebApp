/// File: lib/features/dashboard/bloc/access_control_bloc.dart
/// --- Bloc for managing Access Control screen state and data ---
library;

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import models and potentially other services needed
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart'; // Contains AccessLog

// Link Event and State files
part 'access_control_event.dart';
part 'access_control_state.dart';

class AccessControlBloc extends Bloc<AccessControlEvent, AccessControlState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // To get current provider ID

  // TODO: Implement pagination later
  // final int _logsPerPage = 20;

  AccessControlBloc() : super(AccessControlInitial()) {
    on<LoadAccessLogs>(_onLoadAccessLogs);
    // TODO: Add handlers for filtering, searching, loading more
  }

  Future<void> _onLoadAccessLogs(
    LoadAccessLogs event,
    Emitter<AccessControlState> emit,
  ) async {
     // Only emit loading if not already loading
     if (state is AccessControlLoading) return;

     emit(AccessControlLoading());

     final User? user = _auth.currentUser;
     if (user == null) {
       emit(const AccessControlError("User not authenticated."));
       return;
     }
     final String providerId = user.uid;

     try {
       print("AccessControlBloc: Loading logs for provider $providerId");

       // Basic query: Get latest logs for this provider
       // TODO: Add filtering based on event parameters later
       // TODO: Add pagination later (.limit(), .startAfter())
       final querySnapshot = await _firestore
           .collection("accessLogs") // Ensure this collection name is correct
           .where("providerId", isEqualTo: providerId)
           .orderBy("timestamp", descending: true) // Latest first
           .limit(20) // Load initial batch
           .get();

       final logs = querySnapshot.docs
           .map((doc) => AccessLog.fromSnapshot(doc)) // Use model factory
           .toList();

       print("AccessControlBloc: Loaded ${logs.length} logs.");
       emit(AccessControlLoaded(accessLogs: logs));

     } catch (e, stackTrace) {
       print("AccessControlBloc: Error loading access logs: $e");
       print(stackTrace);
       emit(AccessControlError("Failed to load access logs: ${e.toString()}"));
     }
  }
}

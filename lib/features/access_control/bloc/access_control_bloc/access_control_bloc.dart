library;

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import models and potentially other services needed
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart'; // Contains AccessLog
import 'package:shamil_web_app/features/access_control/service/access_control_repository.dart'; // Add repository

// Link Event and State files
part 'access_control_event.dart';
part 'access_control_state.dart';

class AccessControlBloc extends Bloc<AccessControlEvent, AccessControlState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth =
      FirebaseAuth.instance; // To get current provider ID
  final AccessControlRepository _repository = AccessControlRepository();

  // Expose repository for UI operations
  AccessControlRepository get repository => _repository;

  // Define page size
  final int _logsPerPage = 20;

  AccessControlBloc() : super(AccessControlInitial()) {
    on<LoadAccessLogs>(_onLoadAccessLogs);
    // Add handler for loading more
    on<LoadMoreAccessLogs>(_onLoadMoreAccessLogs);
    // TODO: Add handlers for filtering, searching, loading more
  }

  // Handler for initial load and refresh
  Future<void> _onLoadAccessLogs(
    LoadAccessLogs event,
    Emitter<AccessControlState> emit,
  ) async {
    emit(const AccessControlLoading());

    final User? user = _auth.currentUser;
    if (user == null) {
      emit(const AccessControlError("User not authenticated."));
      return;
    }
    final String providerId = user.uid;

    try {
      print("AccessControlBloc: Loading INITIAL logs for provider $providerId");

      final querySnapshot =
          await _firestore
              .collection(
                "accessLogs",
              ) // Ensure this collection name is correct
              .where("providerId", isEqualTo: providerId)
              .orderBy("timestamp", descending: true) // Latest first
              .limit(_logsPerPage) // Load initial batch size
              .get();

      final logs =
          querySnapshot.docs
              .map((doc) => AccessLog.fromSnapshot(doc)) // Use model factory
              .toList();

      final bool hasReachedMax = logs.length < _logsPerPage;
      final DocumentSnapshot? lastDoc =
          querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null;

      print(
        "AccessControlBloc: Loaded initial ${logs.length} logs. HasReachedMax: $hasReachedMax",
      );
      emit(
        AccessControlLoaded(
          accessLogs: logs,
          hasReachedMax: hasReachedMax,
          lastLogDocument: lastDoc,
        ),
      );
    } catch (e, stackTrace) {
      print("AccessControlBloc: Error loading initial access logs: $e");
      print(stackTrace);
      emit(AccessControlError("Failed to load access logs: ${e.toString()}"));
    }
  }

  // Handler for loading more logs
  Future<void> _onLoadMoreAccessLogs(
    LoadMoreAccessLogs event,
    Emitter<AccessControlState> emit,
  ) async {
    // Ensure current state is Loaded and not already at max
    if (state is! AccessControlLoaded ||
        (state as AccessControlLoaded).hasReachedMax) {
      print(
        "AccessControlBloc: Cannot load more, state is not Loaded or hasReachedMax.",
      );
      return;
    }

    final currentState = state as AccessControlLoaded;

    // Prevent emitting loading if already loading more
    if (state is AccessControlLoading &&
        (state as AccessControlLoading).isLoadingMore)
      return;

    emit(
      const AccessControlLoading(isLoadingMore: true),
    ); // Indicate loading more

    final User? user = _auth.currentUser;
    if (user == null) {
      // Revert to previous loaded state if user gets logged out during load more
      emit(currentState);
      emit(const AccessControlError("User not authenticated."));
      return;
    }
    final String providerId = user.uid;

    try {
      print(
        "AccessControlBloc: Loading MORE logs for provider $providerId after document ${currentState.lastLogDocument?.id}",
      );

      // Start query after the last known document
      Query query = _firestore
          .collection("accessLogs")
          .where("providerId", isEqualTo: providerId)
          .orderBy("timestamp", descending: true)
          .limit(_logsPerPage);

      if (currentState.lastLogDocument != null) {
        query = query.startAfterDocument(currentState.lastLogDocument!);
      } else {
        // This case shouldn't happen if LoadAccessLogs worked correctly, but handle defensively
        print(
          "AccessControlBloc: Warning - lastLogDocument is null when trying to load more.",
        );
        emit(
          currentState.copyWith(hasReachedMax: true),
        ); // Assume max reached if last doc is missing
        return;
      }

      final querySnapshot = await query.get();

      final newLogs =
          querySnapshot.docs.map((doc) => AccessLog.fromSnapshot(doc)).toList();

      final bool hasReachedMax = newLogs.length < _logsPerPage;
      final DocumentSnapshot? lastDoc =
          querySnapshot.docs.isNotEmpty
              ? querySnapshot.docs.last
              : currentState.lastLogDocument;

      print(
        "AccessControlBloc: Loaded ${newLogs.length} more logs. HasReachedMax now: $hasReachedMax",
      );

      emit(
        currentState.copyWith(
          accessLogs: currentState.accessLogs + newLogs, // Append new logs
          hasReachedMax: hasReachedMax,
          lastLogDocument: lastDoc,
        ),
      );
    } catch (e, stackTrace) {
      print("AccessControlBloc: Error loading more access logs: $e");
      print(stackTrace);
      // Emit error but keep previously loaded logs
      emit(currentState); // Revert to previous loaded state first
      emit(
        AccessControlError("Failed to load more access logs: ${e.toString()}"),
      );
    }
  }

  /// Fetch users with reservations (for the smart access control screen)
  Future<List<AccessLog>> fetchUsersWithReservations() async {
    try {
      // Get the repository
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        return [];
      }

      // Get users with reservations from Firestore
      final querySnapshot =
          await _firestore
              .collection('accessLogs')
              .where('providerId', isEqualTo: providerId)
              .orderBy('timestamp', descending: true)
              .limit(50)
              .get();

      final logs =
          querySnapshot.docs.map((doc) => AccessLog.fromSnapshot(doc)).toList();

      // Get unique users from logs
      final uniqueUserIds = <String>{};
      final uniqueUsers = <AccessLog>[];

      for (final log in logs) {
        if (!uniqueUserIds.contains(log.userId)) {
          uniqueUserIds.add(log.userId);
          uniqueUsers.add(log);
        }
      }

      return uniqueUsers;
    } catch (e) {
      print('Error fetching users with reservations: $e');
      return [];
    }
  }
}

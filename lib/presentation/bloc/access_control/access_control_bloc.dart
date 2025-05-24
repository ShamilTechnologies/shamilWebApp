import 'package:bloc/bloc.dart';
import 'dart:async';

import '../../../domain/usecases/access_control/validate_access_usecase.dart';
import '../../../domain/usecases/access_control/sync_data_usecase.dart';
import '../../../domain/models/access_control/access_credential.dart';
import '../../../domain/models/access_control/access_log.dart' as domain;
import '../../../domain/models/access_control/cached_user.dart';
import '../../../core/services/sync_manager.dart';
import 'access_control_event.dart';
import 'access_control_state.dart';

/// BLoC for access control functionality
class AccessControlBloc extends Bloc<AccessControlEvent, AccessControlState> {
  final ValidateAccessUseCase _validateAccessUseCase;
  final SyncDataUseCase _syncDataUseCase;
  StreamSubscription<bool>? _syncStatusSubscription;
  StreamSubscription<List<domain.AccessLog>>? _logsSubscription;

  /// Creates a new access control BLoC with required use cases
  AccessControlBloc({
    required ValidateAccessUseCase validateAccessUseCase,
    required SyncDataUseCase syncDataUseCase,
  }) : _validateAccessUseCase = validateAccessUseCase,
       _syncDataUseCase = syncDataUseCase,
       super(AccessControlInitial()) {
    on<ValidateAccessEvent>(_onValidateAccess);
    on<SyncDataEvent>(_onSyncData);
    on<SyncAccessLogsEvent>(_onSyncAccessLogs);
    on<LoadAccessLogsEvent>(_onLoadAccessLogs);
    on<ClearCacheEvent>(_onClearCache);
    on<RebuildCacheEvent>(_onRebuildCache);
    on<SyncStatusChangedEvent>(_onSyncStatusChanged);
    on<LogsLoadedEvent>(_onLogsLoaded);
    on<LogsErrorEvent>(_onLogsError);

    // Listen for sync status changes
    _syncStatusSubscription = _syncDataUseCase.syncStatusStream().listen((
      isSyncing,
    ) {
      if (isSyncing) {
        add(const SyncStatusChangedEvent(isSyncing: true));
      } else {
        // When sync is complete, if we were in a syncing state, go back to initial
        add(const SyncStatusChangedEvent(isSyncing: false));
      }
    });
  }

  void _onSyncStatusChanged(
    SyncStatusChangedEvent event,
    Emitter<AccessControlState> emit,
  ) {
    if (event.isSyncing) {
      emit(AccessControlSyncing());
    } else if (state is AccessControlSyncing) {
      emit(AccessControlInitial());
    }
  }

  void _onLogsLoaded(LogsLoadedEvent event, Emitter<AccessControlState> emit) {
    emit(AccessLogsLoaded(event.logs));
  }

  void _onLogsError(LogsErrorEvent event, Emitter<AccessControlState> emit) {
    emit(AccessControlError(event.message));
  }

  Future<void> _onValidateAccess(
    ValidateAccessEvent event,
    Emitter<AccessControlState> emit,
  ) async {
    try {
      emit(AccessValidating());

      final result = await _validateAccessUseCase.execute(
        uid: event.uid,
        method: event.method,
      );

      if (result.granted) {
        // Create user object if we have a name
        CachedUser? user;
        if (result.userName != null) {
          user = CachedUser(uid: event.uid, name: result.userName!);
        }

        if (result.credential != null) {
          emit(AccessGranted(user: user, credential: result.credential!));
        } else {
          // This should rarely happen since a credential is needed for access
          emit(
            AccessControlError(
              'Validation error: Access granted but no credential found',
            ),
          );
        }
      } else {
        // Access denied
        CachedUser? user;
        if (result.userName != null) {
          user = CachedUser(uid: event.uid, name: result.userName!);
        }

        // Categorize the access denial type for UI display
        final String reason = result.reason ?? 'Access denied';
        String denialType = 'generic';

        // Categorize the message based on keywords for proper UI display
        if (reason.contains('already in the facility') ||
            reason.contains('already reserved')) {
          denialType = 'already_present';
        } else if (reason.contains('has already passed')) {
          denialType = 'past_reservation';
        } else if (reason.contains('reservation is for')) {
          denialType = 'future_reservation';
        }

        emit(
          AccessDenied(
            user: user,
            reason: reason,
            denialType: denialType,
            credential: result.credential,
          ),
        );
      }
    } catch (e) {
      emit(AccessControlError('Validation error: ${e.toString()}'));
    }
  }

  Future<void> _onSyncData(
    SyncDataEvent event,
    Emitter<AccessControlState> emit,
  ) async {
    try {
      emit(AccessControlSyncing());

      // Update global sync status
      final syncManager = SyncManager();
      syncManager.startDataSync();

      final success = await _syncDataUseCase.execute();

      if (!success) {
        emit(AccessControlError('Data synchronization failed'));
        syncManager.markSyncFailed();
      } else {
        emit(AccessControlInitial());
        syncManager.markSyncSuccess();
      }
    } catch (e) {
      emit(AccessControlError('Sync error: ${e.toString()}'));
      SyncManager().markSyncFailed();
    }
  }

  Future<void> _onSyncAccessLogs(
    SyncAccessLogsEvent event,
    Emitter<AccessControlState> emit,
  ) async {
    try {
      // This will happen in the background through the repository
      // when logs are added, so no need to change state

      // Update global sync status
      final syncManager = SyncManager();
      syncManager.startLogSync();

      final success = await _syncDataUseCase.execute();

      // Update global sync status based on result
      if (success) {
        syncManager.markSyncSuccess();
      } else {
        syncManager.markSyncFailed();
      }
    } catch (e) {
      emit(AccessControlError('Log sync error: ${e.toString()}'));
      SyncManager().markSyncFailed();
    }
  }

  Future<void> _onLoadAccessLogs(
    LoadAccessLogsEvent event,
    Emitter<AccessControlState> emit,
  ) async {
    try {
      emit(AccessControlLoading());

      // Cancel previous subscription if exists
      await _logsSubscription?.cancel();

      // Create a subscription but don't use the listener to emit directly
      _logsSubscription = _syncDataUseCase.repository
          .getRecentAccessLogs(limit: event.limit)
          .listen(
            (logs) {
              // Instead of emitting directly, dispatch a new event
              add(LogsLoadedEvent(logs: logs));
            },
            onError: (e) {
              add(
                LogsErrorEvent(message: 'Error loading logs: ${e.toString()}'),
              );
            },
          );
    } catch (e) {
      emit(AccessControlError('Error loading access logs: ${e.toString()}'));
    }
  }

  Future<void> _onClearCache(
    ClearCacheEvent event,
    Emitter<AccessControlState> emit,
  ) async {
    try {
      emit(AccessControlLoading());
      await _syncDataUseCase.repository.clearCache();
      emit(AccessControlInitial());
    } catch (e) {
      emit(AccessControlError('Error clearing cache: ${e.toString()}'));
    }
  }

  Future<void> _onRebuildCache(
    RebuildCacheEvent event,
    Emitter<AccessControlState> emit,
  ) async {
    try {
      emit(AccessControlSyncing());
      await _syncDataUseCase.rebuildCache();
      emit(AccessControlInitial());
    } catch (e) {
      emit(AccessControlError('Error rebuilding cache: ${e.toString()}'));
    }
  }

  @override
  Future<void> close() {
    _syncStatusSubscription?.cancel();
    _logsSubscription?.cancel();
    return super.close();
  }

  /// Expose the repository for diagnostic purposes
  SyncDataUseCase get syncDataUseCase => _syncDataUseCase;

  /// Diagnostic helper to check access for pending reservations
  Future<void> diagnoseAccessForUser(String uid) async {
    try {
      // Call the repository's diagnostic method
      await _validateAccessUseCase.repository.diagnoseUserAccess(uid);

      // Do our own diagnosis
      final user = await _validateAccessUseCase.repository.getUser(uid);
      final credential = await _validateAccessUseCase.repository
          .getValidCredential(uid);

      // Log results
      print('===== ADDITIONAL ACCESS DIAGNOSIS FOR USER $uid =====');
      if (user != null) {
        print('✓ USER FOUND: ${user.name}');
      } else {
        print('✗ USER NOT FOUND');
      }

      if (credential != null) {
        print(
          '✓ CREDENTIAL FOUND: ${credential.type}, isValid: ${credential.isValid}',
        );
        print('  Service: ${credential.serviceName}');
        print('  Start: ${credential.startDate}');
        print('  End: ${credential.endDate}');

        if (credential.details != null) {
          print('  Details: ${credential.details}');

          if (credential.details!.containsKey('reservationStatus')) {
            print(
              '  Reservation Status: ${credential.details!['reservationStatus']}',
            );
            if (credential.details!['reservationStatus'] == 'Pending') {
              print(
                '  NOTE: This is a pending reservation. Access should be allowed now.',
              );
            }
          }
        }
      } else {
        print('✗ NO CREDENTIAL FOUND');
      }

      // Check validation
      final bool hasAccess = await _validateAccessUseCase.repository
          .validateAccess(uid);
      print(hasAccess ? '✓ ACCESS GRANTED' : '✗ ACCESS DENIED');
      print('===== END OF ADDITIONAL DIAGNOSIS =====');
    } catch (e) {
      print('Error in access diagnosis: $e');
    }
  }
}

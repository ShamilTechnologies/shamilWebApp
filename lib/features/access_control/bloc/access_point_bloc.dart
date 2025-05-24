/// File: lib/features/access_control/bloc/access_point_bloc.dart
/// --- UPDATED: Uses updated ServiceProviderModel to get governorateId for validation ---
/// --- UPDATED: Verified governorateId usage and dependency on Sync Service ---
library;

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
// Removed Isar import
import 'package:flutter/foundation.dart'; // For kDebugMode, ValueNotifier
// *** Uses updated Sync Service (already refactored) ***
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart';
// *** Import NFC Service ***
import 'package:shamil_web_app/features/access_control/service/nfc_reader_service.dart';
// *** Import Repository Service ***
import 'package:shamil_web_app/features/access_control/service/access_control_repository.dart';

// *** Uses updated Hive Models (via Sync Service) ***
import 'package:shamil_web_app/features/access_control/data/local_cache_models.dart';
// *** Uses updated ServiceProviderModel (read via DashboardBloc) ***
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
// Import Dashboard Bloc/State to potentially read provider info
import 'package:shamil_web_app/features/dashboard/bloc/dashboard_bloc.dart';

// Import our new offline-first service
import 'package:shamil_web_app/features/access_control/service/offline_first_access_service.dart';

part 'access_point_event.dart';
part 'access_point_state.dart';

class AccessPointBloc extends Bloc<AccessPointEvent, AccessPointState> {
  // Use our new offline-first service
  final OfflineFirstAccessService _offlineAccessService =
      OfflineFirstAccessService();
  final NfcReaderService _nfcReaderService = NfcReaderService();
  final DashboardBloc dashboardBloc; // To get provider info

  // Repository for access control operations
  final AccessControlRepository _repository = AccessControlRepository();

  // Debounce for NFC reads might still be useful
  Timer? _nfcDebounceTimer;
  String? _lastReadNfcId;

  StreamSubscription? _nfcTagSubscription;
  // Listener callback needs to be stored to be removed later
  late final VoidCallback _nfcStatusListenerCallback;

  AccessPointBloc({required this.dashboardBloc})
    : super(const AccessPointInitial()) {
    // Define the listener callback here
    _nfcStatusListenerCallback = () {
      if (!isClosed) {
        // Check if Bloc is closed before adding event
        add(
          _NfcReaderStatusChanged(
            _nfcReaderService.connectionStatusNotifier.value,
          ),
        );
      }
    };

    // Register event handlers
    // REMOVED: QrCodeScanned, StartScanner, StopScanner handlers (assuming QR UI removed)
    on<NfcTagRead>(_onNfcTagRead); // Triggered by service listener
    on<ValidateAccess>(_onValidateAccess);
    on<ValidateUserAccess>(
      _onValidateUserAccess,
    ); // Add handler for direct user validation
    on<ResetAccessPoint>(_onResetAccessPoint);
    on<ListAvailablePorts>(_onListAvailablePorts);
    on<ConnectNfcReader>(_onConnectNfcReader);
    on<DisconnectNfcReader>(_onDisconnectNfcReader);
    on<_NfcReaderStatusChanged>(_onNfcReaderStatusChanged);
    on<ForceSyncWithMobileApp>(_onForceSyncWithMobileApp);

    // Listen to service streams/notifiers
    _listenToNfcService();

    // List ports on initialization
    add(ListAvailablePorts());
  }

  /// Sets up listeners for the NfcReaderService streams and notifiers.
  void _listenToNfcService() {
    _nfcTagSubscription?.cancel();
    _nfcReaderService.connectionStatusNotifier.removeListener(
      _nfcStatusListenerCallback,
    ); // Use stored callback

    _nfcTagSubscription = _nfcReaderService.tagStream.listen((tagId) {
      // Ensure bloc is not closed before adding event
      if (!isClosed)
        add(NfcTagRead(id: tagId)); // Dispatch event when service emits tag
    });

    _nfcReaderService.connectionStatusNotifier.addListener(
      _nfcStatusListenerCallback,
    ); // Add listener

    print("AccessPointBloc: Subscribed to NFC Reader Service updates.");
    // Update initial state with current NFC status
    if (!isClosed) {
      // Check before adding initial status event
      add(
        _NfcReaderStatusChanged(
          _nfcReaderService.connectionStatusNotifier.value,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    print("AccessPointBloc: Closing and cleaning up subscriptions.");
    _nfcDebounceTimer?.cancel();
    _nfcTagSubscription?.cancel();
    _nfcReaderService.connectionStatusNotifier.removeListener(
      _nfcStatusListenerCallback,
    ); // Use stored callback
    return super.close();
  }

  // --- Event Handlers --- (Keep existing NFC/Reset/Port handlers)

  // Handles NFC tag read event (dispatched by the service listener)
  void _onNfcTagRead(NfcTagRead event, Emitter<AccessPointState> emit) {
    // Prevent processing if closed
    if (isClosed) return;
    print("AccessPointBloc: NFC Tag Read Event Received: ${event.id}");

    // Optional Debounce for NFC
    if (event.id == _lastReadNfcId && _nfcDebounceTimer?.isActive == true) {
      print("AccessPointBloc: Debouncing duplicate NFC read: ${event.id}");
      return;
    }
    _lastReadNfcId = event.id;
    _nfcDebounceTimer?.cancel();
    _nfcDebounceTimer = Timer(
      const Duration(seconds: 3),
      () => _lastReadNfcId = null,
    );

    if (event.id.isNotEmpty) {
      add(ValidateAccess(userId: event.id, method: 'NFC'));
    }
  }

  void _onResetAccessPoint(
    ResetAccessPoint event,
    Emitter<AccessPointState> emit,
  ) {
    // Prevent processing if closed
    if (isClosed) return;
    print("AccessPointBloc: Resetting state.");
    // Just go back to initial state, keeping NFC status/ports
    emit(
      AccessPointInitial(
        nfcStatus: state.nfcStatus,
        availablePorts: state.availablePorts,
      ),
    );
  }

  // --- NFC Reader Connection Event Handlers ---

  void _onListAvailablePorts(
    ListAvailablePorts event,
    Emitter<AccessPointState> emit,
  ) {
    // Prevent processing if closed
    if (isClosed) return;
    print("AccessPointBloc: Listing available serial ports...");
    final ports = _nfcReaderService.getAvailablePorts();
    print("AccessPointBloc: Found ports: $ports");
    // Emit the current state type but update the availablePorts list
    emit(state.copyWithNewBaseState(availablePorts: ports));
  }

  Future<void> _onConnectNfcReader(
    ConnectNfcReader event,
    Emitter<AccessPointState> emit,
  ) async {
    // Prevent processing if closed
    if (isClosed) return;
    print("AccessPointBloc: Attempting NFC connect to ${event.portName}");
    // Service handles actual connection and status update via notifier
    await _nfcReaderService.connect(event.portName);
    // Status change will trigger _onNfcReaderStatusChanged
  }

  Future<void> _onDisconnectNfcReader(
    DisconnectNfcReader event,
    Emitter<AccessPointState> emit,
  ) async {
    // Prevent processing if closed
    if (isClosed) return;
    print("AccessPointBloc: Attempting NFC disconnect");
    // Service handles actual disconnection and status update via notifier
    await _nfcReaderService.disconnect();
    // Status change will trigger _onNfcReaderStatusChanged
  }

  // Handles status changes reported by the NfcReaderService listener
  void _onNfcReaderStatusChanged(
    _NfcReaderStatusChanged event,
    Emitter<AccessPointState> emit,
  ) {
    // Prevent processing if closed
    if (isClosed) return;
    print("AccessPointBloc: NFC Status Changed to ${event.status}");
    // Update available ports when status changes (e.g., port disappears on error)
    final ports = _nfcReaderService.getAvailablePorts();
    // Emit the appropriate state type based on the *current* state, just updating base props
    emit(
      state.copyWithNewBaseState(
        nfcStatus: event.status,
        availablePorts: ports,
      ),
    );
  }

  // --- Validation Logic ---

  Future<void> _onValidateAccess(
    ValidateAccess event,
    Emitter<AccessPointState> emit,
  ) async {
    // Prevent processing if closed
    if (isClosed) return;
    // Prevent validation if already validating
    if (state is AccessPointValidating) return;

    // Emit validating state, preserving current NFC status and ports
    emit(
      AccessPointValidating(
        nfcStatus: state.nfcStatus,
        availablePorts: state.availablePorts,
      ),
    );
    print(
      "AccessPointBloc: Validating access (Offline) for User ID: ${event.userId} via ${event.method}",
    );

    String? denialReason;
    CachedUser? cachedUser;

    // *** Get Provider Info (including governorateId) from DashboardBloc state ***
    PricingModel currentPricingModel = PricingModel.other; // Default
    String? currentGovernorateId; // Default null
    final dashboardState = dashboardBloc.state; // Access injected bloc's state
    if (dashboardState is DashboardLoadSuccess) {
      currentPricingModel = dashboardState.providerInfo.pricingModel;
      // *** Fetch governorateId from the UPDATED providerInfo model ***
      currentGovernorateId = dashboardState.providerInfo.governorateId;
      print(
        "AccessPointBloc: Using Provider Info - Pricing Model: ${currentPricingModel.name}, Governorate ID: $currentGovernorateId",
      );
    } else {
      print(
        "AccessPointBloc: Warning - Could not get provider info from DashboardBloc state (${dashboardState.runtimeType}). Validation might be unreliable. Using defaults.",
      );
      // Emit error or deny access if provider info is critical and missing
      emit(
        AccessPointResult(
          validationStatus: ValidationStatus.error,
          scannedId: event.userId,
          method: event.method,
          message: "Provider info unavailable for validation.",
          nfcStatus: state.nfcStatus,
          availablePorts: state.availablePorts,
        ),
      );
      return;
    }

    try {
      // Initialize the offline service if needed
      if (!_offlineAccessService.isInitializedNotifier.value) {
        await _offlineAccessService.initialize();
      }

      // Check user access with our offline-first service
      final accessResult = await _offlineAccessService.checkUserAccess(
        event.userId,
      );

      // Get the result details
      final bool hasAccess = accessResult['hasAccess'] as bool;
      final String? accessType = accessResult['accessType'] as String?;
      final String message =
          accessResult['message'] as String? ??
          (hasAccess ? 'Access granted' : 'Access denied');

      if (!hasAccess) {
        denialReason = accessResult['reason'] as String?;
      }

      // Use the username provided in the access result or default to 'Unknown User'
      final String userName = 'Unknown User';

      // Record the access attempt
      await _offlineAccessService.recordAccessAttemptNamed(
        userId: event.userId,
        userName: userName,
        granted: hasAccess,
        denialReason: denialReason,
        method: event.method,
      );

      // Emit the result
      emit(
        AccessPointResult(
          validationStatus:
              hasAccess ? ValidationStatus.granted : ValidationStatus.denied,
          scannedId: event.userId,
          method: event.method,
          userName: userName,
          message: message,
          nfcStatus: state.nfcStatus,
          availablePorts: state.availablePorts,
        ),
      );
    } catch (e, stackTrace) {
      print("!!! Error during access validation (Offline): $e\n$stackTrace");

      // Attempt to log the error
      try {
        await _offlineAccessService.recordAccessAttemptNamed(
          userId: event.userId,
          userName: 'Unknown',
          granted: false,
          denialReason: 'Validation Error: ${e.toString()}',
          method: event.method,
        );
      } catch (logError) {
        print("Failed to save error log: $logError");
      }

      // Emit error result, preserving current NFC status and ports
      emit(
        AccessPointResult(
          validationStatus: ValidationStatus.error,
          scannedId: event.userId,
          method: event.method,
          message: "Validation Error: ${e.toString()}",
          nfcStatus: state.nfcStatus,
          availablePorts: state.availablePorts,
        ),
      );
    }
  }

  Future<void> _onForceSyncWithMobileApp(
    ForceSyncWithMobileApp event,
    Emitter<AccessPointState> emit,
  ) async {
    // Prevent processing if closed
    if (isClosed) return;
    print("AccessPointBloc: Force syncing with mobile app");

    emit(AccessPointSyncing());

    try {
      // Use our offline-first service for sync
      final success = await _offlineAccessService.syncNow(forceFull: true);

      // Also trigger sync in dashboard bloc if available
      try {
        dashboardBloc.add(SyncMobileAppData());
      } catch (e) {
        print("Error triggering sync in dashboard bloc: $e");
        // Don't fail the whole operation if this fails
      }

      if (success) {
        emit(AccessPointSyncSuccess());
      } else {
        emit(
          AccessPointSyncFailure(
            _offlineAccessService.errorMessageNotifier.value ??
                "Failed to sync with mobile app",
          ),
        );
      }
    } catch (e) {
      print("Error syncing with mobile app: $e");
      emit(AccessPointSyncFailure(e.toString()));
    } finally {
      // Reset after a delay
      Timer(const Duration(seconds: 3), () {
        if (!isClosed) {
          add(ResetAccessPoint());
        }
      });
    }
  }

  // Handler for validating user access by user ID (from dropdown/selection)
  Future<void> _onValidateUserAccess(
    ValidateUserAccess event,
    Emitter<AccessPointState> emit,
  ) async {
    // Prevent processing if closed
    if (isClosed) return;

    print("AccessPointBloc: Validating user access for ID: ${event.uid}");

    // Show validating state first
    emit(
      AccessPointValidating(
        nfcStatus: state.nfcStatus,
        availablePorts: state.availablePorts,
      ),
    );

    try {
      // Initialize the repository if needed
      await _repository.initialize();

      // Check if user has access
      final accessResult = await _repository.checkUserAccess(event.uid);

      // Extract results
      final bool hasAccess = accessResult['hasAccess'] as bool;
      final String? userName = accessResult['userName'] as String?;
      final String? reason = accessResult['reason'] as String?;
      final String? accessType = accessResult['accessType'] as String?;

      // Record the access attempt (creates log entry)
      await _repository.recordAccess(
        userId: event.uid,
        userName: userName ?? 'Unknown User',
        status: hasAccess ? 'Granted' : 'Denied',
        method: event.method,
        denialReason: hasAccess ? null : reason,
      );

      // Emit appropriate result state
      emit(
        AccessPointResult(
          scannedId: event.uid,
          validationStatus:
              hasAccess ? ValidationStatus.granted : ValidationStatus.denied,
          userName: userName,
          message:
              hasAccess
                  ? accessType == 'subscription'
                      ? 'Access granted (Active subscription)'
                      : 'Access granted (Valid reservation)'
                  : reason ?? 'Access denied',
          method: event.method,
          nfcStatus: state.nfcStatus,
          availablePorts: state.availablePorts,
        ),
      );
    } catch (e) {
      print("AccessPointBloc: Error validating user access: $e");
      emit(
        AccessPointResult(
          scannedId: event.uid,
          validationStatus: ValidationStatus.error,
          message: "Error validating access: $e",
          method: event.method,
          nfcStatus: state.nfcStatus,
          availablePorts: state.availablePorts,
        ),
      );
    }
  }
}

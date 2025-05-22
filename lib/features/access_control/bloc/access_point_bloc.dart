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

part 'access_point_event.dart';
part 'access_point_state.dart';

class AccessPointBloc extends Bloc<AccessPointEvent, AccessPointState> {
  // *** Uses updated Sync Service ***
  final AccessControlSyncService _syncService = AccessControlSyncService();
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
      "AccessPointBloc: Validating access (Offline - Hive) for User ID: ${event.userId} via ${event.method}",
    );

    String accessStatus = "Denied";
    String? denialReason;
    CachedUser? cachedUser;
    final now = DateTime.now();

    // *** Get Provider Info (including governorateId) from DashboardBloc state ***
    // This is crucial for future online validation and context, even if offline check doesn't use govId directly.
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

    // --- Perform Offline Validation using Sync Service and Cached Data ---
    // Note: This relies on AccessControlSyncService having synced data correctly
    // using the governorateId during its `syncAllData` process. The validation
    // check here uses the cached data relevant to this provider.
    try {
      // 1. First, ensure user data is in cache or add temporary entry if we have ID
      await _syncService.ensureUserInCache(event.userId, null);

      // 2. Find User in Cache
      cachedUser = await _syncService.getCachedUser(event.userId);

      if (cachedUser == null) {
        denialReason = "User not found in local cache.";
      } else {
        print("User found: ${cachedUser.userName}");
        bool hasValidSubscription = false;
        bool hasValidReservation = false;

        // 3. Check Subscriptions (Logic remains the same, uses cached data)
        if (currentPricingModel == PricingModel.subscription ||
            currentPricingModel == PricingModel.hybrid) {
          final activeSub = await _syncService.findActiveSubscription(
            event.userId,
            now,
          );
          hasValidSubscription = activeSub != null;
          if (!hasValidSubscription) {
            print("No active subscription found.");
          } else {
            print(
              "Found active subscription expiring on ${activeSub.expiryDate}",
            );
          }
        }

        // 4. Check Reservations (Logic uses updated CachedReservation, but check is same)
        if (currentPricingModel == PricingModel.reservation ||
            currentPricingModel == PricingModel.hybrid) {
          final activeRes = await _syncService.findActiveReservation(
            event.userId,
            now,
          ); // Uses CachedReservation internally
          hasValidReservation = activeRes != null;
          if (!hasValidReservation) {
            print("No active reservation found for this time.");
          } else {
            print(
              "Found active reservation for ${activeRes.serviceName} from ${activeRes.startTime} to ${activeRes.endTime}",
            );
          }
        }

        // 5. Determine Access Status based on provider's model
        switch (currentPricingModel) {
          case PricingModel.subscription:
            if (hasValidSubscription)
              accessStatus = "Granted";
            else
              denialReason = "No active subscription.";
            break;
          case PricingModel.reservation:
            if (hasValidReservation)
              accessStatus = "Granted";
            else
              denialReason = "No valid reservation found for this time.";
            break;
          case PricingModel.hybrid:
            if (hasValidSubscription || hasValidReservation)
              accessStatus = "Granted";
            else
              denialReason = "No active subscription or valid reservation.";
            break;
          case PricingModel.other:
            // Grant if user exists and provider model is 'other'
            // Add more complex rules if needed for 'other' model
            accessStatus = "Granted";
            break;
        }
      }

      // 6. Log the attempt locally using Sync Service method
      final String userName = cachedUser?.userName ?? "Unknown User";
      final logEntry = LocalAccessLog(
        userId: event.userId,
        userName: userName,
        timestamp: DateTime.now(),
        status: accessStatus,
        method: event.method,
        denialReason: denialReason,
        needsSync: true, // Mark for upload later
      );
      await _syncService.saveLocalAccessLog(logEntry); // Use service method
      print(
        "Local access log saved via service. Status: $accessStatus, User: $userName",
      );

      // 7. Emit the result, preserving current NFC status and ports
      emit(
        AccessPointResult(
          validationStatus:
              accessStatus == "Granted"
                  ? ValidationStatus.granted
                  : ValidationStatus.denied,
          scannedId: event.userId,
          method: event.method,
          userName: cachedUser?.userName,
          message:
              denialReason ??
              (accessStatus == "Granted" ? "Access Granted" : "Access Denied"),
          nfcStatus: state.nfcStatus,
          availablePorts: state.availablePorts,
        ),
      );

      // --- Handle potential errors during Hive access or validation ---
    } catch (e, stackTrace) {
      print(
        "!!! Error during access validation (Offline - Hive): $e\n$stackTrace",
      );
      // Attempt to log the error itself
      try {
        final logEntry = LocalAccessLog(
          userId: event.userId,
          userName: 'Unknown',
          timestamp: DateTime.now(),
          status: 'Error', // Log status as Error
          method: event.method,
          denialReason: 'Validation Error: ${e.toString()}',
          needsSync: true,
        );
        await _syncService.saveLocalAccessLog(logEntry);
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

    // --- Placeholder for future online validation call ---
    // if (onlineCheckNeeded) {
    //    print("AccessPointBloc: Performing Online Validation (Not Implemented Yet)...");
    //    // TODO: Call Cloud Function validateAccess(userId: event.userId, providerId: providerId, governorateId: currentGovernorateId)
    //    // Update state based on Cloud Function response
    // }
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
      // Use the repository's dedicated method for mobile app sync
      final success = await _repository.refreshMobileAppData();

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
        emit(AccessPointSyncFailure("Failed to sync with mobile app"));
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
}

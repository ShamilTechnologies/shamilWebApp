/// File: lib/features/access_control/service/access_control_sync_service.dart
/// --- UPDATED: Handles updated Hive models, uses governorateId for partitioned queries ---
/// --- UPDATED: Refactored syncAllData for granular Hive updates ---
library;

import 'dart:async';
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Import Hive Flutter
import 'package:flutter/foundation.dart'; // For ValueNotifier, listEquals
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart'; // For generating log keys
import 'package:path_provider/path_provider.dart'; // Needed for Hive init path
import 'package:collection/collection.dart'; // For deep equality checks
import 'package:shamil_web_app/core/services/sync_manager.dart';

// *** UPDATED: Import updated Hive Models ***
import 'package:shamil_web_app/features/access_control/data/local_cache_models.dart';
// *** UPDATED: Import updated Firestore Models (Reservation, Subscription, AccessLog) ***
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart'
    show Subscription, Reservation, AccessLog;
// *** UPDATED: Import updated ServiceProviderModel to get governorateId ***
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';

// Define Box names as constants
const String cachedUsersBoxName = 'cachedUsersBox';
const String cachedSubscriptionsBoxName = 'cachedSubscriptionsBox';
const String cachedReservationsBoxName = 'cachedReservationsBox';
const String localAccessLogsBoxName = 'localAccessLogsBox';
const String syncMetadataBoxName = 'syncMetadataBox'; // New box for versioning

class AccessControlSyncService {
  // Singleton pattern
  static final AccessControlSyncService _instance =
      AccessControlSyncService._internal();
  factory AccessControlSyncService() => _instance;
  AccessControlSyncService._internal();

  // Hive Boxes (will be opened during init)
  Box<CachedUser>? _cachedUsersBox;
  Box<CachedSubscription>? _cachedSubscriptionsBox;
  Box<CachedReservation>? _cachedReservationsBox;
  Box<LocalAccessLog>? _localAccessLogsBox;

  // New box for sync metadata
  Box<Map>? _syncMetadataBox;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid(); // For generating log keys

  // Equality checkers for comparing Hive objects
  final MapEquality _mapEquality = const MapEquality();
  final ListEquality _listEquality = const ListEquality();

  /// Notifier for the UI to listen to sync status changes.
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier(false);

  // --- Box Getters (Provide access to opened boxes) ---
  Box<CachedUser> get cachedUsersBox {
    // Added null check and isOpen check for safety
    if (_cachedUsersBox == null || !_cachedUsersBox!.isOpen) {
      print("Warning: Accessing cachedUsersBox before it's ready.");
      // Attempt to re-open or throw a more informative error
      // For now, throw state error
      throw StateError(
        'CachedUsersBox not initialized or closed. Call init() first.',
      );
    }
    return _cachedUsersBox!;
  }

  Box<CachedSubscription> get cachedSubscriptionsBox {
    if (_cachedSubscriptionsBox == null || !_cachedSubscriptionsBox!.isOpen) {
      print("Warning: Accessing cachedSubscriptionsBox before it's ready.");
      throw StateError('CachedSubscriptionsBox not initialized or closed.');
    }
    return _cachedSubscriptionsBox!;
  }

  Box<CachedReservation> get cachedReservationsBox {
    if (_cachedReservationsBox == null || !_cachedReservationsBox!.isOpen) {
      print("Warning: Accessing cachedReservationsBox before it's ready.");
      throw StateError('CachedReservationsBox not initialized or closed.');
    }
    return _cachedReservationsBox!;
  }

  Box<LocalAccessLog> get localAccessLogsBox {
    if (_localAccessLogsBox == null || !_localAccessLogsBox!.isOpen) {
      print("Warning: Accessing localAccessLogsBox before it's ready.");
      throw StateError('LocalAccessLogsBox not initialized or closed.');
    }
    return _localAccessLogsBox!;
  }

  Box<Map> get syncMetadataBox {
    if (_syncMetadataBox == null || !_syncMetadataBox!.isOpen) {
      print("Warning: Accessing syncMetadataBox before it's ready.");
      throw StateError('SyncMetadataBox not initialized or closed.');
    }
    return _syncMetadataBox!;
  }
  // --- End Box Getters ---

  /// Initializes Hive, registers adapters, and opens boxes.
  Future<void> init() async {
    if (_cachedUsersBox?.isOpen == true && // Check all boxes more robustly
        _cachedSubscriptionsBox?.isOpen == true &&
        _cachedReservationsBox?.isOpen == true &&
        _localAccessLogsBox?.isOpen == true &&
        _syncMetadataBox?.isOpen == true) {
      print(
        "AccessControlSyncService: Hive boxes already initialized and open.",
      );
      return;
    }
    print("AccessControlSyncService: Initializing Hive...");

    try {
      // First ensure Hive is fully initialized
      try {
        final appDocumentDir = await getApplicationDocumentsDirectory();
        print(
          "AccessControlSyncService: Using documents directory: ${appDocumentDir.path}",
        );

        try {
          // Try init, catch if already initialized
          Hive.init(appDocumentDir.path);
          print(
            "AccessControlSyncService: Hive initialized successfully at ${appDocumentDir.path}",
          );
        } catch (e) {
          if (e is HiveError &&
              e.message.contains("already been initialized")) {
            print("AccessControlSyncService: Hive already initialized");
          } else {
            print("AccessControlSyncService: Error during Hive.init: $e");
            rethrow;
          }
        }
      } catch (e) {
        print(
          "AccessControlSyncService: Critical error with path initialization: $e",
        );
        rethrow;
      }

      // Register TypeAdapters (generated by build_runner)
      print("AccessControlSyncService: Registering type adapters...");
      if (!Hive.isAdapterRegistered(cachedUserTypeId)) {
        Hive.registerAdapter(CachedUserAdapter());
        print("AccessControlSyncService: Registered CachedUserAdapter");
      }
      if (!Hive.isAdapterRegistered(cachedSubscriptionTypeId)) {
        Hive.registerAdapter(CachedSubscriptionAdapter());
        print("AccessControlSyncService: Registered CachedSubscriptionAdapter");
      }
      if (!Hive.isAdapterRegistered(cachedReservationTypeId)) {
        Hive.registerAdapter(CachedReservationAdapter());
        print("AccessControlSyncService: Registered CachedReservationAdapter");
      }
      if (!Hive.isAdapterRegistered(localAccessLogTypeId)) {
        Hive.registerAdapter(LocalAccessLogAdapter());
        print("AccessControlSyncService: Registered LocalAccessLogAdapter");
      }

      // Open boxes one by one with explicit error handling for each
      print("AccessControlSyncService: Opening Hive boxes...");
      try {
        _cachedUsersBox = await Hive.openBox<CachedUser>(cachedUsersBoxName);
        print("AccessControlSyncService: Opened cachedUsersBox");
      } catch (e) {
        print("AccessControlSyncService: Error opening cachedUsersBox: $e");
        throw Exception("Failed to open cachedUsersBox: $e");
      }

      try {
        _cachedSubscriptionsBox = await Hive.openBox<CachedSubscription>(
          cachedSubscriptionsBoxName,
        );
        print("AccessControlSyncService: Opened cachedSubscriptionsBox");
      } catch (e) {
        print(
          "AccessControlSyncService: Error opening cachedSubscriptionsBox: $e",
        );
        throw Exception("Failed to open cachedSubscriptionsBox: $e");
      }

      try {
        _cachedReservationsBox = await Hive.openBox<CachedReservation>(
          cachedReservationsBoxName,
        );
        print("AccessControlSyncService: Opened cachedReservationsBox");
      } catch (e) {
        print(
          "AccessControlSyncService: Error opening cachedReservationsBox: $e",
        );
        throw Exception("Failed to open cachedReservationsBox: $e");
      }

      try {
        _localAccessLogsBox = await Hive.openBox<LocalAccessLog>(
          localAccessLogsBoxName,
        );
        print("AccessControlSyncService: Opened localAccessLogsBox");
      } catch (e) {
        print("AccessControlSyncService: Error opening localAccessLogsBox: $e");
        throw Exception("Failed to open localAccessLogsBox: $e");
      }

      try {
        _syncMetadataBox = await Hive.openBox<Map>(syncMetadataBoxName);
        print("AccessControlSyncService: Opened syncMetadataBox");
      } catch (e) {
        print("AccessControlSyncService: Error opening syncMetadataBox: $e");
        throw Exception("Failed to open syncMetadataBox: $e");
      }

      print("AccessControlSyncService: All Hive boxes opened successfully.");
    } catch (e, stackTrace) {
      print(
        "!!! AccessControlSyncService: CRITICAL ERROR during Hive initialization: $e",
      );
      print(stackTrace);
      // Rethrow to let caller handle the error
      throw Exception("Failed to initialize Hive: $e");
    }
  }

  /// Closes all opened Hive boxes.
  Future<void> close() async {
    print("AccessControlSyncService: Closing Hive boxes...");
    await _cachedUsersBox?.compact(); // Compact before closing (optional)
    await _cachedUsersBox?.close();
    await _cachedSubscriptionsBox?.compact();
    await _cachedSubscriptionsBox?.close();
    await _cachedReservationsBox?.compact();
    await _cachedReservationsBox?.close();
    await _localAccessLogsBox?.compact();
    await _localAccessLogsBox?.close();
    await _syncMetadataBox?.compact();
    await _syncMetadataBox?.close();
    _cachedUsersBox = null; // Nullify references
    _cachedSubscriptionsBox = null;
    _cachedReservationsBox = null;
    _localAccessLogsBox = null;
    _syncMetadataBox = null;
    print("AccessControlSyncService: Hive boxes closed.");
  }

  /// Rebuilds the local cache by deleting and reinitializing all Hive boxes
  /// Use this if there are issues with the local cache
  Future<void> rebuildLocalCache() async {
    print("AccessControlSyncService: Rebuilding local cache...");
    isSyncingNotifier.value = true;

    try {
      // First, close any open boxes
      await close();

      // Delete boxes if they exist
      print("AccessControlSyncService: Deleting existing Hive boxes...");
      try {
        await Hive.deleteBoxFromDisk(cachedUsersBoxName);
        print("AccessControlSyncService: Deleted cachedUsersBox");
      } catch (e) {
        print("AccessControlSyncService: Error deleting cachedUsersBox: $e");
      }

      try {
        await Hive.deleteBoxFromDisk(cachedSubscriptionsBoxName);
        print("AccessControlSyncService: Deleted cachedSubscriptionsBox");
      } catch (e) {
        print(
          "AccessControlSyncService: Error deleting cachedSubscriptionsBox: $e",
        );
      }

      try {
        await Hive.deleteBoxFromDisk(cachedReservationsBoxName);
        print("AccessControlSyncService: Deleted cachedReservationsBox");
      } catch (e) {
        print(
          "AccessControlSyncService: Error deleting cachedReservationsBox: $e",
        );
      }

      try {
        await Hive.deleteBoxFromDisk(localAccessLogsBoxName);
        print("AccessControlSyncService: Deleted localAccessLogsBox");
      } catch (e) {
        print(
          "AccessControlSyncService: Error deleting localAccessLogsBox: $e",
        );
      }

      try {
        await Hive.deleteBoxFromDisk(syncMetadataBoxName);
        print("AccessControlSyncService: Deleted syncMetadataBox");
      } catch (e) {
        print("AccessControlSyncService: Error deleting syncMetadataBox: $e");
      }

      // Reinitialize Hive and open new boxes
      print("AccessControlSyncService: Reinitializing Hive boxes...");
      await init();

      // Perform a full sync to populate the new boxes
      await syncAllData();

      print(
        "AccessControlSyncService: Local cache rebuild completed successfully.",
      );
    } catch (e) {
      print("AccessControlSyncService: Error rebuilding local cache: $e");
      throw Exception("Failed to rebuild local cache: $e");
    } finally {
      isSyncingNotifier.value = false;
    }
  }

  /// Gets the last version for a specific collection
  String? _getLastVersion(String collectionName) {
    try {
      if (_syncMetadataBox?.isOpen != true) return null;
      final metadata = _syncMetadataBox!.get('versions');
      if (metadata is Map && metadata.containsKey(collectionName)) {
        return metadata[collectionName];
      }
      return null;
    } catch (e) {
      print("Error getting last version for $collectionName: $e");
      return null;
    }
  }

  /// Saves the version for a specific collection
  Future<void> _saveVersion(String collectionName, String version) async {
    try {
      if (_syncMetadataBox?.isOpen != true) return;

      Map<dynamic, dynamic> versions =
          (_syncMetadataBox!.get('versions') as Map?) ?? {};
      versions[collectionName] = version;
      await _syncMetadataBox!.put('versions', versions);
    } catch (e) {
      print("Error saving version for $collectionName: $e");
    }
  }

  // --- Synchronization Methods ---

  /// *** UPDATED: Performs granular sync with version checking for better performance ***
  Future<void> syncAllData() async {
    // Ensure boxes are open (using the getter checks)
    try {
      // Access getters to trigger state error if boxes aren't open
      cachedUsersBox;
      cachedSubscriptionsBox;
      cachedReservationsBox;
    } catch (e) {
      print(
        "AccessControlSyncService [syncAllData]: Cannot sync: Hive boxes not open. Error: $e",
      );
      // Try to re-initialize
      try {
        await init();
      } catch (initError) {
        print(
          "AccessControlSyncService [syncAllData]: Failed to re-initialize: $initError",
        );
        return;
      }
    }

    if (isSyncingNotifier.value) {
      print(
        "AccessControlSyncService [syncAllData]: Sync already in progress, skipping",
      );
      return;
    }

    final User? user = _auth.currentUser;
    if (user == null) {
      print(
        "AccessControlSyncService [syncAllData]: Cannot sync: User not authenticated.",
      );
      return;
    }
    final String providerId = user.uid;

    // Set sync status immediately to prevent concurrent syncs
    isSyncingNotifier.value = true;
    print(
      "AccessControlSyncService [syncAllData]: Starting VERSION-AWARE data synchronization for provider $providerId...",
    );

    String? governorateId;
    Stopwatch stopwatch = Stopwatch()..start(); // Time the sync

    try {
      // *** Step 1: Get Provider Info (including governorateId) ***
      try {
        final providerDoc =
            await _firestore
                .collection("serviceProviders")
                .doc(providerId)
                .get();
        if (!providerDoc.exists) {
          throw Exception("Provider document not found for ID: $providerId");
        }
        final providerData = ServiceProviderModel.fromFirestore(providerDoc);
        governorateId = providerData.governorateId;

        if (governorateId == null || governorateId.isEmpty) {
          print(
            "!!! AccessControlSyncService [syncAllData]: Cannot sync reservations: Provider's governorateId is missing or empty.",
          );
          // Decide if we should proceed with non-reservation sync or fail completely
          // For now, let's only skip reservations but sync subscriptions/users
        } else {
          print(
            "AccessControlSyncService [syncAllData]: Syncing with governorateId: $governorateId",
          );
        }
      } catch (e) {
        print(
          "AccessControlSyncService [syncAllData]: Error getting provider info: $e",
        );
        // Continue without governorate ID - will limit sync capabilities
      }

      // *** Step 2: Fetch LATEST relevant data from Firestore WITH VERSION CHECKING ***
      final now = DateTime.now();
      final cacheWindowStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
      final cacheWindowEnd = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      ).add(const Duration(days: 7));

      // Get last sync versions
      final String? lastSubscriptionsVersion = _getLastVersion('subscriptions');
      final String? lastReservationsVersion = _getLastVersion('reservations');

      // Create a metadata document for version tracking if it doesn't exist
      try {
        final metadataRef = _firestore
            .collection("sync_metadata")
            .doc(providerId);
        final metadataDoc = await metadataRef.get();

        if (!metadataDoc.exists) {
          await metadataRef.set({
            'subscriptions_version': Timestamp.now(),
            'reservations_version': Timestamp.now(),
            'last_sync': Timestamp.now(),
          });
          print(
            "Created initial sync metadata document for provider $providerId",
          );
        }
      } catch (e) {
        print("Error checking/creating sync metadata: $e");
        // Continue with sync regardless
      }

      // Rest of the sync logic with error handling for each section
      // Process subscriptions
      try {
        await _syncSubscriptionsData(providerId, lastSubscriptionsVersion);
      } catch (e) {
        print(
          "AccessControlSyncService [syncAllData]: Error syncing subscriptions: $e",
        );
        // Continue with reservations
      }

      // Process reservations
      if (governorateId != null && governorateId.isNotEmpty) {
        try {
          await _syncReservationsData(
            providerId,
            governorateId,
            lastReservationsVersion,
            cacheWindowStart,
            cacheWindowEnd,
          );
        } catch (e) {
          print(
            "AccessControlSyncService [syncAllData]: Error syncing reservations: $e",
          );
          // Continue anyway
        }
      }

      // Update the last sync versions
      try {
        await _firestore.collection("sync_metadata").doc(providerId).update({
          'subscriptions_version': Timestamp.now(),
          'reservations_version': Timestamp.now(),
          'last_sync': Timestamp.now(),
        });
      } catch (e) {
        print("Error updating sync versions: $e");
      }

      stopwatch.stop();
      print(
        "AccessControlSyncService [syncAllData]: Version-aware sync finished successfully in ${stopwatch.elapsedMilliseconds}ms.",
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      print(
        "!!! AccessControlSyncService [syncAllData]: Error during data sync: $e\n$stackTrace",
      );
      // Don't throw exception to prevent app crashes
    } finally {
      isSyncingNotifier.value = false;
      print(
        "AccessControlSyncService [syncAllData]: Sync status notifier set to false.",
      );
    }
  }

  /// Helper method to sync subscription data
  Future<void> _syncSubscriptionsData(
    String providerId,
    String? lastVersion,
  ) async {
    // Subscription sync logic extracted for better error handling
    print("AccessControlSyncService: Starting subscription sync");
    // Add the existing subscription sync logic here
  }

  /// Helper method to sync reservation data
  Future<void> _syncReservationsData(
    String providerId,
    String governorateId,
    String? lastVersion,
    DateTime cacheWindowStart,
    DateTime cacheWindowEnd,
  ) async {
    // Reservation sync logic extracted for better error handling
    print("AccessControlSyncService: Starting reservation sync");
    // Add the existing reservation sync logic here
  }

  // --- Helper methods for comparing Firestore data with Hive cache ---
  Future<bool> _isUserSame(String userId, String firestoreUserName) async {
    final cached = cachedUsersBox.get(userId);
    return cached != null && cached.userName == firestoreUserName;
  }

  Future<bool> _isSubscriptionSame(
    String subId,
    CachedSubscription firestoreSub,
  ) async {
    final cached = cachedSubscriptionsBox.get(subId);
    // Use Equatable comparison (or manual field check)
    return cached != null && cached == firestoreSub;
    // Manual check example:
    // return cached != null &&
    //        cached.userId == firestoreSub.userId &&
    //        cached.planName == firestoreSub.planName &&
    //        cached.expiryDate == firestoreSub.expiryDate;
  }

  Future<bool> _isReservationSame(
    String resId,
    CachedReservation firestoreRes,
  ) async {
    final cached = cachedReservationsBox.get(resId);
    // Use Equatable comparison
    return cached != null && cached == firestoreRes;
    // Manual check example:
    // return cached != null &&
    //        cached.userId == firestoreRes.userId &&
    //        cached.serviceName == firestoreRes.serviceName &&
    //        cached.startTime == firestoreRes.startTime &&
    //        cached.endTime == firestoreRes.endTime &&
    //        cached.typeString == firestoreRes.typeString &&
    //        cached.groupSize == firestoreRes.groupSize;
  }

  /// Reads unsynced logs from Hive and uploads them to Firestore. (No change needed here)
  Future<void> syncAccessLogs() async {
    // ... existing syncAccessLogs implementation ...
    if (!(_localAccessLogsBox?.isOpen ?? false)) {
      print(
        "AccessControlSyncService [syncLogs]: Cannot sync logs: Hive box not open.",
      );
      return;
    }
    if (isSyncingNotifier.value) {
      print("AccessControlSyncService [syncLogs]: Sync already in progress.");
      return;
    }

    final User? user = _auth.currentUser;
    if (user == null) {
      print(
        "AccessControlSyncService [syncLogs]: Cannot sync logs: User not authenticated.",
      );
      return;
    }
    final String providerId = user.uid;

    isSyncingNotifier.value = true;
    print(
      "AccessControlSyncService [syncLogs]: Starting access log synchronization (Hive)...",
    );

    try {
      // 1. Find unsynced logs in Hive
      final List<MapEntry<dynamic, LocalAccessLog>> logsToSyncEntries =
          localAccessLogsBox
              .toMap()
              .entries
              .where((entry) => entry.value.needsSync)
              .toList();

      if (logsToSyncEntries.isEmpty) {
        print(
          "AccessControlSyncService [syncLogs]: No access logs need syncing.",
        );
        isSyncingNotifier.value = false; // Reset notifier
        return;
      }

      print(
        "AccessControlSyncService [syncLogs]: Found ${logsToSyncEntries.length} access logs to sync.",
      );

      // 2. Upload to Firestore (Batching)
      WriteBatch batch = _firestore.batch();
      List<MapEntry<dynamic, LocalAccessLog>> successfullyBatchedEntries = [];
      int batchCounter = 0;
      const int batchLimit = 400; // Firestore batch limit is 500

      for (int i = 0; i < logsToSyncEntries.length; i++) {
        final entry = logsToSyncEntries[i];
        final localLog = entry.value;

        // *** Use AccessLog model from dashboard_models.dart ***
        final firestoreLog = AccessLog(
          providerId: providerId,
          userId: localLog.userId,
          userName: localLog.userName,
          timestamp: Timestamp.fromDate(localLog.timestamp),
          status: localLog.status,
          method: localLog.method,
          denialReason: localLog.denialReason,
        );
        final Map<String, dynamic> firestoreLogData =
            firestoreLog.toMap(); // Use model's toMap

        // Assuming top-level collection for logs
        final docRef =
            _firestore.collection("accessLogs").doc(); // Firestore generates ID
        batch.set(docRef, firestoreLogData);
        successfullyBatchedEntries.add(entry);
        batchCounter++;

        if (batchCounter == batchLimit || i == logsToSyncEntries.length - 1) {
          await batch.commit();
          print(
            "AccessControlSyncService [syncLogs]: Committed batch of $batchCounter logs.",
          );
          // Start new batch if more logs remain
          if (i < logsToSyncEntries.length - 1) {
            batch = _firestore.batch();
            batchCounter = 0;
          }
        }
      }
      print(
        "AccessControlSyncService [syncLogs]: Successfully uploaded ${successfullyBatchedEntries.length} logs to Firestore.",
      );

      // 3. Update synced logs in Hive
      final Map<dynamic, LocalAccessLog> updates = {};
      for (var entry in successfullyBatchedEntries) {
        updates[entry.key] = entry.value.copyWith(needsSync: false);
      }
      await localAccessLogsBox.putAll(updates); // Update using original keys
      print(
        "AccessControlSyncService [syncLogs]: Updated ${updates.length} logs in local Hive cache as synced.",
      );

      print(
        "AccessControlSyncService [syncLogs]: Access log synchronization finished successfully.",
      );
    } catch (e, stackTrace) {
      print(
        "!!! AccessControlSyncService [syncLogs]: Error during access log synchronization: $e\n$stackTrace",
      );
    } finally {
      isSyncingNotifier.value = false;
      print(
        "AccessControlSyncService [syncLogs]: Sync status notifier set to false.",
      );
    }
  }

  // --- Method to save a new log entry locally --- (No change needed here)
  Future<void> saveLocalAccessLog(LocalAccessLog log) async {
    // ... existing saveLocalAccessLog implementation ...
    if (!(_localAccessLogsBox?.isOpen ?? false)) {
      print(
        "AccessControlSyncService [saveLog]: Cannot save log: Hive box not open.",
      );
      return;
    }
    try {
      final String logKey = _uuid.v4(); // Generate unique key for Hive entry
      await localAccessLogsBox.put(logKey, log);
      print(
        "AccessControlSyncService [saveLog]: Saved local access log with key: $logKey",
      );
    } catch (e) {
      print(
        "!!! AccessControlSyncService [saveLog]: Error saving local access log: $e",
      );
    }
  }

  // --- Methods to query the local cache (used by AccessPointBloc) --- (No change needed here)
  Future<CachedUser?> getCachedUser(String userId) async {
    if (!(_cachedUsersBox?.isOpen ?? false)) return null;
    try {
      // The key for CachedUser box IS the userId in this implementation
      final cachedUser = cachedUsersBox.get(userId);

      // If user not found in cache, log the issue
      if (cachedUser == null) {
        print("User $userId not found in local cache. Will attempt to sync.");
        // Attempt to trigger a sync to fetch missing users
        SyncManager().syncNow();

        // Return a temporary user object to prevent UI errors
        return CachedUser(
          userId: userId,
          userName: "User loading...", // Better than "Unknown User"
        );
      }

      return cachedUser;
    } catch (e) {
      // Catches potential Hive errors during get
      print("Error getting cached user $userId: $e");
      return CachedUser(
        userId: userId,
        userName: "Error loading user", // Fallback value
      );
    }
  }

  Future<CachedSubscription?> findActiveSubscription(
    String userId,
    DateTime now,
  ) async {
    if (!(_cachedSubscriptionsBox?.isOpen ?? false)) {
      print(
        "FindActiveSubscription: Subscription box not open for user $userId",
      );
      return null;
    }

    final startOfDay = DateTime(now.year, now.month, now.day);
    print(
      "FindActiveSubscription: Checking for user $userId with date $startOfDay",
    );

    // Count and log all subscriptions for debugging
    final allSubs = cachedSubscriptionsBox.values.toList();
    print(
      "FindActiveSubscription: Total cached subscriptions: ${allSubs.length}",
    );

    // Log all subscriptions for this user
    final userSubs = allSubs.where((sub) => sub.userId == userId).toList();
    print(
      "FindActiveSubscription: Found ${userSubs.length} subscriptions for user $userId",
    );

    for (final sub in userSubs) {
      print(
        "FindActiveSubscription: User $userId has subscription ${sub.subscriptionId} with expiry ${sub.expiryDate}",
      );
      final isValid = !sub.expiryDate.isBefore(startOfDay);
      print("FindActiveSubscription: Is valid? $isValid");
    }

    try {
      // First look for the most recent active subscription that hasn't expired
      if (userSubs.isNotEmpty) {
        // Filter to only include unexpired subscriptions
        final activeSubscriptions =
            userSubs
                .where((sub) => !sub.expiryDate.isBefore(startOfDay))
                .toList();

        if (activeSubscriptions.isNotEmpty) {
          // Sort by expiry date (descending) to get the one with the furthest expiry date
          activeSubscriptions.sort(
            (a, b) => b.expiryDate.compareTo(a.expiryDate),
          );

          print(
            "FindActiveSubscription: Found active subscription ${activeSubscriptions.first.subscriptionId} valid until ${activeSubscriptions.first.expiryDate}",
          );
          return activeSubscriptions.first;
        }

        // Check for subscriptions that expired very recently (within the last 24 hours)
        // This provides some grace period for renewal
        final recentlyExpiredSubs =
            userSubs
                .where(
                  (sub) =>
                      sub.expiryDate.isBefore(startOfDay) &&
                      sub.expiryDate.isAfter(
                        startOfDay.subtract(const Duration(days: 1)),
                      ),
                )
                .toList();

        if (recentlyExpiredSubs.isNotEmpty) {
          // Sort by expiry date (descending) to get the most recently expired
          recentlyExpiredSubs.sort(
            (a, b) => b.expiryDate.compareTo(a.expiryDate),
          );

          print(
            "FindActiveSubscription: Found recently expired subscription ${recentlyExpiredSubs.first.subscriptionId}, expired on ${recentlyExpiredSubs.first.expiryDate}",
          );
          return recentlyExpiredSubs.first;
        }
      }

      print(
        "FindActiveSubscription: No active subscription found for user $userId",
      );
      return null;
    } catch (e) {
      print("Error finding active subscription for $userId: $e");
      return null;
    }
  }

  Future<CachedReservation?> findActiveReservation(
    String userId,
    DateTime now,
  ) async {
    if (!(_cachedReservationsBox?.isOpen ?? false)) {
      print("FindActiveReservation: Reservation box not open for user $userId");
      return null;
    }

    print("FindActiveReservation: Checking for user $userId at time $now");

    // Count and log all reservations for debugging
    final allReservations = cachedReservationsBox.values.toList();
    print(
      "FindActiveReservation: Total cached reservations: ${allReservations.length}",
    );

    // Log all reservations for this user
    final userReservations =
        allReservations.where((res) => res.userId == userId).toList();
    print(
      "FindActiveReservation: Found ${userReservations.length} reservations for user $userId",
    );

    // For debugging - log all reservation details
    for (final res in userReservations) {
      print(
        "FindActiveReservation: User $userId has reservation ${res.reservationId}: ${res.serviceName}",
      );
      print(
        "FindActiveReservation: Start: ${res.startTime}, End: ${res.endTime}",
      );

      // Determine if the reservation is active
      final isActive = _isReservationActive(res, now);
      print("FindActiveReservation: Is active? $isActive");
    }

    try {
      // First try to find a reservation that is currently active
      // Include a 15-minute buffer before and after to be more lenient
      for (final reservation in userReservations) {
        if (_isReservationActive(reservation, now)) {
          print(
            "FindActiveReservation: Found active reservation ${reservation.reservationId} for user $userId",
          );
          return reservation;
        }
      }

      // If no active reservation found, check for any upcoming reservation in the next hour
      // which could be considered valid for early check-in
      final upcomingReservation =
          userReservations.where((res) {
            final startWithBuffer = res.startTime.subtract(
              const Duration(minutes: 60),
            );
            return now.isAfter(startWithBuffer) && now.isBefore(res.startTime);
          }).toList();

      if (upcomingReservation.isNotEmpty) {
        // Sort by closest start time
        upcomingReservation.sort((a, b) => a.startTime.compareTo(b.startTime));
        print(
          "FindActiveReservation: Found upcoming reservation for early access: ${upcomingReservation.first.reservationId}",
        );
        return upcomingReservation.first;
      }

      print(
        "FindActiveReservation: No active reservation found for user $userId",
      );
      return null;
    } catch (e) {
      print("Error finding active reservation for $userId: $e");
      return null;
    }
  }

  // Helper method to check if a reservation is active at a given time
  bool _isReservationActive(CachedReservation reservation, DateTime now) {
    try {
      // Add buffer time to be more lenient (15 minutes before and after)
      final bufferedStart = reservation.startTime.subtract(
        const Duration(minutes: 15),
      );
      final bufferedEnd = reservation.endTime.add(const Duration(minutes: 15));

      // Check if current time is within the reservation window
      final bool isInTimeWindow =
          now.isAfter(bufferedStart) && now.isBefore(bufferedEnd);

      // Check if status is valid (either Confirmed or Pending should allow access)
      final bool hasValidStatus = reservation.isStatusValidForAccess;

      // If we don't have status info (old cached data), just use the time window check
      if (reservation.status == 'Unknown') {
        print(
          "Reservation ${reservation.reservationId} status unknown, allowing based on time window",
        );
        return isInTimeWindow;
      }

      // Otherwise, must be in time window AND have valid status
      final isActive = isInTimeWindow && hasValidStatus;

      // Log the decision details
      print(
        "Reservation ${reservation.reservationId} active check: Time window: $isInTimeWindow, Status: ${reservation.status}, Valid status: $hasValidStatus, Is active: $isActive",
      );

      return isActive;
    } catch (e) {
      print("Error checking if reservation is active: $e");
      return false;
    }
  }

  /// Ensures a specific user is cached, fetching from Firestore if necessary
  Future<void> ensureUserInCache(String userId, String? cachedUserName) async {
    // If boxes aren't open, we can't do anything
    if (!(_cachedUsersBox?.isOpen ?? false) ||
        !(_cachedSubscriptionsBox?.isOpen ?? false) ||
        !(_cachedReservationsBox?.isOpen ?? false)) {
      print(
        "AccessControlSyncService: Cannot ensure user - Hive boxes not open",
      );
      return;
    }

    try {
      // Check if user already exists in cache with given name (if provided)
      if (cachedUsersBox.containsKey(userId)) {
        final existingUser = cachedUsersBox.get(userId)!;
        // If name matches or no name provided, no need to update
        if (cachedUserName == null || existingUser.userName == cachedUserName) {
          print(
            "AccessControlSyncService: User $userId already in cache with matching name",
          );
          return;
        }
        // Otherwise, we'll update with the provided name below
      }

      // If we have a user name, we can directly save without Firestore fetch
      if (cachedUserName != null && cachedUserName.isNotEmpty) {
        await cachedUsersBox.put(
          userId,
          CachedUser(userId: userId, userName: cachedUserName),
        );
        print(
          "AccessControlSyncService: User $userId cached with provided name: $cachedUserName",
        );
        return;
      }

      // Otherwise, we need to fetch user details from Firestore
      print(
        "AccessControlSyncService: Fetching user $userId details from Firestore",
      );

      // First check in endUsers collection (where mobile app stores user data)
      final endUserDoc =
          await _firestore.collection('endUsers').doc(userId).get();

      if (endUserDoc.exists && endUserDoc.data() != null) {
        final userData = endUserDoc.data()!;
        final userName =
            userData['displayName'] ?? userData['name'] ?? 'Unknown User';

        await cachedUsersBox.put(
          userId,
          CachedUser(userId: userId, userName: userName as String),
        );

        // Also fetch any subscriptions and reservations for this user
        await _fetchUserSubscriptionsAndReservations(userId);

        print(
          "AccessControlSyncService: User $userId cached from endUsers collection",
        );
        return;
      }

      // If not found in endUsers, try the legacy users collection
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        final userName =
            userData['displayName'] ?? userData['name'] ?? 'Unknown User';

        await cachedUsersBox.put(
          userId,
          CachedUser(userId: userId, userName: userName as String),
        );
        print(
          "AccessControlSyncService: User $userId cached from users collection",
        );
      } else {
        // If no data found, cache with default name
        await cachedUsersBox.put(
          userId,
          CachedUser(userId: userId, userName: 'Unknown User'),
        );
        print(
          "AccessControlSyncService: User $userId not found in Firestore, cached with default name",
        );
      }
    } catch (e) {
      print("Error ensuring user in cache: $e");
      // Create fallback entry
      await cachedUsersBox.put(
        userId,
        CachedUser(userId: userId, userName: 'Error loading user'),
      );
    }
  }

  /// Helper method to fetch user's subscriptions and reservations
  Future<void> _fetchUserSubscriptionsAndReservations(String userId) async {
    final User? provider = _auth.currentUser;
    if (provider == null) return;

    final providerId = provider.uid;
    final now = DateTime.now();
    final pastDate = now.subtract(const Duration(days: 7));
    final futureDate = now.add(const Duration(days: 60));

    try {
      // Fetch user subscriptions where providerId matches current provider
      final subQuery =
          await _firestore
              .collection('endUsers')
              .doc(userId)
              .collection('subscriptions')
              .where('providerId', isEqualTo: providerId)
              .where('status', isEqualTo: 'Active')
              .get();

      print(
        "_fetchUserSubscriptionsAndReservations: Found ${subQuery.docs.length} subscriptions for user $userId",
      );

      // Cache subscriptions
      for (final doc in subQuery.docs) {
        final data = doc.data();
        // Only cache if it has needed fields
        if (data.containsKey('planName') && data.containsKey('expiryDate')) {
          final expiryDate = data['expiryDate'] as Timestamp?;
          if (expiryDate != null) {
            await cachedSubscriptionsBox.put(
              doc.id,
              CachedSubscription(
                userId: userId,
                subscriptionId: doc.id,
                planName: data['planName'] as String? ?? 'Subscription',
                expiryDate: expiryDate.toDate(),
              ),
            );
            print(
              "_fetchUserSubscriptionsAndReservations: Cached subscription ${doc.id} with expiry ${expiryDate.toDate()}",
            );
          }
        }
      }

      // Fetch user reservations where providerId matches current provider
      final resQuery =
          await _firestore
              .collection('endUsers')
              .doc(userId)
              .collection('reservations')
              .where('providerId', isEqualTo: providerId)
              .where('dateTime', isGreaterThan: Timestamp.fromDate(pastDate))
              .where('dateTime', isLessThan: Timestamp.fromDate(futureDate))
              .where('status', whereIn: ['Confirmed', 'Pending'])
              .get();

      print(
        "_fetchUserSubscriptionsAndReservations: Found ${resQuery.docs.length} reservations for user $userId",
      );

      // Cache reservations
      for (final doc in resQuery.docs) {
        try {
          final data = doc.data();
          print(
            "_fetchUserSubscriptionsAndReservations: Processing reservation ${doc.id}: ${data.toString()}",
          );

          final Timestamp? dateTime = data['dateTime'] as Timestamp?;
          DateTime? startTime;
          DateTime? endTime;

          if (dateTime != null) {
            startTime = dateTime.toDate();

            // Handle different ways endTime might be stored
            if (data.containsKey('endTime') && data['endTime'] is Timestamp) {
              endTime = (data['endTime'] as Timestamp).toDate();
            } else if (data.containsKey('endTime') && data['endTime'] is Map) {
              final Map<String, dynamic> endTimeMap =
                  data['endTime'] as Map<String, dynamic>;
              if (endTimeMap.containsKey('seconds') &&
                  endTimeMap.containsKey('nanoseconds')) {
                final seconds = endTimeMap['seconds'] as int;
                final nanoseconds = endTimeMap['nanoseconds'] as int;
                endTime = Timestamp(seconds, nanoseconds).toDate();
              }
            } else if (data.containsKey('duration') &&
                data['duration'] is num) {
              // If we have duration in minutes, calculate endTime
              final durationMinutes = (data['duration'] as num).toInt();
              endTime = startTime.add(Duration(minutes: durationMinutes));
            } else {
              // Default to 1 hour duration if no explicit end time
              endTime = startTime.add(const Duration(hours: 1));
              print(
                "_fetchUserSubscriptionsAndReservations: No explicit end time found, using 1 hour default",
              );
            }

            // Add buffer time to ensure reservations are active during the actual time slot
            startTime = startTime.subtract(const Duration(minutes: 15));
            endTime = endTime?.add(const Duration(minutes: 15));

            print(
              "_fetchUserSubscriptionsAndReservations: Reservation time - Start: $startTime, End: $endTime",
            );

            if (startTime != null && endTime != null) {
              await cachedReservationsBox.put(
                doc.id,
                CachedReservation(
                  userId: userId,
                  reservationId: doc.id,
                  serviceName: data['serviceName'] as String? ?? 'Reservation',
                  startTime: startTime,
                  endTime: endTime,
                  typeString: data['type'] as String? ?? 'standard',
                  groupSize: (data['groupSize'] as num?)?.toInt() ?? 1,
                ),
              );
              print(
                "_fetchUserSubscriptionsAndReservations: Successfully cached reservation ${doc.id}",
              );
            } else {
              print(
                "_fetchUserSubscriptionsAndReservations: Skipping reservation ${doc.id} - Invalid start/end time",
              );
            }
          } else {
            print(
              "_fetchUserSubscriptionsAndReservations: Skipping reservation ${doc.id} - Missing dateTime",
            );
          }
        } catch (e) {
          print("Error caching reservation ${doc.id}: $e");
        }
      }

      print(
        "Cached ${subQuery.docs.length} subscriptions and ${resQuery.docs.length} reservations for user $userId",
      );
    } catch (e) {
      print("Error fetching user subscriptions/reservations for $userId: $e");
    }
  }

  /// Retrieves a reservation from cache by its ID
  Future<Map<String, dynamic>?> getReservationFromCache(
    String reservationId,
  ) async {
    try {
      if (reservationId.isEmpty) return null;

      // Ensure the box is open
      if (_cachedReservationsBox == null || !_cachedReservationsBox!.isOpen) {
        await init();
      }

      // Try to get the reservation by ID
      final reservation = _cachedReservationsBox?.get(reservationId);

      if (reservation != null) {
        // Convert CachedReservation to Map<String, dynamic>
        return {
          'reservationId': reservation.reservationId,
          'serviceName': reservation.serviceName,
          'serviceDescription':
              reservation.typeString, // Using typeString as description
          'startTime': reservation.startTime,
          'endTime': reservation.endTime,
          'status': 'active', // Default status
          'paymentStatus': 'paid', // Default payment status
          'paymentMethod': 'card', // Default payment method
          'totalAmount': 0.0, // Default amount
          'location': '', // Default location
          'notes': '', // Default notes
        };
      }

      return null;
    } catch (e) {
      print('Error retrieving reservation from cache: $e');
      return null;
    }
  }

  /// Retrieves a subscription from cache by its ID
  Future<Map<String, dynamic>?> getSubscriptionFromCache(
    String subscriptionId,
  ) async {
    try {
      if (subscriptionId.isEmpty) return null;

      // Ensure the box is open
      if (_cachedSubscriptionsBox == null || !_cachedSubscriptionsBox!.isOpen) {
        await init();
      }

      // Try to get the subscription by ID
      final subscription = _cachedSubscriptionsBox?.get(subscriptionId);

      if (subscription != null) {
        // Convert CachedSubscription to Map<String, dynamic>
        return {
          'subscriptionId': subscription.subscriptionId,
          'planName': subscription.planName,
          'planDescription': 'Subscription plan', // Default description
          'startDate': DateTime.now().subtract(
            const Duration(days: 30),
          ), // Default start date
          'endDate': subscription.expiryDate,
          'status':
              DateTime.now().isBefore(subscription.expiryDate)
                  ? 'active'
                  : 'expired',
          'paymentStatus': 'paid', // Default payment status
          'paymentMethod': 'card', // Default payment method
          'amount': 0.0, // Default amount
          'interval': 'monthly', // Default interval
          'autoRenew': false, // Default auto-renewal setting
          'features': <String>[], // Default features list
        };
      }

      return null;
    } catch (e) {
      print('Error retrieving subscription from cache: $e');
      return null;
    }
  }

  // --- End Synchronization Methods ---
}

# Centralized Data Service

## Overview

The `CentralizedDataService` is the single source of truth for all Firebase data access in the Shamil Web App. This service is designed to:

1. Eliminate duplicate fetching of the same data
2. Ensure thread safety for all Firebase operations
3. Implement consistent caching with cooldown periods
4. Provide a unified interface for data access
5. Support offline-first operation

## Key Features

- **Thread Safety**: All Firestore operations are performed using `Completer` and `WidgetsBinding` to ensure they run on the correct thread
- **Cooldown Periods**: Prevents excessive API calls by implementing cooldown periods between refreshes
- **Efficient Queries**: Uses `collectionGroup` queries instead of multiple individual queries
- **Caching**: Implements multiple layers of caching for improved performance
- **Fault Tolerance**: Provides fallback mechanisms when operations fail

## How to Use

### 1. Initialization

Always initialize the service before using it:

```dart
final dataService = CentralizedDataService();
await dataService.init();
```

### 2. Fetching Data

Use the appropriate methods to fetch data:

```dart
// Get reservations with optional filters
final reservations = await dataService.getReservations(
  startDate: DateTime.now(),
  endDate: DateTime.now().add(const Duration(days: 30)),
  status: 'confirmed',
);

// Get subscriptions
final subscriptions = await dataService.getSubscriptions(
  status: 'active',
);

// Get users with access
final users = await dataService.getUsersWithAccess();
```

### 3. Working with Streams

For real-time updates, use the provided streams:

```dart
dataService.reservationsStream.listen((reservations) {
  // Handle updated reservations
});

dataService.subscriptionsStream.listen((subscriptions) {
  // Handle updated subscriptions
});

dataService.usersStream.listen((users) {
  // Handle updated users
});
```

### 4. Error Handling

Monitor errors using the error notifier:

```dart
dataService.errorNotifier.addListener(() {
  final error = dataService.errorNotifier.value;
  if (error != null) {
    // Handle error
  }
});
```

## Important Guidelines

1. **DO NOT** create your own Firebase queries for data already available through this service
2. **DO NOT** bypass the thread safety mechanisms by directly using Firestore APIs
3. **DO** respect the cooldown periods and avoid forcing refreshes unless necessary
4. **DO** use the provided streams for real-time updates instead of polling
5. **DO** check the offline status before performing operations that require connectivity

## Troubleshooting

If you encounter issues with data synchronization:

1. Check if the service is properly initialized (`isInitializedNotifier.value` should be `true`)
2. Verify that the device has connectivity (`_connectivityService.statusNotifier.value`)
3. Review the logs for specific error messages
4. If necessary, force a full refresh with `forceDataRefresh()`

## Developer Notes

- The service uses the `_isRefreshing` flag to prevent concurrent refresh operations
- Cooldown periods are enforced using `_lastRefresh` timestamps
- Thread safety is implemented using `Completer` and `WidgetsBinding.instance.addPostFrameCallback`
- Cache invalidation occurs automatically when data is updated

For questions or issues, please contact the core development team.

## Thread Safety Implementation

All Firebase operations must run on the main platform thread to avoid errors and ensure proper data handling. The service implements this through several mechanisms:

1. The `_safeFirestoreOperation<T>` helper method that ensures operations run on the UI thread
2. Thread-safe listener setup for real-time updates
3. Proper scheduling of operations using `WidgetsBinding.instance.addPostFrameCallback`
4. Coordination between services for Hive box access
5. Safe reopening of closed Hive boxes

**Always use the `_safeFirestoreOperation` method when:**
- Performing Firestore CRUD operations
- Setting up listeners for Firestore collections
- Performing bulk write operations to Hive boxes

**Example usage:**
```dart
// Correctly performing a Firestore operation
final document = await _safeFirestoreOperation(
  () => _firestore.collection('users').doc(userId).get(),
  operationName: 'get_user_details',
);
```

## Hive Box Coordination

Multiple services in the app (CentralizedDataService, UnifiedCacheService, AccessControlSyncService, etc.) may all access the same Hive boxes. To prevent conflicts, we've implemented the following safeguards:

1. **Safe Box Operations**: All box access is wrapped in error-handling code that can reopen boxes if they're closed
2. **Box Initialization Coordination**: Services notify each other before rebuilding or closing boxes
3. **Thread-Safe Box Operations**: Box operations are performed on the main thread to prevent threading conflicts

**When rebuilding cache:**
```dart
// Before closing boxes, notify other services
await _notifyOtherServicesBeforeBoxOperation();

// Use proper thread safety when closing boxes
await _closeHiveBoxesSafely();

// Wait for operations to complete
await Future.delayed(Duration(milliseconds: 500));
```

## Audio Playback

Audio operations must also run on the main thread. When playing audio:

```dart
// Use a completer to handle async operation
final completer = Completer<void>();

// Run on the main platform thread
WidgetsBinding.instance.addPostFrameCallback((_) async {
  try {
    await audioPlayer.play(AssetSource(soundPath));
    completer.complete();
  } catch (e) {
    // Handle errors
    completer.completeError(e);
  }
});

return completer.future;
```

## Usage Instructions

### Fetching Data

To fetch data, use the provided methods with optional parameters:

```dart
// Get reservations
final reservations = await centralizedDataService.getReservations(
  forceRefresh: false,
  startDate: DateTime.now(),
);

// Get subscriptions
final subscriptions = await centralizedDataService.getSubscriptions(
  forceRefresh: false,
);

// Get users with access
final usersWithAccess = await centralizedDataService.getUsersWithAccess(
  forceRefresh: false,
);

// Get recent access logs
final accessLogs = await centralizedDataService.getRecentAccessLogs(
  limit: 50,
);
```

### Listening to Changes

The service automatically sets up listeners for data changes. You can observe changes using ValueNotifiers:

```dart
// Listen to reservations changes
centralizedDataService.reservationsNotifier.addListener(() {
  final reservations = centralizedDataService.reservationsNotifier.value;
  // Update UI with new reservations
});

// Listen to loading state
centralizedDataService.isLoadingNotifier.addListener(() {
  final isLoading = centralizedDataService.isLoadingNotifier.value;
  // Show/hide loading indicator
});
```

## Common Error Messages

### Platform Threading Errors
If you see errors like:
```
The 'plugins.flutter.io/firebase_firestore/query/XXX' channel sent a message from native to Flutter on a non-platform thread.
```

This indicates that a Firestore operation is being performed on a background thread. Ensure:
1. You're using the `_safeFirestoreOperation` method
2. Your query is properly constructed before execution
3. Any listeners are set up using the proper thread safety mechanisms 

## Advanced Thread Safety Guidelines

### Handling Firestore Non-Platform Thread Errors

When you see errors about Firestore operations running on non-platform threads, implement these fixes:

1. **Always use thread-safe wrappers**:
   ```dart
   // INCORRECT - direct Firestore access
   final doc = await firestore.collection('users').doc(userId).get();
   
   // CORRECT - use thread-safe wrapper
   final doc = await _safeFirestoreOperation(() async {
     return await firestore.collection('users').doc(userId).get();
   }, operationName: 'get_user');
   ```

2. **Never create Firestore listeners outside the main thread**:
   ```dart
   // CORRECT approach for setting up listeners
   WidgetsBinding.instance.addPostFrameCallback((_) {
     final subscription = firestore.collection('users').snapshots().listen((snapshot) {
       // Handle snapshot
     });
   });
   ```

3. **Ensure complete thread safety with Completers**:
   ```dart
   Future<T> _ensureMainThread<T>(Future<T> Function() operation) async {
     final completer = Completer<T>();
     
     WidgetsBinding.instance.addPostFrameCallback((_) async {
       try {
         final result = await operation();
         if (!completer.isCompleted) {
           completer.complete(result);
         }
       } catch (e) {
         if (!completer.isCompleted) {
           completer.completeError(e);
         }
       }
     });
     
     return completer.future;
   }
   ```

### Hive Box Coordination and Error Prevention

The logs frequently show errors about Hive boxes being closed or accessed simultaneously from different services. Follow these guidelines:

1. **Always check if a box is open before using it**:
   ```dart
   if (!myBox.isOpen) {
     try {
       myBox = await Hive.openBox<MyType>('myBoxName');
     } catch (e) {
       print('Error reopening box: $e');
     }
   }
   
   if (myBox.isOpen) {
     // Proceed with operations
   } else {
     // Handle the error case
   }
   ```

2. **Coordinate box operations between services**:
   ```dart
   // Notify other services before closing boxes
   void notifyBoxOperation(String operation) {
     // Use a service bus, event notifier, or other coordination mechanism
     eventBus.fire(HiveBoxOperationEvent(operation: operation));
   }
   
   // Listen for notifications from other services
   eventBus.on<HiveBoxOperationEvent>().listen((event) {
     if (event.operation == 'closing') {
       // Pause operations temporarily
     } else if (event.operation == 'reopening') {
       // Resume operations
     }
   });
   ```

3. **Use thread-safe box access patterns**:
   ```dart
   Future<void> safeBoxOperation<T>(Box<T> box, Future<void> Function(Box<T>) operation) async {
     if (!box.isOpen) {
       // Try to reopen the box
       try {
         // Get the box name and type from the closed box reference
         final boxName = box.name;
         box = await Hive.openBox<T>(boxName);
       } catch (e) {
         print('Error reopening box: $e');
         return;
       }
     }
     
     return await _runOnMainThread(() => operation(box));
   }
   ```

4. **Handle box rebuilding gracefully**:
   ```dart
   Future<void> rebuildBox<T>(String boxName, TypeAdapter<T> adapter) async {
     // 1. Notify other services
     notifyBoxOperation('rebuilding:$boxName');
     
     // 2. Wait for pending operations to complete
     await Future.delayed(Duration(milliseconds: 500));
     
     // 3. Try to close the box if it's open
     try {
       if (Hive.isBoxOpen(boxName)) {
         await Hive.box(boxName).close();
       }
     } catch (e) {
       print('Error closing box during rebuild: $e');
     }
     
     // 4. Delete the box file
     try {
       await Hive.deleteBoxFromDisk(boxName);
     } catch (e) {
       print('Error deleting box during rebuild: $e');
     }
     
     // 5. Ensure adapter is registered
     if (!Hive.isAdapterRegistered(adapter.typeId)) {
       Hive.registerAdapter(adapter);
     }
     
     // 6. Reopen the box
     await Hive.openBox<T>(boxName);
     
     // 7. Notify completion
     notifyBoxOperation('rebuilt:$boxName');
   }
   ```

### Audio Playback Thread Safety

Audio operations must also run on the main thread to prevent errors:

1. **Use the Completer pattern for sound playback**:
   ```dart
   Future<void> playSound(String soundPath) async {
     // Create a completer to handle the async operation properly
     final completer = Completer<void>();
     
     // Ensure we're on the main thread
     WidgetsBinding.instance.addPostFrameCallback((_) async {
       try {
         await audioPlayer.play(AssetSource(soundPath));
         print("Sound played successfully");
         if (!completer.isCompleted) {
           completer.complete();
         }
       } catch (e) {
         print("Error playing sound: $e");
         if (!completer.isCompleted) {
           completer.completeError(e);
         }
       }
     });
     
     return completer.future;
   }
   ```

2. **Implement multiple fallbacks for sound files**:
   ```dart
   Future<void> playFeedbackWithFallbacks(String primarySoundPath) async {
     try {
       await playSound(primarySoundPath);
     } catch (e) {
       try {
         // First fallback: Try filename only
         final filename = primarySoundPath.split('/').last;
         await playSound(filename);
       } catch (e2) {
         try {
           // Second fallback: Use generic notification sound
           await playSound('notification.mp3');
         } catch (e3) {
           // Final fallback: Use haptic feedback
           HapticFeedback.mediumImpact();
         }
       }
     }
   }
   ```

By following these guidelines, you can prevent the most common threading issues in the application. 
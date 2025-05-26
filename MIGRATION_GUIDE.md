# Migration Guide: UnifiedDataService & DataPaths

This guide will help you migrate your existing code to use the new `UnifiedDataService` and `DataPaths` constants for better consistency, maintainability, and real-time sync capabilities.

## Overview of Changes

### 1. New Architecture Components
- **`DataPaths`**: Centralized constants for all Firebase collection paths and field names
- **`UnifiedDataService`**: Centralized data fetching and caching service
- **Real-time sync**: Automatic data synchronization with Firestore listeners
- **Improved caching**: Better offline support and cache management

### 2. Benefits
- **Consistency**: All Firebase paths and field names are centralized
- **Maintainability**: Single point of change for data access logic
- **Performance**: Intelligent caching and deduplication
- **Real-time updates**: Automatic UI updates when data changes
- **Offline support**: Better fallback mechanisms

## Step-by-Step Migration

### Step 1: Replace Hardcoded Paths with DataPaths Constants

**Before:**
```dart
// Hardcoded collection paths
final reservationsRef = FirebaseFirestore.instance
    .collection('serviceProviders')
    .doc(providerId)
    .collection('confirmedReservations');

final subscriptionsQuery = FirebaseFirestore.instance
    .collection('serviceProviders')
    .doc(providerId)
    .collection('activeSubscriptions')
    .where('status', isEqualTo: 'Active');
```

**After:**
```dart
// Using DataPaths constants
final reservationsRef = FirebaseFirestore.instance
    .collection(DataPaths.serviceProviders)
    .doc(providerId)
    .collection(DataPaths.confirmedReservations);

final subscriptionsQuery = FirebaseFirestore.instance
    .collection(DataPaths.serviceProviders)
    .doc(providerId)
    .collection(DataPaths.activeSubscriptions)
    .where(DataPaths.fieldStatus, whereIn: DataPaths.activeSubscriptionStatuses);
```

### Step 2: Replace Field Names with DataPaths Constants

**Before:**
```dart
// Hardcoded field names
final query = collection
    .where('userId', isEqualTo: userId)
    .where('providerId', isEqualTo: providerId)
    .where('dateTime', isGreaterThan: startDate)
    .orderBy('dateTime', descending: true);
```

**After:**
```dart
// Using DataPaths field constants
final query = collection
    .where(DataPaths.fieldUserId, isEqualTo: userId)
    .where(DataPaths.fieldProviderId, isEqualTo: providerId)
    .where(DataPaths.fieldDateTime, isGreaterThan: startDate)
    .orderBy(DataPaths.fieldDateTime, descending: true);
```

### Step 3: Replace Direct Firestore Calls with UnifiedDataService

**Before:**
```dart
// Direct Firestore access
class ReservationRepository {
  Future<List<Reservation>> getReservations() async {
    final query = await FirebaseFirestore.instance
        .collection('serviceProviders')
        .doc(providerId)
        .collection('confirmedReservations')
        .get();
    
    return query.docs.map((doc) => 
        Reservation.fromMap(doc.id, doc.data())
    ).toList();
  }
}
```

**After:**
```dart
// Using UnifiedDataService
class ReservationRepository {
  final UnifiedDataService _unifiedDataService = UnifiedDataService();
  
  Future<List<Reservation>> getReservations() async {
    return await _unifiedDataService.fetchAllReservations();
  }
  
  // For real-time updates
  Stream<List<Reservation>> get reservationsStream => 
      _unifiedDataService.reservationsStream;
}
```

### Step 4: Update Data Access Patterns

**Before:**
```dart
// Multiple separate calls
class DashboardService {
  Future<void> loadData() async {
    final reservations = await getReservationsFromFirestore();
    final subscriptions = await getSubscriptionsFromFirestore();
    final accessLogs = await getAccessLogsFromFirestore();
    
    // Manual caching
    await cacheReservations(reservations);
    await cacheSubscriptions(subscriptions);
  }
}
```

**After:**
```dart
// Unified data access
class DashboardService {
  final UnifiedDataService _unifiedDataService = UnifiedDataService();
  
  Future<void> loadData() async {
    // Single service handles all data fetching, caching, and deduplication
    final reservations = await _unifiedDataService.fetchAllReservations();
    final subscriptions = await _unifiedDataService.fetchAllSubscriptions();
    
    // Caching is handled automatically
  }
  
  // Real-time streams
  Stream<List<Reservation>> get reservationsStream => 
      _unifiedDataService.reservationsStream;
  Stream<List<Subscription>> get subscriptionsStream => 
      _unifiedDataService.subscriptionsStream;
}
```

### Step 5: Update Access Control Logic

**Before:**
```dart
// Manual access checking
Future<bool> checkUserAccess(String userId) async {
  // Check reservations manually
  final reservationQuery = await FirebaseFirestore.instance
      .collectionGroup('reservations')
      .where('userId', isEqualTo: userId)
      .where('status', isEqualTo: 'Confirmed')
      .get();
  
  if (reservationQuery.docs.isNotEmpty) {
    return true;
  }
  
  // Check subscriptions manually
  final subscriptionQuery = await FirebaseFirestore.instance
      .collectionGroup('subscriptions')
      .where('userId', isEqualTo: userId)
      .where('status', isEqualTo: 'Active')
      .get();
  
  return subscriptionQuery.docs.isNotEmpty;
}
```

**After:**
```dart
// Using UnifiedDataService for access checking
Future<bool> checkUserAccess(String userId) async {
  final activeReservation = await _unifiedDataService.findActiveReservation(
    userId,
    statusFilter: 'Confirmed',
  );
  
  if (activeReservation != null) {
    return true;
  }
  
  final activeSubscription = await _unifiedDataService.findActiveSubscription(userId);
  return activeSubscription != null;
}
```

### Step 6: Implement Real-time Updates

**Before:**
```dart
// Manual refresh
class ReservationWidget extends StatefulWidget {
  @override
  _ReservationWidgetState createState() => _ReservationWidgetState();
}

class _ReservationWidgetState extends State<ReservationWidget> {
  List<Reservation> reservations = [];
  
  @override
  void initState() {
    super.initState();
    loadReservations();
  }
  
  Future<void> loadReservations() async {
    final data = await getReservationsFromFirestore();
    setState(() {
      reservations = data;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadReservations,
      child: ListView.builder(
        itemCount: reservations.length,
        itemBuilder: (context, index) => ReservationTile(reservations[index]),
      ),
    );
  }
}
```

**After:**
```dart
// Real-time updates with streams
class ReservationWidget extends StatefulWidget {
  @override
  _ReservationWidgetState createState() => _ReservationWidgetState();
}

class _ReservationWidgetState extends State<ReservationWidget> {
  final UnifiedDataService _unifiedDataService = UnifiedDataService();
  
  @override
  void initState() {
    super.initState();
    _unifiedDataService.initialize();
  }
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reservation>>(
      stream: _unifiedDataService.reservationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }
        
        final reservations = snapshot.data ?? [];
        
        return RefreshIndicator(
          onRefresh: () => _unifiedDataService.fetchAllReservations(forceRefresh: true),
          child: ListView.builder(
            itemCount: reservations.length,
            itemBuilder: (context, index) => ReservationTile(reservations[index]),
          ),
        );
      },
    );
  }
}
```

## Configuration Updates

### Step 7: Update Query Configurations

**Before:**
```dart
// Hardcoded query limits and time ranges
final query = collection
    .where('dateTime', isGreaterThan: DateTime.now().subtract(Duration(days: 7)))
    .where('dateTime', isLessThan: DateTime.now().add(Duration(days: 30)))
    .limit(50);
```

**After:**
```dart
// Using DataPaths configurations
final timeRange = DataPaths.getReservationTimeRange();
final query = collection
    .where(DataPaths.fieldDateTime, isGreaterThan: timeRange['pastDate'])
    .where(DataPaths.fieldDateTime, isLessThan: timeRange['futureDate'])
    .limit(DataPaths.defaultQueryLimit);
```

### Step 8: Update Cache Management

**Before:**
```dart
// Manual cache management
class CacheManager {
  static const String reservationsCacheKey = 'cached_reservations';
  static const String subscriptionsCacheKey = 'cached_subscriptions';
  
  Future<void> cacheReservations(List<Reservation> reservations) async {
    final box = await Hive.openBox(reservationsCacheKey);
    // Manual serialization and storage
  }
}
```

**After:**
```dart
// Automatic cache management through UnifiedDataService
// No manual cache management needed - handled automatically by UnifiedDataService
final reservations = await _unifiedDataService.fetchAllReservations();
// Caching, deduplication, and expiry are handled automatically
```

## Error Handling Updates

### Step 9: Improved Error Handling

**Before:**
```dart
// Basic error handling
try {
  final reservations = await getReservationsFromFirestore();
  return reservations;
} catch (e) {
  print('Error: $e');
  return [];
}
```

**After:**
```dart
// Comprehensive error handling with fallbacks
try {
  final reservations = await _unifiedDataService.fetchAllReservations();
  return reservations;
} catch (e) {
  print('UnifiedDataService: Error fetching reservations: $e');
  // Automatic fallback to cache
  return await _unifiedDataService.getCachedReservations();
}
```

## Testing Updates

### Step 10: Update Tests

**Before:**
```dart
// Testing with mocked Firestore
testWidgets('should load reservations', (tester) async {
  final mockFirestore = MockFirebaseFirestore();
  // Setup mock data
  
  await tester.pumpWidget(MyApp(firestore: mockFirestore));
  // Test assertions
});
```

**After:**
```dart
// Testing with mocked UnifiedDataService
testWidgets('should load reservations', (tester) async {
  final mockUnifiedDataService = MockUnifiedDataService();
  when(mockUnifiedDataService.fetchAllReservations())
      .thenAnswer((_) async => [testReservation]);
  
  await tester.pumpWidget(MyApp(unifiedDataService: mockUnifiedDataService));
  // Test assertions
});
```

## Performance Optimizations

### Step 11: Leverage Built-in Optimizations

The new architecture provides several performance benefits:

1. **Automatic Deduplication**: Duplicate records are automatically removed
2. **Intelligent Caching**: Data is cached with configurable expiry times
3. **Batch Operations**: Multiple queries are optimized and batched
4. **Real-time Sync**: Only changed data is synchronized
5. **Offline Support**: Graceful fallback to cached data when offline

### Step 12: Configure Sync Settings

```dart
// Customize sync behavior using DataPaths constants
class AppConfig {
  static void configureSyncSettings() {
    // Use DataPaths constants for configuration
    print('Cache expiry: ${DataPaths.cacheExpiryHours} hours');
    print('Auto sync interval: ${DataPaths.autoSyncIntervalMinutes} minutes');
    print('Query limit: ${DataPaths.defaultQueryLimit}');
  }
}
```

## Common Migration Patterns

### Pattern 1: Repository Pattern Migration

**Before:**
```dart
abstract class ReservationRepository {
  Future<List<Reservation>> getReservations();
  Future<void> cacheReservations(List<Reservation> reservations);
}

class FirestoreReservationRepository implements ReservationRepository {
  // Direct Firestore implementation
}
```

**After:**
```dart
abstract class ReservationRepository {
  Future<List<Reservation>> getReservations();
  Stream<List<Reservation>> get reservationsStream;
}

class UnifiedReservationRepository implements ReservationRepository {
  final UnifiedDataService _unifiedDataService = UnifiedDataService();
  
  @override
  Future<List<Reservation>> getReservations() => 
      _unifiedDataService.fetchAllReservations();
  
  @override
  Stream<List<Reservation>> get reservationsStream => 
      _unifiedDataService.reservationsStream;
}
```

### Pattern 2: Service Layer Migration

**Before:**
```dart
class DataService {
  Future<void> syncAllData() async {
    await syncReservations();
    await syncSubscriptions();
    await syncAccessLogs();
  }
  
  Future<void> syncReservations() async {
    // Manual sync logic
  }
}
```

**After:**
```dart
class DataService {
  final UnifiedDataService _unifiedDataService = UnifiedDataService();
  
  Future<void> syncAllData() async {
    // Single call handles all data types
    await _unifiedDataService.fetchAllReservations(forceRefresh: true);
    await _unifiedDataService.fetchAllSubscriptions(forceRefresh: true);
  }
}
```

## Troubleshooting

### Common Issues and Solutions

1. **Import Errors**: Make sure to import the new services
   ```dart
   import 'package:shamil_web_app/core/constants/data_paths.dart';
   import 'package:shamil_web_app/core/services/unified_data_service.dart';
   ```

2. **Initialization**: Always initialize UnifiedDataService before use
   ```dart
   final unifiedDataService = UnifiedDataService();
   await unifiedDataService.initialize();
   ```

3. **Stream Subscriptions**: Remember to dispose of stream subscriptions
   ```dart
   StreamSubscription? _subscription;
   
   @override
   void dispose() {
     _subscription?.cancel();
     super.dispose();
   }
   ```

4. **Cache Issues**: Clear cache if you encounter stale data
   ```dart
   await _unifiedDataService.fetchAllReservations(forceRefresh: true);
   ```

## Validation Checklist

After migration, verify:

- [ ] All hardcoded paths replaced with DataPaths constants
- [ ] All field names use DataPaths.field* constants
- [ ] Direct Firestore calls replaced with UnifiedDataService
- [ ] Real-time streams implemented where needed
- [ ] Error handling includes cache fallbacks
- [ ] Tests updated to use mocked services
- [ ] Performance improvements verified
- [ ] Offline functionality tested

## Next Steps

1. **Monitor Performance**: Check that the new architecture improves performance
2. **Test Offline Scenarios**: Verify that offline functionality works as expected
3. **Real-time Updates**: Ensure UI updates automatically when data changes
4. **Cache Management**: Monitor cache usage and adjust expiry times if needed
5. **Error Monitoring**: Set up logging to monitor any migration issues

## Support

If you encounter issues during migration:

1. Check the `DATA_ARCHITECTURE.md` for detailed documentation
2. Review the example implementations in the migration guide
3. Test with small changes first before migrating entire features
4. Use the debugging logs to identify issues

The migration provides significant benefits in terms of maintainability, performance, and user experience. Take time to test thoroughly and leverage the new real-time capabilities for a better user experience. 
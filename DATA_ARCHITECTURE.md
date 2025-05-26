# Data Architecture Documentation

## Overview

This document explains how reservation and subscription data is fetched, cached, and managed throughout the Shamil Web App. The architecture has been centralized to ensure consistency and maintainability.

## Key Components

### 1. DataPaths (`lib/core/constants/data_paths.dart`)

This is the central configuration file that contains all Firebase collection paths, field names, and data fetching configurations used throughout the app.

#### Main Collections
- `serviceProviders` - Main collection for service providers
- `endUsers` - Main collection for end users
- `reservations` - Legacy reservation collection
- `subscriptions` - Legacy subscription collection
- `accessLogs` - Access logs collection
- `syncMetadata` - Sync metadata collection

#### Service Provider Subcollections
- `activeSubscriptions` - Active subscriptions under service provider
- `expiredSubscriptions` - Expired subscriptions under service provider
- `confirmedReservations` - Confirmed reservations under service provider
- `pendingReservations` - Pending reservations under service provider
- `completedReservations` - Completed reservations under service provider
- `cancelledReservations` - Cancelled reservations under service provider
- `upcomingReservations` - Upcoming reservations under service provider

#### End User Subcollections
- `reservations` - User reservations subcollection
- `subscriptions` - User subscriptions subcollection
- `memberships` - User memberships subcollection (alternative)

### 2. UnifiedDataService (`lib/core/services/unified_data_service.dart`)

This service centralizes all data fetching and caching logic for reservations, subscriptions, and access logs.

#### Key Features
- **Multi-source fetching**: Fetches data from multiple Firebase collection paths
- **Intelligent caching**: Uses Hive for local storage with expiry management
- **Duplicate removal**: Automatically removes duplicate records based on ID
- **Fallback mechanisms**: Falls back to cache when network is unavailable
- **Type conversion**: Handles conversion between different data models

#### Usage Example

```dart
// Initialize the service
final unifiedDataService = UnifiedDataService();
await unifiedDataService.initialize();

// Fetch all reservations (with caching)
final reservations = await unifiedDataService.fetchAllReservations();

// Fetch all subscriptions (with caching)
final subscriptions = await unifiedDataService.fetchAllSubscriptions();

// Force refresh from server
final freshReservations = await unifiedDataService.fetchAllReservations(
  forceRefresh: true,
);

// Find active reservation for a user
final activeReservation = await unifiedDataService.findActiveReservation(
  'userId123',
  statusFilter: 'Confirmed',
);

// Find active subscription for a user
final activeSubscription = await unifiedDataService.findActiveSubscription('userId123');
```

## Data Flow Architecture

### Reservation Data Flow

```
1. UnifiedDataService.fetchAllReservations()
   ├── Check cache (if useCache=true && !forceRefresh)
   ├── Fetch from Service Provider subcollections
   │   ├── confirmedReservations
   │   ├── pendingReservations
   │   ├── completedReservations
   │   ├── cancelledReservations
   │   └── upcomingReservations
   ├── Fetch from Collection Group queries
   │   └── collectionGroup('reservations')
   ├── Fetch from Legacy paths (if applicable)
   ├── Remove duplicates
   ├── Sort by date
   ├── Cache results
   └── Return unified list
```

### Subscription Data Flow

```
1. UnifiedDataService.fetchAllSubscriptions()
   ├── Check cache (if useCache=true && !forceRefresh)
   ├── Fetch from Service Provider subcollections
   │   ├── activeSubscriptions
   │   └── expiredSubscriptions
   ├── Fetch from Collection Group queries
   │   └── collectionGroup('subscriptions')
   ├── Remove duplicates
   ├── Sort by expiry date
   ├── Cache results
   └── Return unified list
```

## Cache Management

### Cache Structure

The app uses Hive for local caching with the following boxes:

- `cached_users` - User information cache
- `cached_reservations` - Reservation cache
- `cached_subscriptions` - Subscription cache
- `cached_access_logs` - Access logs cache
- `sync_metadata` - Sync metadata and timestamps

### Cache Models

#### CachedReservation
```dart
class CachedReservation {
  final String userId;
  final String reservationId;
  final String serviceName;
  final DateTime startTime;
  final DateTime endTime;
  final String typeString;
  final int groupSize;
  final String status;
}
```

#### CachedSubscription
```dart
class CachedSubscription {
  final String userId;
  final String subscriptionId;
  final String planName;
  final DateTime expiryDate;
}
```

### Cache Expiry

- **Default cache expiry**: 24 hours
- **Sync metadata expiry**: 1 hour
- **Auto-sync interval**: 30 minutes
- **Force sync interval**: 6 hours

## Configuration Constants

### Time Ranges
- `defaultPastDaysRange`: 7 days (for fetching past reservations)
- `defaultFutureDaysRange`: 60 days (for fetching future reservations)
- `defaultQueryLimit`: 100 records per query

### Buffer Times
- `earlyCheckInBufferMinutes`: 60 minutes (early check-in allowed)
- `lateCheckOutBufferMinutes`: 30 minutes (late check-out allowed)
- `reservationValidityBufferMinutes`: 15 minutes (reservation validity buffer)

### Status Filters
- **Active reservation statuses**: `['Confirmed', 'Pending']`
- **Active subscription statuses**: `['Active']`
- **Valid reservation statuses**: `['Confirmed', 'Pending', 'Completed', 'Cancelled', 'cancelled_by_user', 'cancelled_by_provider', 'expired']`

## Path Building Helpers

The `DataPaths` class provides helper methods for building Firebase paths:

```dart
// Service provider paths
final providerPath = DataPaths.serviceProviderPath(providerId);
final activeSubsPath = DataPaths.providerActiveSubscriptionsPath(providerId);
final confirmedResPath = DataPaths.providerConfirmedReservationsPath(providerId);

// End user paths
final userPath = DataPaths.endUserPath(userId);
final userResPath = DataPaths.userReservationsPath(userId);
final userSubsPath = DataPaths.userSubscriptionsPath(userId);

// Get all possible paths
final allReservationPaths = DataPaths.getAllReservationPaths(providerId);
final allSubscriptionPaths = DataPaths.getAllSubscriptionPaths(providerId);
```

## Field Name Constants

All Firebase field names are centralized in `DataPaths`:

```dart
// Common fields
DataPaths.fieldUserId        // 'userId'
DataPaths.fieldProviderId    // 'providerId'
DataPaths.fieldDateTime      // 'dateTime'
DataPaths.fieldStatus        // 'status'
DataPaths.fieldServiceName   // 'serviceName'
DataPaths.fieldPlanName      // 'planName'
DataPaths.fieldExpiryDate    // 'expiryDate'
// ... and many more
```

## Migration Guide

### From Old Architecture

If you're migrating from the old data fetching approach:

1. **Replace direct Firestore calls** with `UnifiedDataService` methods
2. **Update collection paths** to use `DataPaths` constants
3. **Update field names** to use `DataPaths.field*` constants
4. **Remove duplicate data fetching logic** and use the centralized service

### Example Migration

**Before:**
```dart
// Old approach - scattered throughout the app
final reservations = await FirebaseFirestore.instance
    .collection('serviceProviders')
    .doc(providerId)
    .collection('confirmedReservations')
    .where('dateTime', isGreaterThan: pastDate)
    .get();
```

**After:**
```dart
// New approach - centralized
final unifiedService = UnifiedDataService();
final reservations = await unifiedService.fetchAllReservations();
```

## Best Practices

1. **Always use DataPaths constants** for collection and field names
2. **Initialize UnifiedDataService once** and reuse the instance
3. **Handle offline scenarios** by enabling cache fallback
4. **Use appropriate cache strategies** based on data freshness requirements
5. **Monitor cache size** and implement cleanup if needed
6. **Test with different network conditions** to ensure proper fallback behavior

## Error Handling

The UnifiedDataService includes comprehensive error handling:

- **Network errors**: Falls back to cache automatically
- **Parse errors**: Logs errors and continues with other records
- **Cache errors**: Gracefully handles cache failures
- **Authentication errors**: Throws appropriate exceptions

## Performance Considerations

- **Batch operations**: Uses configurable batch sizes for bulk operations
- **Query limits**: Implements reasonable query limits to prevent large data transfers
- **Duplicate removal**: Efficiently removes duplicates using Set-based deduplication
- **Lazy loading**: Only fetches data when needed
- **Cache-first approach**: Prioritizes cached data for better performance

## Monitoring and Debugging

Enable debug logging to monitor data fetching:

```dart
// The service includes comprehensive logging
// Check console output for detailed operation logs
```

Key log patterns to watch for:
- `UnifiedDataService: Fetched X reservations from Y`
- `UnifiedDataService: Returning X cached reservations`
- `UnifiedDataService: Error fetching from path: Y`

## Future Enhancements

Planned improvements:
1. **Real-time sync** using Firestore listeners
2. **Incremental sync** to reduce data transfer
3. **Background sync** for better offline support
4. **Data compression** for cache optimization
5. **Analytics integration** for usage tracking 
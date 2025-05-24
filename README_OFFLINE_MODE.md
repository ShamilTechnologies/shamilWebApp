# Enhanced Offline Mode

## Overview
This document explains the enhanced offline capabilities added to the Shamil Web App. The app now features a comprehensive offline mode that allows it to operate seamlessly without an internet connection, ensuring uninterrupted access control operations, user management, and more.

## Features
- **Complete Offline Operation**: The app continues to function normally even when offline
- **Automatic Data Caching**: Critical data is prioritized and cached locally
- **Smart Sync Mechanism**: Background synchronization when connectivity is restored
- **Data Prioritization**: Essential data for access control takes precedence
- **Offline Access Validation**: User access can be validated without internet connection
- **Local Logging**: All access attempts are logged locally and synced later

## Architecture

### Core Components

1. **EnhancedOfflineService**
   - Central manager for offline capabilities
   - Handles data prioritization and caching
   - Manages sync schedules and status tracking
   - Provides offline access control validation

2. **UnifiedCacheService**
   - Consolidates all local data storage
   - Uses Hive for high-performance offline storage
   - Manages data models and type adapters
   - Handles CRUD operations for cached data

3. **ConnectivityService**
   - Monitors network connectivity status
   - Triggers appropriate actions when connectivity changes
   - Provides connectivity status information to the UI

4. **SyncManager**
   - Orchestrates data synchronization between local cache and remote servers
   - Implements retry mechanisms with exponential backoff
   - Tracks sync status and provides feedback to the UI

## Data Prioritization

The app categorizes data into different priority levels:

- **Critical**: Essential for basic functionality (users, access rules)
- **High**: Important for core features (current day's reservations)
- **Medium**: Useful but not critical (past access logs)
- **Low**: Nice to have (analytics data)

## Offline Capabilities

### Access Control
- NFC and QR readers continue to function when offline
- Access validation based on cached subscription and reservation data
- Locally stored access rules are enforced
- All access attempts are logged locally for later sync

### User Management
- View and search cached user information
- See user access status based on locally stored data
- Check subscription and reservation status offline

### Reservations & Subscriptions
- View today's reservations and active subscriptions
- Check reservation status offline
- Validate user access based on locally cached data

## Sync Strategy

The app implements several sync strategies:

1. **Full Sync**: Complete synchronization of all data (performed periodically)
2. **Partial Sync**: Updates only high-priority data (performed more frequently)
3. **Background Sync**: Automatic sync when connectivity is restored
4. **Manual Sync**: User-triggered sync from the dashboard
5. **Incremental Sync**: Only syncs changes since last sync

## Status Indicators

The app provides clear feedback about offline status:

- **Offline Ready**: All essential data is cached and the app is fully functional offline
- **Limited Offline**: Some critical data may be missing, limiting some functionality
- **Sync in Progress**: Visual indicators when synchronization is occurring
- **Sync Error**: Clear error messages if synchronization fails

## Developer Notes

### Adding New Data Types

When adding new data that should be available offline:

1. Create a model class in the appropriate feature directory
2. Register a Hive TypeAdapter for the model
3. Update the UnifiedCacheService to handle the new data type
4. Set the appropriate priority level in EnhancedOfflineService

### Testing Offline Mode

To test offline functionality:

1. Enable airplane mode or disable network connectivity
2. Perform operations that should work offline
3. Re-enable connectivity and verify that data syncs correctly
4. Check the logs for any sync errors or warnings

## Configuration

The offline capabilities can be configured in the app settings:

- **Sync Frequency**: How often background sync occurs
- **Data Retention**: How long offline data is stored
- **Sync on Cellular**: Whether to sync when on cellular data
- **Automatic Sync**: Enable/disable background synchronization

## Troubleshooting

If you encounter issues with offline mode:

1. Check the app logs for error messages
2. Verify that the device has sufficient storage space
3. Try manually triggering a sync when online
4. If problems persist, clear the app cache and restart

For developers, more detailed logs can be enabled in development mode to help diagnose sync issues. 
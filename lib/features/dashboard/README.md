# Dashboard Module

This module contains all the components needed for the dashboard in the shamilWebApp web application. The dashboard provides an overview of key business metrics, reservations, subscriptions and more.

## Integration with Mobile App Reservation System

The dashboard integrates with the mobile app's reservation system through a real-time synchronization mechanism. This enables service providers to view and manage reservations made through the mobile app directly from the web dashboard.

### ReservationSyncService

The `ReservationSyncService` is responsible for synchronizing reservation data between the mobile app and web dashboard. It provides:

1. **Real-time listening**: Automatically detects and reflects changes in reservations made on the mobile app
2. **Manual synchronization**: Can be triggered to ensure data consistency
3. **Update functions**: Handles updating of key reservation properties:
   - Attendee payment status
   - Community visibility
   - Reservation status changes

#### How Synchronization Works

Reservation data follows a specific path in Firestore:
```
/reservations/{governorateId}/{providerId}/{reservationId}
```

The sync process:
1. Fetches the provider's governorate ID from their profile
2. Sets up real-time listeners for reservation changes
3. When changes occur, they are processed and reflected in the UI
4. Updates metadata to track synchronization status

#### Usage Example

```dart
// Initialize the service
final syncService = ReservationSyncService();
await syncService.init();

// Start listening for real-time updates
await syncService.startReservationListener();

// Manually trigger synchronization
await syncService.syncReservations();

// Update payment status for an attendee
await syncService.updateAttendeePaymentStatus(
  reservationId: 'reservation123',
  attendeeId: 'user456',
  hasPaid: true,
);

// Update community visibility
await syncService.updateCommunityVisibility(
  reservationId: 'reservation123',
  isVisible: true,
);

// Update reservation status
await syncService.updateReservationStatus(
  reservationId: 'reservation123',
  status: 'Confirmed',
);
```

### DashboardBloc and Reservation Integration

The `DashboardBloc` coordinates between the `ReservationSyncService` and the UI components. When a new reservation is received or updated, the bloc:

1. Updates the internal state with the new reservation data
2. Emits a notification that can be displayed to the user
3. Updates the UI to reflect the changes

### Troubleshooting Sync Issues

Common issues:

1. **Missing governorateId**: Ensure the service provider profile has a valid governorateId
2. **Authentication errors**: Verify the user is properly authenticated
3. **Firestore permission issues**: Check security rules to ensure the service provider has access to reservation data
4. **Offline sync**: The system will retry sync when connectivity is restored

## Module Structure

- **bloc/**: BLoC classes for state management
- **data/**: Data models, repositories, and services
- **services/**: Business logic and services including reservation sync
- **views/**: Screen and page components
- **widgets/**: Reusable UI components

## Overview

The Shamil Web App dashboard now supports viewing and managing reservations created from both the web interface and the mobile app. The integration ensures that all reservation data is consistently displayed and can be managed from a single interface.

## Key Components Updated

1. **Reservation Repository** (`lib/features/dashboard/data/reservation_repository.dart`)
   - Updated to use the same Firestore collection structure as the mobile app
   - Field names synchronized (e.g., `reservationStartTime` instead of `dateTime`)
   - Added support for mobile app-specific fields like attendees, community visibility, etc.
   - Enhanced queue-based reservations support

2. **Reservation Model** (`lib/features/dashboard/data/dashboard_models.dart`)
   - Updated to match mobile app's data structure
   - Added fields for attendees, queue status, community visibility, etc.
   - Handles both web and mobile app reservation formats

3. **New Reservation Sync Service** (`lib/features/dashboard/services/reservation_sync_service.dart`)
   - Real-time listening to reservation changes
   - Bidirectional sync with mobile app reservations
   - Integration with SyncManager for central sync coordination

4. **Reservation Form** (`lib/features/dashboard/widgets/forms/reservation_form.dart`)
   - Added UI for managing attendees lists
   - Added community visibility settings
   - Added full venue reservation option
   - Added price field

5. **Reservation Management UI** (`lib/features/dashboard/widgets/reservation_management.dart`)
   - Enhanced card view to show mobile app specific fields when available
   - Improved filtering to work with the mobile app data structure

## Mobile App Reservation Structure

Mobile app reservations contain several fields not previously used in the web app:

- `reservationStartTime`: Timestamp for the reservation start time
- `reservationEndTime`: Timestamp for the reservation end time
- `attendees`: List of users attending the reservation
- `isCommunityVisible`: Whether the reservation is visible to the community
- `isFullVenueReservation`: Whether the entire venue is reserved
- `typeSpecificData`: Additional data based on reservation type
- `queueStatus`: Information about queue position and estimated entry time

## Sync Implementation Details

The sync process occurs in several ways:

1. **Real-time updates**: The web app listens to changes in the reservations collection, ensuring instant updates when reservations are created/modified from the mobile app.

2. **Scheduled syncs**: The SyncManager performs regular syncs to ensure data consistency.

3. **Manual syncs**: Users can manually trigger a sync from the dashboard.

## Using the Reservation Sync Service

The `ReservationSyncService` provides methods to manage reservations:

```dart
// Get an instance of the service
final reservationService = ReservationSyncService();

// Update an attendee's payment status
await reservationService.updateAttendeePaymentStatus(
  reservationId: 'reservation123',
  attendeeUserId: 'user456',
  paymentStatus: 'paid',
  amount: 50.0,
);

// Update community visibility
await reservationService.updateCommunityVisibility(
  reservationId: 'reservation123',
  isVisible: true,
  hostingCategory: 'Sports',
  description: 'Open basketball session',
);

// Get community-hosted reservations
final communityReservations = await reservationService.getCommunityReservations(
  category: 'Sports',
  startDate: DateTime.now(),
);
```

## Troubleshooting

If reservations aren't appearing properly in the dashboard:

1. Check the governorateId configuration for the service provider
2. Verify that the mobile app is using the correct Firestore collection structure
3. Check the sync logs in the console for any errors
4. Manually trigger a sync from the dashboard

## Future Improvements

- Enhanced conflict resolution for simultaneous edits
- Offline support with background synchronization
- Improved notification system for reservation changes

## Firestore Structure

Reservations are stored in Firestore with the following path structure:
```
reservations/{governorateId}/{providerId}/{reservationId}
```

Key fields in the reservation document include:
- `reservationStartTime`: Timestamp when the reservation begins
- `reservationEndTime`: Timestamp when the reservation ends
- `reservationType`: Type of reservation (timeBased, serviceBased, etc.)
- `userId`: ID of the user making the reservation
- `userName`: Name of the user making the reservation
- `status`: Status of the reservation (Pending, Confirmed, Cancelled, etc.)
- `groupSize`: Number of people in the reservation
- `attendees`: List of attendees with their payment status
- `isCommunityVisible`: Whether the reservation is visible to the community
- `isFullVenueReservation`: Whether the reservation is for the full venue
- `typeSpecificData`: Additional type-specific data like hosting information

## Usage Notes

1. **Creating Reservations**:
   - The web app can create reservations that are fully compatible with the mobile app
   - All required fields for mobile app display are populated

2. **Managing Reservations**:
   - Editing and canceling reservations work across both platforms
   - Status updates are synchronized

3. **Community Features**:
   - Reservations can be made visible to the community
   - Hosting details can be provided for community events

4. **Attendee Management**:
   - The web app can now manage multiple attendees for a reservation
   - Payment status can be tracked for each attendee

## Future Enhancements

1. Add support for handling join requests from mobile app users
2. Implement detailed payment tracking for community reservations
3. Add analytics specific to community-hosted events
4. Enhance queue management features in the dashboard 
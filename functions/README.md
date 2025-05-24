# Access Control Cloud Functions

This directory contains Cloud Functions that support the offline-first access control system in the Shamil Web App.

## Overview

The access control system is designed to operate primarily offline, with Cloud Functions providing the following services:

1. **Validation Backup**: Online validation when local validation is not possible or for critical cases
2. **Data Synchronization**: Efficient syncing of access logs and user data
3. **Batch Processing**: Processing access logs in batches to reduce server load

## Setup

### Prerequisites

- Node.js 14 or later
- Firebase CLI installed (`npm install -g firebase-tools`)
- Firebase project set up with Firestore and Cloud Functions enabled

### Installation

1. Navigate to the functions directory:
   ```
   cd functions
   ```

2. Install dependencies:
   ```
   npm install
   ```

3. Deploy the functions:
   ```
   firebase deploy --only functions
   ```

## Available Functions

### `validateAccess`

This function validates a user's access rights by checking their subscriptions and reservations.

**Usage:**
```javascript
// In your Flutter app
final callable = FirebaseFunctions.instance.httpsCallable('validateAccess');
final result = await callable.call({
  'userId': 'user123',
  'providerId': 'provider456',
});
```

**Parameters:**
- `userId`: ID of the user to validate
- `providerId`: ID of the service provider (optional, defaults to authenticated user)

**Returns:**
```json
{
  "success": true,
  "hasAccess": true,
  "message": "Access granted via subscription",
  "accessType": "Subscription",
  "userData": {
    "name": "John Doe"
  },
  "subscription": {
    "id": "sub123",
    "planName": "Premium Membership",
    "expiryDate": "Timestamp"
  },
  "reservation": null,
  "pricingModel": "subscription"
}
```

### `syncAccessLogs`

This function processes batches of access logs efficiently.

**Usage:**
```javascript
// In your Flutter app
final callable = FirebaseFunctions.instance.httpsCallable('syncAccessLogs');
final result = await callable.call({
  'logs': [
    {
      "userId": "user123",
      "timestamp": Timestamp.now(),
      "status": "Granted",
      // ...other fields
    }
  ]
});
```

**Parameters:**
- `logs`: Array of access log objects to process

**Returns:**
```json
{
  "success": true,
  "processedCount": 5,
  "errorCount": 0
}
```

## Development

### Local Testing

1. Start the Firebase emulators:
   ```
   firebase emulators:start
   ```

2. In your app, point to the local emulator:
   ```dart
   if (kDebugMode) {
     FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
   }
   ```

### Structure

- `src/index.ts` - Main entry point
- `src/access-control.ts` - Access control functions
- `src/batch-processing.ts` - Batch processing functions

## Best Practices

1. **Idempotency**: All functions are designed to be idempotent to handle retries safely.
2. **Error Handling**: Functions include comprehensive error handling and logging.
3. **Security**: All functions verify authentication before processing.
4. **Performance**: Functions are optimized for quick execution to minimize costs.

## Troubleshooting

Check the Firebase Functions logs in the Firebase Console for detailed error information. 
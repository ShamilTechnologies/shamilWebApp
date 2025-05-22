# Firebase Indexes Deployment

This directory contains updated Firestore index configuration and deployment scripts to resolve the collection group query errors in the application.

## Index Issues Resolved

The following collection group indexes have been added to `firestore.indexes.json`:

1. `memberships` collection - Index on `providerId` field
2. `packages` collection - Index on `providerId` field
3. `plans` collection - Index on `providerId` field
4. `appointments` collection - Index on `providerId` field
5. `bookings` collection - Index on `providerId` field

These indexes are required for the collection group queries in the access control repository when searching for user access data across different collection paths.

## How to Deploy the Indexes

### Method 1: Using the Firebase Console

The error messages in your application logs include direct links to create each index. For example:

```
https://console.firebase.google.com/v1/r/project/shamilapp-shamiltechnologies/firestore/indexes?create_exemption=Cmhwcm9qZWN0cy9zaGFtaWxhcHAtc2hhbWlsdGVjaG5vbG9naWVzL2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9tZW1iZXJzaGlwcy9maWVsZHMvcHJvdmlkZXJJZBACGg4KCnByb3ZpZGVySWQQAQ
```

You can click each of these links to directly create the required indexes.

### Method 2: Using Firebase CLI (Recommended)

#### For Windows:

1. Run the `deploy_indexes.bat` script:
   ```
   .\deploy_indexes.bat
   ```
   
2. Follow the prompts for login if needed.

#### For macOS/Linux:

1. Make the script executable:
   ```
   chmod +x deploy_indexes.sh
   ```

2. Run the script:
   ```
   ./deploy_indexes.sh
   ```

3. Follow the prompts for login if needed.

### Method 3: Manual Firebase CLI Commands

1. Install Firebase CLI if you haven't already:
   ```
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```
   firebase login
   ```

3. Deploy only the Firestore indexes:
   ```
   firebase deploy --only firestore:indexes
   ```

## Verification

After deployment, the index creation may take several minutes (up to 30 minutes for large collections). Once completed, your application should no longer show the "failed-precondition" errors related to collection group queries. 
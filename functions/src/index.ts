import * as admin from 'firebase-admin';
// We're importing functions in the other files, so don't need it here

// Initialize Firebase Admin
admin.initializeApp();

// Import our access control functions
import { validateAccess } from './access-control';
import { syncAccessLogs, processPendingLogs } from './batch-processing';

// Export all functions
export {
  validateAccess,
  syncAccessLogs,
  processPendingLogs,
}; 
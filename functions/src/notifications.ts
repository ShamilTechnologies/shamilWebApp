import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import axios from 'axios';

// Hard-coded OneSignal credentials (Not ideal for security, but solves immediate deployment issues)
const ONE_SIGNAL_APP_ID = "b11ee2c0-8e8d-461b-9369-e161c0b26765";
const ONE_SIGNAL_API_KEY = "os_v2_app_wepofqeorvdbxe3j4fq4bmthmvepwd6vjl6enl4jmfb5vfyxmoklbl7djfurq3dleefe5iuuqwsbkahtthhomn3d7xyvfg5x5hykkoq";

/**
 * Sends a notification to a user's mobile device using OneSignal
 * This is triggered when a user accesses with their reservation
 */
export const sendAccessNotification = functions.https.onCall(async (data, context) => {
  // Log the incoming request data with request ID for tracking
  const requestId = Date.now().toString(36) + Math.random().toString(36).substring(2, 7);
  console.log(`[${requestId}] Notification request received:`, JSON.stringify(data));
  
  // Validate the request data
  if (!data.userId || !data.userName || !data.serviceName || !data.reservationId) {
    console.error(`[${requestId}] Missing required fields in notification request`);
    return { success: false, error: 'Missing required fields' };
  }

  try {
    // Save notification attempt to Firestore for tracking
    const notificationLogRef = await admin.firestore().collection('notificationLogs').add({
      userId: data.userId,
      userName: data.userName,
      serviceName: data.serviceName,
      reservationId: data.reservationId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      status: 'processing',
      requestId: requestId,
      source: data.source || 'access_control',
      platform: data.debug_device || 'unknown',
      providerName: data.providerName || 'Unknown Provider',
      providerMessage: data.message || `Your ${data.serviceName} reservation has been activated`,
    });
    
    console.log(`[${requestId}] Created notification log with ID: ${notificationLogRef.id}`);

    // Verify reservation status before sending notification
    try {
      const reservationRef = admin.firestore().collection('reservations').doc(data.reservationId);
      const reservationSnapshot = await reservationRef.get();
      
      if (!reservationSnapshot.exists) {
        console.warn(`[${requestId}] Reservation ${data.reservationId} not found in main collection`);
        
        // Try looking in user's reservations subcollection
        const userReservationRef = admin.firestore()
          .collection('endUsers')
          .doc(data.userId)
          .collection('reservations')
          .doc(data.reservationId);
          
        const userReservationSnapshot = await userReservationRef.get();
        
        if (!userReservationSnapshot.exists) {
          console.error(`[${requestId}] Reservation ${data.reservationId} not found in any collection`);
          await notificationLogRef.update({
            status: 'failed',
            errorMessage: 'Reservation not found in database',
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return { success: false, error: 'Reservation not found' };
        }
        
        const reservationData = userReservationSnapshot.data();
        
        // Check if reservation is cancelled or expired
        if (reservationData?.status === 'cancelled_by_user' || 
            reservationData?.status === 'cancelled_by_provider' || 
            reservationData?.status === 'expired') {
          console.warn(`[${requestId}] Reservation ${data.reservationId} has status: ${reservationData?.status}, cancelling notification`);
          
          await notificationLogRef.update({
            status: 'cancelled',
            errorMessage: `Notification cancelled due to reservation status: ${reservationData?.status}`,
            reservationStatus: reservationData?.status,
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          return { 
            success: false, 
            error: `Reservation has status: ${reservationData?.status}`,
            status: reservationData?.status 
          };
        }
      } else {
        const reservationData = reservationSnapshot.data();
        
        // Check if reservation is cancelled or expired
        if (reservationData?.status === 'cancelled_by_user' || 
            reservationData?.status === 'cancelled_by_provider' || 
            reservationData?.status === 'expired') {
          console.warn(`[${requestId}] Reservation ${data.reservationId} has status: ${reservationData?.status}, cancelling notification`);
          
          await notificationLogRef.update({
            status: 'cancelled',
            errorMessage: `Notification cancelled due to reservation status: ${reservationData?.status}`,
            reservationStatus: reservationData?.status,
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          return { 
            success: false, 
            error: `Reservation has status: ${reservationData?.status}`,
            status: reservationData?.status 
          };
        }
      }
    } catch (verificationError) {
      console.error(`[${requestId}] Error verifying reservation:`, verificationError);
      // Continue with notification anyway to avoid blocking user access
    }

    // Step 1: First try to find the user's OneSignal player ID directly
    let playerIds: string[] = [];
    
    try {
      // Query user document for oneSignalPlayerId or oneSignalPlayerIds
      const userDoc = await admin.firestore().collection('endUsers').doc(data.userId).get();
      
      if (userDoc.exists) {
        const userData = userDoc.data();
        if (userData) {
          // Check for array of player IDs
          if (userData.oneSignalPlayerIds && Array.isArray(userData.oneSignalPlayerIds)) {
            playerIds = userData.oneSignalPlayerIds.filter(id => id && typeof id === 'string');
          }
          
          // Check for single player ID
          if (userData.oneSignalPlayerId && typeof userData.oneSignalPlayerId === 'string') {
            if (!playerIds.includes(userData.oneSignalPlayerId)) {
              playerIds.push(userData.oneSignalPlayerId);
            }
          }
          
          // Also check for possible FCM tokens
          if (userData.fcmToken && typeof userData.fcmToken === 'string') {
            // We'd need to handle this differently for FCM
            console.log(`[${requestId}] Found FCM token for user ${data.userId}, but using OneSignal instead`);
          }
        }
      }
      
      console.log(`[${requestId}] Found ${playerIds.length} OneSignal player IDs for user ${data.userId}`);
    } catch (error) {
      console.error(`[${requestId}] Error fetching user OneSignal data:`, error);
    }

    // If no player IDs found directly, try external ID targeting
    const externalUserId = data.userId;
    let sendResult;
    
    if (playerIds.length > 0) {
      // Send to specific player IDs
      console.log(`[${requestId}] Sending notification via OneSignal to ${playerIds.length} player IDs`);
      
      sendResult = await axios.post(
        'https://onesignal.com/api/v1/notifications',
        {
          app_id: ONE_SIGNAL_APP_ID,
          include_player_ids: playerIds,
          contents: {
            en: data.message || `Your ${data.serviceName} reservation has been activated and marked as used.`
          },
          headings: {
            en: `${data.providerName || 'Shamil'} - Reservation Access`
          },
          data: {
            reservationId: data.reservationId,
            serviceName: data.serviceName,
            type: 'reservation_access',
            timestamp: Date.now()
          },
          android_channel_id: "reservation-updates",
          priority: 10,
        },
        {
          headers: {
            'Authorization': `Bearer ${ONE_SIGNAL_API_KEY}`,
            'Content-Type': 'application/json'
          }
        }
      );
    } else {
      // Send using external user ID
      console.log(`[${requestId}] Sending notification via OneSignal using external ID: ${externalUserId}`);
      
      sendResult = await axios.post(
        'https://onesignal.com/api/v1/notifications',
        {
          app_id: ONE_SIGNAL_APP_ID,
          include_external_user_ids: [externalUserId],
          contents: {
            en: data.message || `Your ${data.serviceName} reservation has been activated and marked as used.`
          },
          headings: {
            en: `${data.providerName || 'Shamil'} - Reservation Access`
          },
          data: {
            reservationId: data.reservationId,
            serviceName: data.serviceName,
            type: 'reservation_access',
            timestamp: Date.now()
          },
          android_channel_id: "reservation-updates",
          priority: 10,
        },
        {
          headers: {
            'Authorization': `Bearer ${ONE_SIGNAL_API_KEY}`,
            'Content-Type': 'application/json'
          }
        }
      );
    }

    console.log(`[${requestId}] OneSignal API response:`, JSON.stringify(sendResult.data));
    
    // Update notification log with success
    await notificationLogRef.update({
      status: 'sent',
      oneSignalResponse: sendResult.data,
      oneSignalRecipients: sendResult.data.recipients || 0,
      oneSignalPlayerIds: playerIds,
      externalUserId: externalUserId,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Also update the reservation document to mark notification as sent
    try {
      // Try to update in main reservations collection
      await admin.firestore().collection('reservations').doc(data.reservationId).update({
        notificationSent: true,
        notificationTime: admin.firestore.FieldValue.serverTimestamp(),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (reservationUpdateError) {
      console.warn(`[${requestId}] Error updating main reservation record:`, reservationUpdateError);
      
      // Try to update in user's reservations subcollection
      try {
        await admin.firestore()
          .collection('endUsers')
          .doc(data.userId)
          .collection('reservations')
          .doc(data.reservationId)
          .update({
            notificationSent: true,
            notificationTime: admin.firestore.FieldValue.serverTimestamp(),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          });
      } catch (userReservationUpdateError) {
        console.error(`[${requestId}] Error updating user reservation record:`, userReservationUpdateError);
      }
    }

    return { 
      success: true, 
      recipients: sendResult.data.recipients || 0,
      requestId: requestId,
      notificationId: notificationLogRef.id
    };
  } catch (error) {
    console.error(`[${requestId}] Error sending notification:`, error);
    
    // Log the error to Firestore
    try {
      await admin.firestore().collection('notificationLogs').add({
        userId: data.userId,
        userName: data.userName,
        serviceName: data.serviceName,
        reservationId: data.reservationId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        status: 'error',
        errorMessage: error.message || 'Unknown error',
        errorStack: error.stack,
        requestId: requestId,
      });
    } catch (logError) {
      console.error(`[${requestId}] Error logging notification error:`, logError);
    }
    
    return { 
      success: false, 
      error: error.message || 'Unknown error during notification', 
      requestId: requestId 
    };
  }
});

/**
 * Helper function to update the tracking document status
 */
async function updateTrackingStatus(trackingId: string, status: string, additionalData: any = {}) {
  try {
    await admin.firestore().collection('notificationTracking').doc(trackingId).update({
      status,
      updateTime: admin.firestore.FieldValue.serverTimestamp(),
      ...additionalData
    });
  } catch (error) {
    console.error(`Failed to update tracking document ${trackingId}:`, error);
  }
} 
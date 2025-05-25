"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendAccessNotification = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios_1 = require("axios");
// Hard-coded OneSignal credentials (Not ideal for security, but solves immediate deployment issues)
const ONE_SIGNAL_APP_ID = "b11ee2c0-8e8d-461b-9369-e161c0b26765";
const ONE_SIGNAL_API_KEY = "os_v2_app_wepofqeorvdbxe3j4fq4bmthmvepwd6vjl6enl4jmfb5vfyxmoklbl7djfurq3dleefe5iuuqwsbkahtthhomn3d7xyvfg5x5hykkoq";
/**
 * Sends a notification to a user's mobile device using OneSignal
 * This is triggered when a user accesses with their reservation
 */
exports.sendAccessNotification = functions.https.onCall(async (data, context) => {
    // Log the incoming request data
    console.log('sendAccessNotification function called with data:', JSON.stringify(data));
    // Verify authentication
    if (!context.auth) {
        console.error('Authentication error: No auth context provided');
        throw new functions.https.HttpsError('unauthenticated', 'You must be authenticated to send notifications.');
    }
    try {
        const { userId, userName, serviceName, reservationId, accessTime, message } = data;
        // Validate required parameters
        if (!userId || !serviceName) {
            console.error('Missing required parameters', { userId, serviceName });
            throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters: userId and serviceName are required.');
        }
        console.log(`Processing notification for user ${userId} (${userName}) for service ${serviceName}`);
        // First, log this notification in Firestore for tracking
        try {
            await admin.firestore().collection('notificationLogs').add({
                userId,
                userName,
                serviceName,
                reservationId,
                accessTime,
                message: message || `Your ${serviceName} reservation has been activated.`,
                status: 'processing',
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                providerUserId: context.auth.uid
            });
            console.log('Notification log entry created');
        }
        catch (error) {
            console.error('Error creating notification log entry:', error);
            // Continue anyway - this is just for logging
        }
        // Get the user's OneSignal external user ID (stored in Firebase)
        let userDoc;
        try {
            userDoc = await admin.firestore().collection('endUsers').doc(userId).get();
            if (!userDoc.exists) {
                console.error(`User ${userId} not found in database.`);
                throw new functions.https.HttpsError('not-found', `User ${userId} not found in database.`);
            }
        }
        catch (error) {
            console.error('Error fetching user document:', error);
            throw new functions.https.HttpsError('internal', `Error fetching user document: ${error instanceof Error ? error.message : 'Unknown error'}`);
        }
        const userData = userDoc.data();
        if (!userData) {
            console.error('User data is null or undefined.');
            throw new functions.https.HttpsError('internal', 'User data is null or undefined.');
        }
        console.log('User data retrieved successfully, checking notification channels');
        // Get the external ID (OneSignal ID) or device tokens
        const oneSignalExternalId = userData.oneSignalExternalId;
        const oneSignalPlayerId = userData.oneSignalPlayerId; // Some apps use this instead
        const deviceTokens = userData.deviceTokens || [];
        console.log('Notification channels:', {
            hasOneSignalExternalId: !!oneSignalExternalId,
            hasOneSignalPlayerId: !!oneSignalPlayerId,
            deviceTokensCount: deviceTokens.length
        });
        // If no ways to send notifications, try to find alternative identifiers
        let notificationSent = false;
        // Try sending via OneSignal External ID if available
        if (oneSignalExternalId) {
            try {
                console.log(`Attempting to send OneSignal notification to external ID: ${oneSignalExternalId}`);
                await sendOneSignalNotification(oneSignalExternalId, 'Reservation Activated', message || `Your ${serviceName} reservation has been activated. It's now marked as used.`, {
                    userId,
                    reservationId,
                    serviceName,
                    accessTime
                }, 'external_id');
                console.log(`OneSignal notification sent to user ${userId} (${userName}) via external ID`);
                notificationSent = true;
            }
            catch (error) {
                console.error('Error sending OneSignal notification via external ID:', error);
                // Continue to try other methods
            }
        }
        // Try sending via OneSignal Player ID if available and previous method failed
        if (!notificationSent && oneSignalPlayerId) {
            try {
                console.log(`Attempting to send OneSignal notification to player ID: ${oneSignalPlayerId}`);
                await sendOneSignalNotification(oneSignalPlayerId, 'Reservation Activated', message || `Your ${serviceName} reservation has been activated. It's now marked as used.`, {
                    userId,
                    reservationId,
                    serviceName,
                    accessTime
                }, 'player_id');
                console.log(`OneSignal notification sent to user ${userId} (${userName}) via player ID`);
                notificationSent = true;
            }
            catch (error) {
                console.error('Error sending OneSignal notification via player ID:', error);
                // Continue to try other methods
            }
        }
        // Try FCM if OneSignal failed and we have device tokens
        if (!notificationSent && deviceTokens.length > 0) {
            try {
                console.log(`Attempting to send FCM notification to ${deviceTokens.length} device tokens`);
                await sendFCMNotification(deviceTokens, 'Reservation Activated', message || `Your ${serviceName} reservation has been activated. It's now marked as used.`, {
                    userId,
                    reservationId,
                    serviceName,
                    accessTime
                });
                console.log(`FCM notification sent to user ${userId} (${userName}) via FCM`);
                notificationSent = true;
            }
            catch (error) {
                console.error('Error sending FCM notification:', error);
                // All methods have failed
            }
        }
        // Update the notification log with the result
        try {
            const querySnapshot = await admin.firestore()
                .collection('notificationLogs')
                .where('userId', '==', userId)
                .where('reservationId', '==', reservationId)
                .orderBy('timestamp', 'desc')
                .limit(1)
                .get();
            if (!querySnapshot.empty) {
                await querySnapshot.docs[0].ref.update({
                    status: notificationSent ? 'sent' : 'failed',
                    completedAt: admin.firestore.FieldValue.serverTimestamp()
                });
            }
        }
        catch (error) {
            console.error('Error updating notification log:', error);
            // Non-critical, continue
        }
        if (notificationSent) {
            console.log(`Successfully sent notification to user ${userId} (${userName})`);
            return {
                success: true,
                method: oneSignalExternalId ? 'onesignal_external_id' :
                    oneSignalPlayerId ? 'onesignal_player_id' :
                        deviceTokens.length > 0 ? 'fcm' : 'unknown'
            };
        }
        else {
            console.error('All notification methods failed');
            return {
                success: false,
                error: 'All notification methods failed',
                attemptedMethods: {
                    oneSignalExternalId: !!oneSignalExternalId,
                    oneSignalPlayerId: !!oneSignalPlayerId,
                    fcm: deviceTokens.length > 0
                }
            };
        }
    }
    catch (error) {
        console.error('Error sending notification:', error);
        throw new functions.https.HttpsError('internal', `Error sending notification: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
});
/**
 * Send a notification using OneSignal's REST API
 */
async function sendOneSignalNotification(id, title, content, data, idType = 'external_id') {
    try {
        console.log(`Sending OneSignal notification to ${idType}: ${id}`);
        console.log(`OneSignal APP ID: ${ONE_SIGNAL_APP_ID}`);
        console.log(`OneSignal API KEY: ${ONE_SIGNAL_API_KEY.substring(0, 10)}...`);
        const payload = {
            app_id: ONE_SIGNAL_APP_ID,
            headings: { en: title },
            contents: { en: content },
            data: data,
            android_channel_id: 'reservation-updates',
            ios_badgeType: 'Increase',
            ios_badgeCount: 1,
        };
        // Set the appropriate field based on ID type
        if (idType === 'external_id') {
            payload.include_external_user_ids = [id];
        }
        else {
            payload.include_player_ids = [id];
        }
        console.log('OneSignal request payload:', JSON.stringify(payload));
        const response = await axios_1.default.post('https://onesignal.com/api/v1/notifications', payload, {
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Basic ${ONE_SIGNAL_API_KEY}`,
            },
        });
        console.log('OneSignal API response:', JSON.stringify(response.data));
        return response.data;
    }
    catch (error) {
        console.error('OneSignal API error:', error);
        if (axios_1.default.isAxiosError(error) && error.response) {
            console.error('OneSignal API error response:', JSON.stringify(error.response.data));
        }
        throw error;
    }
}
/**
 * Fallback method to send notification using Firebase Cloud Messaging
 */
async function sendFCMNotification(deviceTokens, title, body, data) {
    console.log(`Sending FCM notification to ${deviceTokens.length} device tokens`);
    const message = {
        notification: {
            title,
            body,
        },
        data: Object.assign(Object.assign({}, data), { click_action: 'FLUTTER_NOTIFICATION_CLICK' }),
        tokens: deviceTokens,
    };
    console.log('FCM message payload:', JSON.stringify(message));
    const response = await admin.messaging().sendMulticast(message);
    console.log(`FCM response: ${response.successCount} successful, ${response.failureCount} failed`);
    return response;
}
//# sourceMappingURL=notifications.js.map
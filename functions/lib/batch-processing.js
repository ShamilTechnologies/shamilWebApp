"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.processPendingLogs = exports.syncAccessLogs = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
/**
 * Cloud function for processing batches of access logs efficiently
 * This helps minimize Firestore writes and reduces costs
 */
exports.syncAccessLogs = functions.https.onCall(async (data, context) => {
    // Ensure user is authenticated
    if (!context.auth) {
        return {
            success: false,
            message: 'Authentication required',
        };
    }
    try {
        const logs = data.logs;
        // Ensure logs array is provided
        if (!logs || !Array.isArray(logs) || logs.length === 0) {
            return {
                success: false,
                message: 'No logs provided or invalid format',
            };
        }
        const providerId = context.auth.uid;
        console.log(`Processing ${logs.length} access logs for provider ${providerId}`);
        // Use batched writes for better performance
        const batchSize = 500; // Firestore batch limit
        const batches = [];
        // Split logs into batches of 500
        for (let i = 0; i < logs.length; i += batchSize) {
            const batch = admin.firestore().batch();
            const batchLogs = logs.slice(i, i + batchSize);
            // Process each log in this batch
            for (const log of batchLogs) {
                // Validate required fields
                if (!log.userId || !log.timestamp) {
                    console.warn('Skipping log with missing required fields:', log);
                    continue;
                }
                // Create a document reference
                const docRef = admin.firestore().collection('accessLogs').doc();
                // Prepare log data with provider ID
                const logData = Object.assign(Object.assign({}, log), { providerId, synced: true, syncTimestamp: admin.firestore.FieldValue.serverTimestamp() });
                // Add to batch
                batch.set(docRef, logData);
            }
            // Add this batch to our batches array
            batches.push(batch);
        }
        // Execute all batches
        console.log(`Executing ${batches.length} batches of writes`);
        await Promise.all(batches.map(batch => batch.commit()));
        // Update analytics
        try {
            const analyticsRef = admin.firestore().collection('analytics').doc(providerId);
            await analyticsRef.set({
                lastSyncTime: admin.firestore.FieldValue.serverTimestamp(),
                totalAccessLogs: admin.firestore.FieldValue.increment(logs.length),
            }, { merge: true });
        }
        catch (e) {
            console.error('Error updating analytics:', e);
            // Don't fail the entire operation for analytics
        }
        return {
            success: true,
            processedCount: logs.length,
            batchCount: batches.length,
        };
    }
    catch (error) {
        console.error('Error processing access logs:', error);
        return {
            success: false,
            message: `Error processing logs: ${error.message || 'Unknown error'}`,
        };
    }
});
/**
 * Scheduled function to process any pending logs that weren't synced
 * Runs once a day to ensure no logs are lost
 */
exports.processPendingLogs = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
    try {
        // Find logs that are older than 24 hours and haven't been synced
        const oneDayAgo = new Date();
        oneDayAgo.setDate(oneDayAgo.getDate() - 1);
        const snapshot = await admin.firestore().collection('accessLogs')
            .where('synced', '==', false)
            .where('timestamp', '<', admin.firestore.Timestamp.fromDate(oneDayAgo))
            .limit(1000) // Process in chunks
            .get();
        if (snapshot.empty) {
            console.log('No pending logs to process');
            return null;
        }
        console.log(`Found ${snapshot.size} pending logs to process`);
        // Group logs by provider ID for efficient processing
        const logsByProvider = {};
        snapshot.forEach(doc => {
            const data = doc.data();
            const providerId = data.providerId;
            if (!logsByProvider[providerId]) {
                logsByProvider[providerId] = [];
            }
            logsByProvider[providerId].push(Object.assign({ id: doc.id }, data));
        });
        // Process each provider's logs
        for (const [providerId, logs] of Object.entries(logsByProvider)) {
            console.log(`Processing ${logs.length} logs for provider ${providerId}`);
            // Update each log as synced
            const batch = admin.firestore().batch();
            for (const log of logs) {
                const logRef = admin.firestore().collection('accessLogs').doc(log.id);
                batch.update(logRef, {
                    synced: true,
                    syncTimestamp: admin.firestore.FieldValue.serverTimestamp()
                });
            }
            await batch.commit();
            // Update analytics
            const analyticsRef = admin.firestore().collection('analytics').doc(providerId);
            await analyticsRef.set({
                lastSyncTime: admin.firestore.FieldValue.serverTimestamp(),
                totalAccessLogs: admin.firestore.FieldValue.increment(logs.length),
            }, { merge: true });
        }
        return null;
    }
    catch (error) {
        console.error('Error processing pending logs:', error);
        return null;
    }
});
//# sourceMappingURL=batch-processing.js.map
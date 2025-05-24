import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Cloud function for validating user access that supports offline-first operation
 * This function is called only when online validation is required
 */
export const validateAccess = functions.https.onCall(async (data, context) => {
  // Ensure user is authenticated
  if (!context.auth) {
    return {
      success: false,
      hasAccess: false,
      message: 'Authentication required',
    };
  }

  try {
    const userId = data.userId;
    const providerId = data.providerId || context.auth.uid;

    // Ensure required parameters are provided
    if (!userId || !providerId) {
      return {
        success: false,
        message: 'Missing required parameters',
      };
    }

    console.log(`Validating access for user ${userId} with provider ${providerId}`);

    // Get user data
    const userDoc = await admin.firestore().collection('endUsers').doc(userId).get();

    if (!userDoc.exists) {
      return {
        success: false,
        hasAccess: false,
        message: 'User not found',
        userData: null,
      };
    }

    const userData = userDoc.data();
    const userName = userData?.displayName || userData?.name || 'Unknown User';

    // Get provider info to determine pricing model
    const providerDoc = await admin.firestore().collection('serviceProviders').doc(providerId).get();

    if (!providerDoc.exists) {
      return {
        success: false,
        hasAccess: false,
        message: 'Service provider not found',
        userData: { name: userName },
      };
    }

    const providerData = providerDoc.data();
    const pricingModel = providerData?.pricingModel || 'other';
    // Use the governorateId if needed in the future
    // const governorateId = providerData?.governorateId;

    // Get current time
    const now = admin.firestore.Timestamp.now();
    const today = new Date(now.toDate().setHours(0, 0, 0, 0));

    // Check for active subscription
    let hasSubscription = false;
    let subscriptionData = null;

    if (pricingModel === 'subscription' || pricingModel === 'hybrid') {
      // Check active subscriptions
      const subscriptionsQuery = await admin.firestore()
        .collection('serviceProviders')
        .doc(providerId)
        .collection('activeSubscriptions')
        .where('userId', '==', userId)
        .limit(1)
        .get();

      if (!subscriptionsQuery.empty) {
        const subscriptionDoc = subscriptionsQuery.docs[0];
        const subscription = subscriptionDoc.data();
        
        // Check if subscription is still valid
        if (subscription.expiryDate && subscription.expiryDate.toDate() > now.toDate()) {
          hasSubscription = true;
          subscriptionData = {
            id: subscriptionDoc.id,
            planName: subscription.planName || 'Membership',
            expiryDate: subscription.expiryDate,
          };
        }
      }

      // If not found, check user's subscriptions
      if (!hasSubscription) {
        const userSubsQuery = await admin.firestore()
          .collection('endUsers')
          .doc(userId)
          .collection('subscriptions')
          .where('providerId', '==', providerId)
          .where('status', '==', 'Active')
          .limit(1)
          .get();

        if (!userSubsQuery.empty) {
          const subscriptionDoc = userSubsQuery.docs[0];
          const subscription = subscriptionDoc.data();
          
          // Check if subscription is still valid
          if (subscription.expiryDate && subscription.expiryDate.toDate() > now.toDate()) {
            hasSubscription = true;
            subscriptionData = {
              id: subscriptionDoc.id,
              planName: subscription.planName || 'Membership',
              expiryDate: subscription.expiryDate,
            };
          }
        }
      }
    }

    // Check for active reservation
    let hasReservation = false;
    let reservationData = null;

    if (pricingModel === 'reservation' || pricingModel === 'hybrid') {
      // Check today's reservations
      const confirmedReservationsQuery = await admin.firestore()
        .collection('serviceProviders')
        .doc(providerId)
        .collection('confirmedReservations')
        .where('userId', '==', userId)
        .get();

      // Find a reservation for today
      for (const doc of confirmedReservationsQuery.docs) {
        const reservation = doc.data();
        
        // Check if the reservation is for today
        if (reservation.dateTime) {
          const resDate = new Date(reservation.dateTime.toDate().setHours(0, 0, 0, 0));
          
          if (resDate.getTime() === today.getTime()) {
            hasReservation = true;
            
            // Calculate end time if not specified
            let endTime = reservation.endTime;
            if (!endTime && reservation.duration) {
              const startTime = reservation.dateTime.toDate();
              endTime = new admin.firestore.Timestamp(
                startTime.getTime() / 1000 + (reservation.duration * 60),
                0
              );
            } else if (!endTime) {
              // Default to 1 hour duration
              const startTime = reservation.dateTime.toDate();
              endTime = new admin.firestore.Timestamp(
                startTime.getTime() / 1000 + (60 * 60),
                0
              );
            }
            
            reservationData = {
              id: doc.id,
              serviceName: reservation.serviceName || reservation.className || 'Booking',
              startTime: reservation.dateTime,
              endTime: endTime,
              type: reservation.type || 'standard',
              groupSize: reservation.groupSize || reservation.persons || 1,
              status: 'Confirmed',
            };
            
            break;
          }
        }
      }
      
      // If not found in confirmed, check pending as well
      if (!hasReservation) {
        const pendingReservationsQuery = await admin.firestore()
          .collection('serviceProviders')
          .doc(providerId)
          .collection('pendingReservations')
          .where('userId', '==', userId)
          .get();

        // Find a reservation for today
        for (const doc of pendingReservationsQuery.docs) {
          const reservation = doc.data();
          
          // Check if the reservation is for today
          if (reservation.dateTime) {
            const resDate = new Date(reservation.dateTime.toDate().setHours(0, 0, 0, 0));
            
            if (resDate.getTime() === today.getTime()) {
              hasReservation = true;
              
              // Calculate end time if not specified
              let endTime = reservation.endTime;
              if (!endTime && reservation.duration) {
                const startTime = reservation.dateTime.toDate();
                endTime = new admin.firestore.Timestamp(
                  startTime.getTime() / 1000 + (reservation.duration * 60),
                  0
                );
              } else if (!endTime) {
                // Default to 1 hour duration
                const startTime = reservation.dateTime.toDate();
                endTime = new admin.firestore.Timestamp(
                  startTime.getTime() / 1000 + (60 * 60),
                  0
                );
              }
              
              reservationData = {
                id: doc.id,
                serviceName: reservation.serviceName || reservation.className || 'Booking',
                startTime: reservation.dateTime,
                endTime: endTime,
                type: reservation.type || 'standard',
                groupSize: reservation.groupSize || reservation.persons || 1,
                status: 'Pending',
              };
              
              break;
            }
          }
        }
      }
    }

    // Determine access based on provider's pricing model
    let hasAccess = false;
    let accessType: string | null = null;
    let message = '';
    
    switch (pricingModel) {
      case 'subscription':
        hasAccess = hasSubscription;
        accessType = hasAccess ? 'Subscription' : null;
        message = hasAccess ? 'Access granted via subscription' : 'No active subscription found';
        break;
        
      case 'reservation':
        hasAccess = hasReservation;
        accessType = hasAccess ? 'Reservation' : null;
        message = hasAccess ? 'Access granted via reservation' : 'No valid reservation for today';
        break;
        
      case 'hybrid':
        hasAccess = hasSubscription || hasReservation;
        accessType = hasSubscription ? 'Subscription' : (hasReservation ? 'Reservation' : null);
        message = hasAccess ? `Access granted via ${accessType?.toLowerCase() || 'unknown'}` : 'No active subscription or reservation';
        break;
        
      case 'other':
        // For 'other' model, just grant access if the user exists
        hasAccess = true;
        accessType = 'Default';
        message = 'Access granted';
        break;
        
      default:
        hasAccess = false;
        message = 'Unknown pricing model';
    }

    // Record access log
    try {
      await admin.firestore().collection('accessLogs').add({
        userId: userId,
        userName: userName,
        providerId: providerId,
        timestamp: now,
        status: hasAccess ? 'Granted' : 'Denied',
        method: 'Online Validation',
        denialReason: hasAccess ? null : message,
      });
    } catch (logError) {
      console.error('Error recording access log:', logError);
      // Don't fail the whole function for a log error
    }

    // Return comprehensive result with all data needed to update local cache
    return {
      success: true,
      hasAccess,
      message,
      accessType,
      userData: {
        name: userName,
      },
      subscription: subscriptionData,
      reservation: reservationData,
      pricingModel,
    };
  } catch (error: any) {
    console.error('Error validating access:', error);
    return {
      success: false,
      hasAccess: false,
      message: `Error validating access: ${error.message || 'Unknown error'}`,
    };
  }
}); 
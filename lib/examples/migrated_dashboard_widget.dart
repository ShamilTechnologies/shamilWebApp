import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamil_web_app/core/constants/data_paths.dart';
import 'package:shamil_web_app/core/services/unified_data_service.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';

/// Example widget demonstrating the new UnifiedDataService and DataPaths usage
/// This shows how to implement real-time updates and proper error handling
class MigratedDashboardWidget extends StatefulWidget {
  const MigratedDashboardWidget({Key? key}) : super(key: key);

  @override
  State<MigratedDashboardWidget> createState() =>
      _MigratedDashboardWidgetState();
}

class _MigratedDashboardWidgetState extends State<MigratedDashboardWidget> {
  final UnifiedDataService _unifiedDataService = UnifiedDataService();
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _unifiedDataService.initialize();
      setState(() {
        _isInitialized = true;
        _errorMessage = null;
      });

      // Initial data load
      await _loadInitialData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize data service: $e';
      });
    }
  }

  Future<void> _loadInitialData() async {
    try {
      // Load initial data - this will also populate the streams
      await _unifiedDataService.fetchAllReservations();
      await _unifiedDataService.fetchAllSubscriptions();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load initial data: $e';
      });
    }
  }

  Future<void> _refreshData() async {
    try {
      setState(() {
        _errorMessage = null;
      });

      // Force refresh from server
      await _unifiedDataService.fetchAllReservations(forceRefresh: true);
      await _unifiedDataService.fetchAllSubscriptions(forceRefresh: true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data refreshed successfully')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to refresh data: $e';
      });
    }
  }

  @override
  void dispose() {
    _unifiedDataService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing data service...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard (Migrated)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                _buildErrorCard(),
                const SizedBox(height: 16),
              ],
              _buildConfigurationInfo(),
              const SizedBox(height: 24),
              _buildReservationsSection(),
              const SizedBox(height: 24),
              _buildSubscriptionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _errorMessage = null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuration (using DataPaths)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildConfigRow('Query Limit', '${DataPaths.defaultQueryLimit}'),
            _buildConfigRow(
              'Cache Expiry',
              '${DataPaths.cacheExpiryHours} hours',
            ),
            _buildConfigRow(
              'Auto Sync Interval',
              '${DataPaths.autoSyncIntervalMinutes} minutes',
            ),
            _buildConfigRow(
              'Early Check-in Buffer',
              '${DataPaths.earlyCheckInBufferMinutes} minutes',
            ),
            _buildConfigRow(
              'Late Check-out Buffer',
              '${DataPaths.lateCheckOutBufferMinutes} minutes',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildReservationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reservations (Real-time)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Reservation>>(
          stream: _unifiedDataService.reservationsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error loading reservations: ${snapshot.error}',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              );
            }

            final reservations = snapshot.data ?? [];

            if (reservations.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No reservations found')),
                ),
              );
            }

            return Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total: ${reservations.length}'),
                        Text(
                          'Active: ${reservations.where((r) => DataPaths.isActiveReservationStatus(r.status)).length}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...reservations
                    .take(5)
                    .map((reservation) => _buildReservationCard(reservation)),
                if (reservations.length > 5)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text('... and ${reservations.length - 5} more'),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildReservationCard(Reservation reservation) {
    final isActive = DataPaths.isActiveReservationStatus(reservation.status);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.green : Colors.grey,
          child: Icon(
            isActive ? Icons.check : Icons.schedule,
            color: Colors.white,
          ),
        ),
        title: Text(reservation.serviceName ?? 'Unknown Service'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${reservation.userName ?? 'Unknown'}'),
            Text('Status: ${reservation.status}'),
            if (reservation.groupSize != null)
              Text('Group Size: ${reservation.groupSize}'),
          ],
        ),
        trailing: Text(
          reservation.dateTime?.toDate().toString().split(' ')[0] ?? 'No date',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildSubscriptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Subscriptions (Real-time)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Subscription>>(
          stream: _unifiedDataService.subscriptionsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error loading subscriptions: ${snapshot.error}',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              );
            }

            final subscriptions = snapshot.data ?? [];

            if (subscriptions.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No subscriptions found')),
                ),
              );
            }

            return Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total: ${subscriptions.length}'),
                        Text(
                          'Active: ${subscriptions.where((s) => DataPaths.isActiveSubscriptionStatus(s.status)).length}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...subscriptions
                    .take(5)
                    .map(
                      (subscription) => _buildSubscriptionCard(subscription),
                    ),
                if (subscriptions.length > 5)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text('... and ${subscriptions.length - 5} more'),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubscriptionCard(Subscription subscription) {
    final isActive = DataPaths.isActiveSubscriptionStatus(subscription.status);
    final isExpiringSoon =
        subscription.expiryDate != null &&
        subscription.expiryDate!.toDate().difference(DateTime.now()).inDays < 7;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isActive
                  ? (isExpiringSoon ? Colors.orange : Colors.green)
                  : Colors.grey,
          child: Icon(
            isActive ? Icons.card_membership : Icons.cancel,
            color: Colors.white,
          ),
        ),
        title: Text(subscription.planName ?? 'Unknown Plan'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${subscription.userName ?? 'Unknown'}'),
            Text('Status: ${subscription.status}'),
            if (subscription.expiryDate != null)
              Text(
                'Expires: ${subscription.expiryDate!.toDate().toString().split(' ')[0]}',
                style: TextStyle(
                  color: isExpiringSoon ? Colors.orange : null,
                  fontWeight: isExpiringSoon ? FontWeight.bold : null,
                ),
              ),
          ],
        ),
        trailing:
            subscription.isAutoRenewal == true
                ? const Icon(Icons.autorenew, color: Colors.blue)
                : null,
      ),
    );
  }
}

/// Example of how to use the UnifiedDataService for access control
class AccessControlExample {
  final UnifiedDataService _unifiedDataService = UnifiedDataService();

  Future<Map<String, dynamic>> checkUserAccess(String userId) async {
    try {
      // Initialize if not already done
      await _unifiedDataService.initialize();

      // Check for active reservation using DataPaths status constants
      final activeReservation = await _unifiedDataService.findActiveReservation(
        userId,
        statusFilter: DataPaths.activeReservationStatuses.first, // 'Confirmed'
      );

      if (activeReservation != null) {
        return {
          'hasAccess': true,
          'accessType': 'reservation',
          'message':
              'Active reservation found for ${activeReservation.serviceName}',
          'details': {
            'serviceName': activeReservation.serviceName,
            'startTime': activeReservation.startTime,
            'endTime': activeReservation.endTime,
            'groupSize': activeReservation.groupSize,
          },
        };
      }

      // Check for active subscription
      final activeSubscription = await _unifiedDataService
          .findActiveSubscription(userId);

      if (activeSubscription != null) {
        return {
          'hasAccess': true,
          'accessType': 'subscription',
          'message':
              'Active subscription found: ${activeSubscription.planName}',
          'details': {
            'planName': activeSubscription.planName,
            'expiryDate': activeSubscription.expiryDate,
          },
        };
      }

      return {
        'hasAccess': false,
        'accessType': null,
        'message': 'No active reservation or subscription found',
        'details': null,
      };
    } catch (e) {
      return {
        'hasAccess': false,
        'accessType': null,
        'message': 'Error checking access: $e',
        'details': null,
      };
    }
  }
}

/// Example of how to use DataPaths for building queries
class QueryExample {
  static Query<Map<String, dynamic>> buildReservationQuery(
    FirebaseFirestore firestore,
    String providerId,
  ) {
    final timeRange = DataPaths.getReservationTimeRange();

    return firestore
        .collection(DataPaths.serviceProviders)
        .doc(providerId)
        .collection(DataPaths.confirmedReservations)
        .where(DataPaths.fieldDateTime, isGreaterThan: timeRange['pastDate'])
        .where(DataPaths.fieldDateTime, isLessThan: timeRange['futureDate'])
        .where(
          DataPaths.fieldStatus,
          whereIn: DataPaths.activeReservationStatuses,
        )
        .orderBy(DataPaths.fieldDateTime, descending: true)
        .limit(DataPaths.defaultQueryLimit);
  }

  static Query<Map<String, dynamic>> buildSubscriptionQuery(
    FirebaseFirestore firestore,
    String providerId,
  ) {
    return firestore
        .collection(DataPaths.serviceProviders)
        .doc(providerId)
        .collection(DataPaths.activeSubscriptions)
        .where(
          DataPaths.fieldStatus,
          whereIn: DataPaths.activeSubscriptionStatuses,
        )
        .limit(DataPaths.defaultQueryLimit);
  }
}

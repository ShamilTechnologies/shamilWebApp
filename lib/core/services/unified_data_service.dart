import 'dart:async';
import 'dart:isolate';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

import '../constants/data_paths.dart';
import '../../features/access_control/data/local_cache_models.dart';
import '../../features/dashboard/data/dashboard_models.dart';
import 'status_management_service.dart';

/// Intelligent unified data service that works with minimal data structures
/// and enriches them intelligently while preventing threading issues
class UnifiedDataService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final StatusManagementService _statusService = StatusManagementService();

  bool _isInitialized = false;
  bool _isFetching = false;
  DateTime? _lastFetch;
  static const Duration _fetchCooldown = Duration(seconds: 5);

  // Intelligent caches for data enrichment
  final Map<String, String> _userNameCache = {};
  final Map<String, String> _serviceNameCache = {};
  final Map<String, Map<String, dynamic>> _userDetailsCache = {};
  final Set<String> _processedReservationIds = {};
  final Set<String> _processedSubscriptionIds = {};

  // Stream controllers for real-time updates
  final StreamController<List<Reservation>> _reservationsStreamController =
      StreamController<List<Reservation>>.broadcast();
  final StreamController<List<Subscription>> _subscriptionsStreamController =
      StreamController<List<Subscription>>.broadcast();

  // Stream getters
  Stream<List<Reservation>> get reservationsStream =>
      _reservationsStreamController.stream;
  Stream<List<Subscription>> get subscriptionsStream =>
      _subscriptionsStreamController.stream;

  UnifiedDataService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Initialize the service with intelligent setup
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if boxes are already open
      final isUsersBoxOpen = Hive.isBoxOpen('cachedUsersBox');
      final isReservationsBoxOpen = Hive.isBoxOpen('cachedReservationsBox');
      final isSubscriptionsBoxOpen = Hive.isBoxOpen('cachedSubscriptionsBox');

      if (!isUsersBoxOpen ||
          !isReservationsBoxOpen ||
          !isSubscriptionsBoxOpen) {
        print(
          'UnifiedDataService: Required boxes not open, waiting for initialization',
        );
        await Future.delayed(Duration(milliseconds: 500));
      }

      // Pre-populate user cache for faster lookups
      await _preloadUserCache();

      _isInitialized = true;
      print('UnifiedDataService: Intelligent initialization completed');
    } catch (e) {
      print('UnifiedDataService: Error during initialization: $e');
      throw Exception('Failed to initialize UnifiedDataService: $e');
    }
  }

  /// Pre-load user cache for intelligent data enrichment
  Future<void> _preloadUserCache() async {
    try {
      if (Hive.isBoxOpen('cachedUsersBox')) {
        final box = Hive.box<CachedUser>('cachedUsersBox');
        for (final user in box.values) {
          _userNameCache[user.userId] = user.userName;
          _userDetailsCache[user.userId] = {
            'name': user.userName,
            'userId': user.userId,
          };
        }
        print('UnifiedDataService: Pre-loaded ${box.length} users into cache');
      }
    } catch (e) {
      print('UnifiedDataService: Error pre-loading user cache: $e');
    }
  }

  /// Intelligent reservation fetching with minimal data enrichment
  Future<List<Reservation>> fetchAllReservations({
    bool useCache = true,
    bool forceRefresh = false,
  }) async {
    await _ensureInitialized();

    final providerId = _getCurrentProviderId();
    if (providerId == null) {
      throw Exception('Provider not authenticated');
    }

    // Intelligent debouncing
    final now = DateTime.now();
    if (!forceRefresh && _isFetching) {
      print('UnifiedDataService: Fetch in progress, returning cached data');
      return await getCachedReservations();
    }

    if (!forceRefresh &&
        _lastFetch != null &&
        now.difference(_lastFetch!) < _fetchCooldown) {
      print('UnifiedDataService: Fetch throttled, returning cached data');
      return await getCachedReservations();
    }

    _isFetching = true;
    _lastFetch = now;

    // Clear processed IDs on force refresh
    if (forceRefresh) {
      _processedReservationIds.clear();
    }

    // Return cached data if available and not forcing refresh
    if (useCache && !forceRefresh) {
      final cachedReservations = await getCachedReservations();
      if (cachedReservations.isNotEmpty) {
        print(
          'UnifiedDataService: Returning ${cachedReservations.length} cached reservations',
        );
        _isFetching = false;
        return cachedReservations;
      }
    }

    print('UnifiedDataService: Starting intelligent reservation fetch');

    try {
      final allReservations = <Reservation>[];

      // Use compute for heavy processing to avoid threading issues
      final reservationData = await _fetchReservationDataSafely(providerId);

      // Process data intelligently
      for (final data in reservationData) {
        try {
          final reservation = await _createIntelligentReservation(
            data['id'] as String,
            data['data'] as Map<String, dynamic>,
            providerId,
          );
          if (reservation != null) {
            allReservations.add(reservation);
          }
        } catch (e) {
          print(
            'UnifiedDataService: Error processing reservation ${data['id']}: $e',
          );
        }
      }

      // Remove duplicates and sort intelligently
      final uniqueReservations = _deduplicateReservations(allReservations);

      // Cache the results
      await _cacheReservations(uniqueReservations);

      // Update stream
      _reservationsStreamController.add(uniqueReservations);

      print(
        'UnifiedDataService: Intelligently fetched ${uniqueReservations.length} reservations',
      );

      return uniqueReservations;
    } catch (e) {
      print('UnifiedDataService: Error in intelligent fetch: $e');

      // Fallback to cache
      if (useCache) {
        final cachedReservations = await getCachedReservations();
        if (cachedReservations.isNotEmpty) {
          print(
            'UnifiedDataService: Falling back to ${cachedReservations.length} cached reservations',
          );
          return cachedReservations;
        }
      }

      throw Exception('Failed to fetch reservations: $e');
    } finally {
      _isFetching = false;
    }
  }

  /// Safely fetch reservation data to avoid threading issues
  Future<List<Map<String, dynamic>>> _fetchReservationDataSafely(
    String providerId,
  ) async {
    final reservationData = <Map<String, dynamic>>[];

    // Define all possible reservation paths
    final paths = [
      'serviceProviders/$providerId/confirmedReservations',
      'serviceProviders/$providerId/pendingReservations',
      'serviceProviders/$providerId/completedReservations',
      'serviceProviders/$providerId/cancelledReservations',
      'serviceProviders/$providerId/upcomingReservations',
    ];

    for (final path in paths) {
      try {
        final pathParts = path.split('/');
        if (pathParts.length >= 3) {
          // Use a simple query without complex constraints to avoid threading issues
          final snapshot =
              await _firestore
                  .collection(pathParts[0])
                  .doc(pathParts[1])
                  .collection(pathParts[2])
                  .limit(50) // Reasonable limit
                  .get();

          for (final doc in snapshot.docs) {
            if (!_processedReservationIds.contains(doc.id)) {
              _processedReservationIds.add(doc.id);
              reservationData.add({
                'id': doc.id,
                'data': doc.data(),
                'path': path,
              });
            }
          }

          print(
            'UnifiedDataService: Fetched ${snapshot.docs.length} from $path',
          );
        }
      } catch (e) {
        print('UnifiedDataService: Error fetching from $path: $e');
      }
    }

    // Also try collection group query
    try {
      final snapshot =
          await _firestore
              .collectionGroup('reservations')
              .where('providerId', isEqualTo: providerId)
              .limit(50)
              .get();

      for (final doc in snapshot.docs) {
        if (!_processedReservationIds.contains(doc.id)) {
          _processedReservationIds.add(doc.id);
          reservationData.add({
            'id': doc.id,
            'data': doc.data(),
            'path': 'collectionGroup',
          });
        }
      }

      print(
        'UnifiedDataService: Collection group found ${snapshot.docs.length} reservations',
      );
    } catch (e) {
      print('UnifiedDataService: Collection group error: $e');
    }

    return reservationData;
  }

  /// Create intelligent reservation from minimal data
  Future<Reservation?> _createIntelligentReservation(
    String id,
    Map<String, dynamic> data,
    String providerId,
  ) async {
    try {
      // Extract basic information
      final userId = data['userId'] as String? ?? '';
      final reservationId = data['reservationId'] as String? ?? id;

      // Intelligent user name resolution
      String userName = 'Unknown User';
      if (userId.isNotEmpty) {
        userName = await _getIntelligentUserName(userId);
      }

      // Intelligent date parsing
      final dateTime = _parseIntelligentDateTime(data);

      // Intelligent status determination
      final status = _determineIntelligentStatus(data, id);

      // Intelligent service name
      final serviceName = _determineIntelligentServiceName(data);

      // Create reservation with intelligent defaults
      return Reservation(
        id: id,
        userId: userId,
        userName: userName,
        providerId: providerId,
        serviceName: serviceName,
        serviceId: data['serviceId'] as String? ?? '',
        status: status,
        dateTime: dateTime,
        notes: data['notes'] as String? ?? '',
        type: _parseReservationType(data['type']),
        groupSize: data['groupSize'] as int? ?? 1,
        durationMinutes: data['durationMinutes'] as int? ?? 60,
      );
    } catch (e) {
      print('UnifiedDataService: Error creating intelligent reservation: $e');
      return null;
    }
  }

  /// Intelligent user name resolution with caching
  Future<String> _getIntelligentUserName(String userId) async {
    // Check cache first
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }

    // Try to fetch from Firestore (with error handling)
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(Duration(seconds: 3));

      if (userDoc.exists) {
        final userData = userDoc.data();
        final maxLength = userId.length < 8 ? userId.length : 8;
        final userName =
            userData?['name'] as String? ??
            userData?['displayName'] as String? ??
            userData?['userName'] as String? ??
            'User ${userId.substring(0, maxLength)}';

        _userNameCache[userId] = userName;
        return userName;
      }
    } catch (e) {
      print('UnifiedDataService: Error fetching user $userId: $e');
    }

    // Fallback to a readable user ID
    final maxLength = userId.length < 8 ? userId.length : 8;
    final fallbackName = 'User ${userId.substring(0, maxLength)}';
    _userNameCache[userId] = fallbackName;
    return fallbackName;
  }

  /// Intelligent date parsing from various possible fields
  Timestamp _parseIntelligentDateTime(Map<String, dynamic> data) {
    final possibleFields = [
      'timestamp',
      'dateTime',
      'reservationStartTime',
      'startTime',
      'createdAt',
      'cancelledAt',
      'scheduledTime',
      'bookingTime',
    ];

    for (final field in possibleFields) {
      final value = data[field];
      if (value != null) {
        try {
          if (value is Timestamp) {
            print(
              'UnifiedDataService: Found valid Timestamp in field $field: ${value.toDate()}',
            );
            return value;
          } else if (value is DateTime) {
            print(
              'UnifiedDataService: Found valid DateTime in field $field: $value',
            );
            return Timestamp.fromDate(value);
          } else if (value is String && value.isNotEmpty) {
            final parsedDate = DateTime.parse(value);
            print(
              'UnifiedDataService: Parsed string date from field $field: $parsedDate',
            );
            return Timestamp.fromDate(parsedDate);
          } else if (value is int) {
            // Handle Unix timestamp (seconds or milliseconds)
            final dateTime =
                value > 1000000000000
                    ? DateTime.fromMillisecondsSinceEpoch(value)
                    : DateTime.fromMillisecondsSinceEpoch(value * 1000);
            print(
              'UnifiedDataService: Parsed int timestamp from field $field: $dateTime',
            );
            return Timestamp.fromDate(dateTime);
          }
        } catch (e) {
          print(
            'UnifiedDataService: Failed to parse date from field $field: $value - $e',
          );
          continue;
        }
      }
    }

    print(
      'UnifiedDataService: No valid date found in data, using current time. Available fields: ${data.keys.toList()}',
    );
    return Timestamp.now();
  }

  /// Intelligent status determination
  String _determineIntelligentStatus(Map<String, dynamic> data, String docId) {
    // Check explicit status field
    if (data.containsKey('status') && data['status'] != null) {
      return data['status'] as String;
    }

    // Infer from document path or fields
    if (data.containsKey('cancelledAt')) {
      return 'cancelled';
    } else if (data.containsKey('completedAt')) {
      return 'completed';
    } else if (data.containsKey('confirmedAt')) {
      return 'confirmed';
    }

    // Default based on current time vs reservation time
    final dateTime = _parseIntelligentDateTime(data);
    final now = DateTime.now();
    final reservationTime = dateTime.toDate();

    if (reservationTime.isBefore(now)) {
      return 'completed';
    } else {
      return 'pending';
    }
  }

  /// Intelligent service name determination
  String _determineIntelligentServiceName(Map<String, dynamic> data) {
    final possibleFields = ['serviceName', 'service', 'name', 'title'];

    for (final field in possibleFields) {
      final value = data[field] as String?;
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return 'General Reservation';
  }

  /// Intelligent subscription fetching with throttling
  Future<List<Subscription>> fetchAllSubscriptions({
    bool useCache = true,
    bool forceRefresh = false,
  }) async {
    await _ensureInitialized();

    final providerId = _getCurrentProviderId();
    if (providerId == null) {
      throw Exception('Provider not authenticated');
    }

    // Check if we're already fetching or recently fetched
    if (_isFetching && !forceRefresh) {
      print('UnifiedDataService: Fetch in progress, returning cached data');
      return await getCachedSubscriptions();
    }

    final now = DateTime.now();
    if (_lastFetch != null &&
        now.difference(_lastFetch!) < _fetchCooldown &&
        !forceRefresh) {
      print('UnifiedDataService: Fetch throttled, returning cached data');
      return await getCachedSubscriptions();
    }

    // Return cached data if available and not forcing refresh
    if (useCache && !forceRefresh) {
      final cachedSubscriptions = await getCachedSubscriptions();
      if (cachedSubscriptions.isNotEmpty) {
        print(
          'UnifiedDataService: Returning ${cachedSubscriptions.length} cached subscriptions',
        );
        return cachedSubscriptions;
      }
    }

    _isFetching = true;
    _lastFetch = now;

    print('UnifiedDataService: Starting intelligent subscription fetch');

    try {
      final allSubscriptions = <Subscription>[];

      // Fetch subscription data safely with timeout
      final subscriptionData = await Future.any([
        _fetchSubscriptionDataSafely(providerId),
        Future.delayed(
          const Duration(seconds: 10),
          () => <Map<String, dynamic>>[],
        ),
      ]);

      // Process data intelligently
      for (final data in subscriptionData) {
        try {
          final subscription = await _createIntelligentSubscription(
            data['id'] as String,
            data['data'] as Map<String, dynamic>,
            providerId,
          );
          if (subscription != null) {
            allSubscriptions.add(subscription);
          }
        } catch (e) {
          print(
            'UnifiedDataService: Error processing subscription ${data['id']}: $e',
          );
        }
      }

      // Remove duplicates
      final uniqueSubscriptions = _deduplicateSubscriptions(allSubscriptions);

      // Cache the results
      await _cacheSubscriptions(uniqueSubscriptions);

      // Update stream
      _subscriptionsStreamController.add(uniqueSubscriptions);

      print(
        'UnifiedDataService: Intelligently fetched ${uniqueSubscriptions.length} subscriptions',
      );

      return uniqueSubscriptions;
    } catch (e) {
      print('UnifiedDataService: Error fetching subscriptions: $e');

      // Fallback to cache
      if (useCache) {
        final cachedSubscriptions = await getCachedSubscriptions();
        if (cachedSubscriptions.isNotEmpty) {
          print(
            'UnifiedDataService: Falling back to ${cachedSubscriptions.length} cached subscriptions',
          );
          return cachedSubscriptions;
        }
      }

      return [];
    } finally {
      _isFetching = false;
    }
  }

  /// Safely fetch subscription data with optimized queries
  Future<List<Map<String, dynamic>>> _fetchSubscriptionDataSafely(
    String providerId,
  ) async {
    final subscriptionData = <Map<String, dynamic>>[];

    // Limit to only active subscriptions to reduce load
    final paths = ['serviceProviders/$providerId/activeSubscriptions'];

    for (final path in paths) {
      try {
        final pathParts = path.split('/');
        if (pathParts.length >= 3) {
          // Use a smaller limit and add timeout
          final snapshot = await Future.any([
            _firestore
                .collection(pathParts[0])
                .doc(pathParts[1])
                .collection(pathParts[2])
                .limit(20) // Reduced from 50
                .get(),
            Future.delayed(
              const Duration(seconds: 5),
              () => throw Exception('Query timeout'),
            ),
          ]);

          for (final doc in snapshot.docs) {
            if (!_processedSubscriptionIds.contains(doc.id)) {
              _processedSubscriptionIds.add(doc.id);
              subscriptionData.add({
                'id': doc.id,
                'data': doc.data(),
                'path': path,
              });
            }
          }

          print(
            'UnifiedDataService: Fetched ${snapshot.docs.length} subscriptions from $path',
          );
        }
      } catch (e) {
        print(
          'UnifiedDataService: Error fetching subscriptions from $path: $e',
        );
      }
    }

    return subscriptionData;
  }

  /// Create intelligent subscription from data
  Future<Subscription?> _createIntelligentSubscription(
    String id,
    Map<String, dynamic> data,
    String providerId,
  ) async {
    try {
      final userId = data['userId'] as String? ?? '';

      // Intelligent user name resolution
      String userName = 'Unknown User';
      if (userId.isNotEmpty) {
        userName = await _getIntelligentUserName(userId);
      }

      // Intelligent plan name
      final planName =
          data['planName'] as String? ??
          data['plan'] as String? ??
          data['subscriptionType'] as String? ??
          'Membership Plan';

      // Intelligent status
      final status = data['status'] as String? ?? 'Active';

      // Intelligent dates
      final startDate = data['startDate'] as dynamic ?? Timestamp.now();
      final expiryDate =
          data['expiryDate'] as dynamic ??
          Timestamp.fromDate(DateTime.now().add(Duration(days: 30)));

      return Subscription(
        id: id,
        userId: userId,
        userName: userName,
        providerId: providerId,
        planName: planName,
        status: status,
        startDate: startDate,
        expiryDate: expiryDate,
        isAutoRenewal: data['autoRenew'] as bool? ?? false,
        pricePaid: (data['price'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      print('UnifiedDataService: Error creating intelligent subscription: $e');
      return null;
    }
  }

  /// Intelligent deduplication of reservations
  List<Reservation> _deduplicateReservations(List<Reservation> reservations) {
    final uniqueReservations = <String, Reservation>{};

    for (final reservation in reservations) {
      if (reservation.id != null && reservation.id!.isNotEmpty) {
        // Keep the most complete reservation if duplicates exist
        final existing = uniqueReservations[reservation.id!];
        if (existing == null ||
            _isMoreCompleteReservation(reservation, existing)) {
          uniqueReservations[reservation.id!] = reservation;
        }
      }
    }

    final result = uniqueReservations.values.toList();

    // Sort by date (newest first)
    result.sort((a, b) {
      try {
        final aDate =
            a.dateTime is Timestamp
                ? (a.dateTime as Timestamp).toDate()
                : a.dateTime as DateTime;
        final bDate =
            b.dateTime is Timestamp
                ? (b.dateTime as Timestamp).toDate()
                : b.dateTime as DateTime;
        return bDate.compareTo(aDate);
      } catch (e) {
        return 0;
      }
    });

    return result;
  }

  /// Check if one reservation is more complete than another
  bool _isMoreCompleteReservation(Reservation a, Reservation b) {
    int scoreA = 0;
    int scoreB = 0;

    // Score based on completeness
    if (a.userName != 'Unknown User') scoreA++;
    if (b.userName != 'Unknown User') scoreB++;

    if (a.serviceName != 'General Reservation') scoreA++;
    if (b.serviceName != 'General Reservation') scoreB++;

    if (a.notes?.isNotEmpty == true) scoreA++;
    if (b.notes?.isNotEmpty == true) scoreB++;

    return scoreA > scoreB;
  }

  /// Intelligent deduplication of subscriptions
  List<Subscription> _deduplicateSubscriptions(
    List<Subscription> subscriptions,
  ) {
    final uniqueSubscriptions = <String, Subscription>{};

    for (final subscription in subscriptions) {
      if (subscription.id != null && subscription.id!.isNotEmpty) {
        uniqueSubscriptions[subscription.id!] = subscription;
      }
    }

    final result = uniqueSubscriptions.values.toList();

    // Sort by expiry date (latest first)
    result.sort((a, b) {
      if (a.expiryDate == null && b.expiryDate == null) return 0;
      if (a.expiryDate == null) return 1;
      if (b.expiryDate == null) return -1;
      return b.expiryDate!.compareTo(a.expiryDate!);
    });

    return result;
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      // Close stream controllers
      await _reservationsStreamController.close();
      await _subscriptionsStreamController.close();

      _isInitialized = false;
      print('UnifiedDataService: Disposed successfully');
    } catch (e) {
      print('UnifiedDataService: Error during disposal: $e');
    }
  }

  // ==================== CACHE OPERATIONS ====================

  /// Fetch reservations from service provider subcollections
  Future<void> _fetchProviderReservations(
    String providerId,
    List<Reservation> allReservations,
    Map<String, DateTime> timeRange,
  ) async {
    final reservationPaths = DataPaths.getAllReservationPaths(providerId);

    for (final path in reservationPaths) {
      try {
        final pathParts = path.split('/');

        // Skip paths that don't have the expected subcollection structure
        if (pathParts.length < 3) {
          print(
            'UnifiedDataService: Skipping path with insufficient parts: $path',
          );
          continue;
        }

        print(
          'UnifiedDataService: Querying ${pathParts[0]}/${pathParts[1]}/${pathParts[2]}',
        );
        print(
          'UnifiedDataService: Date range: ${timeRange['pastDate']} to ${timeRange['futureDate']}',
        );

        // Try different query strategies to find data
        QuerySnapshot<Map<String, dynamic>>? snapshot;

        // Strategy 1: Try with expanded date constraints using multiple field names
        final dateFields = [
          'dateTime',
          'reservationStartTime',
          'startTime',
          'createdAt',
        ];

        for (final dateField in dateFields) {
          if (snapshot != null && snapshot.docs.isNotEmpty) break;

          try {
            // Use a much broader date range (2 years past, 2 years future)
            final broadPastDate = DateTime.now().subtract(
              const Duration(days: 730),
            );
            final broadFutureDate = DateTime.now().add(
              const Duration(days: 730),
            );

            final dateQuery = _firestore
                .collection(pathParts[0])
                .doc(pathParts[1])
                .collection(pathParts[2])
                .where(
                  dateField,
                  isGreaterThan: Timestamp.fromDate(broadPastDate),
                )
                .where(
                  dateField,
                  isLessThan: Timestamp.fromDate(broadFutureDate),
                )
                .limit(DataPaths.defaultQueryLimit);

            snapshot = await dateQuery.get();

            if (snapshot.docs.isNotEmpty) {
              print(
                'UnifiedDataService: Found ${snapshot.docs.length} documents with $dateField field',
              );
              break;
            }
          } catch (e) {
            print('UnifiedDataService: Error with $dateField query: $e');
          }
        }

        // Strategy 2: Try with provider ID filter (if available)
        if (snapshot == null || snapshot.docs.isEmpty) {
          try {
            final providerQuery = _firestore
                .collection(pathParts[0])
                .doc(pathParts[1])
                .collection(pathParts[2])
                .where('providerId', isEqualTo: providerId)
                .limit(DataPaths.defaultQueryLimit);

            snapshot = await providerQuery.get();

            if (snapshot.docs.isNotEmpty) {
              print(
                'UnifiedDataService: Found ${snapshot.docs.length} documents with providerId filter',
              );
            }
          } catch (e) {
            print('UnifiedDataService: Error with providerId query: $e');
          }
        }

        // Strategy 3: Try with status filter for active reservations
        if (snapshot == null || snapshot.docs.isEmpty) {
          try {
            final statusQuery = _firestore
                .collection(pathParts[0])
                .doc(pathParts[1])
                .collection(pathParts[2])
                .where(
                  'status',
                  whereIn: DataPaths.validReservationStatuses.take(10).toList(),
                )
                .limit(DataPaths.defaultQueryLimit);

            snapshot = await statusQuery.get();

            if (snapshot.docs.isNotEmpty) {
              print(
                'UnifiedDataService: Found ${snapshot.docs.length} documents with status filter',
              );
            }
          } catch (e) {
            print('UnifiedDataService: Error with status query: $e');
          }
        }

        // Strategy 4: If still no results, try without any constraints
        if (snapshot == null || snapshot.docs.isEmpty) {
          print(
            'UnifiedDataService: No results with constraints, trying without...',
          );
          try {
            final fallbackQuery = _firestore
                .collection(pathParts[0])
                .doc(pathParts[1])
                .collection(pathParts[2])
                .limit(DataPaths.defaultQueryLimit);

            snapshot = await fallbackQuery.get();
            print(
              'UnifiedDataService: Fallback query returned ${snapshot.docs.length} documents',
            );
          } catch (e) {
            print('UnifiedDataService: Error with fallback query: $e');
            continue; // Skip this path if all queries fail
          }
        }

        // Process the results with enhanced error handling and detail fetching
        for (final doc in snapshot.docs) {
          try {
            // Skip if already processed
            if (_processedReservationIds.contains(doc.id)) {
              continue;
            }
            _processedReservationIds.add(doc.id);

            final data = doc.data();

            // Log the document structure for debugging (less verbose)
            if (data.keys.length <= 5) {
              print(
                'UnifiedDataService: Processing reservation ${doc.id} with fields: ${data.keys.toList()}',
              );
            }

            // Ensure required fields exist or provide defaults
            final enhancedData = Map<String, dynamic>.from(data);

            // Enhanced detail fetching for incomplete reservations
            await _enhanceReservationDetails(enhancedData, doc.id, providerId);

            // Create reservation with enhanced data
            final reservation = Reservation(
              id: doc.id,
              userId: enhancedData['userId'] as String? ?? '',
              userName: enhancedData['userName'] as String? ?? 'Unknown User',
              providerId: providerId,
              serviceName:
                  enhancedData['serviceName'] as String? ??
                  'General Reservation',
              serviceId: enhancedData['serviceId'] as String? ?? '',
              status: enhancedData['status'] as String? ?? 'pending',
              dateTime: _parseDateTime(enhancedData),
              notes: enhancedData['notes'] as String? ?? '',
              type: _parseReservationType(enhancedData['type']),
              groupSize: enhancedData['groupSize'] as int? ?? 1,
              durationMinutes: enhancedData['durationMinutes'] as int? ?? 60,
            );

            allReservations.add(reservation);

            print(
              'UnifiedDataService: Successfully parsed reservation ${doc.id}: ${reservation.userName} - ${reservation.serviceName} on ${reservation.dateTime}',
            );
          } catch (e) {
            print(
              'UnifiedDataService: Error processing reservation ${doc.id}: $e',
            );
          }
        }

        print(
          'UnifiedDataService: Fetched ${snapshot.docs.length} reservations from $path',
        );
      } catch (e) {
        print('UnifiedDataService: Error fetching from $path: $e');
      }
    }
  }

  /// Fetch reservations using collection group queries
  Future<void> _fetchCollectionGroupReservations(
    String providerId,
    List<Reservation> allReservations,
    Map<String, DateTime> timeRange,
  ) async {
    try {
      QuerySnapshot<Map<String, dynamic>>? snapshot;

      // Strategy 1: Try with date constraints
      try {
        final dateQuery = _firestore
            .collectionGroup(DataPaths.reservationsCollectionGroup)
            .where('providerId', isEqualTo: providerId)
            .where(
              'dateTime',
              isGreaterThan: Timestamp.fromDate(timeRange['pastDate']!),
            )
            .where(
              'dateTime',
              isLessThan: Timestamp.fromDate(timeRange['futureDate']!),
            )
            .limit(DataPaths.defaultQueryLimit);

        snapshot = await dateQuery.get();

        if (snapshot.docs.isNotEmpty) {
          print(
            'UnifiedDataService: Collection group found ${snapshot.docs.length} reservations with date constraints',
          );
        }
      } catch (e) {
        print('UnifiedDataService: Error with collection group date query: $e');
      }

      // Strategy 2: If no results, try without date constraints
      if (snapshot == null || snapshot.docs.isEmpty) {
        try {
          final fallbackQuery = _firestore
              .collectionGroup(DataPaths.reservationsCollectionGroup)
              .where('providerId', isEqualTo: providerId)
              .limit(DataPaths.defaultQueryLimit);

          snapshot = await fallbackQuery.get();
          print(
            'UnifiedDataService: Collection group fallback found ${snapshot.docs.length} reservations',
          );
        } catch (e) {
          print(
            'UnifiedDataService: Error with collection group fallback query: $e',
          );
          return; // Exit if both strategies fail
        }
      }

      // Process the results with enhanced error handling and detail fetching
      if (snapshot != null) {
        for (final doc in snapshot.docs) {
          try {
            // Skip if already processed
            if (_processedReservationIds.contains(doc.id)) {
              continue;
            }
            _processedReservationIds.add(doc.id);

            final data = doc.data();

            // Log the document structure for debugging (less verbose)
            if (data.keys.length <= 5) {
              print(
                'UnifiedDataService: Processing collection group reservation ${doc.id} with fields: ${data.keys.toList()}',
              );
            }

            // Ensure required fields exist or provide defaults
            final enhancedData = Map<String, dynamic>.from(data);

            // Enhanced detail fetching for incomplete reservations
            await _enhanceReservationDetails(enhancedData, doc.id, providerId);

            // Create reservation with enhanced data
            final reservation = Reservation(
              id: doc.id,
              userId: enhancedData['userId'] as String? ?? '',
              userName: enhancedData['userName'] as String? ?? 'Unknown User',
              providerId: providerId,
              serviceName:
                  enhancedData['serviceName'] as String? ??
                  'General Reservation',
              serviceId: enhancedData['serviceId'] as String? ?? '',
              status: enhancedData['status'] as String? ?? 'pending',
              dateTime: _parseDateTime(enhancedData),
              notes: enhancedData['notes'] as String? ?? '',
              type: _parseReservationType(enhancedData['type']),
              groupSize: enhancedData['groupSize'] as int? ?? 1,
              durationMinutes: enhancedData['durationMinutes'] as int? ?? 60,
            );

            allReservations.add(reservation);

            print(
              'UnifiedDataService: Successfully parsed collection group reservation ${doc.id}: ${reservation.userName} - ${reservation.serviceName} on ${reservation.dateTime}',
            );
          } catch (e) {
            print(
              'UnifiedDataService: Error processing collection group reservation ${doc.id}: $e',
            );
          }
        }

        print(
          'UnifiedDataService: Fetched ${snapshot.docs.length} reservations from collection group',
        );
      }
    } catch (e) {
      print(
        'UnifiedDataService: Error fetching collection group reservations: $e',
      );
    }
  }

  /// Fetch reservations from legacy paths
  Future<void> _fetchLegacyReservations(
    String providerId,
    List<Reservation> allReservations,
    Map<String, DateTime> timeRange,
  ) async {
    try {
      // Handle legacy path: reservations/providerId (direct collection)
      final legacyPath = DataPaths.legacyReservationPath(providerId);
      final pathParts = legacyPath.split('/');

      if (pathParts.length == 2) {
        print('UnifiedDataService: Fetching from legacy path: $legacyPath');

        QuerySnapshot<Map<String, dynamic>>? snapshot;

        // Strategy 1: Try with date constraints
        try {
          final dateQuery = _firestore
              .collection(pathParts[0])
              .where('providerId', isEqualTo: providerId)
              .where(
                'dateTime',
                isGreaterThan: Timestamp.fromDate(timeRange['pastDate']!),
              )
              .where(
                'dateTime',
                isLessThan: Timestamp.fromDate(timeRange['futureDate']!),
              )
              .limit(DataPaths.defaultQueryLimit);

          snapshot = await dateQuery.get();

          if (snapshot.docs.isNotEmpty) {
            print(
              'UnifiedDataService: Legacy path found ${snapshot.docs.length} reservations with date constraints',
            );
          }
        } catch (e) {
          print('UnifiedDataService: Error with legacy date query: $e');
        }

        // Strategy 2: If no results, try without date constraints
        if (snapshot == null || snapshot.docs.isEmpty) {
          try {
            final fallbackQuery = _firestore
                .collection(pathParts[0])
                .where('providerId', isEqualTo: providerId)
                .limit(DataPaths.defaultQueryLimit);

            snapshot = await fallbackQuery.get();
            print(
              'UnifiedDataService: Legacy fallback found ${snapshot.docs.length} reservations',
            );
          } catch (e) {
            print('UnifiedDataService: Error with legacy fallback query: $e');
            return; // Exit if both strategies fail
          }
        }

        // Process the results with enhanced error handling and detail fetching
        if (snapshot != null) {
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();

              // Log the document structure for debugging (less verbose)
              if (data.keys.length <= 5) {
                print(
                  'UnifiedDataService: Processing legacy reservation ${doc.id} with fields: ${data.keys.toList()}',
                );
              }

              // Ensure required fields exist or provide defaults
              final enhancedData = Map<String, dynamic>.from(data);

              // Enhanced detail fetching for incomplete reservations
              await _enhanceReservationDetails(
                enhancedData,
                doc.id,
                providerId,
              );

              // Create reservation with enhanced data
              final reservation = Reservation(
                id: doc.id,
                userId: enhancedData['userId'] as String? ?? '',
                userName: enhancedData['userName'] as String? ?? 'Unknown User',
                providerId: providerId,
                serviceName:
                    enhancedData['serviceName'] as String? ??
                    'General Reservation',
                serviceId: enhancedData['serviceId'] as String? ?? '',
                status: enhancedData['status'] as String? ?? 'pending',
                dateTime: _parseDateTime(enhancedData),
                notes: enhancedData['notes'] as String? ?? '',
                type: _parseReservationType(enhancedData['type']),
                groupSize: enhancedData['groupSize'] as int? ?? 1,
                durationMinutes: enhancedData['durationMinutes'] as int? ?? 60,
              );

              allReservations.add(reservation);

              print(
                'UnifiedDataService: Successfully parsed legacy reservation ${doc.id}: ${reservation.userName} - ${reservation.serviceName} on ${reservation.dateTime}',
              );
            } catch (e) {
              print(
                'UnifiedDataService: Error processing legacy reservation ${doc.id}: $e',
              );
            }
          }

          print(
            'UnifiedDataService: Fetched ${snapshot.docs.length} reservations from legacy path',
          );
        }
      } else {
        print('UnifiedDataService: Invalid legacy path format: $legacyPath');
      }
    } catch (e) {
      print('UnifiedDataService: Error fetching legacy reservations: $e');
    }
  }

  /// Fetch subscriptions from service provider subcollections
  Future<void> _fetchProviderSubscriptions(
    String providerId,
    List<Subscription> allSubscriptions,
  ) async {
    final subscriptionPaths = DataPaths.getAllSubscriptionPaths(providerId);

    for (final path in subscriptionPaths) {
      try {
        final pathParts = path.split('/');

        // Skip paths that don't have the expected subcollection structure
        if (pathParts.length < 3) {
          print(
            'UnifiedDataService: Skipping subscription path with insufficient parts: $path',
          );
          continue;
        }

        print(
          'UnifiedDataService: Querying subscription path ${pathParts[0]}/${pathParts[1]}/${pathParts[2]}',
        );

        QuerySnapshot<Map<String, dynamic>>? snapshot;

        // Strategy 1: Try with provider ID filter
        try {
          final providerQuery = _firestore
              .collection(pathParts[0])
              .doc(pathParts[1])
              .collection(pathParts[2])
              .where('providerId', isEqualTo: providerId)
              .limit(DataPaths.defaultQueryLimit);

          snapshot = await providerQuery.get();

          if (snapshot.docs.isNotEmpty) {
            print(
              'UnifiedDataService: Found ${snapshot.docs.length} subscriptions with providerId filter',
            );
          }
        } catch (e) {
          print(
            'UnifiedDataService: Error with subscription providerId query: $e',
          );
        }

        // Strategy 2: Try with status filter for valid statuses
        if (snapshot == null || snapshot.docs.isEmpty) {
          try {
            final statusQuery = _firestore
                .collection(pathParts[0])
                .doc(pathParts[1])
                .collection(pathParts[2])
                .where(
                  'status',
                  whereIn:
                      DataPaths.validSubscriptionStatuses.take(10).toList(),
                )
                .limit(DataPaths.defaultQueryLimit);

            snapshot = await statusQuery.get();

            if (snapshot.docs.isNotEmpty) {
              print(
                'UnifiedDataService: Found ${snapshot.docs.length} subscriptions with status filter',
              );
            }
          } catch (e) {
            print(
              'UnifiedDataService: Error with subscription status query: $e',
            );
          }
        }

        // Strategy 3: Try with expiry date filter (not expired)
        if (snapshot == null || snapshot.docs.isEmpty) {
          try {
            final expiryQuery = _firestore
                .collection(pathParts[0])
                .doc(pathParts[1])
                .collection(pathParts[2])
                .where('expiryDate', isGreaterThan: Timestamp.now())
                .limit(DataPaths.defaultQueryLimit);

            snapshot = await expiryQuery.get();

            if (snapshot.docs.isNotEmpty) {
              print(
                'UnifiedDataService: Found ${snapshot.docs.length} subscriptions with expiry filter',
              );
            }
          } catch (e) {
            print(
              'UnifiedDataService: Error with subscription expiry query: $e',
            );
          }
        }

        // Strategy 4: If no results, try without any filter
        if (snapshot == null || snapshot.docs.isEmpty) {
          try {
            final fallbackQuery = _firestore
                .collection(pathParts[0])
                .doc(pathParts[1])
                .collection(pathParts[2])
                .limit(DataPaths.defaultQueryLimit);

            snapshot = await fallbackQuery.get();
            print(
              'UnifiedDataService: Subscription fallback found ${snapshot.docs.length} documents',
            );
          } catch (e) {
            print(
              'UnifiedDataService: Error with subscription fallback query: $e',
            );
            continue; // Skip this path if all queries fail
          }
        }

        // Process the results with enhanced error handling
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();

            // Log the document structure for debugging
            print(
              'UnifiedDataService: Processing subscription ${doc.id} with fields: ${data.keys.toList()}',
            );

            // Ensure required fields exist or provide defaults
            final enhancedData = Map<String, dynamic>.from(data);

            // Ensure userName exists
            if (!enhancedData.containsKey('userName') ||
                enhancedData['userName'] == null) {
              enhancedData['userName'] =
                  enhancedData['displayName'] ??
                  enhancedData['name'] ??
                  'Unknown User';
            }

            // Ensure planName exists
            if (!enhancedData.containsKey('planName') ||
                enhancedData['planName'] == null) {
              enhancedData['planName'] =
                  enhancedData['plan'] ??
                  enhancedData['subscriptionType'] ??
                  'Unknown Plan';
            }

            // Ensure status exists
            if (!enhancedData.containsKey('status') ||
                enhancedData['status'] == null) {
              enhancedData['status'] = 'Active';
            }

            // Ensure startDate exists
            if (!enhancedData.containsKey('startDate') ||
                enhancedData['startDate'] == null) {
              enhancedData['startDate'] =
                  enhancedData['createdAt'] ??
                  enhancedData['subscriptionDate'] ??
                  Timestamp.now();
            }

            // Ensure providerId exists
            if (!enhancedData.containsKey('providerId') ||
                enhancedData['providerId'] == null) {
              enhancedData['providerId'] = providerId;
            }

            final subscription = Subscription.fromMap(doc.id, enhancedData);
            allSubscriptions.add(subscription);

            print(
              'UnifiedDataService: Successfully parsed subscription ${doc.id}: ${subscription.userName} - ${subscription.planName} (${subscription.status})',
            );
          } catch (e) {
            print(
              'UnifiedDataService: Error parsing subscription ${doc.id}: $e',
            );
            print('UnifiedDataService: Document data: ${doc.data()}');
          }
        }

        print(
          'UnifiedDataService: Fetched ${snapshot.docs.length} subscriptions from $path',
        );
      } catch (e) {
        print('UnifiedDataService: Error fetching from $path: $e');
      }
    }
  }

  /// Fetch subscriptions using collection group queries
  Future<void> _fetchCollectionGroupSubscriptions(
    String providerId,
    List<Subscription> allSubscriptions,
  ) async {
    try {
      QuerySnapshot<Map<String, dynamic>>? snapshot;

      // Strategy 1: Try with provider ID and status filter
      try {
        final statusQuery = _firestore
            .collectionGroup(DataPaths.subscriptionsCollectionGroup)
            .where('providerId', isEqualTo: providerId)
            .where(
              'status',
              whereIn: DataPaths.validSubscriptionStatuses.take(10).toList(),
            )
            .limit(DataPaths.defaultQueryLimit);

        snapshot = await statusQuery.get();

        if (snapshot.docs.isNotEmpty) {
          print(
            'UnifiedDataService: Collection group found ${snapshot.docs.length} subscriptions with status filter',
          );
        }
      } catch (e) {
        print(
          'UnifiedDataService: Error with collection group subscription status query: $e',
        );
      }

      // Strategy 2: Try with just provider ID filter
      if (snapshot == null || snapshot.docs.isEmpty) {
        try {
          final providerQuery = _firestore
              .collectionGroup(DataPaths.subscriptionsCollectionGroup)
              .where('providerId', isEqualTo: providerId)
              .limit(DataPaths.defaultQueryLimit);

          snapshot = await providerQuery.get();
          print(
            'UnifiedDataService: Collection group subscription fallback found ${snapshot.docs.length} documents',
          );
        } catch (e) {
          print(
            'UnifiedDataService: Error with collection group subscription fallback query: $e',
          );
          return; // Exit if both strategies fail
        }
      }

      // Process the results with enhanced error handling
      if (snapshot != null) {
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();

            // Log the document structure for debugging
            print(
              'UnifiedDataService: Processing collection group subscription ${doc.id} with fields: ${data.keys.toList()}',
            );

            // Ensure required fields exist or provide defaults
            final enhancedData = Map<String, dynamic>.from(data);

            // Ensure userName exists
            if (!enhancedData.containsKey('userName') ||
                enhancedData['userName'] == null) {
              enhancedData['userName'] =
                  enhancedData['displayName'] ??
                  enhancedData['name'] ??
                  'Unknown User';
            }

            // Ensure planName exists
            if (!enhancedData.containsKey('planName') ||
                enhancedData['planName'] == null) {
              enhancedData['planName'] =
                  enhancedData['plan'] ??
                  enhancedData['subscriptionType'] ??
                  'Unknown Plan';
            }

            // Ensure status exists
            if (!enhancedData.containsKey('status') ||
                enhancedData['status'] == null) {
              enhancedData['status'] = 'Active';
            }

            // Ensure startDate exists
            if (!enhancedData.containsKey('startDate') ||
                enhancedData['startDate'] == null) {
              enhancedData['startDate'] =
                  enhancedData['createdAt'] ??
                  enhancedData['subscriptionDate'] ??
                  Timestamp.now();
            }

            // Ensure providerId exists
            if (!enhancedData.containsKey('providerId') ||
                enhancedData['providerId'] == null) {
              enhancedData['providerId'] = providerId;
            }

            final subscription = Subscription.fromMap(doc.id, enhancedData);
            allSubscriptions.add(subscription);

            print(
              'UnifiedDataService: Successfully parsed collection group subscription ${doc.id}: ${subscription.userName} - ${subscription.planName} (${subscription.status})',
            );
          } catch (e) {
            print(
              'UnifiedDataService: Error parsing collection group subscription ${doc.id}: $e',
            );
            print('UnifiedDataService: Document data: ${doc.data()}');
          }
        }

        print(
          'UnifiedDataService: Fetched ${snapshot.docs.length} subscriptions from collection group',
        );
      }
    } catch (e) {
      print(
        'UnifiedDataService: Error fetching collection group subscriptions: $e',
      );
    }
  }

  // ==================== CACHE OPERATIONS ====================

  /// Get cached reservations
  Future<List<Reservation>> getCachedReservations() async {
    await _ensureInitialized();

    try {
      if (Hive.isBoxOpen('cachedReservationsBox')) {
        final box = Hive.box<CachedReservation>('cachedReservationsBox');
        final cachedReservations = box.values.toList();
        final reservations = _convertCachedReservationsToReservations(
          cachedReservations,
        );

        // Update stream
        _reservationsStreamController.add(reservations);

        return reservations;
      }
      return [];
    } catch (e) {
      print('UnifiedDataService: Error getting cached reservations: $e');
      return [];
    }
  }

  /// Get cached subscriptions
  Future<List<Subscription>> getCachedSubscriptions() async {
    await _ensureInitialized();

    try {
      if (Hive.isBoxOpen('cachedSubscriptionsBox')) {
        final box = Hive.box<CachedSubscription>('cachedSubscriptionsBox');
        final cachedSubscriptions = box.values.toList();
        final subscriptions = _convertCachedSubscriptionsToSubscriptions(
          cachedSubscriptions,
        );

        // Update stream
        _subscriptionsStreamController.add(subscriptions);

        return subscriptions;
      }
      return [];
    } catch (e) {
      print('UnifiedDataService: Error getting cached subscriptions: $e');
      return [];
    }
  }

  /// Cache reservations
  Future<void> _cacheReservations(List<Reservation> reservations) async {
    await _ensureInitialized();

    try {
      if (Hive.isBoxOpen('cachedReservationsBox')) {
        final box = Hive.box<CachedReservation>('cachedReservationsBox');

        // Cache new reservations
        for (final reservation in reservations) {
          final cachedReservation = _convertReservationToCached(reservation);
          if (cachedReservation != null) {
            await box.put(reservation.id, cachedReservation);
          }
        }

        print('UnifiedDataService: Cached ${reservations.length} reservations');
      }
    } catch (e) {
      print('UnifiedDataService: Error caching reservations: $e');
    }
  }

  /// Cache subscriptions
  Future<void> _cacheSubscriptions(List<Subscription> subscriptions) async {
    await _ensureInitialized();

    try {
      if (Hive.isBoxOpen('cachedSubscriptionsBox')) {
        final box = Hive.box<CachedSubscription>('cachedSubscriptionsBox');

        // Cache new subscriptions
        for (final subscription in subscriptions) {
          final cachedSubscription = _convertSubscriptionToCached(subscription);
          if (cachedSubscription != null) {
            await box.put(subscription.id, cachedSubscription);
          }
        }

        print(
          'UnifiedDataService: Cached ${subscriptions.length} subscriptions',
        );
      }
    } catch (e) {
      print('UnifiedDataService: Error caching subscriptions: $e');
    }
  }

  // ==================== USER OPERATIONS ====================

  /// Find active reservation for a user with intelligent status checking
  Future<CachedReservation?> findActiveReservation(
    String userId, {
    String? statusFilter,
  }) async {
    await _ensureInitialized();

    try {
      if (!Hive.isBoxOpen('cachedReservationsBox')) return null;

      final box = Hive.box<CachedReservation>('cachedReservationsBox');
      final userReservations =
          box.values.where((res) => res.userId == userId).toList();

      if (userReservations.isEmpty) return null;

      // Filter by status if provided
      final filteredReservations =
          statusFilter != null
              ? userReservations
                  .where(
                    (res) =>
                        res.status.toLowerCase() == statusFilter.toLowerCase(),
                  )
                  .toList()
              : userReservations;

      // Sort by priority and find the best active reservation
      filteredReservations.sort((a, b) {
        final priorityA = _statusService.getStatusPriority(a.status);
        final priorityB = _statusService.getStatusPriority(b.status);
        if (priorityA != priorityB) return priorityA.compareTo(priorityB);

        // If same priority, prefer closer to current time
        final now = DateTime.now();
        final diffA = (a.startTime.difference(now)).abs();
        final diffB = (b.startTime.difference(now)).abs();
        return diffA.compareTo(diffB);
      });

      // Find the best active reservation using intelligent status checking
      for (final reservation in filteredReservations) {
        // Convert to Reservation model for intelligent checking
        final reservationModel = Reservation(
          id: reservation.reservationId,
          userId: reservation.userId,
          userName: 'User', // Placeholder
          providerId: _getCurrentProviderId() ?? '',
          status: reservation.status,
          dateTime: Timestamp.fromDate(reservation.startTime),
          serviceName: reservation.serviceName,
          serviceId: '',
          notes: '',
          type: ReservationType.unknown,
          groupSize: reservation.groupSize,
          durationMinutes:
              reservation.endTime.difference(reservation.startTime).inMinutes,
        );

        final accessDecision = _statusService.getReservationAccessDecision(
          reservationModel,
        );
        if (accessDecision.hasAccess) {
          return reservation;
        }
      }

      return null;
    } catch (e) {
      print('UnifiedDataService: Error finding active reservation: $e');
      return null;
    }
  }

  /// Find active subscription for a user
  Future<CachedSubscription?> findActiveSubscription(String userId) async {
    await _ensureInitialized();

    try {
      if (!Hive.isBoxOpen('cachedSubscriptionsBox')) return null;

      final box = Hive.box<CachedSubscription>('cachedSubscriptionsBox');
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final userSubscriptions =
          box.values.where((sub) => sub.userId == userId).toList();

      if (userSubscriptions.isEmpty) return null;

      // Find active subscriptions (not expired)
      final activeSubscriptions =
          userSubscriptions
              .where((sub) => !sub.expiryDate.isBefore(startOfDay))
              .toList();

      if (activeSubscriptions.isNotEmpty) {
        // Sort by expiry date (latest first)
        activeSubscriptions.sort(
          (a, b) => b.expiryDate.compareTo(a.expiryDate),
        );
        return activeSubscriptions.first;
      }

      return null;
    } catch (e) {
      print('UnifiedDataService: Error finding active subscription: $e');
      return null;
    }
  }

  // ==================== HELPER METHODS ====================

  /// Ensure the service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Get current provider ID
  String? _getCurrentProviderId() {
    return _auth.currentUser?.uid;
  }

  /// Remove duplicate reservations based on ID
  List<Reservation> _removeDuplicateReservations(
    List<Reservation> reservations,
  ) {
    final seen = <String>{};
    return reservations.where((reservation) {
      if (reservation.id == null) return false;
      return seen.add(reservation.id!);
    }).toList();
  }

  /// Remove duplicate subscriptions based on ID
  List<Subscription> _removeDuplicateSubscriptions(
    List<Subscription> subscriptions,
  ) {
    final seen = <String>{};
    return subscriptions.where((subscription) {
      if (subscription.id == null) return false;
      return seen.add(subscription.id!);
    }).toList();
  }

  /// Build subscription from Firestore document
  Future<Subscription?> _buildSubscriptionFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String providerId,
  ) async {
    try {
      final data = doc.data();
      final userId = data['userId'] as String?;

      if (userId == null) return null;

      // Get user name
      String userName = 'Unknown User';
      try {
        final userDoc =
            await _firestore.collection('endUsers').doc(userId).get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          userName =
              userData['displayName'] ??
              userData['name'] ??
              userData['userName'] ??
              'Unknown User';
        }
      } catch (e) {
        print(
          'UnifiedDataService: Error fetching user data for subscription: $e',
        );
      }

      return Subscription(
        id: doc.id,
        userId: userId,
        userName: userName,
        providerId: providerId,
        planName: data['planName'] as String? ?? 'Membership Plan',
        status: data['status'] as String? ?? 'Active',
        startDate: data['startDate'] as dynamic ?? Timestamp.now(),
        expiryDate: data['expiryDate'] as dynamic,
        isAutoRenewal: data['autoRenew'] as bool? ?? false,
        pricePaid:
            (data['price'] as num?)?.toDouble() ??
            (data['amount'] as num?)?.toDouble() ??
            0.0,
      );
    } catch (e) {
      print('UnifiedDataService: Error building subscription from doc: $e');
      return null;
    }
  }

  /// Convert cached reservations to reservation models
  List<Reservation> _convertCachedReservationsToReservations(
    List<CachedReservation> cachedReservations,
  ) {
    return cachedReservations.map((cached) {
      return Reservation(
        id: cached.reservationId,
        userId: cached.userId,
        userName: 'Unknown User', // Will be populated from user cache if needed
        providerId: _getCurrentProviderId() ?? '',
        status: cached.status,
        dateTime: Timestamp.fromDate(cached.startTime),
        serviceName: cached.serviceName,
        serviceId: '',
        notes: '',
        type: _convertReservationType(cached.typeString),
        groupSize: cached.groupSize,
        durationMinutes: cached.endTime.difference(cached.startTime).inMinutes,
      );
    }).toList();
  }

  /// Convert string to dashboard ReservationType
  ReservationType _convertReservationType(String typeString) {
    switch (typeString.toLowerCase()) {
      case 'timebased':
      case 'time_based':
      case 'time':
        return ReservationType.timeBased;
      case 'servicebased':
      case 'service_based':
      case 'service':
        return ReservationType.serviceBased;
      case 'seatbased':
      case 'seat_based':
      case 'seat':
        return ReservationType.seatBased;
      case 'recurring':
        return ReservationType.recurring;
      case 'group':
        return ReservationType.group;
      case 'accessbased':
      case 'access_based':
      case 'access':
        return ReservationType.accessBased;
      case 'sequencebased':
      case 'sequence_based':
      case 'sequence':
        return ReservationType.sequenceBased;
      default:
        return ReservationType.unknown;
    }
  }

  /// Convert cached subscriptions to subscription models
  List<Subscription> _convertCachedSubscriptionsToSubscriptions(
    List<CachedSubscription> cachedSubscriptions,
  ) {
    return cachedSubscriptions.map((cached) {
      return Subscription(
        id: cached.subscriptionId,
        userId: cached.userId,
        userName: 'Unknown User', // Will be populated from user cache if needed
        providerId: _getCurrentProviderId() ?? '',
        planName: cached.planName,
        status: 'Active',
        startDate: Timestamp.now(),
        expiryDate: Timestamp.fromDate(cached.expiryDate),
        isAutoRenewal: false,
        pricePaid: 0.0,
      );
    }).toList();
  }

  /// Convert reservation to cached format
  CachedReservation? _convertReservationToCached(Reservation reservation) {
    try {
      if (reservation.id == null || reservation.userId == null) return null;

      DateTime startTime;
      DateTime endTime;

      // Handle dateTime conversion
      if (reservation.dateTime is Timestamp) {
        startTime = (reservation.dateTime as Timestamp).toDate();
      } else if (reservation.dateTime is DateTime) {
        startTime = reservation.dateTime as DateTime;
      } else {
        startTime = DateTime.now();
      }

      // Handle endTime conversion
      if (reservation.endTime != null) {
        if (reservation.endTime is Timestamp) {
          endTime = (reservation.endTime as Timestamp).toDate();
        } else if (reservation.endTime is DateTime) {
          endTime = reservation.endTime as DateTime;
        } else {
          endTime = startTime.add(const Duration(hours: 1));
        }
      } else {
        endTime = startTime.add(const Duration(hours: 1));
      }

      return CachedReservation(
        userId: reservation.userId!,
        reservationId: reservation.id!,
        serviceName: reservation.serviceName ?? 'Unnamed Service',
        startTime: startTime,
        endTime: endTime,
        typeString: reservation.type.toString().split('.').last,
        groupSize: reservation.groupSize ?? 1,
        status: reservation.status,
      );
    } catch (e) {
      print('UnifiedDataService: Error converting reservation to cached: $e');
      return null;
    }
  }

  /// Convert subscription to cached format
  CachedSubscription? _convertSubscriptionToCached(Subscription subscription) {
    try {
      if (subscription.id == null || subscription.userId == null) return null;

      DateTime expiryDate;
      if (subscription.expiryDate != null) {
        if (subscription.expiryDate is Timestamp) {
          expiryDate = (subscription.expiryDate as Timestamp).toDate();
        } else if (subscription.expiryDate is DateTime) {
          expiryDate = subscription.expiryDate as DateTime;
        } else {
          expiryDate = DateTime.now().add(const Duration(days: 30));
        }
      } else {
        expiryDate = DateTime.now().add(const Duration(days: 30));
      }

      return CachedSubscription(
        userId: subscription.userId!,
        subscriptionId: subscription.id!,
        planName: subscription.planName ?? 'Membership',
        expiryDate: expiryDate,
      );
    } catch (e) {
      print('UnifiedDataService: Error converting subscription to cached: $e');
      return null;
    }
  }

  /// Enhance reservation details by fetching missing information
  Future<void> _enhanceReservationDetails(
    Map<String, dynamic> data,
    String reservationId,
    String providerId,
  ) async {
    try {
      // Ensure userName exists - use cache first
      if (!data.containsKey('userName') ||
          data['userName'] == null ||
          data['userName'] == 'Unknown User') {
        final userId = data['userId'] as String?;
        if (userId != null && userId.isNotEmpty) {
          // Check cache first
          if (_userNameCache.containsKey(userId)) {
            data['userName'] = _userNameCache[userId];
          } else {
            // Try to fetch from users collection
            try {
              final userDoc =
                  await _firestore.collection('users').doc(userId).get();
              if (userDoc.exists) {
                final userData = userDoc.data();
                final userName =
                    userData?['name'] as String? ??
                    userData?['displayName'] as String? ??
                    userData?['userName'] as String? ??
                    'User $userId';
                data['userName'] = userName;
                _userNameCache[userId] = userName;
              } else {
                data['userName'] = 'User $userId';
                _userNameCache[userId] = 'User $userId';
              }
            } catch (e) {
              data['userName'] = 'User $userId';
              _userNameCache[userId] = 'User $userId';
            }
          }
        } else {
          data['userName'] = 'Unknown User';
        }
      }

      // Ensure dateTime exists with fallback fields
      if (!data.containsKey('dateTime') || data['dateTime'] == null) {
        data['dateTime'] =
            data['reservationStartTime'] ??
            data['startTime'] ??
            data['timestamp'] ??
            data['createdAt'] ??
            Timestamp.now();
      }

      // Ensure status exists - infer from collection path if missing
      if (!data.containsKey('status') || data['status'] == null) {
        // Try to infer status from the reservation ID or other fields
        if (data.containsKey('cancelledAt')) {
          data['status'] = 'cancelled';
        } else if (data.containsKey('completedAt')) {
          data['status'] = 'completed';
        } else if (data.containsKey('confirmedAt')) {
          data['status'] = 'confirmed';
        } else {
          data['status'] = 'pending';
        }
      }

      // Ensure serviceName exists - use cache first
      if (!data.containsKey('serviceName') ||
          data['serviceName'] == null ||
          data['serviceName'] == 'Unknown Service') {
        final serviceId = data['serviceId'] as String?;
        if (serviceId != null && serviceId.isNotEmpty) {
          // Check cache first
          if (_serviceNameCache.containsKey(serviceId)) {
            data['serviceName'] = _serviceNameCache[serviceId];
          } else {
            // Try to fetch from services collection
            try {
              final serviceDoc =
                  await _firestore
                      .collection('serviceProviders')
                      .doc(providerId)
                      .collection('services')
                      .doc(serviceId)
                      .get();

              if (serviceDoc.exists) {
                final serviceData = serviceDoc.data();
                final serviceName =
                    serviceData?['name'] as String? ??
                    serviceData?['serviceName'] as String? ??
                    'General Reservation';
                data['serviceName'] = serviceName;
                _serviceNameCache[serviceId] = serviceName;
              } else {
                data['serviceName'] = 'General Reservation';
                _serviceNameCache[serviceId] = 'General Reservation';
              }
            } catch (e) {
              data['serviceName'] = 'General Reservation';
              _serviceNameCache[serviceId] = 'General Reservation';
            }
          }
        } else {
          data['serviceName'] = 'General Reservation';
        }
      }

      // Ensure providerId exists
      if (!data.containsKey('providerId') || data['providerId'] == null) {
        data['providerId'] = providerId;
      }

      // Ensure other required fields have defaults
      data['notes'] ??= '';
      data['groupSize'] ??= 1;
      data['durationMinutes'] ??= 60;
      data['serviceId'] ??= '';
    } catch (e) {
      print(
        'UnifiedDataService: Error enhancing reservation details for $reservationId: $e',
      );
    }
  }

  /// Parse date time from various possible fields
  Timestamp _parseDateTime(Map<String, dynamic> data) {
    try {
      final possibleFields = [
        'dateTime',
        'reservationStartTime',
        'startTime',
        'timestamp',
        'createdAt',
        'scheduledTime',
        'bookingTime',
      ];

      for (final field in possibleFields) {
        final dateTimeValue = data[field];

        if (dateTimeValue is Timestamp) {
          print(
            'UnifiedDataService: _parseDateTime found Timestamp in $field: ${dateTimeValue.toDate()}',
          );
          return dateTimeValue;
        } else if (dateTimeValue is DateTime) {
          print(
            'UnifiedDataService: _parseDateTime found DateTime in $field: $dateTimeValue',
          );
          return Timestamp.fromDate(dateTimeValue);
        } else if (dateTimeValue is String && dateTimeValue.isNotEmpty) {
          try {
            final parsedDate = DateTime.parse(dateTimeValue);
            print(
              'UnifiedDataService: _parseDateTime parsed string in $field: $parsedDate',
            );
            return Timestamp.fromDate(parsedDate);
          } catch (e) {
            print(
              'UnifiedDataService: _parseDateTime failed to parse string in $field: $dateTimeValue',
            );
            continue;
          }
        } else if (dateTimeValue is int) {
          try {
            final dateTime =
                dateTimeValue > 1000000000000
                    ? DateTime.fromMillisecondsSinceEpoch(dateTimeValue)
                    : DateTime.fromMillisecondsSinceEpoch(dateTimeValue * 1000);
            print(
              'UnifiedDataService: _parseDateTime parsed int in $field: $dateTime',
            );
            return Timestamp.fromDate(dateTime);
          } catch (e) {
            print(
              'UnifiedDataService: _parseDateTime failed to parse int in $field: $dateTimeValue',
            );
            continue;
          }
        }
      }

      print(
        'UnifiedDataService: _parseDateTime no valid date found, using current time. Available fields: ${data.keys.toList()}',
      );
      return Timestamp.now();
    } catch (e) {
      print('UnifiedDataService: _parseDateTime error: $e');
      return Timestamp.now();
    }
  }

  /// Parse end time
  DateTime _parseEndTime(Map<String, dynamic> data) {
    // Implement the logic to parse end time based on the data
    // This is a placeholder and should be replaced with the actual implementation
    return DateTime.now();
  }

  /// Parse reservation type from string or enum
  ReservationType _parseReservationType(dynamic type) {
    if (type == null) return ReservationType.unknown;

    if (type is ReservationType) return type;

    final typeString = type.toString().toLowerCase();

    switch (typeString) {
      case 'timebased':
      case 'time_based':
      case 'time':
        return ReservationType.timeBased;
      case 'servicebased':
      case 'service_based':
      case 'service':
        return ReservationType.serviceBased;
      case 'seatbased':
      case 'seat_based':
      case 'seat':
        return ReservationType.seatBased;
      case 'recurring':
        return ReservationType.recurring;
      case 'group':
        return ReservationType.group;
      case 'accessbased':
      case 'access_based':
      case 'access':
        return ReservationType.accessBased;
      case 'sequencebased':
      case 'sequence_based':
      case 'sequence':
        return ReservationType.sequenceBased;
      default:
        return ReservationType.unknown;
    }
  }
}

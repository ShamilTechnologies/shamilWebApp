/// Unified Data Orchestrator Service
///
/// This service centralizes all data operations to prevent multiple fetches
/// from different sources and provides a single source of truth for all data.
/// It handles classification, enrichment, caching, and state management.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

import '../constants/data_paths.dart';
import '../../features/access_control/data/local_cache_models.dart';
import '../../features/dashboard/data/dashboard_models.dart';
import '../../features/dashboard/data/user_models.dart';
import 'status_management_service.dart';

/// Unified data state for the entire application
class UnifiedDataState {
  final List<ClassifiedReservation> reservations;
  final List<ClassifiedSubscription> subscriptions;
  final List<EnrichedUser> users;
  final List<AccessLog> accessLogs;
  final DateTime lastUpdated;
  final bool isLoading;
  final String? error;

  const UnifiedDataState({
    this.reservations = const [],
    this.subscriptions = const [],
    this.users = const [],
    this.accessLogs = const [],
    required this.lastUpdated,
    this.isLoading = false,
    this.error,
  });

  UnifiedDataState copyWith({
    List<ClassifiedReservation>? reservations,
    List<ClassifiedSubscription>? subscriptions,
    List<EnrichedUser>? users,
    List<AccessLog>? accessLogs,
    DateTime? lastUpdated,
    bool? isLoading,
    String? error,
  }) {
    return UnifiedDataState(
      reservations: reservations ?? this.reservations,
      subscriptions: subscriptions ?? this.subscriptions,
      users: users ?? this.users,
      accessLogs: accessLogs ?? this.accessLogs,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Enhanced reservation with classification and enrichment
class ClassifiedReservation extends Reservation {
  final ReservationCategory category;
  final AccessStatus accessStatus;
  final String enrichedUserName;
  final String enrichedServiceName;
  final DateTime? enrichedStartTime;
  final DateTime? enrichedEndTime;
  final Map<String, dynamic> metadata;

  ClassifiedReservation({
    required super.id,
    required super.userId,
    required super.userName,
    required super.providerId,
    required super.serviceName,
    required super.serviceId,
    required super.status,
    required super.dateTime,
    required super.notes,
    required super.type,
    required super.groupSize,
    required super.durationMinutes,
    required this.category,
    required this.accessStatus,
    required this.enrichedUserName,
    required this.enrichedServiceName,
    this.enrichedStartTime,
    this.enrichedEndTime,
    this.metadata = const {},
  });
}

/// Enhanced subscription with classification and enrichment
class ClassifiedSubscription extends Subscription {
  final SubscriptionCategory category;
  final AccessStatus accessStatus;
  final String enrichedUserName;
  final String enrichedPlanName;
  final DateTime? enrichedStartDate;
  final DateTime? enrichedExpiryDate;
  final Map<String, dynamic> metadata;

  ClassifiedSubscription({
    required super.id,
    required super.userId,
    required super.userName,
    required super.providerId,
    required super.planName,
    required super.status,
    required super.startDate,
    required super.expiryDate,
    required super.isAutoRenewal,
    required super.pricePaid,
    required this.category,
    required this.accessStatus,
    required this.enrichedUserName,
    required this.enrichedPlanName,
    this.enrichedStartDate,
    this.enrichedExpiryDate,
    this.metadata = const {},
  });
}

/// Enhanced user with all related data
class EnrichedUser {
  final String userId;
  final String name;
  final String accessType;
  final String? email;
  final String? phone;
  final String? profilePicUrl;
  final UserType? userType;
  final List<RelatedRecord> relatedRecords;
  final List<ClassifiedReservation> reservations;
  final List<ClassifiedSubscription> subscriptions;
  final UserAccessLevel accessLevel;
  final DateTime? lastActivity;
  final Map<String, dynamic> metadata;

  EnrichedUser({
    required this.userId,
    required this.name,
    required this.accessType,
    this.email,
    this.phone,
    this.profilePicUrl,
    this.userType,
    this.relatedRecords = const [],
    this.reservations = const [],
    this.subscriptions = const [],
    required this.accessLevel,
    this.lastActivity,
    this.metadata = const {},
  });
}

/// Data classification enums
enum ReservationCategory {
  active,
  upcoming,
  completed,
  cancelled,
  expired,
  pending,
}

enum SubscriptionCategory { active, expired, suspended, trial, cancelled }

enum AccessStatus { granted, denied, pending, expired, suspended }

enum UserAccessLevel { full, limited, none, suspended }

/// Main Unified Data Orchestrator Service
class UnifiedDataOrchestrator {
  static final UnifiedDataOrchestrator _instance =
      UnifiedDataOrchestrator._internal();
  factory UnifiedDataOrchestrator() => _instance;
  UnifiedDataOrchestrator._internal();

  // Core services
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StatusManagementService _statusService = StatusManagementService();

  // State management
  final StreamController<UnifiedDataState> _stateController =
      StreamController<UnifiedDataState>.broadcast();

  UnifiedDataState _currentState = UnifiedDataState(
    lastUpdated: DateTime.now(),
  );

  // Caching and enrichment
  final Map<String, String> _userNameCache = {};
  final Map<String, String> _serviceNameCache = {};
  final Map<String, Map<String, dynamic>> _userDetailsCache = {};

  // Fetch control
  bool _isInitialized = false;
  bool _isFetching = false;
  DateTime? _lastFetch;
  static const Duration _fetchCooldown = Duration(seconds: 10);

  // Listeners
  StreamSubscription? _reservationListener;
  StreamSubscription? _subscriptionListener;
  StreamSubscription? _userListener;

  /// Public state stream
  Stream<UnifiedDataState> get stateStream => _stateController.stream;
  UnifiedDataState get currentState => _currentState;

  /// Initialize the orchestrator
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('UnifiedDataOrchestrator: Initializing...');

      // Load cached data first
      await _loadCachedData();

      // Set up real-time listeners
      await _setupRealTimeListeners();

      // Perform initial fetch
      await _performUnifiedFetch();

      _isInitialized = true;
      print('UnifiedDataOrchestrator: Initialization complete');
    } catch (e) {
      print('UnifiedDataOrchestrator: Initialization failed: $e');
      _updateState(_currentState.copyWith(error: 'Initialization failed: $e'));
    }
  }

  /// Perform unified data fetch from all sources
  Future<void> _performUnifiedFetch({bool forceRefresh = false}) async {
    if (_isFetching && !forceRefresh) {
      print('UnifiedDataOrchestrator: Fetch in progress, skipping');
      return;
    }

    final now = DateTime.now();
    if (!forceRefresh &&
        _lastFetch != null &&
        now.difference(_lastFetch!) < _fetchCooldown) {
      print('UnifiedDataOrchestrator: Fetch throttled');
      return;
    }

    _isFetching = true;
    _lastFetch = now;

    _updateState(_currentState.copyWith(isLoading: true, error: null));

    try {
      final providerId = _getCurrentProviderId();
      if (providerId == null) {
        throw Exception('No authenticated provider');
      }

      print(
        'UnifiedDataOrchestrator: Starting unified fetch for provider $providerId',
      );

      // Fetch all data in parallel
      final results = await Future.wait([
        _fetchAllReservationsUnified(providerId),
        _fetchAllSubscriptionsUnified(providerId),
        _fetchAllUsersUnified(providerId),
        _fetchAccessLogsUnified(providerId),
      ]);

      final rawReservations = results[0] as List<Map<String, dynamic>>;
      final rawSubscriptions = results[1] as List<Map<String, dynamic>>;
      final rawUsers = results[2] as List<Map<String, dynamic>>;
      final rawAccessLogs = results[3] as List<AccessLog>;

      print(
        'UnifiedDataOrchestrator: Raw data fetched - ${rawReservations.length} reservations, ${rawSubscriptions.length} subscriptions, ${rawUsers.length} users',
      );

      // Enrich and classify data
      final enrichedUsers = await _enrichUsers(
        rawUsers,
        rawReservations,
        rawSubscriptions,
      );
      final classifiedReservations = await _classifyReservations(
        rawReservations,
        enrichedUsers,
      );
      final classifiedSubscriptions = await _classifySubscriptions(
        rawSubscriptions,
        enrichedUsers,
      );

      // Cache the processed data
      await _cacheProcessedData(
        classifiedReservations,
        classifiedSubscriptions,
        enrichedUsers,
      );

      // Update state
      _updateState(
        UnifiedDataState(
          reservations: classifiedReservations,
          subscriptions: classifiedSubscriptions,
          users: enrichedUsers,
          accessLogs: rawAccessLogs,
          lastUpdated: now,
          isLoading: false,
        ),
      );

      print('UnifiedDataOrchestrator: Unified fetch completed successfully');
    } catch (e) {
      print('UnifiedDataOrchestrator: Unified fetch failed: $e');
      _updateState(
        _currentState.copyWith(
          isLoading: false,
          error: 'Data fetch failed: $e',
        ),
      );
    } finally {
      _isFetching = false;
    }
  }

  /// Fetch all reservations from all possible sources with complete details
  Future<List<Map<String, dynamic>>> _fetchAllReservationsUnified(
    String providerId,
  ) async {
    final allReservations = <Map<String, dynamic>>[];
    final processedIds = <String>{};

    print(
      'UnifiedDataOrchestrator: Starting comprehensive reservation fetch for provider $providerId',
    );

    // Step 1: Get reservation references from serviceProviders structure
    final reservationReferences = <Map<String, dynamic>>[];

    final referencePaths = [
      'serviceProviders/$providerId/confirmedReservations',
      'serviceProviders/$providerId/pendingReservations',
      'serviceProviders/$providerId/completedReservations',
      'serviceProviders/$providerId/cancelledReservations',
      'serviceProviders/$providerId/upcomingReservations',
    ];

    // Collect reservation references
    for (final path in referencePaths) {
      try {
        final pathParts = path.split('/');
        final snapshot =
            await _firestore
                .collection(pathParts[0])
                .doc(pathParts[1])
                .collection(pathParts[2])
                .limit(50)
                .get();

        for (final doc in snapshot.docs) {
          if (!processedIds.contains(doc.id)) {
            processedIds.add(doc.id);
            final data = doc.data();
            data['reservationId'] = doc.id;
            data['referenceSource'] = path;
            reservationReferences.add(data);
          }
        }

        print(
          'UnifiedDataOrchestrator: Found ${snapshot.docs.length} reservation references in $path',
        );
      } catch (e) {
        print(
          'UnifiedDataOrchestrator: Error fetching references from $path: $e',
        );
      }
    }

    // Step 2: For each reservation reference, fetch complete details from the proper path
    for (final reference in reservationReferences) {
      try {
        final reservationId = reference['reservationId'] as String;
        final userId = reference['userId'] as String?;

        if (userId == null || userId.isEmpty) {
          print(
            'UnifiedDataOrchestrator: Skipping reservation $reservationId - no userId',
          );
          continue;
        }

        // Try to get user's governorate to construct the proper path
        String? governorateId = await _getUserGovernorate(userId);

        if (governorateId == null) {
          // Fallback: try common governorate names
          final commonGovernorates = [
            'aswan',
            'cairo',
            'alexandria',
            'giza',
            'luxor',
          ];
          for (final gov in commonGovernorates) {
            try {
              final detailDoc =
                  await _firestore
                      .collection('reservations')
                      .doc(gov)
                      .collection(providerId)
                      .doc(reservationId)
                      .get();

              if (detailDoc.exists) {
                governorateId = gov;
                break;
              }
            } catch (e) {
              // Continue trying other governorates
            }
          }
        }

        if (governorateId != null) {
          // Fetch complete reservation details
          final detailPath = 'reservations/$governorateId/$providerId';
          try {
            final detailDoc =
                await _firestore
                    .collection('reservations')
                    .doc(governorateId)
                    .collection(providerId)
                    .doc(reservationId)
                    .get();

            if (detailDoc.exists) {
              final completeData = detailDoc.data() ?? {};
              completeData['id'] = reservationId;
              completeData['reservationId'] = reservationId;
              completeData['source'] = 'detailPath:$detailPath';
              completeData['hasCompleteDetails'] = true;

              // Merge with reference data for any missing fields
              for (final key in reference.keys) {
                if (!completeData.containsKey(key) ||
                    completeData[key] == null) {
                  completeData[key] = reference[key];
                }
              }

              allReservations.add(completeData);
              print(
                'UnifiedDataOrchestrator: Fetched complete details for reservation $reservationId from $detailPath',
              );
            } else {
              // Fallback to reference data if complete details not found
              reference['hasCompleteDetails'] = false;
              reference['source'] = 'referenceOnly';
              allReservations.add(reference);
              print(
                'UnifiedDataOrchestrator: Using reference data for reservation $reservationId (details not found)',
              );
            }
          } catch (e) {
            print(
              'UnifiedDataOrchestrator: Error fetching details for reservation $reservationId: $e',
            );
            // Fallback to reference data
            reference['hasCompleteDetails'] = false;
            reference['source'] = 'referenceOnly';
            allReservations.add(reference);
          }
        } else {
          // No governorate found, use reference data
          reference['hasCompleteDetails'] = false;
          reference['source'] = 'referenceOnly';
          allReservations.add(reference);
          print(
            'UnifiedDataOrchestrator: No governorate found for reservation $reservationId, using reference data',
          );
        }
      } catch (e) {
        print(
          'UnifiedDataOrchestrator: Error processing reservation reference: $e',
        );
      }
    }

    // Step 3: Also try collection group query as fallback
    try {
      final snapshot =
          await _firestore
              .collectionGroup('reservations')
              .where('providerId', isEqualTo: providerId)
              .limit(50)
              .get();

      for (final doc in snapshot.docs) {
        final reservationId = doc.id;
        if (!processedIds.contains(reservationId)) {
          processedIds.add(reservationId);
          final data = doc.data();
          data['id'] = reservationId;
          data['reservationId'] = reservationId;
          data['source'] = 'collectionGroup';
          data['hasCompleteDetails'] = true;
          allReservations.add(data);
        }
      }

      print(
        'UnifiedDataOrchestrator: Found ${snapshot.docs.length} additional reservations from collection group',
      );
    } catch (e) {
      print(
        'UnifiedDataOrchestrator: Error fetching from collection group: $e',
      );
    }

    print(
      'UnifiedDataOrchestrator: Total reservations fetched: ${allReservations.length}',
    );

    // Log detailed sample of fetched data for debugging
    if (allReservations.isNotEmpty) {
      final sample = allReservations.first;
      final hasCompleteDetails = sample['hasCompleteDetails'] ?? false;
      print(
        'UnifiedDataOrchestrator: Sample reservation data keys: ${sample.keys.toList()}',
      );
      print(
        'UnifiedDataOrchestrator: Sample has complete details: $hasCompleteDetails',
      );
      print(
        'UnifiedDataOrchestrator: Sample reservation ID: ${sample['id'] ?? sample['reservationId']}',
      );
      print('UnifiedDataOrchestrator: Sample user ID: ${sample['userId']}');
      print(
        'UnifiedDataOrchestrator: Sample service name: ${sample['serviceName'] ?? 'Not found'}',
      );
      print(
        'UnifiedDataOrchestrator: Sample status: ${sample['status'] ?? 'Not found'}',
      );
      print(
        'UnifiedDataOrchestrator: Sample duration fields: durationMinutes=${sample['durationMinutes']}, duration=${sample['duration']}, durationHours=${sample['durationHours']}',
      );
      print(
        'UnifiedDataOrchestrator: Sample time fields: dateTime=${sample['dateTime']}, startTime=${sample['startTime']}, endTime=${sample['endTime']}',
      );

      // Count reservations with complete details vs reference only
      final completeCount =
          allReservations.where((r) => r['hasCompleteDetails'] == true).length;
      final referenceCount = allReservations.length - completeCount;
      print(
        'UnifiedDataOrchestrator: Complete details: $completeCount, Reference only: $referenceCount',
      );
    }

    return allReservations;
  }

  /// Get user's governorate from their profile
  Future<String?> _getUserGovernorate(String userId) async {
    try {
      // Try endUsers collection first
      final endUserDoc =
          await _firestore.collection('endUsers').doc(userId).get();
      if (endUserDoc.exists) {
        final data = endUserDoc.data();
        final governorateId = data?['governorateId'] as String?;
        if (governorateId != null && governorateId.isNotEmpty) {
          return governorateId;
        }
      }

      // Try users collection as fallback
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final governorateId = data?['governorateId'] as String?;
        if (governorateId != null && governorateId.isNotEmpty) {
          return governorateId;
        }
      }
    } catch (e) {
      print(
        'UnifiedDataOrchestrator: Error fetching user governorate for $userId: $e',
      );
    }

    return null;
  }

  /// Fetch all subscriptions from all possible sources with complete details
  Future<List<Map<String, dynamic>>> _fetchAllSubscriptionsUnified(
    String providerId,
  ) async {
    final allSubscriptions = <Map<String, dynamic>>[];
    final processedIds = <String>{};

    print(
      'UnifiedDataOrchestrator: Starting comprehensive subscription fetch for provider $providerId',
    );

    // Step 1: Get subscription references from serviceProviders structure
    final subscriptionReferences = <Map<String, dynamic>>[];

    final referencePaths = [
      'serviceProviders/$providerId/activeSubscriptions',
      'serviceProviders/$providerId/expiredSubscriptions',
      'serviceProviders/$providerId/suspendedSubscriptions',
    ];

    // Collect subscription references
    for (final path in referencePaths) {
      try {
        final pathParts = path.split('/');
        final snapshot =
            await _firestore
                .collection(pathParts[0])
                .doc(pathParts[1])
                .collection(pathParts[2])
                .limit(30)
                .get();

        for (final doc in snapshot.docs) {
          if (!processedIds.contains(doc.id)) {
            processedIds.add(doc.id);
            final data = doc.data();
            data['subscriptionId'] = doc.id;
            data['referenceSource'] = path;
            subscriptionReferences.add(data);
          }
        }

        print(
          'UnifiedDataOrchestrator: Found ${snapshot.docs.length} subscription references in $path',
        );
      } catch (e) {
        print(
          'UnifiedDataOrchestrator: Error fetching subscription references from $path: $e',
        );
      }
    }

    // Step 2: For each subscription reference, fetch complete details from the proper path
    for (final reference in subscriptionReferences) {
      try {
        final subscriptionId = reference['subscriptionId'] as String;
        final userId = reference['userId'] as String?;

        if (userId == null || userId.isEmpty) {
          print(
            'UnifiedDataOrchestrator: Skipping subscription $subscriptionId - no userId',
          );
          continue;
        }

        // Try to get user's governorate to construct the proper path
        String? governorateId = await _getUserGovernorate(userId);

        if (governorateId == null) {
          // Fallback: try common governorate names
          final commonGovernorates = [
            'aswan',
            'cairo',
            'alexandria',
            'giza',
            'luxor',
          ];
          for (final gov in commonGovernorates) {
            try {
              final detailDoc =
                  await _firestore
                      .collection('subscriptions')
                      .doc(gov)
                      .collection(providerId)
                      .doc(subscriptionId)
                      .get();

              if (detailDoc.exists) {
                governorateId = gov;
                break;
              }
            } catch (e) {
              // Continue trying other governorates
            }
          }
        }

        if (governorateId != null) {
          // Fetch complete subscription details
          final detailPath = 'subscriptions/$governorateId/$providerId';
          try {
            final detailDoc =
                await _firestore
                    .collection('subscriptions')
                    .doc(governorateId)
                    .collection(providerId)
                    .doc(subscriptionId)
                    .get();

            if (detailDoc.exists) {
              final completeData = detailDoc.data() ?? {};
              completeData['id'] = subscriptionId;
              completeData['subscriptionId'] = subscriptionId;
              completeData['source'] = 'detailPath:$detailPath';
              completeData['hasCompleteDetails'] = true;

              // Merge with reference data for any missing fields
              for (final key in reference.keys) {
                if (!completeData.containsKey(key) ||
                    completeData[key] == null) {
                  completeData[key] = reference[key];
                }
              }

              allSubscriptions.add(completeData);
              print(
                'UnifiedDataOrchestrator: Fetched complete details for subscription $subscriptionId from $detailPath',
              );
            } else {
              // Fallback to reference data if complete details not found
              reference['hasCompleteDetails'] = false;
              reference['source'] = 'referenceOnly';
              allSubscriptions.add(reference);
              print(
                'UnifiedDataOrchestrator: Using reference data for subscription $subscriptionId (details not found)',
              );
            }
          } catch (e) {
            print(
              'UnifiedDataOrchestrator: Error fetching details for subscription $subscriptionId: $e',
            );
            // Fallback to reference data
            reference['hasCompleteDetails'] = false;
            reference['source'] = 'referenceOnly';
            allSubscriptions.add(reference);
          }
        } else {
          // No governorate found, use reference data
          reference['hasCompleteDetails'] = false;
          reference['source'] = 'referenceOnly';
          allSubscriptions.add(reference);
          print(
            'UnifiedDataOrchestrator: No governorate found for subscription $subscriptionId, using reference data',
          );
        }
      } catch (e) {
        print(
          'UnifiedDataOrchestrator: Error processing subscription reference: $e',
        );
      }
    }

    // Step 3: Also try collection group query as fallback
    try {
      final snapshot =
          await _firestore
              .collectionGroup('subscriptions')
              .where('providerId', isEqualTo: providerId)
              .limit(30)
              .get();

      for (final doc in snapshot.docs) {
        final subscriptionId = doc.id;
        if (!processedIds.contains(subscriptionId)) {
          processedIds.add(subscriptionId);
          final data = doc.data();
          data['id'] = subscriptionId;
          data['subscriptionId'] = subscriptionId;
          data['source'] = 'collectionGroup';
          data['hasCompleteDetails'] = true;
          allSubscriptions.add(data);
        }
      }

      print(
        'UnifiedDataOrchestrator: Found ${snapshot.docs.length} additional subscriptions from collection group',
      );
    } catch (e) {
      print(
        'UnifiedDataOrchestrator: Error fetching subscriptions from collection group: $e',
      );
    }

    print(
      'UnifiedDataOrchestrator: Total subscriptions fetched: ${allSubscriptions.length}',
    );

    // Log sample of fetched data for debugging
    if (allSubscriptions.isNotEmpty) {
      final sample = allSubscriptions.first;
      print(
        'UnifiedDataOrchestrator: Sample subscription data keys: ${sample.keys.toList()}',
      );
      print(
        'UnifiedDataOrchestrator: Sample has complete details: ${sample['hasCompleteDetails'] ?? false}',
      );
    }

    return allSubscriptions;
  }

  /// Fetch only users who have reservations or subscriptions with enhanced user details
  Future<List<Map<String, dynamic>>> _fetchAllUsersUnified(
    String providerId,
  ) async {
    final allUsers = <Map<String, dynamic>>[];
    final processedIds = <String>{};

    try {
      // First, get all user IDs from reservations and subscriptions
      final userIdsWithActivity = <String>{};

      // Get user IDs from reservations using multiple sources
      final reservationPaths = [
        'serviceProviders/$providerId/confirmedReservations',
        'serviceProviders/$providerId/pendingReservations',
        'serviceProviders/$providerId/completedReservations',
        'serviceProviders/$providerId/cancelledReservations',
        'serviceProviders/$providerId/upcomingReservations',
      ];

      for (final path in reservationPaths) {
        try {
          final pathParts = path.split('/');
          final snapshot =
              await _firestore
                  .collection(pathParts[0])
                  .doc(pathParts[1])
                  .collection(pathParts[2])
                  .limit(50)
                  .get();

          for (final doc in snapshot.docs) {
            final userId = doc.data()['userId'] as String?;
            if (userId != null && userId.isNotEmpty) {
              userIdsWithActivity.add(userId);
            }
          }
        } catch (e) {
          print('UnifiedDataOrchestrator: Error fetching from $path: $e');
        }
      }

      // Get user IDs from subscriptions
      final subscriptionPaths = [
        'serviceProviders/$providerId/activeSubscriptions',
        'serviceProviders/$providerId/expiredSubscriptions',
        'serviceProviders/$providerId/suspendedSubscriptions',
      ];

      for (final path in subscriptionPaths) {
        try {
          final pathParts = path.split('/');
          final snapshot =
              await _firestore
                  .collection(pathParts[0])
                  .doc(pathParts[1])
                  .collection(pathParts[2])
                  .limit(30)
                  .get();

          for (final doc in snapshot.docs) {
            final userId = doc.data()['userId'] as String?;
            if (userId != null && userId.isNotEmpty) {
              userIdsWithActivity.add(userId);
            }
          }
        } catch (e) {
          print('UnifiedDataOrchestrator: Error fetching from $path: $e');
        }
      }

      // Also check collection groups for additional user IDs
      try {
        final reservationSnapshot =
            await _firestore
                .collectionGroup('reservations')
                .where('providerId', isEqualTo: providerId)
                .limit(100)
                .get();

        for (final doc in reservationSnapshot.docs) {
          final userId = doc.data()['userId'] as String?;
          if (userId != null && userId.isNotEmpty) {
            userIdsWithActivity.add(userId);
          }
        }
      } catch (e) {
        print(
          'UnifiedDataOrchestrator: Error fetching reservation collection group: $e',
        );
      }

      try {
        final subscriptionSnapshot =
            await _firestore
                .collectionGroup('subscriptions')
                .where('providerId', isEqualTo: providerId)
                .limit(50)
                .get();

        for (final doc in subscriptionSnapshot.docs) {
          final userId = doc.data()['userId'] as String?;
          if (userId != null && userId.isNotEmpty) {
            userIdsWithActivity.add(userId);
          }
        }
      } catch (e) {
        print(
          'UnifiedDataOrchestrator: Error fetching subscription collection group: $e',
        );
      }

      print(
        'UnifiedDataOrchestrator: Found ${userIdsWithActivity.length} unique users with reservations/subscriptions',
      );

      // Now fetch user details with enhanced data enrichment
      final userFetchTasks = userIdsWithActivity.map((userId) async {
        if (processedIds.contains(userId)) return null;
        processedIds.add(userId);

        // Try multiple user collections with enhanced data
        Map<String, dynamic>? userData;

        // Try endUsers collection first (most complete data)
        try {
          final userDoc =
              await _firestore.collection('endUsers').doc(userId).get();
          if (userDoc.exists) {
            userData = userDoc.data() ?? {};
            userData['id'] = userId;
            userData['source'] = 'endUsers';
            userData['dataCompleteness'] = _calculateUserDataCompleteness(
              userData,
            );
            return userData;
          }
        } catch (e) {
          print(
            'UnifiedDataOrchestrator: Error fetching user $userId from endUsers: $e',
          );
        }

        // Try users collection as fallback
        try {
          final userDoc =
              await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            userData = userDoc.data() ?? {};
            userData['id'] = userId;
            userData['source'] = 'users';
            userData['dataCompleteness'] = _calculateUserDataCompleteness(
              userData,
            );
            return userData;
          }
        } catch (e) {
          print(
            'UnifiedDataOrchestrator: Error fetching user $userId from users: $e',
          );
        }

        // If user not found, create enhanced minimal entry
        final generatedUser = {
          'id': userId,
          'displayName': _generateIntelligentUserName(userId),
          'name': _generateIntelligentUserName(userId),
          'userName': _generateIntelligentUserName(userId),
          'source': 'generated',
          'dataCompleteness': 0.1, // Low completeness for generated users
          'isGenerated': true,
        };
        return generatedUser;
      });

      // Execute all user fetch tasks in parallel
      final userResults = await Future.wait(userFetchTasks);

      // Filter out null results and add to allUsers
      for (final userData in userResults) {
        if (userData != null) {
          allUsers.add(userData);
        }
      }

      // Sort users by data completeness (most complete first)
      allUsers.sort((a, b) {
        final aCompleteness = a['dataCompleteness'] as double? ?? 0.0;
        final bCompleteness = b['dataCompleteness'] as double? ?? 0.0;
        return bCompleteness.compareTo(aCompleteness);
      });

      print(
        'UnifiedDataOrchestrator: Successfully fetched ${allUsers.length} users with enhanced details',
      );
    } catch (e) {
      print('UnifiedDataOrchestrator: Error fetching users: $e');
    }

    return allUsers;
  }

  /// Calculate user data completeness score
  double _calculateUserDataCompleteness(Map<String, dynamic> userData) {
    double score = 0.0;
    final fields = [
      'displayName', 'name', 'userName', // Name fields
      'email', 'phone', // Contact fields
      'profilePicUrl', 'avatar', // Profile fields
      'governorateId', 'location', // Location fields
    ];

    for (final field in fields) {
      if (userData[field] != null && userData[field].toString().isNotEmpty) {
        score += 1.0;
      }
    }

    return score / fields.length;
  }

  /// Generate intelligent user name from user ID
  String _generateIntelligentUserName(String userId) {
    if (userId.length > 8) {
      return 'User ${userId.substring(0, 8)}';
    }
    return 'User $userId';
  }

  /// Fetch access logs
  Future<List<AccessLog>> _fetchAccessLogsUnified(String providerId) async {
    try {
      final snapshot =
          await _firestore
              .collection(DataPaths.accessLogs)
              .where('providerId', isEqualTo: providerId)
              .orderBy('timestamp', descending: true)
              .limit(50)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return AccessLog(
          id: doc.id,
          providerId: providerId,
          userId: data['userId'] as String? ?? '',
          userName: data['userName'] as String? ?? 'Unknown',
          timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
          status: data['status'] as String? ?? 'unknown',
          method: data['method'] as String?,
          denialReason: data['denialReason'] as String?,
        );
      }).toList();
    } catch (e) {
      print('UnifiedDataOrchestrator: Error fetching access logs: $e');
      return [];
    }
  }

  /// Enrich users with their reservations and subscriptions
  Future<List<EnrichedUser>> _enrichUsers(
    List<Map<String, dynamic>> rawUsers,
    List<Map<String, dynamic>> rawReservations,
    List<Map<String, dynamic>> rawSubscriptions,
  ) async {
    final enrichedUsers = <EnrichedUser>[];

    for (final userData in rawUsers) {
      try {
        final userId = userData['id'] as String;
        final userName = _extractUserName(userData);

        // Cache user name
        _userNameCache[userId] = userName;
        _userDetailsCache[userId] = userData;

        // Find user's reservations and subscriptions
        final userReservations =
            rawReservations.where((r) => r['userId'] == userId).toList();
        final userSubscriptions =
            rawSubscriptions.where((s) => s['userId'] == userId).toList();

        // Determine access level
        final accessLevel = _determineUserAccessLevel(
          userReservations,
          userSubscriptions,
        );

        // Create enriched user
        final enrichedUser = EnrichedUser(
          userId: userId,
          name: userName,
          accessType: _determineAccessType(userReservations, userSubscriptions),
          email: userData['email'] as String?,
          phone: userData['phone'] as String?,
          profilePicUrl: userData['profilePicUrl'] as String?,
          accessLevel: accessLevel,
          lastActivity: _getLastActivity(userReservations, userSubscriptions),
          metadata: {
            'source': userData['source'],
            'reservationCount': userReservations.length,
            'subscriptionCount': userSubscriptions.length,
          },
        );

        enrichedUsers.add(enrichedUser);
      } catch (e) {
        print('UnifiedDataOrchestrator: Error enriching user: $e');
      }
    }

    return enrichedUsers;
  }

  /// Classify reservations with enhanced data
  Future<List<ClassifiedReservation>> _classifyReservations(
    List<Map<String, dynamic>> rawReservations,
    List<EnrichedUser> users,
  ) async {
    final classifiedReservations = <ClassifiedReservation>[];

    for (final reservationData in rawReservations) {
      try {
        final userId = reservationData['userId'] as String? ?? '';
        final user = users.where((u) => u.userId == userId).firstOrNull;

        final enrichedUserName =
            user?.name ?? _userNameCache[userId] ?? 'Unknown User';
        final enrichedServiceName = _extractServiceName(reservationData);

        // Parse dates
        final dateTime = _parseDateTime(reservationData);
        final enrichedStartTime = _parseStartTime(reservationData);
        final enrichedEndTime = _parseEndTime(
          reservationData,
          enrichedStartTime,
        );

        // Classify reservation
        final category = _classifyReservation(
          reservationData,
          enrichedStartTime,
          enrichedEndTime,
        );
        final accessStatus = _determineReservationAccessStatus(
          reservationData,
          category,
        );

        // Enhanced data enrichment with comprehensive field extraction
        final enrichedNotes =
            reservationData['notes'] as String? ??
            reservationData['description'] as String? ??
            reservationData['comments'] as String? ??
            reservationData['details'] as String? ??
            reservationData['specialRequests'] as String? ??
            reservationData['additionalInfo'] as String? ??
            '';

        final enrichedGroupSize =
            reservationData['groupSize'] as int? ??
            reservationData['partySize'] as int? ??
            reservationData['attendees'] as int? ??
            reservationData['numberOfGuests'] as int? ??
            reservationData['guestCount'] as int? ??
            reservationData['peopleCount'] as int? ??
            1;

        // Enhanced duration parsing with multiple sources
        int enrichedDuration = 60; // Default 1 hour

        // Try to get duration from various fields
        if (reservationData['durationMinutes'] != null) {
          enrichedDuration = reservationData['durationMinutes'] as int;
        } else if (reservationData['duration'] != null) {
          final durationValue = reservationData['duration'];
          if (durationValue is int) {
            enrichedDuration = durationValue;
          } else if (durationValue is String) {
            enrichedDuration = int.tryParse(durationValue) ?? 60;
          }
        } else if (reservationData['durationHours'] != null) {
          final hours = reservationData['durationHours'];
          if (hours is int) {
            enrichedDuration = hours * 60;
          } else if (hours is double) {
            enrichedDuration = (hours * 60).round();
          } else if (hours is String) {
            final parsedHours = double.tryParse(hours);
            if (parsedHours != null) {
              enrichedDuration = (parsedHours * 60).round();
            }
          }
        } else if (enrichedStartTime != null && enrichedEndTime != null) {
          // Calculate duration from start and end times
          enrichedDuration =
              enrichedEndTime.difference(enrichedStartTime).inMinutes;
          if (enrichedDuration <= 0) {
            enrichedDuration = 60; // Fallback to 1 hour
          }
        }

        // Extract additional fields that might be present in complete details
        final enrichedServiceId =
            reservationData['serviceId'] as String? ??
            reservationData['service_id'] as String? ??
            reservationData['serviceID'] as String? ??
            reservationData['id'] as String? ??
            '';

        final enrichedProviderId =
            reservationData['providerId'] as String? ??
            reservationData['provider_id'] as String? ??
            reservationData['providerID'] as String? ??
            _getCurrentProviderId() ??
            '';

        // Extract pricing information if available
        final enrichedPrice =
            reservationData['totalPrice'] as double? ??
            (reservationData['totalPrice'] as int?)?.toDouble() ??
            reservationData['price'] as double? ??
            reservationData['cost'] as double? ??
            reservationData['amount'] as double? ??
            (reservationData['price'] as int?)?.toDouble() ??
            0.0;

        // Extract contact information
        final enrichedPhone =
            reservationData['phone'] as String? ??
            reservationData['phoneNumber'] as String? ??
            reservationData['contactNumber'] as String? ??
            '';

        final enrichedEmail =
            reservationData['email'] as String? ??
            reservationData['emailAddress'] as String? ??
            reservationData['contactEmail'] as String? ??
            '';

        // Extract location/venue information
        final enrichedLocation =
            reservationData['location'] as String? ??
            reservationData['venue'] as String? ??
            reservationData['address'] as String? ??
            reservationData['place'] as String? ??
            '';

        // Extract additional fields from the complete data structure
        final isHost = reservationData['isHost'] as bool? ?? false;
        final paymentStatus = reservationData['paymentStatus'] as String? ?? '';
        final governorateId = reservationData['governorateId'] as String? ?? '';
        final isCommunityVisible =
            reservationData['isCommunityVisible'] as bool? ?? false;
        final isFullVenueReservation =
            reservationData['isFullVenueReservation'] as bool? ?? false;
        final queueBased = reservationData['queueBased'] as bool? ?? false;

        // Extract payment details if available
        final paymentDetails =
            reservationData['paymentDetails'] as Map<String, dynamic>? ?? {};
        final paymentMethod = paymentDetails['method'] as String? ?? '';

        // Extract type-specific data
        final typeSpecificData =
            reservationData['typeSpecificData'] as Map<String, dynamic>? ?? {};
        final addToCalendar =
            typeSpecificData['addToCalendar'] as bool? ?? false;

        // Extract selected add-ons
        final selectedAddOnsList =
            reservationData['selectedAddOnsList'] as List? ?? [];

        // Add intelligent status enhancement
        final originalStatus =
            reservationData['status'] as String? ?? 'pending';
        final enhancedStatus = _enhanceReservationStatus(
          originalStatus,
          category,
        );

        final classifiedReservation = ClassifiedReservation(
          id:
              reservationData['id'] as String? ??
              reservationData['reservationId'] as String? ??
              'res_${DateTime.now().millisecondsSinceEpoch}',
          userId: userId,
          userName: enrichedUserName,
          providerId: enrichedProviderId,
          serviceName: enrichedServiceName,
          serviceId: enrichedServiceId,
          status: enhancedStatus,
          dateTime: dateTime,
          notes: enrichedNotes,
          type: _parseReservationType(
            reservationData['type'] ?? reservationData['reservationType'],
          ),
          groupSize: enrichedGroupSize,
          durationMinutes: enrichedDuration,
          category: category,
          accessStatus: accessStatus,
          enrichedUserName: enrichedUserName,
          enrichedServiceName: enrichedServiceName,
          enrichedStartTime: enrichedStartTime,
          enrichedEndTime: enrichedEndTime,
          metadata: {
            'source': reservationData['source'] ?? 'firestore',
            'originalStatus': originalStatus,
            'dataCompleteness': _calculateReservationCompleteness(
              reservationData,
            ),
            'hasUserDetails': user != null,
            'userSource': user?.metadata?['source'] ?? 'unknown',
            'hasCompleteDetails':
                reservationData['hasCompleteDetails'] ?? false,
            'referenceSource': reservationData['referenceSource'],
            'detailPath':
                reservationData['source']?.toString().contains('detailPath:') ==
                        true
                    ? reservationData['source'].toString().replaceFirst(
                      'detailPath:',
                      '',
                    )
                    : null,
            // Enhanced metadata with additional fields
            'totalPrice': enrichedPrice,
            'price': enrichedPrice,
            'phone': enrichedPhone,
            'email': enrichedEmail,
            'location': enrichedLocation,
            'durationMinutes': enrichedDuration,
            'durationHours': (enrichedDuration / 60.0).toStringAsFixed(1),
            'calculatedEndTime': enrichedEndTime?.toIso8601String(),
            'allAvailableFields': reservationData.keys.toList(),
            // Complete data structure fields
            'isHost': isHost,
            'paymentStatus': paymentStatus,
            'governorateId': governorateId,
            'isCommunityVisible': isCommunityVisible,
            'isFullVenueReservation': isFullVenueReservation,
            'queueBased': queueBased,
            'paymentMethod': paymentMethod,
            'paymentDetails': paymentDetails,
            'typeSpecificData': typeSpecificData,
            'addToCalendar': addToCalendar,
            'selectedAddOnsList': selectedAddOnsList,
            'createdAt': reservationData['createdAt'],
            'updatedAt': reservationData['updatedAt'],
          },
        );

        classifiedReservations.add(classifiedReservation);
      } catch (e) {
        print('UnifiedDataOrchestrator: Error classifying reservation: $e');
      }
    }

    return classifiedReservations;
  }

  /// Classify subscriptions with enhanced data
  Future<List<ClassifiedSubscription>> _classifySubscriptions(
    List<Map<String, dynamic>> rawSubscriptions,
    List<EnrichedUser> users,
  ) async {
    final classifiedSubscriptions = <ClassifiedSubscription>[];

    for (final subscriptionData in rawSubscriptions) {
      try {
        final userId = subscriptionData['userId'] as String? ?? '';
        final user = users.where((u) => u.userId == userId).firstOrNull;

        final enrichedUserName =
            user?.name ?? _userNameCache[userId] ?? 'Unknown User';
        final enrichedPlanName = _extractPlanName(subscriptionData);

        // Parse dates
        final startDate = _parseStartDate(subscriptionData);
        final expiryDate = _parseExpiryDate(subscriptionData);

        // Classify subscription
        final category = _classifySubscription(subscriptionData, expiryDate);
        final accessStatus = _determineSubscriptionAccessStatus(
          subscriptionData,
          category,
        );

        final classifiedSubscription = ClassifiedSubscription(
          id: subscriptionData['id'] as String? ?? '',
          userId: userId,
          userName: enrichedUserName,
          providerId: _getCurrentProviderId() ?? '',
          planName: enrichedPlanName,
          status: subscriptionData['status'] as String? ?? 'active',
          startDate: startDate ?? Timestamp.now(),
          expiryDate:
              expiryDate ??
              Timestamp.fromDate(DateTime.now().add(Duration(days: 30))),
          isAutoRenewal: subscriptionData['autoRenew'] as bool? ?? false,
          pricePaid: (subscriptionData['price'] as num?)?.toDouble() ?? 0.0,
          category: category,
          accessStatus: accessStatus,
          enrichedUserName: enrichedUserName,
          enrichedPlanName: enrichedPlanName,
          enrichedStartDate: startDate?.toDate(),
          enrichedExpiryDate: expiryDate?.toDate(),
          metadata: {
            'source': subscriptionData['source'],
            'originalStatus': subscriptionData['status'],
          },
        );

        classifiedSubscriptions.add(classifiedSubscription);
      } catch (e) {
        print('UnifiedDataOrchestrator: Error classifying subscription: $e');
      }
    }

    return classifiedSubscriptions;
  }

  /// Helper methods for data extraction and classification
  String _extractUserName(Map<String, dynamic> userData) {
    // Try multiple user name fields with intelligent fallbacks
    String userName =
        userData['userName'] as String? ??
        userData['name'] as String? ??
        userData['displayName'] as String? ??
        userData['fullName'] as String? ??
        userData['firstName'] as String? ??
        userData['email'] as String? ??
        '';

    // If still empty, generate from user ID
    if (userName.isEmpty) {
      final userId = userData['id'] as String? ?? '';
      userName = _generateIntelligentUserName(userId);
    }

    // Clean up email if that's what we got
    if (userName.contains('@')) {
      userName = userName.split('@').first;
      userName = _formatUserName(userName);
    }

    return userName;
  }

  /// Format user name intelligently
  String _formatUserName(String input) {
    if (input.isEmpty) return 'User';

    // Convert various formats to readable names
    final formatted = input
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll('.', ' ')
        .split(' ')
        .map(
          (word) =>
              word.isNotEmpty
                  ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                  : '',
        )
        .join(' ');

    return formatted.isNotEmpty ? formatted : 'User';
  }

  String _extractServiceName(Map<String, dynamic> reservationData) {
    // Try multiple service name fields with intelligent fallbacks
    String serviceName =
        reservationData['serviceName'] as String? ??
        reservationData['service'] as String? ??
        reservationData['serviceTitle'] as String? ??
        reservationData['name'] as String? ??
        reservationData['title'] as String? ??
        reservationData['description'] as String? ??
        '';

    // If still empty, try to infer from other fields
    if (serviceName.isEmpty) {
      final type = reservationData['type'] as String? ?? '';
      final category = reservationData['category'] as String? ?? '';
      final serviceId = reservationData['serviceId'] as String? ?? '';
      final reservationType =
          reservationData['reservationType'] as String? ?? '';

      if (type.isNotEmpty && type != 'self') {
        serviceName = _formatServiceName(type);
      } else if (category.isNotEmpty) {
        serviceName = _formatServiceName(category);
      } else if (reservationType.isNotEmpty) {
        serviceName = _formatServiceName(reservationType);
      } else if (serviceId.isNotEmpty) {
        serviceName =
            'Service ${serviceId.length > 8 ? serviceId.substring(0, 8) : serviceId}';
      } else {
        // Check if we have complete details to provide a better default
        final hasCompleteDetails =
            reservationData['hasCompleteDetails'] as bool? ?? false;
        if (hasCompleteDetails) {
          serviceName = 'Service Reservation';
        } else {
          serviceName = 'General Reservation';
        }
      }
    }

    return serviceName;
  }

  /// Format service name intelligently from raw input
  String _formatServiceName(String input) {
    if (input.isEmpty) return 'Service';

    // Convert camelCase or snake_case to readable format
    final formatted = input
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .map(
          (word) =>
              word.isNotEmpty
                  ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                  : '',
        )
        .join(' ');

    return formatted.isNotEmpty ? formatted : 'Service';
  }

  String _extractPlanName(Map<String, dynamic> subscriptionData) {
    return subscriptionData['planName'] as String? ??
        subscriptionData['plan'] as String? ??
        subscriptionData['subscriptionType'] as String? ??
        'Membership Plan';
  }

  Timestamp _parseDateTime(Map<String, dynamic> data) {
    final fields = [
      'reservationStartTime', // Primary field for reservations
      'dateTime',
      'startTime',
      'timestamp',
      'reservationDateTime',
      'appointmentTime',
      'scheduledTime',
      'bookingTime',
      'date',
      'time',
      'createdAt',
      'updatedAt',
      'cancelledAt', // Check cancelled date as fallback
    ];

    for (final field in fields) {
      final value = data[field];
      if (value is Timestamp) {
        print(
          'UnifiedDataOrchestrator: Found valid Timestamp in field $field: ${value.toDate()}',
        );
        return value;
      }
      if (value is DateTime) {
        print(
          'UnifiedDataOrchestrator: Found valid DateTime in field $field: $value',
        );
        return Timestamp.fromDate(value);
      }
      if (value is String && value.isNotEmpty) {
        try {
          final parsedDate = DateTime.parse(value);
          print(
            'UnifiedDataOrchestrator: Parsed string date from field $field: $parsedDate',
          );
          return Timestamp.fromDate(parsedDate);
        } catch (e) {
          print(
            'UnifiedDataOrchestrator: Failed to parse string date from field $field: $value',
          );
          continue;
        }
      }
      if (value is int) {
        try {
          // Handle Unix timestamp (seconds or milliseconds)
          final dateTime =
              value > 1000000000000
                  ? DateTime.fromMillisecondsSinceEpoch(value)
                  : DateTime.fromMillisecondsSinceEpoch(value * 1000);
          print(
            'UnifiedDataOrchestrator: Parsed int timestamp from field $field: $dateTime',
          );
          return Timestamp.fromDate(dateTime);
        } catch (e) {
          print(
            'UnifiedDataOrchestrator: Failed to parse int timestamp from field $field: $value',
          );
          continue;
        }
      }
    }

    // If no valid date found, try to generate a reasonable date based on reservation ID
    // This prevents all reservations from having the same timestamp
    final reservationId =
        data['reservationId'] as String? ?? data['id'] as String? ?? '';
    if (reservationId.isNotEmpty) {
      try {
        // Use hash of reservation ID to generate a consistent but varied date
        final hash = reservationId.hashCode.abs();
        final daysOffset = (hash % 30) - 15; // Spread across ±15 days from now
        final hoursOffset = (hash ~/ 1000) % 24; // Vary hours
        final minutesOffset = (hash ~/ 100) % 60; // Vary minutes

        final baseDate = DateTime.now().add(Duration(days: daysOffset));
        final finalDate = DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          hoursOffset,
          minutesOffset,
        );

        print(
          'UnifiedDataOrchestrator: Generated date from reservation ID $reservationId: $finalDate',
        );
        return Timestamp.fromDate(finalDate);
      } catch (e) {
        print(
          'UnifiedDataOrchestrator: Failed to generate date from reservation ID: $e',
        );
      }
    }

    print(
      'UnifiedDataOrchestrator: No valid date found in data, using current time. Available fields: ${data.keys.toList()}',
    );
    return Timestamp.now();
  }

  DateTime? _parseStartTime(Map<String, dynamic> data) {
    final dateTime = _parseDateTime(data);
    return dateTime.toDate();
  }

  DateTime? _parseEndTime(Map<String, dynamic> data, DateTime? startTime) {
    // Try multiple end time fields
    final endTimeFields = [
      'endTime',
      'reservationEndTime',
      'appointmentEndTime',
      'finishTime',
      'completionTime',
    ];

    for (final field in endTimeFields) {
      final endTimeValue = data[field];
      if (endTimeValue is Timestamp) {
        print(
          'UnifiedDataOrchestrator: Found valid end time Timestamp in field $field: ${endTimeValue.toDate()}',
        );
        return endTimeValue.toDate();
      }
      if (endTimeValue is DateTime) {
        print(
          'UnifiedDataOrchestrator: Found valid end time DateTime in field $field: $endTimeValue',
        );
        return endTimeValue;
      }
      if (endTimeValue is String && endTimeValue.isNotEmpty) {
        try {
          final parsedDate = DateTime.parse(endTimeValue);
          print(
            'UnifiedDataOrchestrator: Parsed end time from string in field $field: $parsedDate',
          );
          return parsedDate;
        } catch (e) {
          continue;
        }
      }
    }

    // If no explicit end time found, calculate from start time and duration
    if (startTime != null) {
      // Try multiple duration fields
      int durationMinutes = 60; // Default 1 hour

      if (data['durationMinutes'] != null) {
        durationMinutes = data['durationMinutes'] as int;
      } else if (data['duration'] != null) {
        final durationValue = data['duration'];
        if (durationValue is int) {
          durationMinutes = durationValue;
        } else if (durationValue is String) {
          durationMinutes = int.tryParse(durationValue) ?? 60;
        }
      } else if (data['durationHours'] != null) {
        final hours = data['durationHours'];
        if (hours is int) {
          durationMinutes = hours * 60;
        } else if (hours is double) {
          durationMinutes = (hours * 60).round();
        } else if (hours is String) {
          final parsedHours = double.tryParse(hours);
          if (parsedHours != null) {
            durationMinutes = (parsedHours * 60).round();
          }
        }
      }

      final calculatedEndTime = startTime.add(
        Duration(minutes: durationMinutes),
      );
      print(
        'UnifiedDataOrchestrator: Calculated end time from start time + duration ($durationMinutes min): $calculatedEndTime',
      );
      return calculatedEndTime;
    }

    print(
      'UnifiedDataOrchestrator: No end time found and no start time to calculate from',
    );
    return null;
  }

  Timestamp? _parseStartDate(Map<String, dynamic> data) {
    final value = data['startDate'] ?? data['createdAt'];
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    return Timestamp.now();
  }

  Timestamp? _parseExpiryDate(Map<String, dynamic> data) {
    final value = data['expiryDate'] ?? data['endDate'];
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    return null;
  }

  ReservationType _parseReservationType(dynamic type) {
    if (type == null) return ReservationType.unknown;
    final typeString = type.toString().toLowerCase().replaceAll('-', '_');

    switch (typeString) {
      case 'timebased':
      case 'time_based':
        return ReservationType.timeBased;
      case 'servicebased':
      case 'service_based':
        return ReservationType.serviceBased;
      case 'seatbased':
      case 'seat_based':
        return ReservationType.seatBased;
      case 'recurring':
        return ReservationType.recurring;
      case 'group':
        return ReservationType.group;
      case 'accessbased':
      case 'access_based':
        return ReservationType.accessBased;
      case 'sequencebased':
      case 'sequence_based':
        return ReservationType.sequenceBased;
      case 'self':
        return ReservationType.serviceBased; // Treat 'self' as service-based
      default:
        return ReservationType.unknown;
    }
  }

  ReservationCategory _classifyReservation(
    Map<String, dynamic> data,
    DateTime? startTime,
    DateTime? endTime,
  ) {
    final status = (data['status'] as String? ?? '').toLowerCase();
    final paymentStatus =
        (data['paymentStatus'] as String? ?? '').toLowerCase();
    final now = DateTime.now();

    // First check explicit status values with enhanced logic
    if (status.contains('cancel')) return ReservationCategory.cancelled;
    if (status.contains('complet')) return ReservationCategory.completed;
    if (status == 'pending' && paymentStatus == 'pending')
      return ReservationCategory.pending;

    // Enhanced time-based classification for confirmed reservations
    if (status == 'confirmed' ||
        status == 'active' ||
        (status.isEmpty && paymentStatus != 'failed')) {
      if (startTime != null) {
        final startOfToday = DateTime(now.year, now.month, now.day);
        final startOfReservationDay = DateTime(
          startTime.year,
          startTime.month,
          startTime.day,
        );

        // Check if reservation has passed (expired)
        if (endTime != null && now.isAfter(endTime.add(Duration(hours: 1)))) {
          // Grace period of 1 hour after end time
          return ReservationCategory.expired;
        }

        // If reservation is today
        if (startOfReservationDay.isAtSameMomentAs(startOfToday)) {
          if (endTime != null && now.isAfter(endTime)) {
            return ReservationCategory.completed;
          } else if (now.isAfter(startTime.subtract(Duration(minutes: 15)))) {
            // Allow 15 minutes early check-in
            return ReservationCategory.active;
          } else {
            return ReservationCategory.upcoming; // Later today
          }
        }
        // If reservation is in the future
        else if (startOfReservationDay.isAfter(startOfToday)) {
          return ReservationCategory.upcoming;
        }
        // If reservation was in the past but within grace period
        else if (startOfReservationDay.isBefore(startOfToday)) {
          final daysPassed =
              startOfToday.difference(startOfReservationDay).inDays;
          if (daysPassed <= 1) {
            // Allow access for up to 1 day after reservation date
            return ReservationCategory.expired;
          } else {
            return ReservationCategory.completed;
          }
        }
      }
    }

    // Payment-based classification
    if (paymentStatus == 'failed' || paymentStatus == 'cancelled') {
      return ReservationCategory.cancelled;
    }

    // Default classification based on status
    if (status == 'confirmed') return ReservationCategory.upcoming;
    if (status == 'active') return ReservationCategory.active;

    return ReservationCategory.pending;
  }

  SubscriptionCategory _classifySubscription(
    Map<String, dynamic> data,
    Timestamp? expiryDate,
  ) {
    final status = (data['status'] as String? ?? '').toLowerCase();
    final now = DateTime.now();

    if (status.contains('cancel')) return SubscriptionCategory.cancelled;
    if (status.contains('suspend')) return SubscriptionCategory.suspended;
    if (status.contains('trial')) return SubscriptionCategory.trial;

    if (expiryDate != null) {
      if (now.isAfter(expiryDate.toDate())) return SubscriptionCategory.expired;
    }

    return SubscriptionCategory.active;
  }

  AccessStatus _determineReservationAccessStatus(
    Map<String, dynamic> data,
    ReservationCategory category,
  ) {
    final paymentStatus =
        (data['paymentStatus'] as String? ?? '').toLowerCase();
    final now = DateTime.now();

    // Check payment status first
    if (paymentStatus == 'failed' || paymentStatus == 'cancelled') {
      return AccessStatus.denied;
    }

    switch (category) {
      case ReservationCategory.active:
        return AccessStatus.granted;
      case ReservationCategory.upcoming:
        // Allow access 15 minutes before start time
        final startTime = _parseStartTime(data);
        if (startTime != null &&
            now.isAfter(startTime.subtract(Duration(minutes: 15)))) {
          return AccessStatus.granted;
        }
        return AccessStatus.pending;
      case ReservationCategory.cancelled:
        return AccessStatus.denied;
      case ReservationCategory.expired:
        // Allow grace period access
        final endTime = _parseEndTime(data, _parseStartTime(data));
        if (endTime != null && now.isBefore(endTime.add(Duration(hours: 1)))) {
          return AccessStatus.granted; // Grace period access
        }
        return AccessStatus.expired;
      case ReservationCategory.completed:
        return AccessStatus.expired;
      default:
        return paymentStatus == 'pending'
            ? AccessStatus.pending
            : AccessStatus.denied;
    }
  }

  AccessStatus _determineSubscriptionAccessStatus(
    Map<String, dynamic> data,
    SubscriptionCategory category,
  ) {
    switch (category) {
      case SubscriptionCategory.active:
        return AccessStatus.granted;
      case SubscriptionCategory.trial:
        return AccessStatus.granted;
      case SubscriptionCategory.expired:
        return AccessStatus.expired;
      case SubscriptionCategory.suspended:
        return AccessStatus.suspended;
      case SubscriptionCategory.cancelled:
        return AccessStatus.denied;
      default:
        return AccessStatus.pending;
    }
  }

  UserAccessLevel _determineUserAccessLevel(
    List<Map<String, dynamic>> reservations,
    List<Map<String, dynamic>> subscriptions,
  ) {
    final hasActiveReservation = reservations.any(
      (r) =>
          (r['status'] as String? ?? '').toLowerCase() == 'confirmed' ||
          (r['status'] as String? ?? '').toLowerCase() == 'active',
    );

    final hasActiveSubscription = subscriptions.any(
      (s) => (s['status'] as String? ?? '').toLowerCase() == 'active',
    );

    if (hasActiveReservation || hasActiveSubscription) {
      return UserAccessLevel.full;
    }

    if (reservations.isNotEmpty || subscriptions.isNotEmpty) {
      return UserAccessLevel.limited;
    }

    return UserAccessLevel.none;
  }

  String _determineAccessType(
    List<Map<String, dynamic>> reservations,
    List<Map<String, dynamic>> subscriptions,
  ) {
    if (reservations.isNotEmpty && subscriptions.isNotEmpty) {
      return 'Both';
    } else if (reservations.isNotEmpty) {
      return 'Reservation';
    } else if (subscriptions.isNotEmpty) {
      return 'Subscription';
    }
    return 'None';
  }

  DateTime? _getLastActivity(
    List<Map<String, dynamic>> reservations,
    List<Map<String, dynamic>> subscriptions,
  ) {
    DateTime? lastActivity;

    for (final reservation in reservations) {
      final dateTime = _parseDateTime(reservation).toDate();
      if (lastActivity == null || dateTime.isAfter(lastActivity)) {
        lastActivity = dateTime;
      }
    }

    for (final subscription in subscriptions) {
      final startDate = _parseStartDate(subscription)?.toDate();
      if (startDate != null &&
          (lastActivity == null || startDate.isAfter(lastActivity))) {
        lastActivity = startDate;
      }
    }

    return lastActivity;
  }

  /// Cache processed data
  Future<void> _cacheProcessedData(
    List<ClassifiedReservation> reservations,
    List<ClassifiedSubscription> subscriptions,
    List<EnrichedUser> users,
  ) async {
    try {
      // Cache reservations
      if (Hive.isBoxOpen('cachedReservationsBox')) {
        final box = Hive.box<CachedReservation>('cachedReservationsBox');
        await box.clear();

        for (final reservation in reservations) {
          final cached = CachedReservation(
            userId: reservation.userId ?? '',
            reservationId: reservation.id ?? '',
            serviceName: reservation.enrichedServiceName,
            startTime: reservation.enrichedStartTime ?? DateTime.now(),
            endTime:
                reservation.enrichedEndTime ??
                DateTime.now().add(Duration(hours: 1)),
            typeString: reservation.type.toString().split('.').last,
            groupSize: reservation.groupSize ?? 1,
            status: reservation.status,
          );
          await box.put(reservation.id, cached);
        }
      }

      // Cache subscriptions
      if (Hive.isBoxOpen('cachedSubscriptionsBox')) {
        final box = Hive.box<CachedSubscription>('cachedSubscriptionsBox');
        await box.clear();

        for (final subscription in subscriptions) {
          final cached = CachedSubscription(
            userId: subscription.userId ?? '',
            subscriptionId: subscription.id ?? '',
            planName: subscription.enrichedPlanName,
            expiryDate:
                subscription.enrichedExpiryDate ??
                DateTime.now().add(Duration(days: 30)),
          );
          await box.put(subscription.id, cached);
        }
      }

      // Cache users
      if (Hive.isBoxOpen('cachedUsersBox')) {
        final box = Hive.box<CachedUser>('cachedUsersBox');
        await box.clear();

        for (final user in users) {
          final cached = CachedUser(userId: user.userId, userName: user.name);
          await box.put(user.userId, cached);
        }
      }

      print(
        'UnifiedDataOrchestrator: Cached ${reservations.length} reservations, ${subscriptions.length} subscriptions, ${users.length} users',
      );
    } catch (e) {
      print('UnifiedDataOrchestrator: Error caching data: $e');
    }
  }

  /// Load cached data on startup
  Future<void> _loadCachedData() async {
    try {
      final cachedReservations = <ClassifiedReservation>[];
      final cachedSubscriptions = <ClassifiedSubscription>[];
      final cachedUsers = <EnrichedUser>[];

      // Load from Hive boxes if available
      if (Hive.isBoxOpen('cachedReservationsBox')) {
        final box = Hive.box<CachedReservation>('cachedReservationsBox');
        for (final cached in box.values) {
          // Convert cached to classified (simplified)
          final classified = ClassifiedReservation(
            id: cached.reservationId,
            userId: cached.userId,
            userName: cached.userId,
            providerId: _getCurrentProviderId() ?? '',
            serviceName: cached.serviceName,
            serviceId: '',
            status: cached.status,
            dateTime: Timestamp.fromDate(cached.startTime),
            notes: '',
            type: ReservationType.unknown,
            groupSize: cached.groupSize,
            durationMinutes:
                cached.endTime.difference(cached.startTime).inMinutes,
            category: ReservationCategory.pending,
            accessStatus: AccessStatus.pending,
            enrichedUserName: cached.userId,
            enrichedServiceName: cached.serviceName,
            enrichedStartTime: cached.startTime,
            enrichedEndTime: cached.endTime,
          );
          cachedReservations.add(classified);
        }
      }

      _updateState(
        UnifiedDataState(
          reservations: cachedReservations,
          subscriptions: cachedSubscriptions,
          users: cachedUsers,
          accessLogs: [],
          lastUpdated: DateTime.now(),
        ),
      );

      print(
        'UnifiedDataOrchestrator: Loaded ${cachedReservations.length} cached reservations',
      );
    } catch (e) {
      print('UnifiedDataOrchestrator: Error loading cached data: $e');
    }
  }

  /// Set up real-time listeners
  Future<void> _setupRealTimeListeners() async {
    final providerId = _getCurrentProviderId();
    if (providerId == null) return;

    try {
      // Listen to reservation changes
      _reservationListener = _firestore
          .collectionGroup('reservations')
          .where('providerId', isEqualTo: providerId)
          .snapshots()
          .listen((snapshot) {
            print(
              'UnifiedDataOrchestrator: Reservation changes detected (${snapshot.docs.length} docs)',
            );
            _performUnifiedFetch();
          });

      // Listen to subscription changes
      _subscriptionListener = _firestore
          .collectionGroup('subscriptions')
          .where('providerId', isEqualTo: providerId)
          .snapshots()
          .listen((snapshot) {
            print(
              'UnifiedDataOrchestrator: Subscription changes detected (${snapshot.docs.length} docs)',
            );
            _performUnifiedFetch();
          });

      print('UnifiedDataOrchestrator: Real-time listeners set up');
    } catch (e) {
      print('UnifiedDataOrchestrator: Error setting up listeners: $e');
    }
  }

  /// Public methods for external access
  Future<void> refresh({bool forceRefresh = false}) async {
    await _performUnifiedFetch(forceRefresh: forceRefresh);
  }

  List<ClassifiedReservation> getReservationsByCategory(
    ReservationCategory category,
  ) {
    return _currentState.reservations
        .where((r) => r.category == category)
        .toList();
  }

  List<ClassifiedSubscription> getSubscriptionsByCategory(
    SubscriptionCategory category,
  ) {
    return _currentState.subscriptions
        .where((s) => s.category == category)
        .toList();
  }

  List<EnrichedUser> getUsersByAccessLevel(UserAccessLevel level) {
    return _currentState.users.where((u) => u.accessLevel == level).toList();
  }

  EnrichedUser? getUserById(String userId) {
    return _currentState.users.where((u) => u.userId == userId).firstOrNull;
  }

  List<ClassifiedReservation> getReservationsForUser(String userId) {
    return _currentState.reservations.where((r) => r.userId == userId).toList();
  }

  List<ClassifiedSubscription> getSubscriptionsForUser(String userId) {
    return _currentState.subscriptions
        .where((s) => s.userId == userId)
        .toList();
  }

  /// Helper methods
  String? _getCurrentProviderId() => _auth.currentUser?.uid;

  void _updateState(UnifiedDataState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  /// Enhance reservation status with intelligent categorization
  String _enhanceReservationStatus(
    String originalStatus,
    ReservationCategory category,
  ) {
    if (originalStatus.isEmpty) {
      switch (category) {
        case ReservationCategory.active:
          return 'Confirmed';
        case ReservationCategory.upcoming:
          return 'Confirmed';
        case ReservationCategory.pending:
          return 'Pending';
        case ReservationCategory.completed:
          return 'Completed';
        case ReservationCategory.cancelled:
          return 'Cancelled';
        default:
          return 'Unknown';
      }
    }

    // Clean up and standardize status
    final cleanStatus = originalStatus.trim();
    if (cleanStatus.toLowerCase().contains('confirm')) return 'Confirmed';
    if (cleanStatus.toLowerCase().contains('pending')) return 'Pending';
    if (cleanStatus.toLowerCase().contains('cancel')) return 'Cancelled';
    if (cleanStatus.toLowerCase().contains('complet')) return 'Completed';
    if (cleanStatus.toLowerCase().contains('active')) return 'Active';

    return cleanStatus.isNotEmpty ? cleanStatus : 'Unknown';
  }

  /// Calculate reservation data completeness score
  double _calculateReservationCompleteness(
    Map<String, dynamic> reservationData,
  ) {
    double score = 0.0;
    final coreFields = [
      'userId',
      'userName',
      'serviceName',
      'status',
      'reservationStartTime', // Essential fields
    ];
    final additionalFields = [
      'notes', 'groupSize', 'durationMinutes', 'serviceId', // Important fields
      'description', 'type', 'providerId', 'totalPrice', // Enhanced fields
      'paymentStatus',
      'governorateId',
      'createdAt',
      'updatedAt', // Complete data fields
    ];

    // Core fields are weighted more heavily
    for (final field in coreFields) {
      if (reservationData[field] != null &&
          reservationData[field].toString().isNotEmpty) {
        score += 2.0; // Core fields worth 2 points each
      }
    }

    // Additional fields add to completeness
    for (final field in additionalFields) {
      if (reservationData[field] != null &&
          reservationData[field].toString().isNotEmpty) {
        score += 1.0; // Additional fields worth 1 point each
      }
    }

    // Bonus for having complete details from proper path
    if (reservationData['hasCompleteDetails'] == true) {
      score += 2.0;
    }

    // Bonus for having payment details
    if (reservationData['paymentDetails'] != null) {
      score += 1.0;
    }

    // Bonus for having type-specific data
    if (reservationData['typeSpecificData'] != null) {
      score += 1.0;
    }

    final maxScore = (coreFields.length * 2.0) + additionalFields.length + 4.0;
    return score / maxScore;
  }

  /// Convert ClassifiedReservation to regular Reservation for compatibility
  Reservation _toRegularReservation(ClassifiedReservation classified) {
    return Reservation(
      id: classified.id,
      userId: classified.userId,
      userName: classified.enrichedUserName,
      providerId: classified.providerId,
      serviceName: classified.enrichedServiceName,
      serviceId: classified.serviceId,
      status: classified.status,
      dateTime: classified.dateTime,
      notes: classified.notes,
      type: classified.type,
      groupSize: classified.groupSize,
      durationMinutes: classified.durationMinutes,
      // Enhanced fields from metadata
      totalPrice: classified.metadata['price'] as double?,
      amount: classified.metadata['price'] as double?,
      checkInTime:
          classified.enrichedStartTime != null
              ? Timestamp.fromDate(classified.enrichedStartTime!)
              : null,
      checkOutTime:
          classified.enrichedEndTime != null
              ? Timestamp.fromDate(classified.enrichedEndTime!)
              : null,
    );
  }

  /// Convert ClassifiedSubscription to regular Subscription for compatibility
  Subscription _toRegularSubscription(ClassifiedSubscription classified) {
    return Subscription(
      id: classified.id,
      userId: classified.userId,
      userName: classified.enrichedUserName,
      providerId: classified.providerId,
      planName: classified.enrichedPlanName,
      status: classified.status,
      startDate: classified.startDate,
      expiryDate: classified.expiryDate,
      isAutoRenewal: classified.isAutoRenewal,
      pricePaid: classified.pricePaid,
    );
  }

  /// Generate intelligent AI comment for access decision
  String generateIntelligentAccessComment({
    required bool hasAccess,
    required ClassifiedReservation? reservation,
    required ClassifiedSubscription? subscription,
    required String userName,
  }) {
    final now = DateTime.now();

    if (hasAccess) {
      return _generatePositiveAccessComment(
        reservation,
        subscription,
        userName,
        now,
      );
    } else {
      return _generateNegativeAccessComment(
        reservation,
        subscription,
        userName,
        now,
      );
    }
  }

  /// Generate positive access comment
  String _generatePositiveAccessComment(
    ClassifiedReservation? reservation,
    ClassifiedSubscription? subscription,
    String userName,
    DateTime now,
  ) {
    if (reservation != null) {
      final startTime = reservation.enrichedStartTime;
      final endTime = reservation.enrichedEndTime;
      final serviceName = reservation.enrichedServiceName;

      if (startTime != null) {
        final timeUntilStart = startTime.difference(now);
        final timeUntilEnd = endTime?.difference(now);

        if (reservation.category == ReservationCategory.active) {
          final remainingTime =
              timeUntilEnd != null
                  ? '${timeUntilEnd.inMinutes} minutes remaining'
                  : 'in progress';
          return '✅ Welcome ${userName}! Your $serviceName session is active ($remainingTime). Enjoy your time! 🎯';
        } else if (reservation.category == ReservationCategory.upcoming) {
          if (timeUntilStart.inMinutes <= 15) {
            return '🚀 Perfect timing ${userName}! Your $serviceName session starts in ${timeUntilStart.inMinutes} minutes. You\'re all set to enter! 💪';
          } else {
            return '⏰ Early bird ${userName}! Your $serviceName session starts in ${timeUntilStart.inMinutes} minutes. You can enter 15 minutes before start time. 🌟';
          }
        } else if (reservation.category == ReservationCategory.expired) {
          return '🕐 Grace period access granted for ${userName}! Your $serviceName session has ended, but you have 1 hour to finish up. Please wrap up soon! ⚡';
        }
      }

      return '✅ Access granted ${userName}! Your $serviceName reservation is confirmed. Welcome! 🎉';
    }

    if (subscription != null) {
      final planName = subscription.enrichedPlanName;
      final expiryDate = subscription.enrichedExpiryDate;

      if (expiryDate != null) {
        final daysUntilExpiry = expiryDate.difference(now).inDays;
        if (daysUntilExpiry <= 7) {
          return '✅ Welcome ${userName}! Your $planName membership is active but expires in $daysUntilExpiry days. Consider renewing soon! 🔄';
        }
      }

      return '✅ Welcome ${userName}! Your $planName membership is active. Enjoy unlimited access! 🌟';
    }

    return '✅ Access granted ${userName}! Welcome! 🎉';
  }

  /// Generate negative access comment with intelligent reasoning
  String _generateNegativeAccessComment(
    ClassifiedReservation? reservation,
    ClassifiedSubscription? subscription,
    String userName,
    DateTime now,
  ) {
    final reasons = <String>[];
    final suggestions = <String>[];

    // Analyze reservation issues
    if (reservation != null) {
      final startTime = reservation.enrichedStartTime;
      final endTime = reservation.enrichedEndTime;
      final serviceName = reservation.enrichedServiceName;
      final paymentStatus = reservation.metadata['paymentStatus'] as String?;

      switch (reservation.category) {
        case ReservationCategory.pending:
          if (paymentStatus == 'pending') {
            reasons.add(
              'Your $serviceName reservation payment is still pending',
            );
            suggestions.add(
              'Complete your payment to activate your reservation',
            );
          } else {
            reasons.add(
              'Your $serviceName reservation is pending confirmation',
            );
            suggestions.add('Wait for staff confirmation or contact support');
          }
          break;

        case ReservationCategory.cancelled:
          if (paymentStatus == 'failed') {
            reasons.add(
              'Your $serviceName reservation was cancelled due to payment failure',
            );
            suggestions.add(
              'Update your payment method and make a new reservation',
            );
          } else {
            reasons.add('Your $serviceName reservation was cancelled');
            suggestions.add(
              'Make a new reservation if you still want to attend',
            );
          }
          break;

        case ReservationCategory.expired:
          if (startTime != null && endTime != null) {
            final hoursPassed = now.difference(endTime).inHours;
            reasons.add(
              'Your $serviceName session ended $hoursPassed hours ago',
            );
            suggestions.add('Book a new session for your next visit');
          }
          break;

        case ReservationCategory.completed:
          reasons.add('Your $serviceName session has been completed');
          suggestions.add('Book a new session for your next visit');
          break;

        case ReservationCategory.upcoming:
          if (startTime != null) {
            final hoursUntilStart = startTime.difference(now).inHours;
            final minutesUntilStart = startTime.difference(now).inMinutes;

            if (hoursUntilStart > 24) {
              reasons.add(
                'Your $serviceName session is scheduled for ${hoursUntilStart} hours from now',
              );
              suggestions.add('Return 15 minutes before your scheduled time');
            } else if (minutesUntilStart > 15) {
              reasons.add(
                'Your $serviceName session starts in $minutesUntilStart minutes',
              );
              suggestions.add('You can enter 15 minutes before start time');
            }
          }
          break;

        default:
          reasons.add('Your reservation status needs verification');
          suggestions.add('Contact staff for assistance');
      }
    }

    // Analyze subscription issues
    if (subscription != null) {
      final planName = subscription.enrichedPlanName;
      final expiryDate = subscription.enrichedExpiryDate;

      switch (subscription.category) {
        case SubscriptionCategory.expired:
          if (expiryDate != null) {
            final daysExpired = now.difference(expiryDate).inDays;
            reasons.add(
              'Your $planName membership expired $daysExpired days ago',
            );
            suggestions.add('Renew your membership to regain access');
          }
          break;

        case SubscriptionCategory.suspended:
          reasons.add('Your $planName membership is temporarily suspended');
          suggestions.add(
            'Contact support to resolve any issues and reactivate',
          );
          break;

        case SubscriptionCategory.cancelled:
          reasons.add('Your $planName membership has been cancelled');
          suggestions.add('Subscribe to a new plan to regain access');
          break;

        default:
          reasons.add('Your membership status needs verification');
          suggestions.add('Contact support for assistance');
      }
    }

    // If no specific reservation or subscription found
    if (reservation == null && subscription == null) {
      reasons.add('No active reservation or membership found');
      suggestions.add(
        'Make a reservation or purchase a membership to gain access',
      );
    }

    // Build the intelligent comment
    final reasonText =
        reasons.isNotEmpty ? reasons.join('. ') : 'Access requirements not met';
    final suggestionText =
        suggestions.isNotEmpty
            ? suggestions.join(' or ')
            : 'Contact staff for assistance';

    return '🚫 Sorry ${userName}, access denied.\n\n📋 Reason: $reasonText.\n\n💡 Next steps: $suggestionText.\n\n📞 Need help? Contact our staff for immediate assistance!';
  }

  /// Get detailed access analysis for a user
  Map<String, dynamic> getDetailedAccessAnalysis(String userId) {
    final user = getUserById(userId);
    final userReservations = getReservationsForUser(userId);
    final userSubscriptions = getSubscriptionsForUser(userId);

    final now = DateTime.now();
    final analysis = <String, dynamic>{
      'userId': userId,
      'userName': user?.name ?? 'Unknown User',
      'hasAccess': false,
      'accessType': 'none',
      'primaryReason': '',
      'detailedAnalysis': <String, dynamic>{},
      'recommendations': <String>[],
      'aiComment': '',
    };

    // Analyze reservations
    if (userReservations.isNotEmpty) {
      final activeReservations =
          userReservations
              .where(
                (r) =>
                    r.category == ReservationCategory.active ||
                    (r.category == ReservationCategory.upcoming &&
                        r.accessStatus == AccessStatus.granted),
              )
              .toList();

      if (activeReservations.isNotEmpty) {
        final reservation = activeReservations.first;
        analysis['hasAccess'] = true;
        analysis['accessType'] = 'reservation';
        analysis['primaryReason'] =
            'Active reservation for ${reservation.enrichedServiceName}';
        analysis['aiComment'] = generateIntelligentAccessComment(
          hasAccess: true,
          reservation: reservation,
          subscription: null,
          userName: user?.name ?? 'User',
        );
        return analysis;
      }
    }

    // Analyze subscriptions
    if (userSubscriptions.isNotEmpty) {
      final activeSubscriptions =
          userSubscriptions
              .where(
                (s) =>
                    s.category == SubscriptionCategory.active ||
                    s.category == SubscriptionCategory.trial,
              )
              .toList();

      if (activeSubscriptions.isNotEmpty) {
        final subscription = activeSubscriptions.first;
        analysis['hasAccess'] = true;
        analysis['accessType'] = 'subscription';
        analysis['primaryReason'] =
            'Active ${subscription.enrichedPlanName} membership';
        analysis['aiComment'] = generateIntelligentAccessComment(
          hasAccess: true,
          reservation: null,
          subscription: subscription,
          userName: user?.name ?? 'User',
        );
        return analysis;
      }
    }

    // No access found - generate denial comment
    final latestReservation =
        userReservations.isNotEmpty ? userReservations.first : null;
    final latestSubscription =
        userSubscriptions.isNotEmpty ? userSubscriptions.first : null;

    analysis['aiComment'] = generateIntelligentAccessComment(
      hasAccess: false,
      reservation: latestReservation,
      subscription: latestSubscription,
      userName: user?.name ?? 'User',
    );

    return analysis;
  }

  /// Dispose resources
  void dispose() {
    _reservationListener?.cancel();
    _subscriptionListener?.cancel();
    _userListener?.cancel();
    _stateController.close();
  }
}

/// Extension for null safety
extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

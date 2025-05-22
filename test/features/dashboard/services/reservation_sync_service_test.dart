import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shamil_web_app/features/dashboard/services/reservation_sync_service.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';

// Generate mocks for Firebase dependencies
@GenerateMocks([
  FirebaseFirestore,
  FirebaseAuth,
  User,
  DocumentReference,
  CollectionReference,
  DocumentSnapshot,
  QuerySnapshot,
  Query,
])
void main() {
  late ReservationSyncService reservationSyncService;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockDocumentReference mockProviderDocRef;
  late MockDocumentSnapshot mockProviderDocSnapshot;
  late MockCollectionReference mockReservationCollection;
  late MockCollectionReference mockProviderCollection;
  late MockDocumentReference mockGovernorateDocRef;
  late MockCollectionReference mockProviderReservationCollection;

  // Setup test environment
  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockProviderDocRef = MockDocumentReference();
    mockProviderDocSnapshot = MockDocumentSnapshot();
    mockReservationCollection = MockCollectionReference();
    mockProviderCollection = MockCollectionReference();
    mockGovernorateDocRef = MockDocumentReference();
    mockProviderReservationCollection = MockCollectionReference();

    // Configure mock behaviors
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test-provider-id');

    when(
      mockFirestore.collection("serviceProviders"),
    ).thenReturn(mockProviderCollection);
    when(
      mockProviderCollection.doc('test-provider-id'),
    ).thenReturn(mockProviderDocRef);
    when(
      mockProviderDocRef.get(),
    ).thenAnswer((_) async => mockProviderDocSnapshot);
    when(mockProviderDocSnapshot.exists).thenReturn(true);
    when(mockProviderDocSnapshot.data()).thenReturn({
      'uid': 'test-provider-id',
      'businessName': 'Test Provider',
      'governorateId': 'test-governorate-id',
    });

    when(
      mockFirestore.collection("reservations"),
    ).thenReturn(mockReservationCollection);
    when(
      mockReservationCollection.doc('test-governorate-id'),
    ).thenReturn(mockGovernorateDocRef);
    when(
      mockGovernorateDocRef.collection('test-provider-id'),
    ).thenReturn(mockProviderReservationCollection);

    // Create instance with injected mocks
    reservationSyncService = ReservationSyncService.testInstance(
      firestore: mockFirestore,
      auth: mockAuth,
    );
  });

  group('ReservationSyncService', () {
    test('init() should fetch and cache governorateId', () async {
      // Arrange
      // Setup is already done in the main setUp

      // Act
      await reservationSyncService.init();

      // Assert
      expect(
        reservationSyncService.getCachedGovernorateId(),
        'test-governorate-id',
      );
      verify(mockFirestore.collection("serviceProviders")).called(1);
      verify(mockProviderCollection.doc('test-provider-id')).called(1);
      verify(mockProviderDocRef.get()).called(1);
    });

    test('init() should handle authentication errors', () async {
      // Arrange
      when(mockAuth.currentUser).thenReturn(null);

      // Act
      await reservationSyncService.init();

      // Assert
      expect(reservationSyncService.getCachedGovernorateId(), isNull);
      verifyNever(mockFirestore.collection("serviceProviders"));
    });

    test(
      'syncReservations() should update metadata after successful sync',
      () async {
        // Arrange
        final mockQuery = MockQuery();
        final mockQuerySnapshot = MockQuerySnapshot();

        when(
          mockProviderReservationCollection.where("status", whereIn: any),
        ).thenReturn(mockQuery);
        when(
          mockQuery.where("dateTime", isGreaterThanOrEqualTo: any),
        ).thenReturn(mockQuery);
        when(
          mockQuery.where("dateTime", isLessThanOrEqualTo: any),
        ).thenReturn(mockQuery);
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([]);

        final mockMetadataCollection = MockCollectionReference();
        final mockMetadataDocRef = MockDocumentReference();
        final mockMetadataSnapshot = MockDocumentSnapshot();

        when(
          mockFirestore.collection("sync_metadata"),
        ).thenReturn(mockMetadataCollection);
        when(
          mockMetadataCollection.doc('test-provider-id'),
        ).thenReturn(mockMetadataDocRef);
        when(
          mockMetadataDocRef.get(),
        ).thenAnswer((_) async => mockMetadataSnapshot);
        when(mockMetadataSnapshot.exists).thenReturn(false);
        when(mockMetadataDocRef.set(any)).thenAnswer((_) async => null);

        // Initialize with governorateId
        await reservationSyncService.init();

        // Act
        await reservationSyncService.syncReservations();

        // Assert
        verify(mockFirestore.collection("sync_metadata")).called(1);
        verify(mockMetadataCollection.doc('test-provider-id')).called(1);
        verify(mockMetadataDocRef.set(any)).called(1);
        expect(reservationSyncService.isSyncingNotifier.value, false);
      },
    );

    test(
      'updateReservationStatus() should update reservation status',
      () async {
        // Arrange
        final mockResDocRef = MockDocumentReference();

        when(
          mockProviderReservationCollection.doc('test-reservation-id'),
        ).thenReturn(mockResDocRef);
        when(mockResDocRef.update(any)).thenAnswer((_) async => null);

        // Initialize with governorateId
        await reservationSyncService.init();

        // Act
        await reservationSyncService.updateReservationStatus(
          reservationId: 'test-reservation-id',
          status: 'Confirmed',
        );

        // Assert
        verify(
          mockProviderReservationCollection.doc('test-reservation-id'),
        ).called(1);
        verify(
          mockResDocRef.update(
            argThat(
              predicate(
                (Map<String, dynamic> data) =>
                    data.containsKey('status') &&
                    data['status'] == 'Confirmed' &&
                    data.containsKey('updatedAt'),
              ),
            ),
          ),
        ).called(1);
      },
    );

    test(
      'updateReservationStatus() should throw with invalid status',
      () async {
        // Arrange
        await reservationSyncService.init();

        // Act & Assert
        expect(
          () => reservationSyncService.updateReservationStatus(
            reservationId: 'test-reservation-id',
            status: 'InvalidStatus',
          ),
          throwsException,
        );
      },
    );
  });
}

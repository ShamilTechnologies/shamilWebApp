import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:shamil_web_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/services/reservation_sync_service.dart';
import 'package:shamil_web_app/features/dashboard/widgets/reservation_management.dart';
import 'package:shamil_web_app/core/services/sync_manager.dart';
import 'package:shamil_web_app/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore firestore;
  late FirebaseAuth auth;
  late String testProviderId;
  late String testGovernorateId;
  late String testReservationId;

  setUpAll(() async {
    // Initialize Firebase for tests
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Use the actual Firebase instances
    firestore = FirebaseFirestore.instance;
    auth = FirebaseAuth.instance;

    // Sign in with test account - replace with your test credentials
    await auth.signInWithEmailAndPassword(
      email: 'test@example.com',
      password: 'testpassword',
    );

    testProviderId = auth.currentUser!.uid;

    // Get the governorateId from provider document
    final providerDoc =
        await firestore
            .collection('serviceProviders')
            .doc(testProviderId)
            .get();
    testGovernorateId = providerDoc.data()!['governorateId'] as String;

    // Clean up any existing test reservations
    await _cleanupTestReservations();
  });

  tearDownAll(() async {
    // Clean up test data
    await _cleanupTestReservations();

    // Sign out
    await auth.signOut();
  });

  Future<void> _cleanupTestReservations() async {
    // Delete any reservations with test names
    final snapshot =
        await firestore
            .collection('reservations')
            .doc(testGovernorateId)
            .collection(testProviderId)
            .where('userName', isEqualTo: 'Integration Test User')
            .get();

    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Future<String> _createTestReservation() async {
    // Create a test reservation
    final reservationRef =
        firestore
            .collection('reservations')
            .doc(testGovernorateId)
            .collection(testProviderId)
            .doc();

    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    await reservationRef.set({
      'id': reservationRef.id,
      'userId': 'test-user-id',
      'userName': 'Integration Test User',
      'dateTime': Timestamp.fromDate(tomorrow),
      'endTime': Timestamp.fromDate(tomorrow.add(const Duration(hours: 1))),
      'status': 'Confirmed',
      'serviceName': 'Test Service',
      'type': 'timeBased',
      'providerId': testProviderId,
      'groupSize': 2,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'isCommunityVisible': true,
    });

    return reservationRef.id;
  }

  testWidgets('Reservation should flow from Firestore to Dashboard UI', (
    WidgetTester tester,
  ) async {
    // Create test reservation
    testReservationId = await _createTestReservation();

    // Build widget tree with ReservationManagement
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          BlocProvider<DashboardBloc>(create: (context) => DashboardBloc()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        context.read<DashboardBloc>().add(LoadDashboardData());
                      },
                      child: const Text('Load Dashboard Data'),
                    ),
                    Expanded(
                      child: BlocBuilder<DashboardBloc, DashboardState>(
                        builder: (context, state) {
                          if (state is DashboardLoadSuccess) {
                            return ReservationManagement(
                              reservations: state.reservations,
                              providerId: testProviderId,
                              governorateId: testGovernorateId,
                            );
                          } else if (state is DashboardLoading) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          } else {
                            return const Center(child: Text('No data loaded'));
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    // Initial frame
    await tester.pump();

    // Tap the load button
    await tester.tap(find.text('Load Dashboard Data'));

    // Wait for data to load (may need multiple pump durations)
    await tester.pump(); // Start animations
    await tester.pump(const Duration(seconds: 5)); // Wait for network

    // Verify that the test reservation appears in the UI
    expect(find.text('Integration Test User'), findsOneWidget);
    expect(find.text('Test Service'), findsOneWidget);

    // Update the reservation to verify real-time updates
    await firestore
        .collection('reservations')
        .doc(testGovernorateId)
        .collection(testProviderId)
        .doc(testReservationId)
        .update({
          'serviceName': 'Updated Test Service',
          'updatedAt': Timestamp.now(),
        });

    // Wait for the update to propagate
    await tester.pump(const Duration(seconds: 3));

    // Verify the update appeared
    expect(find.text('Updated Test Service'), findsOneWidget);
  });
}

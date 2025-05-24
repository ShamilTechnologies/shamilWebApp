import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/access_control/access_type.dart';
import '../../../domain/models/access_control/access_log.dart' as domain;
import '../../../domain/models/access_control/access_credential.dart';
import '../../../presentation/bloc/access_control/access_control_bloc.dart';
import '../../../presentation/bloc/access_control/access_control_event.dart';
import '../../../presentation/bloc/access_control/access_control_state.dart';

/// Widget for validating user access
class AccessValidationWidget extends StatefulWidget {
  /// UID to validate
  final String uid;

  /// Access method
  final String method;

  /// Callback when access is granted
  final Function(String uid, String? userName)? onAccessGranted;

  /// Callback when access is denied
  final Function(String uid, String? reason)? onAccessDenied;

  /// Creates an access validation widget
  const AccessValidationWidget({
    Key? key,
    required this.uid,
    required this.method,
    this.onAccessGranted,
    this.onAccessDenied,
  }) : super(key: key);

  @override
  State<AccessValidationWidget> createState() => _AccessValidationWidgetState();
}

class _AccessValidationWidgetState extends State<AccessValidationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    // Trigger validation when widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccessControlBloc>().add(
        ValidateAccessEvent(uid: widget.uid, method: widget.method),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccessControlBloc, AccessControlState>(
      listener: (context, state) {
        if (state is AccessGranted) {
          _animationController.forward();
          if (widget.onAccessGranted != null) {
            widget.onAccessGranted!(widget.uid, state.user?.name);
          }
        } else if (state is AccessDenied) {
          _animationController.forward();
          if (widget.onAccessDenied != null) {
            widget.onAccessDenied!(widget.uid, state.reason);
          }
        } else {
          _animationController.reset();
        }
      },
      builder: (context, state) {
        if (state is AccessValidating) {
          return _buildValidatingUI();
        } else if (state is AccessGranted) {
          return _buildAccessGrantedUI(state);
        } else if (state is AccessDenied) {
          return _buildAccessDeniedUI(state);
        } else if (state is AccessControlError) {
          return _buildErrorUI(state);
        } else {
          return _buildInitialUI();
        }
      },
    );
  }

  Widget _buildInitialUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.badge_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Ready to validate access',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildValidatingUI() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              backgroundColor: Colors.grey.withOpacity(0.2),
              strokeWidth: 6,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Validating access...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Checking credentials for ${widget.uid}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessGrantedUI(AccessGranted state) {
    final userName = state.user?.name ?? 'Unknown User';
    final serviceName = state.credential.serviceName;

    // Try to determine type of access credential
    AccessType credentialType = AccessType.subscription;
    String validUntil = '';

    // Try to get the end date if available
    if (state.credential.endDate != null) {
      final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
      validUntil = dateFormat.format(state.credential.endDate);
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Access Granted',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              userName: userName,
              serviceName: serviceName,
              credentialType: credentialType,
              validUntil: validUntil,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                context.read<AccessControlBloc>().add(
                  ValidateAccessEvent(uid: widget.uid, method: widget.method),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Validate Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessDeniedUI(AccessDenied state) {
    final userName = state.user?.name ?? 'Unknown User';
    final reason = state.reason ?? 'No valid subscription or reservation found';

    // Get the icon, color, and title based on denial type
    IconData icon;
    Color color;
    String title;

    switch (state.denialType) {
      case 'already_present':
        icon = Icons.person_off_outlined;
        color = Colors.orange;
        title = 'Already in Facility';
        break;
      case 'past_reservation':
        icon = Icons.event_busy;
        color = Colors.deepOrange;
        title = 'Reservation Expired';
        break;
      case 'future_reservation':
        icon = Icons.calendar_today;
        color = Colors.blue;
        title = 'Future Reservation';
        break;
      default:
        icon = Icons.block;
        color = Colors.red;
        title = 'Access Denied';
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 64),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                reason,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
              ),
            ),
            const SizedBox(height: 20),
            // Only show the username if available
            if (state.user != null) ...[
              Text(
                'User: ${state.user!.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
            ],

            // Show reservation details if it's a future or past reservation
            if (state.credential != null &&
                (state.denialType == 'future_reservation' ||
                    state.denialType == 'past_reservation')) ...[
              _buildReservationInfoCard(state.credential!),
              const SizedBox(height: 16),
            ],

            ElevatedButton.icon(
              onPressed: () {
                context.read<AccessControlBloc>().add(
                  ValidateAccessEvent(uid: widget.uid, method: widget.method),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationInfoCard(AccessCredential credential) {
    // Extract relevant details from the credential
    final startDate = credential.startDate;
    final endDate = credential.endDate;

    // Format dates
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    final formattedDate = dateFormat.format(startDate);
    final formattedStartTime = timeFormat.format(startDate);
    final formattedEndTime = timeFormat.format(endDate);

    // Get class name and instructor if available
    String className = credential.serviceName;
    String? instructorName;

    if (credential.details != null) {
      if (credential.details!.containsKey('className')) {
        className = credential.details!['className'] ?? className;
      }
      if (credential.details!.containsKey('instructorName')) {
        instructorName = credential.details!['instructorName'];
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reservation Details',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const Divider(),
            _buildInfoRow(
              const Icon(Icons.event, color: Colors.teal),
              'Class',
              className,
            ),
            if (instructorName != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                const Icon(Icons.person, color: Colors.blue),
                'Instructor',
                instructorName,
              ),
            ],
            const SizedBox(height: 8),
            _buildInfoRow(
              const Icon(Icons.calendar_today, color: Colors.purple),
              'Date',
              formattedDate,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              const Icon(Icons.access_time, color: Colors.orange),
              'Time',
              '$formattedStartTime - $formattedEndTime',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String userName,
    required String serviceName,
    required AccessType credentialType,
    required String validUntil,
  }) {
    final Icon typeIcon =
        credentialType == AccessType.subscription
            ? const Icon(Icons.card_membership, color: Colors.blue)
            : const Icon(Icons.event_available, color: Colors.purple);

    final String typeText =
        credentialType == AccessType.subscription
            ? 'Subscription'
            : 'Reservation';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(
              const Icon(Icons.person, color: Colors.teal),
              'Name',
              userName,
            ),
            const Divider(),
            _buildInfoRow(typeIcon, 'Type', typeText),
            const Divider(),
            _buildInfoRow(
              const Icon(Icons.confirmation_number, color: Colors.amber),
              'Service',
              serviceName,
            ),
            if (validUntil.isNotEmpty) ...[
              const Divider(),
              _buildInfoRow(
                const Icon(Icons.timer, color: Colors.orange),
                'Valid Until',
                validUntil,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(Icon icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorUI(AccessControlError state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              color: Colors.amber,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Validation Error',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              state.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  context.read<AccessControlBloc>().add(
                    ValidateAccessEvent(uid: widget.uid, method: widget.method),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(180, 45),
                ),
              ),
              const SizedBox(width: 16),
              // Add diagnostic button
              OutlinedButton.icon(
                onPressed: () {
                  // Run diagnostic for this user
                  context.read<AccessControlBloc>().diagnoseAccessForUser(
                    widget.uid,
                  );

                  // Show diagnostic message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Check logs for diagnostic information'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                icon: const Icon(Icons.bug_report),
                label: const Text('Diagnostic'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(120, 45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

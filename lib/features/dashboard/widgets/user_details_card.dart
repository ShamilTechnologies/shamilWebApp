/// File: lib/features/dashboard/widgets/user_details_card.dart
/// A widget to display end user details fetched by their ID
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/core/services/end_user_service.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/widgets/detail_row.dart';
import 'package:shamil_web_app/features/dashboard/data/end_user_model.dart';

/// A widget that displays details of an end user fetched by their ID
class UserDetailsCard extends StatefulWidget {
  /// The ID of the user to display
  final String userId;

  /// Optional callback when user data is loaded
  final void Function(EndUser)? onUserLoaded;

  const UserDetailsCard({Key? key, required this.userId, this.onUserLoaded})
    : super(key: key);

  @override
  State<UserDetailsCard> createState() => _UserDetailsCardState();
}

class _UserDetailsCardState extends State<UserDetailsCard> {
  final EndUserService _userService = EndUserService();
  bool _isLoading = true;
  EndUser? _user;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didUpdateWidget(UserDetailsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    if (widget.userId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'User ID is empty';
        _user = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await _userService.getEndUserById(widget.userId);

      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
          _error = user == null ? 'User not found' : null;
        });

        if (user != null && widget.onUserLoaded != null) {
          widget.onUserLoaded!(user);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error loading user: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: _buildContent()),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.redColor, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: getTitleStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_off,
                color: AppColors.secondaryColor,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text('User not found', style: getTitleStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    // Format dates
    final DateFormat dateFormat = DateFormat('MMM d, yyyy');
    final String formattedDob =
        _user!.dob != null ? dateFormat.format(_user!.dob!) : 'Not provided';

    final String formattedCreatedAt =
        _user!.createdAt != null
            ? dateFormat.format(_user!.createdAt!)
            : 'Unknown';

    final String formattedLastSeen =
        _user!.lastSeen != null
            ? DateFormat('MMM d, yyyy HH:mm').format(_user!.lastSeen!)
            : 'Never';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with avatar and basic info
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User avatar
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primaryColor.withOpacity(0.1),
              backgroundImage:
                  _user!.profilePicUrl != null
                      ? NetworkImage(_user!.profilePicUrl!)
                      : null,
              child:
                  _user!.profilePicUrl == null
                      ? Text(
                        _user!.name.isNotEmpty
                            ? _user!.name[0].toUpperCase()
                            : '?',
                        style: getTitleStyle(
                          fontSize: 30,
                          color: AppColors.primaryColor,
                        ),
                      )
                      : null,
            ),
            const SizedBox(width: 16),

            // Basic info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _user!.name,
                    style: getTitleStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${_user!.username}',
                    style: getSmallStyle(color: AppColors.secondaryColor),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 16,
                        color: AppColors.mediumGrey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _user!.email,
                          style: getSmallStyle(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 16,
                        color: AppColors.mediumGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(_user!.phone, style: getSmallStyle()),
                    ],
                  ),
                ],
              ),
            ),

            // Status indicators
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatusBadge(
                  'ID',
                  _user!.uploadedId,
                  _user!.uploadedId ? Colors.green : Colors.grey,
                ),
                const SizedBox(height: 4),
                _buildStatusBadge(
                  'Verified',
                  _user!.isVerified,
                  _user!.isVerified ? Colors.green : Colors.orange,
                ),
                const SizedBox(height: 4),
                _buildStatusBadge(
                  'Blocked',
                  _user!.isBlocked,
                  _user!.isBlocked ? Colors.red : Colors.green,
                  invertValue: true,
                ),
              ],
            ),
          ],
        ),

        const Divider(height: 32),

        // Detailed information
        Text(
          'Personal Information',
          style: getTitleStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),

        DetailRow(label: 'Gender:', value: _user!.gender),
        DetailRow(label: 'Date of Birth:', value: formattedDob),
        DetailRow(label: 'National ID:', value: _user!.nationalId),

        const Divider(height: 32),

        Text(
          'Account Information',
          style: getTitleStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),

        DetailRow(label: 'User ID:', value: _user!.uid),
        DetailRow(label: 'Registered On:', value: formattedCreatedAt),
        DetailRow(label: 'Last Seen:', value: formattedLastSeen),

        if (_user!.uploadedId &&
            (_user!.idFrontUrl != null || _user!.idBackUrl != null))
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 32),

              Text(
                'ID Documents',
                style: getTitleStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // ID image previews
              Row(
                children: [
                  if (_user!.idFrontUrl != null)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'ID Front',
                            style: getSmallStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _user!.idFrontUrl!,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 100,
                                  color: AppColors.lightGrey,
                                  child: const Center(
                                    child: Icon(Icons.broken_image),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 16),
                  if (_user!.idBackUrl != null)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'ID Back',
                            style: getSmallStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _user!.idBackUrl!,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 100,
                                  color: AppColors.lightGrey,
                                  child: const Center(
                                    child: Icon(Icons.broken_image),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatusBadge(
    String label,
    bool value,
    Color color, {
    bool invertValue = false,
  }) {
    final bool displayValue = invertValue ? !value : value;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            displayValue ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: getSmallStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

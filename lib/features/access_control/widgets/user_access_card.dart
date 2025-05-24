import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A modern card to display user access events in the dashboard
class UserAccessCard extends StatelessWidget {
  final String userName;
  final String userId;
  final DateTime timestamp;
  final bool isGranted;
  final String accessMethod;
  final String? denialReason;

  const UserAccessCard({
    super.key,
    required this.userName,
    required this.userId,
    required this.timestamp,
    required this.isGranted,
    required this.accessMethod,
    this.denialReason,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isGranted ? Colors.green.shade100 : Colors.red.shade100,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isGranted ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isGranted ? Icons.check_circle : Icons.cancel,
                      color:
                          isGranted
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isGranted ? 'Access Granted' : 'Access Denied',
                      style: TextStyle(
                        color:
                            isGranted
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Text(
                  DateFormat('h:mm a').format(timestamp),
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),

          // User info
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildUserAvatar(userName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatUserId(userId),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Access method
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMethodIcon(accessMethod),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          accessMethod,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Denial reason (if applicable)
                if (!isGranted && denialReason != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            denialReason!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String name) {
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // Generate a consistent color based on the name
    final int hashCode = name.hashCode;
    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
    ];

    final Color avatarColor = colors[hashCode.abs() % colors.length];

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: avatarColor.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: avatarColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMethodIcon(String method) {
    final IconData icon;
    final Color color;

    if (method.toLowerCase().contains('nfc')) {
      icon = Icons.contactless;
      color = Colors.blue;
    } else if (method.toLowerCase().contains('card')) {
      icon = Icons.credit_card;
      color = Colors.purple;
    } else if (method.toLowerCase().contains('biometric')) {
      icon = Icons.fingerprint;
      color = Colors.teal;
    } else if (method.toLowerCase().contains('smart')) {
      icon = Icons.phone_android;
      color = Colors.green;
    } else {
      icon = Icons.security;
      color = Colors.blueGrey;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }

  String _formatUserId(String id) {
    // Format user ID for display
    if (id.length > 16) {
      return '${id.substring(0, 8)}...${id.substring(id.length - 4)}';
    }
    return id;
  }
}

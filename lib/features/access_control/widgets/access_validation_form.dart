import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shamil_web_app/core/services/centralized_data_service.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_field_templates.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:flutter/foundation.dart';

class AccessValidationForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onAccessResult;
  final CentralizedDataService dataService;

  const AccessValidationForm({
    Key? key,
    required this.onAccessResult,
    required this.dataService,
  }) : super(key: key);

  @override
  State<AccessValidationForm> createState() => _AccessValidationFormState();
}

class _AccessValidationFormState extends State<AccessValidationForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userIdController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _lastAccessResult;

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _validateAccess() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final userId = _userIdController.text.trim();
        final result = await widget.dataService.checkUserAccess(userId);

        setState(() {
          _isLoading = false;
          _lastAccessResult = result;
          if (result['hasAccess'] != true) {
            _errorMessage = result['reason'] ?? 'Access denied';
          }
        });

        // Pass the result to the parent
        widget.onAccessResult(result);

        // Record the access attempt
        _recordAccessAttempt(userId, result);
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _recordAccessAttempt(
    String userId,
    Map<String, dynamic> result,
  ) async {
    final bool hasAccess = result['hasAccess'] == true;

    try {
      await widget.dataService.recordAccess(
        userId: userId,
        userName: result['userName'] ?? 'Unknown User',
        status: hasAccess ? 'Granted' : 'Denied',
        method: 'Manual ID Entry',
        denialReason: hasAccess ? null : (result['reason'] ?? 'Unknown reason'),
      );
    } catch (e) {
      // Just log the error, don't show to user since the main function succeeded
      print('Error recording access attempt: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Validate User Access',
            style: getTitleStyle(fontSize: 20, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // NFC Status Indicator (placeholder for now)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightGrey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.nfc_rounded, color: AppColors.mediumGrey, size: 24),
                const SizedBox(width: 8),
                Text(
                  'NFC Reader: Not Connected',
                  style: getbodyStyle(color: AppColors.mediumGrey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Manual ID Entry
          RequiredTextFormField(
            controller: _userIdController,
            labelText: 'User ID',
            hintText: 'Enter user ID to validate access',
            prefixIconData: Icons.person,
            keyboardType: TextInputType.text,
            inputFormatters: [
              // Allow only alphanumeric characters
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            ],
          ),
          const SizedBox(height: 16),

          // Error message
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _errorMessage!,
                style: getbodyStyle(color: Colors.red.shade700),
              ),
            ),

          // Success message
          if (_lastAccessResult != null &&
              _lastAccessResult!['hasAccess'] == true)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Access Granted',
                    style: getbodyStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Access Type: ${_lastAccessResult!['accessType'] ?? 'Unknown'}',
                    style: getSmallStyle(color: Colors.green.shade700),
                  ),
                  if (_lastAccessResult!['accessType'] == 'subscription')
                    Text(
                      'Plan: ${_lastAccessResult!['planName'] ?? 'N/A'}',
                      style: getSmallStyle(color: Colors.green.shade700),
                    ),
                  if (_lastAccessResult!['accessType'] == 'reservation')
                    Text(
                      'Service: ${_lastAccessResult!['serviceName'] ?? 'N/A'}',
                      style: getSmallStyle(color: Colors.green.shade700),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Mobile app data refresh button
          OutlinedButton.icon(
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });

              try {
                final result = await widget.dataService.refreshMobileAppData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result
                            ? 'Mobile app data refreshed successfully!'
                            : 'Failed to refresh mobile app data.',
                      ),
                      backgroundColor:
                          result ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error refreshing data: ${e.toString()}'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            icon: Icon(Icons.refresh, color: AppColors.accentColor),
            label: Text(
              'Refresh Mobile App Data',
              style: getbodyStyle(color: AppColors.accentColor),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(color: AppColors.accentColor),
            ),
          ),

          const SizedBox(height: 12),

          // FOR DEVELOPMENT TESTING ONLY: Test data buttons
          if (kDebugMode) // Only show in debug mode
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _userIdController.text.isEmpty
                            ? null
                            : () async {
                              setState(() {
                                _isLoading = true;
                              });

                              try {
                                final result = await widget
                                    .dataService
                                    .accessControlRepository
                                    .addTestSubscription(
                                      _userIdController.text.trim(),
                                      'Test User',
                                    );

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        result
                                            ? 'Added test subscription for ${_userIdController.text}'
                                            : 'Failed to add test subscription',
                                      ),
                                      backgroundColor:
                                          result ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                print('Error adding test subscription: $e');
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                }
                              }
                            },
                    icon: const Icon(Icons.add_card, size: 16),
                    label: const Text('Add Test Subscription'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _userIdController.text.isEmpty
                            ? null
                            : () async {
                              setState(() {
                                _isLoading = true;
                              });

                              try {
                                final result = await widget
                                    .dataService
                                    .accessControlRepository
                                    .addTestReservation(
                                      _userIdController.text.trim(),
                                      'Test User',
                                    );

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        result
                                            ? 'Added test reservation for ${_userIdController.text}'
                                            : 'Failed to add test reservation',
                                      ),
                                      backgroundColor:
                                          result ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                print('Error adding test reservation: $e');
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                }
                              }
                            },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Add Test Reservation'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 12),

          // Submit Button
          ElevatedButton(
            onPressed: _isLoading ? null : _validateAccess,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              disabledBackgroundColor: AppColors.primaryColor.withOpacity(0.5),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Text('Validate Access'),
          ),

          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _userIdController.clear();
              setState(() {
                _errorMessage = null;
                _lastAccessResult = null;
              });
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

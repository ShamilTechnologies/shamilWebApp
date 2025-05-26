import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_field_templates.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/bookable_service.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart'
    show ReservationType;
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart'
    hide ReservationType;

class ReservationForm extends StatefulWidget {
  final Reservation? initialReservation;
  final Function(Map<String, dynamic>) onSubmit;
  final List<BookableService>? availableServices;

  const ReservationForm({
    Key? key,
    this.initialReservation,
    required this.onSubmit,
    this.availableServices,
  }) : super(key: key);

  @override
  State<ReservationForm> createState() => _ReservationFormState();
}

class _ReservationFormState extends State<ReservationForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _groupSizeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _hostingCategoryController =
      TextEditingController();
  final TextEditingController _hostingDescriptionController =
      TextEditingController();

  BookableService? _selectedService;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  ReservationType _reservationType = ReservationType.timeBased;
  String _status = 'Pending';
  bool _isCommunityVisible = false;
  bool _isFullVenueReservation = false;
  double? _totalPrice;

  // For attendees list
  List<Map<String, dynamic>> _attendees = [];

  @override
  void initState() {
    super.initState();

    // Initialize controllers if editing
    if (widget.initialReservation != null) {
      final res = widget.initialReservation!;
      _userIdController.text = res.userId ?? '';
      _userNameController.text = res.userName;

      final DateTime dateTime = res.dateTime.toDate();
      _selectedDate = dateTime;
      _selectedTime = TimeOfDay.fromDateTime(dateTime);
      _dateController.text = DateFormat('yyyy-MM-dd').format(dateTime);
      _timeController.text = _formatTimeOfDay(_selectedTime);

      _durationController.text = res.durationMinutes?.toString() ?? '';
      _groupSizeController.text = res.groupSize.toString();
      _notesController.text = res.notes ?? '';

      // Convert ReservationType from dashboard_models to service_provider_model
      final typeString = res.type.toString().split('.').last;
      _reservationType = _getReservationTypeFromString(typeString);

      _status = res.status;

      // Community visibility settings
      _isCommunityVisible = res.isCommunityVisible;
      _isFullVenueReservation = res.isFullVenueReservation;
      _totalPrice = res.totalPrice;

      // For community hosting details
      if (res.typeSpecificData != null &&
          res.typeSpecificData!.containsKey('hostingCategory')) {
        _hostingCategoryController.text =
            res.typeSpecificData!['hostingCategory'] ?? '';
      }

      if (res.typeSpecificData != null &&
          res.typeSpecificData!.containsKey('hostingDescription')) {
        _hostingDescriptionController.text =
            res.typeSpecificData!['hostingDescription'] ?? '';
      }

      // Initialize attendees list
      if (res.attendees != null) {
        _attendees = List<Map<String, dynamic>>.from(res.attendees!);
      } else {
        // Add main user as default attendee
        _attendees = [
          {
            'userId': res.userId,
            'userName': res.userName,
            'paymentStatus': 'paid',
          },
        ];
      }

      if (widget.availableServices != null && res.serviceId != null) {
        try {
          _selectedService = widget.availableServices!.firstWhere(
            (service) => service.id == res.serviceId,
          );
        } catch (e) {
          // No matching service found
          _selectedService = null;
        }
      }
    } else {
      // Set defaults for new reservation
      _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _timeController.text = _formatTimeOfDay(_selectedTime);
      _groupSizeController.text = '1';
      _durationController.text = '60';

      // Initialize with main user as an attendee
      _attendees = [];

      // Set a default service if available
      if (widget.availableServices != null &&
          widget.availableServices!.isNotEmpty) {
        _selectedService = widget.availableServices!.first;
      }
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _userNameController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _durationController.dispose();
    _groupSizeController.dispose();
    _notesController.dispose();
    _hostingCategoryController.dispose();
    _hostingDescriptionController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final now = DateTime.now();
    final dateTime = DateTime(
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
    return DateFormat('HH:mm').format(dateTime);
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _timeController.text = _formatTimeOfDay(picked);
      });
    }
  }

  void _addAttendee() {
    setState(() {
      _attendees.add({
        'userId': '',
        'userName': '',
        'paymentStatus': 'pending',
      });
    });
  }

  void _removeAttendee(int index) {
    if (index >= 0 && index < _attendees.length) {
      setState(() {
        _attendees.removeAt(index);
      });
    }
  }

  void _updateAttendee(int index, String field, dynamic value) {
    if (index >= 0 && index < _attendees.length) {
      setState(() {
        _attendees[index][field] = value;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      // Combine date and time
      final DateTime dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Convert reservation type to string for storage
      final reservationTypeString = _reservationType.toString().split('.').last;

      // Ensure at least one attendee - the primary user
      if (_attendees.isEmpty) {
        _attendees.add({
          'userId': _userIdController.text.trim(),
          'userName': _userNameController.text.trim(),
          'paymentStatus': 'paid',
        });
      } else if (_attendees.length == 1 && _attendees[0]['userId'].isEmpty) {
        // Update first attendee if empty
        _attendees[0] = {
          'userId': _userIdController.text.trim(),
          'userName': _userNameController.text.trim(),
          'paymentStatus': 'paid',
        };
      }

      // Create typeSpecificData for community hosting
      Map<String, dynamic> typeSpecificData = {};
      if (_isCommunityVisible) {
        if (_hostingCategoryController.text.isNotEmpty) {
          typeSpecificData['hostingCategory'] = _hostingCategoryController.text;
        }
        if (_hostingDescriptionController.text.isNotEmpty) {
          typeSpecificData['hostingDescription'] =
              _hostingDescriptionController.text;
        }
      }

      // Prepare form data
      final formData = {
        'userId': _userIdController.text.trim(),
        'userName': _userNameController.text.trim(),
        'dateTime': dateTime,
        'status': _status,
        'type': reservationTypeString,
        'groupSize': int.tryParse(_groupSizeController.text) ?? 1,
        if (_selectedService != null) 'serviceId': _selectedService!.id,
        if (_selectedService != null)
          'serviceName': _selectedService!.name ?? 'Unknown Service',
        if (_durationController.text.isNotEmpty)
          'durationMinutes': int.tryParse(_durationController.text),
        if (_notesController.text.isNotEmpty)
          'notes': _notesController.text.trim(),
        'isCommunityVisible': _isCommunityVisible,
        'isFullVenueReservation': _isFullVenueReservation,
        if (_attendees.isNotEmpty) 'attendees': _attendees,
        if (typeSpecificData.isNotEmpty) 'typeSpecificData': typeSpecificData,
        if (_totalPrice != null) 'totalPrice': _totalPrice,
      };

      // Submit the form data
      widget.onSubmit(formData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialReservation != null;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // User Information
            Text(
              'User Information',
              style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            RequiredTextFormField(
              controller: _userIdController,
              labelText: 'User ID*',
              hintText: 'Enter user ID',
            ),
            const SizedBox(height: 12),
            RequiredTextFormField(
              controller: _userNameController,
              labelText: 'User Name*',
              hintText: 'Enter user name',
            ),
            const SizedBox(height: 20),

            // Reservation Type and Service
            Text(
              'Reservation Details',
              style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            GlobalDropdownFormField<ReservationType>(
              labelText: "Reservation Type*",
              value: _reservationType,
              items:
                  ReservationType.values
                      .map(
                        (type) => DropdownMenuItem<ReservationType>(
                          value: type,
                          child: Text(type.name),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _reservationType = value);
                }
              },
              validator: (value) => value == null ? 'Required field' : null,
            ),
            const SizedBox(height: 12),

            // Service Selection
            if (widget.availableServices != null)
              GlobalDropdownFormField<BookableService>(
                labelText: "Service",
                value: _selectedService,
                items:
                    widget.availableServices!
                        .map(
                          (service) => DropdownMenuItem<BookableService>(
                            value: service,
                            child: Text(service.name),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedService = value;
                    if (value != null && value.durationMinutes != null) {
                      _durationController.text =
                          value.durationMinutes.toString();
                    }
                  });
                },
              ),
            const SizedBox(height: 12),

            // Date and Time
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dateController,
                    decoration: InputDecoration(
                      labelText: 'Date*',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: _selectDate,
                      ),
                    ),
                    readOnly: true,
                    onTap: _selectDate,
                    validator:
                        (value) => value!.isEmpty ? 'Required field' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _timeController,
                    decoration: InputDecoration(
                      labelText: 'Time*',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.access_time),
                        onPressed: _selectTime,
                      ),
                    ),
                    readOnly: true,
                    onTap: _selectTime,
                    validator:
                        (value) => value!.isEmpty ? 'Required field' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Duration and Group Size
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duration (minutes)',
                      hintText: 'e.g., 60',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _groupSizeController,
                    decoration: const InputDecoration(
                      labelText: 'Group Size*',
                      hintText: 'e.g., 1',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator:
                        (value) =>
                            value!.isEmpty || int.tryParse(value) == null
                                ? 'Valid number required'
                                : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Price field
            TextFormField(
              initialValue: _totalPrice?.toString() ?? '',
              decoration: const InputDecoration(
                labelText: 'Price',
                hintText: 'Total price for the reservation',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              onChanged: (value) {
                _totalPrice = double.tryParse(value);
              },
            ),
            const SizedBox(height: 12),

            // Additional Options
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Community Visible'),
                    value: _isCommunityVisible,
                    onChanged: (value) {
                      setState(() {
                        _isCommunityVisible = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Full Venue'),
                    value: _isFullVenueReservation,
                    onChanged: (value) {
                      setState(() {
                        _isFullVenueReservation = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),

            // Community hosting details (shown only if community visible is checked)
            if (_isCommunityVisible) ...[
              const SizedBox(height: 12),
              Text(
                'Community Hosting Details',
                style: getTitleStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _hostingCategoryController,
                decoration: const InputDecoration(
                  labelText: 'Hosting Category',
                  hintText: 'e.g., Sports, Study Group, Gaming',
                ),
              ),
              const SizedBox(height: 12),
              TextAreaFormField(
                controller: _hostingDescriptionController,
                labelText: 'Hosting Description',
                hintText: 'Describe your hosted event',
                minLines: 2,
                maxLines: 3,
              ),
            ],

            // Status Selection for editing
            if (isEditing)
              GlobalDropdownFormField<String>(
                labelText: "Status*",
                value: _status,
                items:
                    ['pending', 'confirmed', 'cancelled', 'completed']
                        .map(
                          (status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(
                              status.substring(0, 1).toUpperCase() +
                                  status.substring(1),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _status = value);
                  }
                },
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Required field'
                            : null,
              ),
            const SizedBox(height: 12),

            // Notes
            TextAreaFormField(
              controller: _notesController,
              labelText: 'Notes',
              hintText: 'Additional information (optional)',
              minLines: 2,
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Attendees Section
            Text(
              'Attendees',
              style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // List of attendees
            ..._buildAttendeesList(),

            // Add attendee button
            TextButton.icon(
              onPressed: _addAttendee,
              icon: const Icon(Icons.add),
              label: const Text('Add Attendee'),
            ),
            const SizedBox(height: 20),

            // Submit Button
            Center(
              child: ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  isEditing ? 'Update Reservation' : 'Create Reservation',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAttendeesList() {
    return List.generate(_attendees.length, (index) {
      final attendee = _attendees[index];
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: attendee['userName'],
                  decoration: const InputDecoration(
                    labelText: 'Attendee Name',
                    isDense: true,
                  ),
                  onChanged:
                      (value) => _updateAttendee(index, 'userName', value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: attendee['userId'],
                  decoration: const InputDecoration(
                    labelText: 'Attendee ID',
                    isDense: true,
                  ),
                  onChanged: (value) => _updateAttendee(index, 'userId', value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: attendee['paymentStatus'] ?? 'pending',
                  decoration: const InputDecoration(
                    labelText: 'Payment',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'waived', child: Text('Waived')),
                    DropdownMenuItem(value: 'hosted', child: Text('Hosted')),
                  ],
                  onChanged:
                      (value) => _updateAttendee(index, 'paymentStatus', value),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeAttendee(index),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
        ),
      );
    });
  }

  // Helper method to convert string to ReservationType enum
  ReservationType _getReservationTypeFromString(String typeString) {
    switch (typeString.toLowerCase()) {
      case 'timebased':
        return ReservationType.timeBased;
      case 'servicebased':
        return ReservationType.serviceBased;
      case 'seatbased':
        return ReservationType.seatBased;
      case 'recurring':
        return ReservationType.recurring;
      case 'group':
        return ReservationType.group;
      case 'accessbased':
        return ReservationType.accessBased;
      case 'sequencebased':
        return ReservationType.sequenceBased;
      default:
        return ReservationType.timeBased;
    }
  }
}

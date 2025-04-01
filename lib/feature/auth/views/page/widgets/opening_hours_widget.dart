import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart'; // Adjust path if needed
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path if needed
// Import AppColors if needed for styling disabled state
// import 'package:shamil_web_app/core/utils/colors.dart';

class OpeningHoursWidget extends StatefulWidget {
  final OpeningHours initialOpeningHours;
  // Callback still passes the full OpeningHours object
  final Function(OpeningHours) onHoursChanged;
  final bool enabled; // Added enabled property

  const OpeningHoursWidget({
    super.key,
    required this.initialOpeningHours,
    required this.onHoursChanged,
    this.enabled = true, // Default to enabled
  });

  @override
  _OpeningHoursWidgetState createState() => _OpeningHoursWidgetState();
}

class _OpeningHoursWidgetState extends State<OpeningHoursWidget> {
  final List<String> daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  // Internal state for managing hours and open status
  late Map<String, Map<String, String>> _hours;
  late Map<String, bool> _isOpen;
  // Time options generated once
  final List<String> _timeOptions = _generateTimeOptions();

  @override
  void initState() {
    super.initState();
    _updateInternalStateFromWidget(widget.initialOpeningHours);
    // Do NOT notify parent on initial state setup
    // _notifyParent(); // Removed initial notify call
  }

  // Add didUpdateWidget to handle external changes
  @override
  void didUpdateWidget(covariant OpeningHoursWidget oldWidget) {
      super.didUpdateWidget(oldWidget);
      // If the initial data passed from the parent changes, update the internal state
      // This handles cases where data is loaded from Firebase after the widget first builds
      if (widget.initialOpeningHours != oldWidget.initialOpeningHours) {
          _updateInternalStateFromWidget(widget.initialOpeningHours);
      }
      // No need to notify parent here either, parent controls the data flow
  }

  // Helper function to initialize or update state from widget property
  void _updateInternalStateFromWidget(OpeningHours openingHoursData) {
      _hours = {};
      _isOpen = {};
      for (var day in daysOfWeek) {
          // Check if the day exists and the inner map is not null
          if (openingHoursData.hours.containsKey(day) && openingHoursData.hours[day] != null) {
              _isOpen[day] = true;
              _hours[day] = {
                  // Provide defaults if specific open/close times are null/missing
                  'open': openingHoursData.hours[day]!['open'] ?? '09:00',
                  'close': openingHoursData.hours[day]!['close'] ?? '17:00',
              };
          } else {
              _isOpen[day] = false;
              // Optionally initialize default hours even if closed, if needed when toggling on
              // _hours[day] = {'open': '09:00', 'close': '17:00'};
          }
      }
  }


  // Generates time options (e.g., "00:00", "00:30", ..., "23:30")
  static List<String> _generateTimeOptions() { // Made static as it doesn't depend on instance state
    List<String> options = [];
    for (int hour = 0; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 30) { // 30-minute intervals
        final hourStr = hour.toString().padLeft(2, '0');
        final minuteStr = minute.toString().padLeft(2, '0');
        options.add('$hourStr:$minuteStr');
      }
    }
    return options;
  }

  // Notifies the parent widget (BusinessDetailsStep) with the current state
  void _notifyParent() {
    // Create a clean map containing only the days that are marked as open
    final Map<String, Map<String, String>> hoursToSend = {};
    _isOpen.forEach((day, isOpen) {
        if (isOpen && _hours.containsKey(day)) {
             // Ensure the map for the day exists and has valid times before adding
             // If _hours doesn't contain the day when isOpen is true, something is wrong,
             // but we check defensively here.
             hoursToSend[day] = _hours[day]!;
        }
    });
    // Pass the updated OpeningHours object to the parent
    widget.onHoursChanged(OpeningHours(hours: hoursToSend));
  }

  @override
  Widget build(BuildContext context) {
    // Use the enabled property passed from the parent
    final bool isEnabled = widget.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Opening Hours", style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.5)), // Use your text style
        const SizedBox(height: 10),
        Column(
          // Generate rows for each day
          children: daysOfWeek.map((day) {
            // Get current state for the day, providing defaults
            bool dayOpen = _isOpen[day] ?? false;
            // Get hours safely, provide defaults if map or keys don't exist
            String openTime = _hours[day]?['open'] ?? '09:00';
            String closeTime = _hours[day]?['close'] ?? '17:00';

            return Padding( // Add some padding for better spacing
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Checkbox(
                    value: dayOpen,
                    // Disable onChanged if widget is not enabled
                    onChanged: isEnabled ? (val) {
                      setState(() {
                        _isOpen[day] = val ?? false;
                        if (val == true) {
                          // If opening, ensure default hours are set if not already present
                          _hours[day] ??= {'open': '09:00', 'close': '17:00'};
                          // Re-assign potentially existing values to ensure map exists
                           _hours[day] = {'open': openTime, 'close': closeTime};
                        } else {
                          // If closing, we remove the day from the hours map conceptually,
                          // but keep the defaults stored internally maybe, or let _notifyParent handle it.
                          // _hours.remove(day); // Let _notifyParent filter based on _isOpen
                        }
                      });
                      _notifyParent(); // Notify parent of the change
                    } : null, // Set onChanged to null to disable
                    activeColor: AppColors.primaryColor, // Use your AppColors
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(day, style: getbodyStyle( // Use your text style
                          color: isEnabled ? null : AppColors.mediumGrey // Style disabled text
                      ))
                  ),
                  // Only show dropdowns if the day is marked as open
                  if (dayOpen) ...[
                    _buildTimeDropdown(openTime, isEnabled, (value) {
                        if (value != null) {
                          setState(() {
                            // Ensure the map for the day exists before updating
                             _hours[day] ??= {};
                            _hours[day]!['open'] = value;
                          });
                          _notifyParent();
                        }
                    }),
                    const SizedBox(width: 8),
                    Text("-", style: getbodyStyle(color: isEnabled ? null : AppColors.mediumGrey)),
                    const SizedBox(width: 8),
                     _buildTimeDropdown(closeTime, isEnabled, (value) {
                        if (value != null) {
                          setState(() {
                             _hours[day] ??= {};
                            _hours[day]!['close'] = value;
                          });
                          _notifyParent();
                        }
                    }),
                  ] else ...[
                      // Optional: Show placeholder text like "Closed" if day is not open
                       Text("Closed", style: getbodyStyle(color: AppColors.mediumGrey)),
                       const SizedBox(width: 140) // Approx width of dropdowns for alignment
                  ]
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Helper widget for time dropdowns to reduce repetition
  Widget _buildTimeDropdown(String currentValue, bool isEnabled, ValueChanged<String?> onChanged) {
      // Ensure the currentValue exists in the options, otherwise default to a valid one or handle null
      final validValue = _timeOptions.contains(currentValue) ? currentValue : _timeOptions.first;

      return DropdownButton<String>(
          value: validValue,
          items: _timeOptions.map((time) => DropdownMenuItem(
              value: time,
              child: Text(time, style: getbodyStyle( // Style dropdown items
                   color: isEnabled ? null : AppColors.mediumGrey,
                   fontSize: 14
              )),
          )).toList(),
          onChanged: isEnabled ? onChanged : null, // Disable if needed
          underline: Container(), // Optional: remove default underline
          style: getbodyStyle(color: isEnabled ? null : AppColors.mediumGrey), // Style selected value
          // Add other styling as needed (icon color, etc.)
          // iconEnabledColor: isEnabled ? AppColors.primaryColor : AppColors.mediumGrey,
       );
  }

}
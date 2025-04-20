import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart'; // Adjust path if needed
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path if needed
// Import AppColors if needed for styling disabled state
// import 'package:shamil_web_app/core/utils/colors.dart';

/// A stateful widget that allows users to select opening and closing times
/// for each day of the week, or mark days as closed.
class OpeningHoursWidget extends StatefulWidget {
  /// The initial opening hours data to display.
  final OpeningHours initialOpeningHours;
  /// Callback function triggered when the selected hours change.
  /// It passes the updated OpeningHours object (containing only open days).
  final Function(OpeningHours) onHoursChanged;
  /// Controls whether the widget allows interaction.
  final bool enabled; // Added enabled property

  const OpeningHoursWidget({
    super.key,
    required this.initialOpeningHours,
    required this.onHoursChanged,
    this.enabled = true, // Default to enabled
  });

  @override
  State<OpeningHoursWidget> createState() => _OpeningHoursWidgetState();
}

class _OpeningHoursWidgetState extends State<OpeningHoursWidget> {
  // Define the order of days
  final List<String> daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  // --- Internal State ---
  /// Stores the selected open/close times for each day internally.
  /// Uses defaults ('09:00', '17:00') if a day is toggled open without prior data.
  late Map<String, Map<String, String>> _hours;
  /// Stores whether each day is marked as open (checkbox state).
  late Map<String, bool> _isOpen;
  /// Pre-generated list of time options for the dropdowns (e.g., "00:00", "00:30", ...).
  final List<String> _timeOptions = _generateTimeOptions();

  @override
  void initState() {
    super.initState();
    print("OpeningHoursWidget: initState");
    // Initialize the internal state based on the initial data passed from the parent
    _updateInternalStateFromWidget(widget.initialOpeningHours);
    // Do NOT notify parent on initial state setup, as no user change has occurred yet.
  }

  /// Updates the internal state when the initialOpeningHours prop changes.
  /// This is crucial if the parent widget loads data asynchronously after initial build.
  @override
  void didUpdateWidget(covariant OpeningHoursWidget oldWidget) {
      super.didUpdateWidget(oldWidget);
      // If the initial data passed from the parent changes, update the internal state
      if (widget.initialOpeningHours != oldWidget.initialOpeningHours) {
          print("OpeningHoursWidget: didUpdateWidget - initialOpeningHours changed, updating internal state.");
          _updateInternalStateFromWidget(widget.initialOpeningHours);
          // No need to notify parent here either, parent controls the data flow via props.
      }
      // Also check if the enabled status changed, might need UI refresh via setState if styling depends on it heavily.
      if (widget.enabled != oldWidget.enabled) {
         print("OpeningHoursWidget: didUpdateWidget - enabled status changed to ${widget.enabled}.");
         // Force rebuild if needed, though build method already uses widget.enabled
         // setState(() {});
      }
  }

  /// Helper function to initialize or update internal state from the OpeningHours prop.
  void _updateInternalStateFromWidget(OpeningHours openingHoursData) {
      _hours = {};
      _isOpen = {};
      for (var day in daysOfWeek) {
          final dayKeyLower = day.toLowerCase(); // Use lowercase for keys if model uses it
          // Check if the day exists in the input data's hours map
          if (openingHoursData.hours.containsKey(dayKeyLower) && openingHoursData.hours[dayKeyLower] != null) {
              // Day is marked as open in the input data
              _isOpen[day] = true;
              // Store the open/close times, providing defaults if specific times are missing
              _hours[day] = {
                  'open': openingHoursData.hours[dayKeyLower]!['open'] ?? '09:00',
                  'close': openingHoursData.hours[dayKeyLower]!['close'] ?? '17:00',
              };
          } else {
              // Day is marked as closed in the input data
              _isOpen[day] = false;
              // Optionally initialize default hours internally even if closed,
              // so they appear when the checkbox is toggled on.
              _hours[day] = {'open': '09:00', 'close': '17:00'};
          }
      }
      print("OpeningHoursWidget: Internal state updated - isOpen: $_isOpen, hours: $_hours");
  }


  /// Generates time options in "HH:MM" format with 30-minute intervals.
  static List<String> _generateTimeOptions() {
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

  /// Constructs an OpeningHours object based on the current internal state
  /// (only including days marked as open) and calls the onHoursChanged callback.
  void _notifyParent() {
    print("OpeningHoursWidget: Notifying parent of changes.");
    // Create a clean map containing only the days that are marked as open
    final Map<String, Map<String, String>> hoursToSend = {};
    _isOpen.forEach((day, isOpen) {
        if (isOpen && _hours.containsKey(day)) {
            // Ensure the map for the day exists and has valid times before adding
            // If _hours doesn't contain the day when isOpen is true, something is wrong,
            // but we check defensively here.
            hoursToSend[day.toLowerCase()] = _hours[day]!; // Use lowercase key for consistency with model?
        }
    });
    print("OpeningHoursWidget: Sending hours to parent: $hoursToSend");
    // Pass the updated OpeningHours object (containing only open days) to the parent
    widget.onHoursChanged(OpeningHours(hours: hoursToSend));
  }

  @override
  Widget build(BuildContext context) {
    // Use the enabled property passed from the parent to control interactivity
    final bool isEnabled = widget.enabled;

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.mediumGrey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
        color: isEnabled ? AppColors.white : AppColors.lightGrey.withOpacity(0.5), // Visual cue when disabled
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Optional: Add a title within the widget itself
          // Text("Set Weekly Hours", style: getTitleStyle(fontSize: 16)),
          // const SizedBox(height: 10),
          Column(
            // Generate rows for each day of the week
            children: daysOfWeek.map((day) {
              // Get current internal state for the day, providing defaults
              bool dayOpen = _isOpen[day] ?? false;
              // Get hours safely, provide defaults if map or keys don't exist
              // Use internal _hours map which always has defaults
              String openTime = _hours[day]?['open'] ?? '09:00';
              String closeTime = _hours[day]?['close'] ?? '17:00';

              return Padding( // Add some padding for better spacing between day rows
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    // Checkbox to mark day as open/closed
                    Checkbox(
                      value: dayOpen,
                      visualDensity: VisualDensity.compact, // Make checkbox smaller
                      // Disable onChanged if the whole widget is not enabled
                      onChanged: isEnabled ? (val) {
                        setState(() {
                          _isOpen[day] = val ?? false; // Update open status
                          if (val == true) {
                            // If opening, ensure default hours are set if not already present
                            // (already handled by _updateInternalStateFromWidget and state initialization)
                            // Re-assign potentially existing values to ensure map exists if needed
                             _hours[day] ??= {'open': '09:00', 'close': '17:00'}; // Ensure map exists
                             _hours[day] = {'open': openTime, 'close': closeTime}; // Use current/default times
                          }
                          // No need to explicitly remove from _hours when closing,
                          // _notifyParent filters based on _isOpen.
                        });
                        _notifyParent(); // Notify parent of the change
                      } : null, // Set onChanged to null to disable checkbox interaction
                      activeColor: AppColors.primaryColor, // Use your AppColors
                      checkColor: AppColors.white,
                      // Style disabled state
                      fillColor: MaterialStateProperty.resolveWith((states) {
                         if (states.contains(MaterialState.disabled)) {
                            return AppColors.mediumGrey.withOpacity(0.3);
                         }
                         return null; // Use default active/inactive colors
                      }),
                    ),
                    const SizedBox(width: 8),
                    // Display Day Name
                    Expanded(
                        child: Text(
                          day,
                          style: getbodyStyle( // Use your text style
                            // Style disabled text differently
                            color: isEnabled ? AppColors.darkGrey : AppColors.mediumGrey
                          )
                        )
                    ),
                    const SizedBox(width: 16), // Spacer before times

                    // Conditionally display time dropdowns or "Closed" text
                    if (dayOpen) ...[
                      // Opening Time Dropdown
                      _buildTimeDropdown(openTime, isEnabled, (value) {
                          if (value != null) {
                            setState(() {
                              // Ensure the map for the day exists before updating
                              _hours[day] ??= {}; // Should already exist if dayOpen is true
                              _hours[day]!['open'] = value;
                              // Optional: Add validation (e.g., open time < close time)
                            });
                            _notifyParent(); // Notify parent of time change
                          }
                      }),
                      const SizedBox(width: 8),
                      Text("-", style: getbodyStyle(color: isEnabled ? null : AppColors.mediumGrey)),
                      const SizedBox(width: 8),
                      // Closing Time Dropdown
                       _buildTimeDropdown(closeTime, isEnabled, (value) {
                          if (value != null) {
                            setState(() {
                               _hours[day] ??= {}; // Should already exist
                              _hours[day]!['close'] = value;
                               // Optional: Add validation (e.g., close time > open time)
                            });
                            _notifyParent(); // Notify parent of time change
                          }
                      }),
                    ] else ...[
                      // Display "Closed" text if checkbox is unchecked
                       Expanded( // Use Expanded to push "Closed" text to the right
                         child: Text(
                            "Closed",
                            textAlign: TextAlign.right, // Align text to the right
                            style: getbodyStyle(color: AppColors.mediumGrey)
                         ),
                       ),
                       // Add SizedBox to roughly match width of dropdowns for alignment, adjust as needed
                       // const SizedBox(width: 180)
                    ]
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Helper widget for building the time selection DropdownButton.
  Widget _buildTimeDropdown(String currentValue, bool isEnabled, ValueChanged<String?> onChanged) {
      // Ensure the currentValue exists in the options, otherwise default to the first option
      // This prevents errors if the initial data has an invalid time format.
      final validValue = _timeOptions.contains(currentValue) ? currentValue : _timeOptions.first;

      // Use a simple DropdownButton for time selection
      return DropdownButton<String>(
          value: validValue, // The currently selected time
          items: _timeOptions.map((time) => DropdownMenuItem(
              value: time,
              child: Text(time, style: getbodyStyle( // Style dropdown items
                  // Adjust text color based on enabled state
                  color: isEnabled ? AppColors.darkGrey : AppColors.mediumGrey,
                  fontSize: 14 // Slightly smaller font for dropdown
              )),
          )).toList(),
          // Disable onChanged callback if the widget is not enabled
          onChanged: isEnabled ? onChanged : null,
          underline: Container(), // Optional: remove default underline for cleaner look
          // Style the selected value text shown in the button
          style: getbodyStyle(color: isEnabled ? AppColors.darkGrey : AppColors.mediumGrey),
          // Style the dropdown icon
          iconEnabledColor: isEnabled ? AppColors.darkGrey.withOpacity(0.7) : AppColors.mediumGrey,
          iconDisabledColor: AppColors.mediumGrey.withOpacity(0.5),
          isDense: true, // Make dropdown more compact
          // Consider adding focusNode, alignment, etc. if needed
       );
  }

}

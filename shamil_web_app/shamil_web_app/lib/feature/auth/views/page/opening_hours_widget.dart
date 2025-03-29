import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart';

class OpeningHoursWidget extends StatefulWidget {
  final Map<String, Map<String, String>> initialHours;
  final Function(Map<String, Map<String, String>>) onHoursChanged;

  const OpeningHoursWidget({
    super.key,
    required this.initialHours,
    required this.onHoursChanged,
  });

  @override
  State<OpeningHoursWidget> createState() => _OpeningHoursWidgetState();
}

class _OpeningHoursWidgetState extends State<OpeningHoursWidget> {
  Map<String, Map<String, String>> _hours = {};

  @override
  void initState() {
    super.initState();
    _hours = widget.initialHours;
  }

  void _updateHours(Map<String, Map<String, String>> newHours) {
    setState(() {
      _hours = newHours;
    });
    widget.onHoursChanged(_hours);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Opening Hours",
          style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.5),
        ),
        const SizedBox(height: 10),

        // Add logic to display/edit opening hours dynamically
        // Example: Allow users to add/remove days and set open/close times
        // You can use a table or grid layout for each day of the week
        // with text fields for open/close times

        // Placeholder for dynamic opening hours input
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 7, // Days of the week
          itemBuilder: (context, index) {
            final dayOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][index];
            return ListTile(
              title: Text(dayOfWeek),
              subtitle: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Open Time',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _hours[dayOfWeek] = {'open': value};
                        });
                        _updateHours(_hours);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Close Time',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _hours[dayOfWeek] = {'close': value};
                        });
                        _updateHours(_hours);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
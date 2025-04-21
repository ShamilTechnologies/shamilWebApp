/// File: lib/features/dashboard/views/pages/access_control_screen.dart
/// --- Placeholder screen for managing Access Control ---

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/bloc/access_control_bloc/access_control_bloc.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/helper/dashboard_widgets.dart'; // Adjust path

class AccessControlScreen extends StatelessWidget {
  const AccessControlScreen({super.key});

  // --- Placeholder Action Handlers ---
  void _showLogDetailsDialog(BuildContext context, AccessLog log) {
    final dateTimeFormat = DateFormat(
      'd MMM yyyy, hh:mm:ss a',
    ); // Detailed format
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text("Access Log Details"),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  _buildDetailRow("Log ID:", log.id),
                  _buildDetailRow("User ID:", log.userId),
                  _buildDetailRow("User Name:", log.userName),
                  _buildDetailRow(
                    "Timestamp:",
                    dateTimeFormat.format(log.timestamp.toDate()),
                  ),
                  _buildDetailRow("Status:", log.status),
                  _buildDetailRow("Method:", log.method ?? "N/A"),
                  if (log.denialReason != null && log.denialReason!.isNotEmpty)
                    _buildDetailRow("Denial Reason:", log.denialReason!),
                  _buildDetailRow("Provider ID:", log.providerId),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Close'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
    );
  }

  // Helper for dialog rows
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label ", style: getbodyStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, style: getbodyStyle())),
        ],
      ),
    );
  }
  // --- End Placeholder Action Handlers ---

  @override
  Widget build(BuildContext context) {
    // Provide the Bloc for this screen subtree
    return BlocProvider(
      create:
          (context) =>
              AccessControlBloc()
                ..add(const LoadAccessLogs()), // Load logs initially
      child: Scaffold(
        // No AppBar - Title and content managed within the body
        backgroundColor: AppColors.lightGrey, // Match dashboard background
        body: ListView(
          // Use ListView for overall scrollable content
          padding: const EdgeInsets.all(
            24.0,
          ), // Padding for the whole screen content
          children: [
            // --- Screen Header ---
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                "Access Control Log",
                style: getTitleStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),

            // --- Filter/Search Bar Placeholder ---
            _FilterBar(), // Placeholder for filter controls
            const SizedBox(height: 20),

            // --- Log List Section ---
            buildSectionContainer(
              title: "Recent Activity",
              padding: const EdgeInsets.all(0), // Let list handle padding
              // TODO: Add 'Refresh' button or integrate with main refresh?
              child: BlocBuilder<AccessControlBloc, AccessControlState>(
                builder: (context, state) {
                  if (state is AccessControlLoading &&
                      state is! AccessControlLoaded) {
                    return const Center(
                      heightFactor: 5,
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (state is AccessControlError) {
                    return Center(
                      heightFactor: 5,
                      child: Text(
                        "Error: ${state.message}",
                        style: getbodyStyle(color: AppColors.redColor),
                      ),
                    );
                  }
                  if (state is AccessControlLoaded) {
                    if (state.accessLogs.isEmpty) {
                      return buildEmptyState("No access logs found.");
                    }
                    // Display the list using ListView.separated and custom items
                    return ListView.separated(
                      shrinkWrap: true, // Important inside another scrollable
                      physics:
                          const NeverScrollableScrollPhysics(), // Disable scrolling for inner list
                      itemCount: state.accessLogs.length,
                      separatorBuilder:
                          (_, __) => const Divider(
                            height: 1,
                            thickness: 0.5,
                            indent: 16,
                            endIndent: 16,
                          ),
                      itemBuilder: (context, index) {
                        final log = state.accessLogs[index];
                        return _LogListItem(
                          // Use the custom list item widget
                          log: log,
                          onTap: () => _showLogDetailsDialog(context, log),
                        );
                      },
                    );
                  }
                  // Initial state
                  return const Center(
                    heightFactor: 5,
                    child: Text("Loading logs..."),
                  );
                },
              ),
            ),
            // TODO: Add Load More button or infinite scroll listener for pagination
          ],
        ),
      ),
    );
  }
}

// --- Placeholder Widget for Filter Controls ---
class _FilterBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: Implement actual filter controls (Date Picker, Dropdowns, Search Field)
    // TODO: Connect controls to AccessControlBloc events
    return buildSectionContainer(
      title: "Filter & Search",
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search by User Name or ID...",
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 10,
                ),
              ),
              style: getbodyStyle(),
              onChanged: (value) {
                // TODO: Dispatch search event to Bloc (maybe with debounce)
              },
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            icon: Icon(Icons.calendar_today_outlined, size: 16),
            label: Text("Date Range"), // TODO: Show selected range
            onPressed: () {
              // TODO: Show Date Range Picker and dispatch filter event
            },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(width: 10),
          // TODO: Add Dropdowns or FilterChips for Status/Method
          Text("Status: All", style: getbodyStyle()), // Placeholder
        ],
      ),
    );
  }
}

// --- Custom Widget for Displaying a Log Item ---
class _LogListItem extends StatelessWidget {
  final AccessLog log;
  final VoidCallback onTap;

  const _LogListItem({
    required this.log,
    required this.onTap,
    super.key, // Use super key
  });

  @override
  Widget build(BuildContext context) {
    final dateTimeFormat = DateFormat('d MMM, hh:mm:ss a');
    final bool granted = log.status.toLowerCase() == 'granted';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Row(
          children: [
            // Status Icon
            Icon(
              granted
                  ? Icons.check_circle_outline_rounded
                  : Icons.highlight_off_rounded,
              color: granted ? Colors.green.shade600 : AppColors.redColor,
              size: 28,
            ),
            const SizedBox(width: 16),
            // User Info
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.userName,
                    style: getbodyStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "ID: ${log.userId}", // Show User ID subtly
                    style: getSmallStyle(color: AppColors.mediumGrey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Status Chip
            Expanded(
              flex: 2,
              child: buildStatusChip(log.status), // Use common helper
            ),
            const SizedBox(width: 16),
            // Method & Time
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    dateTimeFormat.format(log.timestamp.toDate()),
                    style: getSmallStyle(
                      color: AppColors.darkGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Method: ${log.method ?? 'N/A'}${log.denialReason != null ? ' (${log.denialReason})' : ''}",
                    style: getSmallStyle(color: AppColors.secondaryColor),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

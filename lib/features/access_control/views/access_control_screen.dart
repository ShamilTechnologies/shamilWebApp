/// File: lib/features/dashboard/views/pages/access_control_screen.dart
/// --- Screen for viewing logs AND performing access validation ---
/// --- UPDATED: Added buildWhen to BlocBuilders ---
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
// Added import for collection equality
import 'package:collection/collection.dart';

// Only needed for Timestamp in AccessLog model
// Import QR Scanner

// Import Models and Utils needed
// *** IMPORTANT: Ensure these paths are correct for your project structure ***
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/access_control/service/nfc_reader_service.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart'; // For AccessLog model
import 'package:shamil_web_app/features/dashboard/helper/dashboard_widgets.dart';
// Import common helper widgets/functions
// *** Ensure this path is correct ***
// Import the Blocs
// *** Ensure these paths are correct ***
import 'package:shamil_web_app/features/access_control/bloc/access_control_bloc/access_control_bloc.dart';
import 'package:shamil_web_app/features/access_control/bloc/access_point_bloc.dart';
// Import Dashboard Bloc to read provider info
import 'package:shamil_web_app/features/dashboard/bloc/dashboard_bloc.dart';
// Import NFC Service for Enum (used in AccessPointState)

class AccessControlScreen extends StatefulWidget {
  // Added const constructor
  const AccessControlScreen({super.key});

  @override
  State<AccessControlScreen> createState() => _AccessControlScreenState();
}

class _AccessControlScreenState extends State<AccessControlScreen> {
  // State variable for selected COM port (managed locally in this screen)
  String? _selectedComPort;
  final ScrollController _logScrollController =
      ScrollController(); // For potential infinite scroll

  // --- Dialog Helpers (Log Details) ---
  void _showLogDetailsDialog(BuildContext context, AccessLog log) {
    final dateTimeFormat = DateFormat('d MMM EEE, hh:mm:ss a');
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            // Added const
            title: const Text("Access Log Details"),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  _buildDetailRow("Log ID:", log.id ?? "N/A"),
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
                // Added const
                child: const Text('Close'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      // Added const
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
  // --- End Dialog Helpers ---

  // Dispose scroll controller
  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AccessPointBloc needs DashboardBloc, ensure it's provided above this screen
    // final dashboardBloc = BlocProvider.of<DashboardBloc>(context); // Not strictly needed here anymore

    // Provide the Blocs needed for this screen's functionality
    return MultiBlocProvider(
      providers: [
        // AccessControlBloc is for viewing logs shown on this screen
        BlocProvider(
          create: (context) => AccessControlBloc()..add(const LoadAccessLogs()),
        ),
      ],
      child: Container(
        color: AppColors.lightGrey,
        // Use Scaffold to easily add AppBar if needed later
        child: Scaffold(
          backgroundColor: AppColors.lightGrey,
          // Removed AppBar for integration into DashboardScreen
          body: ListView(
            // Use ListView to allow scrolling of all sections together
            controller: _logScrollController, // Attach scroll controller
            padding: const EdgeInsets.all(24.0),
            children: [
              // --- Screen Header ---
              _buildScreenHeader(),
              const SizedBox(height: 20),

              // --- NFC Reader Configuration & Status Section ---
              _buildNfcConfigSection(), // Renamed section
              const SizedBox(height: 20),

              // --- Last Validation Result Display ---
              _buildLastValidationResultSection(), // Separated result display
              const SizedBox(height: 20),

              // --- Filter/Search Bar for Logs ---
              const _FilterBar(), // Keep placeholder filter bar
              const SizedBox(height: 20),

              // --- Log List Section ---
              _buildLogListSection(), // This now contains the paginated list
            ],
          ),
        ),
      ),
    );
  }

  // --- Extracted Widget Builders ---

  Widget _buildScreenHeader() {
    return Padding(
      // Added const
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Access Control",
            style: getTitleStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          // Add Mobile App Data Refresh Button
          BlocBuilder<AccessControlBloc, AccessControlState>(
            builder: (context, state) {
              // Show loading indicator if syncing
              bool isSyncing =
                  state is AccessControlLoading && !state.isLoadingMore;

              return TextButton.icon(
                onPressed:
                    isSyncing
                        ? null
                        : () async {
                          // Show loading state
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Refreshing data from mobile app structure...',
                              ),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          // Call the mobile app data refresh method
                          final result =
                              await context
                                  .read<AccessControlBloc>()
                                  .repository
                                  .refreshMobileAppData();

                          // Show result
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result
                                      ? 'Mobile app data refreshed successfully!'
                                      : 'Failed to refresh mobile app data.',
                                ),
                                backgroundColor:
                                    result
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                              ),
                            );

                            // Reload logs if successful
                            if (result) {
                              context.read<AccessControlBloc>().add(
                                const LoadAccessLogs(),
                              );
                            }
                          }
                        },
                icon:
                    isSyncing
                        ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentColor,
                          ),
                        )
                        : Icon(Icons.sync, color: AppColors.secondaryColor),
                label: Text(
                  'Sync Mobile App Data',
                  style: getbodyStyle(color: AppColors.secondaryColor),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.lightGrey.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNfcConfigSection() {
    return buildSectionContainer(
      title: "NFC Reader Connection",
      // Added const
      padding: const EdgeInsets.all(20),
      child: BlocBuilder<AccessPointBloc, AccessPointState>(
        // *** ADDED buildWhen for NFC section ***
        buildWhen: (previous, current) {
          return previous.nfcStatus != current.nfcStatus ||
              !const ListEquality().equals(
                previous.availablePorts,
                current.availablePorts,
              );
        },
        builder: (context, state) {
          print(
            "BUILDER: _buildNfcConfigSection - State: ${state.runtimeType}",
          ); // Debug log
          bool isConnected =
              state.nfcStatus == SerialPortConnectionStatus.connected;
          bool isConnecting =
              state.nfcStatus == SerialPortConnectionStatus.connecting;
          bool isError = state.nfcStatus == SerialPortConnectionStatus.error;

          // Update local state for dropdown if needed (safe check)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                _selectedComPort != null &&
                !state.availablePorts.contains(_selectedComPort)) {
              setState(() => _selectedComPort = null);
            }
          });

          return Row(
            children: [
              // Added const
              const Icon(Icons.nfc_rounded, color: AppColors.secondaryColor),
              // Added const
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedComPort,
                  // Added const
                  hint: const Text("Select NFC Reader Port"),
                  items:
                      state.availablePorts
                          .map(
                            (port) => DropdownMenuItem(
                              value: port,
                              child: Text(port),
                            ),
                          )
                          .toList(),
                  onChanged:
                      isConnected || isConnecting
                          ? null
                          : (value) {
                            setState(() {
                              _selectedComPort = value;
                            });
                          },
                  // Added const
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              // Added const
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed:
                    (_selectedComPort == null || isConnecting)
                        ? null // Disable if no port selected or connecting
                        : () {
                          if (isConnected) {
                            context.read<AccessPointBloc>().add(
                              DisconnectNfcReader(),
                            );
                          } else {
                            context.read<AccessPointBloc>().add(
                              ConnectNfcReader(portName: _selectedComPort!),
                            );
                          }
                        },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isConnected
                          ? AppColors.secondaryColor
                          : AppColors.primaryColor,
                  // Added const
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child:
                    isConnecting
                        // Added const
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Text(isConnected ? "Disconnect" : "Connect"),
              ),
              // Added const
              const SizedBox(width: 10),
              // Status Indicator
              Tooltip(
                message:
                    isError
                        ? "Connection Error"
                        : (isConnected
                            ? "Connected & Listening"
                            : (isConnecting
                                ? "Connecting..."
                                : "Disconnected")),
                child: Icon(
                  isError
                      ? Icons.error_outline
                      : (isConnected
                          ? Icons.sensors_rounded
                          : (isConnecting
                              ? Icons.sync_rounded
                              : Icons.sensors_off_rounded)), // Updated icons
                  color:
                      isError
                          ? AppColors.redColor
                          : (isConnected
                              ? Colors.green
                              : (isConnecting
                                  ? AppColors.secondaryColor
                                  : AppColors.mediumGrey)),
                  size: 24, // Slightly larger icon
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLastValidationResultSection() {
    return BlocBuilder<AccessPointBloc, AccessPointState>(
      // *** ADDED buildWhen for Validation Result Section ***
      // Rebuild only if the state type changes OR if it's a Result state and the content differs
      buildWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        if (current is AccessPointResult && previous is AccessPointResult) {
          return current != previous; // Use Equatable comparison
        }
        // Only rebuild other state transitions (e.g., Initial -> Validating)
        return current is! AccessPointResult || previous is! AccessPointResult;
      },
      builder: (context, state) {
        print(
          "BUILDER: _buildLastValidationResultSection - State: ${state.runtimeType}",
        ); // Debug log
        Widget content;
        if (state is AccessPointResult) {
          content = _buildValidationResultWidget(state);
        } else if (state is AccessPointValidating) {
          // Added const
          content = const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            // Added const
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Text("Validating...")],
            ),
          );
        } else {
          bool isNfcConnected =
              state.nfcStatus == SerialPortConnectionStatus.connected;
          content = Padding(
            // Added const
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              isNfcConnected
                  ? "Ready for NFC Tag..."
                  : "Connect NFC Reader to see validation results.",
              style: getbodyStyle(color: AppColors.mediumGrey),
              textAlign: TextAlign.center,
            ),
          );
        }

        return buildSectionContainer(
          title: "Last Scan Result",
          // Added const
          padding: const EdgeInsets.all(20),
          trailingAction:
              (state is AccessPointResult || state is AccessPointValidating)
                  ? TextButton(
                    onPressed:
                        () => context.read<AccessPointBloc>().add(
                          ResetAccessPoint(),
                        ),
                    // Added const
                    child: const Text("Clear"),
                  )
                  : null,
          child: AnimatedSize(
            // Added const
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: content,
          ),
        );
      },
    );
  }

  // Widget to display the validation result - No change needed
  Widget _buildValidationResultWidget(AccessPointResult state) {
    // ... same as before ...
    IconData icon;
    Color color;
    switch (state.validationStatus) {
      case ValidationStatus.granted:
        icon = Icons.check_circle_rounded;
        color = Colors.green.shade700;
        break;
      case ValidationStatus.denied:
        icon = Icons.cancel_rounded;
        color = AppColors.redColor;
        break;
      case ValidationStatus.error:
        icon = Icons.error_rounded;
        color = Colors.orange.shade800;
        break;
      default:
        icon = Icons.info_rounded;
        color = AppColors.mediumGrey;
        break;
    }
    return Container(
      // Added const
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          // Added const
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.validationStatus.name.toUpperCase(),
                  style: getTitleStyle(
                    fontSize: 16,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (state.userName != null)
                  Padding(
                    // Added const
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      state.userName!,
                      style: getbodyStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                if (state.message != null)
                  Padding(
                    // Added const
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      state.message!,
                      style: getbodyStyle(color: color.withOpacity(0.9)),
                    ),
                  ),
                Padding(
                  // Added const
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    "ID: ${state.scannedId} (${state.method})",
                    style: getSmallStyle(color: AppColors.mediumGrey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Updated Log List Section with Pagination UI ---
  Widget _buildLogListSection() {
    return buildSectionContainer(
      title: "Recent Activity Log",
      padding: const EdgeInsets.all(0), // Let list handle padding
      trailingAction: IconButton(
        // Added const
        icon: const Icon(
          Icons.refresh_rounded,
          color: AppColors.secondaryColor,
        ),
        tooltip: "Refresh Log",
        onPressed:
            () => context.read<AccessControlBloc>().add(const LoadAccessLogs()),
      ),
      child: BlocBuilder<AccessControlBloc, AccessControlState>(
        // *** ADDED buildWhen for Log List Section ***
        buildWhen: (previous, current) {
          // Rebuild only if it's an error state or if the loaded logs/flags change
          if (current is AccessControlError) return true;
          if (previous is AccessControlLoaded &&
              current is AccessControlLoaded) {
            // Use ListEquality for logs comparison
            return previous.hasReachedMax != current.hasReachedMax ||
                !const ListEquality().equals(
                  previous.accessLogs,
                  current.accessLogs,
                );
          }
          // Rebuild if transitioning between loading/loaded/initial/error states
          return previous.runtimeType != current.runtimeType;
        },
        builder: (context, state) {
          print(
            "BUILDER: _buildLogListSection - State: ${state.runtimeType}",
          ); // Debug log
          // Handle initial loading
          if (state is AccessControlLoading && !state.isLoadingMore) {
            // Added const
            return const Center(
              heightFactor: 5,
              child: CircularProgressIndicator(),
            );
          }
          // Handle error state
          if (state is AccessControlError) {
            return Center(
              heightFactor: 5,
              child: Text(
                "Error loading logs: ${state.message}",
                style: getbodyStyle(color: AppColors.redColor),
              ),
            );
          }
          // Handle loaded or loading more states
          if (state is AccessControlLoaded ||
              (state is AccessControlLoading && state.isLoadingMore)) {
            // Determine the list of logs and flags based on the current state
            final List<AccessLog> logs;
            final bool hasReachedMax;
            final bool isLoadingMore;

            if (state is AccessControlLoaded) {
              logs = state.accessLogs;
              hasReachedMax = state.hasReachedMax;
              isLoadingMore = false;
            } else {
              // Must be AccessControlLoading && state.isLoadingMore
              // Access the underlying loaded state to display existing logs while loading more
              final underlyingState = context.read<AccessControlBloc>().state;
              logs =
                  underlyingState is AccessControlLoaded
                      ? underlyingState.accessLogs
                      : [];
              hasReachedMax = false;
              isLoadingMore = true;
            }

            // Handle empty state
            if (logs.isEmpty && !isLoadingMore) {
              return buildEmptyState("No access logs found.");
            }

            // Build the list view + load more button/indicator
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListView.separated(
                  shrinkWrap: true, // Important within Column/ListView parent
                  physics:
                      const NeverScrollableScrollPhysics(), // Parent ListView handles scroll
                  // Add 1 extra item slot for the button/indicator if not maxed out
                  itemCount: logs.length + (hasReachedMax ? 0 : 1),
                  // Added const
                  separatorBuilder:
                      (_, __) => const Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 20,
                        endIndent: 20,
                      ),
                  itemBuilder: (context, index) {
                    // Check if it's the last item potential slot for button/indicator
                    if (index >= logs.length) {
                      // If loading more, show indicator
                      if (isLoadingMore) {
                        // Added const Center
                        return const Center(
                          heightFactor: 3,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      // If not loading more and not reached max, show button
                      else if (!hasReachedMax) {
                        return Container(
                          // Added const
                          padding: const EdgeInsets.symmetric(vertical: 15.0),
                          alignment: Alignment.center,
                          child: OutlinedButton(
                            onPressed:
                                () => context.read<AccessControlBloc>().add(
                                  const LoadMoreAccessLogs(),
                                ),
                            // Added const Text
                            child: const Text("Load More Logs"),
                          ),
                        );
                      }
                      // If reached max, return empty container
                      else {
                        // Added const
                        return const SizedBox.shrink();
                      }
                    }
                    // Build the actual log item
                    final log = logs[index];
                    return _LogListItem(
                      log: log,
                      onTap: () => _showLogDetailsDialog(context, log),
                    );
                  },
                ),
              ],
            );
          }
          // Fallback for Initial state or unexpected states
          // Added const Center
          return const Center(heightFactor: 5, child: Text("Loading logs..."));
        },
      ),
    );
  }

  // --- End Updated Log List Section ---
} // End _AccessControlScreenState

// --- Placeholder Widget for Filter Controls ---
class _FilterBar extends StatelessWidget {
  // Added const constructor
  const _FilterBar(); // Private constructor

  @override
  Widget build(BuildContext context) {
    return buildSectionContainer(
      title: "Filter & Search Logs",
      // Added const
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              // Added const InputDecoration
              decoration: InputDecoration(
                hintText: "Search by User Name or ID...",
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                // Added const
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 10,
                ),
              ),
              style: getbodyStyle(),
              onChanged: (value) {
                /* TODO: Dispatch filter event */
              },
            ),
          ),
          // Added const
          const SizedBox(width: 16),
          OutlinedButton.icon(
            // Added const
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            // Added const
            label: const Text("Date Range"),
            onPressed: () {
              /* TODO: Show Date Picker */
            },
            style: OutlinedButton.styleFrom(
              // Added const
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          // Added const
          const SizedBox(width: 10),
          Text("Status: All", style: getbodyStyle()),
          // Added const
          const SizedBox(width: 10),
          Text("Method: All", style: getbodyStyle()),
        ],
      ),
    );
  }
}

// --- Custom Widget for Displaying a Log Item ---
class _LogListItem extends StatelessWidget {
  final AccessLog log;
  final VoidCallback onTap;
  // Added const constructor
  const _LogListItem({required this.log, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final dateTimeFormat = DateFormat('d MMM, hh:mm:ss a');
    final bool granted = log.status.toLowerCase() == 'granted';
    return InkWell(
      onTap: onTap,
      hoverColor: AppColors.primaryColor.withOpacity(0.05),
      child: Padding(
        // Added const
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(
              granted
                  ? Icons.check_circle_outline_rounded
                  : Icons.highlight_off_rounded,
              color: granted ? Colors.green.shade600 : AppColors.redColor,
              size: 28,
            ),
            // Added const
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.userName,
                    style: getbodyStyle(fontWeight: FontWeight.w500),
                  ),
                  // Added const
                  const SizedBox(height: 2),
                  Text(
                    "ID: ${log.userId}",
                    style: getSmallStyle(color: AppColors.mediumGrey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Added const
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: buildStatusChip(log.status),
            ), // Assumes buildStatusChip handles const internally
            // Added const
            const SizedBox(width: 16),
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
                  // Added const
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

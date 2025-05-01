/// File: lib/features/dashboard/views/pages/access_control_screen.dart
/// --- Screen for viewing logs AND performing access validation ---
/// --- UPDATED: Declared _selectedComPort state variable ---
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
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
import 'package:shamil_web_app/features/dashboard/bloc/access_control_bloc/access_control_bloc.dart';
import 'package:shamil_web_app/features/access_control/bloc/access_point_bloc.dart';
// Import Dashboard Bloc to read provider info
import 'package:shamil_web_app/features/dashboard/bloc/dashboard_bloc.dart';
// Import NFC Service for Enum (used in AccessPointState)

class AccessControlScreen extends StatefulWidget {
  const AccessControlScreen({super.key});

  @override
  State<AccessControlScreen> createState() => _AccessControlScreenState();
}

class _AccessControlScreenState extends State<AccessControlScreen> {
  // State variable for selected COM port (managed locally in this screen)
  String? _selectedComPort;

  // --- Dialog Helpers (Log Details) ---
  void _showLogDetailsDialog(BuildContext context, AccessLog log) {
    final dateTimeFormat = DateFormat('d MMM EEE, hh:mm:ss a');
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
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
                child: const Text('Close'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
    );
  }

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
  // --- End Dialog Helpers ---

  // No scanner controller needed anymore
  // @override void dispose() { super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // AccessPointBloc needs DashboardBloc, ensure it's provided above this screen
    final dashboardBloc = BlocProvider.of<DashboardBloc>(context);

    // Provide the Blocs needed for this screen's functionality
    return MultiBlocProvider(
      providers: [
        // AccessControlBloc is for viewing logs shown on this screen
        BlocProvider(
          create: (context) => AccessControlBloc()..add(const LoadAccessLogs()),
        ),
        // AccessPointBloc is provided globally (in main.dart), but we listen to it here
        // We don't need to provide it again, but can access it via context.read or BlocBuilder/Listener
        // If AccessPointBloc wasn't global, you'd provide it here:
        // BlocProvider(create: (context) => AccessPointBloc(dashboardBloc: dashboardBloc)..add(ListAvailablePorts())),
      ],
      child: Container(
        color: AppColors.lightGrey,
        child: ListView(
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
            _FilterBar(),
            const SizedBox(height: 20),

            // --- Log List Section ---
            _buildLogListSection(),
          ],
        ),
      ),
    );
  }

  // --- Extracted Widget Builders ---

  Widget _buildScreenHeader() {
    // Use BlocBuilder to get the sync service instance if needed, or access directly
    // final syncService = AccessControlSyncService(); // Access singleton directly if needed
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Access Control",
            style: getTitleStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          // Removed Sync Buttons - Syncing should ideally be automatic/background
          // Or add a dedicated settings/status area elsewhere if manual sync is needed
        ],
      ),
    );
  }

  Widget _buildNfcConfigSection() {
    // This section now only contains NFC connection controls
    return buildSectionContainer(
      title: "NFC Reader Connection",
      padding: const EdgeInsets.all(20),
      child: BlocBuilder<AccessPointBloc, AccessPointState>(
        // Listen to AccessPointBloc for status/ports
        builder: (context, state) {
          bool isConnected =
              state.nfcStatus == SerialPortConnectionStatus.connected;
          bool isConnecting =
              state.nfcStatus == SerialPortConnectionStatus.connecting;
          bool isError = state.nfcStatus == SerialPortConnectionStatus.error;

          // Ensure selected port is valid if available ports change
          if (_selectedComPort != null &&
              !state.availablePorts.contains(_selectedComPort)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedComPort = null);
            });
          }

          return Row(
            children: [
              const Icon(Icons.nfc_rounded, color: AppColors.secondaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedComPort,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child:
                    isConnecting
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
    // This section listens to the AccessPointBloc to show the *last* validation result
    return BlocBuilder<AccessPointBloc, AccessPointState>(
      builder: (context, state) {
        Widget content;
        if (state is AccessPointResult) {
          content = _buildValidationResultWidget(state);
        } else if (state is AccessPointValidating) {
          // Show a subtle validating indicator or just the previous state
          content = const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Text("Validating...")],
            ),
          ); // Or simply show nothing/previous result
        } else {
          // Show prompt if NFC is connected, otherwise maybe hide section or show different message
          bool isNfcConnected =
              state.nfcStatus == SerialPortConnectionStatus.connected;
          content = Padding(
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
          padding: const EdgeInsets.all(20),
          // Optionally add a clear button linked to ResetAccessPoint event
          trailingAction:
              (state is AccessPointResult || state is AccessPointValidating)
                  ? TextButton(
                    onPressed:
                        () => context.read<AccessPointBloc>().add(
                          ResetAccessPoint(),
                        ),
                    child: const Text("Clear"),
                  )
                  : null,
          child: AnimatedSize(
            // Animate size changes
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: content,
          ),
        );
      },
    );
  }

  // Renamed from _buildValidationResult to avoid conflict if kept locally
  Widget _buildValidationResultWidget(AccessPointResult state) {
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
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      state.userName!,
                      style: getbodyStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                if (state.message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      state.message!,
                      style: getbodyStyle(color: color.withOpacity(0.9)),
                    ),
                  ),
                Padding(
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

  Widget _buildLogListSection() {
    // This part uses the AccessControlBloc (for viewing logs) - unchanged
    return buildSectionContainer(
      title: "Recent Activity Log",
      padding: const EdgeInsets.all(0), // Let list handle padding
      trailingAction: IconButton(
        // Example: Refresh button for logs
        icon: const Icon(
          Icons.refresh_rounded,
          color: AppColors.secondaryColor,
        ),
        tooltip: "Refresh Log",
        onPressed:
            () => context.read<AccessControlBloc>().add(const LoadAccessLogs()),
      ),
      child: BlocBuilder<AccessControlBloc, AccessControlState>(
        builder: (context, state) {
          if (state is AccessControlLoading) {
            return const Center(
              heightFactor: 5,
              child: CircularProgressIndicator(),
            );
          }
          if (state is AccessControlError) {
            return Center(
              heightFactor: 5,
              child: Text(
                "Error loading logs: ${state.message}",
                style: getbodyStyle(color: AppColors.redColor),
              ),
            );
          }
          if (state is AccessControlLoaded) {
            if (state.accessLogs.isEmpty) {
              return buildEmptyState("No access logs found.");
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.accessLogs.length,
              separatorBuilder:
                  (_, __) => const Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 20,
                    endIndent: 20,
                  ),
              itemBuilder: (context, index) {
                final log = state.accessLogs[index];
                return _LogListItem(
                  log: log,
                  onTap: () => _showLogDetailsDialog(context, log),
                );
              },
            );
          }
          return const Center(
            heightFactor: 5,
            child: Text("Loading logs..."),
          ); // Initial state
        },
      ),
    );
  }
} // End _AccessControlScreenState

// --- Placeholder Widget for Filter Controls ---
class _FilterBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return buildSectionContainer(
      title: "Filter & Search Logs",
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search by User Name or ID...",
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
          const SizedBox(width: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: const Text("Date Range"),
            onPressed: () {
              /* TODO: Show Date Picker */
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(width: 10),
          Text("Status: All", style: getbodyStyle()),
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
  const _LogListItem({required this.log, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final dateTimeFormat = DateFormat('d MMM, hh:mm:ss a');
    final bool granted = log.status.toLowerCase() == 'granted';
    return InkWell(
      onTap: onTap,
      hoverColor: AppColors.primaryColor.withOpacity(0.05),
      child: Padding(
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
                  const SizedBox(height: 2),
                  Text(
                    "ID: ${log.userId}",
                    style: getSmallStyle(color: AppColors.mediumGrey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: buildStatusChip(log.status)),
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

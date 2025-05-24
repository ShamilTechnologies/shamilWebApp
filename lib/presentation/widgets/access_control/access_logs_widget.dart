import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/access_control/access_log.dart' as domain;
import '../../../domain/models/access_control/access_result.dart';
import '../../../presentation/bloc/access_control/access_control_bloc.dart';
import '../../../presentation/bloc/access_control/access_control_event.dart';
import '../../../presentation/bloc/access_control/access_control_state.dart';

/// Widget for displaying access logs
class AccessLogsWidget extends StatefulWidget {
  /// Maximum number of logs to display
  final int limit;

  /// Creates an access logs widget
  const AccessLogsWidget({Key? key, this.limit = 50}) : super(key: key);

  @override
  State<AccessLogsWidget> createState() => _AccessLogsWidgetState();
}

class _AccessLogsWidgetState extends State<AccessLogsWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  AccessResult? _filterResult;

  @override
  void initState() {
    super.initState();

    // Load logs when widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccessControlBloc>().add(
        LoadAccessLogsEvent(limit: widget.limit),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccessControlBloc, AccessControlState>(
      builder: (context, state) {
        if (state is AccessLogsLoaded) {
          return _buildLogsList(state.logs);
        } else if (state is AccessControlLoading) {
          return _buildLoadingState();
        } else if (state is AccessControlError) {
          return _buildErrorUI(state);
        } else {
          return _buildEmptyState();
        }
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading access logs...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No access logs available',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Access history will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.read<AccessControlBloc>().add(
                LoadAccessLogsEvent(limit: widget.limit),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList(List<domain.AccessLog> logs) {
    // Apply filters
    final filteredLogs =
        logs.where((log) {
          // Apply result filter
          if (_filterResult != null && log.result != _filterResult) {
            return false;
          }

          // Apply search query
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            final userName = (log.userName ?? '').toLowerCase();
            final reason = (log.reason ?? '').toLowerCase();
            final method = log.method.toLowerCase();

            return userName.contains(query) ||
                reason.contains(query) ||
                method.contains(query) ||
                log.uid.toLowerCase().contains(query);
          }

          return true;
        }).toList();

    if (logs.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFiltersSection(logs),
        Expanded(
          child:
              filteredLogs.isEmpty
                  ? _buildNoResultsFound()
                  : _buildLogsListView(filteredLogs),
        ),
      ],
    );
  }

  Widget _buildFiltersSection(List<domain.AccessLog> allLogs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Access Logs',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.sync),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _filterResult = null;
                      });
                      context.read<AccessControlBloc>().add(
                        LoadAccessLogsEvent(limit: widget.limit),
                      );
                    },
                    tooltip: 'Refresh logs',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search logs',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Granted',
                selected: _filterResult == AccessResult.granted,
                onSelected: (selected) {
                  setState(() {
                    _filterResult = selected ? AccessResult.granted : null;
                  });
                },
                color: Colors.green,
              ),
              const SizedBox(width: 4),
              _buildFilterChip(
                label: 'Denied',
                selected: _filterResult == AccessResult.denied,
                onSelected: (selected) {
                  setState(() {
                    _filterResult = selected ? AccessResult.denied : null;
                  });
                },
                color: Colors.red,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Showing ${_formatLogCount(allLogs.length, _getFilteredCount(allLogs))}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
    required Color color,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? Colors.white : null,
        fontWeight: selected ? FontWeight.bold : null,
      ),
      selectedColor: color,
      avatar: Icon(
        selected
            ? (label == 'Granted' ? Icons.check_circle : Icons.cancel)
            : (label == 'Granted'
                ? Icons.check_circle_outline
                : Icons.cancel_outlined),
        size: 16,
        color: selected ? Colors.white : color,
      ),
    );
  }

  int _getFilteredCount(List<domain.AccessLog> allLogs) {
    if (_searchQuery.isEmpty && _filterResult == null) {
      return allLogs.length;
    }

    return allLogs.where((log) {
      // Apply result filter
      if (_filterResult != null && log.result != _filterResult) {
        return false;
      }

      // Apply search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final userName = (log.userName ?? '').toLowerCase();
        final reason = (log.reason ?? '').toLowerCase();
        final method = log.method.toLowerCase();

        return userName.contains(query) ||
            reason.contains(query) ||
            method.contains(query) ||
            log.uid.toLowerCase().contains(query);
      }

      return true;
    }).length;
  }

  String _formatLogCount(int total, int filtered) {
    if (filtered == total) {
      return '$total logs';
    } else {
      return '$filtered of $total logs';
    }
  }

  Widget _buildNoResultsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _filterResult = null;
              });
            },
            icon: const Icon(Icons.filter_list_off),
            label: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsListView(List<domain.AccessLog> logs) {
    return ListView.builder(
      itemCount: logs.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final log = logs[index];
        return _buildLogItem(log);
      },
    );
  }

  Widget _buildLogItem(domain.AccessLog log) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final formattedDate = dateFormat.format(log.timestamp);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _showLogDetails(log),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusIcon(log.result),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            log.userName ?? 'Unknown User',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _methodColor(log.method).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            log.method,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color: _methodColor(log.method),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    if (log.reason != null && log.reason!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        log.reason!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              log.result == AccessResult.denied
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                        ),
                      ),
                    ],
                    if (log.needsSync)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sync,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Pending sync',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.orange),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(AccessResult result) {
    final color = result == AccessResult.granted ? Colors.green : Colors.red;
    final icon = result == AccessResult.granted ? Icons.check : Icons.close;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Color _methodColor(String method) {
    switch (method.toLowerCase()) {
      case 'nfc':
        return Colors.blue;
      case 'qr':
        return Colors.purple;
      case 'manual':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  void _showLogDetails(domain.AccessLog log) {
    final dateFormat = DateFormat('MMMM d, yyyy • h:mm:ss a');
    final formattedDate = dateFormat.format(log.timestamp);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              log.result == AccessResult.granted
                  ? 'Access Granted'
                  : 'Access Denied',
              style: TextStyle(
                color:
                    log.result == AccessResult.granted
                        ? Colors.green
                        : Colors.red,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('User ID:', log.uid),
                _buildDetailRow('Name:', log.userName ?? 'Unknown'),
                _buildDetailRow('Time:', formattedDate),
                _buildDetailRow('Method:', log.method),
                if (log.reason != null) _buildDetailRow('Reason:', log.reason!),
                _buildDetailRow('Synced:', !log.needsSync ? 'Yes' : 'No'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
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
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildErrorUI(AccessControlError state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.orange, size: 48),
          const SizedBox(height: 16),
          Text(
            'Error loading logs',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(state.message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              context.read<AccessControlBloc>().add(
                LoadAccessLogsEvent(limit: widget.limit),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

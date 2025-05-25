import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/features/dashboard/bloc/users/user_bloc.dart';
import 'package:shamil_web_app/features/dashboard/bloc/users/user_event.dart';
import 'package:shamil_web_app/features/dashboard/bloc/users/user_state.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_profile_dialog.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_management/components/user_detail_panel.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_management/components/user_table.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_management/components/sidebar_filter.dart';
import 'package:shamil_web_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:shamil_web_app/core/services/centralized_data_service.dart';

/// Main user management screen with desktop-like interface
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late UserBloc _userBloc;
  final CentralizedDataService _dataService = CentralizedDataService();

  // Selected user for detail panel
  AppUser? _selectedUser;

  // Filtering and sorting state
  String _searchQuery = '';
  String _filterType = 'All';
  String _sortField = 'name';
  bool _sortAscending = true;

  // View type: 'all', 'reserved', 'subscribed', 'active'
  String _viewType = 'all';

  // Advanced filters
  DateTime? _fromDate;
  DateTime? _toDate;
  List<String> _selectedServiceTypes = [];
  bool _showExpiredSubscriptions = false;

  @override
  void initState() {
    super.initState();

    // Register keyboard shortcuts
    _registerKeyboardShortcuts();

    // Create and initialize UserBloc
    _userBloc = UserBloc();

    // Check if data is already available in dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndUseDashboardData();
    });

    // Set up auto-refresh timer
    Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        _userBloc.add(const RefreshUsers(showLoadingIndicator: false));
      }
    });
  }

  void _checkAndUseDashboardData() async {
    // Check if DashboardBloc has already loaded data
    try {
      final dashboardState = context.read<DashboardBloc>().state;
      if (dashboardState is DashboardLoadSuccess) {
        print("UserManagementScreen: Using existing data from DashboardBloc");

        // Extract user data from dashboard state
        final usersMap = <String, AppUser>{};

        // First, collect all users from subscriptions
        print(
          "UserManagementScreen: Processing ${dashboardState.subscriptions.length} subscriptions",
        );
        for (final subscription in dashboardState.subscriptions) {
          if (subscription.userId != null) {
            final String userId = subscription.userId!;
            final String userName = subscription.userName ?? 'Unknown User';

            // Create the record
            final record = RelatedRecord(
              id: subscription.id ?? '',
              type: RecordType.subscription,
              name: subscription.planName ?? 'Membership',
              status: subscription.status ?? 'Unknown',
              date: subscription.startDate?.toDate() ?? DateTime.now(),
              additionalData: {
                'planName': subscription.planName,
                'startDate': subscription.startDate?.toDate(),
                'expiryDate': subscription.expiryDate?.toDate(),
                'status': subscription.status,
              },
            );

            // Add to map or update existing
            if (usersMap.containsKey(userId)) {
              // Add record to existing user
              final existingRecords = List<RelatedRecord>.from(
                usersMap[userId]!.relatedRecords,
              );
              existingRecords.add(record);

              // Update user type
              final currentType = usersMap[userId]!.userType;
              final newType =
                  currentType == UserType.reserved
                      ? UserType.both
                      : UserType.subscribed;

              usersMap[userId] = usersMap[userId]!.copyWith(
                relatedRecords: existingRecords,
                userType: newType,
                name:
                    userName != 'Unknown User'
                        ? userName
                        : usersMap[userId]!.name,
              );
            } else {
              // Create new user
              usersMap[userId] = AppUser(
                userId: userId,
                name: userName,
                userType: UserType.subscribed,
                relatedRecords: [record],
              );
            }
          }
        }

        // Then, process reservations and add/update users
        print(
          "UserManagementScreen: Processing ${dashboardState.reservations.length} reservations",
        );
        for (final reservation in dashboardState.reservations) {
          if (reservation.userId != null) {
            final String userId = reservation.userId!;
            final String userName = reservation.userName ?? 'Unknown User';

            // Create the record
            final record = RelatedRecord(
              id: reservation.id ?? '',
              type: RecordType.reservation,
              name: reservation.serviceName ?? 'Reservation',
              status: reservation.status ?? 'Unknown',
              date: reservation.dateTime?.toDate() ?? DateTime.now(),
              additionalData: {
                'startTime': reservation.dateTime?.toDate(),
                'endTime': reservation.endTime,
                'notes': reservation.notes,
                'groupSize': reservation.groupSize,
              },
            );

            if (usersMap.containsKey(userId)) {
              // Add record to existing user
              final existingRecords = List<RelatedRecord>.from(
                usersMap[userId]!.relatedRecords,
              );
              existingRecords.add(record);

              // Determine user type (reserved, subscribed, or both)
              final currentType = usersMap[userId]!.userType;
              final newType =
                  currentType == UserType.subscribed
                      ? UserType.both
                      : UserType.reserved;

              usersMap[userId] = usersMap[userId]!.copyWith(
                relatedRecords: existingRecords,
                userType: newType,
                name:
                    userName != 'Unknown User'
                        ? userName
                        : usersMap[userId]!.name,
              );
            } else {
              // Create new user
              usersMap[userId] = AppUser(
                userId: userId,
                name: userName,
                userType: UserType.reserved,
                relatedRecords: [record],
              );
            }
          }
        }

        // Note: We're intentionally skipping users from access logs that have no reservations or subscriptions
        // per the requirement to only get users who reserved or subscribed to the service

        // Convert map to list - now only contains users with reservations or subscriptions
        final usersList = usersMap.values.toList();
        print(
          "UserManagementScreen: Collected ${usersList.length} users with reservations or subscriptions",
        );

        // Display the list while we enrich it (better UX)
        _userBloc.add(UsersUpdated(usersList));

        // Now enrich the users with additional details from CentralizedDataService
        final enrichedUsers = <AppUser>[];

        // Process users in smaller batches to avoid UI freezes
        const batchSize = 10;
        for (var i = 0; i < usersList.length; i += batchSize) {
          final batch = usersList.sublist(
            i,
            i + batchSize < usersList.length ? i + batchSize : usersList.length,
          );

          print(
            "UserManagementScreen: Enriching batch ${i ~/ batchSize + 1} of ${(usersList.length / batchSize).ceil()}",
          );

          // Enrich each user in the batch with full details
          for (final user in batch) {
            try {
              // Use a more direct approach to get complete user details from Firestore
              final userDoc =
                  await FirebaseFirestore.instance
                      .collection('endUsers')
                      .doc(user.userId)
                      .get();

              // If user document exists, extract all available fields
              if (userDoc.exists && userDoc.data() != null) {
                final userData = userDoc.data()!;

                // Extract name from various possible fields
                final userName =
                    userData['displayName'] ??
                    userData['name'] ??
                    userData['userName'] ??
                    userData['fullName'] ??
                    user.name;

                // Create enriched user with all available details
                final enrichedUser = user.copyWith(
                  name:
                      userName != 'Unknown User'
                          ? userName.toString()
                          : user.name,
                  email: userData['email'] as String?,
                  phone: userData['phone'] as String?,
                  profilePicUrl:
                      userData['profilePicUrl'] ??
                      userData['photoURL'] ??
                      userData['image'] as String?,
                );

                enrichedUsers.add(enrichedUser);
                print(
                  "UserManagementScreen: Successfully enriched user ${user.userId}",
                );
              } else {
                // Fallback to centralized service if direct approach fails
                final fullUserData = await _dataService.getUserById(
                  user.userId,
                );

                if (fullUserData != null) {
                  // Keep name from records if we have it and fullUserData has unknown name
                  final bestName =
                      fullUserData.name == 'Unknown User' &&
                              user.name != 'Unknown User'
                          ? user.name
                          : fullUserData.name;

                  // Merge the data, keeping the records we've already built
                  final mergedUser = fullUserData.copyWith(
                    relatedRecords: user.relatedRecords,
                    userType: user.userType,
                    name: bestName,
                  );
                  enrichedUsers.add(mergedUser);
                } else {
                  // If user details not found, just use what we have
                  print(
                    "UserManagementScreen: Could not find additional details for user ${user.userId}",
                  );
                  enrichedUsers.add(user);
                }
              }
            } catch (e) {
              print(
                "UserManagementScreen: Error enriching user ${user.userId}: $e",
              );
              enrichedUsers.add(user);
            }
          }

          // Update the UI with batch progress
          if (mounted) {
            _userBloc.add(
              UsersUpdated([
                ...enrichedUsers,
                ...usersList.sublist(i + batch.length),
              ]),
            );
          }
        }

        // Final update with all enriched users
        _userBloc.add(UsersUpdated(enrichedUsers));
        print(
          "UserManagementScreen: Completed user enrichment with ${enrichedUsers.length} users",
        );
        return;
      }
    } catch (e) {
      print("UserManagementScreen: Error accessing dashboard data: $e");
    }

    // If we get here, either the dashboard data wasn't available or there was an error
    // Fall back to normal data loading (will be filtered for reservations/subscriptions in the bloc)
    _userBloc.add(LoadUsers());
  }

  @override
  void dispose() {
    _userBloc.close();
    super.dispose();
  }

  void _registerKeyboardShortcuts() {
    // This would be implemented with Focus widgets and keyboard handlers
    // For now we'll just define what shortcuts we want

    // Ctrl+F: Focus search
    // Ctrl+R: Refresh data
    // Ctrl+A: Show all users
    // Ctrl+S: Show subscribed users
    // Ctrl+E: Show reserved users
    // Escape: Clear selection
  }

  /// Filter users based on current criteria
  List<AppUser> _filterUsers(List<AppUser> users) {
    // Basic search filter
    var filtered =
        users.where((user) {
          if (_searchQuery.isEmpty) return true;

          return user.userName.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              (user.email?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                  false) ||
              (user.phone?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                  false);
        }).toList();

    // Status filter
    if (_filterType != 'All') {
      filtered =
          filtered.where((user) {
            if (_filterType == 'Active') {
              return user.relatedRecords.any(
                (record) =>
                    record.status.toLowerCase() == 'active' ||
                    record.status.toLowerCase() == 'confirmed',
              );
            } else if (_filterType == 'Pending') {
              return user.relatedRecords.any(
                (record) => record.status.toLowerCase() == 'pending',
              );
            } else if (_filterType == 'Completed') {
              return user.relatedRecords.any(
                (record) => record.status.toLowerCase() == 'completed',
              );
            } else if (_filterType == 'Cancelled') {
              return user.relatedRecords.any(
                (record) => record.status.toLowerCase().contains('cancel'),
              );
            }
            return true;
          }).toList();
    }

    // Date range filter (if applicable)
    if (_fromDate != null || _toDate != null) {
      filtered =
          filtered.where((user) {
            // Check if any records fall within the date range
            return user.relatedRecords.any((record) {
              final DateTime recordDate = record.date;
              if (_fromDate != null && recordDate.isBefore(_fromDate!)) {
                return false;
              }
              if (_toDate != null && recordDate.isAfter(_toDate!)) {
                return false;
              }
              return true;
            });
          }).toList();
    }

    // Service type filter (if applicable)
    if (_selectedServiceTypes.isNotEmpty) {
      filtered =
          filtered.where((user) {
            return user.relatedRecords.any((record) {
              return _selectedServiceTypes.contains(record.name);
            });
          }).toList();
    }

    // Expired subscriptions filter
    if (!_showExpiredSubscriptions) {
      final now = DateTime.now();
      filtered =
          filtered.where((user) {
            // If no subscription records, this filter doesn't apply
            final hasSubscriptions = user.relatedRecords.any(
              (r) => r.type == RecordType.subscription,
            );

            if (!hasSubscriptions) return true;

            // Check if user has any active (non-expired) subscriptions
            return user.relatedRecords.any((record) {
              if (record.type != RecordType.subscription) return false;

              final endDate = record.additionalData['endDate'] as DateTime?;
              if (endDate == null) return true; // No end date means not expired

              return endDate.isAfter(now);
            });
          }).toList();
    }

    // Sort the filtered list
    _sortUsers(filtered);

    return filtered;
  }

  /// Sort users based on current criteria
  void _sortUsers(List<AppUser> users) {
    users.sort((a, b) {
      int result;
      switch (_sortField) {
        case 'name':
          result = a.userName.compareTo(b.userName);
          break;
        case 'email':
          final aEmail = a.email ?? '';
          final bEmail = b.email ?? '';
          result = aEmail.compareTo(bEmail);
          break;
        case 'status':
          final aStatus = _getUserStatusText(a);
          final bStatus = _getUserStatusText(b);
          result = aStatus.compareTo(bStatus);
          break;
        case 'records':
          result = a.relatedRecords.length.compareTo(b.relatedRecords.length);
          break;
        default:
          result = 0;
      }

      return _sortAscending ? result : -result;
    });
  }

  String _getUserStatusText(AppUser user) {
    if (user.relatedRecords.any(
      (r) =>
          r.status.toLowerCase().contains('active') ||
          r.status.toLowerCase().contains('confirmed'),
    )) {
      return 'Active';
    } else if (user.relatedRecords.any(
      (r) => r.status.toLowerCase().contains('pending'),
    )) {
      return 'Pending';
    }
    return 'Inactive';
  }

  /// Handle column sorting
  void _onSort(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = true;
      }
    });
  }

  /// Handle user selection
  void _onUserSelected(AppUser? user) {
    setState(() {
      _selectedUser = user;
    });
  }

  /// Handle view type change
  void _onViewTypeChanged(String viewType) {
    setState(() {
      _viewType = viewType;

      // If switching to active users view, trigger load
      if (viewType == 'active') {
        _userBloc.add(LoadActiveUsers());
      }
    });
  }

  /// Handle search query change
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  /// Handle filter type change
  void _onFilterChanged(String filter) {
    setState(() {
      _filterType = filter;
    });
  }

  /// Handle date range filter change
  void _onDateRangeChanged(DateTime? from, DateTime? to) {
    setState(() {
      _fromDate = from;
      _toDate = to;
    });
  }

  /// Handle service types filter change
  void _onServiceTypesChanged(List<String> types) {
    setState(() {
      _selectedServiceTypes = types;
    });
  }

  /// Handle expired subscriptions filter change
  void _onShowExpiredChanged(bool show) {
    setState(() {
      _showExpiredSubscriptions = show;
    });
  }

  /// Clear all filters
  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _filterType = 'All';
      _fromDate = null;
      _toDate = null;
      _selectedServiceTypes = [];
      _showExpiredSubscriptions = false;
    });
  }

  /// View user profile
  void _viewUserProfile(AppUser user) {
    _userBloc.add(ViewUserProfile(user));
  }

  /// Load user details
  void _loadUserDetails(String userId) {
    _userBloc.add(LoadUserServiceDetails(userId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _userBloc,
      child: BlocConsumer<UserBloc, UserState>(
        listener: (context, state) {
          if (state is UserError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          // Handle various states
          return _buildContent(state);
        },
      ),
    );
  }

  Widget _buildContent(UserState state) {
    // Loading state
    if (state is UserLoading && !(state is UserLoaded)) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error state
    if (state is UserError) {
      return _buildErrorState(state);
    }

    // Handle active users state
    if (state is ActiveUsersLoaded) {
      return _buildMainLayout(
        state,
        users: _filterUsers(state.activeUsers),
        isActive: true,
      );
    }

    // Handle regular loaded state
    if (state is UserLoaded) {
      List<AppUser> users;

      switch (_viewType) {
        case 'reserved':
          users = _filterUsers(state.reservedUsers);
          break;
        case 'subscribed':
          users = _filterUsers(state.subscribedUsers);
          break;
        case 'all':
        default:
          users = _filterUsers(state.allUsers);
      }

      return _buildMainLayout(state, users: users, isActive: false);
    }

    // Default loading state
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState(UserError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            state.message,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _userBloc.add(LoadUsers()),
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainLayout(
    UserState state, {
    required List<AppUser> users,
    required bool isActive,
  }) {
    final isRefreshing = state is UserLoaded && state.isRefreshing;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left sidebar with filters
              SizedBox(
                width: 250, // Fixed width for sidebar
                height: constraints.maxHeight,
                child: SidebarFilter(
                  viewType: _viewType,
                  onViewTypeChanged: _onViewTypeChanged,
                  searchQuery: _searchQuery,
                  onSearchChanged: _onSearchChanged,
                  filterType: _filterType,
                  onFilterChanged: _onFilterChanged,
                  fromDate: _fromDate,
                  toDate: _toDate,
                  onDateRangeChanged: _onDateRangeChanged,
                  selectedServiceTypes: _selectedServiceTypes,
                  onServiceTypesChanged: _onServiceTypesChanged,
                  showExpiredSubscriptions: _showExpiredSubscriptions,
                  onShowExpiredChanged: _onShowExpiredChanged,
                  onClearFilters: _clearFilters,
                  onRefreshPressed: () => _userBloc.add(const RefreshUsers()),
                  isRefreshing: isRefreshing,
                  isActive: isActive,
                  // We'll provide these service types from the full dataset
                  availableServiceTypes: _getAvailableServiceTypes(state),
                ),
              ),

              // Vertical divider
              const VerticalDivider(width: 1, thickness: 1),

              // Main content area with data table
              Expanded(
                flex:
                    _selectedUser != null
                        ? 2
                        : 3, // Adjust flex based on detail panel
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header bar with view title and actions
                      _buildHeaderBar(users.length, isActive),

                      // Data table with users
                      Expanded(
                        child: UserTable(
                          users: users,
                          selectedUser: _selectedUser,
                          onUserSelected: _onUserSelected,
                          onViewProfile: _viewUserProfile,
                          onLoadDetails: _loadUserDetails,
                          sortField: _sortField,
                          sortAscending: _sortAscending,
                          onSort: _onSort,
                          isLoading: isRefreshing,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Detail panel (if user is selected)
              if (_selectedUser != null) ...[
                // Vertical divider
                const VerticalDivider(width: 1, thickness: 1),

                // Detail panel
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: UserDetailPanel(
                      user: _selectedUser!,
                      onClose: () => _onUserSelected(null),
                      onViewProfile: _viewUserProfile,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderBar(int userCount, bool isActive) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // View title with count
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              children: [
                TextSpan(
                  text: _getViewTitle(isActive),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: ' ($userCount)',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          // Action buttons
          Row(
            children: [
              // Export button
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Export functionality coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Export'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getViewTitle(bool isActive) {
    if (isActive) return 'Active Users';

    switch (_viewType) {
      case 'reserved':
        return 'Reserved Users';
      case 'subscribed':
        return 'Subscribed Users';
      case 'all':
      default:
        return 'All Users';
    }
  }

  List<String> _getAvailableServiceTypes(UserState state) {
    // Extract unique service types from all records
    final Set<String> types = {};

    if (state is UserLoaded) {
      for (final user in state.allUsers) {
        for (final record in user.relatedRecords) {
          types.add(record.name);
        }
      }
    }

    return types.toList()..sort();
  }
}

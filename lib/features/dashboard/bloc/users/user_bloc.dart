import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamil_web_app/core/services/centralized_data_service.dart';
import 'package:shamil_web_app/features/dashboard/bloc/users/user_event.dart';
import 'package:shamil_web_app/features/dashboard/bloc/users/user_state.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';
import 'package:shamil_web_app/features/dashboard/services/user_reservations_repository.dart';
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart';

/// BLoC for managing user data in the user management screen
class UserBloc extends Bloc<UserEvent, UserState> {
  final CentralizedDataService _dataService = CentralizedDataService();
  final UserReservationsRepository _userReservationsRepository =
      UserReservationsRepository();
  StreamSubscription? _usersSubscription;
  // Flag to track if the bloc is closed
  bool _isClosed = false;

  UserBloc() : super(UserInitial()) {
    on<LoadUsers>(_onLoadUsers);
    on<RefreshUsers>(_onRefreshUsers);
    on<LoadActiveUsers>(_onLoadActiveUsers);
    on<UsersUpdated>(_onUsersUpdated);
    on<SearchUsers>(_onSearchUsers);
    on<FilterUsersByStatus>(_onFilterUsersByStatus);
    on<ViewUserProfile>(_onViewUserProfile);
    on<LoadUserServiceDetails>(_onLoadUserServiceDetails);

    // Initialize data service and subscribe to updates
    _initializeDataService();
  }

  /// Initialize the data service and set up subscriptions
  Future<void> _initializeDataService() async {
    try {
      // Skip initialization if the bloc is closed
      if (_isClosed) {
        print("UserBloc: Skipping initialization as bloc is closed");
        return;
      }

      // Initialize access control service first to ensure Hive adapters are registered
      final accessControlService = AccessControlSyncService();
      await accessControlService.init();

      // Check if data service is already initialized before initializing again
      if (!_dataService.isInitializedNotifier.value) {
        // Now initialize the centralized data service
        await _dataService.init();
      } else {
        print("UserBloc: CentralizedDataService already initialized");
        // Force a refresh of user data even if already initialized
        await _dataService.forceDataRefresh();
      }

      // Set up subscription without forcing a full refresh
      _subscribeToUserUpdates();

      // Skip loading initial data if the bloc is closed
      if (!_isClosed) {
        add(LoadUsers());
      }
    } catch (e) {
      print("UserBloc: Error initializing data service: $e");

      // Try to continue with at least the subscription if the bloc is still active
      if (!_isClosed) {
        try {
          _subscribeToUserUpdates();
          // Load what data we can get
          add(LoadUsers());
        } catch (subscriptionError) {
          print(
            "UserBloc: Error setting up user subscription: $subscriptionError",
          );
        }
      }
    }
  }

  /// Subscribe to user data updates from the centralized service
  void _subscribeToUserUpdates() {
    // Skip if the bloc is already closed
    if (_isClosed) return;

    _usersSubscription = _dataService.usersStream.listen(
      (users) {
        // Check if the bloc is closed before adding an event
        if (!_isClosed) {
          add(UsersUpdated(users));
        }
      },
      onError: (e) {
        print("UserBloc: Error in users stream: $e");
        // Only add event if the bloc is still active
        if (!_isClosed) {
          add(UsersUpdated([])); // Add empty users instead of directly emitting
        }
      },
    );
  }

  /// Handle the LoadUsers event
  Future<void> _onLoadUsers(LoadUsers event, Emitter<UserState> emit) async {
    try {
      emit(UserLoading());

      // Get users from the data service
      final users = await _dataService.getUsers();

      // For each user, enhance the related records with detailed service information
      for (var i = 0; i < users.length; i++) {
        users[i] = await _enrichUserWithServiceDetails(users[i]);
      }

      _processUsers(users, emit);
    } catch (e) {
      emit(UserError("Failed to load users: $e"));
    }
  }

  /// Handle the RefreshUsers event
  Future<void> _onRefreshUsers(
    RefreshUsers event,
    Emitter<UserState> emit,
  ) async {
    try {
      // If we're showing a loading indicator, emit a loading state
      if (event.showLoadingIndicator) {
        emit(UserLoading());
      } else if (state is UserLoaded) {
        // Otherwise, we're doing a background refresh, so keep the current data but mark as refreshing
        emit((state as UserLoaded).copyWith(isRefreshing: true));
      }

      // Step 1: Force a comprehensive refresh of mobile app data
      await _dataService.refreshMobileAppData();

      // Step 2: Get all users with detailed information
      final allUsers = await _dataService.getUsers(forceRefresh: true);

      // Step 3: Enhance each user with detailed service information
      List<AppUser> enhancedUsers = [];
      for (var user in allUsers) {
        final enhancedUser = await _enrichUserWithServiceDetails(user);
        enhancedUsers.add(enhancedUser);
      }

      _processUsers(enhancedUsers, emit);
    } catch (e) {
      emit(UserError("Failed to refresh users: $e"));
    }
  }

  /// Handle the LoadActiveUsers event
  Future<void> _onLoadActiveUsers(
    LoadActiveUsers event,
    Emitter<UserState> emit,
  ) async {
    try {
      emit(UserLoading());

      // Get users with active access
      final activeUsers = await _dataService.getUsersWithActiveAccess();

      // Enhance each active user with service details
      List<AppUser> enhancedActiveUsers = [];
      for (var user in activeUsers) {
        final enhancedUser = await _enrichUserWithServiceDetails(user);
        enhancedActiveUsers.add(enhancedUser);
      }

      emit(ActiveUsersLoaded(enhancedActiveUsers));
    } catch (e) {
      emit(UserError("Failed to load active users: $e"));
    }
  }

  /// Handle user data updates from the stream
  void _onUsersUpdated(UsersUpdated event, Emitter<UserState> emit) {
    _processUsers(event.users, emit);
  }

  /// Process users and separate them by type
  void _processUsers(List<AppUser> users, Emitter<UserState> emit) {
    final reservedUsers =
        users
            .where(
              (user) =>
                  user.userType == UserType.reserved ||
                  user.userType == UserType.both,
            )
            .toList();

    final subscribedUsers =
        users
            .where(
              (user) =>
                  user.userType == UserType.subscribed ||
                  user.userType == UserType.both,
            )
            .toList();

    emit(
      UserLoaded(
        allUsers: users,
        reservedUsers: reservedUsers,
        subscribedUsers: subscribedUsers,
        isRefreshing: false,
      ),
    );
  }

  /// Handle the LoadUserServiceDetails event
  Future<void> _onLoadUserServiceDetails(
    LoadUserServiceDetails event,
    Emitter<UserState> emit,
  ) async {
    try {
      if (state is! UserLoaded) return;
      final currentState = state as UserLoaded;

      // Find the user to update
      final userIndex = currentState.allUsers.indexWhere(
        (user) => user.userId == event.userId,
      );

      if (userIndex < 0) return;

      // Get the current user
      final user = currentState.allUsers[userIndex];

      // Enhance with service details using the new repository
      final enhancedUser = await _enrichUserWithServiceDetails(user);

      // Create updated user lists
      final updatedAllUsers = List<AppUser>.from(currentState.allUsers);
      updatedAllUsers[userIndex] = enhancedUser;

      // Update reserved and subscribed user lists
      final updatedReservedUsers =
          updatedAllUsers
              .where(
                (user) =>
                    user.userType == UserType.reserved ||
                    user.userType == UserType.both,
              )
              .toList();

      final updatedSubscribedUsers =
          updatedAllUsers
              .where(
                (user) =>
                    user.userType == UserType.subscribed ||
                    user.userType == UserType.both,
              )
              .toList();

      // Emit updated state
      emit(
        UserLoaded(
          allUsers: updatedAllUsers,
          reservedUsers: updatedReservedUsers,
          subscribedUsers: updatedSubscribedUsers,
          isRefreshing: false,
        ),
      );
    } catch (e) {
      print("UserBloc: Error loading service details: $e");
      // Don't change state on error, just log
    }
  }

  /// Enriches a user with detailed service information for their records
  /// Using the new UserReservationsRepository for consistent data fetching
  Future<AppUser> _enrichUserWithServiceDetails(AppUser user) async {
    try {
      // Get complete user details first
      final userDetails = await _userReservationsRepository
          .getUserCompleteDetails(user.userId);

      // Use our repository to fetch all related records
      final relatedRecords = await _userReservationsRepository
          .getUserRelatedRecords(user.userId);

      // If we found records, update the user type based on what we found
      if (relatedRecords.isNotEmpty) {
        // Determine if user has reservations or subscriptions or both
        final hasReservations = relatedRecords.any(
          (record) => record.type == RecordType.reservation,
        );
        final hasSubscriptions = relatedRecords.any(
          (record) => record.type == RecordType.subscription,
        );

        UserType userType;
        if (hasReservations && hasSubscriptions) {
          userType = UserType.both;
        } else if (hasReservations) {
          userType = UserType.reserved;
        } else if (hasSubscriptions) {
          userType = UserType.subscribed;
        } else {
          userType =
              user.userType ??
              UserType.reserved; // Keep existing type if no related records
        }

        // Merge user details with existing user data and new records
        if (userDetails != null) {
          // Use the details we fetched but keep the records and user type
          return userDetails.copyWith(
            relatedRecords: relatedRecords,
            userType: userType,
            // Keep any non-null fields from existing user if userDetails is missing them
            email: userDetails.email ?? user.email,
            phone: userDetails.phone ?? user.phone,
            profilePicUrl: userDetails.profilePicUrl ?? user.profilePicUrl,
            name:
                (userDetails.name != 'Unknown User' &&
                        userDetails.name.isNotEmpty)
                    ? userDetails.name
                    : user.name,
          );
        } else {
          // If no details found, update existing user with records and type
          return user.copyWith(
            relatedRecords: relatedRecords,
            userType: userType,
          );
        }
      }

      // If no records found but we have user details, use those
      if (userDetails != null) {
        return userDetails.copyWith(
          // Keep the existing user type if it exists
          userType: user.userType,
          // Keep any existing records
          relatedRecords: user.relatedRecords,
        );
      }

      // If neither records nor details found, return user as is
      return user;
    } catch (e) {
      print("UserBloc: Error enriching user with service details: $e");
      return user;
    }
  }

  /// Handle searching users - this is done locally since we already have the data
  void _onSearchUsers(SearchUsers event, Emitter<UserState> emit) {
    // Filtering is done in the UI, no need to modify state
  }

  /// Handle filtering users by status - this is done locally since we already have the data
  void _onFilterUsersByStatus(
    FilterUsersByStatus event,
    Emitter<UserState> emit,
  ) {
    // Filtering is done in the UI, no need to modify state
  }

  /// Handle viewing a user's profile
  void _onViewUserProfile(ViewUserProfile event, Emitter<UserState> emit) {
    // This would be implemented for navigation or dialog showing
    // Here we might need to load detailed user data if needed
  }

  @override
  Future<void> close() {
    // Set the closed flag first
    _isClosed = true;
    _usersSubscription?.cancel();
    return super.close();
  }
}

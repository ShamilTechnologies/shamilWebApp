/// File: lib/features/dashboard/views/pages/user_profile_view.dart
/// A page to view an end user's profile details
library;

import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/services/end_user_service.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/data/end_user_model.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_details_card.dart';

/// A page to search for and view an end user's profile
class UserProfileView extends StatefulWidget {
  /// Optional user ID to load directly
  final String? initialUserId;

  const UserProfileView({Key? key, this.initialUserId}) : super(key: key);

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  final TextEditingController _searchController = TextEditingController();
  final EndUserService _userService = EndUserService();
  bool _isSearching = false;
  String? _selectedUserId;
  List<EndUser> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.initialUserId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Handles user search
  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final results = await _userService.searchEndUsers(query);

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          // Show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error searching users: $e'),
              backgroundColor: Colors.red,
            ),
          );
        });
      }
    }
  }

  // Select a user from search results
  void _selectUser(EndUser user) {
    setState(() {
      _selectedUserId = user.uid;
      _searchController.text = ''; // Clear search
      _searchResults = []; // Clear results
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search User',
                      style: getTitleStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText:
                                  'Search by name, email, username, or ID',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onSubmitted: (_) => _searchUsers(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isSearching ? null : _searchUsers,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          child:
                              _isSearching
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : const Text('Search'),
                        ),
                      ],
                    ),

                    // Search results
                    if (_searchResults.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Search Results',
                              style: getTitleStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final user = _searchResults[index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primaryColor
                                          .withOpacity(0.1),
                                      backgroundImage:
                                          user.profilePicUrl != null
                                              ? NetworkImage(
                                                user.profilePicUrl!,
                                              )
                                              : null,
                                      child:
                                          user.profilePicUrl == null
                                              ? Text(
                                                user.name.isNotEmpty
                                                    ? user.name[0].toUpperCase()
                                                    : '?',
                                                style: getTitleStyle(
                                                  fontSize: 16,
                                                  color: AppColors.primaryColor,
                                                ),
                                              )
                                              : null,
                                    ),
                                    title: Text(user.name),
                                    subtitle: Text(user.email),
                                    trailing: ElevatedButton.icon(
                                      icon: const Icon(Icons.visibility),
                                      label: const Text('View'),
                                      onPressed: () => _selectUser(user),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.secondaryColor,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    onTap: () => _selectUser(user),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // User details card
          if (_selectedUserId != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: UserDetailsCard(
                  userId: _selectedUserId!,
                  onUserLoaded: (user) {
                    // Optional: Handle when user is loaded
                    print('User loaded: ${user.name}');
                  },
                ),
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.person_search,
                      size: 80,
                      color: AppColors.lightGrey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Search for a user to view their profile',
                      style: getTitleStyle(
                        fontSize: 18,
                        color: AppColors.mediumGrey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

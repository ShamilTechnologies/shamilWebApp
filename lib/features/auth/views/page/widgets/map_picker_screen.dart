import 'dart:async';
import 'dart:convert'; // For jsonDecode

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http; // For Nominatim requests
import 'package:latlong2/latlong.dart'; // For LatLng object
import 'package:geolocator/geolocator.dart'; // For current location

// Import your AppColors if needed for styling
import 'package:shamil_web_app/core/utils/colors.dart';
// Import text styles if needed
import 'package:shamil_web_app/core/utils/text_style.dart';

/// A screen that displays a map allowing the user to pick a location.
/// Includes search, my location, zoom controls, and reverse geocoding using Nominatim.
/// Returns the selected LatLng coordinates via Navigator.pop().
class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation; // Optional initial location to center the map

  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // Default center if no initial location is provided (e.g., Cairo)
  static const LatLng _defaultCenter = LatLng(30.0444, 31.2357);
  static const double _defaultZoom = 13.0;

  // Controllers
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // State variables
  LatLng? _selectedLocation;
  String _selectedAddress = "Tap map or search to select location";
  bool _isLoading = false; // For search/reverse geocoding
  bool _myLocationEnabled = false; // Track if location permission is granted

  // Debouncer for search queries to avoid excessive API calls
  Timer? _searchDebounce;

  // Nominatim API details (Free service - RESPECT USAGE POLICY)
  final String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  // *** IMPORTANT: Replace with your actual app name/info for User-Agent ***
  final Map<String, String> _nominatimHeaders = {
    'User-Agent':
        'ShamilWebApp/1.0 (Contact: your.email@example.com)', // Be specific and provide contact
  };

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation ?? _defaultCenter;
    _checkLocationPermission();
    // Get initial address for the starting location
    if (_selectedLocation != null) {
      _getPlacemarkFromCoordinates(_selectedLocation!);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // --- Location Permission Handling ---
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location services are disabled. Please enable them.'),
        ),
      );
      setState(() => _myLocationEnabled = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
        }
        setState(() => _myLocationEnabled = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permissions are permanently denied, we cannot request permissions.',
          ),
        ),
      );
      setState(() => _myLocationEnabled = false);
      return;
    }

    // Permissions are granted
    setState(() => _myLocationEnabled = true);
  }

  // --- Map Interaction ---

  /// Handles tap events on the map to update the selected location marker.
  void _handleTap(TapPosition tapPosition, LatLng latLng) {
    if (_isLoading) return; // Don't allow taps while loading
    setState(() {
      _selectedLocation = latLng;
      print("Map tapped. New selected location: $_selectedLocation");
      _selectedAddress =
          "Loading address..."; // Show loading indicator for address
    });
    // Get address for the newly tapped location
    _getPlacemarkFromCoordinates(latLng);
    // Optionally clear search field
    _searchController.clear();
  }

  /// Animates the map to the user's current location.
  Future<void> _goToMyLocation() async {
    if (!_myLocationEnabled) {
      // Re-check permission if button is tapped but permission wasn't granted initially
      await _checkLocationPermission();
      if (!_myLocationEnabled && mounted) {
        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Location Permission'),
                content: const Text(
                  'Please grant location permission in your device settings to use this feature.',
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
        );
        return;
      }
      // If permission granted now, proceed
      if (!_myLocationEnabled) return;
    }

    setState(() => _isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final myLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = myLatLng;
        _selectedAddress = "Loading address...";
      });
      _mapController.move(myLatLng, 15.0); // Move map and zoom in
      _getPlacemarkFromCoordinates(
        myLatLng,
      ); // Get address for current location
    } catch (e) {
      print("Error getting current location: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get current location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Search and Geocoding (Nominatim) ---

  /// Debounced search function to call Nominatim API.
  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 750), () {
      // Wait 750ms after user stops typing
      if (query.length > 2) {
        // Only search if query is long enough
        _searchLocation(query);
      }
    });
  }

  /// Performs geocoding using Nominatim Search API.
  Future<void> _searchLocation(String query) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    print("Searching Nominatim for: $query");

    final url = Uri.parse(
      '$_nominatimBaseUrl/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&countrycodes=eg',
    ); // Limit to Egypt

    try {
      // Respect Nominatim Usage Policy: Max 1 req/sec
      await Future.delayed(const Duration(milliseconds: 1100)); // Ensure delay
      final response = await http.get(url, headers: _nominatimHeaders);

      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List<dynamic>;
        if (results.isNotEmpty) {
          final firstResult = results[0] as Map<String, dynamic>;
          final lat = double.tryParse(firstResult['lat']?.toString() ?? '');
          final lon = double.tryParse(firstResult['lon']?.toString() ?? '');
          final displayName =
              firstResult['display_name'] as String? ?? 'Unknown Address';

          if (lat != null && lon != null) {
            final foundLatLng = LatLng(lat, lon);
            setState(() {
              _selectedLocation = foundLatLng;
              _selectedAddress =
                  displayName; // Use display name from search result
            });
            _mapController.move(foundLatLng, 15.0); // Move map to result
            print(
              "Search successful. Location: $foundLatLng, Address: $displayName",
            );
          } else {
            throw Exception("Invalid coordinates in Nominatim response.");
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location not found.')),
            );
          }
        }
      } else {
        throw Exception(
          "Nominatim search failed with status: ${response.statusCode}",
        );
      }
    } catch (e) {
      print("Error during Nominatim search: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching location: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Performs reverse geocoding using Nominatim Reverse API.
  Future<void> _getPlacemarkFromCoordinates(LatLng latLng) async {
    if (_isLoading) return; // Avoid concurrent requests
    setState(() => _isLoading = true); // Show loading for reverse geocoding
    print("Reverse geocoding for: $latLng");

    final url = Uri.parse(
      '$_nominatimBaseUrl/reverse?lat=${latLng.latitude}&lon=${latLng.longitude}&format=json&accept-language=en',
    );

    try {
      // Respect Nominatim Usage Policy: Max 1 req/sec
      await Future.delayed(const Duration(milliseconds: 1100)); // Ensure delay
      final response = await http.get(url, headers: _nominatimHeaders);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName =
            result['display_name'] as String? ?? 'Address not found';
        setState(() {
          _selectedAddress = displayName;
        });
        print("Reverse geocoding successful: $displayName");
      } else {
        throw Exception(
          "Nominatim reverse failed with status: ${response.statusCode}",
        );
      }
    } catch (e) {
      print("Error during Nominatim reverse geocoding: $e");
      setState(() {
        _selectedAddress = "Could not load address";
      }); // Update UI on error
      // Optional: Show snackbar error
      // if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error getting address: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Confirmation ---

  /// Confirms the selected location and returns it to the previous screen.
  void _confirmSelection() {
    if (_selectedLocation != null) {
      print("Confirming location: $_selectedLocation");
      Navigator.of(
        context,
      ).pop(_selectedLocation); // Return the selected LatLng
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a location on the map first."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use a less intrusive AppBar or remove if modal presentation is preferred
      appBar: AppBar(
        title: const Text("Select Business Location"),
        backgroundColor:
            Theme.of(context).scaffoldBackgroundColor, // Blend with background
        foregroundColor: AppColors.darkGrey, // Use theme colors
        elevation: 1,
        centerTitle: true,
        actions: [
          // Add a confirmation button to the app bar
          TextButton(
            onPressed: _confirmSelection,
            child: Text(
              "Confirm",
              style: getbodyStyle(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        // Use Stack for layering map and controls
        children: [
          // --- Map ---
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation ?? _defaultCenter,
              initialZoom: _defaultZoom,
              onTap: _handleTap,
              minZoom: 5.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags:
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom, // Standard interactions
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.example.shamil_web_app', // Replace with your app package name
              ),
              // Display marker at the selected location
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 50.0, // Adjust size
                      height: 50.0,
                      point: _selectedLocation!,
                      child: const Icon(
                        Icons.location_on, // Material location icon
                        color:
                            AppColors.redColor, // Use app's error/accent color
                        size: 50.0,
                      ),
                      // Center anchor point
                      alignment:
                          Alignment
                              .topCenter, // Anchor point at the bottom center of the icon
                    ),
                  ],
                ),
            ],
          ),

          // --- Search Bar ---
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              // Wrap in Card for elevation and background
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search address or place...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.mediumGrey,
                    ),
                    suffixIcon:
                        _searchController.text.isNotEmpty
                            ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: AppColors.mediumGrey,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                // Optionally clear search results or reset map view here
                              },
                            )
                            : null,
                    border:
                        InputBorder.none, // Remove TextField border inside Card
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: _onSearchChanged, // Use debounced search
                  onSubmitted: _searchLocation, // Allow direct search on submit
                ),
              ),
            ),
          ),

          // --- Map Controls (Zoom, My Location) ---
          Positioned(
            bottom: 90, // Adjust position above FAB and address display
            right: 15,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in_button', // Unique hero tag
                  tooltip: 'Zoom In',
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryColor,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out_button', // Unique hero tag
                  tooltip: 'Zoom Out',
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryColor,
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 16),
                FloatingActionButton.small(
                  heroTag: 'my_location_button', // Unique hero tag
                  tooltip: 'My Location',
                  onPressed:
                      _myLocationEnabled
                          ? _goToMyLocation
                          : _checkLocationPermission, // Go or request permission
                  backgroundColor: Colors.white,
                  foregroundColor:
                      _myLocationEnabled
                          ? AppColors.primaryColor
                          : AppColors.mediumGrey,
                  child:
                      _isLoading // Show loading indicator if busy getting location
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.my_location),
                ),
              ],
            ),
          ),

          // --- Selected Address Display & Confirm Button ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(
                12.0,
              ).copyWith(bottom: 20), // Add padding for FAB overlap
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Display selected address or loading indicator
                  Row(
                    children: [
                      const Icon(
                        Icons.pin_drop_outlined,
                        color: AppColors.mediumGrey,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isLoading && _selectedAddress == "Loading address..."
                              ? "Loading address..."
                              : _selectedAddress,
                          style: getbodyStyle(color: AppColors.darkGrey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isLoading) // Show loading indicator next to text
                        const SizedBox(width: 8),
                      if (_isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Confirmation Button (Alternative/Redundant to FAB)
                  // ElevatedButton.icon(
                  //   icon: const Icon(Icons.check_circle_outline),
                  //   label: const Text("Confirm This Location"),
                  //   onPressed: _confirmSelection,
                  //   style: ElevatedButton.styleFrom(
                  //      backgroundColor: AppColors.primaryColor,
                  //      foregroundColor: Colors.white,
                  //      padding: const EdgeInsets.symmetric(vertical: 14),
                  //      textStyle: getTitleStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  //      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  //   ),
                  // )
                ],
              ),
            ),
          ),

          // --- Global Loading Indicator (Optional) ---
          // if (_isLoading)
          //   Container(
          //     color: Colors.black.withOpacity(0.1),
          //     child: const Center(child: CircularProgressIndicator()),
          //   ),
        ],
      ),
    );
  }
}

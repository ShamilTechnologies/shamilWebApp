/// File: lib/core/constants/registration_constants.dart
/// --- Constants used during the service provider registration flow ---

import 'package:flutter/material.dart'; // Needed for Widget, InputDecoration typedefs
import 'package:latlong2/latlong.dart'; // For LatLng

// --- Typedefs for Builder Functions ---
// Define function types for builders passed to section widgets for better type safety
typedef SectionHeaderBuilder = Widget Function(String title);
typedef InputDecorationBuilder = InputDecoration Function({required String label, bool enabled, String? hint});
typedef UrlValidator = bool Function(String url);


// --- Business Details Step Constants ---

/// List of Egyptian Governorates for address selection.
const List<String> kGovernorates = [
  'Cairo', 'Giza', 'Alexandria', 'Qalyubia', 'Sharqia', 'Dakahlia', 'Beheira',
  'Kafr El Sheikh', 'Gharbia', 'Monufia', 'Damietta', 'Port Said', 'Ismailia',
  'Suez', 'North Sinai', 'South Sinai', 'Beni Suef', 'Faiyum', 'Minya', 'Asyut',
  'Sohag', 'Qena', 'Luxor', 'Aswan', 'Red Sea', 'New Valley', 'Matrouh',
];

/// List of common business amenities for selection.
const List<String> kAmenities = [
  'WiFi', 'Parking', 'Air Conditioning', 'Waiting Area', 'Restrooms', 'Cafe',
  'Lockers', 'Showers', 'Wheelchair Accessible', 'Prayer Room', 'Music System',
  'TV Screens', 'Water Dispenser', 'Changing Rooms',
];

/// List of main business categories for selection.
/// Consider using the more detailed Category structure from shamil_business_categories if needed.
const List<String> kBusinessCategories = [
  // Using the detailed list might be better here if subcategories aren't handled separately
  'Fitness', 'Sports', 'Entertainment', 'Events', 'Health',
  'Education', 'Beauty', 'Retail', 'Consulting', 'Restaurant', 'Other',
];


// --- Map Picker Constants ---

/// Default map center coordinates (e.g., Cairo). Used if no location is pre-selected.
const LatLng kDefaultMapCenter = LatLng(30.0444, 31.2357);


/// File: lib/core/constants/business_categories.dart
/// Defines the structure and data for business categories and subcategories.
library;

/// Represents a business category with its subcategories.
class Category {
  final String name;
  final List<String> subCategories;
  // To support deeper nesting (sub-subcategories, etc.),
  // you could change subCategories to: final List<Category> subCategories;

  const Category({
    required this.name,
    required this.subCategories,
  });
}

/// List of predefined business categories in the desired order.
/// Each category contains a list of example subcategories.
const List<Category> kBusinessCategories = [
  // 1. Fitness
  Category(
    name: "Fitness",
    subCategories: [
      "Gym",
      "Yoga Studio",
      "Pilates Studio",
      "CrossFit Box",
      "Personal Training",
      "Group Fitness Classes",
      "Bootcamp",
      "Martial Arts (Fitness Focus)",
      "Cycling Studio",
      "Other Fitness", // General fallback
    ],
  ),

  // 2. Sports
  Category(
    name: "Sports",
    subCategories: [
      "Sports Club",
      "Tennis Court",
      "Squash Court",
      "Padel Court",
      "Swimming Pool",
      "Football Pitch",
      "Basketball Court",
      "Volleyball Court",
      "Sports Training Facility",
      "Golf Course / Driving Range",
      "Climbing Wall",
      "Skating Rink",
      "Stadium / Arena", // <-- ADDED
      "Other Sports Facility",
    ],
  ),

  // 3. Entertainment
  Category(
    name: "Entertainment",
    subCategories: [
      "Cinema",
      "Bowling Alley",
      "Arcade / Gaming Center",
      "Billiard Hall",
      "Escape Room",
      "Laser Tag",
      "Mini Golf",
      "Theater / Performing Arts Venue",
      "Music Venue",
      "Comedy Club",
      "VR Experience Center",
      "Other Entertainment Venue",
    ],
  ),

  // 4. Events
  Category(
    name: "Events",
    subCategories: [
      "Event Venue / Hall",
      "Wedding Venue",
      "Conference Center",
      "Exhibition Center",
      "Sporting Event Venue", // <-- ADDED
      "Party Planning Service", // Service, but often tied to venues
      "Catering Service (Event Focus)", // Service
      "Event Equipment Rental", // Service
      "Other Event Space/Service",
    ],
  ),

  // 5. Health
  Category(
    name: "Health",
    subCategories: [
      "Spa",
      "Massage Therapy",
      "Physiotherapy Clinic",
      "Chiropractor",
      "Acupuncture Clinic",
      "Wellness Center",
      "Nutritionist / Dietitian", // Service
      "Mental Health Clinic / Therapy",
      "Alternative Medicine Practitioner",
      "Other Health & Wellness",
    ],
  ),

  // Add more categories as needed following the same structure
  // Example:
  // Category(
  //   name: "Education",
  //   subCategories: [
  //     "Tutoring Center",
  //     "Language School",
  //     "Music School",
  //     "Art Studio (Classes)",
  //     "Cooking Class",
  //     "Workshop Provider",
  //   ],
  // ),
  // Category(
  //   name: "Beauty",
  //   subCategories: [
  //     "Hair Salon",
  //     "Barbershop",
  //     "Nail Salon",
  //     "Beauty Salon",
  //     "Makeup Artist Studio", // Service
  //     "Tattoo & Piercing Studio",
  //   ],
  // ),
];

/// Helper function to get a flat list of all main category names.
List<String> getAllCategoryNames() {
  return kBusinessCategories.map((category) => category.name).toList();
}

/// Helper function to get subcategories for a given main category name.
/// Returns an empty list if the category name is not found.
List<String> getSubcategoriesFor(String categoryName) {
  try {
    // Use case-insensitive comparison for robustness if needed
    // return kBusinessCategories
    //     .firstWhere((category) => category.name.toLowerCase() == categoryName.toLowerCase())
    //     .subCategories;
    return kBusinessCategories
        .firstWhere((category) => category.name == categoryName)
        .subCategories;
  } catch (e) {
    // Handle case where category name doesn't exist
    print("Warning: Category '$categoryName' not found in kBusinessCategories.");
    return []; // Return empty list
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/constants/business_categories.dart';

// Import UI utils & Widgets (adjust paths as needed)
import 'package:shamil_web_app/core/utils/text_field_templates.dart';
// Needed for InputDecoration helper

// Typedef for helper functions passed from parent
typedef InputDecorationBuilder = InputDecoration Function({required String label, bool enabled, String? hint});
typedef SectionHeaderBuilder = Widget Function(String title);
/// Renders the form fields for basic business information.


/// Renders the form fields for basic business information.
class BasicInfoSection extends StatefulWidget { // Changed to StatefulWidget for local state mgmt
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final String? selectedCategory;
  final String? selectedSubCategory; // <-- ADDED
  // final List<String> categories; // No longer needed, use helpers
  final ValueChanged<String?>? onCategoryChanged; // Nullable callback
  final ValueChanged<String?>? onSubCategoryChanged; // <-- ADDED Nullable callback
  final bool enabled;
  // Accept builder functions matching typedefs
  final SectionHeaderBuilder sectionHeaderBuilder;
  final InputDecorationBuilder inputDecorationBuilder;

  const BasicInfoSection({
    super.key,
    required this.nameController,
    required this.descriptionController,
    required this.selectedCategory,
    required this.selectedSubCategory, // <-- ADDED
    // required this.categories, // No longer needed
    this.onCategoryChanged, // Nullable
    this.onSubCategoryChanged, // <-- ADDED Nullable
    required this.enabled,
    required this.sectionHeaderBuilder, // Require builder function
    required this.inputDecorationBuilder, // Require builder function
  });

  @override
  State<BasicInfoSection> createState() => _BasicInfoSectionState();
}

class _BasicInfoSectionState extends State<BasicInfoSection> {
  List<String> _subCategoryOptions = []; // Local state for subcategory dropdown items
  String? _currentSelectedSubCategory; // Local state to manage dropdown value safely

  @override
  void initState() {
    super.initState();
    // Initialize internal subcategory selection based on widget property
    _currentSelectedSubCategory = widget.selectedSubCategory;
    // Initialize subcategory options based on the initial main category
    if (widget.selectedCategory != null) {
      _updateSubCategoryOptions(widget.selectedCategory!);
      // Ensure initial subcategory is valid for the initial category
      _syncSubCategorySelection(runSetState: false); // Sync without calling setState yet
    }
     print("BasicInfoSection initState: Initial Cat='${widget.selectedCategory}', Initial SubCat='${widget.selectedSubCategory}', Internal SubCat='$_currentSelectedSubCategory', Options='$_subCategoryOptions'");
  }

  @override
  void didUpdateWidget(covariant BasicInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool needsSetState = false;

    // If the main category changes externally, update subcategory options
    if (widget.selectedCategory != oldWidget.selectedCategory) {
      print("BasicInfoSection didUpdateWidget: Main category changed from '${oldWidget.selectedCategory}' to '${widget.selectedCategory}'. Updating subcategories.");
      _updateSubCategoryOptions(widget.selectedCategory);
      // Also update the internal subcategory selection if the new main category doesn't contain it
      // or if the main category became null
      if (_syncSubCategorySelection(runSetState: false)) { // Check if sync changed internal state
         needsSetState = true;
      }
    }
     // If the external subcategory selection changes, update internal state
    else if (widget.selectedSubCategory != oldWidget.selectedSubCategory && widget.selectedSubCategory != _currentSelectedSubCategory) {
       print("BasicInfoSection didUpdateWidget: External subcategory changed to ${widget.selectedSubCategory}. Updating internal state.");
       if (_syncSubCategorySelection(runSetState: false)) { // Check if sync changed internal state
          needsSetState = true;
       }
    }

    // Call setState once if needed
    if (needsSetState) {
       print("BasicInfoSection didUpdateWidget: Calling setState.");
       setState(() {});
    }
  }

  /// Updates the list of available subcategories based on the main category.
  void _updateSubCategoryOptions(String? mainCategoryName) {
    List<String> newOptions;
    if (mainCategoryName == null || mainCategoryName.isEmpty) {
      newOptions = []; // Clear options if no main category
    } else {
      // Use the helper function from business_categories.dart
      newOptions = getSubcategoriesFor(mainCategoryName);
    }
    // Update state only if options actually changed
    if (!const ListEquality().equals(_subCategoryOptions, newOptions)) {
       setState(() {
          _subCategoryOptions = newOptions;
       });
        print("BasicInfoSection: Subcategory options updated: $_subCategoryOptions");
    } else {
       print("BasicInfoSection: Subcategory options unchanged.");
    }
  }

   /// Syncs the internal subcategory selection with the widget's property,
   /// ensuring it's a valid option within the current subcategory list.
   /// Returns true if the internal state was changed, false otherwise.
  bool _syncSubCategorySelection({bool runSetState = true}) {
     String? validSubCategory;
     // Determine the valid subcategory based on widget prop and current options
     if (widget.selectedSubCategory != null && _subCategoryOptions.contains(widget.selectedSubCategory)) {
        validSubCategory = widget.selectedSubCategory;
     }
     // Update internal state only if it differs
     if (_currentSelectedSubCategory != validSubCategory) {
        print("BasicInfoSection _syncSubCategorySelection: Internal subcategory changing from '$_currentSelectedSubCategory' to '$validSubCategory'");
        if (runSetState) {
           setState(() {
              _currentSelectedSubCategory = validSubCategory;
           });
        } else {
           _currentSelectedSubCategory = validSubCategory;
        }
        return true; // State changed
     }
     return false; // State did not change
  }


  @override
  Widget build(BuildContext context) {
    // Get main category names from the helper function in business_categories.dart
    final List<String> mainCategoryNames = getAllCategoryNames();
    print("BasicInfoSection build: SelectedCat='${widget.selectedCategory}', CurrentInternalSubCat='$_currentSelectedSubCategory', Options='$_subCategoryOptions'");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Use the passed builder function to create the header
        widget.sectionHeaderBuilder("Basic Information"),

        // Business Name
        RequiredTextFormField(
          labelText: "Business Name*",
          hintText: "Enter the official name of your business",
          controller: widget.nameController,
          enabled: widget.enabled,
          prefixIconData: Icons.business_center_outlined,
        ),
        const SizedBox(height: 20),

        // Business Description
        TextAreaFormField(
          labelText: "Business Description*",
          hintText: "Describe your business, services, and what makes it unique.",
          controller: widget.descriptionController,
          enabled: widget.enabled,
          minLines: 3,
          maxLines: 5,
        ),
        const SizedBox(height: 20),

        // Business Category Dropdown
        GlobalDropdownFormField<String>(
          labelText: "Business Category*",
          hintText: "Select the main category",
          value: widget.selectedCategory, // Use value from parent state
          items: mainCategoryNames.map((String category) =>
              DropdownMenuItem<String>(value: category, child: Text(category))).toList(),
          onChanged: widget.enabled ? (value) {
             // Update subcategories when main category changes
             print("BasicInfoSection: Main category changed TO '$value'");
             if (value != widget.selectedCategory) {
                setState(() {
                   // Update options FIRST
                   _updateSubCategoryOptions(value);
                   // Reset internal subcategory selection immediately
                   _currentSelectedSubCategory = null;
                });
                // Call parent callback for main category change.
                // Parent's setState will eventually call didUpdateWidget here,
                // which will call _syncSubCategorySelection to ensure consistency.
                widget.onCategoryChanged?.call(value);
             }
          } : null,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please select a business category';
            return null;
          },
          enabled: widget.enabled,
          prefixIcon: const Icon(Icons.category_outlined),
        ),
        const SizedBox(height: 20),

        // --- SubCategory Dropdown (Conditionally Visible) ---
        Visibility(
           // Show only if a main category is selected AND it has subcategories
           visible: widget.selectedCategory != null && _subCategoryOptions.isNotEmpty,
           child: GlobalDropdownFormField<String>(
             key: ValueKey(widget.selectedCategory), // Add key to force rebuild when category changes
             labelText: "Subcategory*", // Mark as required if needed
             hintText: "Select a subcategory",
             value: _currentSelectedSubCategory, // Use internal state for dropdown value
             items: _subCategoryOptions.map((String subCategory) =>
                 DropdownMenuItem<String>(value: subCategory, child: Text(subCategory))).toList(),
             onChanged: widget.enabled ? (value) {
                // Update internal state and call parent callback
                print("BasicInfoSection: Subcategory changed TO '$value'");
                setState(() => _currentSelectedSubCategory = value);
                widget.onSubCategoryChanged?.call(value);
             } : null,
             validator: (value) {
                // Make subcategory required only if options are available
                if (_subCategoryOptions.isNotEmpty && (value == null || value.isEmpty)) {
                   return 'Please select a subcategory';
                }
                return null;
             },
             enabled: widget.enabled,
             prefixIcon: const Icon(Icons.subdirectory_arrow_right_outlined),
           ),
        ),
        // Add spacing even if subcategory dropdown is hidden to maintain layout
        // Use SizedBox based on visibility condition for consistent layout spacing
        SizedBox(height: (widget.selectedCategory != null && _subCategoryOptions.isNotEmpty) ? 20 : 0),

      ],
    );
  }
}


/// File: lib/features/dashboard/widgets/animated_loading_screen.dart
/// --- An animated loading screen (V14 - Pulse Icon, Reveal Text, Simple BG) ---
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path if needed
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path if needed
// Removed TypingText import

class AnimatedDashboardLoadingScreen extends StatefulWidget {
  // Added const constructor
  const AnimatedDashboardLoadingScreen({super.key});

  @override
  State<AnimatedDashboardLoadingScreen> createState() =>
      _AnimatedDashboardLoadingScreenState();
}

class _AnimatedDashboardLoadingScreenState
    extends State<AnimatedDashboardLoadingScreen> {
  // Log steps data
  final List<Map<String, dynamic>> _logSteps = [
    {
      "text": "Initializing system...",
      "icon": Icons.settings_input_component_outlined,
    },
    {"text": "Establishing connections...", "icon": Icons.cloud_sync_outlined},
    {
      "text": "Authenticating provider...",
      "icon": Icons.verified_user_outlined,
    },
    {"text": "Compiling statistics...", "icon": Icons.query_stats_rounded},
    {"text": "Loading member data...", "icon": Icons.groups_2_outlined},
    {"text": "Syncing schedules...", "icon": Icons.event_repeat_outlined},
    {"text": "Fetching activity feed...", "icon": Icons.history_edu_outlined},
    {"text": "Launching dashboard...", "icon": Icons.rocket_launch_outlined},
    {
      "text": "Welcome!",
      "icon": Icons.check_circle_outline_rounded,
    }, // Final state
  ];

  // State variables
  final List<Map<String, dynamic>> _displayedLogsData =
      []; // Store actual data map for logs
  int _currentStepIndex =
      0; // Controls the CURRENTLY VISIBLE icon and title text
  Timer? _stepTimer;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    print("initState: AnimatedDashboardLoadingScreen V14");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startLogAnimation();
    });
  }

  void _startLogAnimation() {
    if (!mounted || _isDisposed) return;

    _stepTimer?.cancel();
    _currentStepIndex = 0;

    // Clear previous logs safely
    _clearAnimatedList();

    // Set initial state (first icon/text)
    setState(() {});
    _scheduleNextStep();
  }

  // Helper to safely clear animated list
  void _clearAnimatedList() {
    if (!mounted || _isDisposed) return;
    final listState = _listKey.currentState;
    if (listState != null) {
      for (var i = _displayedLogsData.length - 1; i >= 0; i--) {
        try {
          if (!mounted || _isDisposed) break;
          // Provide a placeholder widget builder for removal animation
          listState.removeItem(
            i,
            (context, animation) => SizeTransition(
              sizeFactor: animation,
              child: const SizedBox(height: 20),
            ), // Example removal animation
            duration: const Duration(milliseconds: 150),
          ); // Short duration for removal
        } catch (e) {
          print("Error removing item during clear: $e");
          break;
        }
      }
    }
    // Clear backing list after initiating removal animations
    if (_displayedLogsData.isNotEmpty) {
      _displayedLogsData.clear();
      // Force rebuild if state was null or needs update after clear
      if (mounted && !_isDisposed) {
        setState(() {});
      }
    }
  }

  void _scheduleNextStep() {
    if (!mounted || _isDisposed) return;

    // Stop condition: Index has reached the final "Welcome!" state
    if (_currentStepIndex >= _logSteps.length - 1) {
      _stepTimer?.cancel();
      print("Log animation sequence finished (V14).");
      return;
    }

    // --- Schedule the NEXT text log and icon update ---
    final delay = Duration(
      milliseconds: _currentStepIndex == 0 ? 700 : 1300,
    ); // Slightly adjusted pace

    _stepTimer = Timer(delay, () {
      if (!mounted || _isDisposed) {
        _stepTimer?.cancel();
        return;
      }

      // 1. Add the *data* for the text log we are about to display
      final logToAdd = _logSteps[_currentStepIndex];
      _displayedLogsData.add(logToAdd);

      // 2. Insert item into AnimatedList (using length BEFORE incrementing index)
      _listKey.currentState?.insertItem(
        _displayedLogsData.length - 1,
        duration: const Duration(
          milliseconds: 650,
        ), // Duration for text reveal animation
      );

      // 3. Increment index to prepare for the *next* icon/title state
      _currentStepIndex++;

      // 4. Trigger setState to update the icon and title text via AnimatedSwitcher
      setState(() {});

      // 5. Schedule the subsequent step's execution
      _scheduleNextStep();
    });
  }

  @override
  void dispose() {
    print("Disposing AnimatedDashboardLoadingScreen V14 - Cancelling Timer");
    _isDisposed = true;
    _stepTimer?.cancel();
    _stepTimer = null;
    super.dispose();
  }

  // --- Custom Icon Transition Builder (Pulse: Fade + Scale) ---
  Widget _iconTransitionBuilder(Widget child, Animation<double> animation) {
    // Pulse effect: Scale up slightly then back down during fade
    final scaleCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack, // Curve with overshoot
    );
    // Adjust scale values for a subtle pulse
    final scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(scaleCurve);

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      ), // Smooth fade
      child: ScaleTransition(scale: scaleAnim, child: child),
    );
  }

  // --- Custom Log Text Item Builder (Reveal Animation) ---
  Widget _buildLogItem(
    BuildContext context,
    int index,
    Animation<double> animation,
  ) {
    // Defensive bounds check using the list length
    if (index >= _displayedLogsData.length || index < 0) {
      return const SizedBox.shrink();
    }

    final logData = _displayedLogsData[index];
    final fullText = logData['text'] as String? ?? '...';

    // Use the animation provided by AnimatedList to drive the reveal
    final revealAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    );

    return FadeTransition(
      // 1. Fade in the item
      opacity: revealAnimation,
      child: SlideTransition(
        // 2. Slide it up slightly
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.3),
          end: Offset.zero,
        ).animate(revealAnimation),
        child: ClipRect(
          // 3. Clip the text vertically
          child: Align(
            alignment: Alignment.center, // Center text vertically during reveal
            heightFactor:
                revealAnimation.value, // Animate heightFactor from 0.0 to 1.0
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 4.0,
              ), // Consistent padding
              child: Text(
                fullText,
                style: getbodyStyle(
                  color: AppColors.secondaryColor.withOpacity(0.85),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Defensive Index Clamping
    final safeIndex = _currentStepIndex.clamp(0, _logSteps.length - 1);
    final currentStepData = _logSteps[safeIndex];
    final IconData currentIconData =
        currentStepData['icon'] as IconData? ?? Icons.hourglass_empty_rounded;
    final String currentIconText =
        currentStepData['text'] as String? ?? "Loading...";

    return Scaffold(
      backgroundColor: AppColors.lightGrey.withBlue(248), // Simple background
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 3), // Pushes content down slightly
              // --- Animated Icon Section (Pulse Transition) ---
              AnimatedSwitcher(
                duration: const Duration(
                  milliseconds: 650,
                ), // Duration for pulse
                transitionBuilder: _iconTransitionBuilder, // Use pulse builder
                child: Icon(
                  currentIconData,
                  key: ValueKey<IconData>(
                    currentIconData,
                  ), // Key triggers animation
                  size: 70, // Slightly smaller icon
                  color: AppColors.primaryColor,
                  semanticLabel: "Loading status icon",
                ),
              ),
              const SizedBox(height: 25),

              // --- Status Text ---
              AnimatedSwitcher(
                duration: const Duration(
                  milliseconds: 650,
                ), // Match icon duration
                transitionBuilder: (Widget child, Animation<double> animation) {
                  // Simple fade for text works well here
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Text(
                  currentIconText,
                  key: ValueKey<String>(currentIconText),
                  style: getTitleStyle(
                    color:
                        AppColors.darkGrey, // Darker text for better contrast
                    fontSize: 18,
                    fontWeight: FontWeight.w400, // Regular weight
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 35),

              // --- Animated Log Text History (Revealing Effect) ---
              SizedBox(
                height: 160,
                width: 500,
                child: AnimatedList(
                  key: _listKey,
                  initialItemCount:
                      _displayedLogsData.length, // Use data list length
                  itemBuilder: _buildLogItem, // Use the reveal builder
                ),
              ),
              const Spacer(flex: 3), // Balance spacing
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamil_web_app/core/functions/navigation.dart';
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/widgets/custom_button.dart';
import 'package:shamil_web_app/feature/auth/views/page/steps/assets_upload_step.dart';
import 'package:shamil_web_app/feature/auth/views/page/steps/business_data_step.dart';
import 'package:shamil_web_app/feature/auth/views/page/steps/personal_data_step.dart';

/// SmoothTypingText widget animates the provided text by typing one letter at a time.
class SmoothTypingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration letterDelay;

  const SmoothTypingText({
    super.key,
    required this.text,
    required this.style,
    this.letterDelay = const Duration(milliseconds: 100),
  });

  @override
  _SmoothTypingTextState createState() => _SmoothTypingTextState();
}

class _SmoothTypingTextState extends State<SmoothTypingText> {
  String _displayedText = "";
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void didUpdateWidget(covariant SmoothTypingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _resetTyping();
      _startTyping();
    }
  }

  void _resetTyping() {
    _timer?.cancel();
    _currentIndex = 0;
    _displayedText = "";
  }

  void _startTyping() {
    _timer = Timer.periodic(widget.letterDelay, (timer) {
      if (_currentIndex < widget.text.length) {
        setState(() {
          _displayedText = widget.text.substring(0, _currentIndex + 1);
        });
        _currentIndex++;
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayedText, style: widget.style);
  }
}

class RegistrationStoryFlow extends StatefulWidget {
  const RegistrationStoryFlow({super.key});

  @override
  State<RegistrationStoryFlow> createState() => _RegistrationStoryFlowState();
}

class _RegistrationStoryFlowState extends State<RegistrationStoryFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Data holders to send to your backend.
  String name = '';
  String email = '';
  String password = '';
  String businessName = '';
  String businessDescription = '';
  String phone = '';
  File? logo;
  File? placePic;
  List<File> facilitiesPics = [];

  // Narrative text for each chapter/step.
  final List<String> _storyNarrative = [
    "Chapter 1: Begin your journey by entering your personal details.",
    "Chapter 2: Tell us the story of your business.",
    "Chapter 3: Bring your vision to life by uploading your assets."
  ];

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> _cacheData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('regName', name);
    await prefs.setString('regEmail', email);
    await prefs.setString('regPassword', password);
    await prefs.setString('regBusinessName', businessName);
    await prefs.setString('regBusinessDescription', businessDescription);
    await prefs.setString('regPhone', phone);
    // File data is kept only in memory.
  }

  Future<void> _loadCachedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      name = prefs.getString('regName') ?? '';
      email = prefs.getString('regEmail') ?? '';
      password = prefs.getString('regPassword') ?? '';
      businessName = prefs.getString('regBusinessName') ?? '';
      businessDescription = prefs.getString('regBusinessDescription') ?? '';
      phone = prefs.getString('regPhone') ?? '';
    });
  }

  Future<void> _clearCachedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('regName');
    await prefs.remove('regEmail');
    await prefs.remove('regPassword');
    await prefs.remove('regBusinessName');
    await prefs.remove('regBusinessDescription');
    await prefs.remove('regPhone');
  }

  void _nextPage() {
    if (_currentPage == 0) {
      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        showGlobalSnackBar(context, "Please fill in all personal data fields.", isError: true);
        return;
      }
    } else if (_currentPage == 1) {
      if (businessName.isEmpty || businessDescription.isEmpty || phone.isEmpty) {
        showGlobalSnackBar(context, "Please fill in all business data fields.", isError: true);
        return;
      }
    } else if (_currentPage == 2) {
      if (logo == null || placePic == null || facilitiesPics.isEmpty) {
        showGlobalSnackBar(context, "Please upload all required assets.", isError: true);
        return;
      }
      // On submission, clear cached data.
      _clearCachedData();
      // Proceed with registration submission logic here.
      return;
    }
    setState(() {
      _currentPage++;
    });
    _cacheData();
    _pageController.animateToPage(
      _currentPage,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _cacheData();
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  // Desktop layout.
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryColor.withOpacity(0.8),
                  AppColors.primaryColor.withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: SmoothTypingText(
                  text: _storyNarrative[_currentPage],
                  style: getbodyStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          PersonalDataStep(
                            initialName: name,
                            initialEmail: email,
                            initialPassword: password,
                            onDataChanged: (data) {
                              setState(() {
                                name = data['name'] ?? '';
                                email = data['email'] ?? '';
                                password = data['password'] ?? '';
                              });
                              _cacheData();
                            },
                          ),
                          BusinessDataStep(
                            initialBusinessName: businessName,
                            initialBusinessDescription: businessDescription,
                            initialPhone: phone,
                            onDataChanged: (data) {
                              setState(() {
                                businessName = data['businessName'] ?? '';
                                businessDescription = data['businessDescription'] ?? '';
                                phone = data['phone'] ?? '';
                              });
                              _cacheData();
                            },
                          ),
                          AssetsUploadStep(
                            onAssetsChanged: (data) {
                              setState(() {
                                logo = data['logo'] as File?;
                                placePic = data['placePic'] as File?;
                                facilitiesPics = data['facilitiesPics'] as List<File>;
                              });
                              // File data is held only in memory.
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentPage > 0)
                          TextButton(
                            onPressed: _previousPage,
                            child: Text("Back", style: getbodyStyle(color: AppColors.primaryColor)),
                          ),
                        CustomButton(
                          width: MediaQuery.of(context).size.width * 0.25,
                          onPressed: _nextPage,
                          text: _currentPage == 2 ? "Finish" : "Continue",
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        // Optionally, handle skip action.
                      },
                      child: Text(
                        "Skip for now",
                        style: getbodyStyle(color: AppColors.secondaryColor, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Mobile layout.
  Widget _buildMobileLayout() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              _storyNarrative[_currentPage],
              textAlign: TextAlign.center,
              style: getbodyStyle(color: AppColors.primaryColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                PersonalDataStep(
                  initialName: name,
                  initialEmail: email,
                  initialPassword: password,
                  onDataChanged: (data) {
                    setState(() {
                      name = data['name'] ?? '';
                      email = data['email'] ?? '';
                      password = data['password'] ?? '';
                    });
                    _cacheData();
                  },
                ),
                BusinessDataStep(
                  initialBusinessName: businessName,
                  initialBusinessDescription: businessDescription,
                  initialPhone: phone,
                  onDataChanged: (data) {
                    setState(() {
                      businessName = data['businessName'] ?? '';
                      businessDescription = data['businessDescription'] ?? '';
                      phone = data['phone'] ?? '';
                    });
                    _cacheData();
                  },
                ),
                AssetsUploadStep(
                  onAssetsChanged: (data) {
                    setState(() {
                      logo = data['logo'] as File?;
                      placePic = data['placePic'] as File?;
                      facilitiesPics = data['facilitiesPics'] as List<File>;
                    });
                    // File data is held only in memory.
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentPage > 0)
                TextButton(
                  onPressed: _previousPage,
                  child: Text("Back", style: getbodyStyle(color: AppColors.primaryColor)),
                ),
              CustomButton(
                width: MediaQuery.of(context).size.width * 0.6,
                onPressed: _nextPage,
                text: _currentPage == 2 ? "Finish" : "Continue",
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              // Optionally, handle skip action.
            },
            child: Text(
              "Skip for now",
              style: getbodyStyle(color: AppColors.secondaryColor, fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

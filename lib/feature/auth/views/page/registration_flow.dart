import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/StepIndicator.dart';
import 'package:shamil_web_app/feature/auth/views/page/steps/business_data_step.dart';
import 'package:shamil_web_app/feature/auth/views/page/steps/personal_id_step.dart';
import 'package:shamil_web_app/feature/auth/views/page/steps/pricing_step.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/widgets/custom_button.dart';
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart' as ServiceProviderModel;
import 'package:shamil_web_app/feature/auth/views/page/steps/assets_upload_step.dart';
import 'package:shamil_web_app/feature/auth/views/page/steps/personal_data_step.dart';

class FadingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration duration;
  final Curve curve;
  final TextAlign textAlign;
  final TextOverflow overflow;

  const FadingText({
    super.key,
    required this.text,
    required this.style,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeIn,
    this.textAlign = TextAlign.start,
    this.overflow = TextOverflow.fade, // Added overflow handling [[3]]
  });

  @override
  _FadingTextState createState() => _FadingTextState();
}

class _FadingTextState extends State<FadingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  String _currentText = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _currentText = widget.text;
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant FadingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.reset();
      setState(() => _currentText = widget.text);
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Text(
        _currentText,
        style: widget.style,
        textAlign: widget.textAlign,
        overflow: widget.overflow, // Apply overflow handling [[3]]
      ),
    );
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
  final int _totalPages = 5;
  // Data holders with platform-aware types
  String name = '';
  String email = '';
  String password = '';
  String idNumber = '';
  dynamic idFrontImage; // Handles File (mobile) and Uint8List (web)
  dynamic idBackImage;
  String businessName = '';
  String businessDescription = '';
  String phone = '';
  String businessCategory = '';
  String businessAddress = '';
  OpeningHours? openingHours;
  ServiceProviderModel.PricingModel pricingModel = ServiceProviderModel.PricingModel.other;
  List<ServiceProviderModel.SubscriptionPlan>? subscriptionPlans;
  double? reservationPrice;
  File? logo;
  File? placePic;
  List<File> facilitiesPics = [];

  final List<String> _storyNarrative = [
    "Let's start your story.\nTell us a bit about yourself.",
    "Provide your personal identification details.",
    "Every great service has a beginning.\nWhat's your business story?",
    "Define your pricing model and details.",
    "Showcase your space.\nUpload images to bring your business to life."
  ];

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> _cacheData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('regName', name);
    await prefs.setString('regEmail', email);
    await prefs.setString('regPassword', password);
    await prefs.setString('regIdNumber', idNumber);
    await prefs.setString('regBusinessName', businessName);
    await prefs.setString('regBusinessDescription', businessDescription);
    await prefs.setString('regPhone', phone);
    await prefs.setString('regBusinessCategory', businessCategory);
    await prefs.setString('regBusinessAddress', businessAddress);
    await prefs.setString('regPricingModel', pricingModel.name);
    await prefs.setStringList('regFacilitiesPics', facilitiesPics.map((f) => f.path).toList());

    // Platform-specific image caching [[5]][[6]]
    if (kIsWeb) {
      await prefs.setString('idFrontImage', idFrontImage != null ? base64Encode(idFrontImage) : '');
      await prefs.setString('idBackImage', idBackImage != null ? base64Encode(idBackImage) : '');
    } else {
      await prefs.setString('idFrontImagePath', idFrontImage?.path ?? '');
      await prefs.setString('idBackImagePath', idBackImage?.path ?? '');
    }
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      name = prefs.getString('regName') ?? '';
      email = prefs.getString('regEmail') ?? '';
      password = prefs.getString('regPassword') ?? '';
      idNumber = prefs.getString('regIdNumber') ?? '';
      businessName = prefs.getString('regBusinessName') ?? '';
      businessDescription = prefs.getString('regBusinessDescription') ?? '';
      phone = prefs.getString('regPhone') ?? '';
      businessCategory = prefs.getString('regBusinessCategory') ?? '';
      businessAddress = prefs.getString('regBusinessAddress') ?? '';
      pricingModel = ServiceProviderModel.PricingModel.values.firstWhere(
        (m) => m.name == prefs.getString('regPricingModel'),
        orElse: () => ServiceProviderModel.PricingModel.other,
      );
      facilitiesPics = (prefs.getStringList('regFacilitiesPics') ?? [])
          .map((p) => File(p))
          .whereType<File>()
          .toList();

      // Restore images with validation [[8]][[9]]
      if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final frontBytes = prefs.getString('idFrontImage');
      idFrontImage = frontBytes?.isNotEmpty == true 
          ? base64Decode(frontBytes!) 
          : null;
      final backBytes = prefs.getString('idBackImage');
      idBackImage = backBytes?.isNotEmpty == true 
          ? base64Decode(backBytes!) 
          : null;
    } else {
      final frontPath = prefs.getString('idFrontImagePath');
      idFrontImage = frontPath != null && File(frontPath).existsSync()
          ? File(frontPath)
          : null;
      final backPath = prefs.getString('idBackImagePath');
      idBackImage = backPath != null && File(backPath).existsSync()
          ? File(backPath)
          : null;
    }
    });
  }

  bool _validateCurrentStep() {
    if (_currentPage == 0) {
      return name.isNotEmpty && email.isNotEmpty && password.isNotEmpty;
    } else if (_currentPage == 1) {
      final hasFrontImage = kIsWeb 
          ? (idFrontImage is Uint8List && (idFrontImage as Uint8List).isNotEmpty)
          : (idFrontImage is File && (idFrontImage as File).existsSync());
      final hasBackImage = kIsWeb 
          ? (idBackImage is Uint8List && (idBackImage as Uint8List).isNotEmpty)
          : (idBackImage is File && (idBackImage as File).existsSync());
      return idNumber.isNotEmpty && hasFrontImage && hasBackImage;
    } else if (_currentPage == 2) {
      return businessName.isNotEmpty &&
          businessDescription.isNotEmpty &&
          phone.isNotEmpty;
    } else if (_currentPage == 3) {
      if (pricingModel == ServiceProviderModel.PricingModel.subscription) {
        return subscriptionPlans != null && subscriptionPlans!.isNotEmpty;
      }
      if (pricingModel == ServiceProviderModel.PricingModel.reservation) {
        return reservationPrice != null;
      }
      return true;
    } else if (_currentPage == 4) {
      return logo != null && placePic != null && facilitiesPics.isNotEmpty;
    }
    return false;
  }

  void _nextPage() async {
    if (!_validateCurrentStep()) return;
    if (_currentPage < _totalPages - 1) {
      await _cacheData();
      setState(() => _currentPage++);
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _submitRegistration();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _submitRegistration() {
    print("Submitting Registration:");
    print("Name: $name, Email: $email");
    print("Business: $businessName, Desc: $businessDescription, Phone: $phone");
    print("Logo: ${logo?.path}, Place Pic: ${placePic?.path}, Facilities: ${facilitiesPics.length}");
    _clearCachedData();
    showGlobalSnackBar(context, "Registration Submitted Successfully!", isError: false);
  }

  Future<void> _clearCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return constraints.maxWidth > 900
              ? _buildDesktopLayout(context)
              : _buildMobileLayout(context);
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 80),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryColor.withOpacity(0.9),
                  AppColors.primaryColor.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                FadingText(
                  key: ValueKey(_currentPage),
                  text: _storyNarrative[_currentPage],
                  overflow: TextOverflow.fade, // Explicit overflow handling [[3]]
                  style: getTitleStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                StepIndicator(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white.withOpacity(0.4),
                  dotSize: 10,
                  spacing: 12,
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: _buildPageViews(),
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildNavigationButtons(context, isDesktop: true),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
              child: Column(
                children: [
                  FadingText(
                    key: ValueKey(_currentPage),
                    text: _storyNarrative[_currentPage],
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.fade, // Explicit overflow handling [[3]]
                    style: getTitleStyle(
                      color: AppColors.primaryColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  StepIndicator(
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                    activeColor: AppColors.primaryColor,
                    inactiveColor: AppColors.primaryColor.withOpacity(0.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: Card(
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _buildPageViews(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),
            _buildNavigationButtons(context, isDesktop: false),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPageViews() {
    return [
      _buildStep(
        PersonalDataStep(
          initialName: name,
          initialEmail: email,
          initialPassword: password,
          onDataChanged: (data) => setState(() {
            name = data['name'] ?? '';
            email = data['email'] ?? '';
            password = data['password'] ?? '';
          }),
        ),
      ),
       _buildStep(
        PersonalIdStep(
          initialIdNumber: idNumber,
          initialIdFrontImage: idFrontImage,
          initialIdBackImage: idBackImage,
          onDataChanged: (data) {
            setState(() {
              idNumber = data['idNumber'] ?? '';
              if (kIsWeb) {
                idFrontImage = data['idFrontImageBytes'] ?? idFrontImage;
                idBackImage = data['idBackImageBytes'] ?? idBackImage;
              } else {
                final frontPath = data['idFrontImageUrl'];
                idFrontImage = (frontPath != null && frontPath.trim().isNotEmpty)
                    ? File(frontPath)
                    : idFrontImage;
                final backPath = data['idBackImageUrl'];
                idBackImage = (backPath != null && backPath.trim().isNotEmpty)
                    ? File(backPath)
                    : idBackImage;
              }
            });
          },
        ),
      ),
      _buildStep(
        BusinessDetailsStep(
          initialBusinessName: businessName,
          initialBusinessDescription: businessDescription,
          initialPhone: phone,
          initialBusinessCategory: businessCategory,
          initialBusinessAddress: businessAddress,
          initialOpeningHours: openingHours ?? OpeningHours(hours: {}),
          onDataChanged: (data) => setState(() {
            businessName = data['businessName'] ?? '';
            businessDescription = data['businessDescription'] ?? '';
            phone = data['phone'] ?? '';
            businessCategory = data['businessCategory'] ?? '';
            businessAddress = data['businessAddress'] ?? '';
            openingHours = data['openingHours'];
          }),
        ),
      ),
      _buildStep(
        PricingStep(
          initialPricingModel: pricingModel,
          initialSubscriptionPlans: subscriptionPlans,
          initialReservationPrice: reservationPrice,
          onDataChanged: (data) => setState(() {
            pricingModel = data['pricingModel'];
            subscriptionPlans = data['subscriptionPlans'];
            reservationPrice = data['reservationPrice'];
          }),
        ),
      ),
      _buildStep(
        AssetsUploadStep(
          onAssetsChanged: (data) => setState(() {
            logo = data['logo'] as File?;
            placePic = data['placePic'] as File?;
            facilitiesPics = data['facilitiesPics'] as List<File>? ?? [];
          }),
        ),
      ),
    ];
  }

  Widget _buildStep(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              maxHeight: MediaQuery.of(context).size.height * 0.8, // Prevent overflow [[4]]
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildNavigationButtons(BuildContext context, {required bool isDesktop}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AnimatedOpacity(
          opacity: _currentPage > 0 ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: TextButton.icon(
            icon: const Icon(Icons.arrow_back_ios, size: 16),
            label: Text("Back", style: getbodyStyle(color: AppColors.secondaryColor)),
            onPressed: _currentPage > 0 ? _previousPage : null,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        CustomButton(
          width: isDesktop ? 180 : MediaQuery.of(context).size.width * 0.45,
          height: 52,
          onPressed: _nextPage,
          text: _currentPage == _totalPages - 1 ? "Finish Setup" : "Continue",
          icon: _currentPage < _totalPages - 1 ? Icons.arrow_forward_ios : null,
          iconSize: 16,
          borderRadius: 10,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/utils/StepIndicator.dart';
import 'package:shamil_web_app/feature/auth/views/page/widgets/fading_text.dart';

class MobileLayout extends StatelessWidget {
  final PageController pageController;
  final int currentPage;
  final int totalPages;
  final List<String> narrative;
  final List<Widget> steps;
  final Widget? navigationButtons;

  const MobileLayout({
    super.key,
    required this.pageController,
    required this.currentPage,
    required this.totalPages,
    required this.narrative,
    required this.steps,
     this.navigationButtons,
  });

  @override
  Widget build(BuildContext context) {
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
                    key: ValueKey(currentPage),
                    text: narrative[currentPage],
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.fade,
                    style: getTitleStyle(
                      color: AppColors.primaryColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  StepIndicator(
                    currentPage: currentPage,
                    totalPages: totalPages,
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
                    controller: pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: steps,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),
            navigationButtons ?? SizedBox.shrink(),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}

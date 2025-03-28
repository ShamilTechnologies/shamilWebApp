import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shamil_web_app/core/constants/assets_icons.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LottieBuilder.asset(
        AssetsIcons.loadingAnimation,
        width: MediaQuery.of(context).size.height / 3,
        height: MediaQuery.of(context).size.height / 2,
        fit: BoxFit.fitWidth,
      ),
    );
  }
}

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use post-frame callback to show the snackbar after the build is complete.

    return Center(
      child: LottieBuilder.asset(
        AssetsIcons.successAnimation,
        width: MediaQuery.of(context).size.height / 3,
        height: MediaQuery.of(context).size.height / 2,
        fit: BoxFit.fitWidth,
      ),
    );
  }
}

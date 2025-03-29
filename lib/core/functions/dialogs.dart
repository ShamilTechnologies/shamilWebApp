import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shamil_web_app/core/constants/assets_icons.dart';
import 'package:shamil_web_app/core/utils/colors.dart';

showErrorDialog(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    backgroundColor: AppColors.redColor,
    content: Text(text),
  ));
}

showSuccessDialog(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    backgroundColor: AppColors.accentColor,
    content: Text(text),
  ));
}

showLoadingDialog(BuildContext context) {
  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              AssetsIcons.loadingAnimation,
              width: 250,
            ),
          ],
        );
      });
}

showsuccessDialog(BuildContext context) {
  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              AssetsIcons.successAnimation,
              width: 250,
            ),
          ],
        );
      });
}

import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';

TextStyle getHeadlineTextStyle(
    {double fontSize = 24, fontWeight = FontWeight.bold, Color? color}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.primaryColor,
  );
}

// title

TextStyle getTitleStyle(
    {double fontSize = 18, fontWeight = FontWeight.bold, Color? color}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.primaryColor,
  );
}

TextStyle getbodyStyle(
    {double fontSize = 18,
    fontWeight = FontWeight.normal,
    Color? color,
    double? height}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.primaryColor,
    height: height,
  );
}
// small

TextStyle getSmallStyle(
    {double fontSize = 14, fontWeight = FontWeight.normal, Color? color}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.secondaryColor,
  );
}


TextStyle getHomeHeadingStyle(
    {double fontSize = 18,
    fontWeight = FontWeight.normal,
    Color? color,
    FontStyle? fontFamily,
    double? height}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.primaryColor,
    fontFamily: "Montserrat",
    height: height,
  );
}
import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';

class AppThemes {
  static ThemeData lightTheme = ThemeData(
      fontFamily: 'cairo',

      // Set scaffoldBackgroundColor to white as the base background
      scaffoldBackgroundColor: AppColors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.accentColor.withOpacity(0.5),
        foregroundColor: AppColors.white,
        titleTextStyle: const TextStyle(
          fontFamily: 'cairo',
          color: AppColors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        elevation: 0,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryColor,
        unselectedItemColor: AppColors.secondaryColor,
      ),
      colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.secondaryColor,
          onSurface: AppColors.primaryColor),
      inputDecorationTheme: const InputDecorationTheme(
          fillColor: AppColors.white,
          filled: true,
          suffixIconColor: AppColors.secondaryColor,
          prefixIconColor: AppColors.secondaryColor,
          hintStyle: TextStyle(
            fontSize: 15,
            color: AppColors.secondaryColor,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide.none,
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide.none,
          )));
}

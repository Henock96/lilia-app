import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color.fromARGB(255, 243, 95, 95);
  static const Color secondaryColor = Color(0xFFFFA726);
  static const Color accentColor = Color(0xFF59061F);
  static const Color backgroundColor = Color(0xFFFBFAFA);
  static const Color textColor = Color(0xFF2E2E2E);

  static ThemeData get theme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: 'Lora',
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: backgroundColor,
        onPrimary: Colors.white,
        onSecondary: textColor,
        onSurface: textColor,
        error: Colors.red,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textColor,
          fontFamily: 'Lora',
        ),
        displayMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textColor,
          fontFamily: 'Lora',
        ),
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textColor,
          fontFamily: 'Lora',
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textColor,
          fontFamily: 'Lora',
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textColor,
          fontFamily: 'Lora',
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Lora',
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        errorStyle: TextStyle(color: textColor),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF616161),
          fontFamily: 'Lora',
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Lora',
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Lora',
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(backgroundColor: Colors.black87),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: Color(0xFFF6BBB5),
      ),
    );
  }
}

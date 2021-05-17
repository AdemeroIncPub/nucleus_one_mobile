import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

ThemeData n1AppTheme = _buildLightTheme();

class _ThemeCommon {
  static const MaterialColor primaryMaterialColor = MaterialColor(
    _palettePrimaryValue,
    <int, Color>{
      50: Color(0xFFE5F5F4),
      100: Color(0xFFBDE5E4),
      200: Color(0xFF92D4D3),
      300: Color(0xFF66C2C1),
      400: Color(0xFF45B5B3),
      500: Color(_palettePrimaryValue),
      600: Color(0xFF20A09E),
      700: Color(0xFF1B9795),
      800: Color(0xFF168D8B),
      900: Color(0xFF0D7D7B),
    },
  );
  static const MaterialColor secondaryMaterialColor = MaterialColor(
    _paletteSecondaryValue,
    <int, Color>{
      50: Color(0xFFE0EDEE),
      100: Color(0xFFB3D2D4),
      200: Color(0xFF80B4B8),
      300: Color(0xFF4D969B),
      400: Color(0xFF268085),
      500: Color(_paletteSecondaryValue),
      600: Color(0xFF006168),
      700: Color(0xFF00565D),
      800: Color(0xFF004C53),
      900: Color(0xFF003B41),
    },
  );

  static const int _palettePrimaryValue = 0xff24a8a6;
  static const int _paletteSecondaryValue = 0xff24a8a6;

  // static const String fontFamily = 'Arial';
  static const accentColor = primaryMaterialColor;
  static const primaryColor = primaryMaterialColor;
  static const primarySwatch = primaryMaterialColor;
  static const buttonColor = secondaryMaterialColor;

  static const iconTheme_color = Colors.white;

  static const textTheme_title_fontSize = 15.0;
  static const textTheme_title_fontWeight = FontWeight.w400;
}

class _ThemeLight {
  static const primaryTextColor = const Color(0xff000000);
}

// class _ThemeDark {
//   static const primaryTextColor = const Color(0xff24a8a6);
//   static const decorationColor = primaryTextColor;
// }

ThemeData _buildLightTheme() {
  var baseTheme = ThemeData(
      // fontFamily: _ThemeCommon.fontFamily,
      // canvasColor: white,
      disabledColor: _ThemeLight.primaryTextColor.withOpacity(0.35),
      accentColor: _ThemeCommon.accentColor,
      primaryColor: _ThemeCommon.primaryColor,
      primarySwatch: _ThemeCommon.primarySwatch,
      brightness: Brightness.light,
      // selectedRowColor: _ThemeCommon.selectedRowColor,
      buttonColor: _ThemeCommon.buttonColor,
      // dividerColor: _ThemeLight.dividerColor,
      primaryIconTheme: IconThemeData(color: _ThemeLight.primaryTextColor),
      hintColor: _ThemeLight.primaryTextColor,
      //dialogBackgroundColor: white,
      );

  baseTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(
          bodyColor: _ThemeLight.primaryTextColor,
          // decorationColor: _ThemeLight.decorationColor,
          displayColor: _ThemeLight.primaryTextColor));

  baseTheme = baseTheme.copyWith(
      iconTheme: baseTheme.iconTheme.copyWith(color: _ThemeCommon.iconTheme_color),
      textTheme: baseTheme.textTheme.copyWith(
          headline6: baseTheme.textTheme.headline6!.copyWith(
              // color: _ThemeCommon._getPurpleTextColor(true, false),
              fontSize: _ThemeCommon.textTheme_title_fontSize,
              fontWeight: _ThemeCommon.textTheme_title_fontWeight)));

  ThemeData ret = baseTheme;

  return ret;
}

enum ThemeType { light }

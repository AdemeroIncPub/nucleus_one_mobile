import 'package:flutter/material.dart';

ThemeData n1AppTheme = _buildDarkTheme();

class _ThemeCommon {
  static const MaterialColor primaryMaterialColor = const MaterialColor(
    _palettePrimaryValue,
    const <int, Color>{
      50: Color(0xff73839e),
      100: Color(0xff697994),
      200: Color(0xff606f8a),
      300: Color(0xff576680),
      400: Color(0xff4e5c76),
      500: Color(_palettePrimaryValue),
      600: Color(0xff3c4a63),
      700: Color(0xff334159),
      800: Color(0xff2b3850),
      900: Color(0xff223047),
    },
  );

  static const int _palettePrimaryValue = 0xff45536c;

  // static const String fontFamily = 'Arial';
  static const accentColor = primaryMaterialColor;
  static const primaryColor = primaryMaterialColor;
  static const primarySwatch = primaryMaterialColor;

  static const iconTheme_color = Colors.white;

  static const textTheme_title_fontSize = 15.0;
  static const textTheme_title_fontWeight = FontWeight.w400;
}

class _ThemeDark {
  static const primaryTextColor = Colors.white;
}

ThemeData _buildDarkTheme() {
  var baseTheme = ThemeData(
    // fontFamily: _ThemeCommon.fontFamily,
    canvasColor: Color.fromARGB(0xFF, 0x25, 0x2e, 0x40),
    disabledColor: _ThemeDark.primaryTextColor.withOpacity(0.35),
    primaryColor: _ThemeCommon.primaryColor,
    primarySwatch: _ThemeCommon.primarySwatch,
    brightness: Brightness.light,
    // selectedRowColor: _ThemeCommon.selectedRowColor,
    // dividerColor: _ThemeLight.dividerColor,
    primaryIconTheme: IconThemeData(color: _ThemeDark.primaryTextColor),
    hintColor: _ThemeDark.primaryTextColor,
    //dialogBackgroundColor: white,
  );

  baseTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(
    bodyColor: _ThemeDark.primaryTextColor,
    // decorationColor: _ThemeLight.decorationColor,
    displayColor: _ThemeDark.primaryTextColor,
  ));

  baseTheme = baseTheme.copyWith(
      iconTheme: baseTheme.iconTheme.copyWith(color: _ThemeCommon.iconTheme_color),
      textTheme: baseTheme.textTheme.copyWith(
          headline6: baseTheme.textTheme.headline6!.copyWith(
              // color: _ThemeCommon._getPurpleTextColor(true, false),
              fontSize: _ThemeCommon.textTheme_title_fontSize,
              fontWeight: _ThemeCommon.textTheme_title_fontWeight)),
      colorScheme: baseTheme.colorScheme.copyWith(secondary: _ThemeCommon.accentColor),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        primary: Colors.white,
      )));

  ThemeData ret = baseTheme;

  return ret;
}

enum ThemeType { light }

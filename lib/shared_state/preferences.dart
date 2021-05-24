import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nucleus_one_mobile/common/runtime_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Preferences with ChangeNotifier {
  static const String _prefKey_deviceBrowserFingerprint = 'deviceBrowserFingerprint';

  SharedPreferences? _sharedPrefs;

  Future<void> initializeAsync() async {
    _sharedPrefs = await SharedPreferences.getInstance();
  }

  int? get deviceBrowserFingerprint {
    final sp = _sharedPrefs;
    if (sp == null) {
      return null;
    }
    final value = sp.get(_prefKey_deviceBrowserFingerprint);
    return tryCast<int?>(value, null);
  }

  Future<void> setDeviceBrowserFingerprint(int? value) async {
    if (value == null) {
      await _sharedPrefs!.remove(_prefKey_deviceBrowserFingerprint);
    } else {
      await _sharedPrefs!.setInt(_prefKey_deviceBrowserFingerprint, value);
    }
    notifyListeners();
  }
}

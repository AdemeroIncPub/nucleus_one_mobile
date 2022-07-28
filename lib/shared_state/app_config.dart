import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:quiver/strings.dart' as quiver_strings;

enum Flavor { dev, prod }

enum FlutterMode { debug, release, profile }

@immutable
class AppConfig {
  AppConfig({
    required this.flavor,
    required this.hostName,
    required this.apiBaseUrl,
    required this.webAppBaseUrl,
    required this.googleSignInClientId,
  })  : assert(!quiver_strings.isBlank(hostName)),
        assert(!quiver_strings.isBlank(apiBaseUrl)),
        assert(!quiver_strings.isBlank(webAppBaseUrl)),
        assert(!quiver_strings.isBlank(googleSignInClientId));

  final Flavor flavor;
  final String hostName;
  final String apiBaseUrl;
  final String webAppBaseUrl;
  final String googleSignInClientId;

  FlutterMode getFlutterMode() {
    /* https://github.com/flutter/flutter/issues/11392#issuecomment-317807633 */
    if (_isReleaseMode()) {
      return FlutterMode.release;
    } else if (_isDebugMode()) {
      return FlutterMode.debug;
    } else {
      return FlutterMode.profile;
    }
  }
}

bool _isReleaseMode() {
  return const bool.fromEnvironment('dart.vm.product');
}

bool _isDebugMode() {
  bool inDebugMode = false;
  assert(() {
    inDebugMode = true;
    return true;
  }());
  return inDebugMode;
}

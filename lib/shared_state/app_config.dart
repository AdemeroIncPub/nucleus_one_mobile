import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:quiver/strings.dart' as quiver_strings;

enum Flavor { dev, prod }

enum FlutterMode { debug, release, profile }

@immutable
class AppConfig {
  AppConfig({
    required this.flavor,
    required this.topLevelDomain,
    required this.apiBaseUrl,
    required this.webAppBaseUrl,
    required this.googleSignInClientId,
    required this.googleSignInServerClientId,
  })  : assert(!quiver_strings.isBlank(topLevelDomain)),
        assert(!quiver_strings.isBlank(apiBaseUrl)),
        assert(!quiver_strings.isBlank(webAppBaseUrl)),
        assert(!quiver_strings.isBlank(googleSignInClientId)),
        assert(!quiver_strings.isBlank(googleSignInServerClientId));

  final Flavor flavor;
  final String topLevelDomain;
  final String apiBaseUrl;
  final String webAppBaseUrl;
  /// Also known as the "Web application" Client ID in Google Cloud Console's Credentials configuration.
  final String googleSignInClientId;
  /// Also known as the "Android" Client ID in Google Cloud Console's Credentials configuration.
  final String googleSignInServerClientId;

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

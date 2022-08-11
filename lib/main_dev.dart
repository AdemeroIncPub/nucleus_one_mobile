import 'package:flutter/material.dart';
import 'package:nucleus_one_mobile/shared_state/app_config.dart';

import 'main_common.dart';

void main() async {
  const topLevelDomain = 'multi-tenant-dms-staging.com';
  final appConfig = AppConfig(
    flavor: Flavor.dev,
    topLevelDomain: topLevelDomain,
    apiBaseUrl: 'https://client-api.$topLevelDomain',
    webAppBaseUrl: 'https://$topLevelDomain',
    googleSignInClientId: '661248912206-8uo87nli6sdlbq077t8799qdlki8onqp.apps.googleusercontent.com',
  );
  await mainCommon(appConfig);
  runApp(MyApp());
}

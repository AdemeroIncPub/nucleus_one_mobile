import 'package:flutter/material.dart';
import 'package:nucleus_one_mobile/shared_state/app_config.dart';

import 'main_common.dart';

void main() async {
  const topLevelDomain = 'nucleus.one';
  final appConfig = AppConfig(
    flavor: Flavor.prod,
    topLevelDomain: topLevelDomain,
    apiBaseUrl: 'https://client-api.$topLevelDomain',
    webAppBaseUrl: 'https://app.$topLevelDomain',
    googleSignInClientId: '712775463138-dcc10aimc0ulqf86cjgg1oghatgtlcgh.apps.googleusercontent.com',
    googleSignInServerClientId: '712775463138-j921jouids3ant1fdkaftqaib1o4jf0u.apps.googleusercontent.com',
  );
  await mainCommon(appConfig);
  runApp(MyApp());
}

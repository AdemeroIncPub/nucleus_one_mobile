import 'package:flutter/material.dart';
import 'package:nucleus_one_mobile/shared_state/app_config.dart';

import 'main_common.dart';

void main() async {
  const hostName = 'nucleus.one';
  final appConfig = AppConfig(
    flavor: Flavor.prod,
    hostName: hostName,
    apiBaseUrl: 'https://client-api.$hostName',
    webAppBaseUrl: 'https://app.$hostName',
    googleSignInClientId: '712775463138-dcc10aimc0ulqf86cjgg1oghatgtlcgh.apps.googleusercontent.com',
  );
  await mainCommon(appConfig);
  runApp(MyApp());
}

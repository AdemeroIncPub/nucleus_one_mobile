import 'package:flutter/material.dart';
import 'package:nucleus_one_mobile/shared_state/app_config.dart';

import 'main_common.dart';

void main() async {
  const hostName = 'app.nucleus.one';
  final appConfig = AppConfig(
    flavor: Flavor.prod,
    hostName: hostName,
    apiBaseUrl: 'https://client-api.$hostName',
    webAppBaseUrl: 'https://$hostName',
  );
  await mainCommon(appConfig);
  runApp(MyApp());
}

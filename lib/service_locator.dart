import 'package:get_it/get_it.dart';

import 'shared_state/app_config.dart';
import 'shared_state/preferences.dart';

final GetIt _sl = GetIt.instance;

Future<void> initializeServiceLocator(AppConfig appConfig) async {
  _sl.registerSingleton<AppConfig>(appConfig);
  _sl.registerSingletonAsync<Preferences>(() async {
    final p = Preferences();
    await p.initializeAsync();
    return p;
  });

  return _sl.allReady();
}

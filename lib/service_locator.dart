import 'package:get_it/get_it.dart';

import 'shared_state/preferences.dart';

final GetIt _sl = GetIt.instance;

Future<void> initializeServiceLocator() async {
  _sl.registerSingletonAsync<Preferences>(() async {
    final p = Preferences();
    await p.initializeAsync();
    return p;
  });

  return _sl.allReady();
}

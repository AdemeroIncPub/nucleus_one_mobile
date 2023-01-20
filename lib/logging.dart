import 'shared_state/session.dart';

class Logging {
  static Future<void> log(String message) async {
    await Session.n1App?.log(message:message);
  }
}

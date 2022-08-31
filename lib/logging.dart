import 'dart:convert';

import 'package:http/http.dart' as http;

import 'shared_state/session.dart';

class Logging {
  // /api/v1/logs

  static Future<void> log(String message) async {
    final apiLogUrl = (Session.n1App as dynamic).getFullUrl('/logs') as String;
    var headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final resp = await http.post(
      Uri.parse(apiLogUrl),
      headers: headers,
      body: jsonEncode({
        'Value1': message,
      }),
    );
    print(resp);
  }
}

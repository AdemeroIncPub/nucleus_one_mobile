import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in/google_sign_in.dart' as gapi;

import 'package:nucleus_one_dart_sdk/nucleus_one_dart_sdk.dart';

abstract class Session {
  // static const HostName = 'multi-tenant-dms-staging.com';
  // static const ApiBaseUrl = 'https://client-api.$HostName';
  // static const WebAppBaseUrl = 'https://$HostName';
  static const HostName = '192.168.1.105';
  static const ApiBaseUrl = 'http://$HostName:8080';
  static const WebAppBaseUrl = 'http://$HostName:3000';

  static NucleusOneApp? n1App;
  static String? n1SessionId;
  static User? n1User;

  static GoogleSignInAccount? googleSignInAccount;
  static gapi.GoogleSignIn? googleSignIn;
}

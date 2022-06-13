import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in/google_sign_in.dart' as gapi;

import 'package:nucleus_one_dart_sdk/nucleus_one_dart_sdk.dart';

abstract class Session {
  static NucleusOneApp? n1App;
  static String? n1SessionId;
  static User? n1User;

  static GoogleSignInAccount? googleSignInAccount;
  static gapi.GoogleSignIn? googleSignIn;
}

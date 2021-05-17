// @dart=2.10
// TODO: Remove the above line once migrated to null safety

import 'dart:convert';
import 'dart:io';

import 'package:ext_storage/ext_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:nucleus_one_dart_sdk/nucleus_one_dart_sdk.dart' as n1_sdk;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as iawv;
import 'package:google_sign_in/google_sign_in.dart' as gapi;
import 'package:flutter/services.dart';
import 'package:flutter_user_agent/flutter_user_agent.dart';
import 'package:nucleus_one_mobile/common/spin_wait_dialog.dart';
import 'package:nucleus_one_mobile/session.dart';
import 'package:nucleus_one_mobile/theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
// import 'package:webview_cookie_manager/webview_cookie_manager.dart';
// import 'package:webview_flutter/webview_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initialzeDependencies();

  // _forceDebugProxy();
  runApp(MyApp());
}

Future<void> _initialzeDependencies() async {
  await n1_sdk.NucleusOne.intializeSdk();
  Session.n1App = await n1_sdk.NucleusOne.initializeApp(
      options: n1_sdk.NucleusOneOptions(
    baseUrl: Session.ApiBaseUrl,
  ));

  await Permission.camera.request();
  await Permission.microphone.request();
  await Permission.storage.request();
}

/*
class _MyProxyHttpOverride extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext context) {
    return super.createHttpClient(context)
      ..findProxy = (uri) {
        return "PROXY 192.168.1.105:8888;";
      }
      // Accept invalid certificates
      ..badCertificateCallback = (X509Certificate _, String __, int ___) => true;
  }
}

void _forceDebugProxy() {
// In your main.dart
  HttpOverrides.global = _MyProxyHttpOverride();
}
*/

Map<String, dynamic> parseIdToken(String idToken) {
  final parts = idToken.split(r'.');
  assert(parts.length == 3);

  return jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: n1AppTheme,
      home: _SinglePageAppHost(),
    );
  }
}

class _SinglePageAppHostModel with ChangeNotifier {
  bool loggedIn = false;
  bool errorDuringInitialization = false;

  bool _initializing = true;
  bool get initializing => _initializing;
  set initializing(bool value) {
    _initializing = value;
    notifyListeners();
  }

  void forceNotifyListeners() {
    notifyListeners();
  }

  void reinitialize() {
    loggedIn = false;
    errorDuringInitialization = false;
    initializing = true;
    _initiateLoginAttempt();
  }

  void _initiateLoginAttempt() {
    Session.googleSignIn = gapi.GoogleSignIn();
    Session.googleSignIn.signIn().then((googleSignInAccount) {
      Session.googleSignInAccount = googleSignInAccount;

      Session.googleSignInAccount.authentication.then((googleKey) async {
        // print(googleKey.accessToken);
        // print(googleKey.idToken);
        // print(Session.googleSignIn.currentUser.displayName);

        // TODO: Find something better than this
        final browserFingerprint = Uuid().v4().hashCode;
        final authApi = Session.n1App.auth();

        final loginResult = await authApi.loginGoogle(browserFingerprint, googleKey.idToken);
        if (loginResult.success) {
          Session.n1SessionId = loginResult.sessionId;
          Session.n1User = loginResult.user;
          loggedIn = true;
        }
        initializing = false;
      }).catchError((err) {
        print(err);

        // TODO: Log to Crashlytics

        errorDuringInitialization = true;
        initializing = false;
      });
    }).catchError((err) {
      // This path is only known to occur when the user doesn't select a Google account at the shown prompt
      print(err);

      initializing = false;
    });
  }
}

class _SinglePageAppHost extends StatefulWidget {
  @override
  _SinglePageAppHostState createState() => _SinglePageAppHostState();
}

class _SinglePageAppHostState extends State<_SinglePageAppHost> {
  _SinglePageAppHostModel _model;

  @override
  void initState() {
    super.initState();
    _model = _SinglePageAppHostModel();
    _model.reinitialize();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<_SinglePageAppHostModel>.value(
        value: _model,
        builder: (BuildContext context, Widget child) {
          return Consumer<_SinglePageAppHostModel>(
            builder: (context, selector, child) {
              return Scaffold(
                body: SafeArea(
                  child: _buildSpaChild(context),
                ),
              );
            },
          );
        });
  }

  Widget _buildSpaChild(BuildContext context) {
    Widget child;

    final modelLocal = context.watch<_SinglePageAppHostModel>();

    if (modelLocal.initializing) {
      child = const SpinWaitDialog();
    } else if (modelLocal.loggedIn) {
      child = _EmbededWebAppPage();
    } else {
      child = _LoggedOut();
    }
    return child;
  }
}

class _EmbededWebAppPage extends StatefulWidget {
  @override
  _EmbededWebAppPageState createState() => _EmbededWebAppPageState();
}

class _EmbededWebAppPageState extends State<_EmbededWebAppPage> {
  String _userAgent;
  String _webUserAgent;
  iawv.InAppWebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    initUserAgentState();

    // TODO: Remove this before publishing
    iawv.AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initUserAgentState() async {
    String userAgent, webViewUserAgent;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      userAgent = await FlutterUserAgent.getPropertyAsync('userAgent');
      await FlutterUserAgent.init();
      webViewUserAgent = FlutterUserAgent.webViewUserAgent;
      print('''
  applicationVersion => ${FlutterUserAgent.getProperty('applicationVersion')}
  systemName         => ${FlutterUserAgent.getProperty('systemName')}
  userAgent          => $userAgent
  webViewUserAgent   => $webViewUserAgent
  packageUserAgent   => ${FlutterUserAgent.getProperty('packageUserAgent')}
        ''');
    } on PlatformException {
      userAgent = webViewUserAgent = '<error>';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _userAgent = userAgent;
      _webUserAgent = webViewUserAgent;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_userAgent == null) {
      return Container();
    }

    return SafeArea(
      child: WillPopScope(
        onWillPop: () => _exitApp(context),
        child: iawv.InAppWebView(
          // initialUrl: "https://flutter.dev/",
          // initialHeaders: {},
          initialOptions: iawv.InAppWebViewGroupOptions(
            crossPlatform: iawv.InAppWebViewOptions(),
          ),
          onWebViewCreated: (iawv.InAppWebViewController controller) async {
            _webViewController = controller;
            _initializeWebViewController(_webViewController);

            final urlForCookie = Uri.parse(Session.WebAppBaseUrl + '/');
            const initialUrlAsString = Session.WebAppBaseUrl + '/dashboard';
            final initialUrl = Uri.parse(initialUrlAsString);
            final initialDomain = initialUrl.host;

            final cookieManager = iawv.CookieManager.instance();
            await cookieManager.setCookie(
                url: urlForCookie,
                name: 'G_ENABLED_IDPS',
                value: 'google',
                domain: initialDomain,
                isHttpOnly: false);
            await cookieManager.setCookie(
                url: urlForCookie,
                name: 'G_AUTHUSER_H',
                value: '0',
                domain: initialDomain,
                isHttpOnly: false);
            await cookieManager.setCookie(
                url: urlForCookie,
                name: 'session_v1',
                value: Session.n1SessionId,
                domain: initialDomain,
                isHttpOnly: false);

            _webViewController.loadUrl(
              urlRequest: iawv.URLRequest(url: initialUrl),
              // headers: {
              //   'Cookie': 'G_ENABLED_IDPS=google; G_AUTHUSER_H=0; session_
              // },
            );
          },
          shouldOverrideUrlLoading: (controller, navAction) async {
            final url = navAction.request.url;

            if (url.path.endsWith('/login')) {
              setState(() {});
              return iawv.NavigationActionPolicy.CANCEL;
            }
            return iawv.NavigationActionPolicy.ALLOW;
          },
          onConsoleMessage:
              (iawv.InAppWebViewController controller, iawv.ConsoleMessage consoleMessage) {
            print('----------------------------------------------------------------------------');
            print(consoleMessage.message);
          },
          // onLoadStart: (InAppWebViewController controller, String url) {
          //   setState(() {
          //     this.url = url;
          //   });
          // },
          onLoadStop: (iawv.InAppWebViewController controller, Uri url) async {
            final js = await rootBundle.loadString('assets/js/core.js');
            
            // Inject JavaScript that will receive data back from Flutter
            _webViewController.evaluateJavascript(source: js);
          },
          // onProgressChanged: (InAppWebViewController controller, int progress) {
          //   setState(() {
          //     this.progress = progress / 100;
          //   });
          // },
        ),
      ),
    );
  }

  void _initializeWebViewController(iawv.InAppWebViewController controller) {
    controller.addJavaScriptHandler(
        handlerName: 'routerLocationChanged',
        callback: (args) {
          final argMap = args[0] as Map;
          _handleRouterLocationChangedEvent(argMap['pathname'] as String);
        });
  }

  Future<bool> _exitApp(BuildContext context) async {
    if (await _webViewController.canGoBack()) {
      _webViewController.goBack();
      return true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No back history item')),
      );
      return false;
    }
  }

  void _handleRouterLocationChangedEvent(String pathName) async {
    switch (pathName) {
      case '/logout':
        Session.n1SessionId = null;
        if (Session.googleSignIn != null) {
          await Session.googleSignIn.signOut();
          Session.googleSignIn = null;
          Session.googleSignInAccount = null;
        }
        final model = context.read<_SinglePageAppHostModel>();
        model.loggedIn = false;
        model.forceNotifyListeners();
        break;
      default:
    }
  }
}

class _LoggedOut extends StatefulWidget {
  @override
  _LoggedOutState createState() => _LoggedOutState();
}

class _LoggedOutState extends State<_LoggedOut> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/nucleusOne.png'),
          ElevatedButton(
            child: Text('SIGN IN'),
            onPressed: () {
              final model = context.read<_SinglePageAppHostModel>();
              model.reinitialize();
            },
          ),
        ],
      ),
    );
  }
}

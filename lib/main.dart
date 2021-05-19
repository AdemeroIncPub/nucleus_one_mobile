import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:nucleus_one_dart_sdk/nucleus_one_dart_sdk.dart' as n1_sdk;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
// import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as iawv;
import 'package:google_sign_in/google_sign_in.dart' as gapi;
import 'package:flutter/services.dart';
import 'package:fk_user_agent/fk_user_agent.dart';
import 'package:nucleus_one_mobile/common/spin_wait_dialog.dart';
import 'package:nucleus_one_mobile/session.dart';
import 'package:nucleus_one_mobile/theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initialzeDependencies();

  // _forceDebugProxy();
  runApp(MyApp());
}

// void downloadCallback(String id, DownloadTaskStatus status, int progress) {
//   /*if (debug)*/ {
//     print('Background Isolate Callback: task ($id) is in status ($status) and process ($progress)');
//   }
//   final send = IsolateNameServer.lookupPortByName('downloader_send_port')!;
//   send.send([id, status, progress]);
// }

Future<void> _initialzeDependencies() async {
  await n1_sdk.NucleusOne.intializeSdk();
  Session.n1App = await n1_sdk.NucleusOne.initializeApp(
      options: n1_sdk.NucleusOneOptions(
    baseUrl: Session.ApiBaseUrl,
  ));

  await Permission.camera.request();
  await Permission.microphone.request();
  await Permission.storage.request();

  // await FlutterDownloader.initialize(
  //   debug: true, // optional: set false to disable printing logs to console
  // );
  // FlutterDownloader.registerCallback(downloadCallback);
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
    final gsi = Session.googleSignIn = gapi.GoogleSignIn();
    gsi.signIn().then((googleSignInAccount) {
      final gsia = Session.googleSignInAccount = googleSignInAccount!;

      gsia.authentication.then((googleKey) async {
        final googleKeyIdToken = googleKey.idToken;
        if (googleKeyIdToken == null) {
          throw StateError('Unable to obtain Google sign-in token.');
        }

        // print(googleKey.accessToken);
        // print(googleKeyIdToken);
        // print(Session.googleSignIn.currentUser.displayName);

        final browserFingerprint = Uuid().v4().hashCode;
        final authApi = Session.n1App!.auth();

        final loginResult = await authApi.loginGoogle(browserFingerprint, googleKeyIdToken);
        if (loginResult.success) {
          Session.n1SessionId = loginResult.sessionId!;
          Session.n1User = loginResult.user!;
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
  late _SinglePageAppHostModel _model;

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
        builder: (BuildContext context, Widget? child) {
          return Consumer<_SinglePageAppHostModel>(
            builder: (context, selector, child2) {
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
      child = _EmbededWebAppPage();
      // child = _LoggedOut();
    }
    return child;
  }
}

class _EmbededWebAppPage extends StatefulWidget {
  @override
  _EmbededWebAppPageState createState() => _EmbededWebAppPageState();
}

class _EmbededWebAppPageState extends State<_EmbededWebAppPage> {
  String? _userAgent;
  String? _webUserAgent;

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
      userAgent = await FkUserAgent.getPropertyAsync('userAgent');
      await FkUserAgent.init();
      webViewUserAgent = FkUserAgent.webViewUserAgent ?? '';
      print('''
  applicationVersion => ${FkUserAgent.getProperty('applicationVersion')}
  systemName         => ${FkUserAgent.getProperty('systemName')}
  userAgent          => $userAgent
  webViewUserAgent   => $webViewUserAgent
  packageUserAgent   => ${FkUserAgent.getProperty('packageUserAgent')}
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
    if ((_webUserAgent == null) || (_webUserAgent == '')) {
      return Container();
    }

    return SafeArea(
      child: _buildInAppWebView(context),
    );
  }

  Widget _buildInAppWebView(BuildContext context,
      [iawv.CreateWindowAction? onCreateWindowRequest]) {
    final isChildWindow = (onCreateWindowRequest != null);
    iawv.InAppWebViewController? _webViewController;

    final urlForCookie = Uri.parse(Session.WebAppBaseUrl + '/');
    const initialUrlAsString = Session.WebAppBaseUrl + '/dashboard';
    final initialUrl = Uri.parse(initialUrlAsString);
    final initialDomain = initialUrl.host;

    final retIawv = WillPopScope(
      onWillPop: () async {
        final wvc = _webViewController!;
        if (await wvc.canGoBack()) {
          // Get the webview history
          final webHistory = await wvc.getCopyBackForwardList();
          if ((webHistory!.currentIndex ?? 0) > 0) {
            await wvc.goBack();
            return false;
          }
        }
        return true;
      },
      child: iawv.InAppWebView(
        // Setting the windowId property is important here!
        windowId: onCreateWindowRequest?.windowId,
        initialUrlRequest:
            isChildWindow ? onCreateWindowRequest!.request : iawv.URLRequest(url: initialUrl),
        initialOptions: iawv.InAppWebViewGroupOptions(
          android: iawv.AndroidInAppWebViewOptions(
            supportMultipleWindows: true,
            useHybridComposition: true,
          ),
          crossPlatform: iawv.InAppWebViewOptions(
            userAgent: _webUserAgent!,
            javaScriptCanOpenWindowsAutomatically: true,
            useShouldOverrideUrlLoading: true,
            useOnDownloadStart: true,
          ),
        ),
        onCreateWindow: (controller, onCreateWindowRequest) async {
          showDialog(
            context: context,
            builder: (context) {
              return Container(
                  child: Column(children: <Widget>[
                Expanded(
                  child: _buildInAppWebView(context, onCreateWindowRequest),
                )
              ]));
            },
          );

          return true;
        },
        onCloseWindow: (controller) {
          if (isChildWindow) {
            Navigator.of(context).pop();
          }
        },
        onWebViewCreated: (iawv.InAppWebViewController controller) async {
          _webViewController = controller;
          _initializeWebViewController(_webViewController!);

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
              value: Session.n1SessionId!,
              domain: initialDomain,
              isHttpOnly: false);
        },
        onDownloadStart: (controller, url) async {
          final urlString = url.toString();

          // print("onDownloadStart $url");

          // final downloadLocation = await getExternalStorageDirectory();

          // if (downloadLocation == null) {
          //   return;
          // }

          // final taskId = await FlutterDownloader.enqueue(
          //   url: url.toString(),
          //   savedDir: downloadLocation.path,
          // );

          // if (await canLaunch(urlString)) {
          //   await launch(urlString);
          //   return;
          // }

          // TODO: Revisit this when the following issue is addressed
          // https://github.com/fluttercommunity/flutter_downloader/issues/466
          showDialog<void>(
            context: context,
            barrierDismissible: true,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Error'),
                content: SingleChildScrollView(
                  child: Text('This feature is currently under development.'),
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        },
        shouldOverrideUrlLoading: (controller, navAction) async {
          final url = navAction.request.url;

          // if (url?.path.endsWith('/login') == true) {
          //   setState(() {});
          //   return iawv.NavigationActionPolicy.CANCEL;
          // }
          return iawv.NavigationActionPolicy.ALLOW;
        },
        onConsoleMessage:
            (iawv.InAppWebViewController controller, iawv.ConsoleMessage consoleMessage) {
          print('----------------------------------------------------------------------------');
          print(consoleMessage.message);
        },
        onLoadStop: (iawv.InAppWebViewController controller, Uri? url) async {
          final js = await rootBundle.loadString('assets/js/core.js');

          // Inject JavaScript that will receive data back from Flutter
          _webViewController!.evaluateJavascript(source: js);
        },
      ),
    );

    return retIawv;
  }

  void _initializeWebViewController(iawv.InAppWebViewController controller) {
    controller.addJavaScriptHandler(
        handlerName: 'routerLocationChanged',
        callback: (args) {
          final argMap = args[0] as Map;
          _handleRouterLocationChangedEvent(argMap['pathname'] as String);
        });

    controller.addJavaScriptHandler(
        handlerName: 'login_handleGoogleLogin',
        callback: (args) {
          // final argMap = args[0] as Map;
          // _handleRouterLocationChangedEvent(argMap['pathname'] as String);

          final model = context.read<_SinglePageAppHostModel>();
          model.reinitialize();
        });
  }

  void _handleRouterLocationChangedEvent(String pathName) async {
    switch (pathName) {
      case '/logout':
        Session.n1SessionId = null;
        if (Session.googleSignIn != null) {
          await Session.googleSignIn!.signOut();
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

// class _LoggedOut extends StatefulWidget {
//   @override
//   _LoggedOutState createState() => _LoggedOutState();
// }

// class _LoggedOutState extends State<_LoggedOut> {
//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Image.asset('assets/images/nucleusOne.png'),
//           ElevatedButton(
//             child: Text('SIGN IN'),
//             onPressed: () {
//               final model = context.read<_SinglePageAppHostModel>();
//               model.reinitialize();
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }

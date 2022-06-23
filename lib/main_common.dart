import 'dart:convert';
import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:nucleus_one_dart_sdk/nucleus_one_dart_sdk.dart' as n1_sdk;
import 'package:flutter/material.dart';
// import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as iawv;
import 'package:google_sign_in/google_sign_in.dart' as gapi;
import 'package:flutter/services.dart';
import 'package:fk_user_agent/fk_user_agent.dart';
import 'package:nucleus_one_mobile/common/spin_wait_dialog.dart';
import 'package:nucleus_one_mobile/shared_state/app_config.dart';
import 'package:nucleus_one_mobile/shared_state/session.dart';
import 'package:nucleus_one_mobile/theme.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'service_locator.dart';
import 'shared_state/preferences.dart';

final _sl = GetIt.instance;

Future<void> mainCommon(AppConfig appConfig) {
  WidgetsFlutterBinding.ensureInitialized();
  return _initialzeDependencies(appConfig);

  // _forceDebugProxy();
}

// void downloadCallback(String id, DownloadTaskStatus status, int progress) {
//   /*if (debug)*/ {
//     print('Background Isolate Callback: task ($id) is in status ($status) and process ($progress)');
//   }
//   final send = IsolateNameServer.lookupPortByName('downloader_send_port')!;
//   send.send([id, status, progress]);
// }

Future<void> _initialzeDependencies(AppConfig appConfig) async {
  await initializeServiceLocator(appConfig);
  await n1_sdk.NucleusOne.intializeSdk();
  Session.n1App = await n1_sdk.NucleusOne.initializeApp(
      options: n1_sdk.NucleusOneOptions(
    baseUrl: _sl<AppConfig>().apiBaseUrl,
    browserFingerprint: await _getDeviceBrowserFingerprint(),
  ));

  await Permission.camera.request();
  await Permission.storage.request();
  await Permission.notification.request();

  // await FlutterDownloader.initialize(
  //   debug: true, // optional: set false to disable printing logs to console
  // );
  // FlutterDownloader.registerCallback(downloadCallback);
}

Future<int> _getDeviceBrowserFingerprint() async {
  final prefs = _sl<Preferences>();
  var browserFingerprint = prefs.deviceBrowserFingerprint;
  if (browserFingerprint == null) {
    browserFingerprint = Uuid().v4().hashCode;
    await prefs.setDeviceBrowserFingerprint(browserFingerprint);
  }
  return browserFingerprint;
}

/*
class _MyProxyHttpOverride extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
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
      debugShowCheckedModeBanner: false,
      title: 'Nucleus One',
      theme: n1AppTheme,
      home: _SinglePageAppHost(),
    );
  }
}

enum OnDeviceAccountAuthProvider { google }

class _SinglePageAppHostModel with ChangeNotifier {
  static final initialUrlAsString = _sl<AppConfig>().webAppBaseUrl;
  final initialUrl = Uri.parse(initialUrlAsString);
  String get initialDomain => initialUrl.host;

  bool loggedIn = false;
  OnDeviceAccountAuthProvider? loggedInWithOnDeviceAcct;
  bool errorDuringInitialization = false;

  bool _initializing = true;
  bool get initializing => _initializing;
  set initializing(bool value) {
    _initializing = value;
    notifyListeners();
  }

  bool _inErrorState = false;
  bool get inErrorState => _inErrorState;
  set inErrorState(bool value) {
    _inErrorState = value;
    notifyListeners();
  }

  String _errorState = '';
  String get errorState => _errorState;
  set errorState(String value) {
    _errorState = value;
    notifyListeners();
  }

  void forceNotifyListeners() {
    notifyListeners();
  }

  void reinitialize(OnDeviceAccountAuthProvider? loginWithOnDeviceAuthProvider) {
    loggedIn = false;
    loggedInWithOnDeviceAcct = null;
    errorDuringInitialization = false;
    initializing = true;
    if (loginWithOnDeviceAuthProvider == null) {
      initializing = false;
    } else {
      _initiateLoginAttempt(loginWithOnDeviceAuthProvider);
    }
  }

  void _initiateLoginAttempt(OnDeviceAccountAuthProvider loginWithOnDeviceAuthProvider) {
    switch (loginWithOnDeviceAuthProvider) {
      case OnDeviceAccountAuthProvider.google:
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

            final authApi = Session.n1App!.auth();
            final loginResult = await authApi.loginGoogle(googleKeyIdToken);
            if (loginResult.success) {
              Session.n1SessionId = loginResult.sessionId!;
              Session.n1User = loginResult.user!;

              {
                final urlForCookie = Uri.parse(_sl<AppConfig>().webAppBaseUrl + '/');

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
                    value: '1',
                    domain: initialDomain,
                    isHttpOnly: false);
                await cookieManager.setCookie(
                    url: urlForCookie,
                    name: 'session_v1',
                    value: Session.n1SessionId!,
                    domain: initialDomain,
                    isHttpOnly: false);
              }

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
        break;
    }
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
    _model.reinitialize(null);
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
    final webAppPage = _EmbededWebAppPage();
    final modelLocal = context.watch<_SinglePageAppHostModel>();

    if (modelLocal.inErrorState) {
      return _WebPageLoadFailure();
    }

    return modelLocal.initializing ? const SpinWaitDialog() : webAppPage;
  }
}

class _EmbededWebAppPageModel with ChangeNotifier {
  bool _initializing = true;
  bool get initializing => _initializing;
  set initializing(bool value) {
    _initializing = value;
    notifyListeners();
  }

  void forceNotifyListeners() {
    notifyListeners();
  }

  void finishInitialization() {
    initializing = false;
  }
}

class _EmbededWebAppPage extends StatefulWidget {
  @override
  _EmbededWebAppPageState createState() => _EmbededWebAppPageState();
}

class _EmbededWebAppPageState extends State<_EmbededWebAppPage> {
  String? _webUserAgent;
  _SinglePageAppHostModel? _model;
  late _EmbededWebAppPageModel _lateModel;
  bool _isFirstRun = true;

  // For iOS, this user agent is used instead of the default for the in-app webview because that
  // user agent triggers a bug in said component.  See below for details.  When this issue is
  // resolved, this workaround can be removed.
  // https://github.com/pichillilorenzo/flutter_inappwebview/issues/1112
  static const String _iosUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 Safari/605.1.15';

  @override
  void initState() {
    super.initState();
    _lateModel = _EmbededWebAppPageModel();
    initUserAgentState();
    // Remove this before publishing
    // if (Platform.isAndroid) {
    //   iawv.AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
    // }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initUserAgentState() async {
    String userAgent, webViewUserAgent;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      userAgent = await _getUserAgent();
      await FkUserAgent.init();
      webViewUserAgent = _getWebViewUserAgent();
      print(
          '''
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
      _webUserAgent = webViewUserAgent;
    });
  }

  String _getWebViewUserAgent() {
    return Platform.isIOS ? _iosUserAgent : (FkUserAgent.webViewUserAgent ?? '');
  }

  Future<dynamic> _getUserAgent() async {
    return Platform.isIOS ? _iosUserAgent : await FkUserAgent.getPropertyAsync('userAgent');
  }

  @override
  Widget build(BuildContext context) {
    if ((_webUserAgent == null) || (_webUserAgent == '')) {
      return Container();
    }

    return ChangeNotifierProvider<_EmbededWebAppPageModel>.value(
        value: _lateModel,
        builder: (BuildContext context, Widget? child) {
          return Consumer<_EmbededWebAppPageModel>(
            builder: (context, selector, child2) {
              return SafeArea(
                child: _buildSpaChild(context),
              );
            },
          );
        });
  }

  Widget _buildSpaChild(BuildContext context) {
    final modelLocal = context.watch<_EmbededWebAppPageModel>();
    final stack = Stack(
      fit: StackFit.expand,
      children: [_buildInAppWebView(context), SpinWaitDialog()],
    );
    if (!modelLocal.initializing) {
      stack.children.removeLast();
      _isFirstRun = false;
    }

    return stack;
  }

  Widget _buildInAppWebView(BuildContext context,
      [iawv.CreateWindowAction? onCreateWindowRequest]) {
    final model = _model = context.read<_SinglePageAppHostModel>();
    final isChildWindow = (onCreateWindowRequest != null);
    iawv.InAppWebViewController? _webViewController;

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
            isChildWindow ? onCreateWindowRequest!.request : _buildURLRequest(model.initialUrl),
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
            builder: (_) {
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
        },
        onDownloadStart: (controller, url) async {
          // final urlString = url.toString();

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
          // final url = navAction.request.url;

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
          final jsCore = await rootBundle.loadString('assets/js/core.js');
          // Inject JavaScript that will receive data back from Flutter
          _webViewController!.evaluateJavascript(source: jsCore);

          // If Android, inject JavaScript that will override the default Google login button on the
          // Login page.  This enables us to use on-device account authentication, instead of the
          // user's browser's accounts.
          if (Platform.isAndroid) {
            final jsLogin = await rootBundle.loadString('assets/js/login.js');
            _webViewController!.evaluateJavascript(source: jsLogin);
          }

          if (_isFirstRun) {
            () async {
              await Future.delayed(Duration(seconds: 1));
              _lateModel.finishInitialization();
            }();
          }
        },
        onLoadError:
            (iawv.InAppWebViewController controller, Uri? url, int code, String message) async {
          _model!.errorState = "$code: $message";
          _model!.inErrorState = true;
        },
        onLoadHttpError: (iawv.InAppWebViewController controller, Uri? url, int statusCode,
            String description) async {
          _model!.errorState = "$statusCode: $description";
          _model!.inErrorState = true;
        },
      ),
    );
    return retIawv;
  }

  iawv.URLRequest _buildURLRequest(Uri url) {
    return iawv.URLRequest(
      url: url,
    );
  }

  void _initializeWebViewController(iawv.InAppWebViewController controller) {
    controller.addJavaScriptHandler(
        handlerName: 'routerLocationChanged',
        callback: (args) {
          final argMap = args[0] as Map;
          print(argMap['pathname'] as String);
          _handleRouterLocationChangedEvent(argMap['pathname'] as String);
        });

    controller.addJavaScriptHandler(
        handlerName: 'login_handleGoogleLogin',
        callback: (args) {
          // final argMap = args[0] as Map;
          // _handleRouterLocationChangedEvent(argMap['pathname'] as String);

          _model!.reinitialize(OnDeviceAccountAuthProvider.google);
        });
  }

  void _handleRouterLocationChangedEvent(String pathName) async {
    switch (pathName) {
      case '/dashboard':
        if (!_model!.loggedIn) {
          final urlForCookie = Uri.parse(_sl<AppConfig>().webAppBaseUrl + '/');
          final cookieManager = iawv.CookieManager.instance();
          final sessionId = (await cookieManager.getCookie(url: urlForCookie, name: 'session_v1'))
              ?.value as String?;

          if (sessionId == null) {
            return;
          }

          final r = Session.n1App!.auth().reestablishExistingSession(sessionId);
          Session.n1SessionId = sessionId;
          Session.n1User = r.user;
          _model!.loggedIn = true;
        }
        break;
      case '/logout':
        Session.n1SessionId = null;
        if (Session.googleSignIn != null) {
          await Session.googleSignIn!.signOut();
          Session.googleSignIn = null;
          Session.googleSignInAccount = null;
        }
        final model = _model!;
        model.loggedIn = false;
        model.forceNotifyListeners();
        break;
      default:
    }
  }
}

class _WebPageLoadFailure extends StatefulWidget {
  const _WebPageLoadFailure({Key? key}) : super(key: key);

  @override
  State<_WebPageLoadFailure> createState() => _WebPageLoadFailureState();
}

class _WebPageLoadFailureState extends State<_WebPageLoadFailure> {
  @override
  Widget build(BuildContext context) {
    final model = context.read<_SinglePageAppHostModel>();
    final mediaSize = MediaQuery.of(context).size;

    return SizedBox.expand(
      child: Container(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20.0,
            mediaSize.height * 0.06,
            20.0,
            0.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('assets/images/nucleusOne.png'),
              Padding(padding: EdgeInsets.only(bottom: 30)),
              Text('There seems to be a problem...'),
              Padding(padding: EdgeInsets.only(bottom: 30)),
              Text(
                model.errorState,
                textAlign: TextAlign.center,
              ),
              Padding(padding: EdgeInsets.only(bottom: 30)),
              Text('Retrying may resolve this issue.'),
              TextButton(
                child: const Text('RETRY'),
                onPressed: () {
                  model.errorState = '';
                  model.inErrorState = false;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

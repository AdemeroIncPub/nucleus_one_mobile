import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:nucleus_one_dart_sdk/nucleus_one_dart_sdk.dart' as n1_sdk;
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as iawv;
import 'package:google_sign_in/google_sign_in.dart' as gapi;
import 'package:flutter/services.dart';
import 'package:fk_user_agent/fk_user_agent.dart';
import 'package:nucleus_one_dart_sdk/nucleus_one_dart_sdk.dart';
import 'package:nucleus_one_mobile/common/spin_wait_dialog.dart';
import 'package:nucleus_one_mobile/shared_state/app_config.dart';
import 'package:nucleus_one_mobile/shared_state/session.dart';
import 'package:nucleus_one_mobile/theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'service_locator.dart';
import 'shared_state/preferences.dart';

final _sl = GetIt.instance;

Future<void> mainCommon(AppConfig appConfig) {
  WidgetsFlutterBinding.ensureInitialized();
  return _initialzeDependencies(appConfig);

  // _forceDebugProxy();
}

void downloadCallback(String id, DownloadTaskStatus status, int progress) {
  final send = IsolateNameServer.lookupPortByName('downloader_send_port')!;
  send.send([id, status, progress]);
}

Future<void> _initialzeDependencies(AppConfig appConfig) async {
  await initializeServiceLocator(appConfig);
  await n1_sdk.NucleusOne.initializeSdk();
  Session.n1App = n1_sdk.NucleusOneApp(
      options: n1_sdk.NucleusOneOptions(
    apiBaseUrl: appConfig.apiBaseUrl,
  ));
  Session.browserFingerprint = await _getDeviceBrowserFingerprint();

  // The iOS-specific logic in these methods is needed because of an open bug in the main permission-
  // requesting library, permission_handler.  Once this bug is fixed, this logic and the other
  // permission libraries can be removed.
  // While this bug only mentions issues with location permission requests, it manifests in other
  // permission requests, as well, but only in release builds and only on iOS.
  // https://github.com/Baseflow/flutter-permission-handler/issues/783
  await _requestCameraPermissions();
  await _requestStoragePermission();
  await _requestNotificationPermissions();

  await FlutterDownloader.initialize(
      debug: true, // optional: set to false to disable printing logs to console (default: true)
      ignoreSsl: true // option: set to false to disable working with http links (default: false)
      );
  await FlutterDownloader.registerCallback(downloadCallback);
}

Future<void> _requestStoragePermission() async {
  await Permission.storage.request();
}

Future<void> _requestNotificationPermissions() async {
  if (Platform.isIOS) {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    final initializationSettingsIOS = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    final initializationSettingsMacOS = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    final initializationSettings = InitializationSettings(
      iOS: initializationSettingsIOS,
      macOS: initializationSettingsMacOS,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  } else {
    await Permission.notification.request();
  }
}

Future<void> _requestCameraPermissions() async {
  if (Platform.isIOS) {
    await PhotoManager.requestPermissionExtend();
  } else {
    await Permission.camera.request();
  }
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
        final gsi = Session.googleSignIn = gapi.GoogleSignIn(
          clientId: _sl<AppConfig>().googleSignInClientId,
          serverClientId: _sl<AppConfig>().googleSignInServerClientId,
        );

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

            final loginResult = await Session.n1App!.user().loginGoogle(
                  oauthIdToken: googleKeyIdToken,
                  browserFingerprint: Session.browserFingerprint!,
                );
            if (loginResult.success) {
              Session.n1SessionId = loginResult.sessionId!;
              Session.n1User = loginResult.user!;

              {
                final appConfig = _sl<AppConfig>();
                final urlForCookie = Uri.parse('https://' + appConfig.topLevelDomain);
                final cookieManager = iawv.CookieManager.instance();
                final expiresDate =
                    DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;
                await cookieManager.setCookie(
                  url: urlForCookie,
                  name: 'session_v1',
                  value: Session.n1SessionId!,
                  domain: appConfig.topLevelDomain,
                  path: '/',
                  expiresDate: expiresDate,
                  sameSite: iawv.HTTPCookieSameSitePolicy.LAX,
                  isHttpOnly: false,
                  isSecure: appConfig.flavor == Flavor.prod,
                );
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

    if (Platform.isAndroid) {
      iawv.AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
    }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initUserAgentState() async {
    String userAgent, webViewUserAgent;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      userAgent = await _getUserAgent();
      await FkUserAgent.init();
      webViewUserAgent = _getWebViewUserAgent();
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
      _webUserAgent = webViewUserAgent;
    });
  }

  String _getWebViewUserAgent() {
    return Platform.isIOS
        ? _iosUserAgent
        : 'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1';
    //: (FkUserAgent.webViewUserAgent ?? '');
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
      children: [_buildInAppWebView(context, null, false), SpinWaitDialog()],
    );
    if (!modelLocal.initializing) {
      stack.children.removeLast();
      _isFirstRun = false;
    }

    return stack;
  }

  Widget _buildInAppWebView(
    BuildContext context, [
    iawv.CreateWindowAction? onCreateWindowRequest,
    bool isExternalLink = false,
  ]) {
    final model = _model = context.read<_SinglePageAppHostModel>();
    final isChildWindow = (onCreateWindowRequest != null);
    iawv.InAppWebViewController? _webViewController;

    final retIawv = WillPopScope(
      onWillPop: () async {
        if (_webViewController == null) {
          return false;
        }
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
        onDownloadStartRequest: (controller, downloadStartRequest) async {
          final externalDir = await getExternalStorageDirectory();
          await FlutterDownloader.enqueue(
            url: downloadStartRequest.url.toString(),
            headers: {}, // optional: header send with url (auth token etc)
            savedDir: externalDir!.path,
            saveInPublicStorage: true,
            showNotification: true, // show download progress in status bar (for Android)
            openFileFromNotification:
                true, // click on notification to open downloaded file (for Android)
          );
        },
        // Setting the windowId property is important here!
        windowId: onCreateWindowRequest?.windowId,
        initialUrlRequest:
            isChildWindow ? onCreateWindowRequest.request : _buildURLRequest(model.initialUrl),
        initialOptions: iawv.InAppWebViewGroupOptions(
          android: iawv.AndroidInAppWebViewOptions(
            supportMultipleWindows: true,
            useHybridComposition: true,
          ),
          crossPlatform: iawv.InAppWebViewOptions(
            //userAgent: _webUserAgent!,
            userAgent: _webUserAgent!,
            javaScriptCanOpenWindowsAutomatically: true,
            useShouldOverrideUrlLoading: true,
            useOnDownloadStart: true,
            javaScriptEnabled: true,
            useOnLoadResource: true,
            cacheEnabled: true,
          ),
        ),
        onCreateWindow: (controller, onCreateWindowRequest) async {
          final currentUrl = await controller.getUrl();
          final openInExternalBrowser = !currentUrl!.path.startsWith('/login');

          showDialog(
            context: context,
            builder: (_) {
              final iawvChild = Container(
                  child: Column(children: <Widget>[
                Expanded(
                  child: _buildInAppWebView(context, onCreateWindowRequest, openInExternalBrowser),
                )
              ]));

              if (openInExternalBrowser) {
                // Draw the web view off screen
                return Transform.translate(
                  offset: Offset(MediaQuery.of(context).size.width, 0),
                  child: iawvChild,
                );
              }

              return iawvChild;
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
        shouldOverrideUrlLoading: (controller, navAction) async {
          if (isExternalLink) {
            launchUrl(
              navAction.request.url!,
              mode: LaunchMode.externalApplication,
            );

            Navigator.of(context).pop();

            return iawv.NavigationActionPolicy.CANCEL;
          }

          return iawv.NavigationActionPolicy.ALLOW;
        },
        onConsoleMessage:
            (iawv.InAppWebViewController controller, iawv.ConsoleMessage consoleMessage) {
          final msg = 'N1 Session: ' +
              (Session.n1SessionId ?? '') +
              ', ' +
              consoleMessage.messageLevel.toString() +
              ' ' +
              consoleMessage.message;

          print('----------------------------------------------------------------------------');
          print(msg);
          // Logging.log(msg);
        },
        onLoadStop: (iawv.InAppWebViewController controller, Uri? url) async {
          if (!_isFirstRun) {
            return;
          }
          final jsCore = await rootBundle.loadString('assets/js/core.js');
          // Inject JavaScript that will receive data back from Flutter
          await _webViewController!.evaluateJavascript(source: jsCore);

          final jsProjects = await rootBundle.loadString('assets/js/projects_departments.js');
          await _webViewController!.evaluateJavascript(source: jsProjects);

          // If Android, inject JavaScript that will override the default Google login button on the
          // Login page.  This enables us to use on-device account authentication, instead of the
          // user's browser's accounts.
          if (Platform.isAndroid) {
            final jsLogin = await rootBundle.loadString('assets/js/login.js');
            _webViewController!.evaluateJavascript(source: jsLogin);
          } else if (Platform.isIOS) {
            // Apple does not permit an app to offer in-app purchases, including subscriptions,
            // without said purchase being routed though Apple's in-app-purchase platform.  So,
            // just hide the relevant controls in the mobile app for iOS only.
            final jsSubscription = await rootBundle.loadString('assets/js/subscription.js');
            _webViewController!.evaluateJavascript(source: jsSubscription);
          }

          () async {
            await Future.delayed(Duration(seconds: 1));
            _lateModel.finishInitialization();
          }();
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

          final r = new _Auth(app: Session.n1App!).reestablishExistingSession(sessionId);
          Session.setAuthenticationState(sessionId);
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

class _Auth {
  NucleusOneApp app;

  _Auth({
    required this.app,
  });

  /// Reestablishes the authentication state to be with the provided auth provider and session id.
  ///
  /// [sessionId]: An existing session id with the authentication provider.
  LoginResult reestablishExistingSession(String sessionId) {
    Session.setAuthenticationState(sessionId);

    return LoginResult(
      success: true,
      sessionId: sessionId,
      user: User(app: app),
    );
  }
}

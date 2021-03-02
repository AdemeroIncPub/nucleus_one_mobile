import 'dart:convert';
import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:nucleus_one_dart_sdk/nucleus_one_dart_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as iawv;
import 'package:google_sign_in/google_sign_in.dart' as gapi;
import 'package:flutter/services.dart';
import 'package:flutter_user_agent/flutter_user_agent.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
// import 'package:webview_cookie_manager/webview_cookie_manager.dart';
// import 'package:webview_flutter/webview_flutter.dart';

abstract class Session {
  static const HostName = 'multi-tenant-dms-staging.com';
  static const ApiBaseUrl = 'https://client-api.$HostName';
  static const WebAppBaseUrl = 'https://$HostName';
  // static const HostName = '192.168.1.105';
  // static const ApiBaseUrl = 'http://$HostName:8080';
  // static const WebAppBaseUrl = 'http://$HostName:3000';

  static NucleusOneApp n1App;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _initialzeDependencies();

  await Permission.camera.request();
  await Permission.microphone.request();

  Session.n1App = await NucleusOne.initializeApp(
      options: NucleusOneOptions(
    baseUrl: Session.ApiBaseUrl,
  ));

  // _forceDebugProxy();
  runApp(MyApp());
}

void _initialzeDependencies() {
  GetIt.I.registerSingleton<NucleusOneApp>(NucleusOneAppUninitialized());
}

class MyProxyHttpOverride extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext context) {
    return super.createHttpClient(context)
      ..findProxy = (uri) {
        return "PROXY 192.168.1.105:8888;";
      }
      ..badCertificateCallback = (X509Certificate _, String __, int ___) => true;
  }
}

void _forceDebugProxy() {
// In your main.dart
  HttpOverrides.global = MyProxyHttpOverride();
}

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
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with 'flutter run'. You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // 'hot reload' (press 'r' in the console where you ran 'flutter run',
        // or simply save your changes to 'hot reload' in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: _EmbededWebAppPage(),
    );
  }
}

class _EmbededWebAppPage extends StatefulWidget {
  @override
  _EmbededWebAppPageState createState() => _EmbededWebAppPageState();
}

class _EmbededWebAppPageState extends State<_EmbededWebAppPage> {
  String _userAgent;
  String _webUserAgent;
  String _n1SessionId;
  GoogleSignInAccount _googleSignInAccount;
  // WebViewController _webViewController;
  iawv.InAppWebViewController _webViewController;

  gapi.GoogleSignIn _googleSignIn;

  @override
  void initState() {
    super.initState();
    initUserAgentState();
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

    if (_n1SessionId == null) {
      _googleSignIn = gapi.GoogleSignIn();
      _googleSignIn.signIn().then((googleSignInAccount) {
        _googleSignInAccount = googleSignInAccount;

        _googleSignInAccount.authentication.then((googleKey) async {
          print(googleKey.accessToken);
          print(googleKey.idToken);
          print(_googleSignIn.currentUser.displayName);

          // TODO: Find something better than this
          final browserFingerprint = Uuid().v4().hashCode;

          final authApi = Session.n1App.auth();
          final docApi = Session.n1App.document();
          // final i = await docApi.getDocumentCount(true, true);
          if (mounted) {
            final loginResult = await authApi.loginGoogle(browserFingerprint, googleKey.idToken);
            if (loginResult.success) {
              final i2 = await docApi.getCount(true, true);
              print(i2);
              setState(() {
                _n1SessionId = loginResult.sessionId;
              });
            }
          }
        }).catchError((err) {
          print(err);
        });
      }).catchError((err) {
        print(err);
      });
      return Container();
    }

    return SafeArea(
      child: WillPopScope(
        onWillPop: () => _exitApp(context),
        child: iawv.InAppWebView(
          // initialUrl: "https://flutter.dev/",
          // initialHeaders: {},
          initialOptions: iawv.InAppWebViewGroupOptions(
              crossPlatform: iawv.InAppWebViewOptions(
            debuggingEnabled: true,
          )),
          onWebViewCreated: (iawv.InAppWebViewController controller) async {
            _webViewController = controller;

            const urlForCookie = Session.WebAppBaseUrl + '/';
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
                value: _n1SessionId,
                domain: initialDomain,
                isHttpOnly: false);

            _webViewController.loadUrl(
              url: initialUrlAsString,
              // headers: {
              //   'Cookie': 'G_ENABLED_IDPS=google; G_AUTHUSER_H=0; session_
              // },
            );
          },
          shouldOverrideUrlLoading: (controller, shouldOverrideUrlLoadingRequest) async {
            final url = shouldOverrideUrlLoadingRequest.url;

            if (url.endsWith('/login')) {
              setState(() {});
              return iawv.ShouldOverrideUrlLoadingAction.CANCEL;
            }
            return iawv.ShouldOverrideUrlLoadingAction.ALLOW;
          },
          // onLoadStart: (InAppWebViewController controller, String url) {
          //   setState(() {
          //     this.url = url;
          //   });
          // },
          // onLoadStop: (InAppWebViewController controller, String url) async {
          //   setState(() {
          //     this.url = url;
          //   });
          // },
          // onProgressChanged: (InAppWebViewController controller, int progress) {
          //   setState(() {
          //     this.progress = progress / 100;
          //   });
          // },
        ),
      ),
    );
  }

  Future<bool> _exitApp(BuildContext context) async {
    if (await _webViewController.canGoBack()) {
      _webViewController.goBack();
      return true;
    } else {
      Scaffold.of(context).showSnackBar(
        const SnackBar(content: Text('No back history item')),
      );
      return false;
    }
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked 'final'.

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  NucleusOneApp _nucleusOneApp;
  int _counter = 0;

  void _incrementCounter() async {
    // final a = gapi.GoogleSignIn(
    //   // hostedDomain: 'localhost',
    //   clientId: '661248912206-195u7nvvse3ob3ps6m6n36a4162573rv.apps.googleusercontent.com',
    // );
    // var isSignedIn = await a.isSignedIn();
    // final gsia = await a.signIn();
    // isSignedIn = await a.isSignedIn();
    // print(isSignedIn);

    // final api = API('https://client-api.multi-tenant-dms-staging.com');
    final docApi = Session.n1App.document();
    final i = await docApi.getCount(true, true);
    print(i);

    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke 'debug painting' (press 'p' in the console, choose the
          // 'Toggle Debug Paint' action from the Flutter Inspector in Android
          // Studio, or the 'Toggle Debug Paint' command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

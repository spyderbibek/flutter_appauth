import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_appauth/flutter_appauth.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isBusy = false;
  final FlutterAppAuth _appAuth = FlutterAppAuth();
  String _codeVerifier;
  String _authorizationCode;
  String _refreshToken;
  String _accessToken;
  final TextEditingController _authorizationCodeTextController =
      TextEditingController();
  final TextEditingController _accessTokenTextController =
      TextEditingController();
  final TextEditingController _accessTokenExpirationTextController =
      TextEditingController();

  final TextEditingController _idTokenTextController = TextEditingController();
  final TextEditingController _refreshTokenTextController =
      TextEditingController();
  String _userInfo = '';

  // For a list of client IDs, go to https://demo.identityserver.io
  final String _clientId = '7bff33f611d9b01c79f340d75823bbc4';
  final String _redirectUrl = 'com.bksapps.animezone://login-callback';
//  final String _issuer = 'https://demo.identityserver.io';
//  final String _discoveryUrl =
//      'https://demo.identityserver.io/.well-known/openid-configuration';
//  final List<String> _scopes = <String>[
//    'openid',
//    'profile',
//    'email',
//    'offline_access',
//    'api'
//  ];

  final AuthorizationServiceConfiguration _serviceConfiguration =
      AuthorizationServiceConfiguration(
          'https://myanimelist.net/v1/oauth2/authorize',
          'https://myanimelist.net/v1/oauth2/token');

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Visibility(
                visible: _isBusy,
                child: const LinearProgressIndicator(),
              ),
              RaisedButton(
                child: const Text('Sign in with no code exchange'),
                onPressed: _signInWithNoCodeExchange,
              ),
              RaisedButton(
                child: const Text('Exchange code'),
                onPressed: _authorizationCode != null ? _exchangeCode : null,
              ),
              RaisedButton(
                child: const Text('Sign in with auto code exchange'),
                onPressed: () => _signInWithAutoCodeExchange(),
              ),
              if (Platform.isIOS)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: RaisedButton(
                    child: const Text(
                      'Sign in with auto code exchange using ephemeral session (iOS only)',
                      textAlign: TextAlign.center,
                    ),
                    onPressed: () => _signInWithAutoCodeExchange(
                        preferEphemeralSession: true),
                  ),
                ),
              RaisedButton(
                child: const Text('Refresh token'),
                onPressed: _refreshToken != null ? _refresh : null,
              ),
              const Text('authorization code'),
              TextField(
                controller: _authorizationCodeTextController,
              ),
              const Text('access token'),
              TextField(
                controller: _accessTokenTextController,
              ),
              const Text('access token expiration'),
              TextField(
                controller: _accessTokenExpirationTextController,
              ),
              const Text('id token'),
              TextField(
                controller: _idTokenTextController,
              ),
              const Text('refresh token'),
              TextField(
                controller: _refreshTokenTextController,
              ),
              const Text('test api results'),
              Text(_userInfo),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    try {
      _setBusyState();
      final TokenResponse result = await _appAuth.token(TokenRequest(
          _clientId, _redirectUrl,
          refreshToken: _refreshToken,
          serviceConfiguration: _serviceConfiguration,
          grantType: GrantType.refreshToken));
      _processTokenResponse(result);
      await _testApi(result);
    } catch (_) {
      _clearBusyState();
    }
  }

  Future<void> _exchangeCode() async {
    debugPrint('Auth Code: $_authorizationCode');
    debugPrint('Code Verifier: $_codeVerifier');
    try {
      _setBusyState();
      final TokenResponse result = await _appAuth.token(TokenRequest(
        _clientId,
        _redirectUrl,
        authorizationCode: _authorizationCode,
        serviceConfiguration: _serviceConfiguration,
        codeVerifier: _codeVerifier,
      ));
      debugPrint('Auth: ${result.accessToken}');
      debugPrint('Auth: ${result.refreshToken}');
      debugPrint('Auth: ${result.accessTokenExpirationDateTime}');
      _processTokenResponse(result);
//      await _testApi(result);
    } catch (e) {
      _clearBusyState();
      throw e.toString();
    }
  }

  Future<void> _signInWithNoCodeExchange() async {
    try {
      _setBusyState();
      // use the discovery endpoint to find the configuration
      final AuthorizationResponse result = await _appAuth.authorize(
        AuthorizationRequest(_clientId, _redirectUrl,
            serviceConfiguration: _serviceConfiguration),
      );

      // or just use the issuer
      // var result = await _appAuth.authorize(
      //   AuthorizationRequest(
      //     _clientId,
      //     _redirectUrl,
      //     issuer: _issuer,
      //     scopes: _scopes,
      //   ),
      // );
      if (result != null) {
        _processAuthResponse(result);
      }
    } catch (_) {
      _clearBusyState();
    }
  }

  Future<void> _signInWithAutoCodeExchange(
      {bool preferEphemeralSession = false}) async {
    try {
      _setBusyState();

      // show that we can also explicitly specify the endpoints rather than getting from the details from the discovery document
      final AuthorizationTokenResponse result =
          await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUrl,
          serviceConfiguration: _serviceConfiguration,
          preferEphemeralSession: preferEphemeralSession,
        ),
      );

      // this code block demonstrates passing in values for the prompt parameter. in this case it prompts the user login even if they have already signed in. the list of supported values depends on the identity provider
      // final AuthorizationTokenResponse result = await _appAuth.authorizeAndExchangeCode(
      //   AuthorizationTokenRequest(_clientId, _redirectUrl,
      //       serviceConfiguration: _serviceConfiguration,
      //       scopes: _scopes,
      //       promptValues: ['login']),
      // );

      if (result != null) {
        _processAuthTokenResponse(result);
        await _testApi(result);
      }
    } catch (_) {
      _clearBusyState();
    }
  }

  void _clearBusyState() {
    setState(() {
      _isBusy = false;
    });
  }

  void _setBusyState() {
    setState(() {
      _isBusy = true;
    });
  }

  void _processAuthTokenResponse(AuthorizationTokenResponse response) {
    debugPrint(response.accessToken);
    debugPrint(response.refreshToken);
    debugPrint(response.accessTokenExpirationDateTime?.toIso8601String());
    setState(() {
      _accessToken = _accessTokenTextController.text = response.accessToken;
      _idTokenTextController.text = response.idToken;
      _refreshToken = _refreshTokenTextController.text = response.refreshToken;
      _accessTokenExpirationTextController.text =
          response.accessTokenExpirationDateTime?.toIso8601String();
    });
  }

  void _processAuthResponse(AuthorizationResponse response) {
    setState(() {
      // save the code verifier as it must be used when exchanging the token
      _codeVerifier = response.codeVerifier;
      _authorizationCode =
          _authorizationCodeTextController.text = response.authorizationCode;
      _isBusy = false;
    });
  }

  void _processTokenResponse(TokenResponse response) {
    setState(() {
      _accessToken = _accessTokenTextController.text = response.accessToken;
      _idTokenTextController.text = response.idToken;
      _refreshToken = _refreshTokenTextController.text = response.refreshToken;
      _accessTokenExpirationTextController.text =
          response.accessTokenExpirationDateTime?.toIso8601String();
    });
  }

  Future<void> _testApi(TokenResponse response) async {
    final http.Response httpResponse = await http.get(
        'https://demo.identityserver.io/api/test',
        headers: <String, String>{'Authorization': 'Bearer $_accessToken'});
    setState(() {
      _userInfo = httpResponse.statusCode == 200 ? httpResponse.body : '';
      _isBusy = false;
    });
  }
}

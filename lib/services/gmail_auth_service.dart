import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/email_account.dart';

/// Levée quand Google a révoqué/expiré la connexion d'un compte et qu'il
/// faut le reconnecter manuellement (ex : app encore en mode "Test",
/// connexion valable 7 jours seulement).
class GmailReauthRequiredException implements Exception {
  final String email;
  GmailReauthRequiredException(this.email);

  @override
  String toString() =>
      'La connexion à $email a expiré. Reconnectez ce compte dans Paramètres > Comptes.';
}

/// Gère la connexion OAuth d'un compte Gmail.
///
/// Fonctionne de la même façon sur Windows et sur Android : on ouvre le
/// navigateur du système sur la page de connexion Google, et un petit
/// serveur local (sur l'appareil lui-même) attend que Google le renvoie
/// avec un code temporaire, qu'on échange ensuite contre les vrais jetons
/// d'accès. Rien ne transite ni ne reste jamais en clair.
class GmailAuthService {
  // Identifiants "Application de bureau" créés dans Google Cloud Console.
  // Ce type d'identifiant est prévu pour être utilisé par une application
  // installée (pas un serveur web) : le "secret" n'est pas une donnée
  // confidentielle au sens strict pour ce type d'app, Google le précise
  // dans sa documentation officielle.
  static const _clientId =
      '291397891123-1sgk9m5tsrrbp22nugi63rgrgmg2upp1.apps.googleusercontent.com';
  // Fourni à la compilation (--dart-define=GOOGLE_CLIENT_SECRET=...), jamais écrit dans le code source.
  static const _clientSecret = String.fromEnvironment('GOOGLE_CLIENT_SECRET');

  static const _authEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const _userInfoEndpoint =
      'https://www.googleapis.com/oauth2/v2/userinfo';

  static const _scopes = [
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/userinfo.email',
  ];

  /// Lance le flux complet de connexion et renvoie le compte connecté.
  /// Lève une exception si l'utilisateur annule ou si une erreur survient.
  Future<EmailAccount> connectAccount() async {
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _codeChallengeFromVerifier(codeVerifier);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    final redirectUri = 'http://localhost:$port';

    final authUrl = Uri.parse(_authEndpoint).replace(queryParameters: {
      'client_id': _clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': _scopes.join(' '),
      'access_type': 'offline',
      'prompt': 'consent',
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    });

    final launched = await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    if (!launched) {
      await server.close(force: true);
      throw Exception("Impossible d'ouvrir le navigateur pour la connexion.");
    }

    late String code;
    try {
      final request = await server.first.timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw TimeoutException('Connexion annulée : délai dépassé.'),
      );

      final params = request.uri.queryParameters;
      if (params.containsKey('error')) {
        _respond(request, 'Connexion annulée. Vous pouvez fermer cette page.');
        throw Exception('Connexion annulée par l\'utilisateur.');
      }
      code = params['code']!;
      _respond(request, 'Compte connecté ! Vous pouvez fermer cette page et revenir à Emailing Pro.');
    } finally {
      await server.close(force: true);
    }

    final tokenResponse = await http.post(
      Uri.parse(_tokenEndpoint),
      body: {
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'code': code,
        'code_verifier': codeVerifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      },
    );

    if (tokenResponse.statusCode != 200) {
      throw Exception('Échec de la connexion Google : ${tokenResponse.body}');
    }

    final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
    final accessToken = tokenData['access_token'] as String;
    final refreshToken = tokenData['refresh_token'] as String?;
    final expiresIn = tokenData['expires_in'] as int;

    if (refreshToken == null) {
      throw Exception(
          'Google n\'a pas fourni de jeton de renouvellement. Réessayez en révoquant l\'accès depuis myaccount.google.com/permissions puis reconnectez.');
    }

    final userInfoResponse = await http.get(
      Uri.parse(_userInfoEndpoint),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final userInfo = jsonDecode(userInfoResponse.body) as Map<String, dynamic>;
    final email = userInfo['email'] as String;

    return EmailAccount(
      email: email,
      provider: 'gmail',
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiry: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  /// Renouvelle le jeton d'accès d'un compte à partir de son jeton de
  /// renouvellement (appelé automatiquement quand le jeton a expiré).
  /// Lève [GmailReauthRequiredException] si Google a révoqué/expiré la
  /// connexion (cas fréquent tant que l'app Google reste en mode "Test" :
  /// la connexion expire automatiquement au bout de 7 jours).
  Future<EmailAccount> refreshAccessToken(EmailAccount account) async {
    final response = await http.post(
      Uri.parse(_tokenEndpoint),
      body: {
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'refresh_token': account.refreshToken,
        'grant_type': 'refresh_token',
      },
    );

    if (response.statusCode != 200) {
      if (response.body.contains('invalid_grant')) {
        throw GmailReauthRequiredException(account.email);
      }
      throw Exception('Échec du renouvellement de connexion : ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return account.copyWith(
      accessToken: data['access_token'] as String,
      accessTokenExpiry:
          DateTime.now().add(Duration(seconds: data['expires_in'] as int)),
    );
  }

  void _respond(HttpRequest request, String message) {
    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html
      ..write('<html><body style="font-family:sans-serif;text-align:center;padding-top:80px;">'
          '<h2>$message</h2></body></html>');
    request.response.close();
  }

  String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(64, (_) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  String _codeChallengeFromVerifier(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}

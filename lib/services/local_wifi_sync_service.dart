import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'local_backup_service.dart';
import 'log_service.dart';

/// Synchronisation directe entre deux appareils sur le même réseau Wi-Fi,
/// sans passer par Internet ni par le cloud.
///
/// Fonctionnement : un appareil démarre un petit serveur local (juste pour
/// la durée de la synchro) et affiche son adresse + un code à 6 chiffres.
/// L'autre appareil saisit cette adresse et ce code pour se connecter.
/// Le code doit correspondre pour que le transfert soit accepté — ça évite
/// qu'un autre appareil du même réseau Wi-Fi (ex : chez un voisin sur une
/// box mal sécurisée) ne puisse s'y connecter par erreur ou intention.
///
/// N'utilise que des briques déjà incluses dans Dart (HttpServer, sockets) :
/// aucune nouvelle dépendance, donc aucun risque supplémentaire pour la
/// compilation.
class LocalWifiSyncServer {
  static final instance = LocalWifiSyncServer._();
  LocalWifiSyncServer._();

  HttpServer? _server;
  String? pairingCode;

  bool get isRunning => _server != null;
  int? get port => _server?.port;

  /// Démarre le serveur et retourne le code de vérification à afficher.
  Future<String> start() async {
    await stop();
    pairingCode = (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    await LogService().log('Synchro Wi-Fi : serveur démarré sur le port ${_server!.port}');
    _server!.listen((HttpRequest request) async {
      try {
        await _handleRequest(request);
      } catch (e) {
        try {
          request.response.statusCode = 500;
          request.response.write(jsonEncode({'error': e.toString()}));
          await request.response.close();
        } catch (_) {}
      }
    });
    return pairingCode!;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final code = request.uri.queryParameters['code'];
    if (code != pairingCode) {
      request.response.statusCode = 403;
      request.response.write(jsonEncode({'error': 'Code incorrect.'}));
      await request.response.close();
      return;
    }

    if (request.method == 'GET' && request.uri.path == '/ping') {
      request.response.write(jsonEncode({'ok': true}));
      await request.response.close();
      return;
    }

    if (request.method == 'GET' && request.uri.path == '/export') {
      final snapshot = await buildSyncSnapshot();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(snapshot));
      await request.response.close();
      await LogService().log('Synchro Wi-Fi : données envoyées à un appareil connecté');
      return;
    }

    if (request.method == 'POST' && request.uri.path == '/import') {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      await mergeSyncData(data);
      request.response.write(jsonEncode({'ok': true}));
      await request.response.close();
      await LogService().log('Synchro Wi-Fi : données reçues d\'un appareil connecté');
      return;
    }

    request.response.statusCode = 404;
    await request.response.close();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    pairingCode = null;
  }

  /// Adresses IP locales de cet appareil sur lesquelles le serveur écoute
  /// (généralement une seule, celle du Wi-Fi — plusieurs si plusieurs
  /// interfaces réseau sont actives).
  static Future<List<String>> localAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      return interfaces.expand((i) => i.addresses).map((a) => a.address).toList();
    } catch (_) {
      return [];
    }
  }
}

/// Traduit une erreur réseau en message compréhensible pour la synchro
/// Wi-Fi (l'appareil distant est injoignable, refuse la connexion, etc.).
String friendlyWifiSyncError(Object error) {
  final message = error.toString();
  if (message.contains('SocketException') || message.contains('Connection refused')) {
    return 'Impossible de joindre l\'autre appareil — vérifiez qu\'il a bien démarré le serveur et que les deux appareils sont sur le même Wi-Fi.';
  }
  if (message.contains('TimeoutException')) {
    return 'L\'autre appareil ne répond pas (délai dépassé) — vérifiez le Wi-Fi.';
  }
  if (message.contains('403') || message.contains('Code incorrect')) {
    return 'Code incorrect — vérifiez qu\'il correspond bien à celui affiché sur l\'autre appareil.';
  }
  return 'Erreur de synchronisation Wi-Fi : $message';
}

/// Se connecte à un appareil qui a démarré le serveur (LocalWifiSyncServer)
/// pour lui envoyer ou récupérer des données.
class LocalWifiSyncClient {
  Future<void> _checkReachable(String host, int port, String code) async {
    final response = await http
        .get(Uri.parse('http://$host:$port/ping?code=$code'))
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Connexion refusée (code ${response.statusCode}).');
    }
  }

  /// Envoie les données de cet appareil vers l'appareil distant.
  Future<void> pushTo(String host, int port, String code) async {
    await _checkReachable(host, port, code);
    final snapshot = await buildSyncSnapshot();
    final response = await http
        .post(
          Uri.parse('http://$host:$port/import?code=$code'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(snapshot),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Échec de l\'envoi.');
    }
    await LogService().log('Synchro Wi-Fi : envoyé vers $host:$port');
  }

  /// Récupère les données de l'appareil distant et les fusionne ici.
  Future<void> pullFrom(String host, int port, String code) async {
    await _checkReachable(host, port, code);
    final response = await http
        .get(Uri.parse('http://$host:$port/export?code=$code'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Échec de la récupération.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await mergeSyncData(data);
    await LogService().log('Synchro Wi-Fi : récupéré depuis $host:$port');
  }
}

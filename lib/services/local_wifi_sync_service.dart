import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'local_backup_service.dart';
import 'log_service.dart';

/// Port fixe utilisé uniquement pour la découverte automatique (annonce
/// "je suis là") — pas pour le transfert de données lui-même, qui passe
/// par un port choisi automatiquement par le système.
const int _discoveryPort = 45678;
const String _discoveryProbe = 'EMAILINGPRO_DISCOVER';
const String _discoveryReplyPrefix = 'EMAILINGPRO_HERE:';

/// Un appareil détecté automatiquement sur le réseau Wi-Fi.
class DiscoveredDevice {
  final String host;
  final int port;
  final String deviceLabel;
  const DiscoveredDevice({required this.host, required this.port, required this.deviceLabel});
}

String get _deviceLabel {
  if (Platform.isWindows) return 'PC Windows';
  if (Platform.isAndroid) return 'Téléphone Android';
  return 'Appareil';
}

/// Synchronisation directe entre deux appareils sur le même réseau Wi-Fi,
/// sans passer par Internet ni par le cloud.
///
/// Fonctionnement : un appareil démarre un petit serveur local (juste pour
/// la durée de la synchro). L'autre appareil le détecte automatiquement sur
/// le réseau (pas besoin de recopier une adresse IP à la main) et saisit
/// uniquement le code à 6 chiffres affiché sur le premier appareil pour
/// confirmer la connexion. Le code évite qu'un autre appareil du même
/// réseau Wi-Fi (ex : chez un voisin sur une box mal sécurisée) ne puisse
/// s'y connecter par erreur ou intention.
///
/// N'utilise que des briques déjà incluses dans Dart (HttpServer, sockets
/// UDP) : aucune nouvelle dépendance, donc aucun risque supplémentaire pour
/// la compilation.
class LocalWifiSyncServer {
  static final instance = LocalWifiSyncServer._();
  LocalWifiSyncServer._();

  HttpServer? _server;
  RawDatagramSocket? _discoverySocket;
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
    await _startDiscoveryResponder();
    return pairingCode!;
  }

  /// Répond aux appareils qui cherchent un serveur sur le réseau, pour
  /// éviter d'avoir à recopier une adresse IP à la main. Ne révèle que le
  /// port et le nom de l'appareil — jamais le code de vérification.
  Future<void> _startDiscoveryResponder() async {
    try {
      _discoverySocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort, reuseAddress: true);
      _discoverySocket!.broadcastEnabled = true;
      _discoverySocket!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _discoverySocket!.receive();
        if (datagram == null) return;
        final message = utf8.decode(datagram.data);
        if (message != _discoveryProbe) return;
        final reply = utf8.encode('$_discoveryReplyPrefix${_server!.port}:$_deviceLabel');
        _discoverySocket!.send(reply, datagram.address, datagram.port);
      });
    } catch (_) {
      // La découverte automatique est un confort, pas un pré-requis : si le
      // port de découverte est déjà utilisé par autre chose, on continue
      // sans elle — l'adresse pourra toujours être saisie manuellement.
    }
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
    _discoverySocket?.close();
    _discoverySocket = null;
  }

  /// Adresses IP locales de cet appareil sur lesquelles le serveur écoute
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

  /// Cherche activement les serveurs disponibles sur le réseau local
  /// pendant quelques secondes, pour éviter d'avoir à saisir une adresse
  /// IP à la main.
  static Future<List<DiscoveredDevice>> discoverDevices({Duration timeout = const Duration(seconds: 3)}) async {
    final found = <String, DiscoveredDevice>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final completer = Completer<void>();
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket!.receive();
        if (datagram == null) return;
        final message = utf8.decode(datagram.data);
        if (!message.startsWith(_discoveryReplyPrefix)) return;
        final parts = message.substring(_discoveryReplyPrefix.length).split(':');
        if (parts.length < 2) return;
        final port = int.tryParse(parts[0]);
        if (port == null) return;
        final label = parts.sublist(1).join(':');
        final host = datagram.address.address;
        found['$host:$port'] = DiscoveredDevice(host: host, port: port, deviceLabel: label);
      });
      socket.send(utf8.encode(_discoveryProbe), InternetAddress('255.255.255.255'), _discoveryPort);
      await Future.any([Future.delayed(timeout), completer.future]);
    } catch (_) {
      // Pas de découverte possible (réseau restrictif, etc.) : la saisie
      // manuelle de l'adresse reste toujours disponible.
    } finally {
      socket?.close();
    }
    return found.values.toList();
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

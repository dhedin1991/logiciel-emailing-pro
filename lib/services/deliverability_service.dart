import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/email_account.dart';
import 'account_storage.dart';
import 'gmail_auth_service.dart';

/// Un e-mail rejeté APRÈS acceptation par Gmail (adresse inexistante,
/// boîte pleine, refus du serveur du destinataire, etc.).
class BounceInfo {
  final String address;
  final String reason;
  final DateTime date;
  BounceInfo({required this.address, required this.reason, required this.date});
}

/// Gmail répond "envoyé" dès qu'il ACCEPTE le message. Si le serveur du
/// destinataire le refuse ensuite, Gmail dépose un message d'erreur
/// (Mail Delivery Subsystem) dans la boîte de réception. Ce service les lit
/// pour montrer quelles adresses n'ont réellement pas reçu l'e-mail.
class DeliverabilityService {
  final _auth = GmailAuthService();
  final _storage = AccountStorage();

  Future<List<BounceInfo>> findBounces(EmailAccount account, {required DateTime since}) async {
    var acc = account;
    if (acc.isAccessTokenExpired) {
      acc = await _auth.refreshAccessToken(acc);
      await _storage.addOrUpdateAccount(acc);
    }
    final headers = {'Authorization': 'Bearer ${acc.accessToken}'};
    final epoch = since.toUtc().millisecondsSinceEpoch ~/ 1000;
    final query = 'from:(mailer-daemon OR postmaster) after:$epoch';

    final listResp = await http.get(
      Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages').replace(
        queryParameters: {'q': query, 'maxResults': '200'},
      ),
      headers: headers,
    );
    if (listResp.statusCode != 200) {
      throw Exception('Lecture de la boîte impossible (${listResp.statusCode}) : ${listResp.body}');
    }
    final ids = ((jsonDecode(listResp.body)['messages'] as List<dynamic>?) ?? [])
        .map((m) => (m as Map<String, dynamic>)['id'] as String)
        .toList();

    final bounces = <BounceInfo>[];
    for (final id in ids) {
      final resp = await http.get(
        Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/$id').replace(
          queryParameters: {
            'format': 'metadata',
            'metadataHeaders': ['X-Failed-Recipients', 'Subject'],
          },
        ),
        headers: headers,
      );
      if (resp.statusCode != 200) continue;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final hdrs = ((data['payload']?['headers'] as List<dynamic>?) ?? [])
          .cast<Map<String, dynamic>>();
      String? failed;
      for (final h in hdrs) {
        if ((h['name'] as String).toLowerCase() == 'x-failed-recipients') {
          failed = h['value'] as String?;
        }
      }
      final snippet = (data['snippet'] as String?) ?? '';
      failed ??= RegExp(r'[\w.+\-]+@[\w\-]+\.[\w.\-]+').firstMatch(snippet)?.group(0);
      if (failed == null) continue;
      final ts = int.tryParse('${data['internalDate']}') ?? 0;
      for (final addr in failed.split(',')) {
        bounces.add(BounceInfo(
          address: addr.trim(),
          reason: snippet,
          date: DateTime.fromMillisecondsSinceEpoch(ts),
        ));
      }
    }
    return bounces;
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/email_account.dart';
import 'account_storage.dart';
import 'gmail_auth_service.dart';

class GmailSendService {
  final _authService = GmailAuthService();
  final _storage = AccountStorage();

  /// Envoie un e-mail avec le compte donné. Renouvelle automatiquement le
  /// jeton d'accès s'il a expiré, et met à jour le compte sauvegardé.
  Future<void> sendEmail({
    required EmailAccount account,
    required String to,
    required String subject,
    required String body,
    String? cc,
    String? bcc,
  }) async {
    var currentAccount = account;
    if (currentAccount.isAccessTokenExpired) {
      currentAccount = await _authService.refreshAccessToken(currentAccount);
      await _storage.addOrUpdateAccount(currentAccount);
    }

    final message = _buildMimeMessage(
      from: currentAccount.email,
      to: to,
      cc: cc,
      bcc: bcc,
      subject: subject,
      body: body,
    );

    final encodedMessage = base64Url.encode(utf8.encode(message)).replaceAll('=', '');

    final response = await http.post(
      Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/send'),
      headers: {
        'Authorization': 'Bearer ${currentAccount.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'raw': encodedMessage}),
    );

    if (response.statusCode != 200) {
      throw Exception("Échec de l'envoi : ${response.body}");
    }
  }

  String _buildMimeMessage({
    required String from,
    required String to,
    String? cc,
    String? bcc,
    required String subject,
    required String body,
  }) {
    final headers = StringBuffer()
      ..writeln('From: $from')
      ..writeln('To: $to');
    if (cc != null && cc.trim().isNotEmpty) headers.writeln('Cc: $cc');
    if (bcc != null && bcc.trim().isNotEmpty) headers.writeln('Bcc: $bcc');
    headers
      ..writeln('Subject: =?UTF-8?B?${base64.encode(utf8.encode(subject))}?=')
      ..writeln('MIME-Version: 1.0')
      ..writeln('Content-Type: text/plain; charset="UTF-8"')
      ..writeln()
      ..write(body);
    return headers.toString();
  }
}

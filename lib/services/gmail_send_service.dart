import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/email_account.dart';
import 'account_storage.dart';
import 'gmail_auth_service.dart';

class GmailSendService {
  final _authService = GmailAuthService();
  final _storage = AccountStorage();

  /// Envoie un e-mail avec le compte donné. Renouvelle automatiquement le
  /// jeton d'accès s'il a expiré, et met à jour le compte sauvegardé.
  /// `attachmentPaths` est facultatif : chemins de fichiers sur l'appareil
  /// à joindre au message.
  Future<void> sendEmail({
    required EmailAccount account,
    required String to,
    required String subject,
    required String body,
    String? cc,
    String? bcc,
    List<String> attachmentPaths = const [],
  }) async {
    var currentAccount = account;
    if (currentAccount.isAccessTokenExpired) {
      currentAccount = await _authService.refreshAccessToken(currentAccount);
      await _storage.addOrUpdateAccount(currentAccount);
    }

    final message = attachmentPaths.isEmpty
        ? _buildSimpleMessage(
            from: currentAccount.email, to: to, cc: cc, bcc: bcc, subject: subject, body: body)
        : await _buildMessageWithAttachments(
            from: currentAccount.email,
            to: to,
            cc: cc,
            bcc: bcc,
            subject: subject,
            body: body,
            attachmentPaths: attachmentPaths,
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

  String _headerBlock({
    required String from,
    required String to,
    String? cc,
    String? bcc,
    required String subject,
  }) {
    final headers = StringBuffer()
      ..writeln('From: $from')
      ..writeln('To: $to');
    if (cc != null && cc.trim().isNotEmpty) headers.writeln('Cc: $cc');
    if (bcc != null && bcc.trim().isNotEmpty) headers.writeln('Bcc: $bcc');
    headers.writeln('Subject: =?UTF-8?B?${base64.encode(utf8.encode(subject))}?=');
    return headers.toString();
  }

  String _buildSimpleMessage({
    required String from,
    required String to,
    String? cc,
    String? bcc,
    required String subject,
    required String body,
  }) {
    final headers = StringBuffer(_headerBlock(from: from, to: to, cc: cc, bcc: bcc, subject: subject))
      ..writeln('MIME-Version: 1.0')
      ..writeln('Content-Type: text/plain; charset="UTF-8"')
      ..writeln()
      ..write(body);
    return headers.toString();
  }

  Future<String> _buildMessageWithAttachments({
    required String from,
    required String to,
    String? cc,
    String? bcc,
    required String subject,
    required String body,
    required List<String> attachmentPaths,
  }) async {
    const boundary = 'emailingpro-boundary-7a1f3c';
    final message = StringBuffer(_headerBlock(from: from, to: to, cc: cc, bcc: bcc, subject: subject))
      ..writeln('MIME-Version: 1.0')
      ..writeln('Content-Type: multipart/mixed; boundary="$boundary"')
      ..writeln()
      ..writeln('--$boundary')
      ..writeln('Content-Type: text/plain; charset="UTF-8"')
      ..writeln()
      ..writeln(body)
      ..writeln();

    for (final path in attachmentPaths) {
      final file = File(path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final fileName = path.split(Platform.pathSeparator).last;
      final base64Content = base64.encode(bytes);

      message
        ..writeln('--$boundary')
        ..writeln('Content-Type: application/octet-stream; name="$fileName"')
        ..writeln('Content-Disposition: attachment; filename="$fileName"')
        ..writeln('Content-Transfer-Encoding: base64')
        ..writeln();

      // Découpe le contenu encodé en lignes de 76 caractères (norme MIME).
      for (var i = 0; i < base64Content.length; i += 76) {
        final end = (i + 76 < base64Content.length) ? i + 76 : base64Content.length;
        message.writeln(base64Content.substring(i, end));
      }
      message.writeln();
    }

    message.writeln('--$boundary--');
    return message.toString();
  }
}

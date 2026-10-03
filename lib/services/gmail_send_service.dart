import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/email_account.dart';
import '../models/sent_email_log.dart';
import 'account_storage.dart';
import 'gmail_auth_service.dart';
import 'history_storage.dart';
import 'mime_utils.dart';

class GmailSendService {
  final _authService = GmailAuthService();
  final _storage = AccountStorage();
  final _historyStorage = HistoryStorage();
  final _uuid = const Uuid();

  /// Envoie un e-mail avec le compte donné. Renouvelle automatiquement le
  /// jeton d'accès s'il a expiré, et met à jour le compte sauvegardé.
  ///
  /// [preloadedAttachments] : pièces jointes déjà lues/encodées une seule fois
  /// pour toute une campagne. À défaut, [attachmentPaths] est lu ici.
  ///
  /// Important : l'historique est écrit APRÈS l'envoi, dans un bloc séparé.
  /// Un souci d'historique ne peut plus faire passer un e-mail parti pour un
  /// échec (et donc le faire renvoyer en double).
  Future<void> sendEmail({
    required EmailAccount account,
    required String to,
    required String subject,
    required String body,
    String? htmlBody,
    String? cc,
    String? bcc,
    List<String> attachmentPaths = const [],
    List<MimeAttachment>? preloadedAttachments,
    Map<String, String> extraHeaders = const {},
  }) async {
    var currentAccount = account;
    final recipientForLog = to;
    try {
      final toList = MimeUtils.parseAddresses(to, field: 'Destinataire');
      if (toList.isEmpty) throw const FormatException('Aucun destinataire.');
      final ccList = MimeUtils.parseAddresses(cc, field: 'Cc');
      final bccList = MimeUtils.parseAddresses(bcc, field: 'Cci');

      if (currentAccount.isAccessTokenExpired) {
        currentAccount = await _authService.refreshAccessToken(currentAccount);
        await _storage.addOrUpdateAccount(currentAccount);
      }

      final attachments =
          preloadedAttachments ?? await MimeUtils.loadAttachments(attachmentPaths);

      final message = MimeUtils.buildMessage(
        from: MimeUtils.fromHeader(currentAccount.email, currentAccount.displayName),
        fromEmail: currentAccount.email,
        to: toList,
        cc: ccList,
        bcc: bccList,
        subject: subject,
        textBody: body,
        htmlBody: htmlBody,
        attachments: attachments,
        extraHeaders: extraHeaders,
      );

      final encodedMessage = base64Url.encode(utf8.encode(message)).replaceAll('=', '');

      final response = await http
          .post(
            Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/send'),
            headers: {
              'Authorization': 'Bearer ${currentAccount.accessToken}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'raw': encodedMessage}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw Exception("Échec de l'envoi (${response.statusCode}) : ${response.body}");
      }

      // Gmail confirme l'acceptation avec un identifiant et le libellé SENT.
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final labels = (data['labelIds'] as List<dynamic>?)?.cast<String>() ?? const [];
        if (data['id'] == null || (labels.isNotEmpty && !labels.contains('SENT'))) {
          throw Exception("Réponse Gmail inattendue : ${response.body}");
        }
      } on FormatException {
        throw Exception("Réponse Gmail illisible : ${response.body}");
      }
    } catch (e) {
      await _historyStorage.add(SentEmailLog(
        id: _uuid.v4(),
        accountEmail: currentAccount.email,
        to: recipientForLog,
        subject: subject,
        sentAt: DateTime.now(),
        success: false,
        errorMessage: e.toString(),
      ));
      rethrow;
    }

    await _historyStorage.add(SentEmailLog(
      id: _uuid.v4(),
      accountEmail: currentAccount.email,
      to: recipientForLog,
      subject: subject,
      sentAt: DateTime.now(),
      success: true,
    ));
  }
}

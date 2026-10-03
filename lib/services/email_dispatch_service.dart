import '../models/email_account.dart';
import 'gmail_send_service.dart';
import 'mime_utils.dart';
import 'package:mailer/mailer.dart' show PersistentConnection;
import 'smtp_send_service.dart';

/// Point d'entrée unique pour envoyer un e-mail, quel que soit le
/// fournisseur du compte (Gmail via OAuth, ou tout autre fournisseur
/// via SMTP + mot de passe d'application).
class EmailDispatchService {
  final _gmailService = GmailSendService();
  final _smtpService = SmtpSendService();

  Future<PersistentConnection> openSmtpConnection(EmailAccount account) =>
      _smtpService.openConnection(account);

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
    PersistentConnection? smtpConnection,
    Map<String, String> extraHeaders = const {},
  }) {
    if (account.provider == 'gmail') {
      return _gmailService.sendEmail(
        account: account,
        to: to,
        subject: subject,
        body: body,
        htmlBody: htmlBody,
        cc: cc,
        bcc: bcc,
        attachmentPaths: attachmentPaths,
        preloadedAttachments: preloadedAttachments,
        extraHeaders: extraHeaders,
      );
    }
    return _smtpService.sendEmail(
      account: account,
      to: to,
      subject: subject,
      body: body,
      htmlBody: htmlBody,
      cc: cc,
      bcc: bcc,
      attachmentPaths: attachmentPaths,
      preloadedAttachments: preloadedAttachments,
      connection: smtpConnection,
      extraHeaders: extraHeaders,
    );
  }
}

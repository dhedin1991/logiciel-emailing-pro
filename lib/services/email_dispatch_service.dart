import '../models/email_account.dart';
import 'gmail_send_service.dart';
import 'smtp_send_service.dart';

/// Point d'entrée unique pour envoyer un e-mail, quel que soit le
/// fournisseur du compte (Gmail via OAuth, ou tout autre fournisseur
/// via SMTP + mot de passe d'application).
class EmailDispatchService {
  final _gmailService = GmailSendService();
  final _smtpService = SmtpSendService();

  Future<void> sendEmail({
    required EmailAccount account,
    required String to,
    required String subject,
    required String body,
    String? cc,
    String? bcc,
    List<String> attachmentPaths = const [],
  }) {
    if (account.provider == 'gmail') {
      return _gmailService.sendEmail(
        account: account,
        to: to,
        subject: subject,
        body: body,
        cc: cc,
        bcc: bcc,
        attachmentPaths: attachmentPaths,
      );
    }
    return _smtpService.sendEmail(
      account: account,
      to: to,
      subject: subject,
      body: body,
      cc: cc,
      bcc: bcc,
      attachmentPaths: attachmentPaths,
    );
  }
}

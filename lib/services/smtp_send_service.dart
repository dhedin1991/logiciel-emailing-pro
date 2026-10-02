import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:uuid/uuid.dart';
import '../models/email_account.dart';
import '../models/sent_email_log.dart';
import 'history_storage.dart';
import 'mime_utils.dart';

/// Fournisseurs SMTP courants pré-configurés (hôte + port).
class SmtpPreset {
  final String label;
  final String host;
  final int port;
  const SmtpPreset(this.label, this.host, this.port);
}

const smtpPresets = [
  SmtpPreset('GMX (gratuit — mot de passe normal)', 'mail.gmx.com', 587),
  SmtpPreset('Yahoo Mail (gratuit — mot de passe d\'application)', 'smtp.mail.yahoo.com', 465),
  SmtpPreset('AOL Mail (gratuit — mot de passe d\'application)', 'smtp.aol.com', 587),
  SmtpPreset('Zoho Mail (nécessite un plan payant, 1\$/mois)', 'smtp.zoho.com', 465),
  SmtpPreset('Autre (personnalisé)', '', 587),
];

class SmtpSendService {
  final _historyStorage = HistoryStorage();
  final _uuid = const Uuid();

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
  }) async {
    try {
      final toList = MimeUtils.parseAddresses(to, field: 'Destinataire');
      if (toList.isEmpty) throw const FormatException('Aucun destinataire.');
      final ccList = MimeUtils.parseAddresses(cc, field: 'Cc');
      final bccList = MimeUtils.parseAddresses(bcc, field: 'Cci');

      final smtpServer = SmtpServer(
        account.smtpHost!,
        port: account.smtpPort ?? 587,
        username: account.email,
        password: account.smtpPassword,
        ssl: account.smtpPort == 465,
      );

      final message = Message()
        ..from = Address(MimeUtils.cleanHeader(account.email),
            MimeUtils.cleanHeader(account.displayName ?? account.email))
        ..recipients.addAll(toList)
        ..ccRecipients.addAll(ccList)
        ..bccRecipients.addAll(bccList)
        ..subject = MimeUtils.cleanHeader(subject)
        ..text = body;
      if (htmlBody != null) message.html = htmlBody;
      for (final path in attachmentPaths) {
        message.attachments.add(FileAttachment(File(path)));
      }

      await send(message, smtpServer, timeout: const Duration(seconds: 60));
    } catch (e) {
      await _historyStorage.add(SentEmailLog(
        id: _uuid.v4(),
        accountEmail: account.email,
        to: to,
        subject: subject,
        sentAt: DateTime.now(),
        success: false,
        errorMessage: e.toString(),
      ));
      rethrow;
    }

    await _historyStorage.add(SentEmailLog(
      id: _uuid.v4(),
      accountEmail: account.email,
      to: to,
      subject: subject,
      sentAt: DateTime.now(),
      success: true,
    ));
  }
}

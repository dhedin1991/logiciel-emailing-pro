import 'package:flutter_test/flutter_test.dart';
import 'package:mailer/mailer.dart' show PersistentConnection;
import 'package:logiciel_emailing_pro/models/contact.dart';
import 'package:logiciel_emailing_pro/models/email_account.dart';
import 'package:logiciel_emailing_pro/models/queue_email_item.dart';
import 'package:logiciel_emailing_pro/services/bulk_send_queue_service.dart';
import 'package:logiciel_emailing_pro/services/email_dispatch_service.dart';
import 'package:logiciel_emailing_pro/services/mime_utils.dart';

class _FakeDispatch implements EmailDispatchService {
  final Set<String> failFor;
  final List<String> sentTo = [];
  Map<String, String> lastHeaders = {};

  _FakeDispatch({this.failFor = const {}});

  @override
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
  }) async {
    lastHeaders = extraHeaders;
    if (failFor.contains(to)) throw Exception('refusé');
    sentTo.add(to);
  }

  @override
  Future<PersistentConnection> openSmtpConnection(EmailAccount account) =>
      throw UnimplementedError();
}

List<Contact> _contacts() => [
      Contact(id: '1', name: 'A', email: 'a@x.fr'),
      Contact(id: '2', name: 'B', email: 'b@x.fr'),
      Contact(id: '3', name: 'C', email: 'c@x.fr'),
    ];

Future<void> _run(BulkSendQueueService q) => q.start(
      account: EmailAccount(email: 'moi@x.fr', provider: 'gmail'),
      subjectTemplate: 'Salut {{nom}}',
      bodyTemplate: 'Bonjour {{nom}}',
      signatureGetter: () => null,
      personalize: (t, i) => t.replaceAll('{{nom}}', i.name),
      attachmentPaths: const [],
    );

void main() {
  test('envoie à tous les destinataires, un par un', () async {
    final fake = _FakeDispatch();
    final q = BulkSendQueueService(dispatchService: fake);
    q.configure(contacts: _contacts(), minDelayMs: 0, maxDelayMs: 0, maxRetries: 0);
    await _run(q);
    expect(fake.sentTo, ['a@x.fr', 'b@x.fr', 'c@x.fr']);
    expect(q.sentCount, 3);
    expect(q.failedCount, 0);
    expect(q.isRunning, isFalse);
  });

  test('un échec n\'empêche pas les suivants et est compté', () async {
    final fake = _FakeDispatch(failFor: {'b@x.fr'});
    final q = BulkSendQueueService(dispatchService: fake);
    q.configure(contacts: _contacts(), minDelayMs: 0, maxDelayMs: 0, maxRetries: 0);
    await _run(q);
    expect(q.sentCount, 2);
    expect(q.failedCount, 1);
    expect(q.items[1].status, QueueItemStatus.failed);
  });

  test('l\'en-tête de désinscription est ajouté', () async {
    final fake = _FakeDispatch();
    final q = BulkSendQueueService(dispatchService: fake);
    q.configure(contacts: _contacts(), minDelayMs: 0, maxDelayMs: 0, maxRetries: 0);
    await _run(q);
    expect(fake.lastHeaders['List-Unsubscribe'], contains('moi@x.fr'));
  });

  test('relancer les échecs ne renvoie pas aux envoyés', () async {
    final fake = _FakeDispatch(failFor: {'b@x.fr'});
    final q = BulkSendQueueService(dispatchService: fake);
    q.configure(contacts: _contacts(), minDelayMs: 0, maxDelayMs: 0, maxRetries: 0);
    await _run(q);
    fake.sentTo.clear();
    await q.retryFailed();
    expect(fake.sentTo, isEmpty); // b échoue encore ; a et c ne sont pas renvoyés
  });

  test('quota horaire : pause quand le maximum est atteint', () async {
    final fake = _FakeDispatch();
    final q = BulkSendQueueService(dispatchService: fake);
    q.configure(contacts: _contacts(), minDelayMs: 0, maxDelayMs: 0, maxRetries: 0, maxPerHour: 1);
    final running = _run(q);
    await Future.delayed(const Duration(milliseconds: 500));
    expect(fake.sentTo.length, 1); // un seul envoi, puis pause
    expect(q.quotaWaitUntil, isNotNull);
    q.cancel();
    await running;
    expect(fake.sentTo.length, 1);
  });
}

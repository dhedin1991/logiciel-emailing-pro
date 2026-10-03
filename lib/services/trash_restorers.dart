import '../models/contact.dart';
import '../models/contact_list.dart';
import '../models/email_draft.dart';
import '../models/message_template.dart';
import '../models/scheduled_email.dart';
import '../models/sent_email_log.dart';
import '../models/signature.dart';
import '../models/snippet.dart';
import 'contact_list_storage.dart';
import 'contact_storage.dart';
import 'draft_storage.dart';
import 'history_storage.dart';
import 'scheduled_email_storage.dart';
import 'signature_storage.dart';
import 'snippet_storage.dart';
import 'template_storage.dart';
import 'trash_service.dart';

/// Branche la restauration de chaque type d'élément. À appeler une fois au démarrage.
void registerTrashRestorers() {
  final trash = TrashService.instance;

  trash.restorers['contact'] = (payloads) async {
    await ContactStorage().addContacts(payloads.map(Contact.fromJson).toList());
  };
  trash.restorers['contactList'] = (payloads) async {
    final storage = ContactListStorage();
    final existing = (await storage.loadAll()).map((l) => l.id).toSet();
    for (final p in payloads) {
      final list = ContactList.fromJson(p);
      if (!existing.contains(list.id)) await storage.add(list);
    }
  };
  trash.restorers['template'] = (payloads) async {
    final storage = TemplateStorage();
    final existing = (await storage.loadTemplates()).map((t) => t.id).toSet();
    for (final p in payloads) {
      final item = MessageTemplate.fromJson(p);
      if (!existing.contains(item.id)) await storage.addTemplate(item);
    }
  };
  trash.restorers['signature'] = (payloads) async {
    final storage = SignatureStorage();
    final existing = (await storage.loadSignatures()).map((s) => s.id).toSet();
    for (final p in payloads) {
      final item = Signature.fromJson(p);
      if (!existing.contains(item.id)) await storage.addSignature(item);
    }
  };
  trash.restorers['snippet'] = (payloads) async {
    final storage = SnippetStorage();
    final existing = (await storage.loadSnippets()).map((s) => s.id).toSet();
    for (final p in payloads) {
      final item = Snippet.fromJson(p);
      if (!existing.contains(item.id)) await storage.addSnippet(item);
    }
  };
  trash.restorers['scheduled'] = (payloads) async {
    final storage = ScheduledEmailStorage();
    final existing = (await storage.loadAll()).map((s) => s.id).toSet();
    for (final p in payloads) {
      final item = ScheduledEmail.fromJson(p);
      if (!existing.contains(item.id)) await storage.add(item);
    }
  };
  trash.restorers['draft'] = (payloads) async {
    final storage = DraftStorage();
    for (final p in payloads) {
      await storage.upsertDraft(EmailDraft.fromJson(p));
    }
  };
  trash.restorers['history'] = (payloads) async {
    final storage = HistoryStorage();
    for (final p in payloads) {
      await storage.add(SentEmailLog.fromJson(p));
    }
  };
}

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import '../widgets/rich_body_editor.dart';
import '../widgets/deliverability_help_dialog.dart';
import '../widgets/daily_send_counter.dart';
import '../services/campaign_recovery_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/contact.dart';
import '../models/contact_list.dart';
import '../models/email_account.dart';
import '../models/message_template.dart';
import '../models/scheduled_email.dart';
import '../models/signature.dart';
import '../services/account_storage.dart';
import '../services/contact_list_storage.dart';
import '../services/contact_storage.dart';
import '../services/email_dispatch_service.dart';
import '../services/scheduled_email_storage.dart';
import '../services/history_storage.dart';
import '../services/template_storage.dart';
import '../services/signature_storage.dart';
import '../services/signature_renderer.dart';
import '../services/bulk_send_queue_service.dart';
import '../services/send_jobs_manager.dart';
import '../services/draft_storage.dart';
import '../models/email_draft.dart';
import '../services/snippet_storage.dart';
import '../models/snippet.dart';
import '../services/compose_prefill.dart';
import '../services/log_service.dart';
import 'bulk_send_progress_panel.dart';
import 'email_preview_dialog.dart';
import 'message_analysis_dialog.dart';
import '../widgets/info_notice.dart';
import '../models/queue_email_item.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _accountStorage = AccountStorage();
  final _sendService = EmailDispatchService();
  final _templateStorage = TemplateStorage();
  final _signatureStorage = SignatureStorage();
  final _contactStorage = ContactStorage();
  final _contactListStorage = ContactListStorage();
  final _scheduledStorage = ScheduledEmailStorage();
  final _uuid = const Uuid();
  late String _draftId = const Uuid().v4();
  Timer? _autosaveTimer;

  final _toController = TextEditingController();
  final _ccController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  /// Éditeur riche : Windows uniquement. Android garde le champ texte
  /// habituel (structure inchangée). Le texte brut reste dans _bodyController
  /// (brouillons, analyse, personnalisation), la mise en forme dans _quill.
  final bool _rich = Platform.isWindows;
  late final QuillController _quill = QuillController.basic();
  bool _syncingBody = false;

  void _setBody(String text, {String? deltaJson}) {
    _syncingBody = true;
    _bodyController.text = text;
    if (_rich) {
      Document doc;
      try {
        if (deltaJson != null) {
          doc = Document.fromJson(jsonDecode(deltaJson) as List<dynamic>);
        } else {
          doc = Document();
          if (text.isNotEmpty) doc.insert(0, text);
        }
      } catch (_) {
        doc = Document();
        if (text.isNotEmpty) doc.insert(0, text);
      }
      _quill.document = doc;
      _quill.updateSelection(const TextSelection.collapsed(offset: 0), ChangeSource.local);
    }
    _syncingBody = false;
  }

  String? _currentDeltaJson() {
    if (!_rich) return null;
    try {
      return jsonEncode(_quill.document.toDelta().toJson());
    } catch (_) {
      return null;
    }
  }

  /// HTML du message mis en forme ; null s'il n'y a aucune mise en forme
  /// (le message part alors en texte simple, comme avant).
  String? _richHtml() {
    if (!_rich) return null;
    try {
      final ops = _quill.document.toDelta().toJson();
      final hasFormatting = ops.any((o) => o is Map && o['attributes'] != null);
      if (!hasFormatting) return null;
      final list = ops.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return QuillDeltaToHtmlConverter(list, ConverterOptions.forEmail()).convert();
    } catch (_) {
      return null;
    }
  }

  static const _fontSteps = <String?>['small', null, 'large', 'huge'];

  /// Change la taille du texte sélectionné d'un cran (petit, normal, grand, très grand).
  void _stepFontSize(int delta) {
    final current = _quill.getSelectionStyle().attributes[Attribute.size.key]?.value as String?;
    final index = _fontSteps.indexOf(current);
    final next = ((index < 0 ? 1 : index) + delta).clamp(0, _fontSteps.length - 1);
    final value = _fontSteps[next];
    _quill.formatSelection(value == null ? Attribute.clone(Attribute.size, null) : SizeAttribute(value));
  }

  /// Version HTML de la personnalisation : les valeurs insérées sont échappées.
  String _personalizeItemHtml(String text, QueueEmailItem item) => text
      .replaceAll('{{nom}}', escapeHtml(item.name))
      .replaceAll('{{email}}', escapeHtml(item.email))
      .replaceAll('{{entreprise}}', escapeHtml(item.company));

  List<EmailAccount> _accounts = [];
  EmailAccount? _selectedAccount;
  List<MessageTemplate> _templates = [];
  List<Signature> _signatures = [];
  Signature? _selectedSignature;
  List<Contact> _contacts = [];
  List<ContactList> _contactLists = [];
  final Set<String> _selectedContactIds = {};
  final List<String> _attachmentPaths = [];
  DateTime? _scheduledFor;
  String? _recurrence;

  bool _bulkMode = false;
  bool _loading = true;
  bool _sending = false;
  String? _statusMessage;
  bool _statusIsError = false;

  final _minDelayController = TextEditingController(text: '1500');
  final _maxDelayController = TextEditingController(text: '3000');
  final _retriesController = TextEditingController(text: '1');
  // Rythme prudent par défaut : 100 e-mails par heure et par compte (0 = illimité).
  int _counterTick = 0;
  Timer? _counterTimer;
  final _hourlyCapController = TextEditingController(text: '100');
  bool _randomDelay = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _counterTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _counterTick++);
    });
    _subjectController.addListener(_scheduleAutosave);
    _bodyController.addListener(_scheduleAutosave);
    if (_rich) {
      _quill.addListener(() {
        if (_syncingBody) return;
        var plain = _quill.document.toPlainText();
        if (plain.endsWith('\n')) plain = plain.substring(0, plain.length - 1);
        if (_bodyController.text != plain) {
          _syncingBody = true;
          _bodyController.text = plain;
          _syncingBody = false;
        }
        _scheduleAutosave(); // aussi pour un simple changement de mise en forme
      });
    }
  }

  /// Enregistrement automatique : un seul brouillon par message (même id),
  /// 3 secondes après la dernière frappe.
  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 3), _autosaveNow);
  }

  Future<void> _autosaveNow() async {
    final subject = _subjectController.text;
    final body = _bodyController.text;
    if (subject.trim().isEmpty && body.trim().isEmpty) return;
    await _draftStorage.upsertDraft(EmailDraft(
      id: _draftId,
      subject: subject,
      body: body,
      savedAt: DateTime.now(),
      deltaJson: _currentDeltaJson(),
    ));
  }

  /// Message envoyé ou programmé : son brouillon disparaît (sans passer par la corbeille).
  Future<void> _discardCurrentDraft() async {
    _autosaveTimer?.cancel();
    await _draftStorage.removeDraft(_draftId, toTrash: false);
    _draftId = const Uuid().v4();
  }

  Future<void> _loadData() async {
    final accounts = await _accountStorage.loadAccounts();
    final templates = await _templateStorage.loadTemplates();
    final signatures = await _signatureStorage.loadSignatures();
    final contacts = await _contactStorage.loadContacts();
    final contactLists = await _contactListStorage.loadAll();
    if (!mounted) return;
    final prefill = ComposePrefill.instance.consume();
    final draftToOpen = ComposePrefill.instance.consumeDraft();
    setState(() {
      _accounts = accounts;
      _selectedAccount = accounts.isNotEmpty ? accounts.first : null;
      _templates = templates;
      _signatures = signatures;
      _contacts = contacts;
      _contactLists = contactLists;
      _loading = false;
      if (draftToOpen != null) {
        _draftId = draftToOpen.id;
        _subjectController.text = draftToOpen.subject;
        _setBody(draftToOpen.body, deltaJson: draftToOpen.deltaJson);
      }
      // Contacts transmis depuis l'écran Contacts (bouton "Rédiger") :
      // on bascule automatiquement en mode envoi multiple et on les
      // pré-sélectionne, pour éviter tout copier-coller manuel.
      if (prefill != null && prefill.isNotEmpty) {
        _bulkMode = true;
        _selectedContactIds
          ..clear()
          ..addAll(prefill.map((c) => c.id));
      }
    });
  }

  void _applyContactList(ContactList list) {
    setState(() {
      _selectedContactIds
        ..clear()
        ..addAll(list.contactIds);
    });
  }

  Future<void> _pickContactsForTo() async {
    final selected = <String>{};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choisir des contacts'),
          content: SizedBox(
            width: 450,
            child: _contacts.isEmpty
                ? const Text('Aucun contact. Ajoutez-en dans l\'onglet Contacts.')
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 350),
                    child: ListView(
                      shrinkWrap: true,
                      children: _contacts
                          .map((c) => CheckboxListTile(
                                dense: true,
                                title: Text(c.name),
                                subtitle: Text(c.email),
                                value: selected.contains(c.email),
                                onChanged: (checked) => setDialogState(() {
                                  if (checked == true) {
                                    selected.add(c.email);
                                  } else {
                                    selected.remove(c.email);
                                  }
                                }),
                              ))
                          .toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, selected), child: const Text('Ajouter')),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (!mounted) return;
      final existing = _toController.text.trim();
      final joined = result.join(', ');
      setState(() {
        _toController.text = existing.isEmpty ? joined : '$existing, $joined';
      });
    }
  }

  void _applyTemplate(MessageTemplate template) {
    setState(() {
      _subjectController.text = template.subject;
      _setBody(template.body);
    });
  }

  final _draftStorage = DraftStorage();
  final _snippetStorage = SnippetStorage();

  Future<void> _saveDraft() async {
    if (_subjectController.text.trim().isEmpty && _bodyController.text.trim().isEmpty) return;
    _autosaveTimer?.cancel();
    await _autosaveNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brouillon enregistré.')));
  }

  Future<void> _openDrafts() async {
    final drafts = await _draftStorage.loadDrafts();
    if (!mounted) return;
    if (drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun brouillon enregistré.')));
      return;
    }
    final selected = await showDialog<EmailDraft>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Brouillons'),
        content: SizedBox(
          width: 450,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final d = drafts[index];
              return ListTile(
                title: Text(d.subject.isEmpty ? '(sans objet)' : d.subject),
                subtitle: Text(
                  '${d.savedAt.day}/${d.savedAt.month}/${d.savedAt.year} ${d.savedAt.hour.toString().padLeft(2, '0')}:${d.savedAt.minute.toString().padLeft(2, '0')}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Supprimer ce brouillon',
                  onPressed: () async {
                    await _draftStorage.removeDraft(d.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                onTap: () => Navigator.pop(context, d),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _draftId = selected.id;
        _subjectController.text = selected.subject;
        _setBody(selected.body, deltaJson: selected.deltaJson);
      });
    }
  }

  void _insertSnippet(Snippet snippet) {
    if (_rich) {
      final sel = _quill.selection;
      final maxIndex = _quill.document.length - 1;
      final start = sel.start.clamp(0, maxIndex);
      final end = sel.end.clamp(start, maxIndex);
      _quill.replaceText(start, end - start, snippet.content,
          TextSelection.collapsed(offset: start + snippet.content.length));
      return;
    }
    final controller = _bodyController;
    final selection = controller.selection;
    final text = controller.text;
    final insertAt = selection.isValid ? selection.start : text.length;
    final newText = text.replaceRange(insertAt, selection.isValid ? selection.end : text.length, snippet.content);
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: insertAt + snippet.content.length);
  }

  Future<void> _openSnippets() async {
    final snippets = await _snippetStorage.loadSnippets();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Textes courts'),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (snippets.isEmpty) const Text('Aucun texte court enregistré pour le moment.'),
                  ...snippets.map((s) => ListTile(
                        title: Text(s.label),
                        subtitle: Text(s.content, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () {
                                _insertSnippet(s);
                                Navigator.pop(context);
                              },
                              child: const Text('Insérer'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () async {
                                await _snippetStorage.removeSnippet(s.id);
                                snippets.removeWhere((x) => x.id == s.id);
                                setDialogState(() {});
                              },
                            ),
                          ],
                        ),
                      )),
                  const Divider(),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final labelController = TextEditingController();
                      final contentController = TextEditingController();
                      final added = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Nouveau texte court'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(controller: labelController, decoration: const InputDecoration(labelText: 'Nom (ex : Formule de politesse)')),
                              TextField(controller: contentController, decoration: const InputDecoration(labelText: 'Texte'), maxLines: 3),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ajouter')),
                          ],
                        ),
                      );
                      if (added == true && labelController.text.trim().isNotEmpty) {
                        final snippet = Snippet(id: const Uuid().v4(), label: labelController.text.trim(), content: contentController.text);
                        await _snippetStorage.addSnippet(snippet);
                        snippets.add(snippet);
                        setDialogState(() {});
                      }
                      labelController.dispose();
                      contentController.dispose();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un texte court'),
                  ),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
          );
        },
      ),
    );
  }

  /// Remplace les variables de personnalisation ({{nom}}, {{email}},
  /// {{entreprise}}) par les informations du destinataire.
  String _personalizeItem(String text, QueueEmailItem item) {
    return text
        .replaceAll('{{nom}}', item.name)
        .replaceAll('{{email}}', item.email)
        .replaceAll('{{entreprise}}', item.company.isEmpty ? '' : item.company);
  }

  /// Utilisé pour l'aperçu avant envoi (un seul contact).
  String _personalize(String text, Contact contact) {
    return text
        .replaceAll('{{nom}}', contact.name)
        .replaceAll('{{email}}', contact.email)
        .replaceAll('{{entreprise}}', contact.company);
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || !mounted) return;
    setState(() {
      for (final file in result.files) {
        if (file.path != null && !_attachmentPaths.contains(file.path)) {
          _attachmentPaths.add(file.path!);
        }
      }
    });
  }

  void _removeAttachment(String path) {
    setState(() => _attachmentPaths.remove(path));
  }

  Future<void> _pickScheduleDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(minutes: 5)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 5))),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledFor = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _scheduleSingle() async {
    if (_toController.text.trim().isEmpty || _scheduledFor == null || _selectedAccount == null) {
      return;
    }
    setState(() => _sending = true);
    try {
      await _scheduledStorage.add(ScheduledEmail(
        id: _uuid.v4(),
        accountEmail: _selectedAccount!.email,
        to: _toController.text.trim(),
        cc: _ccController.text.trim(),
        subject: _subjectController.text.trim(),
        body: composeBody(_bodyController.text, _selectedSignature, bodyHtml: _richHtml()).text,
        htmlBody: composeBody(_bodyController.text, _selectedSignature, bodyHtml: _richHtml()).html,
        attachmentPaths: List.of(_attachmentPaths),
        sendAt: _scheduledFor!,
        recurrence: _recurrence,
      ));
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Envoi programmé pour le '
            '${_scheduledFor!.day}/${_scheduledFor!.month}/${_scheduledFor!.year} à '
            '${_scheduledFor!.hour.toString().padLeft(2, '0')}:${_scheduledFor!.minute.toString().padLeft(2, '0')}.';
        _statusIsError = false;
        _toController.clear();
        _ccController.clear();
        _subjectController.clear();
        _setBody('');
        _attachmentPaths.clear();
        _scheduledFor = null;
        _recurrence = null;
      });
      await _discardCurrentDraft();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _send() async {
    if (_selectedAccount == null) return;

    if (_bulkMode) {
      await _sendBulk();
    } else if (_scheduledFor != null) {
      await _scheduleSingle();
    } else {
      await _sendSingle();
    }
  }

  Future<void> _showPreviewThenSend() async {
    if (_selectedAccount == null) {
      setState(() {
        _statusMessage = 'Sélectionnez un compte expéditeur avant d\'envoyer.';
        _statusIsError = true;
      });
      return;
    }
    if (_subjectController.text.trim().isEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Objet vide'),
          content: const Text('Le message n\'a pas d\'objet. Envoyer quand même ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Envoyer quand même')),
          ],
        ),
      );
      if (proceed != true) return;
    }
    if (_bodyController.text.trim().isEmpty) {
      setState(() {
        _statusMessage = 'Le message est vide — ajoutez du texte avant d\'envoyer.';
        _statusIsError = true;
      });
      return;
    }
    if (_bulkMode) {
      final recipients = _contacts.where((c) => _selectedContactIds.contains(c.id)).toList();
      final emailCounts = <String, int>{};
      for (final c in recipients) {
        final key = c.email.toLowerCase();
        emailCounts[key] = (emailCounts[key] ?? 0) + 1;
      }
      final duplicates = emailCounts.entries.where((e) => e.value > 1).map((e) => e.key).toList();
      if (duplicates.isNotEmpty) {
        setState(() {
          _statusMessage = 'Adresse(s) en double dans la sélection : ${duplicates.join(', ')}';
          _statusIsError = true;
        });
        return;
      }
    }
    var previewSubject = _subjectController.text;
    var previewBody = _bodyController.text;
    var toDisplay = _toController.text;
    if (_bulkMode) {
      final selected = _contacts.where((c) => _selectedContactIds.contains(c.id)).toList();
      final excluded = selected.where(_isUnsubscribed).length;
      toDisplay = '${selected.length - excluded} destinataire(s)'
          '${excluded > 0 ? ' ($excluded « Ne plus contacter » exclu(s))' : ''}';
      // Aperçu tel que le recevra le premier destinataire ({{nom}}, {{email}}, {{entreprise}} remplacés).
      final first = selected.where((c) => !_isUnsubscribed(c)).firstOrNull;
      if (first != null) {
        previewSubject = _personalize(previewSubject, first);
        previewBody = _personalize(previewBody, first);
        toDisplay += ' — aperçu pour : ${first.name.isEmpty ? first.email : first.name}';
      }
    }
    final bodyWithSignature = composeBody(previewBody, _selectedSignature).text;
    final confirmed = await showEmailPreviewDialog(
      context,
      from: _selectedAccount!.email,
      to: toDisplay,
      cc: _bulkMode ? null : _ccController.text,
      subject: previewSubject,
      body: bodyWithSignature,
      attachmentPaths: _bulkMode ? const [] : List.of(_attachmentPaths),
    );
    if (confirmed && mounted) {
      await _send();
    }
  }

  /// Contact à ne plus solliciter (statut ou étiquette « Ne plus contacter »).
  bool _isUnsubscribed(Contact c) =>
      c.status == 'Ne plus contacter' || c.tags.contains('Ne plus contacter');

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _invalidEmailsIn(String rawList) {
    final addresses = rawList.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    final invalid = addresses.where((e) => !_emailRegex.hasMatch(e)).toList();
    return invalid.isEmpty ? null : invalid.join(', ');
  }

  Future<void> _sendSingle() async {
    if (_toController.text.trim().isEmpty) {
      setState(() {
        _statusMessage = 'Indiquez au moins un destinataire.';
        _statusIsError = true;
      });
      return;
    }

    final invalid = _invalidEmailsIn(_toController.text);
    if (invalid != null) {
      setState(() {
        _statusMessage = 'Adresse(s) invalide(s) : $invalid';
        _statusIsError = true;
      });
      return;
    }

    setState(() {
      _sending = true;
      _statusMessage = null;
    });

    try {
      final recipientForLog = _toController.text.trim();
      final composed = composeBody(_bodyController.text, _selectedSignature, bodyHtml: _richHtml());
      await _sendService.sendEmail(
        account: _selectedAccount!,
        to: _toController.text.trim(),
        cc: _ccController.text.trim(),
        subject: _subjectController.text.trim(),
        body: composed.text,
        htmlBody: composed.html,
        attachmentPaths: List.of(_attachmentPaths),
      );
      if (!mounted) return;
      setState(() {
        _statusMessage = 'E-mail envoyé avec succès.';
        _statusIsError = false;
        _toController.clear();
        _ccController.clear();
        _subjectController.clear();
        _setBody('');
        _attachmentPaths.clear();
      });
      await _discardCurrentDraft();
      if (mounted) setState(() => _counterTick++);
      await LogService().log('Envoi simple réussi vers $recipientForLog, compte ${_selectedAccount?.email}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = "Échec de l'envoi : ${e.toString()}";
        _statusIsError = true;
      });
      await LogService().log('Échec envoi simple, compte ${_selectedAccount?.email} : ${e.toString()}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendBulk() async {
    final recipients = _contacts.where((c) => _selectedContactIds.contains(c.id)).toList();
    // Les contacts « Ne plus contacter » ne reçoivent jamais d'envoi en masse.
    final excludedCount = recipients.where(_isUnsubscribed).length;
    recipients.removeWhere(_isUnsubscribed);
    if (excludedCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$excludedCount contact(s) « Ne plus contacter » exclu(s) de l\'envoi.'),
        duration: const Duration(seconds: 4),
      ));
    }
    if (recipients.isEmpty) {
      setState(() {
        _statusMessage = 'Sélectionnez au moins un contact.';
        _statusIsError = true;
      });
      return;
    }

    final invalidEmails = recipients.where((c) => !_emailRegex.hasMatch(c.email)).toList();
    if (invalidEmails.isNotEmpty) {
      setState(() {
        _statusMessage = 'Adresse(s) invalide(s) dans la sélection : ${invalidEmails.map((c) => c.email).join(', ')}';
        _statusIsError = true;
      });
      return;
    }

    if (_selectedAccount!.provider == 'gmail') {
      final sentTodayByThisAccount =
          await HistoryStorage().countSuccessToday(_selectedAccount!.email);
      final projectedTotal = sentTodayByThisAccount + recipients.length;
      if (projectedTotal > 450) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Limite Gmail'),
            content: Text(
              'Ce compte a déjà envoyé $sentTodayByThisAccount e-mail(s) aujourd\'hui. Avec cet envoi de '
              '${recipients.length}, le total atteindrait $projectedTotal, proche ou au-delà de la limite '
              'Gmail (environ 500/jour), ce qui peut faire bloquer temporairement le compte Google. '
              'Continuer quand même ?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuer')),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    final minDelay = int.tryParse(_minDelayController.text.trim()) ?? 1500;
    final maxDelay = _randomDelay ? (int.tryParse(_maxDelayController.text.trim()) ?? minDelay) : minDelay;
    final retries = int.tryParse(_retriesController.text.trim()) ?? 1;
    final hourlyCap = (int.tryParse(_hourlyCapController.text.trim()) ?? 100).clamp(0, 100000);

    final queue = BulkSendQueueService();
    queue.configure(contacts: recipients, minDelayMs: minDelay, maxDelayMs: maxDelay, maxRetries: retries, maxPerHour: hourlyCap);

    final account = _selectedAccount!;
    final subjectTemplate = _subjectController.text;
    final bodyTemplate = _bodyController.text;
    final htmlTemplate = _richHtml();
    final signature = _selectedSignature;
    final attachments = List.of(_attachmentPaths);

    SendJobsManager.instance.addJob(SendJob(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: '${account.email} — ${recipients.length} destinataire(s)',
      queue: queue,
      startedAt: DateTime.now(),
    ));

    // Lancé en arrière-plan : ne bloque pas l'écran, l'utilisateur peut
    // continuer à utiliser l'application (autre rédaction, autre compte...)
    // pendant que cette campagne avance, un e-mail à la fois.
    await CampaignRecoveryService.save(CampaignState(
      accountEmail: account.email,
      subjectTemplate: subjectTemplate,
      bodyTemplate: bodyTemplate,
      htmlBodyTemplate: htmlTemplate,
      signatureId: signature?.id,
      attachmentPaths: attachments,
      minDelayMs: minDelay,
      maxDelayMs: maxDelay,
      maxRetries: retries,
      maxPerHour: hourlyCap,
      totalCount: recipients.length,
      remainingContactIds: recipients.map((c) => c.id).toList(),
      startedAt: DateTime.now(),
    ));

    unawaited(queue.start(
      account: account,
      subjectTemplate: subjectTemplate,
      bodyTemplate: bodyTemplate,
      signatureGetter: () => signature,
      personalize: (template, item) => _personalizeItem(template, item),
      attachmentPaths: attachments,
      htmlBodyTemplate: htmlTemplate,
      personalizeHtml: (template, item) => _personalizeItemHtml(template, item),
      onProgress: CampaignRecoveryService.updateProgress,
    ).whenComplete(CampaignRecoveryService.clear));

    if (!mounted) return;
    // Ouvre directement la fenêtre de suivi complète (statuts détaillés,
    // onglets Destinataires/Journal) au lieu d'un simple message furtif :
    // l'utilisateur voit tout de suite ce qui est en train d'être envoyé.
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => BulkSendProgressPanel(queue: queue),
    );

    setState(() {
      _selectedContactIds.clear();
      _subjectController.clear();
      _setBody('');
      _attachmentPaths.clear();
    });
    await _discardCurrentDraft();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    final pendingSubject = _subjectController.text;
    final pendingBody = _bodyController.text;
    if (pendingSubject.trim().isNotEmpty || pendingBody.trim().isNotEmpty) {
      // On quitte l'écran en cours de rédaction : le brouillon est conservé.
      unawaited(_draftStorage.upsertDraft(EmailDraft(
        id: _draftId,
        subject: pendingSubject,
        body: pendingBody,
        savedAt: DateTime.now(),
        deltaJson: _currentDeltaJson(),
      )));
    }
    _toController.dispose();
    _ccController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    _quill.dispose();
    _minDelayController.dispose();
    _maxDelayController.dispose();
    _retriesController.dispose();
    _hourlyCapController.dispose();
    _counterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_accounts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Connectez d\'abord un compte Gmail dans Paramètres avant de pouvoir envoyer un e-mail.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final scrollView = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      // Windows : cadre large (jusqu'à 1100 px) et centré. Android : inchangé (700 px).
      child: Align(
        alignment: _rich ? Alignment.topCenter : Alignment.topLeft,
        child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _rich ? 1100 : 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_bulkMode ? 'Envoi en masse' : 'Nouveau message',
                      style: Theme.of(context).textTheme.headlineSmall),
                ),
                const Text('Envoi à plusieurs destinataires'),
                Switch(
                  value: _bulkMode,
                  onChanged: (value) => setState(() {
                    _bulkMode = value;
                    _statusMessage = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<EmailAccount>(
              initialValue: _selectedAccount,
              decoration: const InputDecoration(labelText: 'Expéditeur', border: OutlineInputBorder()),
              items: _accounts.map((a) => DropdownMenuItem(value: a, child: Text(a.email))).toList(),
              onChanged: (value) => setState(() {
                _selectedAccount = value;
                if (value?.defaultSignatureId != null) {
                  for (final s in _signatures) {
                    if (s.id == value!.defaultSignatureId) {
                      _selectedSignature = s;
                      break;
                    }
                  }
                }
              }),
            ),
            if (_selectedAccount != null)
              DailySendCounter(account: _selectedAccount!, refreshTick: _counterTick),
            const SizedBox(height: 12),
            if (_bulkMode) ...[
              InfoNotice(
                title: 'Conseils pour un envoi en masse fiable',
                bullets: [
                  'Personnalisez le contenu avec {{nom}}, {{email}} ou {{entreprise}} — remplacés automatiquement pour chaque destinataire.',
                  if (_selectedAccount?.provider == 'gmail')
                    'Gmail gratuit : limite officielle de 500 e-mails/jour, mais restez idéalement sous 100 à 150/jour pour préserver la réputation du compte.',
                  'Espacez les envois (délai réglable ci-dessous) plutôt que d\'envoyer tout d\'un coup.',
                  'Pour un gros volume, répartissez entre plusieurs comptes connectés plutôt que de pousser un seul compte à sa limite.',
                  'Après l\'envoi, vérifiez le taux d\'échec dans l\'Historique — un taux élevé est un signal d\'alerte à prendre au sérieux.',
                ],
              ),
              const SizedBox(height: 12),
              if (_contactLists.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<ContactList>(
                    initialValue: null,
                    decoration: const InputDecoration(labelText: 'Utiliser une liste prédéfinie', border: OutlineInputBorder()),
                    items: _contactLists.map((l) => DropdownMenuItem(value: l, child: Text('${l.name} (${l.contactIds.length})'))).toList(),
                    onChanged: (value) {
                      if (value != null) _applyContactList(value);
                    },
                  ),
                ),
              Text('Destinataires (${_selectedContactIds.length} sélectionné(s))',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_contacts.isEmpty)
                const Text('Aucun contact. Ajoutez-en dans l\'onglet Contacts.')
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
                  child: ListView(
                    shrinkWrap: true,
                    children: _contacts
                        .map((c) => CheckboxListTile(
                              dense: true,
                              title: Text(c.name),
                              subtitle: Text(c.email),
                              value: _selectedContactIds.contains(c.id),
                              onChanged: (checked) => setState(() {
                                if (checked == true) {
                                  _selectedContactIds.add(c.id);
                                } else {
                                  _selectedContactIds.remove(c.id);
                                }
                              }),
                            ))
                        .toList(),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Astuce : utilisez {{nom}} dans l\'objet ou le message pour insérer automatiquement le nom de chaque contact.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Text('Réglages d\'envoi', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minDelayController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _randomDelay ? 'Délai minimum (ms)' : 'Délai entre envois (ms)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  if (_randomDelay) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maxDelayController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Délai maximum (ms)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _retriesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tentatives en cas d\'échec', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _hourlyCapController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum d\'e-mails par heure (0 = illimité)',
                  helperText: 'Recommandé : 100 par heure, surtout avec un compte récent. '
                      'La campagne se met en pause toute seule puis reprend.',
                  border: OutlineInputBorder(),
                ),
              ),
              TextButton.icon(
                onPressed: _selectedAccount == null
                    ? null
                    : () => showDeliverabilityHelp(context, _selectedAccount!),
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Conseils de délivrabilité (SPF, DKIM, DMARC)'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Délai aléatoire (rythme plus naturel)'),
                value: _randomDelay,
                onChanged: (value) => setState(() => _randomDelay = value),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _toController,
                      decoration: const InputDecoration(
                        labelText: 'À (destinataire)',
                        hintText: 'exemple@domaine.com, autre@domaine.com',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _pickContactsForTo,
                    icon: const Icon(Icons.contacts_outlined),
                    tooltip: 'Choisir dans les contacts',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ccController,
                decoration: const InputDecoration(labelText: 'Copie (Cc) — facultatif', border: OutlineInputBorder()),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Objet', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_templates.isNotEmpty)
                  Expanded(
                    child: DropdownButtonFormField<MessageTemplate>(
                      initialValue: null,
                      decoration: const InputDecoration(labelText: 'Utiliser un modèle', border: OutlineInputBorder()),
                      items: _templates.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                      onChanged: (value) {
                        if (value != null) _applyTemplate(value);
                      },
                    ),
                  ),
                if (_templates.isNotEmpty && _signatures.isNotEmpty) const SizedBox(width: 12),
                if (_signatures.isNotEmpty)
                  Expanded(
                    child: DropdownButtonFormField<Signature>(
                      initialValue: _selectedSignature,
                      decoration: const InputDecoration(labelText: 'Signature', border: OutlineInputBorder()),
                      items: _signatures.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                      onChanged: (value) => setState(() => _selectedSignature = value),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_rich)
              RichBodyEditor(
                controller: _quill,
                height: (MediaQuery.of(context).size.height * 0.42).clamp(300.0, 640.0),
              )
            else
              TextField(
                controller: _bodyController,
                decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
                maxLines: 10,
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showMessageAnalysisDialog(
                context,
                subject: _subjectController.text,
                body: _bodyController.text,
              ),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Analyser le message (orthographe, qualité, spam)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openSnippets,
              icon: const Icon(Icons.short_text),
              label: const Text('Textes courts'),
            ),
            const SizedBox(height: 12),
            if (!_bulkMode) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickAttachments,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Joindre un fichier'),
                  ),
                  ..._attachmentPaths.map((path) => Chip(
                        label: Text(path.split('/').last.split('\\').last),
                        onDeleted: () => _removeAttachment(path),
                      )),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickScheduleDateTime,
                    icon: const Icon(Icons.schedule),
                    label: Text(_scheduledFor == null
                        ? 'Programmer l\'envoi'
                        : '${_scheduledFor!.day}/${_scheduledFor!.month} à '
                            '${_scheduledFor!.hour.toString().padLeft(2, '0')}:${_scheduledFor!.minute.toString().padLeft(2, '0')}'),
                  ),
                  if (_scheduledFor != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Annuler la programmation',
                      onPressed: () => setState(() {
                        _scheduledFor = null;
                        _recurrence = null;
                      }),
                    ),
                ],
              ),
              if (_scheduledFor != null) ...[
                const SizedBox(height: 8),
                DropdownButton<String?>(
                  value: _recurrence,
                  hint: const Text('Envoi unique'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Envoi unique')),
                    DropdownMenuItem(value: 'daily', child: Text('Se répète tous les jours')),
                    DropdownMenuItem(value: 'weekly', child: Text('Se répète toutes les semaines')),
                    DropdownMenuItem(value: 'monthly', child: Text('Se répète tous les mois')),
                  ],
                  onChanged: (value) => setState(() => _recurrence = value),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'L\'envoi programmé se déclenche automatiquement tant que l\'application reste ouverte à l\'heure prévue.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 16),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_statusMessage!, style: TextStyle(color: _statusIsError ? Colors.red : Colors.green)),
              ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _showPreviewThenSend,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                    label: Text(_sending
                        ? (_scheduledFor != null ? 'Programmation…' : 'Envoi en cours…')
                        : (_bulkMode
                            ? 'Envoyer à tous'
                            : (_scheduledFor != null ? 'Programmer l\'envoi' : 'Envoyer'))),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _saveDraft,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Brouillon'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _openDrafts,
                  icon: const Icon(Icons.drafts_outlined),
                  label: const Text('Charger'),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );

    if (!_rich) return scrollView;

    // Raccourcis clavier Windows (Ctrl+B/I/U/K/Z/Y/A/C/X/V sont gérés par l'éditeur).
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (!_sending) _showPreviewThenSend();
        },
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
          if (!_sending) _showPreviewThenSend();
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _saveDraft,
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): _openDrafts,
        // Ctrl+N : nouveau message (le brouillon en cours est conservé automatiquement).
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () async {
          await _autosaveNow();
          if (!mounted) return;
          setState(() {
            _draftId = const Uuid().v4();
            _subjectController.clear();
            _setBody('');
          });
        },
        // Ctrl+Maj+V : coller sans mise en forme.
        const SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true): () async {
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          final text = data?.text;
          if (text == null || text.isEmpty) return;
          final sel = _quill.selection;
          final maxIndex = _quill.document.length - 1;
          final start = sel.start.clamp(0, maxIndex);
          final end = sel.end.clamp(start, maxIndex);
          _quill.replaceText(start, end - start, text, TextSelection.collapsed(offset: start + text.length));
        },
        // Ctrl+Maj+> / < : agrandir / réduire la taille du texte sélectionné.
        const SingleActivator(LogicalKeyboardKey.greater, control: true, shift: true): () => _stepFontSize(1),
        const SingleActivator(LogicalKeyboardKey.less, control: true, shift: true): () => _stepFontSize(-1),
        const SingleActivator(LogicalKeyboardKey.period, control: true, shift: true): () => _stepFontSize(1),
        const SingleActivator(LogicalKeyboardKey.comma, control: true, shift: true): () => _stepFontSize(-1),
        // Ctrl+Maj+7 / 8 : liste numérotée / à puces.
        const SingleActivator(LogicalKeyboardKey.digit7, control: true, shift: true): () =>
            _quill.formatSelection(_quill.getSelectionStyle().attributes.containsKey('list') &&
                    _quill.getSelectionStyle().attributes['list']?.value == 'ordered'
                ? Attribute.clone(Attribute.ol, null)
                : Attribute.ol),
        const SingleActivator(LogicalKeyboardKey.digit8, control: true, shift: true): () =>
            _quill.formatSelection(_quill.getSelectionStyle().attributes.containsKey('list') &&
                    _quill.getSelectionStyle().attributes['list']?.value == 'bullet'
                ? Attribute.clone(Attribute.ul, null)
                : Attribute.ul),
      },
      child: scrollView,
    );
  }
}

import 'dart:async';
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
import '../services/template_storage.dart';
import '../services/signature_storage.dart';
import '../services/bulk_send_queue_service.dart';
import '../services/send_jobs_manager.dart';
import '../services/draft_storage.dart';
import '../models/email_draft.dart';
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

  final _toController = TextEditingController();
  final _ccController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

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
  bool _randomDelay = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final accounts = await _accountStorage.loadAccounts();
    final templates = await _templateStorage.loadTemplates();
    final signatures = await _signatureStorage.loadSignatures();
    final contacts = await _contactStorage.loadContacts();
    final contactLists = await _contactListStorage.loadAll();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _selectedAccount = accounts.isNotEmpty ? accounts.first : null;
      _templates = templates;
      _signatures = signatures;
      _contacts = contacts;
      _contactLists = contactLists;
      _loading = false;
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
      _bodyController.text = template.body;
    });
  }

  final _draftStorage = DraftStorage();

  Future<void> _saveDraft() async {
    if (_subjectController.text.trim().isEmpty && _bodyController.text.trim().isEmpty) return;
    await _draftStorage.addDraft(EmailDraft(
      id: const Uuid().v4(),
      subject: _subjectController.text,
      body: _bodyController.text,
      savedAt: DateTime.now(),
    ));
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
        _subjectController.text = selected.subject;
        _bodyController.text = selected.body;
      });
    }
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
        body: _selectedSignature != null
            ? '${_bodyController.text}\n\n${_selectedSignature!.content}'
            : _bodyController.text,
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
        _bodyController.clear();
        _attachmentPaths.clear();
        _scheduledFor = null;
        _recurrence = null;
      });
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
    if (_selectedAccount == null) return;
    final bodyWithSignature = _selectedSignature != null
        ? '${_bodyController.text}\n\n${_selectedSignature!.content}'
        : _bodyController.text;
    final toDisplay = _bulkMode
        ? '${_selectedContactIds.length} destinataire(s) sélectionné(s)'
        : _toController.text;
    final confirmed = await showEmailPreviewDialog(
      context,
      from: _selectedAccount!.email,
      to: toDisplay,
      cc: _bulkMode ? null : _ccController.text,
      subject: _subjectController.text,
      body: bodyWithSignature,
      attachmentPaths: _bulkMode ? const [] : List.of(_attachmentPaths),
    );
    if (confirmed && mounted) {
      await _send();
    }
  }

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
      final bodyWithSignature = _selectedSignature != null
          ? '${_bodyController.text}\n\n${_selectedSignature!.content}'
          : _bodyController.text;
      await _sendService.sendEmail(
        account: _selectedAccount!,
        to: _toController.text.trim(),
        cc: _ccController.text.trim(),
        subject: _subjectController.text.trim(),
        body: bodyWithSignature,
        attachmentPaths: List.of(_attachmentPaths),
      );
      if (!mounted) return;
      setState(() {
        _statusMessage = 'E-mail envoyé avec succès.';
        _statusIsError = false;
        _toController.clear();
        _ccController.clear();
        _subjectController.clear();
        _bodyController.clear();
        _attachmentPaths.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = "Échec de l'envoi : ${e.toString()}";
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendBulk() async {
    final recipients = _contacts.where((c) => _selectedContactIds.contains(c.id)).toList();
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

    if (_selectedAccount!.provider == 'gmail' && recipients.length > 450) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Limite Gmail'),
          content: Text(
            'Gmail limite les comptes gratuits à environ 500 e-mails/jour. '
            'Vous êtes sur le point d\'en envoyer ${recipients.length}, ce qui peut faire bloquer temporairement votre compte Google. '
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

    final minDelay = int.tryParse(_minDelayController.text.trim()) ?? 1500;
    final maxDelay = _randomDelay ? (int.tryParse(_maxDelayController.text.trim()) ?? minDelay) : minDelay;
    final retries = int.tryParse(_retriesController.text.trim()) ?? 1;

    final queue = BulkSendQueueService();
    queue.configure(contacts: recipients, minDelayMs: minDelay, maxDelayMs: maxDelay, maxRetries: retries);

    final account = _selectedAccount!;
    final subjectTemplate = _subjectController.text;
    final bodyTemplate = _bodyController.text;
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
    unawaited(queue.start(
      account: account,
      subjectTemplate: subjectTemplate,
      bodyTemplate: bodyTemplate,
      signatureGetter: () => signature,
      personalize: (template, item) => _personalizeItem(template, item),
      attachmentPaths: attachments,
    ));

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
      _bodyController.clear();
      _attachmentPaths.clear();
    });
  }

  @override
  void dispose() {
    _toController.dispose();
    _ccController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    _minDelayController.dispose();
    _maxDelayController.dispose();
    _retriesController.dispose();
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
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
              onChanged: (value) => setState(() => _selectedAccount = value),
            ),
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
    );
  }
}

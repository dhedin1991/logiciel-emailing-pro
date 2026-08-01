import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/email_account.dart';
import '../models/message_template.dart';
import '../models/signature.dart';
import '../services/account_storage.dart';
import '../services/contact_storage.dart';
import '../services/gmail_send_service.dart';
import '../services/template_storage.dart';
import '../services/signature_storage.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _accountStorage = AccountStorage();
  final _sendService = GmailSendService();
  final _templateStorage = TemplateStorage();
  final _signatureStorage = SignatureStorage();
  final _contactStorage = ContactStorage();

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
  final Set<String> _selectedContactIds = {};

  bool _bulkMode = false;
  bool _loading = true;
  bool _sending = false;
  String? _statusMessage;
  bool _statusIsError = false;
  double _bulkProgress = 0;
  int _bulkTotal = 0;

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
    setState(() {
      _accounts = accounts;
      _selectedAccount = accounts.isNotEmpty ? accounts.first : null;
      _templates = templates;
      _signatures = signatures;
      _contacts = contacts;
      _loading = false;
    });
  }

  void _applyTemplate(MessageTemplate template) {
    setState(() {
      _subjectController.text = template.subject;
      _bodyController.text = template.body;
    });
  }

  /// Remplace {{nom}} par le nom du contact dans un texte.
  String _personalize(String text, Contact contact) {
    return text.replaceAll('{{nom}}', contact.name);
  }

  Future<void> _send() async {
    if (_selectedAccount == null) return;

    if (_bulkMode) {
      await _sendBulk();
    } else {
      await _sendSingle();
    }
  }

  Future<void> _sendSingle() async {
    if (_toController.text.trim().isEmpty) {
      setState(() {
        _statusMessage = 'Indiquez au moins un destinataire.';
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
      );
      setState(() {
        _statusMessage = 'E-mail envoyé avec succès.';
        _statusIsError = false;
        _toController.clear();
        _ccController.clear();
        _subjectController.clear();
        _bodyController.clear();
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Échec de l'envoi : ${e.toString()}";
        _statusIsError = true;
      });
    } finally {
      setState(() => _sending = false);
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

    setState(() {
      _sending = true;
      _statusMessage = null;
      _bulkProgress = 0;
      _bulkTotal = recipients.length;
    });

    var successCount = 0;
    var failCount = 0;

    for (var i = 0; i < recipients.length; i++) {
      final contact = recipients[i];
      try {
        final personalizedBody = _personalize(_bodyController.text, contact);
        final personalizedSubject = _personalize(_subjectController.text, contact);
        final bodyWithSignature = _selectedSignature != null
            ? '$personalizedBody\n\n${_selectedSignature!.content}'
            : personalizedBody;
        await _sendService.sendEmail(
          account: _selectedAccount!,
          to: contact.email,
          subject: personalizedSubject,
          body: bodyWithSignature,
        );
        successCount++;
      } catch (_) {
        failCount++;
      }
      setState(() => _bulkProgress = (i + 1) / recipients.length);
      // Petite pause pour rester raisonnable vis-à-vis des limites d'envoi de Google.
      await Future.delayed(const Duration(milliseconds: 400));
    }

    setState(() {
      _sending = false;
      _statusMessage = '$successCount e-mail(s) envoyé(s)'
          '${failCount > 0 ? ', $failCount échec(s)' : ''}.';
      _statusIsError = failCount > 0 && successCount == 0;
      if (failCount == 0) {
        _selectedContactIds.clear();
        _subjectController.clear();
        _bodyController.clear();
      }
    });
  }

  @override
  void dispose() {
    _toController.dispose();
    _ccController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
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
            ] else ...[
              TextField(
                controller: _toController,
                decoration: const InputDecoration(
                  labelText: 'À (destinataire)',
                  hintText: 'exemple@domaine.com, autre@domaine.com',
                  border: OutlineInputBorder(),
                ),
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
            const SizedBox(height: 16),
            if (_sending && _bulkMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: _bulkProgress),
                    const SizedBox(height: 4),
                    Text('${(_bulkProgress * _bulkTotal).round()} / $_bulkTotal envoyés'),
                  ],
                ),
              ),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_statusMessage!, style: TextStyle(color: _statusIsError ? Colors.red : Colors.green)),
              ),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_sending ? 'Envoi en cours…' : (_bulkMode ? 'Envoyer à tous' : 'Envoyer')),
            ),
          ],
        ),
      ),
    );
  }
}

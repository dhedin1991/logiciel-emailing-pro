import 'package:flutter/material.dart';
import '../models/email_account.dart';
import '../services/account_storage.dart';
import '../services/gmail_send_service.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _storage = AccountStorage();
  final _sendService = GmailSendService();

  final _toController = TextEditingController();
  final _ccController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  List<EmailAccount> _accounts = [];
  EmailAccount? _selectedAccount;
  bool _loading = true;
  bool _sending = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await _storage.loadAccounts();
    setState(() {
      _accounts = accounts;
      _selectedAccount = accounts.isNotEmpty ? accounts.first : null;
      _loading = false;
    });
  }

  Future<void> _send() async {
    if (_selectedAccount == null) return;
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
      await _sendService.sendEmail(
        account: _selectedAccount!,
        to: _toController.text.trim(),
        cc: _ccController.text.trim(),
        subject: _subjectController.text.trim(),
        body: _bodyController.text,
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
      setState(() {
        _sending = false;
      });
    }
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
            Text('Nouveau message', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            DropdownButtonFormField<EmailAccount>(
              initialValue: _selectedAccount,
              decoration: const InputDecoration(labelText: 'Expéditeur', border: OutlineInputBorder()),
              items: _accounts
                  .map((a) => DropdownMenuItem(value: a, child: Text(a.email)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedAccount = value),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Objet', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
              maxLines: 10,
            ),
            const SizedBox(height: 16),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(color: _statusIsError ? Colors.red : Colors.green),
                ),
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
              label: Text(_sending ? 'Envoi en cours…' : 'Envoyer'),
            ),
          ],
        ),
      ),
    );
  }
}

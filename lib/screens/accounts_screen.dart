import 'package:flutter/material.dart';
import '../models/email_account.dart';
import '../services/account_storage.dart';
import '../services/gmail_auth_service.dart';
import '../services/smtp_send_service.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/empty_state.dart';
import '../widgets/password_field.dart';
import '../widgets/provider_connection_guide.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _storage = AccountStorage();
  final _gmailAuth = GmailAuthService();

  List<EmailAccount> _accounts = [];
  bool _loading = true;
  bool _connecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await _storage.loadAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _loading = false;
    });
  }

  Future<void> _connectGmailAccount() async {
    setState(() {
      _connecting = true;
      _errorMessage = null;
    });
    try {
      final account = await _gmailAuth.connectAccount();
      await _storage.addOrUpdateAccount(account);
      await _loadAccounts();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Connexion impossible : ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _connecting = false;
        });
      }
    }
  }

  Future<void> _reconnectAccount(String email) async {
    setState(() {
      _connecting = true;
      _errorMessage = null;
    });
    try {
      final account = await _gmailAuth.connectAccount();
      if (!mounted) return;
      if (account.email != email) {
        setState(() {
          _errorMessage =
              'Vous vous êtes connecté(e) avec ${account.email} au lieu de $email — reconnectez-vous avec le même compte Google.';
        });
      } else {
        await _storage.addOrUpdateAccount(account);
        await _loadAccounts();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Reconnexion impossible : ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _connecting = false;
        });
      }
    }
  }

  Future<void> _showSmtpDialog() async {
    var selectedPreset = smtpPresets.first;
    final hostController = TextEditingController(text: selectedPreset.host);
    final portController = TextEditingController(text: selectedPreset.port.toString());
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    String? errorText;

    final account = await showDialog<EmailAccount>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Connecter un autre compte'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Besoin des étapes détaillées ? Voir "Guide de connexion par fournisseur" au-dessus de la liste des comptes. '
                  'Zoho : nécessite un nom de domaine perso (environ 10€/an, Zoho reste gratuit jusqu\'à 5 adresses) — '
                  'activer "Accès IMAP" dans Zoho Mail (Paramètres → Comptes de messagerie → POP/IMAP) avant de connecter ici. '
                  'Outlook n\'est pas disponible pour le moment (voir le guide). Pas Gmail (bouton dédié).',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SmtpPreset>(
                  initialValue: selectedPreset,
                  decoration: const InputDecoration(labelText: 'Fournisseur', border: OutlineInputBorder()),
                  items: smtpPresets.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
                  onChanged: (value) => setDialogState(() {
                    selectedPreset = value!;
                    hostController.text = value.host;
                    portController.text = value.port.toString();
                  }),
                ),
                const SizedBox(height: 12),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom affiché (facultatif)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Adresse e-mail complète', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: hostController, decoration: const InputDecoration(labelText: 'Serveur SMTP', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                  controller: portController,
                  decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                PasswordField(
                  controller: passwordController,
                  labelText: 'Mot de passe d\'application',
                  border: const OutlineInputBorder(),
                ),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(errorText!, style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (emailController.text.trim().isEmpty || passwordController.text.isEmpty || hostController.text.trim().isEmpty) {
                  setDialogState(() => errorText = 'Remplissez au moins l\'e-mail, le serveur et le mot de passe.');
                  return;
                }
                Navigator.pop(
                  context,
                  EmailAccount(
                    email: emailController.text.trim(),
                    provider: 'smtp',
                    smtpHost: hostController.text.trim(),
                    smtpPort: int.tryParse(portController.text.trim()) ?? 587,
                    smtpPassword: passwordController.text,
                    displayName: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
                  ),
                );
              },
              child: const Text('Connecter'),
            ),
          ],
        ),
      ),
    );

    if (account != null) {
      await _storage.addOrUpdateAccount(account);
      await _loadAccounts();
    }
    hostController.dispose();
    portController.dispose();
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
  }

  Future<void> _removeAccount(String email) async {
    if (!await confirmDelete(context, email)) return;
    await _storage.removeAccount(email);
    if (!mounted) return;
    await _loadAccounts();
  }

  String _providerLabel(String provider) {
    switch (provider) {
      case 'gmail':
        return 'Gmail';
      case 'smtp':
        return 'Autre fournisseur (SMTP)';
      default:
        return provider;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comptes connectés', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          const ProviderConnectionGuideSection(),
          const SizedBox(height: 16),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _accounts.isEmpty
                ? const EmptyState(
                    icon: Icons.alternate_email,
                    title: 'Aucun compte connecté',
                    subtitle: 'Connectez un compte Gmail ou un autre fournisseur pour commencer à envoyer.',
                  )
                : ListView.builder(
                    itemCount: _accounts.length,
                    itemBuilder: (context, index) {
                      final account = _accounts[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.mail_outline),
                          title: Text(account.email),
                          subtitle: Text(_providerLabel(account.provider)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (account.provider == 'gmail')
                                TextButton.icon(
                                  onPressed: _connecting ? null : () => _reconnectAccount(account.email),
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Reconnecter'),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _removeAccount(account.email),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _connecting ? null : _connectGmailAccount,
                icon: _connecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add),
                label: Text(_connecting ? 'Connexion en cours…' : 'Connecter un compte Gmail'),
              ),
              OutlinedButton.icon(
                onPressed: _showSmtpDialog,
                icon: const Icon(Icons.alternate_email),
                label: const Text('Connecter un autre compte (Zoho, GMX, Yahoo...)'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

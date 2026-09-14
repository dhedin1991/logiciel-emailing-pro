import 'package:flutter/material.dart';
import '../models/email_account.dart';
import '../models/signature.dart';
import '../services/account_storage.dart';
import '../services/gmail_auth_service.dart';
import '../services/smtp_send_service.dart';
import '../services/signature_storage.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/empty_state.dart';
import '../widgets/password_field.dart';
import '../widgets/provider_connection_guide.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/info_notice.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _storage = AccountStorage();
  final _gmailAuth = GmailAuthService();
  final _signatureStorage = SignatureStorage();

  List<EmailAccount> _accounts = [];
  List<Signature> _signatures = [];
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
    final signatures = await _signatureStorage.loadSignatures();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _signatures = signatures;
      _loading = false;
    });
  }

  Future<void> _setDefaultSignature(EmailAccount account, String? signatureId) async {
    await _storage.addOrUpdateAccount(account.copyWith(
      defaultSignatureId: signatureId,
      clearDefaultSignature: signatureId == null,
    ));
    await _loadAccounts();
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

  Future<void> _showSmtpDialog({EmailAccount? existing}) async {
    final initialPreset = existing != null
        ? smtpPresets.firstWhere(
            (p) => p.host == existing.smtpHost,
            orElse: () => smtpPresets.first,
          )
        : smtpPresets.first;
    var selectedPreset = initialPreset;
    final hostController = TextEditingController(text: existing?.smtpHost ?? selectedPreset.host);
    final portController = TextEditingController(text: (existing?.smtpPort ?? selectedPreset.port).toString());
    final emailController = TextEditingController(text: existing?.email ?? '');
    final passwordController = TextEditingController(text: existing?.smtpPassword ?? '');
    final nameController = TextEditingController(text: existing?.displayName ?? '');
    String? errorText;

    final account = await showDialog<EmailAccount>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Connecter un autre compte' : 'Modifier le compte'),
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
                TextField(
                  controller: emailController,
                  enabled: existing == null,
                  decoration: InputDecoration(
                    labelText: 'Adresse e-mail complète',
                    border: const OutlineInputBorder(),
                    helperText: existing != null ? 'Non modifiable — supprimez et reconnectez pour changer d\'adresse.' : null,
                  ),
                ),
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
                    defaultSignatureId: existing?.defaultSignatureId,
                  ),
                );
              },
              child: Text(existing == null ? 'Connecter' : 'Enregistrer'),
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
    final account = _accounts.firstWhere((a) => a.email == email);
    await deleteWithUndo(
      context: context,
      itemLabel: email,
      onDelete: () async {
        await _storage.removeAccount(email);
        await _loadAccounts();
      },
      onUndo: () async {
        await _storage.addOrUpdateAccount(account);
        await _loadAccounts();
      },
    );
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
      return const SkeletonListLoader();
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
          if (_accounts.any((a) => a.provider == 'gmail')) ...[
            const InfoNotice(
              title: 'Volume d\'envoi recommandé',
              bullets: [
                'Gmail gratuit : limite officielle de 500 e-mails/jour, mais restez idéalement sous 100 à 150/jour par compte pour préserver sa réputation.',
                'Pour un plus gros volume, répartissez vos envois entre plusieurs comptes connectés plutôt que de pousser un seul compte à sa limite.',
              ],
            ),
            const SizedBox(height: 16),
          ],
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_providerLabel(account.provider)),
                              if (_signatures.isNotEmpty)
                                DropdownButton<String?>(
                                  isDense: true,
                                  value: _signatures.any((s) => s.id == account.defaultSignatureId)
                                      ? account.defaultSignatureId
                                      : null,
                                  hint: const Text('Signature par défaut', style: TextStyle(fontSize: 12)),
                                  items: [
                                    const DropdownMenuItem<String?>(value: null, child: Text('Aucune')),
                                    ..._signatures.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name))),
                                  ],
                                  onChanged: (value) => _setDefaultSignature(account, value),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (account.provider == 'gmail')
                                TextButton.icon(
                                  onPressed: _connecting ? null : () => _reconnectAccount(account.email),
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Reconnecter'),
                                ),
                              if (account.provider == 'smtp')
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Modifier le compte',
                                  onPressed: () => _showSmtpDialog(existing: account),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Supprimer le compte',
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

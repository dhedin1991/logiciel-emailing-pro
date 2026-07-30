import 'package:flutter/material.dart';
import '../models/email_account.dart';
import '../services/account_storage.dart';
import '../services/gmail_auth_service.dart';

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
      setState(() {
        _errorMessage = 'Connexion impossible : ${e.toString()}';
      });
    } finally {
      setState(() {
        _connecting = false;
      });
    }
  }

  Future<void> _removeAccount(String email) async {
    await _storage.removeAccount(email);
    await _loadAccounts();
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
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _accounts.isEmpty
                ? const Center(child: Text('Aucun compte connecté pour le moment.'))
                : ListView.builder(
                    itemCount: _accounts.length,
                    itemBuilder: (context, index) {
                      final account = _accounts[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.mail_outline),
                          title: Text(account.email),
                          subtitle: Text(account.provider == 'gmail' ? 'Gmail' : account.provider),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeAccount(account.email),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
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
        ],
      ),
    );
  }
}

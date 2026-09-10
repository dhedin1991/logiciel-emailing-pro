import 'package:flutter/material.dart';
import '../services/app_auth_service.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _authService = AppAuthService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _statusMessage;
  bool _statusIsError = false;

  Future<void> _updateCredentials() async {
    if (_usernameController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _statusMessage = 'Remplissez tous les champs.';
        _statusIsError = true;
      });
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() {
        _statusMessage = 'Les mots de passe ne correspondent pas.';
        _statusIsError = true;
      });
      return;
    }
    await _authService.setCredentials(_usernameController.text, _passwordController.text);
    setState(() {
      _statusMessage = 'Identifiant et mot de passe mis à jour.';
      _statusIsError = false;
      _usernameController.clear();
      _passwordController.clear();
      _confirmController.clear();
    });
  }

  Future<void> _removeLock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Désactiver la protection'),
        content: const Text('N\'importe qui pourra ouvrir le logiciel sans mot de passe. Continuer ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Désactiver')),
        ],
      ),
    );
    if (confirmed == true) {
      await _authService.removeLock();
      setState(() {
        _statusMessage = 'Protection désactivée. Redémarrez l\'application pour une nouvelle configuration.';
        _statusIsError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sécurité de l\'application', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Changez l\'identifiant et le mot de passe demandés à l\'ouverture du logiciel.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_outlined, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Le mot de passe est désormais redemandé à chaque ouverture du logiciel.'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Nouvel identifiant', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nouveau mot de passe', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmer', border: OutlineInputBorder()),
              ),
              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_statusMessage!, style: TextStyle(color: _statusIsError ? Colors.red : Colors.green)),
                ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _updateCredentials, child: const Text('Mettre à jour')),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _removeLock,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Désactiver la protection par mot de passe'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

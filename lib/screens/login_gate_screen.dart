import 'package:flutter/material.dart';
import '../services/app_auth_service.dart';

class LoginGateScreen extends StatefulWidget {
  final Widget child;
  const LoginGateScreen({super.key, required this.child});

  @override
  State<LoginGateScreen> createState() => _LoginGateScreenState();
}

class _LoginGateScreenState extends State<LoginGateScreen> {
  final _authService = AppAuthService();
  bool _loading = true;
  bool _hasCredentials = false;
  bool _authenticated = false;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final has = await _authService.hasCredentials();
    setState(() {
      _hasCredentials = has;
      _loading = false;
    });
  }

  Future<void> _createCredentials() async {
    if (_usernameController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Remplissez tous les champs.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _errorMessage = 'Les mots de passe ne correspondent pas.');
      return;
    }
    await _authService.setCredentials(_usernameController.text, _passwordController.text);
    setState(() {
      _hasCredentials = true;
      _authenticated = true;
      _errorMessage = null;
    });
  }

  Future<void> _login() async {
    final ok = await _authService.verify(_usernameController.text, _passwordController.text);
    if (ok) {
      setState(() => _authenticated = true);
    } else {
      setState(() => _errorMessage = 'Identifiant ou mot de passe incorrect.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_authenticated) {
      return widget.child;
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mark_email_read_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  _hasCredentials ? 'Connexion' : 'Créer un accès sécurisé',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                if (!_hasCredentials)
                  Text(
                    'Choisissez un identifiant et un mot de passe pour protéger l\'accès à ce logiciel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                const SizedBox(height: 24),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Identifiant', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder()),
                  onSubmitted: (_) => _hasCredentials ? _login() : _createCredentials(),
                ),
                if (!_hasCredentials) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirmer le mot de passe', border: OutlineInputBorder()),
                  ),
                ],
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _hasCredentials ? _login : _createCredentials,
                  style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  child: Text(_hasCredentials ? 'Se connecter' : 'Créer et continuer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

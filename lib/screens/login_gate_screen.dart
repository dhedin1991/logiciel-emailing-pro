import 'package:flutter/material.dart';
import '../services/app_auth_service.dart';
import '../widgets/password_field.dart';

class LoginGateScreen extends StatefulWidget {
  final Widget child;
  const LoginGateScreen({super.key, required this.child});

  @override
  State<LoginGateScreen> createState() => _LoginGateScreenState();
}

class _LoginGateScreenState extends State<LoginGateScreen> {
  final _authService = AppAuthService();
  final _passwordFocusNode = FocusNode();

  bool _loading = true;
  bool _hasCredentials = false;
  bool _authenticated = false;
  String? _savedUsername;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _errorMessage;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Le mot de passe est désormais TOUJOURS redemandé au démarrage : pas de
  /// session persistante. On récupère juste l'identifiant mémorisé pour le
  /// pré-remplir.
  Future<void> _check() async {
    final has = await _authService.hasCredentials();
    final username = has ? await _authService.getUsername() : null;
    setState(() {
      _hasCredentials = has;
      _savedUsername = username;
      _authenticated = false;
      _loading = false;
    });
    if (has) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _passwordFocusNode.requestFocus();
      });
    }
  }

  Future<void> _createCredentials() async {
    if (_usernameController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Remplissez tous les champs.');
      return;
    }
    if (_passwordController.text.length < 4) {
      setState(() => _errorMessage = 'Le mot de passe doit contenir au moins 4 caractères.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _errorMessage = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() => _submitting = true);
    await _authService.setCredentials(_usernameController.text, _passwordController.text);
    if (!mounted) return;
    setState(() {
      _hasCredentials = true;
      _authenticated = true;
      _errorMessage = null;
      _submitting = false;
    });
  }

  Future<void> _login() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Saisissez votre mot de passe.');
      return;
    }
    final locked = await _authService.remainingLockSeconds();
    if (locked > 0) {
      setState(() => _errorMessage = 'Trop d\'essais. Réessayez dans $locked s.');
      return;
    }
    setState(() => _submitting = true);
    final ok = await _authService.verifyPassword(_passwordController.text);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _authenticated = true;
        _submitting = false;
      });
    } else {
      setState(() {
        _errorMessage = 'Mot de passe incorrect.';
        _submitting = false;
        _passwordController.clear();
      });
      _passwordFocusNode.requestFocus();
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

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.mark_email_read_outlined, size: 36, color: colorScheme.onPrimaryContainer),
                ),
                const SizedBox(height: 20),
                Text(
                  _hasCredentials ? 'Connexion' : 'Créer un accès sécurisé',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                if (!_hasCredentials)
                  Text(
                    "Choisissez un identifiant et un mot de passe pour protéger l'accès à ce logiciel.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  )
                else
                  Text(
                    'Mot de passe requis à chaque ouverture du logiciel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                const SizedBox(height: 28),

                if (_hasCredentials) ...[
                  // Identifiant déjà connu : affiché en lecture seule,
                  // seul le mot de passe est à saisir.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 20, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _savedUsername ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PasswordField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    autofocus: true,
                    labelText: 'Mot de passe',
                    border: const OutlineInputBorder(),
                    onSubmitted: (_) => _submitting ? null : _login(),
                  ),
                ] else ...[
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Identifiant', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  PasswordField(
                    controller: _passwordController,
                    labelText: 'Mot de passe',
                    border: const OutlineInputBorder(),
                  ),
                  const SizedBox(height: 12),
                  PasswordField(
                    controller: _confirmController,
                    labelText: 'Confirmer le mot de passe',
                    border: const OutlineInputBorder(),
                    onSubmitted: (_) => _submitting ? null : _createCredentials(),
                  ),
                ],

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : (_hasCredentials ? _login : _createCredentials),
                  style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_hasCredentials ? 'Se connecter' : 'Créer et continuer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

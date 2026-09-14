import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/account_storage.dart';
import '../services/send_jobs_manager.dart';
import '../models/email_account.dart';

/// Centre de diagnostic : permet de comprendre rapidement l'état de
/// l'application (connexion Supabase, comptes, file d'envoi) sans avoir à
/// deviner ce qui ne va pas. Les messages restent compréhensibles pour un
/// utilisateur non technique.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  bool _checking = false;
  String? _supabaseError;
  bool _checked = false;
  List<EmailAccount> _accounts = [];

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    setState(() => _checking = true);
    final accounts = await AccountStorage().loadAccounts();
    final error = await SyncService().testConnection();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _supabaseError = error;
      _checked = true;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeSends = SendJobsManager.instance.activeCount;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.health_and_safety_outlined, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Centre de diagnostic', style: Theme.of(context).textTheme.headlineSmall)),
                  IconButton(
                    icon: _checking
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    tooltip: 'Relancer les vérifications',
                    onPressed: _checking ? null : _runChecks,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _DiagnosticRow(
                icon: Icons.cloud_outlined,
                label: 'Synchronisation cloud (Supabase)',
                status: !_checked
                    ? 'Vérification en cours...'
                    : (_supabaseError == null ? 'Connecté et joignable' : _supabaseError!),
                ok: _checked && _supabaseError == null,
                pending: !_checked,
              ),
              _DiagnosticRow(
                icon: Icons.alternate_email,
                label: 'Comptes e-mail connectés',
                status: _accounts.isEmpty
                    ? 'Aucun compte connecté — allez dans Comptes pour en ajouter un.'
                    : '${_accounts.length} compte(s) : ${_accounts.map((a) => a.email).join(', ')}',
                ok: _accounts.isNotEmpty,
                pending: false,
              ),
              _DiagnosticRow(
                icon: Icons.send_outlined,
                label: 'File d\'envoi',
                status: activeSends == 0 ? 'Aucun envoi en cours' : '$activeSends campagne(s) en cours',
                ok: true,
                pending: false,
              ),
              const SizedBox(height: 24),
              Text(
                'En cas de problème persistant, ces informations (sans mot de passe ni donnée personnelle) '
                'peuvent être utiles pour identifier la cause exacte.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final bool ok;
  final bool pending;

  const _DiagnosticRow({
    required this.icon,
    required this.label,
    required this.status,
    required this.ok,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final color = pending ? Colors.grey : (ok ? Colors.green : Colors.red);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(status, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              ],
            ),
          ),
          Icon(
            pending ? Icons.hourglass_empty : (ok ? Icons.check_circle : Icons.error),
            color: color,
            size: 18,
          ),
        ],
      ),
    );
  }
}

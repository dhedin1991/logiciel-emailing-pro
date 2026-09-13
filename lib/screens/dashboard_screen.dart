import 'package:flutter/material.dart';
import '../models/sent_email_log.dart';
import '../services/account_storage.dart';
import '../services/history_storage.dart';
import '../services/scheduled_email_storage.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  int _accountsCount = 0;
  int _sentCount = 0;
  int _errorCount = 0;
  int _scheduledCount = 0;
  String? _primaryAccountEmail;
  List<SentEmailLog> _recent = [];
  Map<String, int> _sentTodayByGmailAccount = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await AccountStorage().loadAccounts();
    final history = await HistoryStorage().loadAll();
    final scheduled = await ScheduledEmailStorage().loadAll();
    if (!mounted) return;
    final today = DateTime.now();
    final gmailEmails = accounts.where((a) => a.provider == 'gmail').map((a) => a.email).toSet();
    final sentToday = <String, int>{};
    for (final e in history) {
      if (!e.success) continue;
      if (!gmailEmails.contains(e.accountEmail)) continue;
      if (e.sentAt.year != today.year || e.sentAt.month != today.month || e.sentAt.day != today.day) continue;
      sentToday[e.accountEmail] = (sentToday[e.accountEmail] ?? 0) + 1;
    }
    setState(() {
      _accountsCount = accounts.length;
      _primaryAccountEmail = accounts.isEmpty ? null : accounts.first.email;
      _sentCount = history.where((e) => e.success).length;
      _errorCount = history.where((e) => !e.success).length;
      _scheduledCount = scheduled.where((e) => !e.sent).length;
      _recent = history.take(5).toList();
      _sentTodayByGmailAccount = sentToday;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonListLoader();

    final cards = [
      _StatCard(icon: Icons.send, label: 'E-mails envoyés', value: _sentCount, color: Colors.green),
      _StatCard(icon: Icons.schedule, label: 'Envois programmés', value: _scheduledCount, color: Colors.orange),
      _StatCard(icon: Icons.error_outline, label: 'Erreurs', value: _errorCount, color: Colors.red),
      _StatCard(icon: Icons.alternate_email, label: 'Comptes connectés', value: _accountsCount, color: Colors.blue),
    ];

    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Bonjour' : (hour < 18 ? 'Bon après-midi' : 'Bonsoir');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$greeting 👋', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      _primaryAccountEmail != null
                          ? 'Voici l\'activité de $_primaryAccountEmail.'
                          : 'Connectez un compte pour commencer à envoyer des e-mails.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualiser', onPressed: _load),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => widget.onNavigate?.call(3),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Nouvel envoi'),
              ),
              OutlinedButton.icon(
                onPressed: () => widget.onNavigate?.call(1),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Ajouter un contact'),
              ),
              OutlinedButton.icon(
                onPressed: () => widget.onNavigate?.call(4),
                icon: const Icon(Icons.history_outlined),
                label: const Text('Voir l\'historique'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (_sentTodayByGmailAccount.isNotEmpty) ...[
            Text('Volume d\'envoi Gmail aujourd\'hui', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _sentTodayByGmailAccount.entries.map((e) {
                final ratio = e.value / 500;
                final color = ratio >= 0.9 ? Colors.red : (ratio >= 0.3 ? Colors.orange : Colors.green);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('${e.value}/500', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(value: ratio.clamp(0, 1), color: color, minHeight: 6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
          ],
          Wrap(spacing: 16, runSpacing: 16, children: cards),
          const SizedBox(height: 32),
          Text('Activité récente', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_recent.isEmpty)
            const EmptyState(icon: Icons.inbox_outlined, title: 'Rien à afficher pour l\'instant')
          else
            Column(
              children: _recent
                  .map((e) => Card(
                        child: ListTile(
                          leading: Icon(
                            e.success ? Icons.check_circle : Icons.error,
                            color: e.success ? Colors.green : Colors.red,
                          ),
                          title: Text(e.subject.isEmpty ? '(sans objet)' : e.subject),
                          subtitle: Text(e.to),
                          trailing: Text(
                            '${e.sentAt.day}/${e.sentAt.month} ${e.sentAt.hour.toString().padLeft(2, '0')}:${e.sentAt.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text('$value', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

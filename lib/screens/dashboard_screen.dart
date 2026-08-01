import 'package:flutter/material.dart';
import '../services/account_storage.dart';
import '../services/history_storage.dart';
import '../services/scheduled_email_storage.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  int _accountsCount = 0;
  int _sentCount = 0;
  int _errorCount = 0;
  int _scheduledCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await AccountStorage().loadAccounts();
    final history = await HistoryStorage().loadAll();
    final scheduled = await ScheduledEmailStorage().loadAll();
    setState(() {
      _accountsCount = accounts.length;
      _sentCount = history.where((e) => e.success).length;
      _errorCount = history.where((e) => !e.success).length;
      _scheduledCount = scheduled.where((e) => !e.sent).length;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final cards = [
      _StatCard(icon: Icons.send, label: 'E-mails envoyés', value: _sentCount, color: Colors.green),
      _StatCard(icon: Icons.schedule, label: 'Envois programmés', value: _scheduledCount, color: Colors.orange),
      _StatCard(icon: Icons.error_outline, label: 'Erreurs', value: _errorCount, color: Colors.red),
      _StatCard(icon: Icons.alternate_email, label: 'Comptes connectés', value: _accountsCount, color: Colors.blue),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Tableau de bord', style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(spacing: 16, runSpacing: 16, children: cards),
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

import 'package:flutter/material.dart';
import '../services/history_storage.dart';
import '../widgets/skeleton_loader.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _loading = true;
  List<MapEntry<String, int>> _byDay = [];
  List<MapEntry<String, int>> _byAccount = [];
  int _totalSent = 0;
  int _totalErrors = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await HistoryStorage().loadAll();
    final now = DateTime.now();
    final last7Days = List.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));

    final byDayCount = <String, int>{
      for (final d in last7Days) '${d.day}/${d.month}': 0,
    };
    final byAccountCount = <String, int>{};
    var totalSent = 0;
    var totalErrors = 0;

    for (final e in entries) {
      if (!e.success) {
        totalErrors++;
        continue;
      }
      totalSent++;
      final dayKey = '${e.sentAt.day}/${e.sentAt.month}';
      if (byDayCount.containsKey(dayKey)) {
        byDayCount[dayKey] = byDayCount[dayKey]! + 1;
      }
      byAccountCount[e.accountEmail] = (byAccountCount[e.accountEmail] ?? 0) + 1;
    }

    setState(() {
      _byDay = byDayCount.entries.toList();
      _byAccount = byAccountCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      _totalSent = totalSent;
      _totalErrors = totalErrors;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonListLoader();

    final maxDay = _byDay.map((e) => e.value).fold(0, (a, b) => a > b ? a : b);
    final maxAccount = _byAccount.isEmpty ? 0 : _byAccount.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('Statistiques', style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualiser', onPressed: _load),
            ],
          ),
          const SizedBox(height: 8),
          Text('Total envoyés : $_totalSent   •   Total erreurs : $_totalErrors',
              style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 24),
          Text('Envois des 7 derniers jours', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ..._byDay.map((e) => _BarRow(label: e.key, value: e.value, max: maxDay == 0 ? 1 : maxDay, color: Colors.blue)),
          const SizedBox(height: 28),
          Text('Envois par compte', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_byAccount.isEmpty)
            const Text('Aucune donnée pour le moment.')
          else
            ..._byAccount.map((e) => _BarRow(label: e.key, value: e.value, max: maxAccount == 0 ? 1 : maxAccount, color: Colors.green)),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;

  const _BarRow({required this.label, required this.value, required this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, overflow: TextOverflow.ellipsis)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = max == 0 ? 0.0 : (value / max) * constraints.maxWidth;
                return Stack(
                  children: [
                    Container(height: 20, color: Colors.grey.shade200),
                    Container(height: 20, width: width, color: color),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 30, child: Text('$value')),
        ],
      ),
    );
  }
}

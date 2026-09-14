import 'package:flutter/material.dart';
import '../services/history_storage.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/screen_header.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _loading = true;
  List<MapEntry<String, int>> _byDay = [];
  List<MapEntry<String, int>> _byAccount = [];
  List<int> _last30DaysCounts = [];
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
    final last30Days = List.generate(30, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 29 - i)));

    final byDayCount = <String, int>{
      for (final d in last7Days) '${d.day}/${d.month}': 0,
    };
    final byLast30Count = <String, int>{
      for (final d in last30Days) '${d.year}-${d.month}-${d.day}': 0,
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
      final last30Key = '${e.sentAt.year}-${e.sentAt.month}-${e.sentAt.day}';
      if (byLast30Count.containsKey(last30Key)) {
        byLast30Count[last30Key] = byLast30Count[last30Key]! + 1;
      }
      byAccountCount[e.accountEmail] = (byAccountCount[e.accountEmail] ?? 0) + 1;
    }

    setState(() {
      _byDay = byDayCount.entries.toList();
      _byAccount = byAccountCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      _last30DaysCounts = byLast30Count.values.toList();
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
          ScreenHeader(
            icon: Icons.bar_chart,
            title: 'Statistiques',
            actions: [
              IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualiser', onPressed: _load),
            ],
          ),
          const SizedBox(height: 8),
          Text('Total envoyés : $_totalSent   •   Total erreurs : $_totalErrors',
              style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 24),
          Text('Évolution des envois (30 derniers jours)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: _TrendChart(values: _last30DaysCounts, color: Theme.of(context).colorScheme.primary),
          ),
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

class _TrendChart extends StatelessWidget {
  final List<int> values;
  final Color color;

  const _TrendChart({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty || values.every((v) => v == 0)) {
      return Center(child: Text('Aucun envoi sur cette période.', style: TextStyle(color: Colors.grey.shade600)));
    }
    return CustomPaint(
      size: Size.infinite,
      painter: _TrendChartPainter(values: values, color: color),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<int> values;
  final Color color;

  _TrendChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    final stepX = values.length > 1 ? size.width / (values.length - 1) : size.width;

    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(i * stepX, size.height - (values[i] / maxValue) * size.height),
    ];

    // Zone remplie sous la courbe.
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()..color = color.withValues(alpha: 0.12));

    // Ligne de tendance.
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );

    // Point sur le dernier jour.
    canvas.drawCircle(points.last, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
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

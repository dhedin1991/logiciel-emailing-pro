import 'package:flutter/material.dart';
import '../models/scheduled_email.dart';
import '../services/scheduled_email_storage.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/skeleton_loader.dart';

/// Vue calendrier des envois programmés (uniques et récurrents) : un point
/// sur chaque jour qui a au moins un envoi prévu, et la liste du jour
/// sélectionné en dessous.
class ScheduledCalendarScreen extends StatefulWidget {
  const ScheduledCalendarScreen({super.key});

  @override
  State<ScheduledCalendarScreen> createState() => _ScheduledCalendarScreenState();
}

class _ScheduledCalendarScreenState extends State<ScheduledCalendarScreen> {
  final _storage = ScheduledEmailStorage();
  bool _loading = true;
  List<ScheduledEmail> _all = [];
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _storage.loadAll();
    if (!mounted) return;
    setState(() {
      _all = all.where((e) => !e.sent).toList();
      _loading = false;
    });
  }

  List<ScheduledEmail> _forDay(DateTime day) {
    return _all.where((e) => e.sendAt.year == day.year && e.sendAt.month == day.month && e.sendAt.day == day.day).toList()
      ..sort((a, b) => a.sendAt.compareTo(b.sendAt));
  }

  Future<void> _removeOccurrence(ScheduledEmail email) async {
    await deleteWithUndo(
      context: context,
      itemLabel: email.subject.isEmpty ? email.to : email.subject,
      onDelete: () async {
        await _storage.remove(email.id);
        await _load();
      },
      onUndo: () async {
        await _storage.add(email);
        await _load();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: SkeletonListLoader());

    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // Lundi = 0 ... Dimanche = 6, pour aligner la grille.
    final leadingBlanks = (firstOfMonth.weekday - 1) % 7;
    final monthNames = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];

    final dayEvents = _forDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendrier des envois')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1)),
                ),
                Text('${monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                    style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 7,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final d in ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                  Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
                for (var day = 1; day <= daysInMonth; day++)
                  _CalendarDayCell(
                    date: DateTime(_visibleMonth.year, _visibleMonth.month, day),
                    hasEvents: _forDay(DateTime(_visibleMonth.year, _visibleMonth.month, day)).isNotEmpty,
                    isSelected: DateTime(_visibleMonth.year, _visibleMonth.month, day) == _selectedDay,
                    onTap: () => setState(() => _selectedDay = DateTime(_visibleMonth.year, _visibleMonth.month, day)),
                  ),
              ],
            ),
            const Divider(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: dayEvents.isEmpty
                  ? Center(child: Text('Aucun envoi programmé ce jour-là.', style: TextStyle(color: Colors.grey.shade600)))
                  : ListView.builder(
                      itemCount: dayEvents.length,
                      itemBuilder: (context, index) {
                        final e = dayEvents[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(e.recurrence != null ? Icons.repeat : Icons.schedule),
                            title: Text(e.subject.isEmpty ? '(sans objet)' : e.subject),
                            subtitle: Text(
                              '${e.to} — ${e.sendAt.hour.toString().padLeft(2, '0')}:${e.sendAt.minute.toString().padLeft(2, '0')}'
                              '${e.recurrence != null ? ' · récurrent' : ''}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Annuler cet envoi',
                              onPressed: () => _removeOccurrence(e),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final bool hasEvents;
  final bool isSelected;
  final VoidCallback onTap;

  const _CalendarDayCell({required this.date, required this.hasEvents, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isToday = DateTime.now().year == date.year && DateTime.now().month == date.month && DateTime.now().day == date.day;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : null,
          border: isToday && !isSelected ? Border.all(color: colorScheme.primary) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${date.day}', style: TextStyle(color: isSelected ? colorScheme.onPrimaryContainer : null)),
            if (hasEvents)
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

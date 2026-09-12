import 'package:flutter/material.dart';
import '../models/sent_email_log.dart';
import '../services/history_storage.dart';
import '../widgets/empty_state.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/sort_menu_button.dart';
import '../services/export_helper.dart';
import '../widgets/skeleton_loader.dart';

class HistoryScreen extends StatefulWidget {
  final bool onlySuccess;
  const HistoryScreen({super.key, required this.onlySuccess});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _storage = HistoryStorage();
  bool _loading = true;
  List<SentEmailLog> _entries = [];
  final Set<String> _selectedIds = {};
  String _sortField = 'date';
  bool _sortAscending = false;

  List<SentEmailLog> get _sortedEntries {
    final list = [..._entries];
    int compare(SentEmailLog a, SentEmailLog b) {
      switch (_sortField) {
        case 'to':
          return a.to.toLowerCase().compareTo(b.to.toLowerCase());
        case 'subject':
          return a.subject.toLowerCase().compareTo(b.subject.toLowerCase());
        case 'date':
        default:
          return a.sentAt.compareTo(b.sentAt);
      }
    }

    list.sort((a, b) => _sortAscending ? compare(a, b) : compare(b, a));
    return list;
  }

  void _setSort(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = true;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _storage.loadAll();
    final filtered = all.where((e) => e.success == widget.onlySuccess).toList();
    if (!mounted) return;
    setState(() {
      _entries = filtered;
      _selectedIds.removeWhere((id) => !filtered.any((e) => e.id == id));
      _loading = false;
    });
  }

  Future<void> _exportHistory() async {
    final buffer = StringBuffer('Destinataire;Objet;Date;Statut;Erreur\n');
    for (final e in _entries) {
      buffer.writeln([
        csvField(e.to),
        csvField(e.subject),
        csvField('${e.sentAt.day}/${e.sentAt.month}/${e.sentAt.year} ${e.sentAt.hour.toString().padLeft(2, '0')}:${e.sentAt.minute.toString().padLeft(2, '0')}'),
        csvField(e.success ? 'Envoyé' : 'Échec'),
        csvField(e.errorMessage ?? ''),
      ].join(';'));
    }
    try {
      final exported = await exportTextFile(
        content: buffer.toString(),
        suggestedFileName: widget.onlySuccess ? 'historique_envoyes' : 'historique_echecs',
        extension: 'csv',
      );
      if (!mounted || !exported) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export terminé.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'export : ${e.toString()}')),
      );
    }
  }

  Future<void> _clearAll() async {
    if (_entries.isEmpty) return;
    final ok = await confirmDelete(context, '${_entries.length} entrée(s)');
    if (!ok) return;
    await _storage.removeEntries(_entries.map((e) => e.id).toSet());
    if (!mounted) return;
    setState(() => _selectedIds.clear());
    await _load();
  }

  void _toggleSelectAll(bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedIds
          ..clear()
          ..addAll(_entries.map((e) => e.id));
      } else {
        _selectedIds.clear();
      }
    });
  }

  Future<void> _deleteSelection() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Vous êtes sur le point de supprimer ${_selectedIds.length} élément(s). Voulez-vous continuer ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storage.removeEntries(_selectedIds);
    if (!mounted) return;
    setState(() => _selectedIds.clear());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonListLoader();

    final allSelected = _entries.isNotEmpty && _selectedIds.length == _entries.length;
    final title = widget.onlySuccess ? 'E-mails envoyés' : 'E-mails non envoyés / échecs';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('$title (${_entries.length})', style: Theme.of(context).textTheme.headlineSmall)),
              TextButton.icon(
                onPressed: _entries.isEmpty ? null : _exportHistory,
                icon: const Icon(Icons.download),
                label: const Text('Exporter CSV'),
              ),
              TextButton.icon(
                onPressed: _clearAll,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Tout effacer'),
              ),
              IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualiser', onPressed: _load),
            ],
          ),
          if (_entries.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(value: allSelected, onChanged: _toggleSelectAll),
                const Text('Tout sélectionner'),
                const SizedBox(width: 16),
                if (_selectedIds.isNotEmpty) Text('${_selectedIds.length} sélectionné(s)'),
                const Spacer(),
                SortMenuButton(
                  currentField: _sortField,
                  ascending: _sortAscending,
                  options: const {'date': 'Date', 'to': 'Destinataire', 'subject': 'Objet'},
                  onSelected: _setSort,
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _selectedIds.isEmpty ? null : _deleteSelection,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer la sélection'),
                  style: TextButton.styleFrom(foregroundColor: _selectedIds.isEmpty ? null : Colors.red),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: _entries.isEmpty
                ? EmptyState(
                    icon: widget.onlySuccess ? Icons.history : Icons.error_outline,
                    title: widget.onlySuccess ? 'Aucun envoi pour le moment' : 'Aucun échec pour le moment',
                    subtitle: widget.onlySuccess
                        ? 'Vos e-mails envoyés avec succès apparaîtront ici.'
                        : 'Les envois échoués ou non aboutis apparaîtront ici.',
                  )
                : Builder(
                    builder: (context) {
                      final sorted = _sortedEntries;
                      return ListView.builder(
                        itemCount: sorted.length,
                        itemBuilder: (context, index) {
                          final entry = sorted[index];
                          final selected = _selectedIds.contains(entry.id);
                          return Card(
                            child: ListTile(
                              leading: Checkbox(
                                value: selected,
                            onChanged: (checked) => setState(() {
                              if (checked == true) {
                                _selectedIds.add(entry.id);
                              } else {
                                _selectedIds.remove(entry.id);
                              }
                            }),
                          ),
                          title: Text(entry.subject.isEmpty ? '(sans objet)' : entry.subject),
                          subtitle: Text(
                              '${entry.to} — ${entry.sentAt.day}/${entry.sentAt.month}/${entry.sentAt.year} '
                              '${entry.sentAt.hour.toString().padLeft(2, '0')}:${entry.sentAt.minute.toString().padLeft(2, '0')}'
                              '${entry.errorMessage != null ? '\n${entry.errorMessage}' : ''}'),
                          isThreeLine: entry.errorMessage != null,
                          trailing: Icon(
                            entry.success ? Icons.check_circle : Icons.error,
                            color: entry.success ? Colors.green : Colors.red,
                          ),
                        ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

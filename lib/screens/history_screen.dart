import 'package:flutter/material.dart';
import '../models/sent_email_log.dart';
import '../services/history_storage.dart';
import '../widgets/empty_state.dart';
import '../widgets/confirm_delete.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _storage = HistoryStorage();
  bool _loading = true;
  List<SentEmailLog> _entries = [];
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _storage.loadAll();
    setState(() {
      _entries = entries;
      _selectedIds.removeWhere((id) => !entries.any((e) => e.id == id));
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    if (_entries.isEmpty) return;
    final ok = await confirmDelete(context, 'tout l\'historique (${_entries.length} entrées)');
    if (!ok) return;
    await _storage.clearAll();
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
    setState(() => _selectedIds.clear());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final allSelected = _entries.isNotEmpty && _selectedIds.length == _entries.length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Historique (${_entries.length})', style: Theme.of(context).textTheme.headlineSmall)),
              TextButton.icon(
                onPressed: _clearAll,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Tout effacer'),
              ),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
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
                ? const EmptyState(
                    icon: Icons.history,
                    title: 'Aucun envoi pour le moment',
                    subtitle: 'Vos e-mails envoyés apparaîtront ici.',
                  )
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
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
                  ),
          ),
        ],
      ),
    );
  }
}

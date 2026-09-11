import 'package:flutter/material.dart';
import '../services/import_history_storage.dart';
import '../widgets/empty_state.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/skeleton_loader.dart';

class ImportsHistoryScreen extends StatefulWidget {
  const ImportsHistoryScreen({super.key});

  @override
  State<ImportsHistoryScreen> createState() => _ImportsHistoryScreenState();
}

class _ImportsHistoryScreenState extends State<ImportsHistoryScreen> {
  final _storage = ImportHistoryStorage();
  bool _loading = true;
  List<ImportLogEntry> _entries = [];
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _storage.loadAll();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _selectedIds.removeWhere((id) => !entries.any((e) => e.id == id));
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    if (_entries.isEmpty) return;
    final ok = await confirmDelete(context, 'tout l\'historique des imports (${_entries.length} entrées)');
    if (!ok) return;
    await _storage.clearAll();
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Imports (${_entries.length})', style: Theme.of(context).textTheme.headlineSmall)),
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
                    icon: Icons.upload_file,
                    title: 'Aucun import pour le moment',
                    subtitle: 'Les imports de contacts et analyses de nettoyage apparaîtront ici.',
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
                          title: Text(entry.summary),
                          subtitle: Text(
                              '${entry.type == 'contact_import' ? 'Import contacts' : 'Nettoyage e-mails'} — '
                              '${entry.timestamp.day}/${entry.timestamp.month}/${entry.timestamp.year} '
                              '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}'),
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

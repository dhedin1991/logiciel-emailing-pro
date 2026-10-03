import 'package:flutter/material.dart';
import '../models/trash_item.dart';
import '../services/trash_service.dart';

/// Page "Corbeille" : tout ce qui a été supprimé, avec restauration ou
/// suppression définitive. Disponible sur Windows et Android.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final _trash = TrashService.instance;
  List<TrashItem> _items = [];
  int _retention = TrashService.defaultRetentionDays;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _trash.loadAll();
    final days = await _trash.retentionDays();
    if (!mounted) return;
    setState(() {
      _items = items;
      _retention = days;
      _loading = false;
    });
  }

  static const _typeLabels = {
    'draft': 'Brouillon',
    'contact': 'Contact',
    'contactList': 'Liste de contacts',
    'template': 'Modèle',
    'signature': 'Signature',
    'snippet': 'Texte court',
    'scheduled': 'Envoi programmé',
    'history': 'Historique',
  };

  static const _typeIcons = {
    'draft': Icons.drafts_outlined,
    'contact': Icons.person_outline,
    'contactList': Icons.groups_outlined,
    'template': Icons.description_outlined,
    'signature': Icons.draw_outlined,
    'snippet': Icons.short_text,
    'scheduled': Icons.schedule_send_outlined,
    'history': Icons.history,
  };

  int _daysLeft(TrashItem item) {
    final expires = item.deletedAt.add(Duration(days: _retention));
    final left = expires.difference(DateTime.now()).inHours / 24;
    return left <= 0 ? 0 : left.ceil();
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _toast(String message) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  Future<void> _restore(TrashItem item) async {
    try {
      await _trash.restore(item.id);
      _toast('"${item.label}" restauré.');
    } catch (e) {
      _toast('Restauration impossible : $e');
    }
    await _load();
  }

  Future<void> _deleteForever(TrashItem item) async {
    final ok = await _confirm('Supprimer définitivement ?',
        '"${item.label}" sera effacé pour toujours.', 'Supprimer définitivement');
    if (!ok) return;
    await _trash.deleteForever(item.id);
    await _load();
  }

  Future<void> _restoreAll() async {
    try {
      await _trash.restoreAll();
      _toast('Tout a été restauré.');
    } catch (e) {
      _toast('Restauration impossible : $e');
    }
    await _load();
  }

  Future<void> _emptyAll() async {
    final ok = await _confirm('Vider la corbeille ?',
        '${_items.length} élément(s) seront effacés pour toujours.', 'Vider la corbeille');
    if (!ok) return;
    await _trash.emptyAll();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _items.isEmpty ? null : _restoreAll,
                icon: const Icon(Icons.restore),
                label: const Text('Tout restaurer'),
              ),
              OutlinedButton.icon(
                onPressed: _items.isEmpty ? null : _emptyAll,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Vider la corbeille'),
              ),
              const Text('Purge automatique après'),
              DropdownButton<int>(
                value: [7, 15, 30, 60, 90].contains(_retention) ? _retention : 30,
                items: [7, 15, 30, 60, 90]
                    .map((d) => DropdownMenuItem(value: d, child: Text('$d jours')))
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  await _trash.setRetentionDays(v);
                  await _load();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? const Center(child: Text('La corbeille est vide.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final left = _daysLeft(item);
                    return Dismissible(
                      key: ValueKey(item.id),
                      // Glisser vers la droite : restaurer. Vers la gauche : supprimer définitivement.
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        color: Colors.green.shade400,
                        child: const Icon(Icons.restore, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red.shade400,
                        child: const Icon(Icons.delete_forever, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          await _restore(item);
                        } else {
                          await _deleteForever(item);
                        }
                        return false; // la liste est rechargée par les méthodes ci-dessus
                      },
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: Icon(_typeIcons[item.type] ?? Icons.delete_outline),
                          title: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${_typeLabels[item.type] ?? item.type} · '
                            '$left jour${left > 1 ? 's' : ''} restant${left > 1 ? 's' : ''}',
                          ),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.restore),
                                tooltip: 'Restaurer',
                                onPressed: () => _restore(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_forever_outlined),
                                tooltip: 'Supprimer définitivement',
                                onPressed: () => _deleteForever(item),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

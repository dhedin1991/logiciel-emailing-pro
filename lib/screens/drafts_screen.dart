import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/email_draft.dart';
import '../services/compose_prefill.dart';
import '../services/draft_storage.dart';
import '../widgets/confirm_delete.dart';

/// Page "Brouillons" : tous les messages enregistrés (manuellement ou
/// automatiquement pendant la rédaction). Disponible sur Windows et Android.
class DraftsScreen extends StatefulWidget {
  final void Function(int index) onNavigate;
  const DraftsScreen({super.key, required this.onNavigate});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  final _storage = DraftStorage();
  List<EmailDraft> _drafts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final drafts = await _storage.loadDrafts();
    if (!mounted) return;
    setState(() {
      _drafts = drafts;
      _loading = false;
    });
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _preview(String body) {
    final flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.isEmpty) return '(message vide)';
    return flat.length > 120 ? '${flat.substring(0, 120)}…' : flat;
  }

  void _open(EmailDraft draft) {
    ComposePrefill.instance.pendingDraft = draft;
    widget.onNavigate(3); // section Rédaction
  }

  Future<void> _duplicate(EmailDraft draft) async {
    await _storage.upsertDraft(EmailDraft(
      id: const Uuid().v4(),
      subject: draft.subject.isEmpty ? '' : '${draft.subject} (copie)',
      body: draft.body,
      savedAt: DateTime.now(),
      deltaJson: draft.deltaJson,
    ));
    await _load();
  }

  Future<void> _delete(EmailDraft draft) async {
    await deleteWithUndo(
      context: context,
      itemLabel: draft.subject.isEmpty ? '(sans objet)' : draft.subject,
      onDelete: () => _storage.removeDraft(draft.id),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_drafts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucun brouillon.\nVos messages en cours de rédaction sont enregistrés ici automatiquement.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _drafts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final d = _drafts[index];
        return Dismissible(
          key: ValueKey(d.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red.shade400,
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => _delete(d),
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              onTap: () => _open(d),
              title: Text(d.subject.isEmpty ? '(sans objet)' : d.subject,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${_date(d.savedAt)}\n${_preview(d.body)}', maxLines: 3, overflow: TextOverflow.ellipsis),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'open') _open(d);
                  if (v == 'duplicate') _duplicate(d);
                  if (v == 'delete') _delete(d);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'open', child: Text('Ouvrir / modifier')),
                  PopupMenuItem(value: 'duplicate', child: Text('Dupliquer')),
                  PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

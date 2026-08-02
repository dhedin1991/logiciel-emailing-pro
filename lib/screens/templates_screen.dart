import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/message_template.dart';
import '../services/template_storage.dart';
import '../widgets/confirm_delete.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final _storage = TemplateStorage();
  final _uuid = const Uuid();
  List<MessageTemplate> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final templates = await _storage.loadTemplates();
    setState(() {
      _templates = templates;
      _loading = false;
    });
  }

  Future<void> _showEditor({MessageTemplate? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final subjectController = TextEditingController(text: existing?.subject ?? '');
    final bodyController = TextEditingController(text: existing?.body ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Nouveau modèle' : 'Modifier le modèle'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom du modèle')),
              TextField(controller: subjectController, decoration: const InputDecoration(labelText: 'Objet')),
              TextField(
                controller: bodyController,
                decoration: const InputDecoration(labelText: 'Message'),
                maxLines: 8,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    );

    if (saved == true && nameController.text.trim().isNotEmpty) {
      if (existing == null) {
        await _storage.addTemplate(MessageTemplate(
          id: _uuid.v4(),
          name: nameController.text.trim(),
          subject: subjectController.text.trim(),
          body: bodyController.text,
        ));
      } else {
        await _storage.updateTemplate(MessageTemplate(
          id: existing.id,
          name: nameController.text.trim(),
          subject: subjectController.text.trim(),
          body: bodyController.text,
        ));
      }
      await _load();
    }
  }

  Future<void> _remove(String id) async {
    final template = _templates.firstWhere((t) => t.id == id);
    if (!await confirmDelete(context, template.name)) return;
    await _storage.removeTemplate(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Modèles de messages', style: Theme.of(context).textTheme.headlineSmall)),
              FilledButton.icon(
                onPressed: () => _showEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau modèle'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _templates.isEmpty
                ? const Center(child: Text('Aucun modèle pour le moment.'))
                : ListView.builder(
                    itemCount: _templates.length,
                    itemBuilder: (context, index) {
                      final template = _templates[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: Text(template.name),
                          subtitle: Text(template.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => _showEditor(existing: template),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _remove(template.id),
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

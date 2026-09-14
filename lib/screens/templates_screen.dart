import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/message_template.dart';
import '../services/template_storage.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/sort_menu_button.dart';
import '../widgets/screen_header.dart';

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
  String _searchQuery = '';
  String _sortField = 'name';
  bool _sortAscending = true;
  String? _folderFilter;

  List<String> get _allFolders =>
      _templates.map((t) => t.folder).where((f) => f.isNotEmpty).toSet().toList()..sort();

  List<MessageTemplate> get _visibleTemplates {
    final list = _templates.where((t) {
      if (_folderFilter != null && t.folder != _folderFilter) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return t.name.toLowerCase().contains(q) || t.subject.toLowerCase().contains(q);
    }).toList();
    int compare(MessageTemplate a, MessageTemplate b) {
      switch (_sortField) {
        case 'subject':
          return a.subject.toLowerCase().compareTo(b.subject.toLowerCase());
        case 'name':
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
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
    final templates = await _storage.loadTemplates();
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _loading = false;
    });
  }

  Future<void> _showEditor({MessageTemplate? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final subjectController = TextEditingController(text: existing?.subject ?? '');
    final bodyController = TextEditingController(text: existing?.body ?? '');
    final folderController = TextEditingController(text: existing?.folder ?? '');

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
              Autocomplete<String>(
                optionsBuilder: (value) {
                  if (value.text.isEmpty) return _allFolders;
                  return _allFolders.where((f) => f.toLowerCase().contains(value.text.toLowerCase()));
                },
                initialValue: TextEditingValue(text: folderController.text),
                fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                  controller.text = folderController.text;
                  controller.addListener(() => folderController.text = controller.text);
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: 'Dossier (optionnel — ex : Relances, Devis)'),
                  );
                },
                onSelected: (value) => folderController.text = value,
              ),
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
          folder: folderController.text.trim(),
        ));
      } else {
        await _storage.updateTemplate(MessageTemplate(
          id: existing.id,
          name: nameController.text.trim(),
          subject: subjectController.text.trim(),
          body: bodyController.text,
          folder: folderController.text.trim(),
        ));
      }
      await _load();
    }
    nameController.dispose();
    subjectController.dispose();
    bodyController.dispose();
    folderController.dispose();
  }

  Future<void> _duplicate(MessageTemplate template) async {
    await _storage.addTemplate(MessageTemplate(
      id: _uuid.v4(),
      name: '${template.name} (copie)',
      subject: template.subject,
      body: template.body,
      folder: template.folder,
    ));
    await _load();
  }

  Future<void> _remove(String id) async {
    final template = _templates.firstWhere((t) => t.id == id);
    await deleteWithUndo(
      context: context,
      itemLabel: template.name,
      onDelete: () async {
        await _storage.removeTemplate(id);
        await _load();
      },
      onUndo: () async {
        await _storage.addTemplate(template);
        await _load();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonListLoader();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            icon: Icons.description_outlined,
            title: 'Modèles de messages',
            actions: [
              FilledButton.icon(
                onPressed: () => _showEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau modèle'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_templates.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un modèle...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 12),
                SortMenuButton(
                  currentField: _sortField,
                  ascending: _sortAscending,
                  options: const {'name': 'Nom', 'subject': 'Objet'},
                  onSelected: _setSort,
                ),
              ],
            ),
            if (_allFolders.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Tous'),
                    selected: _folderFilter == null,
                    onSelected: (_) => setState(() => _folderFilter = null),
                  ),
                  ..._allFolders.map((f) => ChoiceChip(
                        label: Text(f),
                        selected: _folderFilter == f,
                        onSelected: (_) => setState(() => _folderFilter = f),
                      )),
                ],
              ),
            ],
          ],
          const SizedBox(height: 16),
          Expanded(
            child: _templates.isEmpty
                ? const EmptyState(
                    icon: Icons.description_outlined,
                    title: 'Aucun modèle pour le moment',
                    subtitle: 'Créez des messages types réutilisables (relance, devis, bienvenue...).',
                  )
                : ListView.builder(
                    itemCount: _visibleTemplates.length,
                    itemBuilder: (context, index) {
                      final template = _visibleTemplates[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: Text(template.name),
                          subtitle: Text(
                            template.folder.isEmpty ? template.subject : '${template.folder} · ${template.subject}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _showEditor(existing: template),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy_outlined),
                                tooltip: 'Dupliquer',
                                onPressed: () => _duplicate(template),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Supprimer',
                                onPressed: () => _remove(template.id),
                              ),
                            ],
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

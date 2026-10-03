import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/signature.dart';
import '../services/signature_storage.dart';
import '../services/signature_renderer.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/sort_menu_button.dart';
import '../widgets/screen_header.dart';

class SignaturesScreen extends StatefulWidget {
  const SignaturesScreen({super.key});

  @override
  State<SignaturesScreen> createState() => _SignaturesScreenState();
}

class _SignaturesScreenState extends State<SignaturesScreen> {
  final _storage = SignatureStorage();
  final _uuid = const Uuid();
  List<Signature> _signatures = [];
  bool _loading = true;
  String _searchQuery = '';
  String _sortField = 'name';
  bool _sortAscending = true;

  List<Signature> get _visibleSignatures {
    final list = _signatures.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
    list.sort((a, b) {
      final cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  void _setSort(String field) {
    setState(() {
      _sortAscending = _sortField == field ? !_sortAscending : true;
      _sortField = field;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final signatures = await _storage.loadSignatures();
    if (!mounted) return;
    setState(() {
      _signatures = signatures;
      _loading = false;
    });
  }

  static const _formats = <String, String>{
    'text': 'Texte libre',
    'classic': 'Classique',
    'accent': 'Trait de couleur',
    'corporate': 'Grande entreprise',
  };

  static const _fieldsByFormat = <String, List<String>>{
    'classic': ['name', 'function', 'company', 'phone', 'email', 'website'],
    'accent': ['name', 'function', 'company', 'phone', 'email', 'website'],
    'corporate': [
      'name', 'function', 'direction', 'company', 'registration', 'city',
      'phone', 'mobile', 'email', 'website', 'confidentiality'
    ],
  };

  static const _accentColors = <int>[
    0xFF2563EB, 0xFF059669, 0xFFDC2626, 0xFF7C3AED, 0xFFEA580C, 0xFF111827,
  ];

  Widget _preview(Signature sig) {
    final lines = signatureLines(sig);
    if (lines.isEmpty) {
      return const Text('Aperçu : remplissez les champs ci-dessus.',
          style: TextStyle(color: Colors.grey, fontSize: 12));
    }
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final l in lines)
          Text(
            l.text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              height: 1.3,
              fontSize: l.kind == SigLineKind.name
                  ? signatureNameFontSize
                  : l.kind == SigLineKind.small
                      ? signatureSmallFontSize
                      : signatureFontSize,
              color: l.kind == SigLineKind.name
                  ? const Color(0xFF374151)
                  : l.kind == SigLineKind.small
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF6B7280),
            ),
          ),
      ],
    );
    final decoration = sig.format == 'accent'
        ? BoxDecoration(border: Border(left: BorderSide(color: Color(sig.accentColor), width: 3)))
        : const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFD1D5DB))));
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: decoration,
        padding: sig.format == 'accent'
            ? const EdgeInsets.only(left: 10)
            : const EdgeInsets.only(top: 6),
        child: column,
      ),
    );
  }

  Future<void> _showEditor({Signature? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final contentController = TextEditingController(text: existing?.content ?? '');
    final fieldControllers = <String, TextEditingController>{
      for (final key in signatureFieldLabels.keys)
        key: TextEditingController(text: existing?.fields[key] ?? ''),
    };
    var format = existing?.format ?? 'classic';
    var accent = existing?.accentColor ?? 0xFF2563EB;

    Signature build(String id) {
      final fields = {
        for (final e in fieldControllers.entries)
          if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
      };
      final draft = Signature(
        id: id,
        name: nameController.text.trim(),
        content: contentController.text,
        format: format,
        fields: format == 'text' ? const {} : fields,
        accentColor: accent,
      );
      if (format == 'text') return draft;
      return Signature(
        id: id,
        name: draft.name,
        content: signatureLines(draft).map((l) => l.text).join('\n'),
        format: format,
        fields: fields,
        accentColor: accent,
      );
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void refresh() => setDialogState(() {});
          final fieldKeys = _fieldsByFormat[format] ?? const <String>[];
          return AlertDialog(
            title: Text(existing == null ? 'Nouvelle signature' : 'Modifier la signature'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nom de la signature (ex : Pro, Perso)'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final e in _formats.entries)
                          ChoiceChip(
                            label: Text(e.value),
                            selected: format == e.key,
                            onSelected: (_) => setDialogState(() => format = e.key),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (format == 'text')
                      TextField(
                        controller: contentController,
                        decoration: const InputDecoration(labelText: 'Contenu de la signature'),
                        maxLines: 6,
                        onChanged: (_) => refresh(),
                      )
                    else ...[
                      for (final key in fieldKeys)
                        TextField(
                          controller: fieldControllers[key],
                          decoration: InputDecoration(labelText: signatureFieldLabels[key]),
                          maxLines: key == 'confidentiality' ? 3 : 1,
                          onChanged: (_) => refresh(),
                        ),
                      if (format == 'accent') ...[
                        const SizedBox(height: 12),
                        const Text('Couleur du trait'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final c in _accentColors)
                              GestureDetector(
                                onTap: () => setDialogState(() => accent = c),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Color(c),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: accent == c ? Colors.white : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    const Text('Aperçu', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    _preview(build('preview')),
                    const SizedBox(height: 6),
                    const Text(
                      'Taille et style imposés : petits caractères gras gris, comme toute signature.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
            ],
          );
        },
      ),
    );

    if (saved == true && nameController.text.trim().isNotEmpty) {
      if (existing == null) {
        await _storage.addSignature(build(_uuid.v4()));
      } else {
        await _storage.updateSignature(build(existing.id));
      }
      await _load();
    }
    nameController.dispose();
    contentController.dispose();
    for (final c in fieldControllers.values) {
      c.dispose();
    }
  }

  Future<void> _remove(String id) async {
    final signature = _signatures.firstWhere((s) => s.id == id);
    await deleteWithUndo(
      context: context,
      itemLabel: signature.name,
      onDelete: () async {
        await _storage.removeSignature(id);
        await _load();
      },
      onUndo: () async {
        await _storage.addSignature(signature);
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
            icon: Icons.edit_note,
            title: 'Signatures',
            actions: [
              FilledButton.icon(
                onPressed: () => _showEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle signature'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_signatures.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Rechercher une signature...',
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
                  options: const {'name': 'Nom'},
                  onSelected: _setSort,
                ),
              ],
            ),
          const SizedBox(height: 16),
          Expanded(
            child: _signatures.isEmpty
                ? const EmptyState(
                    icon: Icons.edit_note,
                    title: 'Aucune signature pour le moment',
                    subtitle: 'Créez une ou plusieurs signatures à ajouter à vos messages.',
                  )
                : ListView.builder(
                    itemCount: _visibleSignatures.length,
                    itemBuilder: (context, index) {
                      final signature = _visibleSignatures[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.edit_note),
                          title: Text(signature.name),
                          subtitle: Text(signature.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => _showEditor(existing: signature),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Supprimer',
                            onPressed: () => _remove(signature.id),
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

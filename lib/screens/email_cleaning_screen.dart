import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/email_cleaning_models.dart';
import '../services/cleaning_lists_storage.dart';
import '../services/email_cleaning_service.dart';
import '../services/export_helper.dart';
import '../services/import_history_storage.dart';
import 'package:uuid/uuid.dart';

class EmailCleaningScreen extends StatefulWidget {
  const EmailCleaningScreen({super.key});

  @override
  State<EmailCleaningScreen> createState() => _EmailCleaningScreenState();
}

class _EmailCleaningScreenState extends State<EmailCleaningScreen> {
  final _textController = TextEditingController();
  final _cleaningService = EmailCleaningService();
  final _listsStorage = CleaningListsStorage();

  bool _processing = false;
  CleaningResult? _result;
  String? _copiedMessage;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    if (_textController.text.trim().isEmpty) return;
    setState(() {
      _processing = true;
      _copiedMessage = null;
    });
    final genericPrefixes = await _listsStorage.loadGenericPrefixes();
    final disposableDomains = await _listsStorage.loadDisposableDomains();
    final result = await _cleaningService.process(CleaningInput(
      rawText: _textController.text,
      genericPrefixes: genericPrefixes,
      disposableDomains: disposableDomains,
    ));
    if (!mounted) return;
    setState(() {
      _result = result;
      _processing = false;
    });
    await ImportHistoryStorage().add(ImportLogEntry(
      id: const Uuid().v4(),
      type: 'email_cleaning',
      timestamp: DateTime.now(),
      summary: 'Analyse nettoyage : ${result.totalImported} importé(s), '
          '${result.valid.length} valide(s), ${result.invalid.length} invalide(s), '
          '${result.duplicatesRemoved} doublon(s) retiré(s)',
    ));
  }

  void _clearInput() {
    setState(() {
      _textController.clear();
      _result = null;
      _copiedMessage = null;
    });
  }

  Future<void> _copy(List<ClassifiedEmail> list, String label) async {
    final text = list.map((e) => e.normalized).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copiedMessage = '${list.length} adresse(s) ($label) copiée(s) dans le presse-papiers.');
  }

  Future<void> _showExportFeedback(Future<bool> Function() export) async {
    try {
      final exported = await export();
      if (!mounted || !exported) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export terminé.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'export : ${e.toString()}')),
      );
    }
  }

  Future<void> _exportTxt(List<ClassifiedEmail> list, String suggestedName) async {
    final text = list.map((e) => e.normalized).join('\n');
    await _showExportFeedback(
      () => exportTextFile(content: text, suggestedFileName: suggestedName, extension: 'txt'),
    );
  }

  Future<void> _exportCsv(CleaningResult result, String suggestedName) async {
    final buffer = StringBuffer('Email;Pays;Domaine;Statut\n');
    void writeRows(List<ClassifiedEmail> list, String statut) {
      for (final e in list) {
        buffer.writeln('${e.normalized};${e.country ?? ''};${e.domain};$statut');
      }
    }
    writeRows(result.valid, 'Valide');
    writeRows(result.invalid, 'Invalide');
    writeRows(result.generic, 'Generique/technique');
    writeRows(result.disposable, 'Domaine jetable');

    await _showExportFeedback(
      () => exportTextFile(content: buffer.toString(), suggestedFileName: suggestedName, extension: 'csv'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nettoyage et classement d\'e-mails', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Collez une grande liste d\'adresses (une par ligne, ou séparées par virgules/points-virgules). '
            'Traitement 100% local, aucune donnée envoyée en ligne.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Coller vos e-mails ici',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _processing ? null : _analyze,
                icon: _processing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                label: Text(_processing ? 'Analyse…' : 'Analyser'),
              ),
              OutlinedButton.icon(
                onPressed: _clearInput,
                icon: const Icon(Icons.clear_all),
                label: const Text('Nettoyer le champ'),
              ),
            ],
          ),
          if (_copiedMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_copiedMessage!, style: const TextStyle(color: Colors.green)),
            ),
          if (result != null) ...[
            const SizedBox(height: 28),
            _StatsSummary(result: result),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _copy(result.valid, 'valides'),
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Copier toutes les adresses valides'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportTxt(result.valid, 'emails_valides'),
                  icon: const Icon(Icons.download),
                  label: const Text('Export TXT (valides)'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportCsv(result, 'emails_classes'),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Export CSV (tout)'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Résultats par catégorie', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _CategoryTile(
              title: 'Invalides',
              count: result.invalid.length,
              color: Colors.red,
              emails: result.invalid,
              onCopy: () => _copy(result.invalid, 'invalides'),
            ),
            _CategoryTile(
              title: 'Génériques / techniques',
              count: result.generic.length,
              color: Colors.orange,
              emails: result.generic,
              onCopy: () => _copy(result.generic, 'génériques'),
            ),
            _CategoryTile(
              title: 'Domaines jetables',
              count: result.disposable.length,
              color: Colors.deepOrange,
              emails: result.disposable,
              onCopy: () => _copy(result.disposable, 'domaines jetables'),
            ),
            if (result.byProvider.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Par fournisseur (Gmail, Outlook, Yahoo...)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...(result.byProvider.entries.toList()
                    ..sort((a, b) => b.value.length.compareTo(a.value.length)))
                  .map((entry) => _CategoryTile(
                        title: entry.key,
                        count: entry.value.length,
                        color: Colors.indigo,
                        emails: entry.value,
                        onCopy: () => _copy(entry.value, entry.key),
                      )),
            ],
            _CategoryTile(
              title: 'Autre / pays vraiment indéterminé',
              count: result.undeterminedCountry.length,
              color: Colors.blueGrey,
              emails: result.undeterminedCountry,
              onCopy: () => _copy(result.undeterminedCountry, 'pays indéterminé'),
            ),
            const SizedBox(height: 12),
            if (result.byCountry.isNotEmpty) ...[
              Text('Par pays', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...(result.byCountry.entries.toList()
                    ..sort((a, b) => b.value.length.compareTo(a.value.length)))
                  .map((entry) => _CategoryTile(
                        title: entry.key,
                        count: entry.value.length,
                        color: Colors.green,
                        emails: entry.value,
                        onCopy: () => _copy(entry.value, entry.key),
                      )),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatsSummary extends StatelessWidget {
  final CleaningResult result;
  const _StatsSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    final countryCount = result.byCountry.values.fold<int>(0, (sum, list) => sum + list.length);
    final items = <String, int>{
      'Total importé': result.totalImported,
      'Doublons retirés': result.duplicatesRemoved,
      'Valides': result.valid.length,
      'Invalides': result.invalid.length,
      'Génériques/techniques': result.generic.length,
      'Domaines jetables': result.disposable.length,
      'Pays identifiés': countryCount,
      'Pays indéterminé': result.undeterminedCountry.length,
    };
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.entries
          .map((e) => Container(
                width: 170,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e.value}', style: Theme.of(context).textTheme.titleLarge),
                    Text(e.key, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final List<ClassifiedEmail> emails;
  final VoidCallback onCopy;

  const _CategoryTile({
    required this.title,
    required this.count,
    required this.color,
    required this.emails,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(Icons.circle, color: color, size: 12)),
        title: Text('$title — $count adresse(s)'),
        trailing: TextButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copier'),
        ),
        children: [
          SizedBox(
            height: 150,
            child: ListView.builder(
              itemCount: emails.length > 200 ? 200 : emails.length,
              itemBuilder: (context, index) => ListTile(
                dense: true,
                title: Text(emails[index].normalized),
              ),
            ),
          ),
          if (emails.length > 200)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('… et ${emails.length - 200} de plus (utilisez Copier ou Export pour tout obtenir).',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ),
        ],
      ),
    );
  }
}

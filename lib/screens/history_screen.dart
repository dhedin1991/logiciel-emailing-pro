import 'package:flutter/material.dart';
import '../models/sent_email_log.dart';
import '../services/history_storage.dart';
import '../widgets/empty_state.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _storage = HistoryStorage();
  bool _loading = true;
  List<SentEmailLog> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _storage.loadAll();
    setState(() {
      _entries = entries;
      _loading = false;
    });
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
              Expanded(child: Text('Historique (${_entries.length})', style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),
          const SizedBox(height: 16),
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
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            entry.success ? Icons.check_circle : Icons.error,
                            color: entry.success ? Colors.green : Colors.red,
                          ),
                          title: Text(entry.subject.isEmpty ? '(sans objet)' : entry.subject),
                          subtitle: Text(
                              '${entry.to} — ${entry.sentAt.day}/${entry.sentAt.month}/${entry.sentAt.year} '
                              '${entry.sentAt.hour.toString().padLeft(2, '0')}:${entry.sentAt.minute.toString().padLeft(2, '0')}'
                              '${entry.errorMessage != null ? '\n${entry.errorMessage}' : ''}'),
                          isThreeLine: entry.errorMessage != null,
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

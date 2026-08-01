import 'package:flutter/material.dart';
import '../services/language_tool_service.dart';
import '../services/message_analysis_service.dart';

Future<void> showMessageAnalysisDialog(
  BuildContext context, {
  required String subject,
  required String body,
}) async {
  showDialog(
    context: context,
    builder: (context) => _AnalysisDialog(subject: subject, body: body),
  );
}

class _AnalysisDialog extends StatefulWidget {
  final String subject;
  final String body;
  const _AnalysisDialog({required this.subject, required this.body});

  @override
  State<_AnalysisDialog> createState() => _AnalysisDialogState();
}

class _AnalysisDialogState extends State<_AnalysisDialog> {
  final _languageTool = LanguageToolService();
  final _analysisService = MessageAnalysisService();

  bool _loading = true;
  String? _error;
  List<LanguageToolMatch> _matches = [];
  MessageAnalysisResult? _result;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final result = _analysisService.analyze(subject: widget.subject, body: widget.body);
    List<LanguageToolMatch> matches = [];
    String? error;
    try {
      matches = await _languageTool.checkText('${widget.subject}\n\n${widget.body}');
    } catch (e) {
      error = 'Correction orthographe/grammaire indisponible pour le moment (service externe injoignable).';
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _matches = matches;
      _error = error;
      _loading = false;
    });
  }

  Color _scoreColor(int score, {bool inverse = false}) {
    final good = inverse ? score < 30 : score >= 70;
    final medium = inverse ? score < 60 : score >= 40;
    if (good) return Colors.green;
    if (medium) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Analyse du message'),
      content: SizedBox(
        width: 550,
        child: _loading
            ? const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ScoreTile(
                            label: 'Score de qualité',
                            value: _result!.qualityScore,
                            color: _scoreColor(_result!.qualityScore),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ScoreTile(
                            label: 'Risque spam',
                            value: _result!.spamRiskScore,
                            color: _scoreColor(_result!.spamRiskScore, inverse: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Améliorations possibles', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    ..._result!.qualityRemarks.map((r) => Text('• $r')),
                    const SizedBox(height: 16),
                    Text('Risque indésirable (spam)', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    ..._result!.spamRemarks.map((r) => Text('• $r')),
                    const SizedBox(height: 4),
                    Text(
                      'Cette analyse ne garantit jamais l\'arrivée en boîte de réception principale.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 16),
                    Text('Orthographe et grammaire', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red))
                    else if (_matches.isEmpty)
                      const Text('Aucune faute détectée.')
                    else
                      ..._matches.take(15).map((m) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '• ${m.shortMessage}'
                              '${m.suggestions.isNotEmpty ? ' → suggestion : ${m.suggestions.join(', ')}' : ''}',
                            ),
                          )),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
      ],
    );
  }
}

class _ScoreTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _ScoreTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Text('$value/100', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

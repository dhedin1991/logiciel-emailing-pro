import 'package:flutter/material.dart';

Future<bool> showEmailPreviewDialog(
  BuildContext context, {
  required String from,
  required String to,
  String? cc,
  required String subject,
  required String body,
  required List<String> attachmentPaths,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Aperçu avant envoi'),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PreviewRow(label: 'De', value: from),
              _PreviewRow(label: 'À', value: to.isEmpty ? '(non renseigné)' : to),
              if (cc != null && cc.trim().isNotEmpty) _PreviewRow(label: 'Copie', value: cc),
              _PreviewRow(label: 'Objet', value: subject.isEmpty ? '(sans objet)' : subject),
              if (attachmentPaths.isNotEmpty)
                _PreviewRow(
                  label: 'Pièces jointes',
                  value: attachmentPaths.map((p) => p.split('/').last.split('\\').last).join(', '),
                ),
              const Divider(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(body.isEmpty ? '(message vide)' : body),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retour à l\'édition')),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.send),
          label: const Text('Lancer l\'envoi'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _PreviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

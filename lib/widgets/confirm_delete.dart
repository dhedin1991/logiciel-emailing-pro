import 'package:flutter/material.dart';

Future<bool> confirmDelete(BuildContext context, String itemLabel) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirmer la suppression'),
      content: Text('Supprimer "$itemLabel" ? Cette action est irréversible.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return result ?? false;
}

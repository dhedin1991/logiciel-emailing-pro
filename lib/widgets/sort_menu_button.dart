import 'package:flutter/material.dart';

/// Bouton "Trier par" : ouvre un menu avec les colonnes disponibles,
/// affiche la colonne active et son sens (▲/▼), et permet de re-cliquer
/// sur la même colonne pour inverser le sens.
class SortMenuButton extends StatelessWidget {
  final String currentField;
  final bool ascending;
  final Map<String, String> options;
  final ValueChanged<String> onSelected;

  const SortMenuButton({
    super.key,
    required this.currentField,
    required this.ascending,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => options.entries
          .map((e) => PopupMenuItem<String>(
                value: e.key,
                child: Row(
                  children: [
                    if (e.key == currentField)
                      Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 16)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(e.value),
                  ],
                ),
              ))
          .toList(),
      child: Chip(
        avatar: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
        label: Text('Trier : ${options[currentField] ?? ''}'),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// En-tête de section standard : icône + titre + actions (boutons).
///
/// Corrige un bug d'affichage important sur petits écrans (Android) : avec
/// un `Row` classique contenant `Expanded(child: Text(titre))` suivi de
/// plusieurs boutons, dès que les boutons ne tiennent plus sur la largeur
/// disponible, la zone du titre est compressée à une largeur quasi nulle —
/// le texte se retrouve alors affiché une lettre par ligne, verticalement,
/// sur toute la hauteur de l'écran.
///
/// En utilisant `Wrap` au lieu de `Row`, le titre garde toujours sa largeur
/// naturelle, et les boutons qui ne tiennent pas passent simplement à la
/// ligne suivante. Sur un écran large (Windows), tout tient sur une seule
/// ligne : le rendu reste visuellement identique à l'ancien `Row`.
class ScreenHeader extends StatelessWidget {
  final IconData? icon;
  final String title;
  final List<Widget> actions;

  const ScreenHeader({
    super.key,
    this.icon,
    required this.title,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
            ],
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        if (actions.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
      ],
    );
  }
}

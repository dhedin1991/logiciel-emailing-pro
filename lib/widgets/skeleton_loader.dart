import 'package:flutter/material.dart';

/// Effet "squelette" (silhouettes grisées animées) affiché pendant un
/// chargement, à la place d'un simple rond qui tourne. Implémenté sans
/// dépendance externe pour ne pas ajouter de risque de compilation.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.35 + 0.25 * _controller.value),
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}

/// Liste de lignes "squelette" imitant des cartes de liste (avatar rond +
/// deux lignes de texte), pour remplacer un simple indicateur de chargement
/// sur les écrans Contacts, Historique, Modèles, etc.
class SkeletonListLoader extends StatelessWidget {
  final int itemCount;
  const SkeletonListLoader({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            SkeletonBox(width: 40, height: 40, borderRadius: const BorderRadius.all(Radius.circular(20))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 160 + (index % 3) * 40, height: 14),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 100 + (index % 4) * 30, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

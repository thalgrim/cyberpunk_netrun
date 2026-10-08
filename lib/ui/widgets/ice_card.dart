import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../theme/app_theme.dart';
import 'common.dart';

/// Barre de REZ, avec libellé accessible.
class RezBar extends StatelessWidget {
  const RezBar({super.key, required this.rez, required this.max, this.color});
  final int rez;
  final int max;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ratio = max <= 0 ? 0.0 : (rez / max).clamp(0.0, 1.0);
    return Semantics(
      label: 'REZ $rez sur $max',
      excludeSemantics: true,
      child: Row(
        children: [
          Text('REZ', style: Theme.of(context).textTheme.labelSmall!.copyWith(color: c.muted)),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                color: color ?? c.red,
                backgroundColor: c.panel2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$rez/$max', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// Statistique courte « PER 6 ».
class StatChip extends StatelessWidget {
  const StatChip(this.label, this.value, {super.key});
  final String label;
  final Object value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: c.panel2, borderRadius: BorderRadius.circular(6)),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(color: c.muted),
            ),
            TextSpan(
              text: '$value',
              style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

/// Fiche d'un GLACE ou d'un Démon.
class IceCard extends StatelessWidget {
  const IceCard({
    super.key,
    this.ice,
    this.demon,
    required this.state,
    required this.rez,
    this.actions = const [],
    this.note,
  });

  final IceDef? ice;
  final DemonDef? demon;

  /// État lisible : « En chasse », « En attente », « Dérezzé », « Actif ».
  final String state;
  final int rez;
  final List<Widget> actions;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final name = ice?.name ?? 'Démon ${demon!.name}';
    final cls = ice != null ? 'GLACE ${ice!.cls}' : 'Démon';
    final max = ice?.rez ?? demon!.rez;
    final color = ice != null ? c.red : AppColors.demon;
    final down = state == 'Dérezzé';
    return AccentCard(
      color: down ? c.muted : color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: t.titleMedium)),
              Tag(state, color: down ? c.muted : color, filled: !down && state != 'En attente'),
            ],
          ),
          Text(cls, style: t.bodySmall),
          const SizedBox(height: 8),
          RezBar(rez: rez, max: max, color: color),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ice != null
                ? [
                    StatChip('PER', ice!.per),
                    StatChip('VIT', ice!.vit),
                    StatChip('ATT', ice!.att),
                    StatChip('DÉF', ice!.def),
                    StatChip('REZ', ice!.rez),
                    if (ice!.dmg != null) StatChip('Dégâts', ice!.dmg!),
                  ]
                : [
                    StatChip('REZ', demon!.rez),
                    StatChip('Interface', demon!.iface),
                    StatChip('Actions', demon!.actions),
                  ],
          ),
          if (ice != null) ...[
            const SizedBox(height: 8),
            Text(ice!.effect, style: t.bodyMedium),
          ] else ...[
            const SizedBox(height: 8),
            Text('Élimination : Interface + d10 contre ta défense ; 1d6 au cerveau s\'il touche.', style: t.bodyMedium),
          ],
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(
              note!,
              style: t.bodyMedium!.copyWith(color: c.warn, fontWeight: FontWeight.w600),
            ),
          ],
          if (actions.isNotEmpty) ...[const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: actions)],
        ],
      ),
    );
  }
}

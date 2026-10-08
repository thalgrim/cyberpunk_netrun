import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../engine/netrun_engine.dart';
import '../../theme/app_theme.dart';
import 'common.dart';
import 'ice_card.dart';

/// Combat : GLACE en chasse et Démons actifs.
class CombatPanel extends StatelessWidget {
  const CombatPanel({super.key, required this.engine, required this.onZap, required this.onSlide});

  final NetrunEngine engine;
  final void Function(String targetKey, String? programId) onZap;
  final void Function(String iceKey) onSlide;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enemies = engine.enemies();
    final weapons = engine.deck.items
        .where((i) => i.prog?.type == ProgType.offensif && i.prog!.cls == antiprogramme && i.prog!.iceDmg != null)
        .toList();
    final malus = engine.slideMalus;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.red, width: 2),
        borderRadius: BorderRadius.circular(14),
        color: c.redPale.withValues(alpha: 0.35),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: c.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text('COMBAT', style: Theme.of(context).textTheme.titleMedium!.copyWith(color: c.red)),
              ),
              Text(
                '${enemies.length} adversaire${enemies.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          for (final e in enemies) ...[
            const SizedBox(height: 10),
            IceCard(
              ice: e.iceDef,
              demon: e.demonDef,
              state: e.isDemon ? 'Actif' : 'En chasse',
              rez: e.rez,
              actions: [
                FilledButton(onPressed: () => onZap(e.key, null), child: const Text('Élimination (1d6)')),
                for (final w in weapons)
                  FilledButton.tonal(
                    onPressed: () => onZap(e.key, w.id),
                    child: Text('${w.n} (+${w.prog!.att}, ${w.prog!.iceDmg})'),
                  ),
                if (!e.isDemon)
                  OutlinedButton(
                    onPressed: engine.s.slid ? null : () => onSlide(e.key),
                    child: Text(
                      'Glissement (PER ${e.iceDef!.per}${malus < 0 ? ', malus $malus' : ''})'
                      '${engine.s.slid ? ' : déjà tenté' : ''}',
                    ),
                  ),
              ],
            ),
          ],
          if (enemies.any((e) => e.isDemon))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Pas de Glissement possible contre un Démon.', style: Theme.of(context).textTheme.bodySmall),
            ),
          if (weapons.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Aucun programme antiprogramme installé (Sabre, Bannissement).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 4),
          const SectionTitle('Chaque attaque coûte 1 action virtuelle'),
        ],
      ),
    );
  }
}

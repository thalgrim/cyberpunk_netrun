import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/architectures_state.dart';
import '../../state/deck_state.dart';
import '../../state/run_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/known_map.dart';
import '../widgets/log_list.dart';

/// Onglet Suivi (MJ) : progression du netrunner sur l'architecture proposée.
class GmTrackingScreen extends StatelessWidget {
  const GmTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<ArchitecturesState>();
    final ds = context.watch<DeckState>();
    final rc = context.watch<RunController>();
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    final e = rc.engine();
    if (e == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Aucune architecture proposée.', style: t.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Propose une architecture au joueur depuis l\'onglet Architectures pour suivre sa progression ici.',
            style: t.bodyLarge,
          ),
        ],
      );
    }
    final s = e.s;
    final a = e.archi;
    final d = ds.deck;
    final position = switch (s.status) {
      'on' => s.pos == null ? 'Point d\'accès' : 'Étage ${e.tree.depth(s.pos!)}',
      'out' => 'Déconnecté',
      _ => 'Pas connecté',
    };
    final chasing = e.enemies();

    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label : ',
              style: TextStyle(color: c.muted),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(a.name, style: t.headlineSmall),
        if (a.lieu.isNotEmpty) Text(a.lieu, style: t.bodyMedium!.copyWith(color: c.muted)),
        const SectionTitle('Netrunner'),
        line('Position', position),
        if (s.isOn)
          line(
            'Tour',
            '${s.turn} (${s.actions} action${s.actions > 1 ? 's' : ''} restante${s.actions > 1 ? 's' : ''})',
          ),
        line('PS', s.ps == null ? 'non renseignés' : '${s.ps}${d.me.psMax != null ? '/${d.me.psMax}' : ''}'),
        line('Rang d\'Interface', d.me.rank?.toString() ?? 'non renseigné'),
        if (s.burning) line('État', 'En feu'),
        if (s.kraken > 0) line('Kraken', 'progression et déconnexion bloquées'),
        if (s.masq != null) line('Masquage', '${s.masq}'),
        if (s.virus != null) line('Virus', 'en place, SD ${s.virus} pour le détruire'),
        line('Console', d.items.isEmpty ? 'vide' : d.items.map((i) => e.isOn(i) ? '${i.n} (rezzé)' : i.n).join(', ')),
        if (d.saved.isNotEmpty) line('Disque dur', d.saved.map((i) => i.n).join(', ')),
        line(
          'En chasse',
          chasing.isEmpty ? 'aucun' : chasing.map((x) => '${x.name} (REZ ${x.rez}/${x.rezMax})').join(', '),
        ),
        const SectionTitle('Progression'),
        KnownMap(archi: a, run: s, gmView: true),
        const SectionTitle('Journal'),
        LogList(entries: s.log),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          icon: const Icon(Icons.restart_alt),
          label: const Text('Réinitialiser la run'),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.red,
            side: BorderSide(color: c.red),
          ),
          onPressed: () async {
            final ok = await confirmDialog(
              context,
              title: 'Réinitialiser la run ?',
              message:
                  'Position, étages découverts, GLACE, PS et journal seront remis à zéro. '
                  'La cyberconsole du joueur n\'est pas modifiée.',
              confirmLabel: 'Réinitialiser',
            );
            if (ok) rc.reset(a.id);
          },
        ),
      ],
    );
  }
}

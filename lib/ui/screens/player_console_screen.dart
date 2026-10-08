import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/catalog.dart';
import '../../models/deck.dart';
import '../../state/deck_state.dart';
import '../../state/run_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

/// Onglet Cyberconsole : profil du netrunner et contenu de la console.
class PlayerConsoleScreen extends StatelessWidget {
  const PlayerConsoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DeckState>();
    final rc = context.watch<RunController>();
    final d = ds.deck;
    final run = rc.run;
    final online = run?.isOn ?? false;
    final c = context.colors;
    final t = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (online)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.netPale,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.net),
            ),
            child: Text(
              'Tu es connecté : déconnecte-toi pour installer ou retirer des éléments. '
              'Rezze tes programmes depuis l\'onglet Netrun.',
              style: t.bodyLarge,
            ),
          ),
        const SectionTitle('Profil'),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('rank-${d.me.rank}'),
                initialValue: d.me.rank,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Rang d\'Interface'),
                items: [
                  for (var r = 0; r <= 10; r++)
                    DropdownMenuItem(value: r, child: Text('$r (${apt(r)} action${apt(r) > 1 ? 's' : ''})')),
                ],
                onChanged: online ? null : (v) => ds.setRank(v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LiveTextField(
                key: const ValueKey('vit'),
                value: d.me.vit.toString(),
                label: 'Autre bonus de VIT',
                number: true,
                enabled: !online,
                onChanged: (v) => ds.setVit(int.tryParse(v.trim()) ?? 0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: LiveTextField(
                key: const ValueKey('psMax'),
                value: d.me.psMax?.toString() ?? '',
                label: 'PS max',
                number: true,
                onChanged: (v) => ds.setPsMax(int.tryParse(v.trim())),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: run == null
                  ? const SizedBox.shrink()
                  : LiveTextField(
                      key: ValueKey('ps-${rc.archi?.id}'),
                      value: run.ps?.toString() ?? '',
                      label: 'PS actuels',
                      number: true,
                      onChanged: (v) => rc.setPs(int.tryParse(v.trim())),
                    ),
            ),
          ],
        ),
        const SectionTitle('Modèle de console'),
        DropdownButtonFormField<String>(
          key: ValueKey('model-${d.type}'),
          initialValue: deckModels.containsKey(d.type) ? d.type : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Modèle'),
          items: [
            for (final e in deckModels.entries)
              DropdownMenuItem(
                value: e.key,
                child: Text(e.value == null ? e.key : '${e.key} (${e.value} emplacements)'),
              ),
          ],
          onChanged: online
              ? null
              : (v) {
                  if (v != null) ds.setModel(v);
                },
        ),
        if (d.type == customDeck) ...[
          const SizedBox(height: 12),
          LiveTextField(
            key: const ValueKey('slots'),
            value: d.slots.toString(),
            label: 'Emplacements',
            number: true,
            enabled: !online,
            onChanged: (v) {
              final n = int.tryParse(v.trim());
              if (n != null) ds.setSlots(n);
            },
          ),
        ],
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Option cyberbras (+1)'),
          value: d.arm,
          onChanged: online ? null : (v) => ds.setArm(v ?? false),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Combinaison connectée (+1 matériel)'),
          value: d.suit,
          onChanged: online ? null : (v) => ds.setSuit(v ?? false),
        ),
        Row(
          children: [
            Text('${d.used}/${d.total} emplacements', style: t.titleMedium),
            if (d.used > d.total) ...[const SizedBox(width: 8), Tag('Dépassement', color: c.red)],
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Installer'),
              onPressed: online ? null : () => _installSheet(context),
            ),
          ],
        ),
        const SectionTitle('Éléments installés'),
        if (d.items.isEmpty) Text('Aucun élément installé.', style: t.bodyMedium),
        for (final item in d.items) ...[
          _ItemCard(
            item: item,
            action: online ? null : OutlinedButton(onPressed: () => ds.remove(item.id), child: const Text('Retirer')),
          ),
          const SizedBox(height: 8),
        ],
        if (d.saved.isNotEmpty) ...[
          const SectionTitle('Sur le disque dur de sauvegarde'),
          Text('Programmes détruits sauvés : ${d.saved.map((i) => i.n).join(', ')}.', style: t.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(onPressed: online ? null : () => _restore(context), child: const Text('Réinstaller')),
            ],
          ),
        ],
      ],
    );
  }

  void _restore(BuildContext context) {
    final rc = context.read<RunController>();
    final ds = context.read<DeckState>();
    if (rc.archi != null) {
      showToast(context, rc.act((e) => e.restore()));
      return;
    }
    // Sans architecture proposée : réinstallation directe (hors connexion, gratuite).
    final d = ds.deck;
    final restored = <String>[];
    for (final item in [...d.saved]) {
      if (d.canAdd(item)) {
        d.items.add(item);
        d.saved.remove(item);
        restored.add(item.n);
      }
    }
    ds.changed();
    showToast(context, restored.isEmpty ? 'Plus assez d\'emplacements.' : 'Réinstallé : ${restored.join(', ')}.');
  }

  void _installSheet(BuildContext context) {
    final ds = context.read<DeckState>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        final c = ctx.colors;
        // En-tête de catégorie : bandeau teinté de la couleur de la catégorie.
        Widget group(String title, Color color) => Container(
          margin: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: color, width: 5)),
          ),
          child: Semantics(
            header: true,
            child: Text(title.toUpperCase(), style: t.labelLarge!.copyWith(color: color, letterSpacing: 1.2)),
          ),
        );
        // Élément : carte avec bordure gauche et étiquette de la couleur de la catégorie.
        Widget tile(String k, String n, String sub, int cost, Color color, String type) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Material(
            color: c.panel,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: c.border),
            ),
            child: InkWell(
              onTap: () {
                Navigator.pop(ctx);
                if (!ds.install(k, n)) showToast(context, 'Plus assez d\'emplacements.');
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: color, width: 5)),
                ),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(n, style: t.titleSmall),
                              Tag(type, color: color),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(sub, style: t.bodyMedium!.copyWith(color: c.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$cost empl.', style: t.labelMedium),
                  ],
                ),
              ),
            ),
          ),
        );
        String progSub(ProgramDef p) =>
            '${p.cls.isEmpty ? '' : '${p.cls} · '}ATT ${p.att} · DÉF ${p.def} · REZ ${p.rez}\n${p.effect}';
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            children: [
              for (final type in ProgType.values) ...[
                group(type.label, progTypeColor(c, type)),
                for (final p in programList.where((p) => p.type == type))
                  tile('prog', p.name, progSub(p), 1, progTypeColor(c, type), type.label),
              ],
              group('GLACE (2 emplacements)', c.red),
              for (final i in iceList)
                tile(
                  'ice',
                  i.name,
                  '${i.cls} · PER ${i.per} · VIT ${i.vit} · ATT ${i.att} · DÉF ${i.def} · REZ ${i.rez}',
                  iceSlotCost,
                  c.red,
                  'GLACE',
                ),
              group('Matériel', c.muted),
              for (final h in hardwareList) tile('hw', h.name, h.effect, h.slots, c.muted, 'Matériel'),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, this.action});
  final DeckItem item;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final p = item.prog;
    final i = item.ice;
    final h = item.hw;
    final stats = p != null
        ? '${p.cls.isEmpty ? '' : '${p.cls} · '}ATT ${p.att} · DÉF ${p.def} · REZ ${p.rez}'
              '${p.bonusLabel.isEmpty ? '' : ' · ${p.bonusLabel}'}'
        : i != null
        ? '${i.cls} · PER ${i.per} · VIT ${i.vit} · ATT ${i.att} · DÉF ${i.def} · REZ ${i.rez}'
        : '${h?.slots ?? 1} emplacement${(h?.slots ?? 1) > 1 ? 's' : ''}';
    final effect = p?.effect ?? i?.effect ?? h?.effect ?? '';
    return AccentCard(
      color: itemColor(c, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(item.n, style: t.titleSmall),
                    Tag(item.typeLabel, color: itemColor(c, item)),
                    Text('${item.cost} empl.', style: t.bodySmall),
                  ],
                ),
              ),
              ?action,
            ],
          ),
          Text(stats, style: t.bodySmall),
          const SizedBox(height: 2),
          Text(effect, style: t.bodyMedium),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../engine/floor_tree.dart';
import '../../models/architecture.dart';
import '../../models/run_state.dart';
import '../../theme/app_theme.dart';
import 'common.dart';

/// Arbre des étages connus (joueur) ou de toute l'architecture (suivi MJ).
class KnownMap extends StatelessWidget {
  const KnownMap({super.key, required this.archi, required this.run, this.gmView = false});

  final Architecture archi;
  final RunState run;

  /// Vue MJ : tous les étages, avec leur état, sans « Porte fermée ».
  final bool gmView;

  @override
  Widget build(BuildContext context) {
    final full = FloorTree(archi.floors);
    final known = gmView
        ? archi.floors
        : archi.floors.where((f) => run.seen.contains(f.id) || run.carto.contains(f.id)).toList();
    final tree = FloorTree(known);
    final online = run.isOn;
    final children = <Widget>[_AccessPoint(here: online && run.pos == null)];
    if (known.isEmpty && !gmView) children.add(const _ClosedDoor(level: 0));
    for (final row in tree.rows()) {
      final f = row.floor;
      Widget tile = _FloorNode(
        floor: f,
        depth: full.depth(f.id),
        run: run,
        archi: archi,
        here: online && run.pos == f.id,
        gmView: gmView,
      );
      if (row.branchFrom != null) {
        tile = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                row.branchFrom == 0
                    ? 'Embranchement depuis le point d\'accès'
                    : 'Embranchement depuis l\'étage ${full.depth(full.parentId(f.id) ?? '')}',
                style: Theme.of(context).textTheme.labelSmall!.copyWith(color: context.colors.net),
              ),
            ),
            tile,
          ],
        );
      }
      children.add(_indent(context, row.level, tile));
      if (!gmView && tree.kids(f.id).isEmpty) children.add(_ClosedDoor(level: row.level));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _indent(BuildContext context, int level, Widget child) {
    if (level == 0) return Padding(padding: const EdgeInsets.only(bottom: 6), child: child);
    return Padding(
      padding: EdgeInsets.only(left: 14.0 * level, bottom: 6),
      child: DashedBox(color: context.colors.net, child: child),
    );
  }
}

class _AccessPoint extends StatelessWidget {
  const _AccessPoint({required this.here});
  final bool here;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: here ? c.red : c.border, width: here ? 2 : 1),
      ),
      child: Row(
        children: [
          Text('AP', style: Theme.of(context).textTheme.titleMedium!.copyWith(color: c.net)),
          const SizedBox(width: 10),
          const Expanded(child: Text('Point d\'accès')),
          if (here) Tag('Tu es ici', color: c.red, filled: true),
        ],
      ),
    );
  }
}

class _ClosedDoor extends StatelessWidget {
  const _ClosedDoor({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(left: 14.0 * level + (level > 0 ? 10 : 0), bottom: 8),
      child: DashedBox(
        color: c.border,
        allSides: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: c.muted),
              const SizedBox(width: 8),
              Text('Porte fermée', style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: c.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloorNode extends StatelessWidget {
  const _FloorNode({
    required this.floor,
    required this.depth,
    required this.run,
    required this.archi,
    required this.here,
    required this.gmView,
  });

  final Floor floor;
  final int depth;
  final RunState run;
  final Architecture archi;
  final bool here;
  final bool gmView;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final f = floor;
    final seen = run.seen.contains(f.id);
    final done = run.done.contains(f.id);
    final cartoOnly = !seen && run.carto.contains(f.id);
    final kindColor = c.floorColor(f.kind);
    final tags = <Widget>[
      if (here) Tag('Tu es ici', color: c.red, filled: true),
      if (done) Tag('Réussi', color: c.ok),
      if (seen && !done && !here) Tag('Visité', color: c.muted),
      if (cartoOnly) Tag('Cartographié', color: c.net),
      if (gmView && !seen && !cartoOnly) Tag('Inconnu', color: c.muted),
    ];
    final summary = (seen || gmView) ? floorSummary(f) : kindName(f.kind);
    final label = f.label.trim();
    final title = Row(
      children: [
        Text('É.${two(depth)}', style: t.titleSmall!.copyWith(color: kindColor)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(summary, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(label, style: t.bodyMedium),
          ),
        if (gmView) ..._gmDetails(context),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 6, runSpacing: 4, children: tags),
          ),
        if (!gmView && done && f.info.trim().isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              expandedAlignment: Alignment.centerLeft,
              title: Text('Ce que tu as obtenu', style: t.labelLarge!.copyWith(color: c.net)),
              children: [Text(f.info.trim(), style: t.bodyMedium)],
            ),
          ),
      ],
    );
    if (cartoOnly && !gmView) {
      return DashedBox(
        color: kindColor,
        allSides: true,
        child: Padding(padding: const EdgeInsets.all(10), child: body),
      );
    }
    return Opacity(
      opacity: (!gmView && seen && !here) ? 0.75 : 1,
      child: AccentCard(
        color: kindColor,
        borderColor: here ? c.red : null,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: body,
      ),
    );
  }

  List<Widget> _gmDetails(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    final out = <Widget>[];
    if (FloorTree.hasTest(floor)) {
      out.add(Text('SD ${floor.sd ?? archi.difficulty.sd}', style: t.bodySmall));
    }
    if (floor.kind == FloorKind.glace) {
      for (var i = 0; i < floor.ice.length; i++) {
        final st = run.ice[FloorTree.iceKey(floor.id, i)];
        final def = iceByName[floor.ice[i]];
        final rez = st?.rez ?? def?.rez ?? 0;
        final state = switch (st?.st) {
          'chasing' => 'en chasse',
          'down' => 'dérezzé',
          _ => st == null ? 'pas encore rencontré' : 'en attente',
        };
        out.add(
          Text(
            '${floor.ice[i]} : $state (REZ $rez)',
            style: t.bodyMedium!.copyWith(color: st?.chasing == true ? c.red : null),
          ),
        );
      }
    }
    if (floor.kind == FloorKind.demon) {
      final st = run.demon[floor.id];
      final state = switch (st?.st) {
        'active' => 'actif',
        'down' => 'dérezzé',
        _ => 'en attente',
      };
      out.add(
        Text(
          'Démon ${floor.demon} : $state (REZ ${st?.rez ?? demonByName[floor.demon]?.rez ?? 0})',
          style: t.bodyMedium,
        ),
      );
    }
    return out;
  }
}

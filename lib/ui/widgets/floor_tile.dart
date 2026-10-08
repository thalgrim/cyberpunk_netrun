import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/catalog.dart';
import '../../engine/floor_tree.dart';
import '../../models/architecture.dart';
import '../../state/architectures_state.dart';
import '../../theme/app_theme.dart';
import 'common.dart';
import 'confirm_dialog.dart';

/// Carte repliable d'un étage dans l'éditeur MJ.
class FloorTile extends StatelessWidget {
  const FloorTile({
    super.key,
    required this.archi,
    required this.floor,
    required this.depth,
    required this.hasKids,
    required this.expanded,
    required this.onToggle,
    required this.onCreated,
  });

  final Architecture archi;
  final Floor floor;
  final int depth;
  final bool hasKids;
  final bool expanded;
  final VoidCallback onToggle;

  /// Un nouvel étage a été créé (pour le déplier).
  final ValueChanged<String> onCreated;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final f = floor;
    final hasSd = floorKinds[f.kind]!.hasSd;
    final sd = f.sd ?? (f.kind == FloorKind.vide ? null : archi.difficulty.sd);
    return AccentCard(
      color: c.floorColor(f.kind),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: [
                    Text('É.${two(depth)}', style: t.titleMedium!.copyWith(color: c.floorColor(f.kind))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(floorSummary(f), style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (f.label.trim().isNotEmpty)
                            Text(f.label.trim(), style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (hasSd && sd != null) Tag('SD $sd', color: c.text),
                    if (FloorTree.isBlocking(f))
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.lock, size: 16, color: c.muted, semanticLabel: 'bloquant'),
                      ),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      semanticLabel: expanded ? 'Replier' : 'Déplier',
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) _Editor(archi: archi, floor: f, hasKids: hasKids, onCreated: onCreated),
        ],
      ),
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({required this.archi, required this.floor, required this.hasKids, required this.onCreated});
  final Architecture archi;
  final Floor floor;
  final bool hasKids;
  final ValueChanged<String> onCreated;

  @override
  Widget build(BuildContext context) {
    final st = context.read<ArchitecturesState>();
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final f = floor;
    final def = floorKinds[f.kind]!;
    void typed() => st.changed(debounce: true);
    final blockWhat = switch (f.kind) {
      FloorKind.glace => 'les GLACE ne sont pas dérezzés',
      FloorKind.demon => 'le Démon n\'est pas dérezzé',
      _ => 'le test n\'est pas réussi',
    };
    const gap = SizedBox(height: 12);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          gap,
          DropdownButtonFormField<FloorKind>(
            key: ValueKey('${f.id}-kind-${f.kind.name}'),
            initialValue: f.kind,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [for (final k in FloorKind.values) DropdownMenuItem(value: k, child: Text(kindName(k)))],
            onChanged: (k) {
              if (k != null) st.setKind(archi, f, k);
            },
          ),
          gap,
          LiveTextField(
            key: ValueKey('${f.id}-label'),
            value: f.label,
            label: 'Intitulé',
            hint: def.placeholder,
            onChanged: (v) {
              f.label = v;
              typed();
            },
          ),
          if (f.kind == FloorKind.vide) ...[
            gap,
            LiveTextField(
              key: ValueKey('${f.id}-test'),
              value: f.testName,
              label: 'Nom du test demandé',
              hint: 'Ex. Pistage, Contrôle…',
              onChanged: (v) {
                f.testName = v;
                typed();
              },
            ),
          ],
          if (def.hasSd) ...[
            gap,
            LiveTextField(
              key: ValueKey('${f.id}-sd'),
              value: f.sd?.toString() ?? '',
              label: f.kind == FloorKind.vide ? 'SD (vide = pas de test chiffré)' : 'SD',
              number: true,
              onChanged: (v) {
                f.sd = int.tryParse(v.trim());
                typed();
              },
            ),
            if (f.kind == FloorKind.vide && FloorTree.hasTest(f) && f.sd == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Sans SD, le test utilise le SD de la difficulté (${archi.difficulty.sd}).',
                  style: t.bodySmall,
                ),
              ),
          ],
          if (f.kind == FloorKind.glace) ...[
            gap,
            Text('GLACE', style: t.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < f.ice.length; i++)
                  InputChip(
                    label: Text(f.ice[i]),
                    deleteButtonTooltipMessage: 'Retirer ${f.ice[i]}',
                    onDeleted: () {
                      f.ice.removeAt(i);
                      st.changed();
                    },
                  ),
                if (f.ice.isEmpty) Text('Aucun GLACE.', style: t.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('${f.id}-addice-${f.ice.length}'),
              decoration: const InputDecoration(labelText: 'Ajouter un GLACE'),
              items: [for (final i in iceList) DropdownMenuItem(value: i.name, child: Text('${i.name} (${i.cls})'))],
              onChanged: (n) {
                if (n == null) return;
                f.ice.add(n);
                st.changed();
              },
            ),
          ],
          if (f.kind == FloorKind.demon) ...[
            gap,
            DropdownButtonFormField<String>(
              key: ValueKey('${f.id}-demon'),
              initialValue: demonByName.containsKey(f.demon) ? f.demon : null,
              decoration: const InputDecoration(labelText: 'Démon'),
              items: [
                for (final d in demonList)
                  DropdownMenuItem(value: d.name, child: Text('${d.name} (REZ ${d.rez}, Interface ${d.iface})')),
              ],
              onChanged: (n) {
                if (n == null) return;
                f.demon = n;
                st.changed();
              },
            ),
          ],
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: FloorTree.isBlocking(f),
            title: Text('Bloque la descente tant que $blockWhat'),
            onChanged: (v) {
              f.block = v;
              st.changed();
            },
          ),
          LiveTextField(
            key: ValueKey('${f.id}-info'),
            value: f.info,
            label: 'Révélé au joueur quand il réussit le test',
            maxLines: 5,
            onChanged: (v) {
              f.info = v;
              typed();
            },
          ),
          gap,
          LiveTextField(
            key: ValueKey('${f.id}-notes'),
            value: f.notes,
            label: 'Notes MJ (jamais montrées au joueur)',
            maxLines: 5,
            onChanged: (v) {
              f.notes = v;
              typed();
            },
          ),
          gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.vertical_align_top),
                label: const Text('Insérer au-dessus'),
                onPressed: () => onCreated(st.insertAbove(archi, f.id).id),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.vertical_align_bottom),
                label: const Text('Insérer en dessous'),
                onPressed: () => onCreated(st.insertBelow(archi, f.id).id),
              ),
              if (hasKids)
                OutlinedButton.icon(
                  icon: const Icon(Icons.call_split),
                  label: const Text('Nouvel embranchement'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.net,
                    side: BorderSide(color: c.net),
                  ),
                  onPressed: () => onCreated(st.addBranch(archi, f.id).id),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer l\'étage'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.red,
                  side: BorderSide(color: c.red),
                ),
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Supprimer l\'étage ?',
                    message: 'Les étages en dessous remontent d\'un cran.',
                    confirmLabel: 'Supprimer',
                  );
                  if (ok) st.deleteFloor(archi, f.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

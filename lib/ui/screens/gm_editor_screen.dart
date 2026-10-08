import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/floor_tree.dart';
import '../../models/architecture.dart';
import '../../state/app_state.dart';
import '../../state/architectures_state.dart';
import '../../state/run_controller.dart';
import '../../storage/import_export.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/floor_tile.dart';
import 'qr_transfer_screens.dart';

/// Éditeur de l'architecture sélectionnée : réglages, actions, arbre des étages.
class ArchitectureEditor extends StatefulWidget {
  const ArchitectureEditor({super.key, required this.archi});
  final Architecture archi;

  @override
  State<ArchitectureEditor> createState() => _ArchitectureEditorState();
}

class _ArchitectureEditorState extends State<ArchitectureEditor> {
  final Set<String> _open = {};

  void _toggle(String id) => setState(() => _open.contains(id) ? _open.remove(id) : _open.add(id));
  void _created(String id) => setState(() => _open.add(id));

  @override
  Widget build(BuildContext context) {
    final st = context.watch<ArchitecturesState>();
    final app = context.watch<AppState>();
    final a = widget.archi;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final proposed = app.activeArchiId == a.id;
    final tree = FloorTree(a.floors);
    void typed() => st.changed(debounce: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Réglages'),
        LiveTextField(
          key: ValueKey('${a.id}-name'),
          value: a.name,
          label: 'Nom',
          onChanged: (v) {
            a.name = v;
            typed();
          },
        ),
        const SizedBox(height: 12),
        LiveTextField(
          key: ValueKey('${a.id}-lieu'),
          value: a.lieu,
          label: 'Lieu (visible par le joueur)',
          onChanged: (v) {
            a.lieu = v;
            typed();
          },
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              child: DropdownButtonFormField<int>(
                key: ValueKey('${a.id}-diff'),
                initialValue: a.diff,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Difficulté'),
                items: [
                  for (final d in Difficulty.values)
                    DropdownMenuItem(value: d.index, child: Text('${d.label} (SD ${d.sd})')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  a.diff = v;
                  st.changed();
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              child: LiveTextField(
                key: ValueKey('${a.id}-virus'),
                value: a.virusSD?.toString() ?? '',
                label: 'SD du Virus au fond',
                hint: 'Vide = pas de Virus',
                number: true,
                onChanged: (v) {
                  a.virusSD = int.tryParse(v.trim());
                  typed();
                },
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Montrer les SD au joueur'),
          value: a.showSD,
          onChanged: (v) {
            a.showSD = v;
            st.changed();
          },
        ),
        const SectionTitle('Actions'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            proposed
                ? OutlinedButton.icon(
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Retirer au joueur'),
                    onPressed: () => app.propose(null),
                  )
                : FilledButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Proposer au joueur'),
                    onPressed: () {
                      app.propose(a.id);
                      showToast(context, 'Proposée. Passe la main au joueur depuis l\'onglet Netrun.');
                    },
                  ),
            OutlinedButton.icon(
              icon: const Icon(Icons.casino_outlined),
              label: const Text('Retirer les étages au dé'),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Retirer les étages au dé ?',
                  message:
                      'Tous les étages actuels seront remplacés par un tirage '
                      '${a.difficulty.label} (tables p. 210-211).',
                  confirmLabel: 'Retirer au dé',
                );
                if (ok) {
                  st.regenerate(a);
                  setState(_open.clear);
                }
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Dupliquer'),
              onPressed: () => st.duplicate(a),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.qr_code_2),
              label: const Text('QR code'),
              onPressed: () {
                st.flush();
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => QrShareScreen(archi: a)));
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Exporter'),
              onPressed: () async {
                st.flush();
                try {
                  await shareArchitecture(a);
                } catch (_) {
                  if (context.mounted) showToast(context, 'Partage impossible sur cet appareil.');
                }
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.red,
                side: BorderSide(color: c.red),
              ),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Supprimer l\'architecture ?',
                  message: '« ${a.name} » et sa run seront supprimées. Cette action est définitive.',
                  confirmLabel: 'Supprimer',
                );
                if (!ok || !context.mounted) return;
                if (app.activeArchiId == a.id) app.propose(null);
                context.read<RunController>().forget(a.id);
                st.delete(a.id);
              },
            ),
          ],
        ),
        SectionTitle('Étages (${a.floors.length})'),
        if (a.floors.isEmpty)
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Ajouter le premier étage'),
            onPressed: () => _created(st.addFirst(a).id),
          )
        else
          for (final row in tree.rows()) _row(context, a, tree, row),
        if (a.floors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Touche un étage pour le modifier. Les embranchements sont en retrait, '
              'avec un pointillé à gauche.',
              style: t.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, Architecture a, FloorTree tree, TreeRow row) {
    final c = context.colors;
    final f = row.floor;
    Widget tile = FloorTile(
      key: ValueKey(f.id),
      archi: a,
      floor: f,
      depth: row.depth,
      hasKids: tree.kids(f.id).isNotEmpty,
      expanded: _open.contains(f.id),
      onToggle: () => _toggle(f.id),
      onCreated: _created,
    );
    if (row.branchFrom != null) {
      tile = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              row.branchFrom == 0
                  ? 'Embranchement depuis le point d\'accès'
                  : 'Embranchement depuis l\'étage ${row.branchFrom}',
              style: Theme.of(context).textTheme.labelMedium!.copyWith(color: c.net),
            ),
          ),
          tile,
        ],
      );
    }
    if (row.level == 0) return Padding(padding: const EdgeInsets.only(bottom: 8), child: tile);
    return Padding(
      padding: EdgeInsets.only(left: 14.0 * row.level, bottom: 8),
      child: DashedBox(color: c.net, child: tile),
    );
  }
}

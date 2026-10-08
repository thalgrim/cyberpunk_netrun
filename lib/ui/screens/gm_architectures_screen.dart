import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/architecture.dart';
import '../../state/app_state.dart';
import '../../state/architectures_state.dart';
import '../../storage/import_export.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import 'gm_editor_screen.dart';
import 'photo_import_screen.dart';
import 'qr_transfer_screens.dart';

/// Onglet Architectures (MJ).
class GmArchitecturesScreen extends StatelessWidget {
  const GmArchitecturesScreen({super.key});

  Future<void> _import(BuildContext context) async {
    final st = context.read<ArchitecturesState>();
    try {
      final a = await pickArchitecture();
      if (a == null || !context.mounted) return;
      st.add(a);
      showToast(context, 'Architecture importée : ${a.name}.');
    } on ImportException catch (e) {
      if (context.mounted) showToast(context, e.message);
    } catch (_) {
      if (context.mounted) showToast(context, 'Impossible de lire ce fichier.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<ArchitecturesState>();
    final app = context.watch<AppState>();
    final selected = st.selected;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(icon: const Icon(Icons.add), label: const Text('Nouvelle'), onPressed: () => st.create()),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.casino_outlined),
              label: const Text('Générer au dé'),
              onPressed: () {
                final a = st.create(generated: true);
                showToast(context, '${a.floors.length} étages générés (Standard).');
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Importer'),
              onPressed: () => _import(context),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Depuis une photo'),
              onPressed: () => importFromPhoto(context),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scanner un QR code'),
              onPressed: () => scanArchitecture(context),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (st.list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Aucune architecture. Crée-en une, génère-la au dé ou importe un fichier .netrun.json.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          )
        else
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: st.list.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final a = st.list[i];
                return _ArchiCard(
                  archi: a,
                  selected: a.id == selected?.id,
                  proposed: a.id == app.activeArchiId,
                  onTap: () => st.select(a.id),
                );
              },
            ),
          ),
        if (selected != null) ArchitectureEditor(key: ValueKey(selected.id), archi: selected),
      ],
    );
  }
}

class _ArchiCard extends StatelessWidget {
  const _ArchiCard({required this.archi, required this.selected, required this.proposed, required this.onTap});
  final Architecture archi;
  final bool selected;
  final bool proposed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final n = archi.floors.length;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.redPale : c.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? c.red : c.border, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 180,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    archi.name.trim().isEmpty ? 'Sans nom' : archi.name,
                    style: t.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text('$n étage${n > 1 ? 's' : ''} · ${archi.difficulty.label}', style: t.bodySmall),
                  if (proposed) ...[const SizedBox(height: 4), Tag('Proposée', color: c.net, filled: true)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

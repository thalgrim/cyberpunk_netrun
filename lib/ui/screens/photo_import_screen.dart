import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../engine/architecture_parser.dart';
import '../../engine/floor_tree.dart';
import '../../models/architecture.dart';
import '../../state/architectures_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

/// Crée une architecture à partir d'une photo (livre de jeu, notes) : choix de la source,
/// lecture du texte sur le téléphone (hors ligne), puis écran de vérification.
Future<void> importFromPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Prendre une photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choisir dans la galerie'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;

  final XFile? image;
  try {
    image = await ImagePicker().pickImage(source: source, maxWidth: 2400, maxHeight: 2400);
  } catch (_) {
    if (context.mounted) showToast(context, 'Impossible d\'ouvrir l\'appareil photo ou la galerie.');
    return;
  }
  if (image == null || !context.mounted) return;

  final ParseResult result;
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final text = await recognizer.processImage(InputImage.fromFilePath(image.path));
    final lines = [
      for (final b in text.blocks)
        for (final l in b.lines)
          OcrLine(l.text, left: l.boundingBox.left, top: l.boundingBox.top, bottom: l.boundingBox.bottom),
    ];
    result = parseArchitecture(lines);
  } catch (_) {
    if (context.mounted) showToast(context, 'La lecture du texte a échoué : réessaie avec une photo plus nette.');
    return;
  } finally {
    await recognizer.close();
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PhotoReviewScreen(imagePath: image!.path, result: result),
    ),
  );
}

/// Vérification du brouillon lu sur la photo avant de créer l'architecture.
class PhotoReviewScreen extends StatefulWidget {
  const PhotoReviewScreen({super.key, required this.imagePath, required this.result});
  final String imagePath;
  final ParseResult result;

  @override
  State<PhotoReviewScreen> createState() => _PhotoReviewScreenState();
}

class _PhotoReviewScreenState extends State<PhotoReviewScreen> {
  late final List<Floor> _floors = widget.result.toFloors(newId);
  late int _diff = widget.result.diff ?? 1;
  late final TextEditingController _name = TextEditingController(text: 'Architecture photographiée');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final st = context.read<ArchitecturesState>();
    final a = Architecture(
      id: newId(),
      name: _name.text.trim().isEmpty ? 'Architecture photographiée' : _name.text.trim(),
      diff: _diff,
      virusSD: widget.result.virusSD,
      floors: _floors,
    );
    st.add(a);
    Navigator.of(context).pop();
    showToast(context, '${a.floors.length} étages créés. Vérifie-les et ajoute les embranchements si besoin.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final tree = FloorTree(_floors);
    final sdDefault = Difficulty.of(_diff).sd;
    final missingSd = _floors.where((f) => FloorTree.hasTest(f) && f.sd == null).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Vérifier la lecture')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(widget.imagePath), height: 180, fit: BoxFit.cover, semanticLabel: 'Photo lue'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _diff,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: widget.result.diff != null ? 'Difficulté (lue sur la photo)' : 'Difficulté',
            ),
            items: [
              for (final d in Difficulty.values)
                DropdownMenuItem(value: d.index, child: Text('${d.label} (SD ${d.sd})')),
            ],
            onChanged: (v) => setState(() => _diff = v ?? _diff),
          ),
          if (widget.result.virusSD != null) ...[
            const SizedBox(height: 8),
            Text('Virus au fond : SD ${widget.result.virusSD}', style: t.bodyMedium),
          ],
          SectionTitle('Étages reconnus (${_floors.length})'),
          if (_floors.isEmpty)
            Text(
              'Aucun étage reconnu. Cadre bien l\'architecture, avec une lumière uniforme, '
              'ou crée-la à la main.',
              style: t.bodyLarge,
            )
          else ...[
            Text(
              'La lecture repère les types d\'étage, SD, GLACE et Démons. Supprime ce qui est faux ; '
              'tu pourras tout modifier et ajouter les embranchements dans l\'éditeur.',
              style: t.bodySmall,
            ),
            if (missingSd > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '$missingSd SD non lu${missingSd > 1 ? 's' : ''} : la difficulté s\'appliquera (SD $sdDefault).',
                  style: t.bodyMedium!.copyWith(color: c.warn, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 8),
            for (final row in tree.rows())
              Padding(
                padding: EdgeInsets.only(left: 14.0 * row.level, bottom: 6),
                child: AccentCard(
                  color: c.floorColor(row.floor.kind),
                  padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                  child: Row(
                    children: [
                      Text('É.${two(row.depth)}', style: t.titleSmall!.copyWith(color: c.floorColor(row.floor.kind))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(floorSummary(row.floor), style: t.titleSmall),
                            if (row.branchFrom != null)
                              Text(
                                row.branchFrom == 0
                                    ? 'Embranchement depuis le point d\'accès'
                                    : 'Embranchement depuis l\'étage ${row.branchFrom}',
                                style: t.labelSmall!.copyWith(color: c.net),
                              ),
                          ],
                        ),
                      ),
                      if (FloorTree.hasTest(row.floor))
                        row.floor.sd != null
                            ? Tag('SD ${row.floor.sd}', color: c.text)
                            : Tag('SD non lu', color: c.warn),
                      IconButton(
                        tooltip: 'Supprimer cet étage',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => deleteFloor(_floors, row.floor.id)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (widget.result.unknown.isNotEmpty)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Texte non reconnu (${widget.result.unknown.length})', style: t.labelLarge),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in widget.result.unknown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(l, style: t.bodyMedium!.copyWith(color: c.muted)),
                    ),
                ],
              ),
            ),
          if (widget.result.raw.isNotEmpty)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Tout le texte lu (${widget.result.raw.length} lignes)', style: t.labelLarge),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in widget.result.raw)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(l, style: t.bodyMedium!.copyWith(color: c.muted)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Créer l\'architecture'),
            onPressed: _floors.isEmpty ? null : _create,
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ],
      ),
    );
  }
}

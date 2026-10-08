import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../models/architecture.dart';
import '../../models/deck.dart';
import '../../theme/app_theme.dart';

/// Affiche un message court en bas de l'écran.
void showToast(BuildContext context, String? message) {
  if (message == null || message.isEmpty) return;
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(message)));
}

/// Numéro d'étage à deux chiffres.
String two(int n) => n.toString().padLeft(2, '0');

/// Résumé d'un étage : type, noms des GLACE ou « Démon Ifrit ».
String floorSummary(Floor f) {
  switch (f.kind) {
    case FloorKind.glace:
      if (f.ice.isEmpty) return 'GLACE noire (vide)';
      return groupNames(f.ice);
    case FloorKind.demon:
      return 'Démon ${f.demon}';
    case FloorKind.vide:
      return f.testName.trim().isEmpty ? 'Autre' : 'Autre : ${f.testName.trim()}';
    default:
      return kindName(f.kind);
  }
}

/// « Cerbère ×2 + Tueur ».
String groupNames(List<String> names) {
  final counts = <String, int>{};
  for (final n in names) {
    counts[n] = (counts[n] ?? 0) + 1;
  }
  return counts.entries.map((e) => e.value > 1 ? '${e.key} ×${e.value}' : e.key).join(' + ');
}

/// Couleur d'une catégorie de programme : soutien = NET, défensif, offensif.
Color progTypeColor(AppColors c, ProgType t) => switch (t) {
  ProgType.soutien => c.net,
  ProgType.defensif => AppColors.defensive,
  ProgType.offensif => AppColors.offensive,
};

Color itemColor(AppColors c, DeckItem i) {
  if (i.isIce) return c.red;
  if (i.isHw) return c.muted;
  final t = i.prog?.type;
  return t == null ? c.muted : progTypeColor(c, t);
}

/// Titre de section.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.color});
  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge!
                    .copyWith(letterSpacing: 1.2, color: color ?? context.colors.muted),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Petite étiquette (badge) avec texte.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color, this.filled = false});
  final String text;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? c : Colors.transparent,
        border: Border.all(color: c),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall!
            .copyWith(color: filled ? context.colors.panel : c, letterSpacing: 0.4),
      ),
    );
  }
}

/// Carte avec bordure gauche colorée.
class AccentCard extends StatelessWidget {
  const AccentCard({
    super.key,
    required this.color,
    required this.child,
    this.background,
    this.borderColor,
    this.padding = const EdgeInsets.all(12),
  });
  final Color color;
  final Widget child;
  final Color? background;
  final Color? borderColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Material (et non un DecoratedBox) : les ListTile enfants peignent correctement.
    return Material(
      color: background ?? c.panel,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor ?? c.border, width: borderColor != null ? 2 : 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: color),
            Expanded(
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bordure gauche pointillée (embranchements, étages cartographiés).
class DashedBox extends StatelessWidget {
  const DashedBox({super.key, required this.color, required this.child, this.allSides = false});
  final Color color;
  final Widget child;

  /// Pointillés sur les quatre côtés (sinon à gauche seulement).
  final bool allSides;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashPainter(color, allSides),
      child: Padding(
        padding: EdgeInsets.only(left: allSides ? 0 : 10),
        child: child,
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.allSides);
  final Color color;
  final bool allSides;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = allSides ? 1.5 : 3;
    const dash = 6.0, gap = 4.0;
    void line(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      var d = 0.0;
      while (d < len) {
        canvas.drawLine(a + dir * d, a + dir * (d + dash).clamp(0, len), p);
        d += dash + gap;
      }
    }

    if (allSides) {
      const r = 1.0;
      line(const Offset(r, r), Offset(size.width - r, r));
      line(Offset(size.width - r, r), Offset(size.width - r, size.height - r));
      line(Offset(size.width - r, size.height - r), Offset(r, size.height - r));
      line(Offset(r, size.height - r), const Offset(r, r));
    } else {
      line(const Offset(1.5, 0), Offset(1.5, size.height));
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color || old.allSides != allSides;
}

/// Champ texte qui garde son contrôleur entre les reconstructions.
class LiveTextField extends StatefulWidget {
  const LiveTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.hint,
    this.maxLines = 1,
    this.number = false,
    this.enabled = true,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final String? label;
  final String? hint;
  final int maxLines;
  final bool number;
  final bool enabled;

  @override
  State<LiveTextField> createState() => _LiveTextFieldState();
}

class _LiveTextFieldState extends State<LiveTextField> {
  late final TextEditingController _c = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(LiveTextField old) {
    super.didUpdateWidget(old);
    // Valeur modifiée ailleurs (ex. remise à zéro) : on resynchronise.
    if (widget.value != _c.text && !(widget.number && int.tryParse(_c.text) == int.tryParse(widget.value))) {
      _c.text = widget.value;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      enabled: widget.enabled,
      minLines: widget.maxLines > 1 ? 2 : 1,
      maxLines: widget.maxLines,
      keyboardType: widget.number ? const TextInputType.numberWithOptions(signed: true) : null,
      decoration: InputDecoration(labelText: widget.label, hintText: widget.hint),
      onChanged: widget.onChanged,
    );
  }
}

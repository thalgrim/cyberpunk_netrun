import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Afficheur d'étage façon ascenseur : grand numéro rouge lumineux sur écran sombre.
class ElevatorDisplay extends StatelessWidget {
  const ElevatorDisplay({
    super.key,
    required this.code,
    required this.semanticLabel,
    required this.title,
    this.subtitle = '',
    this.turn,
    this.actions = 0,
    this.spent = 0,
    this.ps,
    this.psMax,
    this.burning = false,
  });

  /// « 03 », « AP » ou « -- ».
  final String code;
  final String semanticLabel;
  final String title;
  final String subtitle;

  /// Tour en cours (null = hors connexion : pas de ligne d'état).
  final int? turn;
  final int actions;
  final int spent;
  final int? ps;
  final int? psMax;
  final bool burning;

  static const _screen = Color(0xFF120A0D);
  static const _glow = Color(0xFFFF3A50);
  static const _text = Color(0xFFF1E6E3);
  static const _muted = Color(0xFFA6939C);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: _screen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3C2B31)),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        foregroundPainter: _Scanlines(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Semantics(
                label: semanticLabel,
                excludeSemantics: true,
                child: SizedBox(
                  width: 92,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        child: Text(
                          code,
                          style: const TextStyle(
                            fontFamily: kTitleFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 56,
                            height: 1.0,
                            color: _glow,
                            shadows: [
                              Shadow(color: _glow, blurRadius: 18),
                              Shadow(color: Color(0x99FF3A50), blurRadius: 36),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('ÉTAGE', style: t.labelSmall!.copyWith(color: _muted, letterSpacing: 2.5, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 70, color: const Color(0xFF3C2B31), margin: const EdgeInsets.only(right: 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium!.copyWith(color: _text, fontWeight: FontWeight.w700),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyMedium!.copyWith(color: _muted),
                      ),
                    if (turn != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _stat(context, 'Tour $turn'),
                          Semantics(
                            label: '$actions action${actions > 1 ? 's' : ''} restante${actions > 1 ? 's' : ''}',
                            excludeSemantics: true,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < actions + spent; i++)
                                  Container(
                                    width: 11,
                                    height: 11,
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i < actions ? const Color(0xFF52DCCF) : Colors.transparent,
                                      border: Border.all(color: const Color(0xFF52DCCF), width: 1.5),
                                    ),
                                  ),
                                const SizedBox(width: 2),
                                Text('$actions', style: t.labelMedium!.copyWith(color: const Color(0xFF52DCCF))),
                              ],
                            ),
                          ),
                          if (ps != null) _stat(context, 'PS $ps${psMax != null ? '/$psMax' : ''}'),
                          if (burning)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_fire_department, size: 16, color: Color(0xFFF0A53A)),
                                Text('En feu', style: t.labelMedium!.copyWith(color: const Color(0xFFF0A53A))),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String s) =>
      Text(s, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: _text, fontSize: 13));
}

class _Scanlines extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x0FFFFFFF)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_Scanlines oldDelegate) => false;
}

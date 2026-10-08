import 'package:flutter/material.dart';

import '../../models/run_state.dart';
import '../../theme/app_theme.dart';

/// Dernier résultat, affiché en grand.
class ResultPanel extends StatelessWidget {
  const ResultPanel({super.key, required this.result});
  final RunResult result;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final ok = result.ok;
    final bg = ok == true ? c.okPale : (ok == false ? c.redPale : c.panel);
    final accent = ok == true ? c.ok : (ok == false ? c.red : c.border);
    final verdict = ok == true ? 'Réussite' : (ok == false ? 'Échec ou dégâts' : null);
    final sum = result.sum;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent, width: ok == null ? 1 : 1.5),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (ok != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      ok ? Icons.check_circle : Icons.cancel,
                      color: accent,
                      size: 22,
                      semanticLabel: verdict,
                    ),
                  ),
                Expanded(child: Text(result.h, style: t.titleLarge)),
              ],
            ),
            if (sum != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: c.red, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Text(
                      '−${sum.tot}',
                      style: t.displaySmall!.copyWith(color: Colors.white, height: 1.0, fontSize: 38),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('dégâts encaissés', style: t.titleSmall!.copyWith(color: Colors.white)),
                          Text(
                            sum.from != null && sum.to != null
                                ? 'PS ${sum.from} → ${sum.to}'
                                : 'Renseigne tes PS dans Cyberconsole pour les décompter',
                            style: t.bodyMedium!.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            for (final l in result.lines)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l, style: t.bodyLarge),
              ),
          ],
        ),
      ),
    );
  }
}

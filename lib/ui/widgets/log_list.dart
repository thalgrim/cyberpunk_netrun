import 'package:flutter/material.dart';

import '../../models/run_state.dart';
import '../../theme/app_theme.dart';

/// Journal de la run : entrées « T3 … », bordure verte (réussite) ou rouge (échec, dégâts).
class LogList extends StatelessWidget {
  const LogList({super.key, required this.entries, this.limit});
  final List<LogEntry> entries;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    if (entries.isEmpty) return Text('Journal vide.', style: t.bodySmall);
    final list = limit == null ? entries : entries.take(limit!).toList();
    return Column(
      children: [
        for (final e in list)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: c.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(width: 4, color: e.c == 'ok' ? c.ok : (e.c == 'ko' ? c.red : c.border))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
                  child: Text('T${e.t}', style: t.labelMedium!.copyWith(color: c.muted)),
                ),
                Expanded(child: Text(e.txt, style: t.bodyMedium)),
                if (e.c.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      e.c == 'ok' ? 'OK' : 'KO',
                      semanticsLabel: e.c == 'ok' ? 'réussite' : 'échec ou dégâts',
                      style: t.labelMedium!.copyWith(color: e.c == 'ok' ? c.ok : c.red),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

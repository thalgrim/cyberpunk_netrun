import 'dart:math';

import 'package:cyberpunk_netrun/data/catalog.dart';
import 'package:cyberpunk_netrun/engine/dice.dart';
import 'package:cyberpunk_netrun/engine/floor_tree.dart';
import 'package:cyberpunk_netrun/engine/generator.dart';
import 'package:cyberpunk_netrun/models/architecture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('200 graines : structure et contenu conformes aux tables', () {
    for (var seed = 0; seed < 200; seed++) {
      final diff = seed % 4;
      var n = 0;
      final g = generateDetailed(diff, Dice(Random(seed)), newId: () => 'f${n++}');
      final floors = g.floors;
      final tree = FloorTree(floors);
      final reason = 'graine $seed';

      expect(floors.length, inInclusiveRange(3, 18), reason: reason);
      expect(tree.roots.length, 1, reason: reason);

      // Fond de la branche principale.
      var cur = tree.roots.first;
      while (tree.kids(cur.id).isNotEmpty) {
        cur = tree.kids(cur.id).first;
      }
      final mainBottom = tree.depth(cur.id);
      expect(mainBottom, tree.maxDepth, reason: reason);

      for (final f in floors) {
        final depth = tree.depth(f.id);
        final roll = g.rolls[f.id]!;
        // Aucun embranchement ne part au-dessus de l'étage 2.
        if (tree.kids(f.id).length > 1) expect(depth, greaterThanOrEqualTo(2), reason: reason);
        // Aucun embranchement n'atteint la profondeur du fond.
        if (!_isMain(tree, f)) {
          expect(depth, greaterThanOrEqualTo(3), reason: reason);
          expect(depth, lessThan(mainBottom), reason: reason);
        }

        if (depth <= 2) {
          expect(roll, inInclusiveRange(1, 6), reason: reason);
          final e = lobbyTable[roll]!;
          expect(f.kind, e.kind, reason: reason);
          expect(f.sd, e.sd, reason: reason);
          expect(f.ice, e.ice, reason: reason);
        } else {
          expect(roll, inInclusiveRange(3, 18), reason: reason);
          final e = bodyEntry(roll, diff);
          expect(f.kind, e.kind, reason: reason);
          expect(f.ice, e.ice, reason: reason);
          if (f.kind != FloorKind.glace) expect(f.sd, Difficulty.of(diff).sd, reason: reason);
        }
      }

      // Pas de doublon interdit.
      final lobby = <int>[];
      final body = <int>[];
      for (final f in floors) {
        (tree.depth(f.id) <= 2 ? lobby : body).add(g.rolls[f.id]!);
      }
      final lobbyNoRepeat = lobby.where((r) => r != 1).toList();
      expect(lobbyNoRepeat.toSet().length, lobbyNoRepeat.length, reason: reason);
      final bodyNoRepeat = body.where((r) => r != 10 && r != 11).toList();
      expect(bodyNoRepeat.toSet().length, bodyNoRepeat.length, reason: reason);
    }
  });

  test('ordre croissant et champs texte vides', () {
    final floors = generate(1, Dice(Random(7)));
    final ords = floors.map((f) => f.ord).toList();
    expect(ords, [for (var i = 0; i < floors.length; i++) i]);
    expect(floors.every((f) => f.label.isEmpty && f.info.isEmpty && f.notes.isEmpty), isTrue);
  });
}

bool _isMain(FloorTree tree, Floor f) {
  Floor? cur = f;
  while (cur != null) {
    final p = tree.parent(cur.id);
    if (tree.kids(p?.id).first.id != cur.id) return false;
    cur = p;
  }
  return true;
}

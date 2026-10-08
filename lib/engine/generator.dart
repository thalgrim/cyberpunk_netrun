/// Génération d'architecture au dé (livre p. 210-211). Dart pur.
library;

import 'dart:math';

import '../data/catalog.dart';
import '../models/architecture.dart';
import 'dice.dart';
import 'floor_tree.dart';

/// Résultat détaillé : étages et résultat de table retenu pour chacun.
class Generation {
  Generation(this.floors, this.rolls);

  final List<Floor> floors;

  /// floorId → résultat de la table (1d6 Lobby, 3d6 Corps).
  final Map<String, int> rolls;
}

int _idCounter = 0;
String _defaultId() => 'g${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

/// Génère les étages d'une architecture de difficulté [diff].
List<Floor> generate(int diff, Dice dice, {String Function()? newId}) =>
    generateDetailed(diff, dice, newId: newId).floors;

Generation generateDetailed(int diff, Dice dice, {String Function()? newId}) {
  final makeId = newId ?? _defaultId;
  var ord = 0;
  Floor make(String? parent) => Floor(id: makeId(), parent: parent, ord: ord++);

  // 1. Nombre total d'étages : 3d6.
  final total = dice.d(6) + dice.d(6) + dice.d(6);

  // 2. Nombre d'embranchements.
  var nb = 0;
  while (nb < 3 && dice.d(10) >= 7) {
    nb++;
  }

  // 3. Longueur de chaque embranchement.
  final lengths = <int>[for (var i = 0; i < nb; i++) 1 + dice.random(max(1, total ~/ (nb + 2)))];

  // 4. Longueur de la branche principale.
  var main = total - lengths.fold<int>(0, (a, b) => a + b);
  while (lengths.isNotEmpty && (main < 4 || main <= lengths.reduce(max) + 2)) {
    main += lengths.removeLast();
  }

  // 5. Branche principale.
  final floors = <Floor>[];
  final mainChain = <Floor>[];
  String? prev;
  for (var i = 0; i < main; i++) {
    final f = make(prev);
    floors.add(f);
    mainChain.add(f);
    prev = f.id;
  }

  // 6. Embranchements.
  for (final l in lengths) {
    final maxP = main - l - 1;
    if (maxP < 2) continue;
    final at = 2 + dice.random(maxP - 1);
    String? p = mainChain[at - 1].id;
    for (var i = 0; i < l; i++) {
      final f = make(p);
      floors.add(f);
      p = f.id;
    }
  }

  // 7. Remplissage par profondeur croissante.
  final tree = FloorTree(floors);
  final ordered = [...floors]
    ..sort((a, b) {
      final c = tree.depth(a.id).compareTo(tree.depth(b.id));
      return c != 0 ? c : a.ord.compareTo(b.ord);
    });
  final usedLobby = <int>{};
  final usedBody = <int>{};
  final rolls = <String, int>{};
  for (final f in ordered) {
    final lobby = tree.depth(f.id) <= 2;
    int roll = 0;
    for (var tries = 0; tries < 20; tries++) {
      roll = lobby ? dice.d(6) : dice.d(6) + dice.d(6) + dice.d(6);
      final repeatable = lobby ? roll == 1 : (roll == 10 || roll == 11);
      if (repeatable || !(lobby ? usedLobby : usedBody).contains(roll)) break;
    }
    (lobby ? usedLobby : usedBody).add(roll);
    rolls[f.id] = roll;
    final e = lobby ? lobbyTable[roll]! : bodyEntry(roll, diff);
    f.kind = e.kind;
    f.sd = e.sd;
    f.ice = [...e.ice];
  }
  return Generation(floors, rolls);
}

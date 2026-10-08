import 'package:cyberpunk_netrun/engine/floor_tree.dart';
import 'package:cyberpunk_netrun/models/architecture.dart';
import 'package:flutter_test/flutter_test.dart';

/// a → b → c → d (principale), b → x → y (embranchement).
List<Floor> sample() => [
  Floor(id: 'a'),
  Floor(id: 'b', parent: 'a'),
  Floor(id: 'c', parent: 'b', ord: 0),
  Floor(id: 'd', parent: 'c'),
  Floor(id: 'x', parent: 'b', ord: 1),
  Floor(id: 'y', parent: 'x'),
];

Map<String, int> depths(List<Floor> floors) {
  final t = FloorTree(floors);
  return {for (final f in floors) f.id: t.depth(f.id)};
}

void main() {
  test('profondeurs, enfants triés, parent', () {
    final t = FloorTree(sample());
    expect(depths(sample()), {'a': 1, 'b': 2, 'c': 3, 'd': 4, 'x': 3, 'y': 4});
    expect(t.kids('b').map((f) => f.id), ['c', 'x']);
    expect(t.roots.map((f) => f.id), ['a']);
    expect(t.parent('a'), isNull);
    expect(t.parent('y')!.id, 'x');
    expect(t.maxDepth, 4);
  });

  test('parent inexistant = racine', () {
    final t = FloorTree([Floor(id: 'a', parent: 'zz'), Floor(id: 'b', parent: 'a')]);
    expect(t.depth('a'), 1);
    expect(t.parent('a'), isNull);
    expect(t.depth('b'), 2);
  });

  test('affichage : embranchement inséré sous son étage de départ', () {
    final rows = FloorTree(sample()).rows();
    expect(rows.map((r) => r.floor.id), ['a', 'b', 'x', 'y', 'c', 'd']);
    expect(rows[2].branchFrom, 2);
    expect(rows[2].level, 1);
    expect(rows[4].level, 0);
  });

  test('insérer au-dessus', () {
    final f = sample();
    insertAbove(f, 'b', Floor(id: 'n'));
    expect(depths(f), {'a': 1, 'b': 3, 'c': 4, 'd': 5, 'x': 4, 'y': 5, 'n': 2});
    final f2 = sample();
    insertAbove(f2, 'a', Floor(id: 'r'));
    expect(FloorTree(f2).roots.map((e) => e.id), ['r']);
    expect(depths(f2)['d'], 5);
  });

  test('insérer en dessous', () {
    final f = sample();
    insertBelow(f, 'b', Floor(id: 'n'));
    expect(depths(f), {'a': 1, 'b': 2, 'c': 4, 'd': 5, 'x': 4, 'y': 5, 'n': 3});
    expect(FloorTree(f).kids('n').map((e) => e.id), ['c', 'x']);
  });

  test('nouvel embranchement', () {
    final f = sample();
    addBranch(f, 'b', Floor(id: 'n'));
    expect(FloorTree(f).kids('b').map((e) => e.id), ['c', 'x', 'n']);
  });

  test('supprimer un étage intermédiaire', () {
    final f = sample();
    deleteFloor(f, 'b');
    expect(depths(f), {'a': 1, 'c': 2, 'd': 3, 'x': 2, 'y': 3});
    expect(FloorTree(f).kids('a').map((e) => e.id), ['c', 'x']);
  });

  test('supprimer un étage d\'embranchement', () {
    final f = sample();
    deleteFloor(f, 'x');
    expect(depths(f), {'a': 1, 'b': 2, 'c': 3, 'd': 4, 'y': 3});
    expect(FloorTree(f).kids('b').map((e) => e.id), ['c', 'y']);
  });

  test('supprimer la racine', () {
    final f = [
      Floor(id: 'a'),
      Floor(id: 'b', parent: 'a', ord: 0),
      Floor(id: 'z', parent: 'a', ord: 1),
      Floor(id: 'c', parent: 'b'),
    ];
    deleteFloor(f, 'a');
    final t = FloorTree(f);
    expect(t.roots.map((e) => e.id), ['b']);
    expect(t.kids('b').map((e) => e.id), ['c', 'z']);
    expect(depths(f), {'b': 1, 'z': 2, 'c': 2});
  });

  test('étage bloquant et étage avec test', () {
    expect(FloorTree.isBlocking(Floor(id: 'a', kind: FloorKind.mdp)), isTrue);
    expect(FloorTree.isBlocking(Floor(id: 'a', kind: FloorKind.glace)), isFalse);
    expect(FloorTree.isBlocking(Floor(id: 'a', kind: FloorKind.glace, block: true)), isTrue);
    expect(FloorTree.hasTest(Floor(id: 'a', kind: FloorKind.vide)), isFalse);
    expect(FloorTree.hasTest(Floor(id: 'a', kind: FloorKind.vide, testName: 'Pistage')), isTrue);
  });
}

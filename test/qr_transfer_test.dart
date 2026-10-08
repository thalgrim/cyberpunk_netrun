import 'dart:math';

import 'package:cyberpunk_netrun/engine/dice.dart';
import 'package:cyberpunk_netrun/engine/floor_tree.dart';
import 'package:cyberpunk_netrun/engine/generator.dart';
import 'package:cyberpunk_netrun/models/architecture.dart';
import 'package:cyberpunk_netrun/storage/import_export.dart';
import 'package:cyberpunk_netrun/storage/qr_transfer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('aller-retour : structure et contenu conservés, notes MJ retirées', () {
    var n = 0;
    final floors = generate(2, Dice(Random(11)), newId: () => '${const Uuid().v4().substring(0, 30)}${n++}');
    floors.first
      ..label = 'Accès au hall'
      ..info = 'Code du hall : 4471.'
      ..notes = 'Secret du MJ'
      ..block = false;
    final a = Architecture(id: 'X', name: 'Tour Arasaka', lieu: 'Night City', diff: 2, virusSD: 12, floors: floors);

    final b = decodeQr(encodeQr(a));
    expect(b.id, isNot('X'));
    expect(b.name, 'Tour Arasaka');
    expect(b.lieu, 'Night City');
    expect(b.diff, 2);
    expect(b.virusSD, 12);
    expect(b.floors.length, a.floors.length);
    expect(b.floors.every((f) => f.notes.isEmpty), isTrue);
    expect(b.floors.first.info, 'Code du hall : 4471.');
    expect(b.floors.first.block, isFalse);

    // Même arbre : mêmes lignes d'affichage (profondeur, retrait, contenu).
    String shape(Architecture x) =>
        FloorTree(x.floors)
            .rows()
            .map((r) => '${r.depth}/${r.level}/${r.floor.kind.name}/${r.floor.sd}/${r.floor.ice.join('+')}')
            .join(',');
    expect(shape(b), shape(a));
  });

  test('une architecture de 18 étages avec des textes tient dans un QR code', () {
    final floors = <Floor>[];
    String? prev;
    for (var i = 0; i < 18; i++) {
      final f = Floor(
        id: const Uuid().v4(),
        parent: prev,
        kind: FloorKind.values[i % 6],
        sd: 8,
        ice: ['Cerbère', 'Tueur'],
        label: 'Étage numéro $i : salle des serveurs',
        info: 'Le joueur obtient les codes des caméras du niveau $i et le plan des conduits.',
        notes: 'Notes longues du MJ qui ne doivent pas partir. ' * 5,
      );
      floors.add(f);
      prev = f.id;
    }
    final code = encodeQr(Architecture(id: 'A', name: 'Grosse architecture', floors: floors));
    expect(code.length, lessThan(qrMaxBytes));
  });

  test('QR étranger ou abîmé : message clair', () {
    expect(() => decodeQr('https://exemple.fr'), throwsA(isA<ImportException>()));
    expect(() => decodeQr('${qrPrefix}abc'), throwsA(isA<ImportException>()));
  });
}

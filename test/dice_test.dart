import 'package:cyberpunk_netrun/engine/dice.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_dice.dart';

void main() {
  test('rollFormula : détail', () {
    final d = ScriptedDice([4, 2, 6, 3]);
    final r = d.rollFormula('3d6');
    expect(r.total, 12);
    expect(r.detail, '3d6 : 4 + 2 + 6 = 12');
    expect(d.rollFormula('1d6').detail, '1d6 : 3');
  });

  test('pRoll : un 10 ajoute un d10', () {
    final r = ScriptedDice([10, 4]).pRoll(6, 2);
    expect(r.total, 6 + 2 + 10 + 4);
    expect(r.text, 'Interface 6 + 2 + dé 10 (critique +4)');
  });

  test('pRoll : un 1 soustrait un d10', () {
    final r = ScriptedDice([1, 7]).pRoll(4, 0);
    expect(r.total, 4 + 1 - 7);
    expect(r.text, 'Interface 4 + dé 1 (échec critique −7)');
  });

  test('pRoll : jet normal, sans dé supplémentaire', () {
    final d = ScriptedDice([5]);
    final r = d.pRoll(4, -2);
    expect(r.total, 7);
    expect(d.remaining, 0);
    expect(r.text, 'Interface 4 − 2 + dé 5');
  });

  test('égalité avec le SD = échec', () {
    final r = ScriptedDice([4]).pRoll(4, 0);
    expect(r.total, 8);
    expect(beats(r.total, 8), isFalse);
    expect(beats(9, 8), isTrue);
  });
}

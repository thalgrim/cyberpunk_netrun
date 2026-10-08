import 'package:cyberpunk_netrun/engine/dice.dart';

/// Dés scriptés : renvoie les valeurs dans l'ordre donné.
class ScriptedDice extends Dice {
  ScriptedDice(List<int> values) : _values = [...values];

  final List<int> _values;

  int get remaining => _values.length;

  void push(List<int> values) => _values.addAll(values);

  @override
  int d(int n) {
    if (_values.isEmpty) throw StateError('ScriptedDice : plus de valeur pour un d$n');
    final v = _values.removeAt(0);
    if (v < 1 || v > n) throw StateError('ScriptedDice : $v impossible sur un d$n');
    return v;
  }
}

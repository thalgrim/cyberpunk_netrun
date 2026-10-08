/// Dés (Dart pur). Toute source d'aléatoire passe par [Dice].
library;

import 'dart:math';

class DiceRoll {
  const DiceRoll(this.total, this.detail, [this.dice = const []]);

  final int total;

  /// Ex. « 3d6 : 4 + 2 + 6 = 12 » ou « 1d6 : 4 ».
  final String detail;
  final List<int> dice;

  /// Valeur fixe (sans dé).
  factory DiceRoll.fixed(int v) => DiceRoll(v, '$v');
}

/// Jet du netrunner : Interface + modificateur + d10 (critique / échec critique).
class PlayerRoll {
  const PlayerRoll({
    required this.total,
    required this.rank,
    required this.mod,
    required this.die,
    required this.extra,
  });

  final int total;
  final int rank;
  final int mod;

  /// Résultat du d10.
  final int die;

  /// Dé supplémentaire : positif sur un 10, négatif sur un 1, 0 sinon.
  final int extra;

  /// Ex. « Interface 6 + 2 + dé 10 (critique +4) ».
  String get text {
    final b = StringBuffer('Interface $rank');
    if (mod > 0) b.write(' + $mod');
    if (mod < 0) b.write(' − ${-mod}');
    b.write(' + dé $die');
    if (extra > 0) b.write(' (critique +$extra)');
    if (extra < 0) b.write(' (échec critique −${-extra})');
    return b.toString();
  }

  /// Ex. « Interface 6 + dé 4 = 10 ».
  String get full => '$text = $total';
}

/// Dés injectables. Une sous-classe peut surcharger [d] pour des tests déterministes.
class Dice {
  Dice([Random? random]) : _random = random ?? Random();

  final Random _random;

  /// Entier de 1 à n.
  int d(int n) => _random.nextInt(n) + 1;

  /// Entier dans [0, n-1].
  int random(int n) => d(n) - 1;

  static final RegExp _formula = RegExp(r'^\s*(\d*)d(\d+)\s*$');

  /// Lance une formule « XdY ».
  DiceRoll rollFormula(String formula) {
    final m = _formula.firstMatch(formula);
    if (m == null) {
      final v = int.tryParse(formula.trim()) ?? 0;
      return DiceRoll.fixed(v);
    }
    final count = m.group(1)!.isEmpty ? 1 : int.parse(m.group(1)!);
    final faces = int.parse(m.group(2)!);
    final dice = [for (var i = 0; i < count; i++) d(faces)];
    final total = dice.fold<int>(0, (a, b) => a + b);
    final detail = count == 1 ? '${count}d$faces : $total' : '${count}d$faces : ${dice.join(' + ')} = $total';
    return DiceRoll(total, detail, dice);
  }

  /// Jet du netrunner : rang d'Interface + mod + d10 ; 10 ajoute un d10, 1 en soustrait un.
  PlayerRoll pRoll(int rank, int mod) {
    final r = d(10);
    var extra = 0;
    if (r == 10) extra = d(10);
    if (r == 1) extra = -d(10);
    return PlayerRoll(total: rank + mod + r + extra, rank: rank, mod: mod, die: r, extra: extra);
  }
}

/// Règle de réussite : l'attaquant ou le testeur doit dépasser strictement ; égalité = défenseur.
bool beats(int attack, int defense) => attack > defense;

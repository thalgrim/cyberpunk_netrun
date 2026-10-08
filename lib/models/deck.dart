/// Cyberconsole et profil du netrunner (Dart pur).
library;

import '../data/catalog.dart';

class DeckItem {
  DeckItem({required this.id, required this.k, required this.n});

  final String id;

  /// "prog" | "ice" | "hw"
  final String k;

  /// Nom du catalogue.
  final String n;

  bool get isProg => k == 'prog';
  bool get isIce => k == 'ice';
  bool get isHw => k == 'hw';

  ProgramDef? get prog => isProg ? programByName[n] : null;
  IceDef? get ice => isIce ? iceByName[n] : null;
  HardwareDef? get hw => isHw ? hardwareByName[n] : null;

  /// Emplacements occupés : programme 1, GLACE 2, matériel selon la table.
  int get cost {
    if (isIce) return iceSlotCost;
    if (isHw) return hw?.slots ?? 1;
    return 1;
  }

  /// Libellé du type affiché.
  String get typeLabel {
    if (isIce) return 'GLACE';
    if (isHw) return 'Matériel';
    return prog?.type.label ?? 'Programme';
  }

  factory DeckItem.fromJson(Map<String, dynamic> j) =>
      DeckItem(id: j['id'] as String, k: j['k'] as String? ?? 'prog', n: j['n'] as String? ?? '');

  Map<String, dynamic> toJson() => {'id': id, 'k': k, 'n': n};
}

class NetrunnerProfile {
  NetrunnerProfile({this.rank, this.vit = 0, this.psMax});

  /// Rang d'Interface 0-10.
  int? rank;

  /// Autre bonus de VIT.
  int vit;
  int? psMax;

  factory NetrunnerProfile.fromJson(Map<String, dynamic> j) => NetrunnerProfile(
    rank: (j['rank'] as num?)?.toInt(),
    vit: (j['vit'] as num?)?.toInt() ?? 0,
    psMax: (j['psMax'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {'rank': rank, 'vit': vit, 'psMax': psMax};
}

class Deck {
  Deck({
    this.type = 'Standard',
    this.slots = 7,
    this.arm = false,
    this.suit = false,
    List<DeckItem>? items,
    List<DeckItem>? saved,
    NetrunnerProfile? me,
  }) : items = items ?? [],
       saved = saved ?? [],
       me = me ?? NetrunnerProfile();

  String type;
  int slots;
  bool arm;
  bool suit;
  List<DeckItem> items;
  List<DeckItem> saved;
  NetrunnerProfile me;

  /// Emplacements pour programmes et GLACE : modèle + option cyberbras.
  int get base => slots + (arm ? 1 : 0);

  /// Total, avec l'emplacement de la combinaison connectée (matériel seulement).
  int get total => base + (suit ? 1 : 0);

  int get used => items.fold<int>(0, (s, i) => s + i.cost);
  int get usedNonHw => items.where((i) => !i.isHw).fold<int>(0, (s, i) => s + i.cost);

  bool canAdd(DeckItem item) {
    if (used + item.cost > total) return false;
    if (!item.isHw && usedNonHw + item.cost > base) return false;
    return true;
  }

  bool hasHardware(String name) => items.any((i) => i.isHw && i.n == name);

  factory Deck.fromJson(Map<String, dynamic> j) {
    List<DeckItem> list(Object? raw) =>
        (raw as List? ?? []).map((e) => DeckItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    return Deck(
      type: j['type'] as String? ?? 'Standard',
      slots: (j['slots'] as num?)?.toInt() ?? 7,
      arm: j['arm'] as bool? ?? false,
      suit: j['suit'] as bool? ?? false,
      items: list(j['items']),
      saved: list(j['saved']),
      me: j['me'] == null ? null : NetrunnerProfile.fromJson(Map<String, dynamic>.from(j['me'] as Map)),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'slots': slots,
    'arm': arm,
    'suit': suit,
    'items': items.map((i) => i.toJson()).toList(),
    'saved': saved.map((i) => i.toJson()).toList(),
    'me': me.toJson(),
  };
}

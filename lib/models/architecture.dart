/// Modèles d'architecture NET (Dart pur).
library;

/// Types d'étage. Le nom de l'énumération est la valeur JSON.
enum FloorKind { mdp, fichier, noeud, glace, demon, vide }

FloorKind floorKindFromJson(Object? v) => FloorKind.values.firstWhere((k) => k.name == v, orElse: () => FloorKind.vide);

/// Difficultés d'architecture (livre p. 210). L'index est la valeur JSON `diff`.
enum Difficulty {
  basique('Basique', 6),
  standard('Standard', 8),
  inhabituelle('Inhabituelle', 10),
  avancee('Avancée', 12);

  const Difficulty(this.label, this.sd);
  final String label;
  final int sd;

  static Difficulty of(int index) => Difficulty.values[index.clamp(0, Difficulty.values.length - 1)];
}

class Floor {
  Floor({
    required this.id,
    this.parent,
    this.ord = 0,
    this.kind = FloorKind.mdp,
    this.label = '',
    this.sd,
    this.testName = '',
    List<String>? ice,
    this.demon = 'Lutin',
    this.info = '',
    this.notes = '',
    this.block,
  }) : ice = ice ?? [];

  String id;
  String? parent;
  int ord;
  FloorKind kind;
  String label;
  int? sd;
  String testName;
  List<String> ice;
  String demon;
  String info;
  String notes;
  bool? block;

  factory Floor.fromJson(Map<String, dynamic> j) => Floor(
    id: j['id'] as String,
    parent: j['parent'] as String?,
    ord: (j['ord'] as num?)?.toInt() ?? 0,
    kind: floorKindFromJson(j['kind']),
    label: j['label'] as String? ?? '',
    sd: (j['sd'] as num?)?.toInt(),
    testName: j['testName'] as String? ?? '',
    ice: (j['ice'] as List?)?.map((e) => e.toString()).toList(),
    demon: j['demon'] as String? ?? 'Lutin',
    info: j['info'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
    block: j['block'] as bool?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'parent': parent,
    'ord': ord,
    'kind': kind.name,
    'label': label,
    'sd': sd,
    'testName': testName,
    'ice': ice,
    'demon': demon,
    'info': info,
    'notes': notes,
    'block': block,
  };

  Floor copy() => Floor.fromJson(toJson());
}

class Architecture {
  Architecture({
    required this.id,
    this.name = 'Nouvelle architecture',
    this.lieu = '',
    this.diff = 1,
    this.showSD = true,
    this.virusSD,
    List<Floor>? floors,
  }) : floors = floors ?? [];

  String id;
  String name;
  String lieu;
  int diff;
  bool showSD;
  int? virusSD;
  List<Floor> floors;

  Difficulty get difficulty => Difficulty.of(diff);

  factory Architecture.fromJson(Map<String, dynamic> j) => Architecture(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    lieu: j['lieu'] as String? ?? '',
    diff: ((j['diff'] as num?)?.toInt() ?? 1).clamp(0, 3),
    showSD: j['showSD'] as bool? ?? true,
    virusSD: (j['virusSD'] as num?)?.toInt(),
    floors: (j['floors'] as List? ?? []).map((e) => Floor.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lieu': lieu,
    'diff': diff,
    'showSD': showSD,
    'virusSD': virusSD,
    'floors': floors.map((f) => f.toJson()).toList(),
  };

  Architecture copy() => Architecture.fromJson(toJson());
}

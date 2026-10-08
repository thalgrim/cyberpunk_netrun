/// Arbre des étages (Dart pur) : profondeur, enfants, parent, opérations d'édition.
library;

import '../models/architecture.dart';
import '../models/run_state.dart';

/// Ligne d'affichage de l'arbre.
class TreeRow {
  const TreeRow(this.floor, this.depth, this.level, this.branchFrom);

  final Floor floor;

  /// Numéro d'étage (racine = 1).
  final int depth;

  /// Niveau de retrait (0 = branche principale).
  final int level;

  /// Pour le premier étage d'un embranchement : profondeur de l'étage d'où il part
  /// (0 = point d'accès). Null sinon.
  final int? branchFrom;
}

class FloorTree {
  FloorTree(List<Floor> floors) : byId = {for (final f in floors) f.id: f} {
    // Parent effectif : un parent inexistant (ou un cycle) fait de l'étage une racine.
    for (final f in floors) {
      _parent[f.id] = byId.containsKey(f.parent) && f.parent != f.id ? f.parent : null;
    }
    for (final f in floors) {
      final seen = <String>{f.id};
      var p = _parent[f.id];
      while (p != null) {
        if (!seen.add(p)) {
          _parent[f.id] = null;
          break;
        }
        p = _parent[p];
      }
    }
    for (final f in floors) {
      (_kids[_parent[f.id]] ??= []).add(f);
    }
    for (final l in _kids.values) {
      l.sort((a, b) => a.ord.compareTo(b.ord));
    }
  }

  final Map<String, Floor> byId;
  final Map<String, String?> _parent = {};
  final Map<String?, List<Floor>> _kids = {};
  final Map<String, int> _depth = {};

  /// Enfants triés par `ord` ; `null` = racines.
  List<Floor> kids(String? parentId) => List.unmodifiable(_kids[parentId] ?? const <Floor>[]);

  List<Floor> get roots => kids(null);

  /// Parent (null si racine ou parent inexistant).
  Floor? parent(String id) {
    final p = _parent[id];
    return p == null ? null : byId[p];
  }

  String? parentId(String id) => _parent[id];

  /// Profondeur depuis la racine (racine = 1). 0 pour un id inconnu.
  int depth(String id) {
    if (!byId.containsKey(id)) return 0;
    final cached = _depth[id];
    if (cached != null) return cached;
    var n = 1;
    var p = _parent[id];
    while (p != null) {
      n++;
      p = _parent[p];
    }
    return _depth[id] = n;
  }

  /// Profondeur maximale de l'architecture.
  int get maxDepth => byId.keys.fold<int>(0, (m, id) => depth(id) > m ? depth(id) : m);

  /// Lignes d'affichage : chaque embranchement est inséré juste sous l'étage d'où il part,
  /// puis la branche principale continue.
  List<TreeRow> rows() {
    final out = <TreeRow>[];
    void chain(Floor f, int level, int? from) {
      Floor? cur = f;
      int? branchFrom = from;
      while (cur != null) {
        out.add(TreeRow(cur, depth(cur.id), level, branchFrom));
        branchFrom = null;
        final k = kids(cur.id);
        for (final b in k.skip(1)) {
          chain(b, level + 1, depth(cur.id));
        }
        cur = k.isEmpty ? null : k.first;
      }
    }

    final r = roots;
    if (r.isNotEmpty) {
      chain(r.first, 0, null);
      for (final b in r.skip(1)) {
        chain(b, 1, 0);
      }
    }
    return out;
  }

  /// Étage bloquant : `block ?? (kind == mdp)`.
  static bool isBlocking(Floor f) => f.block ?? (f.kind == FloorKind.mdp);

  /// L'étage a un test : mdp, fichier, noeud, ou vide avec un nom de test ou un SD.
  static bool hasTest(Floor f) {
    switch (f.kind) {
      case FloorKind.mdp:
      case FloorKind.fichier:
      case FloorKind.noeud:
        return true;
      case FloorKind.vide:
        return f.testName.trim().isNotEmpty || f.sd != null;
      case FloorKind.glace:
      case FloorKind.demon:
        return false;
    }
  }

  /// Clé d'état d'un GLACE : « floorId:index ».
  static String iceKey(String floorId, int index) => '$floorId:$index';

  /// Étage franchi.
  static bool cleared(Floor f, RunState s) {
    if (hasTest(f)) return s.done.contains(f.id);
    if (f.kind == FloorKind.glace) {
      for (var i = 0; i < f.ice.length; i++) {
        if (s.ice[iceKey(f.id, i)]?.down != true) return false;
      }
      return true;
    }
    if (f.kind == FloorKind.demon) return s.demon[f.id]?.down == true;
    return true;
  }
}

// ---------------------------------------------------------------------------
// Opérations d'édition (modifient la liste en place)
// ---------------------------------------------------------------------------

int _nextOrd(List<Floor> siblings) => siblings.fold<int>(-1, (m, f) => f.ord > m ? f.ord : m) + 1;

/// Insère [nf] au-dessus de [targetId] : il prend le parent et l'ordre de la cible,
/// qui devient son enfant.
void insertAbove(List<Floor> floors, String targetId, Floor nf) {
  final t = floors.firstWhere((f) => f.id == targetId);
  nf.parent = FloorTree(floors).parentId(t.id);
  nf.ord = t.ord;
  t.parent = nf.id;
  t.ord = 0;
  floors.add(nf);
}

/// Insère [nf] en dessous de [targetId] : les anciens enfants de la cible deviennent les siens.
void insertBelow(List<Floor> floors, String targetId, Floor nf) {
  final tree = FloorTree(floors);
  final kids = tree.kids(targetId);
  nf.parent = targetId;
  nf.ord = 0;
  for (final k in kids) {
    k.parent = nf.id;
  }
  floors.add(nf);
}

/// Nouvel embranchement : nouvel enfant de [targetId] avec un ordre supérieur aux autres.
void addBranch(List<Floor> floors, String targetId, Floor nf) {
  final kids = FloorTree(floors).kids(targetId);
  nf.parent = targetId;
  nf.ord = _nextOrd(kids);
  floors.add(nf);
}

/// Ajoute un étage tout en bas de la branche principale (ou le premier étage).
void appendMain(List<Floor> floors, Floor nf) {
  final tree = FloorTree(floors);
  var cur = tree.roots.isEmpty ? null : tree.roots.first;
  if (cur == null) {
    nf.parent = null;
    nf.ord = 0;
    floors.add(nf);
    return;
  }
  while (tree.kids(cur!.id).isNotEmpty) {
    cur = tree.kids(cur.id).first;
  }
  nf.parent = cur.id;
  nf.ord = 0;
  floors.add(nf);
}

/// Supprime [id]. Ses enfants remontent d'un cran : le premier reprend la place (et l'ordre)
/// de l'étage supprimé ; les autres se rattachent au parent, ou au premier enfant pour une racine.
void deleteFloor(List<Floor> floors, String id) {
  final tree = FloorTree(floors);
  final f = tree.byId[id];
  if (f == null) return;
  final parentId = tree.parentId(id);
  final kids = tree.kids(id);
  floors.removeWhere((x) => x.id == id);
  if (kids.isEmpty) return;
  final first = kids.first;
  final others = kids.skip(1).toList();
  first.parent = parentId;
  first.ord = f.ord;
  if (parentId != null) {
    final siblings = FloorTree(floors).kids(parentId).where((x) => !others.contains(x)).toList();
    var next = _nextOrd(siblings);
    for (final o in others) {
      o.parent = parentId;
      o.ord = next++;
    }
  } else {
    var next = _nextOrd(FloorTree(floors).kids(first.id));
    for (final o in others) {
      o.parent = first.id;
      o.ord = next++;
    }
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/catalog.dart';
import '../engine/dice.dart';
import '../engine/floor_tree.dart' as tree;
import '../engine/generator.dart';
import '../models/architecture.dart';
import '../storage/repository.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// Liste et édition des architectures (MJ).
class ArchitecturesState extends ChangeNotifier {
  ArchitecturesState(this._repo, {Dice? dice}) : _dice = dice ?? Dice(), _archis = _repo.loadArchis() {
    _selectedId = _archis.keys.isEmpty ? null : _archis.keys.first;
  }

  final Repository _repo;
  final Dice _dice;
  final Map<String, Architecture> _archis;
  String? _selectedId;
  Timer? _debounce;

  List<Architecture> get list => _archis.values.toList();
  Architecture? byId(String? id) => id == null ? null : _archis[id];
  Architecture? get selected => byId(_selectedId);

  void select(String id) {
    _selectedId = id;
    notifyListeners();
  }

  /// À appeler après chaque modification. [debounce] : anti-rebond de 300 ms (champs texte).
  void changed({bool debounce = false}) {
    notifyListeners();
    _debounce?.cancel();
    if (debounce) {
      _debounce = Timer(const Duration(milliseconds: 300), _save);
    } else {
      _save();
    }
  }

  void _save() => _repo.saveArchis(_archis);

  /// Enregistre immédiatement une sauvegarde en attente.
  void flush() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      _save();
    }
  }

  Floor newFloor(Architecture a) => Floor(id: newId(), kind: FloorKind.mdp, sd: a.difficulty.sd);

  List<Floor> _generated(int diff) => generate(diff, _dice, newId: newId);

  Architecture create({bool generated = false}) {
    final a = Architecture(
      id: newId(),
      name: generated ? 'Architecture générée ${_archis.length + 1}' : 'Nouvelle architecture',
      diff: 1,
    );
    if (generated) a.floors = _generated(a.diff);
    add(a);
    return a;
  }

  void add(Architecture a) {
    _archis[a.id] = a;
    _selectedId = a.id;
    changed();
  }

  Architecture duplicate(Architecture src) {
    final a = src.copy();
    final ids = {for (final f in a.floors) f.id: newId()};
    for (final f in a.floors) {
      f.id = ids[f.id]!;
      f.parent = f.parent == null ? null : ids[f.parent];
    }
    a.id = newId();
    a.name = '${src.name} (copie)';
    add(a);
    return a;
  }

  void delete(String id) {
    _archis.remove(id);
    if (_selectedId == id) _selectedId = _archis.keys.isEmpty ? null : _archis.keys.first;
    changed();
  }

  /// Retire les étages au dé selon la difficulté choisie.
  void regenerate(Architecture a) {
    a.floors = _generated(a.diff);
    changed();
  }

  // Étages -------------------------------------------------------------------

  Floor addFirst(Architecture a) {
    final f = newFloor(a);
    tree.appendMain(a.floors, f);
    changed();
    return f;
  }

  Floor insertAbove(Architecture a, String floorId) {
    final f = newFloor(a);
    tree.insertAbove(a.floors, floorId, f);
    changed();
    return f;
  }

  Floor insertBelow(Architecture a, String floorId) {
    final f = newFloor(a);
    tree.insertBelow(a.floors, floorId, f);
    changed();
    return f;
  }

  Floor addBranch(Architecture a, String floorId) {
    final f = newFloor(a);
    tree.addBranch(a.floors, floorId, f);
    changed();
    return f;
  }

  void deleteFloor(Architecture a, String floorId) {
    tree.deleteFloor(a.floors, floorId);
    changed();
  }

  /// Change le type : `block` revient à sa valeur par défaut, SD par défaut si nécessaire.
  void setKind(Architecture a, Floor f, FloorKind k) {
    f.kind = k;
    f.block = null;
    if (floorKinds[k]!.hasSd && k != FloorKind.vide) f.sd ??= a.difficulty.sd;
    if (k == FloorKind.glace && f.ice.isEmpty) f.ice = ['Cerbère'];
    changed();
  }

  @override
  void dispose() {
    flush();
    _debounce?.cancel();
    super.dispose();
  }
}

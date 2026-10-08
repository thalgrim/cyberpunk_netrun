import 'package:flutter/foundation.dart';

import '../engine/dice.dart';
import '../engine/netrun_engine.dart';
import '../models/architecture.dart';
import '../models/run_state.dart';
import '../storage/repository.dart';
import 'app_state.dart';
import 'architectures_state.dart';
import 'deck_state.dart';

/// Pilote le moteur pour l'architecture proposée et sauvegarde la run.
class RunController extends ChangeNotifier {
  RunController({required this._repo, required this.app, required this.archis, required this.decks, Dice? dice})
    : _dice = dice ?? Dice();

  final Repository _repo;
  final AppState app;
  final ArchitecturesState archis;
  final DeckState decks;
  final Dice _dice;
  final Map<String, RunState> _runs = {};

  /// Architecture proposée au joueur.
  Architecture? get archi => archis.byId(app.activeArchiId);

  RunState? runFor(String archiId) => _runs.putIfAbsent(archiId, () => _repo.loadRun(archiId) ?? RunState());

  RunState? get run {
    final a = archi;
    return a == null ? null : runFor(a.id);
  }

  /// Moteur pour l'architecture proposée (lecture ou action).
  NetrunEngine? engine() {
    final a = archi;
    final s = run;
    if (a == null || s == null) return null;
    return NetrunEngine(archi: a, s: s, deck: decks.deck, dice: _dice);
  }

  /// Exécute une action et sauvegarde. Renvoie le message destiné au SnackBar.
  String? act(bool Function(NetrunEngine e) action) {
    final e = engine();
    if (e == null) return 'Aucune architecture proposée.';
    action(e);
    _repo.saveRun(e.archi.id, e.s);
    decks.changed();
    notifyListeners();
    return e.toast;
  }

  void setPs(int? ps) {
    final a = archi;
    final s = run;
    if (a == null || s == null) return;
    s.ps = ps;
    _repo.saveRun(a.id, s);
    notifyListeners();
  }

  void reset(String archiId) {
    _runs[archiId] = RunState();
    _repo.saveRun(archiId, _runs[archiId]!);
    notifyListeners();
  }

  void forget(String archiId) {
    _runs.remove(archiId);
    _repo.deleteRun(archiId);
    notifyListeners();
  }
}

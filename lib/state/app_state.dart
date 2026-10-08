import 'package:flutter/foundation.dart';

import '../storage/repository.dart';

enum AppTab { architectures, suivi, netrun, console }

/// Rôle (MJ / joueur verrouillé), onglet courant, architecture proposée.
class AppState extends ChangeNotifier {
  AppState(this._repo) {
    final lock = _repo.loadLock();
    _locked = lock.locked;
    _pin = lock.pin;
    _gmPin = _repo.loadGmPin();
    _activeArchiId = _repo.loadActiveArchiId();
    _tab = _locked ? AppTab.netrun : AppTab.architectures;
  }

  final Repository _repo;

  late bool _locked;
  late String _pin;
  late String _gmPin;
  String? _activeArchiId;
  late AppTab _tab;

  /// Mode joueur verrouillé.
  bool get locked => _locked;
  bool get hasPin => _pin.isNotEmpty;

  /// Dernier code utilisé par le MJ (proposé par défaut).
  String get gmPin => _gmPin;
  String? get activeArchiId => _activeArchiId;
  AppTab get tab => tabs.contains(_tab) ? _tab : tabs.first;

  List<AppTab> get tabs => _locked ? const [AppTab.netrun, AppTab.console] : AppTab.values;

  void setTab(AppTab t) {
    if (!tabs.contains(t) || t == _tab) return;
    _tab = t;
    notifyListeners();
  }

  void propose(String? archiId) {
    _activeArchiId = archiId;
    _repo.saveActiveArchiId(archiId);
    notifyListeners();
  }

  /// Passe la main au joueur.
  void lock(String pin) {
    _locked = true;
    _pin = pin;
    _tab = AppTab.netrun;
    _repo.saveLock(true, pin);
    if (pin.isNotEmpty) {
      _gmPin = pin;
      _repo.saveGmPin(pin);
    }
    notifyListeners();
  }

  /// Retour en mode MJ. Faux si le code est incorrect.
  bool unlock(String code) {
    if (_pin.isNotEmpty && code != _pin) return false;
    _locked = false;
    _tab = AppTab.netrun;
    _repo.saveLock(false, _pin);
    notifyListeners();
    return true;
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/architecture.dart';
import '../models/deck.dart';
import '../models/run_state.dart';

/// Lecture et écriture JSON dans shared_preferences.
class Repository {
  Repository(this._prefs);

  final SharedPreferences _prefs;

  static const _kArchis = 'archis';
  static const _kActive = 'activeArchiId';
  static const _kDeck = 'deck';
  static const _kLock = 'lock';
  static const _kGmPin = 'gmPin';
  static String _kRun(String archiId) => 'run:$archiId';

  static Future<Repository> open() async => Repository(await SharedPreferences.getInstance());

  Map<String, dynamic>? _readMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map ? Map<String, dynamic>.from(v) : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _writeMap(String key, Map<String, dynamic> value) => _prefs.setString(key, jsonEncode(value));

  // Architectures ------------------------------------------------------------

  Map<String, Architecture> loadArchis() {
    final m = _readMap(_kArchis) ?? {};
    final out = <String, Architecture>{};
    for (final e in m.entries) {
      try {
        out[e.key] = Architecture.fromJson(Map<String, dynamic>.from(e.value as Map));
      } catch (_) {
        // Entrée corrompue : ignorée.
      }
    }
    return out;
  }

  Future<void> saveArchis(Map<String, Architecture> archis) =>
      _writeMap(_kArchis, archis.map((k, v) => MapEntry(k, v.toJson())));

  String? loadActiveArchiId() => _prefs.getString(_kActive);

  Future<void> saveActiveArchiId(String? id) => id == null ? _prefs.remove(_kActive) : _prefs.setString(_kActive, id);

  // Runs ---------------------------------------------------------------------

  RunState? loadRun(String archiId) {
    final m = _readMap(_kRun(archiId));
    if (m == null) return null;
    try {
      return RunState.fromJson(m);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRun(String archiId, RunState run) => _writeMap(_kRun(archiId), run.toJson());

  Future<void> deleteRun(String archiId) => _prefs.remove(_kRun(archiId));

  // Cyberconsole ---------------------------------------------------------------

  Deck loadDeck() {
    final m = _readMap(_kDeck);
    if (m == null) return Deck();
    try {
      return Deck.fromJson(m);
    } catch (_) {
      return Deck();
    }
  }

  Future<void> saveDeck(Deck deck) => _writeMap(_kDeck, deck.toJson());

  // Verrouillage ---------------------------------------------------------------

  ({bool locked, String pin}) loadLock() {
    final m = _readMap(_kLock);
    return (locked: m?['locked'] as bool? ?? false, pin: m?['pin'] as String? ?? '');
  }

  Future<void> saveLock(bool locked, String pin) => _writeMap(_kLock, {'locked': locked, 'pin': pin});

  String loadGmPin() => _prefs.getString(_kGmPin) ?? '';

  Future<void> saveGmPin(String pin) => _prefs.setString(_kGmPin, pin);
}

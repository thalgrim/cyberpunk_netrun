import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/catalog.dart';
import '../models/deck.dart';
import '../storage/repository.dart';

/// Cyberconsole et profil du netrunner (propres à l'appareil).
class DeckState extends ChangeNotifier {
  DeckState(this._repo) : deck = _repo.loadDeck();

  final Repository _repo;
  final Deck deck;

  void changed() {
    _repo.saveDeck(deck);
    notifyListeners();
  }

  void setModel(String type) {
    deck.type = type;
    final slots = deckModels[type];
    if (slots != null) deck.slots = slots;
    changed();
  }

  void setSlots(int slots) {
    deck.slots = slots.clamp(1, 30);
    changed();
  }

  void setArm(bool v) {
    deck.arm = v;
    changed();
  }

  void setSuit(bool v) {
    deck.suit = v;
    changed();
  }

  void setRank(int? rank) {
    deck.me.rank = rank?.clamp(0, 10);
    changed();
  }

  void setVit(int vit) {
    deck.me.vit = vit;
    changed();
  }

  void setPsMax(int? ps) {
    deck.me.psMax = ps;
    changed();
  }

  /// Installe un élément. Faux s'il ne tient pas.
  bool install(String k, String n) {
    final item = DeckItem(id: const Uuid().v4(), k: k, n: n);
    if (!deck.canAdd(item)) return false;
    deck.items.add(item);
    changed();
    return true;
  }

  void remove(String id) {
    deck.items.removeWhere((i) => i.id == id);
    changed();
  }

  void forgetSaved(String id) {
    deck.saved.removeWhere((i) => i.id == id);
    changed();
  }
}

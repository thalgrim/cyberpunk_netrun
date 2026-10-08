/// Moteur de Netrun (livre p. 196-211). Dart pur, sans dépendance à Flutter.
library;

import 'dart:math';

import '../data/catalog.dart';
import '../models/architecture.dart';
import '../models/deck.dart';
import '../models/run_state.dart';
import 'dice.dart';
import 'floor_tree.dart';

/// Adversaire affichable dans le Combat.
class Enemy {
  const Enemy.ice(this.key, this.floorId, this.iceDef, this.ice) : demonDef = null, demon = null;
  const Enemy.demon(this.key, this.floorId, this.demonDef, this.demon) : iceDef = null, ice = null;

  /// Clé de cible : « floorId:index » pour un GLACE, floorId pour un Démon.
  final String key;
  final String floorId;
  final IceDef? iceDef;
  final IceState? ice;
  final DemonDef? demonDef;
  final DemonState? demon;

  bool get isDemon => demonDef != null;
  String get name => iceDef?.name ?? 'Démon ${demonDef!.name}';
  int get rez => ice?.rez ?? demon!.rez;
  int get rezMax => iceDef?.rez ?? demonDef!.rez;
}

class NetrunEngine {
  NetrunEngine({required this.archi, required this.s, required this.deck, required this.dice})
    : tree = FloorTree(archi.floors) {
    // L'architecture a pu être modifiée par le MJ : une position disparue revient au point d'accès.
    if (s.pos != null && !tree.byId.containsKey(s.pos)) s.pos = null;
  }

  final Architecture archi;
  final RunState s;
  final Deck deck;
  final Dice dice;
  final FloorTree tree;

  /// Message court destiné à un SnackBar (refus, avertissement).
  String? toast;

  final List<String> _lines = [];
  int _dmg = 0;
  int? _psBefore;
  bool _progHit = false;

  // -------------------------------------------------------------------------
  // Lecture
  // -------------------------------------------------------------------------

  int get rank => deck.me.rank ?? 0;
  Floor? get current => s.pos == null ? null : tree.byId[s.pos];
  int get currentDepth => s.pos == null ? 0 : tree.depth(s.pos!);

  int sdOf(Floor f) => f.sd ?? archi.difficulty.sd;

  String testNameOf(Floor f) {
    if (f.kind == FloorKind.vide) return f.testName.trim().isEmpty ? 'Test' : f.testName.trim();
    return floorKinds[f.kind]!.test;
  }

  String floorTitle(String id) => 'Étage ${tree.depth(id)} : ${kindName(tree.byId[id]!.kind)}';

  /// SD affiché au joueur (masqué si l'architecture ne montre pas les SD).
  String sdText(int sd) => archi.showSD ? 'SD $sd' : 'SD ?';

  IceState iceState(String floorId, int index) {
    final f = tree.byId[floorId]!;
    return s.ice.putIfAbsent(
      FloorTree.iceKey(floorId, index),
      () => IceState(at: floorId, rez: iceByName[f.ice[index]]?.rez ?? 10),
    );
  }

  DemonState demonState(String floorId) {
    final f = tree.byId[floorId]!;
    return s.demon.putIfAbsent(floorId, () => DemonState(rez: demonByName[f.demon]?.rez ?? 15));
  }

  ProgState progState(DeckItem item) =>
      s.prog.putIfAbsent(item.id, () => ProgState(rez: item.isIce ? (item.ice?.rez ?? 0) : (item.prog?.rez ?? 0)));

  bool isOn(DeckItem item) => s.prog[item.id]?.on == true;

  /// Clés de tous les GLACE de l'architecture, dans l'ordre d'affichage (états créés au besoin).
  List<String> allIceKeys() {
    final out = <String>[];
    for (final row in tree.rows()) {
      final f = row.floor;
      if (f.kind != FloorKind.glace) continue;
      for (var i = 0; i < f.ice.length; i++) {
        iceState(f.id, i);
        out.add(FloorTree.iceKey(f.id, i));
      }
    }
    return out;
  }

  IceDef? iceDefOf(String key) {
    final i = key.lastIndexOf(':');
    if (i < 0) return null;
    final f = tree.byId[key.substring(0, i)];
    final idx = int.tryParse(key.substring(i + 1));
    if (f == null || idx == null || idx >= f.ice.length) return null;
    return iceByName[f.ice[idx]];
  }

  List<String> chasingKeys() => allIceKeys().where((k) => s.ice[k]!.chasing).toList();

  List<String> activeDemonIds() => [
    for (final row in tree.rows())
      if (row.floor.kind == FloorKind.demon && s.demon[row.floor.id]?.active == true) row.floor.id,
  ];

  /// GLACE en chasse et Démons actifs.
  List<Enemy> enemies() {
    final out = <Enemy>[];
    for (final k in chasingKeys()) {
      final def = iceDefOf(k);
      if (def != null) out.add(Enemy.ice(k, k.substring(0, k.lastIndexOf(':')), def, s.ice[k]!));
    }
    for (final id in activeDemonIds()) {
      final def = demonByName[tree.byId[id]!.demon];
      if (def != null) out.add(Enemy.demon(id, id, def, s.demon[id]!));
    }
    return out;
  }

  List<DeckItem> rezzedItems() => deck.items.where(isOn).toList();

  /// Bonus d'un type apporté par les programmes rezzés (+2 par programme).
  int bonus(Bonus b) => rezzedItems().where((i) => i.prog?.bonus == b).length * 2;

  bool get armorOn => bonus(Bonus.armure) > 0;

  /// Libellés des bonus actifs (« Porte dérobée +2 »…).
  List<String> activeBonusLabels() {
    const labels = {
      Bonus.porte: 'Porte dérobée',
      Bonus.cartographie: 'Cartographie',
      Bonus.masquage: 'Masquage',
      Bonus.vitesse: 'VIT',
    };
    final out = <String>[];
    for (final e in labels.entries) {
      final v = bonus(e.key);
      if (v > 0) out.add('${e.value} +$v');
    }
    if (armorOn) out.add('Armure −4 dégâts au cerveau');
    return out;
  }

  /// Malus de Glissement : −2 par Putois qui t'a touché et n'est pas dérezzé.
  int get slideMalus {
    var m = 0;
    for (final k in allIceKeys()) {
      final st = s.ice[k]!;
      if (iceDefOf(k)?.name == 'Putois' && st.hit && !st.down) m -= 2;
    }
    return m;
  }

  bool canTest() {
    final f = current;
    return s.isOn && f != null && FloorTree.hasTest(f) && !s.done.contains(f.id);
  }

  /// Le Virus peut être largué ici : étage sans enfant, à la profondeur maximale.
  bool atVirusSpot() {
    final f = current;
    return archi.virusSD != null && f != null && tree.kids(f.id).isEmpty && tree.depth(f.id) == tree.maxDepth;
  }

  /// Raison qui empêche de descendre (null = permis).
  String? descendBlock() {
    if (s.kraken > 0) return 'Le Kraken t\'empêche de progresser ce tour.';
    final f = current;
    if (f != null && FloorTree.isBlocking(f) && !FloorTree.cleared(f, s)) {
      switch (f.kind) {
        case FloorKind.glace:
          return 'Cet étage te bloque : dérezze ses GLACE d\'abord.';
        case FloorKind.demon:
          return 'Cet étage te bloque : dérezze son Démon d\'abord.';
        default:
          return 'Cet étage te bloque : réussis son test d\'abord.';
      }
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Outils internes
  // -------------------------------------------------------------------------

  bool _refuse(String msg) {
    toast = msg;
    return false;
  }

  void _start() {
    _lines.clear();
    _dmg = 0;
    _psBefore = s.ps;
    _progHit = false;
  }

  void _finish(String h, bool? ok) {
    s.last = RunResult(
      h: h,
      lines: [..._lines],
      ok: ok,
      sum: _dmg > 0 ? DamageSummary(tot: _dmg, from: _psBefore, to: s.ps) : null,
    );
  }

  void _log(String txt, [String c = '']) {
    s.log.insert(0, LogEntry(t: s.turn, txt: txt, c: c));
    if (s.log.length > RunState.maxLog) s.log.removeRange(RunState.maxLog, s.log.length);
  }

  bool _spend() {
    if (s.actions <= 0) return _refuse('Plus d\'action virtuelle ce tour : termine ton tour.');
    s.actions--;
    s.spent++;
    return true;
  }

  bool _needOn() {
    if (!s.isOn) return _refuse('Tu n\'es pas connecté.');
    return true;
  }

  PlayerRoll _p(int mod) => dice.pRoll(rank, mod);

  void _derezAll() {
    for (final p in s.prog.values) {
      p.on = false;
    }
  }

  /// Dégâts encaissés par le netrunner.
  void hurt(DiceRoll roll, String reason, {bool brain = true}) {
    var dmg = roll.total;
    var armor = 0;
    if (brain && armorOn) {
      armor = min(4, dmg);
      dmg -= armor;
    }
    _dmg += dmg;
    final before = s.ps;
    if (s.ps != null) s.ps = s.ps! - dmg;
    final psText = before == null ? '' : ' (PS $before → ${s.ps})';
    final kind = brain ? 'dégâts au cerveau encaissés' : 'dégâts encaissés';
    if (roll.dice.isEmpty && !brain) {
      _lines.add('$reason : $dmg $kind$psText.');
    } else {
      final armorText = armor > 0 ? ', Armure −$armor' : '';
      _lines.add('$reason : ${roll.detail}$armorText → $dmg $kind$psText.');
    }
  }

  void _destroy(DeckItem item) {
    deck.items.removeWhere((i) => i.id == item.id);
    s.prog.remove(item.id);
    var txt = '${item.n} est détruit.';
    if (!item.isIce && deck.hasHardware(hwBackup)) {
      deck.saved.add(item);
      txt += ' Sauvegardé sur ton disque dur.';
    }
    _lines.add(txt);
    _progHit = true;
  }

  // -------------------------------------------------------------------------
  // Connexion
  // -------------------------------------------------------------------------

  bool connect() {
    if (s.isOn) return _refuse('Tu es déjà connecté.');
    if (s.isOut) return _refuse('Prépare d\'abord une nouvelle connexion.');
    if (deck.me.rank == null) return _refuse('Indique ton rang d\'Interface dans l\'onglet Cyberconsole.');
    _start();
    if (s.ps == null && deck.me.psMax != null) s.ps = deck.me.psMax;
    s.status = 'on';
    s.prog = {};
    s.pos = null;
    s.turn = 1;
    s.pen = 0;
    s.slid = false;
    s.kraken = 0;
    s.spent = 1;
    s.actions = apt(rank) - 1;
    for (final st in s.ice.values) {
      if (st.chasing) st.st = 'waiting';
    }
    for (final st in s.demon.values) {
      if (st.active) st.st = 'waiting';
    }
    _lines.add('Tu es au point d\'accès. La première porte est devant toi.');
    _finish('Connecté', null);
    _log('Connexion (1 action).', 'ok');
    return true;
  }

  bool jackout() {
    if (!_needOn()) return false;
    if (s.kraken > 0) return _refuse('Le Kraken t\'empêche de te déconnecter ce tour.');
    if (!_spend()) return false;
    _start();
    s.status = 'out';
    _derezAll();
    _lines.add('Tu quittes l\'architecture proprement. Tous tes programmes sont dérezzés.');
    _finish('Déconnecté', null);
    _log('Déconnexion.');
    return true;
  }

  bool reconnect() {
    if (!s.isOut) return _refuse('Tu n\'es pas déconnecté.');
    _derezAll();
    s.status = 'off';
    s.pos = null;
    s.last = null;
    s.burning = false;
    s.kraken = 0;
    _log('Prêt pour une nouvelle connexion.');
    return true;
  }

  // -------------------------------------------------------------------------
  // Déplacements
  // -------------------------------------------------------------------------

  bool move(String? targetId) {
    if (!_needOn()) return false;
    final pos = s.pos;
    final upId = pos == null ? null : tree.parentId(pos);
    final goingUp = pos != null && targetId == upId;
    if (goingUp) {
      if (targetId == null) {
        s.pos = null;
        _start();
        _lines.add('La première porte est devant toi.');
        _finish('Point d\'accès', null);
        _log('Retour au point d\'accès.');
        return true;
      }
      final waiting = allIceKeys().any((k) => s.ice[k]!.waiting && s.ice[k]!.at == targetId);
      if (waiting) {
        enter(targetId);
      } else {
        s.pos = targetId;
        s.seen.add(targetId);
        _start();
        final f = tree.byId[targetId]!;
        _lines.add(f.label.trim().isEmpty ? 'Tu remontes.' : f.label.trim());
        _finish(floorTitle(targetId), null);
        _log('Remonte à l\'étage ${tree.depth(targetId)}.');
      }
      return true;
    }
    if (targetId == null || !tree.kids(pos).any((f) => f.id == targetId)) {
      return _refuse('Cette porte n\'est pas accessible d\'ici.');
    }
    final block = descendBlock();
    if (block != null) return _refuse(block);
    enter(targetId);
    return true;
  }

  /// Entrée dans un étage : rencontres des GLACE en attente, réveil du Démon.
  void enter(String id) {
    _start();
    s.pos = id;
    s.seen.add(id);
    final f = tree.byId[id]!;
    var events = false;
    var surprised = false;
    for (final key in allIceKeys()) {
      final st = s.ice[key]!;
      if (!st.waiting || st.at != id) continue;
      final def = iceDefOf(key);
      if (def == null) continue;
      events = true;
      final p = _p(deck.me.vit + bonus(Bonus.vitesse));
      final die = dice.d(10);
      final ice = def.vit + die;
      st.st = 'chasing';
      final head = '${def.name} : VIT ${def.vit} + dé $die = $ice contre ta réaction ${p.full}.';
      if (beats(ice, p.total)) {
        surprised = true;
        _lines.add('$head Il te surprend !');
        _log('${def.name} te surprend ($ice contre ${p.total}).', 'ko');
        _iceHits(key, def);
        if (!s.isOn) break;
      } else {
        _lines.add('$head Tu es plus rapide, il te poursuit.');
        _log('${def.name} te poursuit ($ice contre ${p.total}).');
      }
    }
    if (s.isOn && f.kind == FloorKind.demon) {
      final d = demonState(id);
      if (d.waiting) {
        d.st = 'active';
        events = true;
        _lines.add('Le Démon ${f.demon} t\'a repéré.');
        _log('Le Démon ${f.demon} t\'a repéré.', 'ko');
      }
    }
    if (!events) _lines.add(f.label.trim().isEmpty ? 'La porte s\'ouvre.' : f.label.trim());
    _finish(floorTitle(id), surprised || _dmg > 0 ? false : null);
    _log('Étage ${tree.depth(id)} : ${kindName(f.kind)}.');
  }

  // -------------------------------------------------------------------------
  // Capacités d'Interface
  // -------------------------------------------------------------------------

  bool test() {
    if (!_needOn()) return false;
    final f = current;
    if (f == null || !FloorTree.hasTest(f)) return _refuse('Rien à tester ici.');
    if (s.done.contains(f.id)) return _refuse('Déjà réussi.');
    if (!_spend()) return false;
    _start();
    final name = testNameOf(f);
    final mod = f.kind == FloorKind.mdp ? bonus(Bonus.porte) : 0;
    final sd = sdOf(f);
    final p = _p(mod);
    final ok = beats(p.total, sd);
    _lines.add('$name : ${p.full} contre ${sdText(sd)}.');
    if (ok) {
      s.done.add(f.id);
      _lines.add(switch (f.kind) {
        FloorKind.mdp => 'Mot de passe contourné, la voie est libre.',
        FloorKind.fichier => 'Fichier ouvert.',
        FloorKind.noeud => 'Nœud de contrôle sous ton contrôle.',
        _ => 'Réussi.',
      });
      if (f.info.trim().isNotEmpty) _lines.add(f.info.trim());
    } else {
      _lines.add('Échec. Tu peux retenter avec une autre action.');
    }
    _finish(name, ok);
    _log('$name ${sdText(sd)} : ${p.total}, ${ok ? 'réussite' : 'échec'}.', ok ? 'ok' : 'ko');
    return true;
  }

  /// Élimination contre un GLACE en chasse ou un Démon actif.
  bool zap(String targetKey, [String? programId]) {
    if (!_needOn()) return false;
    final isIce = targetKey.contains(':');
    IceDef? iceDef;
    DemonDef? demonDef;
    if (isIce) {
      iceDef = iceDefOf(targetKey);
      if (iceDef == null || s.ice[targetKey]?.chasing != true) return _refuse('Ce GLACE ne te poursuit pas.');
    } else {
      final f = tree.byId[targetKey];
      demonDef = f == null ? null : demonByName[f.demon];
      if (demonDef == null || s.demon[targetKey]?.active != true) return _refuse('Ce Démon n\'est pas actif.');
    }
    var mod = 0;
    var formula = '1d6';
    var label = 'Élimination';
    if (programId != null) {
      final item = deck.items.where((i) => i.id == programId).firstOrNull;
      final def = item?.prog;
      if (def == null || def.type != ProgType.offensif || def.cls != antiprogramme || def.iceDmg == null) {
        return _refuse('Ce programme ne peut pas attaquer un GLACE.');
      }
      mod = def.att;
      formula = def.iceDmg!;
      label = 'Élimination avec ${def.name}';
    }
    if (!_spend()) return false;
    _start();
    final name = iceDef?.name ?? 'Démon ${demonDef!.name}';
    final p = _p(mod);
    final die = dice.d(10);
    final defVal = iceDef?.def ?? demonDef!.iface;
    final defense = defVal + die;
    final defLabel = iceDef != null ? 'DÉF' : 'Interface';
    final hit = beats(p.total, defense);
    _lines.add(
      '$label contre $name : ${p.full} contre $defLabel $defVal + dé $die = $defense. '
      '${hit ? 'Touché !' : 'Raté.'}',
    );
    if (hit) {
      final r = dice.rollFormula(formula);
      final before = isIce ? s.ice[targetKey]!.rez : s.demon[targetKey]!.rez;
      final after = max(0, before - r.total);
      if (isIce) {
        s.ice[targetKey]!.rez = after;
        if (after == 0) s.ice[targetKey]!.st = 'down';
      } else {
        s.demon[targetKey]!.rez = after;
        if (after == 0) s.demon[targetKey]!.st = 'down';
      }
      _lines.add('Dégâts : ${r.detail}. REZ $before → $after${after == 0 ? ' : $name est dérezzé.' : '.'}');
    }
    _finish(label, hit);
    _log('$label contre $name : ${p.total} contre $defense, ${hit ? 'touché' : 'raté'}.', hit ? 'ok' : 'ko');
    return true;
  }

  bool slide(String iceKey) {
    if (!_needOn()) return false;
    final def = iceDefOf(iceKey);
    final st = s.ice[iceKey];
    if (def == null || st == null || !st.chasing) return _refuse('Ce GLACE ne te poursuit pas.');
    if (s.slid) return _refuse('Tu as déjà tenté un Glissement ce tour.');
    if (!_spend()) return false;
    s.slid = true;
    _start();
    final p = _p(slideMalus);
    final die = dice.d(10);
    final per = def.per + die;
    final ok = beats(p.total, per);
    _lines.add('Glissement : ${p.full} contre PER ${def.per} + dé $die = $per.');
    if (ok) {
      st.st = 'waiting';
      st.at = s.pos ?? '';
      _lines.add('${def.name} perd ta trace et reste en attente à cet étage. Change d\'étage maintenant.');
    } else {
      _lines.add('${def.name} te colle toujours.');
    }
    _finish('Glissement', ok);
    _log('Glissement contre ${def.name} : ${p.total} contre $per, ${ok ? 'réussite' : 'échec'}.', ok ? 'ok' : 'ko');
    return true;
  }

  bool carto() {
    if (!_needOn()) return false;
    if (!_spend()) return false;
    _start();
    final p = _p(bonus(Bonus.cartographie));
    final r = p.total;
    final base = currentDepth;
    var found = 0;
    final queue = [...tree.kids(s.pos)];
    while (queue.isNotEmpty) {
      final f = queue.removeAt(0);
      if (tree.depth(f.id) - base > r) continue;
      if (!s.seen.contains(f.id) && !s.carto.contains(f.id)) {
        s.carto.add(f.id);
        found++;
      }
      final lockedBelow = f.kind == FloorKind.mdp && !s.done.contains(f.id) && sdOf(f) > r;
      if (!lockedBelow) queue.addAll(tree.kids(f.id));
    }
    _lines.add('Cartographie : ${p.full}.');
    _lines.add(
      found == 0
          ? 'Rien de nouveau.'
          : '$found étage${found > 1 ? 's' : ''} révélé${found > 1 ? 's' : ''} : vois « Architecture connue ».',
    );
    _finish('Cartographie', found > 0 ? true : null);
    _log('Cartographie : $r, $found étage(s) révélé(s).', found > 0 ? 'ok' : '');
    return true;
  }

  bool masq() {
    if (!_needOn()) return false;
    if (!_spend()) return false;
    _start();
    final p = _p(bonus(Bonus.masquage));
    s.masq = p.total;
    _lines.add('Masquage : ${p.full}.');
    _lines.add('Un Netrunner devra dépasser ${p.total} en Cartographie pour retrouver tes traces.');
    _finish('Masquage', true);
    _log('Masquage : ${p.total}.', 'ok');
    return true;
  }

  bool virus() {
    if (!_needOn()) return false;
    if (!atVirusSpot()) return _refuse('Un Virus se largue au fond de l\'architecture.');
    if (!_spend()) return false;
    _start();
    final sd = archi.virusSD!;
    final p = _p(0);
    final ok = beats(p.total, sd);
    _lines.add('Virus : ${p.full} contre ${sdText(sd)}.');
    if (ok) {
      s.virus = p.total;
      _lines.add('Ton Virus est en place. Il faudra un SD ${p.total} pour le détruire. Décris ses effets au MJ.');
    } else {
      _lines.add('Échec. Tu peux retenter avec une autre action.');
    }
    _finish('Virus', ok);
    _log('Virus ${sdText(sd)} : ${p.total}, ${ok ? 'réussite' : 'échec'}.', ok ? 'ok' : 'ko');
    return true;
  }

  // -------------------------------------------------------------------------
  // Actions réelles
  // -------------------------------------------------------------------------

  bool extinguish() {
    if (!_needOn()) return false;
    if (!s.burning) return _refuse('Tu n\'es pas en feu.');
    if (s.spent > 0) {
      return _refuse('Éteindre les flammes est une action réelle : impossible après des actions virtuelles.');
    }
    _start();
    s.burning = false;
    s.actions = 0;
    _lines.add('Tu éteins les flammes (action réelle). Termine ton tour.');
    _finish('Flammes éteintes', true);
    _log('Flammes éteintes.', 'ok');
    return true;
  }

  /// Réinstalle les programmes sauvés sur le disque dur.
  bool restore() {
    if (deck.saved.isEmpty) return _refuse('Aucun programme sur le disque dur.');
    if (s.isOn && s.spent > 0) {
      return _refuse('Réinstaller est une action réelle : impossible après des actions virtuelles.');
    }
    final restored = <String>[];
    for (final item in [...deck.saved]) {
      if (deck.canAdd(item)) {
        deck.items.add(item);
        deck.saved.remove(item);
        restored.add(item.n);
      }
    }
    if (restored.isEmpty) return _refuse('Plus assez d\'emplacements.');
    if (s.isOn) {
      s.actions = 0;
      _start();
      _lines.add('Réinstallé : ${restored.join(', ')}.');
      if (deck.saved.isNotEmpty) _lines.add('Plus assez d\'emplacements pour le reste.');
      _finish('Réinstallation (action réelle)', true);
    }
    _log('Réinstallé : ${restored.join(', ')}.', 'ok');
    toast = 'Réinstallé : ${restored.join(', ')}.';
    return true;
  }

  // -------------------------------------------------------------------------
  // Programmes
  // -------------------------------------------------------------------------

  bool rez(String itemId) {
    if (!_needOn()) return false;
    final item = deck.items.where((i) => i.id == itemId).firstOrNull;
    if (item == null || item.isHw) return _refuse('Élément introuvable.');
    final def = item.prog;
    if (def != null && def.type == ProgType.offensif) {
      return _refuse('Les programmes offensifs s\'utilisent dans le Combat.');
    }
    final st = progState(item);
    if (st.on) return _refuse('Déjà rezzé.');
    if (st.rezRound == s.turn) return _refuse('Ce programme a déjà été activé ce tour.');
    if (def != null && def.once) {
      if (st.used) return _refuse('Déjà utilisé pendant cette Netrun.');
      final other = deck.items.any((i) => i.id != item.id && i.n == item.n && isOn(i));
      if (other) return _refuse('Une seule copie à la fois.');
    }
    if (!_spend()) return false;
    _start();
    st.on = true;
    st.rezRound = s.turn;
    if (def != null && def.once) st.used = true;
    _lines.add('${item.n} est rezzé (REZ ${st.rez}).');
    if (def != null) {
      if (def.bonusLabel.isNotEmpty) _lines.add('Bonus : ${def.bonusLabel}.');
      if (def.noIce) _lines.add('Sans effet contre les GLACE.');
    }
    final ice = item.ice;
    if (ice != null) {
      if (!ice.antiProg) {
        _lines.add('Ton GLACE ${ice.name} est antipersonnel : il ne chasse que les Netrunners, aucun effet ici.');
      } else {
        final targets = chasingKeys();
        st.tgt = targets.isEmpty ? null : targets.first;
        _lines.add(
          st.tgt == null
              ? 'Aucun GLACE ennemi en chasse : il attaquera le premier qui te poursuit, en fin de tour.'
              : 'Il attaquera ${iceDefOf(st.tgt!)!.name} en fin de tour.',
        );
      }
    }
    _finish('Rezzer : ${item.n}', true);
    _log('${item.n} rezzé.', 'ok');
    return true;
  }

  bool derez(String itemId) {
    if (!_needOn()) return false;
    final item = deck.items.where((i) => i.id == itemId).firstOrNull;
    if (item == null || !isOn(item)) return _refuse('Ce programme n\'est pas rezzé.');
    if (!_spend()) return false;
    _start();
    s.prog[item.id]!.on = false;
    _lines.add('${item.n} est dérezzé.');
    _finish('Dérezzer : ${item.n}', null);
    _log('${item.n} dérezzé.');
    return true;
  }

  // -------------------------------------------------------------------------
  // GLACE ennemis
  // -------------------------------------------------------------------------

  /// Effet d'un GLACE qui touche. [atk] = jet d'attaque (fin de tour) ; null = surprise.
  void _iceHits(String key, IceDef def, {int? atk}) {
    s.ice[key]?.hit = true;
    if (def.antiProg) {
      _antiProgram(def, atk);
      return;
    }
    switch (def.name) {
      case 'Cobra':
        final targets = deck.items.where((i) => !i.isHw).toList();
        if (targets.isEmpty) {
          _lines.add('Cobra cherche un programme installé : aucun, sans effet.');
        } else {
          final t = targets[dice.random(targets.length)];
          _lines.add('Cobra s\'attaque à ${t.n}.');
          _destroy(t);
        }
      case 'Corbeau':
        final targets = rezzedItems().where((i) => i.prog?.type == ProgType.defensif).toList();
        if (targets.isEmpty) {
          _lines.add('Corbeau cherche un programme défensif rezzé : aucun.');
        } else {
          final t = targets[dice.random(targets.length)];
          s.prog[t.id]!.on = false;
          _progHit = true;
          _lines.add('Corbeau dérezze ${t.n}.');
        }
        hurt(dice.rollFormula('1d6'), 'Dégâts du Corbeau');
      case 'Cerbère':
        hurt(dice.rollFormula('2d6'), 'Dégâts du Cerbère');
        if (deck.hasHardware(hwCablage)) {
          _lines.add('Câblage isolé : pas d\'incendie.');
        } else if (!s.burning) {
          s.burning = true;
          _lines.add(
            'Ta console et tes vêtements prennent feu : 2 dégâts à chaque fin de tour. '
            'Éteindre les flammes est une action réelle.',
          );
        }
      case 'Feu follet':
        hurt(dice.rollFormula('1d6'), 'Dégâts du Feu follet');
        s.pen = 1;
        _lines.add('Feu follet : −1 action virtuelle au prochain tour (minimum 2).');
      case 'Kraken':
        hurt(dice.rollFormula('3d6'), 'Dégâts du Kraken');
        s.kraken = 1;
        _lines.add(
          'Kraken : impossible de progresser ou de te déconnecter proprement jusqu\'à la fin du prochain tour.',
        );
      case 'Liche':
        final a = dice.d(6), b = dice.d(6), c = dice.d(6);
        _lines.add('Liche : INT −$a, RÉF −$b, DEX −$c (1d6 chacune, minimum 1) pendant 1 heure.');
      case 'Scorpion':
        _lines.add('Scorpion : MOUV −${dice.d(6)} (1d6, minimum 1) pendant 1 heure.');
      case 'Putois':
        _lines.add('Putois : −2 aux jets de Glissement tant qu\'il n\'est pas dérezzé (malus actuel $slideMalus).');
      case 'Titan':
        hurt(dice.rollFormula('3d6'), 'Dégâts du Titan');
        if (deck.hasHardware(hwAntiKrash)) {
          _lines.add('Barrière anti-KRASH : la déconnexion forcée échoue.');
        } else {
          s.status = 'out';
          _derezAll();
          _lines.add(
            'Titan : déconnexion forcée non sécurisée ! Tu subis l\'effet des GLACE rezzés rencontrés : '
            'vois avec le MJ.',
          );
          _log('Éjecté par le Titan.', 'ko');
        }
      default:
        if (def.dmg != null) hurt(dice.rollFormula(def.dmg!), 'Dégâts de ${def.name}');
    }
  }

  void _antiProgram(IceDef def, int? atk) {
    final targets = rezzedItems().where((i) => i.isIce || i.prog?.type != ProgType.offensif).toList();
    if (targets.isEmpty) {
      _lines.add('${def.name} cherche un programme rezzé : aucun, sans effet.');
      return;
    }
    final t = targets[dice.random(targets.length)];
    if (atk != null) {
      final defVal = t.isIce ? t.ice!.def : t.prog!.def;
      final die = dice.d(10);
      final defense = defVal + die;
      if (!beats(atk, defense)) {
        _lines.add('${def.name} vise ${t.n} (DÉF $defVal + dé $die = $defense) : paré.');
        return;
      }
      _lines.add('${def.name} vise ${t.n} (DÉF $defVal + dé $die = $defense) : touché !');
    } else {
      _lines.add('${def.name} vise ${t.n} : touché !');
    }
    _progHit = true;
    final r = dice.rollFormula(def.dmg ?? '1d6');
    final st = progState(t);
    final before = st.rez;
    st.rez = before - r.total;
    if (st.rez <= 0) {
      _lines.add('Dégâts : ${r.detail}. REZ $before → 0.');
      _destroy(t);
    } else {
      _lines.add('Dégâts : ${r.detail}. REZ $before → ${st.rez}.');
    }
  }

  // -------------------------------------------------------------------------
  // Fin du tour
  // -------------------------------------------------------------------------

  bool endTurn() {
    if (!_needOn()) return false;
    _start();
    final oldTurn = s.turn;

    // 1. Kraken.
    if (s.kraken > 0) s.kraken--;

    // 2. Flammes.
    if (s.burning) hurt(DiceRoll.fixed(2), 'Flammes', brain: false);

    // 3. GLACE ennemis en chasse.
    for (final key in chasingKeys()) {
      if (!s.isOn) break;
      final def = iceDefOf(key);
      if (def == null) continue;
      final die = dice.d(10);
      final atk = def.att + die;
      if (def.antiProg) {
        _lines.add('${def.name} attaque tes programmes : ATT ${def.att} + dé $die = $atk.');
        _iceHits(key, def, atk: atk);
      } else {
        final p = _p(0);
        final hit = beats(atk, p.total);
        _lines.add(
          '${def.name} attaque : ATT ${def.att} + dé $die = $atk contre ta défense ${p.full}. '
          '${hit ? 'Touché !' : 'Paré.'}',
        );
        if (hit) _iceHits(key, def, atk: atk);
      }
    }

    if (s.isOn) {
      // 4. GLACE installés et rezzés du joueur (antiprogramme).
      for (final item in rezzedItems().where((i) => i.isIce && i.ice!.antiProg)) {
        final targets = chasingKeys();
        if (targets.isEmpty) break;
        final st = progState(item);
        final tgt = (st.tgt != null && targets.contains(st.tgt)) ? st.tgt! : targets.first;
        st.tgt = tgt;
        final mine = item.ice!;
        final foe = iceDefOf(tgt)!;
        final d1 = dice.d(10);
        final d2 = dice.d(10);
        final atk = mine.att + d1;
        final defense = foe.def + d2;
        final hit = beats(atk, defense);
        _lines.add(
          'Ton ${mine.name} attaque ${foe.name} : ATT ${mine.att} + dé $d1 = $atk '
          'contre DÉF ${foe.def} + dé $d2 = $defense. ${hit ? 'Touché !' : 'Paré.'}',
        );
        if (hit) {
          final r = dice.rollFormula(mine.dmg ?? '1d6');
          final foeSt = s.ice[tgt]!;
          final before = foeSt.rez;
          foeSt.rez = max(0, before - r.total);
          if (foeSt.rez == 0) foeSt.st = 'down';
          _lines.add(
            'Dégâts : ${r.detail}. REZ $before → ${foeSt.rez}'
            '${foeSt.rez == 0 ? ' : ${foe.name} est dérezzé.' : '.'}',
          );
        }
      }

      // 5. Démons actifs.
      for (final id in activeDemonIds()) {
        final def = demonByName[tree.byId[id]!.demon];
        if (def == null) continue;
        final die = dice.d(10);
        final atk = def.iface + die;
        final p = _p(0);
        final hit = beats(atk, p.total);
        _lines.add(
          'Le Démon ${def.name} attaque : Interface ${def.iface} + dé $die = $atk '
          'contre ta défense ${p.full}. ${hit ? 'Touché !' : 'Paré.'}',
        );
        if (hit) {
          final shield = rezzedItems().where((i) => i.n == 'Bouclier').firstOrNull;
          if (shield != null) {
            s.prog[shield.id]!.on = false;
            _lines.add('Bouclier : les dégâts du Démon sont annulés, puis il se dérezze.');
          } else {
            hurt(dice.rollFormula('1d6'), 'Élimination du Démon');
          }
        }
      }

      // 6. Nouveau tour.
      s.turn++;
      // Feu follet : jamais sous 2 actions, sauf si l'APT est déjà inférieure (rang 0).
      s.actions = max(min(2, apt(rank)), apt(rank) - s.pen);
      s.pen = 0;
      s.slid = false;
      s.spent = 0;
    }

    // 7. Blessure mortelle.
    if (s.ps != null && s.ps! <= 0) _lines.add('Tes PS sont à 0 ou moins : blessure mortelle, préviens le MJ.');

    // 8. Résultat.
    if (_lines.isEmpty) _lines.add('Rien ne t\'attaque. Nouvelles actions disponibles.');
    final bad = _dmg > 0 || _progHit;
    _finish(s.isOn ? 'Attaques ennemies, puis tour ${s.turn}' : 'Attaques ennemies', bad ? false : null);
    s.log.insert(
      0,
      LogEntry(
        t: oldTurn,
        txt: _dmg > 0 ? 'Fin du tour : $_dmg dégâts encaissés.' : 'Fin du tour.',
        c: bad ? 'ko' : '',
      ),
    );
    if (s.log.length > RunState.maxLog) s.log.removeRange(RunState.maxLog, s.log.length);
    return true;
  }
}

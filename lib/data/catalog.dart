/// Tables du livre de base de Cyberpunk RED (VF, p. 196-211), recopiées telles quelles.
library;

import '../models/architecture.dart';

// ---------------------------------------------------------------------------
// Types d'étage
// ---------------------------------------------------------------------------

class FloorKindDef {
  const FloorKindDef(this.kind, this.name, this.test, this.placeholder, this.hasSd);
  final FloorKind kind;
  final String name;

  /// Nom du test (vide pour les étages de combat ; saisi par le MJ pour « Autre »).
  final String test;
  final String placeholder;
  final bool hasSd;
}

const Map<FloorKind, FloorKindDef> floorKinds = {
  FloorKind.mdp: FloorKindDef(FloorKind.mdp, 'Mot de passe', 'Porte dérobée', 'Ex. accès bureau du directeur', true),
  FloorKind.fichier: FloorKindDef(FloorKind.fichier, 'Fichier', 'Analyse', 'Ex. registre des livraisons', true),
  FloorKind.noeud: FloorKindDef(
    FloorKind.noeud,
    'Nœud de contrôle',
    'Contrôle',
    'Ce qu\'il contrôle : caméras, porte…',
    true,
  ),
  FloorKind.glace: FloorKindDef(FloorKind.glace, 'GLACE noire', '', 'Description facultative', false),
  FloorKind.demon: FloorKindDef(FloorKind.demon, 'Démon', '', 'Ce qu\'il surveille', false),
  FloorKind.vide: FloorKindDef(FloorKind.vide, 'Autre', '', 'Ce qui attend derrière la porte', true),
};

String kindName(FloorKind k) => floorKinds[k]!.name;

// ---------------------------------------------------------------------------
// GLACE noire
// ---------------------------------------------------------------------------

const String antipersonnel = 'antipersonnel';
const String antiprogramme = 'antiprogramme';

class IceDef {
  const IceDef(this.name, this.cls, this.per, this.vit, this.att, this.def, this.rez, this.dmg, this.effect);
  final String name;
  final String cls;
  final int per;
  final int vit;
  final int att;
  final int def;
  final int rez;

  /// Formule de dégâts (« 2d6 ») ou null.
  final String? dmg;
  final String effect;

  bool get antiProg => cls == antiprogramme;
}

const List<IceDef> iceList = [
  IceDef(
    'Cerbère',
    antipersonnel,
    6,
    6,
    6,
    2,
    20,
    '2d6',
    '2d6 au cerveau. Console sans câblage isolé et vêtements en feu : 2 dégâts à chaque fin de tour jusqu\'à extinction (action réelle).',
  ),
  IceDef('Cobra', antipersonnel, 4, 6, 2, 2, 15, null, 'Détruit un programme installé au hasard sur la cyberconsole.'),
  IceDef(
    'Corbeau',
    antipersonnel,
    6,
    4,
    4,
    2,
    15,
    '1d6',
    'Dérezze un programme défensif rezzé au hasard, puis 1d6 au cerveau.',
  ),
  IceDef(
    'Feu follet',
    antipersonnel,
    4,
    4,
    4,
    2,
    15,
    '1d6',
    '1d6 au cerveau, −1 action virtuelle au prochain tour (minimum 2).',
  ),
  IceDef(
    'Kraken',
    antipersonnel,
    6,
    2,
    8,
    4,
    30,
    '3d6',
    '3d6 au cerveau. Jusqu\'à la fin de son prochain tour : impossible de progresser ou de se déconnecter proprement.',
  ),
  IceDef(
    'Liche',
    antipersonnel,
    8,
    2,
    6,
    2,
    25,
    null,
    'INT, RÉF et DEX réduites chacune de 1d6 (minimum 1) pendant 1 heure.',
  ),
  IceDef(
    'Putois',
    antipersonnel,
    2,
    4,
    4,
    2,
    10,
    null,
    '−2 aux jets de Glissement tant qu\'il n\'est pas dérezzé (cumulable).',
  ),
  IceDef('Scorpion', antipersonnel, 2, 6, 2, 2, 15, null, 'MOUV réduit de 1d6 (minimum 1) pendant 1 heure.'),
  IceDef(
    'Titan',
    antipersonnel,
    2,
    2,
    8,
    4,
    25,
    '3d6',
    '3d6 au cerveau et déconnexion forcée non sécurisée : subit l\'effet des GLACE rezzés rencontrés.',
  ),
  IceDef(
    'Dragon',
    antiprogramme,
    6,
    4,
    6,
    6,
    30,
    '6d6',
    '6d6 à un programme ; s\'il devait être dérezzé, il est détruit.',
  ),
  IceDef(
    'Tigre à dents de sabre',
    antiprogramme,
    8,
    6,
    6,
    2,
    25,
    '6d6',
    '6d6 à un programme ; s\'il devait être dérezzé, il est détruit.',
  ),
  IceDef(
    'Tueur',
    antiprogramme,
    4,
    8,
    6,
    2,
    20,
    '4d6',
    '4d6 à un programme ; s\'il devait être dérezzé, il est détruit.',
  ),
];

final Map<String, IceDef> iceByName = {for (final i in iceList) i.name: i};

// ---------------------------------------------------------------------------
// Démons
// ---------------------------------------------------------------------------

class DemonDef {
  const DemonDef(this.name, this.rez, this.iface, this.actions, this.combat);
  final String name;
  final int rez;
  final int iface;
  final int actions;
  final int combat;
}

const List<DemonDef> demonList = [
  DemonDef('Lutin', 15, 3, 2, 14),
  DemonDef('Ifrit', 25, 4, 3, 14),
  DemonDef('Balron', 30, 7, 4, 14),
];

final Map<String, DemonDef> demonByName = {for (final d in demonList) d.name: d};

// ---------------------------------------------------------------------------
// Actions virtuelles par rang d'Interface
// ---------------------------------------------------------------------------

/// Nombre d'actions virtuelles (APT) pour un rang d'Interface.
int apt(int rank) {
  if (rank >= 10) return 5;
  if (rank >= 7) return 4;
  if (rank >= 4) return 3;
  if (rank >= 1) return 2;
  // Rang 0 (règle ajoutée à la demande du MJ) : 1 action.
  return 1;
}

// ---------------------------------------------------------------------------
// Programmes
// ---------------------------------------------------------------------------

enum ProgType {
  soutien('Soutien'),
  defensif('Défensif'),
  offensif('Offensif');

  const ProgType(this.label);
  final String label;
}

/// Bonus structurés appliqués par le moteur quand le programme est rezzé.
enum Bonus { none, masquage, cartographie, vitesse, porte, armure }

class ProgramDef {
  const ProgramDef(
    this.name,
    this.type,
    this.cls,
    this.att,
    this.def,
    this.rez,
    this.bonusLabel,
    this.iceDmg,
    this.effect, {
    this.once = false,
    this.noIce = false,
    this.bonus = Bonus.none,
  });
  final String name;
  final ProgType type;

  /// Classe pour les offensifs (antiprogramme / antipersonnel), vide sinon.
  final String cls;
  final int att;
  final int def;
  final int rez;
  final String bonusLabel;

  /// Formule des dégâts aux GLACE, ou null.
  final String? iceDmg;
  final String effect;
  final bool once;
  final bool noIce;
  final Bonus bonus;
}

const List<ProgramDef> programList = [
  ProgramDef(
    'Effaceur',
    ProgType.soutien,
    '',
    0,
    0,
    7,
    'Masquage +2',
    null,
    '+2 aux jets de Masquage tant qu\'il est rezzé.',
    bonus: Bonus.masquage,
  ),
  ProgramDef(
    'Loupe',
    ProgType.soutien,
    '',
    0,
    0,
    7,
    'Cartographie +2',
    null,
    '+2 aux jets de Cartographie tant qu\'il est rezzé.',
    bonus: Bonus.cartographie,
  ),
  ProgramDef(
    'Speedy Gonzalvez',
    ProgType.soutien,
    '',
    0,
    0,
    7,
    'VIT +2',
    null,
    '+2 en Vitesse tant qu\'il est rezzé.',
    bonus: Bonus.vitesse,
  ),
  ProgramDef(
    'Ver',
    ProgType.soutien,
    '',
    0,
    0,
    7,
    'Porte dérobée +2',
    null,
    '+2 aux jets de Porte dérobée tant qu\'il est rezzé.',
    bonus: Bonus.porte,
  ),
  ProgramDef(
    'Armure',
    ProgType.defensif,
    '',
    0,
    0,
    7,
    '−4 dégâts au cerveau',
    null,
    '−4 à tous les dégâts au cerveau tant qu\'il est rezzé. Une copie à la fois, une fois par Netrun.',
    once: true,
    bonus: Bonus.armure,
  ),
  ProgramDef(
    'Bouclier',
    ProgType.defensif,
    '',
    0,
    0,
    7,
    '',
    null,
    'Annule les premiers dégâts au cerveau d\'un programme non GLACE, puis se dérezze. Une fois par Netrun. Sans effet contre les GLACE.',
    once: true,
    noIce: true,
  ),
  ProgramDef(
    'Tir de barrage',
    ProgType.defensif,
    '',
    0,
    0,
    7,
    '',
    null,
    'ATT des programmes offensifs adverses non GLACE à 0. Une fois par Netrun. Sans effet contre les GLACE.',
    once: true,
    noIce: true,
  ),
  ProgramDef(
    'Bannissement',
    ProgType.offensif,
    antiprogramme,
    1,
    0,
    0,
    '',
    '2d6',
    '2d6 aux GLACE, 3d6 aux autres programmes.',
  ),
  ProgramDef(
    'Sabre',
    ProgType.offensif,
    antiprogramme,
    1,
    0,
    0,
    '',
    '3d6',
    '3d6 aux GLACE, 2d6 aux autres programmes.',
  ),
  ProgramDef(
    'ConsoleKRASH',
    ProgType.offensif,
    antipersonnel,
    0,
    0,
    0,
    '',
    null,
    'Déconnecte de force un Netrunner ennemi. Sans effet contre les GLACE.',
    noIce: true,
  ),
  ProgramDef(
    'Feubeu',
    ProgType.offensif,
    antipersonnel,
    2,
    0,
    0,
    '',
    null,
    '2d6 au cerveau d\'un Netrunner ennemi et incendie. Sans effet contre les GLACE.',
    noIce: true,
  ),
  ProgramDef(
    'Hélice d\'éclairs',
    ProgType.offensif,
    antipersonnel,
    1,
    0,
    0,
    '',
    null,
    '1d6 au cerveau d\'un Netrunner ennemi, −1 action. Sans effet contre les GLACE.',
    noIce: true,
  ),
  ProgramDef(
    'Laser corrosif',
    ProgType.offensif,
    antipersonnel,
    0,
    0,
    0,
    '',
    null,
    'Détruit un programme d\'un Netrunner ennemi. Sans effet contre les GLACE.',
    noIce: true,
  ),
  ProgramDef(
    'Superglue',
    ProgType.offensif,
    antipersonnel,
    2,
    0,
    0,
    '',
    null,
    'Bloque un Netrunner ennemi 1d6 rounds. Sans effet contre les GLACE.',
    noIce: true,
  ),
  ProgramDef(
    'Taser',
    ProgType.offensif,
    antipersonnel,
    0,
    0,
    0,
    '',
    null,
    'INT, RÉF, DEX d\'un Netrunner ennemi −1d6. Sans effet contre les GLACE.',
    noIce: true,
  ),
];

final Map<String, ProgramDef> programByName = {for (final p in programList) p.name: p};

/// Emplacements occupés par un GLACE installé dans la console du joueur.
const int iceSlotCost = 2;

// ---------------------------------------------------------------------------
// Matériel
// ---------------------------------------------------------------------------

class HardwareDef {
  const HardwareDef(this.name, this.slots, this.effect);
  final String name;
  final int slots;
  final String effect;
}

const String hwAntiKrash = 'Barrière anti-KRASH';
const String hwCablage = 'Câblage isolé';
const String hwBackup = 'Disque dur de sauvegarde';

const List<HardwareDef> hardwareList = [
  HardwareDef(hwAntiKrash, 2, 'Immunisé contre les déconnexions forcées (Titan…).'),
  HardwareDef(hwCablage, 1, 'La console et tes vêtements ne peuvent pas prendre feu (Cerbère).'),
  HardwareDef('Circuits renforcés', 1, 'Insensible aux IEM et effets non GLACE qui désactivent la console.'),
  HardwareDef(hwBackup, 2, 'Sauve les programmes détruits (hors GLACE). Réinstallation : une action réelle.'),
  HardwareDef('Extension de portée', 1, 'Connexion à un point d\'accès jusqu\'à 8 m.'),
  HardwareDef('Verrou biométrique', 2, 'Console verrouillée par biométrie (Sécurité électronique SD 17 pour forcer).'),
];

final Map<String, HardwareDef> hardwareByName = {for (final h in hardwareList) h.name: h};

// ---------------------------------------------------------------------------
// Modèles de cyberconsole
// ---------------------------------------------------------------------------

const String customDeck = 'Personnalisée';

/// Emplacements par modèle (null = saisi par le joueur).
const Map<String, int?> deckModels = {'Bas de gamme': 5, 'Standard': 7, 'Haut de gamme': 9, customDeck: null};

// ---------------------------------------------------------------------------
// Tables de génération (p. 210-211)
// ---------------------------------------------------------------------------

/// Résultat d'une table de génération : soit un étage à test, soit des GLACE.
class GenEntry {
  const GenEntry.test(this.kind, this.sd) : ice = const [];
  const GenEntry.ice(this.ice) : kind = FloorKind.glace, sd = null;
  final FloorKind kind;

  /// SD fixe (Lobby) ; null = SD de la difficulté (Corps).
  final int? sd;
  final List<String> ice;
}

/// Lobby (étages 1 et 2), 1d6.
const Map<int, GenEntry> lobbyTable = {
  1: GenEntry.test(FloorKind.fichier, 6),
  2: GenEntry.test(FloorKind.mdp, 6),
  3: GenEntry.test(FloorKind.mdp, 8),
  4: GenEntry.ice(['Putois']),
  5: GenEntry.ice(['Feu follet']),
  6: GenEntry.ice(['Tueur']),
};

const String _cerb = 'Cerbère';
const String _tigre = 'Tigre à dents de sabre';

/// Corps (étages 3 et plus), 3d6 : GLACE par résultat, une colonne par difficulté
/// (Basique, Standard, Inhabituelle, Avancée). Les résultats 9 à 12 sont dans [bodyTestTable].
const Map<int, List<List<String>>> bodyIceTable = {
  3: [
    [_cerb],
    [_cerb, _cerb],
    ['Kraken'],
    [_cerb, _cerb, _cerb],
  ],
  4: [
    [_tigre],
    [_cerb, 'Tueur'],
    [_cerb, 'Scorpion'],
    ['Cobra', 'Cobra'],
  ],
  5: [
    ['Corbeau', 'Corbeau'],
    ['Putois', 'Putois'],
    [_cerb, 'Tueur'],
    [_cerb, 'Liche'],
  ],
  6: [
    [_cerb],
    [_tigre],
    ['Corbeau', 'Corbeau'],
    ['Feu follet', 'Feu follet', 'Feu follet'],
  ],
  7: [
    ['Feu follet'],
    ['Scorpion'],
    [_tigre],
    [_cerb, _tigre],
  ],
  8: [
    ['Corbeau'],
    [_cerb],
    [_cerb],
    ['Kraken'],
  ],
  13: [
    ['Putois'],
    ['Cobra'],
    ['Tueur'],
    ['Titan'],
  ],
  14: [
    ['Cobra'],
    ['Tueur'],
    ['Liche'],
    ['Dragon'],
  ],
  15: [
    ['Scorpion'],
    ['Liche'],
    ['Dragon'],
    ['Tueur', 'Scorpion'],
  ],
  16: [
    ['Tueur', 'Putois'],
    ['Cobra'],
    ['Cobra', 'Corbeau'],
    ['Kraken'],
  ],
  17: [
    ['Feu follet', 'Feu follet', 'Feu follet'],
    ['Corbeau', 'Corbeau', 'Corbeau'],
    ['Dragon', 'Feu follet'],
    ['Corbeau', 'Feu follet', _cerb],
  ],
  18: [
    ['Liche'],
    ['Liche', 'Corbeau'],
    ['Titan'],
    ['Dragon', 'Dragon'],
  ],
};

/// Corps : résultats 9 à 12, au SD de la difficulté.
const Map<int, FloorKind> bodyTestTable = {
  9: FloorKind.mdp,
  10: FloorKind.fichier,
  11: FloorKind.noeud,
  12: FloorKind.mdp,
};

/// Entrée de la table Corps pour un résultat 3d6 et une difficulté.
GenEntry bodyEntry(int roll, int diff) {
  final test = bodyTestTable[roll];
  if (test != null) return GenEntry.test(test, Difficulty.of(diff).sd);
  return GenEntry.ice(bodyIceTable[roll]![diff.clamp(0, 3)]);
}

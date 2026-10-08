import 'package:cyberpunk_netrun/data/catalog.dart';
import 'package:cyberpunk_netrun/engine/netrun_engine.dart';
import 'package:cyberpunk_netrun/models/architecture.dart';
import 'package:cyberpunk_netrun/models/deck.dart';
import 'package:cyberpunk_netrun/models/run_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_dice.dart';

/// Ordre des dés dans le moteur :
/// - rencontre : d10 du netrunner (pRoll), puis d10 du GLACE, puis l'effet ;
/// - attaque de fin de tour : d10 du GLACE, puis d10 du netrunner (pRoll) ;
/// - Glissement / Élimination : d10 du netrunner, puis d10 du GLACE ;
/// - cible au hasard : un d(n).
class Rig {
  Rig(List<Floor> floors, {int rank = 4, int? psMax = 40, List<DeckItem>? items, int diff = 1})
    : archi = Architecture(id: 'A', diff: diff, floors: floors, virusSD: 10),
      run = RunState(),
      deck = Deck(
        slots: 9,
        items: items,
        me: NetrunnerProfile(rank: rank, psMax: psMax),
      ),
      dice = ScriptedDice([]);

  final Architecture archi;
  final RunState run;
  final Deck deck;
  final ScriptedDice dice;

  NetrunEngine eng([List<int> rolls = const []]) {
    dice.push(rolls);
    return NetrunEngine(archi: archi, s: run, deck: deck, dice: dice);
  }

  DeckItem item(String n) => deck.items.firstWhere((i) => i.n == n);
}

DeckItem prog(String n) => DeckItem(id: n, k: 'prog', n: n);
DeckItem ice(String n) => DeckItem(id: 'ice-$n', k: 'ice', n: n);
DeckItem hw(String n) => DeckItem(id: 'hw-$n', k: 'hw', n: n);

Floor glace(String id, List<String> ice, {String? parent}) =>
    Floor(id: id, parent: parent, kind: FloorKind.glace, ice: ice);

void main() {
  group('connexion et déplacements', () {
    test('se connecter coûte 1 action (Interface 4 → 2 actions au tour 1)', () {
      final r = Rig([Floor(id: 'a', kind: FloorKind.fichier, sd: 6)]);
      final e = r.eng();
      expect(e.connect(), isTrue);
      expect(r.run.status, 'on');
      expect(r.run.turn, 1);
      expect(r.run.actions, 2);
      expect(r.run.spent, 1);
      expect(r.run.ps, 40);
      expect(r.run.pos, isNull);
    });

    test('sans rang d\'Interface : refus', () {
      final r = Rig([Floor(id: 'a')], rank: 4);
      r.deck.me.rank = null;
      final e = r.eng();
      expect(e.connect(), isFalse);
      expect(e.toast, 'Indique ton rang d\'Interface dans l\'onglet Cyberconsole.');
    });

    test('se déplacer est gratuit', () {
      final r = Rig([
        Floor(id: 'a', kind: FloorKind.fichier, sd: 6),
        Floor(id: 'b', parent: 'a', kind: FloorKind.fichier, sd: 6),
      ]);
      final e = r.eng()..connect();
      expect(e.move('a'), isTrue);
      expect(e.move('b'), isTrue);
      expect(e.move('a'), isTrue);
      expect(e.move(null), isTrue);
      expect(r.run.actions, 2);
      expect(r.run.pos, isNull);
      expect(r.run.seen, {'a', 'b'});
    });
  });

  group('mot de passe', () {
    test('descente refusée avant réussite, acceptée après', () {
      final r = Rig([
        Floor(id: 'a', kind: FloorKind.mdp, sd: 8),
        Floor(id: 'b', parent: 'a', kind: FloorKind.fichier, sd: 6),
      ]);
      final e = r.eng()..connect();
      e.move('a');
      expect(e.move('b'), isFalse);
      expect(e.toast, 'Cet étage te bloque : réussis son test d\'abord.');

      // Égalité avec le SD : échec.
      r.dice.push([4]);
      expect(e.test(), isTrue);
      expect(r.run.done, isEmpty);
      expect(r.run.last!.ok, isFalse);

      r.dice.push([5]);
      e.test();
      expect(r.run.done, {'a'});
      expect(r.run.last!.lines, contains('Mot de passe contourné, la voie est libre.'));
      expect(r.run.actions, 0);
      expect(e.move('b'), isTrue);
      expect(r.run.pos, 'b');
    });

    test('Ver : +2 en Porte dérobée', () {
      final r = Rig(
        [Floor(id: 'a', kind: FloorKind.mdp, sd: 8)],
        items: [prog('Ver')],
      );
      final e = r.eng()..connect();
      e.rez('Ver');
      e.move('a');
      r.dice.push([3]); // 4 + 2 + 3 = 9 > 8
      e.test();
      expect(r.run.done, {'a'});
    });
  });

  group('rencontres', () {
    test('le GLACE passe en chasse ; s\'il surprend, dégâts sur les PS', () {
      final r = Rig([
        glace('a', ['Cerbère']),
      ]);
      final e = r.eng()..connect();
      r.dice.push([3, 5, 3, 4]); // toi 4+3=7 ; Cerbère 6+5=11 ; 2d6 = 7
      e.move('a');
      expect(r.run.ice['a:0']!.st, 'chasing');
      expect(r.run.ps, 33);
      expect(r.run.last!.sum!.tot, 7);
      expect(r.run.last!.sum!.from, 40);
      expect(r.run.last!.sum!.to, 33);
      expect(r.run.last!.lines.first, contains('Il te surprend !'));
    });

    test('plus rapide : il poursuit sans dégâts', () {
      final r = Rig([
        glace('a', ['Cerbère']),
      ]);
      final e = r.eng()..connect();
      r.dice.push([9, 1]); // toi 13 ; Cerbère 7
      e.move('a');
      expect(r.run.ice['a:0']!.chasing, isTrue);
      expect(r.run.ps, 40);
      expect(r.run.last!.lines.first, endsWith('Tu es plus rapide, il te poursuit.'));
      expect(r.dice.remaining, 0);
    });

    test('Démon repéré à l\'entrée', () {
      final r = Rig([Floor(id: 'a', kind: FloorKind.demon, demon: 'Ifrit')]);
      final e = r.eng()..connect();
      e.move('a');
      expect(r.run.demon['a']!.active, isTrue);
      expect(r.run.last!.lines, contains('Le Démon Ifrit t\'a repéré.'));
    });
  });

  group('dégâts', () {
    test('Armure : −4 aux dégâts au cerveau, pas aux flammes', () {
      final r = Rig(
        [
          glace('a', ['Cerbère']),
        ],
        items: [prog('Armure')],
      );
      final e = r.eng()..connect();
      e.rez('Armure');
      r.dice.push([3, 5, 3, 4]); // surprise, 2d6 = 7 → 3
      e.move('a');
      expect(r.run.ps, 37);
      expect(r.run.burning, isTrue);
      expect(r.run.last!.lines[1], contains('Armure −4 → 3 dégâts au cerveau encaissés (PS 40 → 37)'));
      r.dice.push([1, 9]); // Cerbère 7 contre 13 : paré
      e.endTurn();
      expect(r.run.ps, 35);
      expect(r.run.last!.lines.first, 'Flammes : 2 dégâts encaissés (PS 37 → 35).');
    });

    test('Cerbère sans câblage isolé : en feu, −2 PS à chaque fin de tour', () {
      final r = Rig([
        glace('a', ['Cerbère']),
      ]);
      final e = r.eng()..connect();
      r.dice.push([3, 5, 1, 1]); // 2 dégâts
      e.move('a');
      expect(r.run.ps, 38);
      expect(r.run.burning, isTrue);
      r.dice.push([1, 9]);
      e.endTurn();
      expect(r.run.ps, 36);
      r.dice.push([1, 9]);
      e.endTurn();
      expect(r.run.ps, 34);
      expect(r.run.last!.ok, isFalse);
      // Éteindre : action réelle, en début de tour.
      expect(e.extinguish(), isTrue);
      expect(r.run.burning, isFalse);
      expect(r.run.actions, 0);
    });

    test('Cerbère avec câblage isolé : pas de feu', () {
      final r = Rig(
        [
          glace('a', ['Cerbère']),
        ],
        items: [hw(hwCablage)],
      );
      final e = r.eng()..connect();
      r.dice.push([3, 5, 1, 1]);
      e.move('a');
      expect(r.run.burning, isFalse);
      expect(r.run.last!.lines, contains('Câblage isolé : pas d\'incendie.'));
    });

    test('Titan : éjecte le netrunner', () {
      final r = Rig(
        [
          glace('a', ['Titan']),
        ],
        items: [prog('Ver')],
      );
      final e = r.eng()..connect();
      e.rez('Ver');
      r.dice.push([3, 9, 1, 1, 1]); // 7 contre 11 ; 3d6 = 3
      e.move('a');
      expect(r.run.status, 'out');
      expect(r.run.ps, 37);
      expect(r.run.prog['Ver']!.on, isFalse);
    });

    test('Titan : la Barrière anti-KRASH empêche l\'éjection', () {
      final r = Rig(
        [
          glace('a', ['Titan']),
        ],
        items: [hw(hwAntiKrash)],
      );
      final e = r.eng()..connect();
      r.dice.push([3, 9, 1, 1, 1]);
      e.move('a');
      expect(r.run.status, 'on');
      expect(r.run.last!.lines, contains('Barrière anti-KRASH : la déconnexion forcée échoue.'));
    });
  });

  group('GLACE antiprogramme', () {
    test('sans programme rezzé : aucun effet', () {
      final r = Rig(
        [
          glace('a', ['Tueur']),
        ],
        items: [prog('Ver')],
      );
      final e = r.eng()..connect();
      r.dice.push([2, 9]); // 6 contre 17 : surprise
      e.move('a');
      expect(r.run.last!.lines, contains('Tueur cherche un programme rezzé : aucun, sans effet.'));
      expect(r.deck.items.length, 1);
      expect(r.run.ps, 40);
      expect(r.dice.remaining, 0);
    });

    test('programme rezzé détruit et sauvé sur le disque dur', () {
      final r = Rig(
        [
          glace('a', ['Tueur']),
        ],
        items: [prog('Ver'), hw(hwBackup)],
      );
      final e = r.eng()..connect();
      e.rez('Ver');
      r.dice.push([2, 9, 1, 2, 2, 2, 2]); // surprise ; cible ; 4d6 = 8 > REZ 7
      e.move('a');
      expect(r.deck.items.any((i) => i.n == 'Ver'), isFalse);
      expect(r.deck.saved.map((i) => i.n), ['Ver']);
      expect(r.run.prog.containsKey('Ver'), isFalse);
    });

    test('fin du tour : REZ réduit puis destruction ; un GLACE n\'est pas sauvé', () {
      final r = Rig(
        [
          glace('a', ['Tueur']),
        ],
        items: [ice('Dragon'), hw(hwBackup)],
      );
      final e = r.eng()..connect();
      e.rez('ice-Dragon');
      r.dice.push([9, 1]); // toi 13 contre 9 : il poursuit
      e.move('a');
      // Fin du tour : Tueur ATT 6 + 9 = 15 ; cible ; DÉF 6 + 1 = 7 ; 4d6 = 24.
      // Puis ton Dragon attaque le Tueur : 6 + 1 = 7 contre 2 + 9 = 11, paré.
      r.dice.push([9, 1, 1, 6, 6, 6, 6, 1, 9]);
      e.endTurn();
      final dragon = r.item('Dragon');
      expect(r.run.prog[dragon.id]!.rez, 6);
      expect(r.run.last!.ok, isFalse);
      expect(r.run.last!.lines.last, startsWith('Ton Dragon attaque Tueur'));
      // Tour suivant : 4d6 = 8 ≥ REZ 6 → détruit (il ne reste plus de GLACE installé pour riposter).
      r.dice.push([9, 1, 1, 2, 2, 2, 2]);
      e.endTurn();
      expect(r.dice.remaining, 0);
      expect(r.deck.items.any((i) => i.n == 'Dragon'), isFalse);
      expect(r.deck.saved, isEmpty);
    });

    test('fin du tour : le programme pare si l\'attaque ne dépasse pas sa défense', () {
      final r = Rig(
        [
          glace('a', ['Tueur']),
        ],
        items: [prog('Ver')],
      );
      final e = r.eng()..connect();
      e.rez('Ver');
      r.dice.push([9, 1]);
      e.move('a');
      r.dice.push([1, 1, 7]); // ATT 7 ; cible ; DÉF 0 + 7 = 7 : paré
      e.endTurn();
      expect(r.run.prog['Ver']!.rez, 7);
      expect(r.run.last!.lines[1], contains('paré'));
    });
  });

  group('Glissement', () {
    test('une seule tentative par tour ; réussite = attente à l\'étage, nouvelle rencontre au retour', () {
      final r = Rig([
        glace('a', ['Cerbère']),
        Floor(id: 'b', parent: 'a', kind: FloorKind.vide),
      ]);
      final e = r.eng()..connect();
      r.dice.push([9, 1]);
      e.move('a');
      r.dice.push([2, 5]); // 6 contre 11 : échec
      expect(e.slide('a:0'), isTrue);
      expect(r.run.ice['a:0']!.chasing, isTrue);
      expect(e.slide('a:0'), isFalse);
      expect(e.toast, 'Tu as déjà tenté un Glissement ce tour.');
      r.dice.push([1, 9]); // Cerbère attaque, paré
      e.endTurn();
      r.dice.push([8, 2]); // 12 contre 8 : réussite
      e.slide('a:0');
      expect(r.run.ice['a:0']!.st, 'waiting');
      expect(r.run.ice['a:0']!.at, 'a');
      e.move('b');
      expect(r.run.last!.lines, ['La porte s\'ouvre.']);
      r.dice.push([9, 1]);
      e.move('a');
      expect(r.run.ice['a:0']!.chasing, isTrue);
      expect(r.dice.remaining, 0);
    });

    test('malus du Putois qui t\'a touché', () {
      final r = Rig([
        glace('a', ['Putois']),
      ]);
      final e = r.eng()..connect();
      r.dice.push([2, 9]); // surprise
      e.move('a');
      expect(r.run.ice['a:0']!.hit, isTrue);
      expect(e.slideMalus, -2);
      r.dice.push([5, 4]); // 4 − 2 + 5 = 7 contre 2 + 4 = 6
      e.slide('a:0');
      expect(r.run.last!.lines.first, startsWith('Glissement : Interface 4 − 2 + dé 5 = 7'));
      expect(r.run.ice['a:0']!.waiting, isTrue);
    });

    test('pas de Glissement contre un Démon', () {
      final r = Rig([Floor(id: 'a', kind: FloorKind.demon)]);
      final e = r.eng()..connect();
      e.move('a');
      expect(e.slide('a'), isFalse);
    });
  });

  test('Cartographie : s\'arrête sous un mot de passe non réussi dont le SD dépasse le jet', () {
    final r = Rig([
      Floor(id: 'a', kind: FloorKind.mdp, sd: 8),
      Floor(id: 'b', parent: 'a', kind: FloorKind.fichier),
      Floor(id: 'c', parent: 'b', kind: FloorKind.fichier),
    ]);
    final e = r.eng()..connect();
    r.dice.push([3]); // 7 < 8
    e.carto();
    expect(r.run.carto, {'a'});
    r.dice.push([6]); // 10
    e.carto();
    expect(r.run.carto, {'a', 'b', 'c'});
  });

  test('Élimination : dégâts 1d6 et dérezzage à 0', () {
    final r = Rig(
      [
        glace('a', ['Putois']),
      ],
      items: [prog('Sabre')],
    );
    final e = r.eng()..connect();
    r.dice.push([9, 1]);
    e.move('a');
    r.dice.push([9, 1, 6]); // 13 contre 3 ; 1d6 = 6
    e.zap('a:0');
    expect(r.run.ice['a:0']!.rez, 4);
    r.dice.push([9, 1, 2, 2, 2]); // Sabre : +1 ; 3d6 = 6
    e.zap('a:0', 'Sabre');
    expect(r.run.ice['a:0']!.down, isTrue);
    expect(r.run.ice['a:0']!.rez, 0);
  });

  group('programmes', () {
    test('rezzer : 1 action, une activation par tour, Armure une fois par Netrun', () {
      final r = Rig(
        [Floor(id: 'a', kind: FloorKind.vide)],
        items: [prog('Armure'), prog('Ver')],
      );
      final e = r.eng()..connect();
      expect(e.rez('Armure'), isTrue);
      expect(r.run.actions, 1);
      expect(e.derez('Armure'), isTrue);
      expect(r.run.actions, 0);
      expect(e.rez('Armure'), isFalse);
      expect(e.toast, 'Ce programme a déjà été activé ce tour.');
      e.endTurn();
      expect(e.rez('Armure'), isFalse);
      expect(e.toast, 'Déjà utilisé pendant cette Netrun.');
      expect(e.rez('Ver'), isTrue);
      expect(e.derez('Ver'), isTrue);
      expect(e.rez('Ver'), isFalse);
      e.endTurn();
      expect(e.rez('Ver'), isTrue);
    });

    test('une seule copie d\'Armure à la fois', () {
      final r = Rig(
        [Floor(id: 'a')],
        items: [
          prog('Armure'),
          DeckItem(id: 'A2', k: 'prog', n: 'Armure'),
        ],
      );
      final e = r.eng()..connect();
      e.rez('Armure');
      expect(e.rez('A2'), isFalse);
      expect(e.toast, 'Une seule copie à la fois.');
    });

    test('plus d\'action : refus', () {
      final r = Rig([Floor(id: 'a')], items: [prog('Ver'), prog('Loupe'), prog('Effaceur')]);
      final e = r.eng()..connect();
      e.rez('Ver');
      e.rez('Loupe');
      expect(e.rez('Effaceur'), isFalse);
      expect(e.toast, 'Plus d\'action virtuelle ce tour : termine ton tour.');
    });
  });

  group('fin du tour', () {
    test('Feu follet : APT − 1 au tour suivant, minimum 2', () {
      final r = Rig([
        glace('a', ['Feu follet']),
      ], rank: 7);
      final e = r.eng()..connect();
      expect(r.run.actions, 3);
      r.dice.push([2, 9, 3]); // surprise ; 1d6 = 3
      e.move('a');
      expect(r.run.pen, 1);
      r.dice.push([1, 9]);
      e.endTurn();
      expect(r.run.actions, 3); // 4 − 1
      expect(r.run.pen, 0);
      r.dice.push([1, 9]);
      e.endTurn();
      expect(r.run.actions, 4);
    });

    test('Feu follet avec Interface 2 : minimum 2 actions', () {
      final r = Rig([
        glace('a', ['Feu follet']),
      ], rank: 2);
      final e = r.eng()..connect();
      r.dice.push([2, 9, 3]);
      e.move('a');
      r.dice.push([1, 9]);
      e.endTurn();
      expect(r.run.actions, 2);
    });

    test('Kraken : bloque la progression et la déconnexion, puis décrémenté', () {
      final r = Rig([
        glace('a', ['Kraken']),
        Floor(id: 'b', parent: 'a', kind: FloorKind.vide),
      ]);
      final e = r.eng()..connect();
      r.dice.push([2, 9, 1, 1, 1]); // surprise ; 3d6 = 3
      e.move('a');
      expect(r.run.kraken, 1);
      expect(e.move('b'), isFalse);
      expect(e.toast, 'Le Kraken t\'empêche de progresser ce tour.');
      expect(e.jackout(), isFalse);
      r.dice.push([1, 9]); // Kraken attaque : 9 contre 13, paré
      e.endTurn();
      expect(r.run.kraken, 0);
      expect(e.move('b'), isTrue);
    });

    test('Interface 0 : 1 action par tour, la connexion la consomme', () {
      final r = Rig([
        glace('a', ['Feu follet']),
      ], rank: 0);
      final e = r.eng()..connect();
      expect(r.run.actions, 0);
      e.endTurn();
      expect(r.run.actions, 1);
      r.dice.push([2, 9, 3]); // surprise du Feu follet : malus au prochain tour
      e.move('a');
      r.dice.push([1, 9]);
      e.endTurn();
      expect(r.run.actions, 1);
    });

    test('rien ne t\'attaque', () {
      final r = Rig([Floor(id: 'a')]);
      final e = r.eng()..connect();
      e.endTurn();
      expect(r.run.turn, 2);
      expect(r.run.actions, 3);
      expect(r.run.last!.h, 'Attaques ennemies, puis tour 2');
      expect(r.run.last!.lines, ['Rien ne t\'attaque. Nouvelles actions disponibles.']);
    });
  });

  test('Virus au fond de l\'architecture', () {
    final r = Rig([Floor(id: 'a', kind: FloorKind.vide), Floor(id: 'b', parent: 'a', kind: FloorKind.vide)]);
    final e = r.eng()..connect();
    e.move('a');
    expect(e.atVirusSpot(), isFalse);
    e.move('b');
    expect(e.atVirusSpot(), isTrue);
    r.dice.push([8]); // 12 > 10
    e.virus();
    expect(r.run.virus, 12);
  });

  group('emplacements', () {
    test('la combinaison connectée n\'accepte que du matériel', () {
      final d = Deck(
        slots: 5,
        suit: true,
        items: [for (var i = 0; i < 5; i++) DeckItem(id: '$i', k: 'prog', n: 'Ver')],
      );
      expect(d.total, 6);
      expect(d.canAdd(prog('Loupe')), isFalse);
      expect(d.canAdd(hw(hwCablage)), isTrue);
    });

    test('un GLACE coûte 2 emplacements', () {
      final d = Deck(
        slots: 7,
        items: [for (var i = 0; i < 6; i++) DeckItem(id: '$i', k: 'prog', n: 'Ver')],
      );
      expect(ice('Cerbère').cost, 2);
      expect(d.canAdd(ice('Cerbère')), isFalse);
      expect(d.canAdd(prog('Loupe')), isTrue);
      d.arm = true;
      expect(d.canAdd(ice('Cerbère')), isTrue);
    });
  });
}

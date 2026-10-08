import 'package:cyberpunk_netrun/engine/architecture_parser.dart';
import 'package:cyberpunk_netrun/engine/floor_tree.dart';
import 'package:cyberpunk_netrun/models/architecture.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lignes empilées verticalement (une par ligne de texte).
List<OcrLine> stacked(List<String> texts) => [
  for (var i = 0; i < texts.length; i++) OcrLine(texts[i], top: i * 40.0, bottom: i * 40.0 + 20),
];

/// Tableau : chaque ligne est une liste de cellules côte à côte.
List<OcrLine> table(List<List<String>> rows) => [
  for (var i = 0; i < rows.length; i++)
    for (var j = 0; j < rows[i].length; j++)
      OcrLine(rows[i][j], left: j * 200.0, top: i * 40.0 + j, bottom: i * 40.0 + 20 + j),
];

String shape(ParseResult r) {
  var n = 0;
  final floors = r.toFloors(() => 'f${n++}');
  return FloorTree(floors)
      .rows()
      .map((row) {
        final f = row.floor;
        final what = switch (f.kind) {
          FloorKind.glace => f.ice.join('+'),
          FloorKind.demon => 'Démon ${f.demon}',
          _ => '${f.kind.name} ${f.sd ?? '?'}',
        };
        return '${row.depth}${row.level > 0 ? 'b' : ''}:$what';
      })
      .join(' | ');
}

void main() {
  test('liste simple en VF', () {
    final r = parseArchitecture(
      stacked([
        'Architecture Standard',
        'Étage 1 : Mot de passe SD 6',
        'Étage 2 : Fichier SD 8',
        'Étage 3 : GLACE noire : Cerbère ×2',
        'Étage 4 : Nœud de contrôle (caméras) SD 8',
        'Étage 5 : Démon Ifrit',
      ]),
    );
    expect(shape(r), '1:mdp 6 | 2:fichier 8 | 3:Cerbère+Cerbère | 4:noeud 8 | 5:Démon Ifrit');
  });

  test('liste en VO (DV, noms anglais)', () {
    final r = parseArchitecture(
      stacked(['Floor 1 Password DV6', 'Floor 2 Hellhound', 'Floor 3 File DV8', 'Floor 4 Skunk, Wisp', 'Imp']),
    );
    expect(shape(r), '1:mdp 6 | 2:Cerbère | 3:fichier 8 | 4:Putois+Feu follet | 5:Démon Lutin');
  });

  test('tableau en colonnes, SD dans une colonne à part', () {
    final r = parseArchitecture(
      table([
        ['Étage', 'Défense', 'SD'],
        ['1', 'Mot de passe', '8'],
        ['2', 'Kraken'],
        ['3', 'Fichier', 'SD 10'],
        ['4', 'Tigre à dents de sabre'],
      ]),
    );
    expect(shape(r), '1:mdp 8 | 2:Kraken | 3:fichier 10 | 4:Tigre à dents de sabre');
    expect(r.unknown, containsAll(['Étage', 'Défense', 'SD']));
  });

  test('même numéro d\'étage deux fois : embranchement', () {
    final r = parseArchitecture(
      stacked([
        '1 Mot de passe SD 6',
        '2 Putois',
        '3 Fichier SD 8',
        '3 Mot de passe SD 8',
        '4 Fichier SD 8',
        '4 Liche',
      ]),
    );
    // Les deux étages 4 sont lus en dessous du premier étage 3 (branche principale) ;
    // sans position horizontale, l'embranchement part de l'étage du dessus le plus proche.
    var n = 0;
    final floors = r.toFloors(() => 'x${n++}');
    final tree = FloorTree(floors);
    expect(tree.maxDepth, 4);
    expect(tree.kids(tree.roots.first.id).length, 1);
    expect(r.floors.where((f) => f.number == 3).length, 2);
  });

  test('cases côte à côte : la case de droite est un embranchement', () {
    final lines = [
      const OcrLine('Mot de passe SD 6', left: 100, top: 0, bottom: 20),
      const OcrLine('Cerbère', left: 100, top: 60, bottom: 80),
      const OcrLine('Fichier SD 8', left: 100, top: 120, bottom: 140),
      const OcrLine('Nœud de contrôle SD 8', left: 400, top: 121, bottom: 141),
      const OcrLine('Kraken', left: 100, top: 180, bottom: 200),
      const OcrLine('Fichier SD 10', left: 400, top: 181, bottom: 201),
    ];
    final r = parseArchitecture(lines);
    // L'embranchement (cases de droite) part de l'étage 2 et s'affiche juste en dessous.
    expect(shape(r), '1:mdp 6 | 2:Cerbère | 3b:noeud 8 | 4b:fichier 10 | 3:fichier 8 | 4:Kraken');
  });

  test('cases avec « Étage N » au-dessus du contenu, sur deux colonnes', () {
    OcrLine at(String t, double left, double top) => OcrLine(t, left: left, top: top, bottom: top + 30);
    final r = parseArchitecture([
      at('ARCHITECTURE NET - Biotechnica', 60, 50),
      at('Difficulté : Inhabituelle', 60, 120),
      at('Étage 1', 100, 245),
      at('Mot de passe SD 8', 100, 295),
      at('Étage 2', 100, 435),
      at('Cerbère', 100, 485),
      at('Étage 3', 100, 625),
      at('Étage 3', 660, 626),
      at('Fichier SD 10', 100, 675),
      at('Nœud de contrôle SD 10', 660, 676),
      at('Étage 4', 100, 815),
      at('Étage 4', 660, 816),
      at('Kraken', 100, 865),
      at('Liche', 660, 866),
      at('Étage 5', 100, 1005),
      at('Démon Ifrit', 100, 1055),
      at('Virus SD 12', 60, 1215),
    ]);
    expect(r.diff, 2);
    expect(r.virusSD, 12);
    expect(shape(r), '1:mdp 8 | 2:Cerbère | 3b:noeud 10 | 4b:Liche | 3:fichier 10 | 4:Kraken | 5:Démon Ifrit');
  });

  test('difficulté, Virus et lignes inconnues', () {
    final r = parseArchitecture(
      stacked(['NET Architecture — Avancée', 'Lobby', 'Mot de passe SD 12', 'Virus SD 14', 'Café du coin']),
    );
    expect(r.diff, 3);
    expect(r.virusSD, 14);
    expect(r.floors.length, 1);
    expect(r.unknown, contains('Café du coin'));
  });

  test('multiplicateurs : 2x, x3, (2)', () {
    final r = parseArchitecture(stacked(['2x Cobra', 'Feu follet x3', 'Corbeau (2)']));
    expect(shape(r), '1:Cobra+Cobra | 2:Feu follet+Feu follet+Feu follet | 3:Corbeau+Corbeau');
  });
}

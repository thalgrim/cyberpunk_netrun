/// Lecture d'une architecture à partir du texte reconnu sur une photo (Dart pur).
///
/// L'appli reconnaît les types d'étage, les SD, les GLACE et les Démons, en VF comme
/// en VO. Le résultat est un brouillon que le MJ vérifie avant de créer l'architecture.
library;

import '../data/catalog.dart';
import '../models/architecture.dart';

/// Ligne de texte reconnue, avec sa position dans l'image.
class OcrLine {
  const OcrLine(this.text, {this.left = 0, this.top = 0, this.bottom = 0});
  final String text;
  final double left;
  final double top;
  final double bottom;

  double get center => (top + bottom) / 2;
  double get height => bottom - top;
}

/// Étage lu sur la photo.
class ParsedFloor {
  ParsedFloor({required this.kind, this.sd, List<String>? ice, this.demon = 'Lutin', this.source = '', this.left = 0})
    : ice = ice ?? [];

  FloorKind kind;
  int? sd;
  final List<String> ice;
  String demon;

  /// Texte d'origine (affiché dans l'écran de vérification).
  final String source;

  /// Numéro d'étage lu ou déduit (1 = premier étage).
  int number = 0;

  /// Position horizontale (pour rattacher les embranchements).
  final double left;

  /// Parent dans le brouillon (index dans la liste), -1 = point d'accès.
  int parent = -1;

  /// Premier étage d'un embranchement.
  bool branch = false;

  bool get needsSd => floorKinds[kind]!.hasSd && kind != FloorKind.vide;
}

class ParseResult {
  ParseResult(this.floors, this.unknown, {this.diff, this.virusSD, this.raw = const []});
  final List<ParsedFloor> floors;

  /// Lignes non reconnues (montrées au MJ pour vérification).
  final List<String> unknown;
  final int? diff;
  final int? virusSD;

  /// Tout le texte lu, ligne par ligne (pour vérification).
  final List<String> raw;

  /// Construit les étages de l'architecture (nouveaux identifiants via [newId]).
  List<Floor> toFloors(String Function() newId) {
    final ids = [for (final _ in floors) newId()];
    final out = <Floor>[];
    final ordByParent = <int, int>{};
    for (var i = 0; i < floors.length; i++) {
      final p = floors[i];
      final ord = ordByParent[p.parent] ?? 0;
      ordByParent[p.parent] = ord + 1;
      out.add(
        Floor(
          id: ids[i],
          parent: p.parent < 0 ? null : ids[p.parent],
          ord: ord,
          kind: p.kind,
          sd: p.kind == FloorKind.glace || p.kind == FloorKind.demon ? null : p.sd,
          ice: [...p.ice],
          demon: p.demon,
        ),
      );
    }
    return out;
  }
}

/// Retire accents et majuscules, et normalise les espaces.
String normalize(String s) {
  const map = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i', //
    'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c', 'œ': 'oe', 'æ': 'ae', '’': "'",
  };
  var out = s.toLowerCase();
  map.forEach((k, v) => out = out.replaceAll(k, v));
  return out.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Noms des GLACE : VF du catalogue et VO du livre de base.
const Map<String, String> _iceAliases = {
  'cerbere': 'Cerbère',
  'hellhound': 'Cerbère',
  'cobra': 'Cobra',
  'asp': 'Cobra',
  'corbeau': 'Corbeau',
  'raven': 'Corbeau',
  'feu follet': 'Feu follet',
  'feux follets': 'Feu follet',
  'wisp': 'Feu follet',
  'kraken': 'Kraken',
  'liche': 'Liche',
  'lich': 'Liche',
  'putois': 'Putois',
  'skunk': 'Putois',
  'scorpion': 'Scorpion',
  'titan': 'Titan',
  'giant': 'Titan',
  'dragon': 'Dragon',
  'tigre a dents de sabre': 'Tigre à dents de sabre',
  'tigre': 'Tigre à dents de sabre',
  'sabertooth': 'Tigre à dents de sabre',
  'tueur': 'Tueur',
  'killer': 'Tueur',
};

const Map<String, String> _demonAliases = {
  'lutin': 'Lutin',
  'imp': 'Lutin',
  'ifrit': 'Ifrit',
  'efreet': 'Ifrit',
  'balron': 'Balron',
};

final List<(RegExp, FloorKind)> _kinds = [
  (RegExp(r'\b(mot de passe|mots de passe|password|mdp)\b'), FloorKind.mdp),
  (RegExp(r'\b(fichier|fichiers|file|files)\b'), FloorKind.fichier),
  // « Nœud » est souvent mal lu (Nceud, Noud…) : « contrôle » suffit aussi.
  (RegExp(r'\b(n\S{0,2}uds?|nodes?|controle|control)\b'), FloorKind.noeud),
];

final RegExp _sd = RegExp(r'\b(?:sd|dv|vd|nd)\s*[:=]?\s*(\d{1,2})\b');
final RegExp _floorNumber = RegExp(r'^(?:etage|floor|niveau|e\.|f\.)?\s*(\d{1,2})(?:\s*[.:)\-–|]|\s+|$)');
final RegExp _multiplier = RegExp(r'^\s*(?:x|×)\s*(\d)\b|^\s*\(\s*(\d)\s*\)');
final RegExp _leadingCount = RegExp(r'(\d)\s*(?:x|×)\s*$');

Map<String, RegExp> _wordRegexes(Iterable<String> keys) => {
  for (final k in keys) k: RegExp('\\b${RegExp.escape(k)}s?\\b'),
};

final Map<String, RegExp> _iceRegexes = _wordRegexes(_iceAliases.keys);
final Map<String, RegExp> _demonRegexes = _wordRegexes(_demonAliases.keys);

/// Contenu reconnu dans un morceau de texte.
class _Segment {
  int? number;
  FloorKind? kind;
  int? sd;
  final List<String> ice = [];
  String? demon;
  bool virus = false;
  int? diff;

  bool get hasEntry => kind != null || ice.isNotEmpty || demon != null;
  bool get empty => !hasEntry && sd == null && number == null && !virus && diff == null;

  /// Texte restant une fois retirés le numéro et le SD : un « SD seul » n'a rien d'autre.
  String rest = '';
}

_Segment _parseSegment(String raw) {
  final seg = _Segment();
  var s = normalize(raw);
  final n = _floorNumber.firstMatch(s);
  if (n != null) {
    seg.number = int.parse(n.group(1)!);
    s = s.substring(n.end);
  }
  final sd = _sd.firstMatch(s);
  if (sd != null) seg.sd = int.parse(sd.group(1)!);
  seg.rest = s.replaceAll(_sd, '').replaceAll(RegExp(r'[^a-z]'), '');
  if (s.contains('virus')) seg.virus = true;
  for (final (re, kind) in _kinds) {
    if (re.hasMatch(s)) {
      seg.kind = kind;
      break;
    }
  }
  // GLACE, dans l'ordre d'apparition, avec multiplicateurs (×2, x2, 2x, (2)).
  final hits = <(int, int, String)>[];
  for (final e in _iceRegexes.entries) {
    for (final m in e.value.allMatches(s)) {
      // « tigre a dents de sabre » contient « tigre » : on garde le plus long.
      if (hits.any((h) => m.start >= h.$1 && m.end <= h.$2)) continue;
      hits.removeWhere((h) => h.$1 >= m.start && h.$2 <= m.end);
      hits.add((m.start, m.end, _iceAliases[e.key]!));
    }
  }
  hits.sort((a, b) => a.$1.compareTo(b.$1));
  for (final (start, end, name) in hits) {
    var count = 1;
    final after = _multiplier.firstMatch(s.substring(end));
    final before = _leadingCount.firstMatch(s.substring(0, start));
    if (after != null) {
      count = int.parse(after.group(1) ?? after.group(2)!);
    } else if (before != null) {
      count = int.parse(before.group(1)!);
    }
    for (var i = 0; i < count.clamp(1, 6); i++) {
      seg.ice.add(name);
    }
  }
  for (final e in _demonRegexes.entries) {
    if (e.value.hasMatch(s)) {
      seg.demon = _demonAliases[e.key];
      break;
    }
  }
  if (RegExp(r'\b(basique|basic)\b').hasMatch(s)) seg.diff = 0;
  if (RegExp(r'\binhabituelle?\b|\buncommon\b').hasMatch(s)) seg.diff = 2;
  if (RegExp(r'\bavancee?\b|\badvanced\b').hasMatch(s)) seg.diff = 3;
  return seg;
}

/// Regroupe les lignes situées à la même hauteur (colonnes d'un tableau, cases côte à côte).
List<List<OcrLine>> groupRows(List<OcrLine> lines) {
  final sorted = [...lines]..sort((a, b) => a.top.compareTo(b.top));
  final rows = <List<OcrLine>>[];
  for (final l in sorted) {
    if (l.text.trim().isEmpty) continue;
    final last = rows.isEmpty ? null : rows.last;
    if (last != null && l.height > 0) {
      final ref = last.first;
      final tol = (ref.height > 0 ? ref.height : l.height) * 0.6;
      if ((l.center - ref.center).abs() <= tol) {
        last.add(l);
        continue;
      }
    }
    rows.add([l]);
  }
  for (final r in rows) {
    r.sort((a, b) => a.left.compareTo(b.left));
  }
  return rows;
}

/// Analyse le texte d'une photo d'architecture.
ParseResult parseArchitecture(List<OcrLine> lines) {
  final floors = <ParsedFloor>[];
  final unknown = <String>[];
  int? diff;
  int? virusSD;
  var row = 0;
  var anyNumber = false;
  // Numéros seuls sur une ligne (« Étage 3 » en tête de case) : valent pour la ligne suivante.
  var carried = <(int, double)>[];
  int? nearest(List<(int, double)> numbers, double left) {
    if (numbers.isEmpty) return null;
    var best = numbers.first;
    for (final n in numbers) {
      if ((n.$2 - left).abs() < (best.$2 - left).abs()) best = n;
    }
    return best.$1;
  }

  for (final r in groupRows(lines)) {
    final rowNumbers = <(int, double)>[];
    final inRow = <ParsedFloor>[];
    for (final line in r) {
      final seg = _parseSegment(line.text);
      if (seg.diff != null) diff ??= seg.diff;
      if (seg.virus && !seg.hasEntry) {
        if (seg.sd != null) virusSD = seg.sd;
        continue;
      }
      if (seg.number != null && !seg.hasEntry && seg.sd == null) {
        // Nombre seul : SD d'une colonne à part s'il suit un étage qui en attend un, sinon numéro d'étage.
        final last = inRow.isEmpty ? null : inRow.last;
        if (last != null && last.needsSd && last.sd == null) {
          last.sd = seg.number;
        } else {
          rowNumbers.add((seg.number!, line.left));
        }
        continue;
      }
      if (!seg.hasEntry) {
        // SD isolé (colonne à part) : rattaché au dernier étage qui en attend un.
        final target = [...inRow, ...floors].reversed.where((f) => f.needsSd && f.sd == null).firstOrNull;
        if (seg.sd != null && target != null && seg.rest.length <= 2) {
          target.sd = seg.sd;
        } else if (seg.diff == null) {
          unknown.add(line.text.trim());
        }
        continue;
      }
      final FloorKind kind;
      if (seg.demon != null) {
        kind = FloorKind.demon;
      } else if (seg.ice.isNotEmpty && seg.kind == null) {
        kind = FloorKind.glace;
      } else {
        kind = seg.kind ?? FloorKind.glace;
      }
      final f = ParsedFloor(
        kind: kind,
        sd: seg.sd,
        ice: kind == FloorKind.glace ? seg.ice : [],
        demon: seg.demon ?? 'Lutin',
        source: line.text.trim(),
        left: line.left,
      );
      final number = seg.number ?? nearest(rowNumbers, line.left) ?? nearest(carried, line.left);
      if (number != null) {
        f.number = number;
        anyNumber = true;
      }
      inRow.add(f);
    }
    carried = inRow.isEmpty ? rowNumbers : [];
    if (inRow.isEmpty) continue;
    row++;
    for (final f in inRow) {
      if (f.number == 0) f.number = anyNumber ? 0 : row;
    }
    floors.addAll(inRow);
  }
  // Étages sans numéro alors que d'autres en ont : à la suite du précédent.
  var lastNumber = 0;
  for (final f in floors) {
    if (f.number == 0) f.number = lastNumber + 1;
    lastNumber = f.number;
  }
  _buildTree(floors);
  final raw = [for (final r in groupRows(lines)) r.map((l) => l.text.trim()).join('   ')];
  return ParseResult(floors, unknown, diff: diff, virusSD: virusSD, raw: raw);
}

/// Premier étage lu pour chaque numéro = branche principale ; les autres étages
/// du même numéro sont des embranchements, rattachés à l'étage du dessus le plus proche.
void _buildTree(List<ParsedFloor> floors) {
  final byNumber = <int, List<int>>{};
  for (var i = 0; i < floors.length; i++) {
    (byNumber[floors[i].number] ??= []).add(i);
  }
  final numbers = byNumber.keys.toList()..sort();
  int? previousNumber;
  for (final n in numbers) {
    final idx = byNumber[n]!;
    final above = previousNumber == null ? const <int>[] : byNumber[previousNumber]!;
    for (var k = 0; k < idx.length; k++) {
      final f = floors[idx[k]];
      if (above.isEmpty) {
        f.parent = -1;
        f.branch = k > 0;
        continue;
      }
      if (k == 0) {
        f.parent = above.first;
        continue;
      }
      // Embranchement : l'étage du dessus le plus proche horizontalement.
      var best = above.first;
      for (final a in above) {
        if ((floors[a].left - f.left).abs() < (floors[best].left - f.left).abs()) best = a;
      }
      f.parent = best;
      f.branch = best == above.first;
    }
    previousNumber = n;
  }
  // Ordre de la liste = ordre des numéros (les parents viennent avant leurs enfants).
  final order = [for (final n in numbers) ...byNumber[n]!];
  final remap = {for (var i = 0; i < order.length; i++) order[i]: i};
  final sorted = [for (final i in order) floors[i]];
  for (final f in sorted) {
    if (f.parent >= 0) f.parent = remap[f.parent]!;
  }
  floors
    ..clear()
    ..addAll(sorted);
}

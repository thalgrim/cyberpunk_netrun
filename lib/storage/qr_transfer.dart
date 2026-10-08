import 'dart:convert';
import 'dart:io' show gzip;

import 'package:uuid/uuid.dart';

import '../models/architecture.dart';
import 'import_export.dart';

/// Transfert d'une architecture par QR code, sans réseau.
///
/// Format compact : préfixe « CPN1: » puis JSON compressé (gzip) en base64url.
/// Les identifiants sont remplacés par des index (recréés à la lecture) et les
/// notes MJ ne sont pas transmises.
const String qrPrefix = 'CPN1:';

/// Contenu maximal d'un QR code (version 40, correction L, mode octet).
const int qrMaxBytes = 2953;

String encodeQr(Architecture a) {
  final index = {for (var i = 0; i < a.floors.length; i++) a.floors[i].id: i};
  final floors = [
    for (final f in a.floors)
      [index[f.parent] ?? -1, f.ord, f.kind.index, f.label, f.sd, f.testName, f.ice, f.demon, f.info, f.block],
  ];
  final json = jsonEncode({'n': a.name, 'l': a.lieu, 'd': a.diff, 's': a.showSD, 'v': a.virusSD, 'f': floors});
  return qrPrefix + base64Url.encode(gzip.encode(utf8.encode(json)));
}

/// Lit un QR code ; lève [ImportException] si ce n'est pas une architecture.
Architecture decodeQr(String raw) {
  final data = raw.trim();
  if (!data.startsWith(qrPrefix)) {
    throw ImportException('Ce QR code n\'est pas une architecture Cyberpunk - Netrun.');
  }
  try {
    final json = utf8.decode(gzip.decode(base64Url.decode(data.substring(qrPrefix.length))));
    final m = jsonDecode(json) as Map<String, dynamic>;
    const uuid = Uuid();
    final rows = (m['f'] as List).cast<List>();
    final ids = [for (var i = 0; i < rows.length; i++) uuid.v4()];
    final floors = <Floor>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final p = (r[0] as num).toInt();
      final kind = (r[2] as num).toInt();
      floors.add(
        Floor(
          id: ids[i],
          parent: p >= 0 && p < ids.length ? ids[p] : null,
          ord: (r[1] as num).toInt(),
          kind: FloorKind.values[kind.clamp(0, FloorKind.values.length - 1)],
          label: r[3] as String? ?? '',
          sd: (r[4] as num?)?.toInt(),
          testName: r[5] as String? ?? '',
          ice: (r[6] as List? ?? []).map((e) => e.toString()).toList(),
          demon: r[7] as String? ?? 'Lutin',
          info: r[8] as String? ?? '',
          block: r[9] as bool?,
        ),
      );
    }
    return Architecture(
      id: uuid.v4(),
      name: m['n'] as String? ?? 'Architecture',
      lieu: m['l'] as String? ?? '',
      diff: ((m['d'] as num?)?.toInt() ?? 1).clamp(0, 3),
      showSD: m['s'] as bool? ?? true,
      virusSD: (m['v'] as num?)?.toInt(),
      floors: floors,
    );
  } catch (_) {
    throw ImportException('QR code illisible ou incomplet : réessaie.');
  }
}

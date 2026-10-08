import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/architecture.dart';

const String archiFormat = 'cyberpunk-netrun-archi';
const int archiFormatVersion = 1;

class ImportException implements Exception {
  ImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

String exportJson(Architecture a) =>
    const JsonEncoder.withIndent('  ')
        .convert({'format': archiFormat, 'version': archiFormatVersion, 'architecture': a.toJson()});

/// Nom de fichier « nom-de-l-architecture.netrun.json ».
String exportFileName(Architecture a) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i', //
    'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c', 'œ': 'oe', 'æ': 'ae', 'ÿ': 'y',
  };
  var s = a.name.toLowerCase();
  accents.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return '${s.isEmpty ? 'architecture' : s}.netrun.json';
}

/// Lit un export ; attribue de nouveaux identifiants (architecture et étages).
Architecture parseImport(String raw) {
  Object? data;
  try {
    data = jsonDecode(raw);
  } on FormatException {
    throw ImportException('Ce fichier n\'est pas un JSON valide.');
  }
  if (data is! Map || data['format'] != archiFormat) {
    throw ImportException('Ce fichier n\'est pas une architecture Cyberpunk - Netrun.');
  }
  final version = data['version'];
  if (version is! int || version > archiFormatVersion) {
    throw ImportException('Version de fichier non prise en charge.');
  }
  final Architecture a;
  try {
    a = Architecture.fromJson(Map<String, dynamic>.from(data['architecture'] as Map));
  } catch (_) {
    throw ImportException('Architecture illisible : le fichier est incomplet ou abîmé.');
  }
  const uuid = Uuid();
  final ids = {for (final f in a.floors) f.id: uuid.v4()};
  for (final f in a.floors) {
    f.id = ids[f.id]!;
    f.parent = f.parent == null ? null : ids[f.parent];
  }
  a.id = uuid.v4();
  return a;
}

Future<void> shareArchitecture(Architecture a) async {
  final bytes = Uint8List.fromList(utf8.encode(exportJson(a)));
  final name = exportFileName(a);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'application/json', name: name)],
      fileNameOverrides: [name],
      subject: a.name,
    ),
  );
}

/// Ouvre le sélecteur de fichiers ; null si annulé.
Future<Architecture?> pickArchitecture() async {
  final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final String raw;
  try {
    raw = utf8.decode(bytes);
  } on FormatException {
    throw ImportException('Ce fichier n\'est pas un texte UTF-8.');
  }
  return parseImport(raw);
}

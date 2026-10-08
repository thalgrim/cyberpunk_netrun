import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/architecture.dart';
import '../../state/app_state.dart';
import '../../state/architectures_state.dart';
import '../../storage/import_export.dart';
import '../../storage/qr_transfer.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

/// Affiche le QR code d'une architecture, à scanner avec le téléphone du joueur.
class QrShareScreen extends StatelessWidget {
  const QrShareScreen({super.key, required this.archi});
  final Architecture archi;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final data = encodeQr(archi);
    // Correction M (plus robuste) si elle tient, sinon L.
    final ecl = QrValidator.validate(data: data, errorCorrectionLevel: QrErrorCorrectLevel.M).isValid
        ? QrErrorCorrectLevel.M
        : QrErrorCorrectLevel.L;
    final fits = QrValidator.validate(data: data, errorCorrectionLevel: ecl).isValid;
    return Scaffold(
      appBar: AppBar(title: const Text('QR code de l\'architecture')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(archi.name, style: t.headlineSmall),
          if (archi.lieu.isNotEmpty) Text(archi.lieu, style: t.bodyMedium!.copyWith(color: context.colors.muted)),
          const SizedBox(height: 16),
          if (fits) ...[
            // Fond blanc obligatoire, y compris en thème sombre, pour que la caméra lise le code.
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: data,
                  errorCorrectionLevel: ecl,
                  size: 300,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'QR code de l\'architecture ${archi.name}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sur le téléphone du joueur : onglet Netrun ou Architectures, « Scanner un QR code ». '
              'L\'architecture y est importée et proposée directement.',
              style: t.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Les notes MJ ne sont pas transmises. Augmente la luminosité de ton écran si la lecture est difficile.',
              style: t.bodySmall,
            ),
          ] else
            Text(
              'Cette architecture est trop volumineuse pour un QR code (textes trop longs). '
              'Raccourcis les textes « Révélé au joueur » ou utilise « Exporter ».',
              style: t.bodyLarge!.copyWith(color: context.colors.red),
            ),
        ],
      ),
    );
  }
}

/// Ouvre la caméra, lit un QR code d'architecture, l'importe et la propose au joueur.
Future<void> scanArchitecture(BuildContext context) async {
  final a = await Navigator.of(context).push<Architecture>(MaterialPageRoute(builder: (_) => const _QrScanScreen()));
  if (a == null || !context.mounted) return;
  context.read<ArchitecturesState>().add(a);
  final app = context.read<AppState>()..propose(a.id);
  app.setTab(AppTab.netrun);
  showToast(context, 'Architecture reçue et proposée : ${a.name}.');
}

class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      try {
        final a = decodeQr(raw);
        _done = true;
        Navigator.of(context).pop(a);
        return;
      } on ImportException catch (e) {
        if (_error != e.message) setState(() => _error = e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner un QR code')),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? 'Accès à la caméra refusé. Autorise-le dans les réglages Android de l\'appli.'
                        : 'Caméra indisponible : ${error.errorDetails?.message ?? error.errorCode.name}.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: c.panel,
            padding: const EdgeInsets.all(16),
            child: Text(
              _error ?? 'Vise le QR code affiché sur le téléphone du MJ.',
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: _error != null ? c.red : null),
            ),
          ),
        ],
      ),
    );
  }
}

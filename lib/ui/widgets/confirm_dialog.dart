import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Demande une confirmation. Renvoie vrai si l'utilisateur confirme.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  bool danger = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: ctx.colors.red) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Demande un code (facultatif ou non). Renvoie null si annulé.
Future<String?> codeDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String initial = '',
  bool optional = true,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) =>
        _CodeDialog(title: title, message: message, confirmLabel: confirmLabel, initial: initial, optional: optional),
  );
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.initial,
    required this.optional,
  });
  final String title;
  final String message;
  final String confirmLabel;
  final String initial;
  final bool optional;

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);
  bool _obscure = true;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _c.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 14),
          TextField(
            controller: _c,
            autofocus: true,
            obscureText: _obscure,
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: widget.optional ? 'Code (facultatif)' : 'Code',
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Afficher le code' : 'Masquer le code',
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

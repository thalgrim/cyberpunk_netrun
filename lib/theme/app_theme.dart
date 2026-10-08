import 'package:flutter/material.dart';

import '../models/architecture.dart';

/// Polices embarquées (voir pubspec.yaml).
const String kTitleFont = 'ChakraPetch';
const String kTextFont = 'Barlow';

/// Jetons de couleur de la charte graphique, en extension de thème.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.panel,
    required this.panel2,
    required this.text,
    required this.muted,
    required this.border,
    required this.red,
    required this.redPale,
    required this.net,
    required this.netPale,
    required this.warn,
    required this.okPale,
    required this.ok,
  });

  final Color bg;
  final Color panel;
  final Color panel2;
  final Color text;
  final Color muted;
  final Color border;
  final Color red;
  final Color redPale;
  final Color net;
  final Color netPale;
  final Color warn;

  /// Vert du panneau de réussite (dérivé de la couleur NET).
  final Color okPale;
  final Color ok;

  static const light = AppColors(
    bg: Color(0xFFF3ECEB),
    panel: Color(0xFFFFFAF9),
    panel2: Color(0xFFEFE3E1),
    text: Color(0xFF1D1417),
    muted: Color(0xFF76656A),
    border: Color(0xFFDCCBC8),
    red: Color(0xFFC41A2F),
    redPale: Color(0xFFF8DDE0),
    net: Color(0xFF0B7F78),
    netPale: Color(0xFFD6EFEC),
    warn: Color(0xFF9A5B06),
    okPale: Color(0xFFD6EFEC),
    ok: Color(0xFF0B7F78),
  );

  static const dark = AppColors(
    bg: Color(0xFF150E11),
    panel: Color(0xFF20161A),
    panel2: Color(0xFF2B1D22),
    text: Color(0xFFF1E6E3),
    muted: Color(0xFFA6939C),
    border: Color(0xFF3C2B31),
    red: Color(0xFFFF3A50),
    redPale: Color(0xFF3F131B),
    net: Color(0xFF52DCCF),
    netPale: Color(0xFF11302E),
    warn: Color(0xFFF0A53A),
    okPale: Color(0xFF11302E),
    ok: Color(0xFF52DCCF),
  );

  static const Color mdp = Color(0xFFC28A14);
  static const Color noeud = Color(0xFF6F7BD8);
  static const Color demon = Color(0xFFB24FC2);
  static const Color defensive = Color(0xFF6F7BD8);
  static const Color offensive = Color(0xFFC28A14);

  /// Couleur de bordure d'un type d'étage.
  Color floorColor(FloorKind k) {
    switch (k) {
      case FloorKind.mdp:
        return mdp;
      case FloorKind.fichier:
        return net;
      case FloorKind.noeud:
        return noeud;
      case FloorKind.glace:
        return red;
      case FloorKind.demon:
        return demon;
      case FloorKind.vide:
        return muted;
    }
  }

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => t < 0.5 ? this : (other as AppColors? ?? this);
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.red,
      onPrimary: b == Brightness.light ? Colors.white : const Color(0xFF1A0006),
      secondary: c.net,
      onSecondary: b == Brightness.light ? Colors.white : const Color(0xFF00201D),
      tertiary: c.warn,
      onTertiary: Colors.black,
      error: c.red,
      onError: Colors.white,
      surface: c.panel,
      onSurface: c.text,
      onSurfaceVariant: c.muted,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.panel,
      surfaceContainer: c.panel,
      surfaceContainerHigh: c.panel2,
      surfaceContainerHighest: c.panel2,
      outline: c.border,
      outlineVariant: c.border,
      primaryContainer: c.redPale,
      onPrimaryContainer: c.text,
      secondaryContainer: c.netPale,
      onSecondaryContainer: c.text,
    );
    TextStyle title(double size, [FontWeight w = FontWeight.w700]) =>
        TextStyle(fontFamily: kTitleFont, fontSize: size, fontWeight: w, color: c.text);
    TextStyle body(double size, [FontWeight w = FontWeight.w400]) =>
        TextStyle(fontFamily: kTextFont, fontSize: size, fontWeight: w, color: c.text);
    final textTheme = TextTheme(
      displayLarge: title(56),
      displayMedium: title(44),
      displaySmall: title(36),
      headlineLarge: title(30),
      headlineMedium: title(26),
      headlineSmall: title(22),
      titleLarge: title(20),
      titleMedium: title(16, FontWeight.w600),
      titleSmall: title(14, FontWeight.w600),
      labelLarge: title(14, FontWeight.w600),
      labelMedium: title(12, FontWeight.w600),
      labelSmall: title(11, FontWeight.w600),
      bodyLarge: body(16),
      bodyMedium: body(14),
      bodySmall: body(12.5).copyWith(color: c.muted),
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    const minSize = Size(48, 48);
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: kTextFont,
      textTheme: textTheme,
      scaffoldBackgroundColor: c.bg,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: title(20),
      ),
      cardTheme: CardThemeData(
        color: c.panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.panel,
        indicatorColor: c.redPale,
        labelTextStyle: WidgetStatePropertyAll(title(12, FontWeight.w600)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: minSize, shape: shape, textStyle: title(14, FontWeight.w600)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minSize,
          shape: shape,
          foregroundColor: c.text,
          side: BorderSide(color: c.border),
          textStyle: title(14, FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: minSize, shape: shape, textStyle: title(14, FontWeight.w600)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.panel,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.net, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.panel2,
        side: BorderSide(color: c.border),
        labelStyle: body(14, FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titleTextStyle: title(20),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.text,
        contentTextStyle: body(15, FontWeight.w500).copyWith(color: c.bg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

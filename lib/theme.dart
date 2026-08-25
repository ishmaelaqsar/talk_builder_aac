import 'package:flutter/material.dart';

/// Colour and metric tokens for the whole app.
///
/// Every colour lives here. Widgets read them through [Theme.of] or through the
/// static members below, so a palette change is a one-file change.
abstract final class AppTokens {
  /// Sage green. The app's identity colour, and the seed for the scheme.
  static const Color seed = Color(0xFF7BA05B);

  /// The page behind the cards.
  static const Color canvas = Color(0xFFF1F8E9);

  /// Raised surfaces: the app bar and the sentence strip housing.
  static const Color surface = Color(0xFFFFFFFF);

  /// The well that the sentence strip cards sit in.
  static const Color well = Color(0xFFEFF1EC);

  /// Card and well outlines.
  static const Color outline = Color(0xFFBFC5B6);

  /// Body text.
  static const Color ink = Color(0xFF1A1A17);

  /// Hint and placeholder text. Reaches 4.6:1 on [well].
  static const Color inkMuted = Color(0xFF5A5F52);

  /// The speak button, and the accent for a selected word.
  static const Color speak = Color(0xFF2E5E23);

  /// Text and icons drawn on top of [speak].
  static const Color onSpeak = Color(0xFFFFFFFF);

  /// Destructive actions.
  static const Color danger = Color(0xFFB3261E);

  /// The admin-mode indicator.
  static const Color admin = Color(0xFFB3261E);

  /// The toggle that hides a card without deleting it.
  static const Color hidden = Color(0xFF6B7280);
  static const Color visible = Color(0xFF1F5FA8);

  /// Dims the screen while a backup or an import runs.
  static const Color scrim = Color(0x99000000);

  /// The highlight drawn on the word being spoken.
  static const Color speaking = Color(0xFFFFD54F);

  /// The border around a photo card.
  static const Color photoBorder = Color(0xFFB7CBA6);

  /// Fallback fill for a core word whose stored colour is missing.
  static const int defaultCardColor = 0xFFE8EDE1;

  /// The minimum touch target, per the Material accessibility guideline.
  static const double minTouchTarget = 48.0;

  /// The target width of one vocabulary tile. The grid fits as many as it can,
  /// so a tile stays about the same size on a phone and on a tablet.
  static const double tileExtent = 160.0;

  static const double cardRadius = 16.0;
  static const double miniCardRadius = 8.0;
}

abstract final class AppTheme {
  static ThemeData build() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppTokens.seed,
      primary: AppTokens.speak,
      surface: AppTokens.surface,
      error: AppTokens.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppTokens.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTokens.surface,
        foregroundColor: AppTokens.ink,
        elevation: 1,
        centerTitle: false,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        thickness: 1,
        space: 1,
        color: AppTokens.outline,
      ),
    );
  }
}

/// Fills for the core-word cards, grouped by the part of speech they carry.
///
/// Stored as `int` because a card's colour round-trips through JSON.
abstract final class CardPalette {
  /// Pronouns and quantity words.
  static const int subject = 0xFFFFF59D;

  /// Actions.
  static const int action = 0xFFA5D6A7;

  /// Refusal.
  static const int negative = 0xFFEF9A9A;

  /// Agreement.
  static const int affirmative = 0xFFC5E1A5;
}

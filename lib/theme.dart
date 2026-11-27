import 'package:material_ui/material_ui.dart';

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

  /// Dims the screen while a backup or an import runs.
  static const Color scrim = Color(0x99000000);

  /// The highlight drawn on the word being spoken.
  static const Color speaking = Color(0xFFFFD54F);

  /// The border around a photo card.
  static const Color photoBorder = Color(0xFFB7CBA6);

  /// The plate behind a symbol in the picker.
  static const Color symbolPlate = well;

  /// Fallback fill for a core word whose stored colour is missing.
  static const int defaultCardColor = 0xFFE8EDE1;

  /// The minimum touch target, per the Material accessibility guideline.
  static const double minTouchTarget = 48.0;

  /// The target width of one symbol in the picker. Smaller than a card,
  /// because the picker is a parent-facing browse list.
  static const double symbolExtent = 120.0;

  /// The border that marks a card a parent can edit.
  static const double editableBorderWidth = 3.0;

  /// The lift of a card while a parent drags it.
  static const double dragElevation = 3.0;

  /// The height of a key on the parent gate. Its width is a third of the
  /// dialog.
  static const double gateKeySize = 64.0;

  /// How long a parent holds the lock to reach the parent gate. Long enough
  /// that a child's idle press does not open it.
  static const Duration unlockHold = Duration(milliseconds: 1500);

  /// The parent gate closes itself after this long with no key, so a child
  /// who reaches it gets the screen back.
  static const Duration gateTimeout = Duration(seconds: 10);

  /// Admin mode drops back to the locked state after this long without a
  /// touch, so a parent who walks away does not leave the card editor one tap
  /// away from the child.
  static const Duration adminTimeout = Duration(minutes: 2);

  static const double cardRadius = 16.0;
  static const double miniCardRadius = 8.0;
}

/// The target width of one card tile, which a parent chooses. The grid fits
/// as many as it can, so a tile stays about the same size on a phone and on a
/// tablet.
enum CardSize {
  small(120),
  medium(160),
  large(220);

  const CardSize(this.extent);

  final double extent;
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

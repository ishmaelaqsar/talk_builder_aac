import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../theme.dart';

/// One vocabulary item: a built-in core word, or a card that a parent adds
/// with a photo or a symbol.
///
/// A card shows [imagePath] when it has one, else [symbol], else [icon].
///
/// [TalkCard.fromJson] reads the app's own records, in storage and in a
/// backup, and the records of an older *Toddler Talk* backup. It tolerates
/// every key being absent. [toJson] writes the same key set.
/// [TalkCard.fromToddlerTalk] reads a record of a newer *Toddler Talk* backup,
/// which carries a `type` key.
@immutable
class TalkCard {
  const TalkCard({
    required this.id,
    required this.label,
    this.imagePath,
    this.symbol,
    this.icon,
    this.color = AppTokens.defaultCardColor,
    this.isCustom = false,
    this.isVisible = true,
  });

  final String id;
  final String label;

  /// Absolute path to the parent's photo. Null for a core word.
  final String? imagePath;

  /// Asset key of a bundled symbol, for example `assets/symbols/apple.svg`.
  final String? symbol;

  /// The emoji on a core word, or on an emoji card from *Toddler Talk*. Null
  /// for a photo or a symbol card.
  final String? icon;

  /// ARGB fill behind a symbol or an emoji.
  final int color;

  /// True when a parent added this card, so it can be hidden or deleted.
  final bool isCustom;

  final bool isVisible;

  Color get fillColor => Color(color);

  /// Reads a card from stored JSON.
  ///
  /// A *Toddler Talk* backup may omit `isCustom`, and then omit `color` too. The
  /// old code read the missing colour and threw. Infer the kind from the payload
  /// instead: anything carrying an image path is a parent's photo.
  factory TalkCard.fromJson(Map<String, dynamic> json) {
    final String? imagePath = json['imagePath'] as String?;
    final String? icon = json['icon'] as String?;
    final bool isCustom =
        json['isCustom'] == true || (imagePath != null && icon == null);

    return TalkCard(
      id: json['id'] as String? ?? const Uuid().v4(),
      label: json['label'] as String? ?? '',
      imagePath: imagePath,
      symbol: json['symbol'] as String?,
      icon: icon,
      color: json['color'] as int? ?? AppTokens.defaultCardColor,
      isCustom: isCustom,
      isVisible: json['isVisible'] as bool? ?? true,
    );
  }

  /// Reads a record that a *Toddler Talk* backup holds.
  ///
  /// Its `content` is a photo path for the type `image`, a symbol asset key
  /// for `asset`, and an emoji for any other type. Talk Builder plays no
  /// recordings, has no pages, and speaks the label, so `audioPath`, `page`,
  /// and `speech` are dropped.
  factory TalkCard.fromToddlerTalk(Map<String, dynamic> json) {
    final Object? type = json['type'];
    final String content = json['content'] as String? ?? '';

    return TalkCard(
      id: json['id'] as String? ?? const Uuid().v4(),
      label: json['label'] as String? ?? '',
      imagePath: type == 'image' ? content : null,
      symbol: type == 'asset' ? content : null,
      icon: type == 'image' || type == 'asset' ? null : content,
      color: json['color'] as int? ?? AppTokens.defaultCardColor,
      isCustom: true,
      isVisible: json['isVisible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    if (imagePath != null) 'imagePath': imagePath,
    if (symbol != null) 'symbol': symbol,
    if (icon != null) 'icon': icon,
    'color': color,
    'isCustom': isCustom,
    'isVisible': isVisible,
  };

  TalkCard copyWith({
    String? label,
    String? imagePath,
    String? symbol,
    bool? isVisible,
  }) => TalkCard(
    id: id,
    label: label ?? this.label,
    imagePath: imagePath ?? this.imagePath,
    symbol: symbol ?? this.symbol,
    icon: icon,
    color: color,
    isCustom: isCustom,
    isVisible: isVisible ?? this.isVisible,
  );

  /// Replaces the picture with a [photo] or a [symbol], and clears the other
  /// picture fields. [copyWith] cannot clear a field.
  TalkCard withPicture({String? photo, String? symbol}) {
    assert((photo == null) != (symbol == null), 'Give a photo or a symbol.');
    return TalkCard(
      id: id,
      label: label,
      imagePath: photo,
      symbol: symbol,
      color: color,
      isCustom: isCustom,
      isVisible: isVisible,
    );
  }

  @override
  bool operator ==(Object other) => other is TalkCard && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

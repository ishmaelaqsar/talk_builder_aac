import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../theme.dart';

/// One vocabulary item: either a built-in core word or a parent's photo.
///
/// The JSON shape is fixed by two things it must keep reading — the app's own
/// `shared_preferences` entry, and a *Toddler Talk* backup zip. So [toJson]
/// emits the original key set, and [fromJson] tolerates every key being absent.
@immutable
class TalkCard {
  const TalkCard({
    required this.id,
    required this.label,
    this.imagePath,
    this.icon,
    this.color = AppTokens.defaultCardColor,
    this.isCustom = false,
    this.isVisible = true,
  });

  final String id;
  final String label;

  /// Absolute path to the parent's photo. Null for a core word.
  final String? imagePath;

  /// The emoji shown on a core word. Null for a photo card.
  final String? icon;

  /// ARGB fill for a core word.
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
      icon: icon,
      color: json['color'] as int? ?? AppTokens.defaultCardColor,
      isCustom: isCustom,
      isVisible: json['isVisible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    if (imagePath != null) 'imagePath': imagePath,
    if (icon != null) 'icon': icon,
    'color': color,
    'isCustom': isCustom,
    'isVisible': isVisible,
  };

  TalkCard copyWith({String? label, String? imagePath, bool? isVisible}) =>
      TalkCard(
        id: id,
        label: label ?? this.label,
        imagePath: imagePath ?? this.imagePath,
        icon: icon,
        color: color,
        isCustom: isCustom,
        isVisible: isVisible ?? this.isVisible,
      );

  @override
  bool operator ==(Object other) => other is TalkCard && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

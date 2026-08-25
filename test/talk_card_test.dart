import 'package:flutter_test/flutter_test.dart';
import 'package:talk_builder_aac/models/talk_card.dart';
import 'package:talk_builder_aac/theme.dart';

void main() {
  test('a stored card round-trips through JSON', () {
    const TalkCard card = TalkCard(
      id: 'abc',
      label: 'Teddy',
      imagePath: '/photos/abc.jpg',
      isCustom: true,
      isVisible: false,
    );

    final TalkCard restored = TalkCard.fromJson(card.toJson());

    expect(restored.id, 'abc');
    expect(restored.label, 'Teddy');
    expect(restored.imagePath, '/photos/abc.jpg');
    expect(restored.isCustom, isTrue);
    expect(restored.isVisible, isFalse);
  });

  test('a Toddler Talk card with no isCustom flag is read as a photo card', () {
    // The old code read the absent 'color' key here and threw.
    final TalkCard card = TalkCard.fromJson({
      'id': 'legacy',
      'label': 'Apple',
      'imagePath': 'apple.jpg',
    });

    expect(card.isCustom, isTrue);
    expect(card.color, AppTokens.defaultCardColor);
    expect(card.isVisible, isTrue);
  });

  test('a card with no id is still readable', () {
    final TalkCard card = TalkCard.fromJson({'label': 'Ball'});
    expect(card.id, isNotEmpty);
    expect(card.label, 'Ball');
  });

  test('toJson keeps the key set that older builds read', () {
    const TalkCard card = TalkCard(
      id: 'x',
      label: 'Ball',
      imagePath: 'ball.jpg',
      isCustom: true,
    );

    expect(
      card.toJson().keys,
      containsAll([
        'id',
        'label',
        'imagePath',
        'color',
        'isCustom',
        'isVisible',
      ]),
    );
  });
}

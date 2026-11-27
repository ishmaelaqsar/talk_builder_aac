import '../theme.dart';
import 'talk_card.dart';

/// The built-in words, always present and never editable.
///
/// These stay pinned above the parent's cards, so they cannot scroll out of a
/// child's reach as the parent adds cards.
const List<TalkCard> coreWords = [
  TalkCard(id: 'c_i', label: 'I', icon: '🙂', color: CardPalette.subject),
  TalkCard(id: 'c_want', label: 'Want', icon: '🤲', color: CardPalette.action),
  TalkCard(id: 'c_see', label: 'See', icon: '👀', color: CardPalette.action),
  TalkCard(id: 'c_go', label: 'Go', icon: '🏃', color: CardPalette.action),
  TalkCard(id: 'c_like', label: 'Like', icon: '❤️', color: CardPalette.action),
  TalkCard(id: 'c_more', label: 'More', icon: '➕', color: CardPalette.subject),
  TalkCard(id: 'c_no', label: 'No', icon: '👎', color: CardPalette.negative),
  TalkCard(
    id: 'c_yes',
    label: 'Yes',
    icon: '👍',
    color: CardPalette.affirmative,
  ),
];

import 'card_model.dart';
import 'dart:math';

class SolitaireDeck {
  List<SolitaireCard> cards = [];

  SolitaireDeck() {
    _initializeDeck();
    shuffle();
  }

  // 山札の初期化（3スート × 13枚 = 39枚）
  void _initializeDeck() {
    cards = [];
    for (Suit suit in [Suit.hearts, Suit.spades, Suit.clubs]) {
      for (int rank = 1; rank <= 13; rank++) {
        cards.add(SolitaireCard(suit: suit, rank: rank, isFaceUp: false));
      }
    }
  }

  // シャッフル
  void shuffle() {
    cards.shuffle(Random());
  }

  // 5列に分ける初期配置
  List<List<SolitaireCard>> dealToColumns() {
    List<List<SolitaireCard>> columns = List.generate(5, (_) => []);
    int cardIndex = 0;

    // 各列に配る枚数
    List<int> columnCounts = [1, 2, 3, 4, 5];

    for (int col = 0; col < 5; col++) {
      for (int i = 0; i < columnCounts[col]; i++) {
        if (cardIndex < cards.length) {
          columns[col].add(cards[cardIndex]);
          cardIndex++;
        }
      }
    }

    // 各列の一番上を表向きに
    for (var column in columns) {
      if (column.isNotEmpty) column.last.isFaceUp = true;
    }

    // 配ったカードを deck から削除
    cards = cards.sublist(cardIndex);

    return columns;
  }
}

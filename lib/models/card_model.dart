enum Suit { hearts, spades, clubs }

class SolitaireCard {
  final Suit suit;
  final int rank; // 1 = A, 11 = J, 12 = Q, 13 = K
  bool isFaceUp;

  SolitaireCard({
    required this.suit,
    required this.rank,
    this.isFaceUp = false,
  });

  String get displayValue {
    switch (rank) {
      case 1:
        return 'A';
      case 11:
        return 'J';
      case 12:
        return 'Q';
      case 13:
        return 'K';
      default:
        return rank.toString();
    }
  }

  String get suitSymbol {
    switch (suit) {
      case Suit.hearts:
        return '♥';
      case Suit.spades:
        return '♠';
      case Suit.clubs:
        return '♣';
    }
  }
}

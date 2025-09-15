import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card_model.dart';
import '../utils/deck_manager.dart';

class CardWidget extends StatefulWidget {
  final List<SolitaireCard> cards;
  final bool isDraggable;
  final Function(int)? onCardTapped;
  final DragSource sourceType;
  final int? sourceIndex;

  // --- ▼▼▼ サイズを外部から受け取るプロパティを追加 ▼▼▼ ---
  final double width;
  final double height;

  const CardWidget({
    super.key,
    required this.cards,
    this.isDraggable = true,
    this.onCardTapped,
    required this.sourceType,
    this.sourceIndex,
    required this.width,
    required this.height,
  }) : assert(cards.length > 0);

  @override
  State<CardWidget> createState() => _CardWidgetState();
}

class _CardWidgetState extends State<CardWidget> {
  int? _draggingIndex;

  @override
  Widget build(BuildContext context) {
    // isDraggableがfalseの場合は、buildStackViewではなく単一のカード描画を直接呼ぶ
    if (!widget.isDraggable) {
      // isDraggable:false のカードは常に1枚なので、cards.firstで安全
      return _buildSingleCard(widget.cards.first);
    }
    return _buildTappableStackView(widget.cards);
  }

  Widget _buildTappableStackView(List<SolitaireCard> cards) {
    // --- ▼▼▼ 固定値だったサイズをwidgetのプロパティから受け取るように変更 ▼▼▼ ---
    final double cardWidth = widget.width;
    final double cardHeight = widget.height;
    final double overlap = cardHeight * 0.35; // 高さに応じて重なり具合を調整

    final int n = cards.length;
    final double totalHeight = cardHeight + (n - 1) * overlap;

    return SizedBox(
      width: cardWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int index = 0; index < n; index++)
            if (_draggingIndex != null && index >= _draggingIndex!)
              Positioned(
                top: index * overlap,
                left: 0,
                child: SizedBox(width: cardWidth, height: cardHeight),
              )
            else
              Positioned(
                top: index * overlap,
                left: 0,
                child: Builder(
                  builder: (context) {
                    final List<SolitaireCard> dragCards = cards.sublist(index);
                    final double draggingHeight =
                        cardHeight + (dragCards.length - 1) * overlap;

                    return Draggable<List<SolitaireCard>>(
                      data: dragCards,
                      feedback: Material(
                        color: Colors.transparent,
                        elevation: 4, // elevationは影を強調するため残しても良い
                        child: SizedBox(
                          width: cardWidth,
                          height: draggingHeight,
                          // isGlowing: true を渡して光彩エフェクトを有効にする
                          child: _buildStackView(dragCards, isGlowing: true),
                        ),
                      ),
                      onDragStarted: () {
                        final deckManager = Provider.of<DeckManager>(
                          context,
                          listen: false,
                        );

                        // --- ▼▼▼ ロジックをシンプルに修正 ▼▼▼ ---
                        deckManager.dragSource = widget.sourceType;
                        deckManager.sourceIndex = widget.sourceIndex;
                        // 古いdragSourceColumnIndexのロジックは削除
                        // ------------------------------------

                        setState(() {
                          _draggingIndex = index;
                        });
                      },
                      onDragEnd: (details) {
                        setState(() {
                          _draggingIndex = null;
                        });
                      },
                      onDraggableCanceled: (_, __) {
                        setState(() {
                          _draggingIndex = null;
                        });
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onCardTapped?.call(index),
                        // childは直接_buildSingleCardを呼ぶ
                        child: _buildSingleCard(cards[index]),
                      ),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildSingleCard(SolitaireCard card, {bool isGlowing = false}) {
    final Color suitColor;
    switch (card.suit) {
      case Suit.hearts:
        suitColor = Colors.red;
        break;
      case Suit.spades:
        suitColor = Colors.black;
        break;
      case Suit.clubs:
        suitColor = Colors.green;
        break;
    }
    final cardContent = '${card.displayValue}${card.suitSymbol}';

    return Container(
      width: widget.width, // ← widgetのプロパティを使用
      height: widget.height, // ← widgetのプロパティを使用
      decoration: BoxDecoration(
        color: card.isFaceUp
            ? Colors.white
            : Colors.blueGrey.shade800, // 裏面の色を調整
        border: Border.all(color: Colors.black.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(
          widget.width * 0.1,
        ), // 角丸もカードサイズに合わせる
        boxShadow: [
          // 通常の影
          if (card.isFaceUp)
            const BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),

          // isGlowingがtrueの時だけ、黄色い光彩エフェクトを追加
          if (isGlowing)
            BoxShadow(
              color: Colors.amber.withOpacity(0.9),
              blurRadius: 20.0,
              spreadRadius: 2.0,
            ),
        ],
      ),
      child: card.isFaceUp
          ? Stack(
              children: [
                Align(
                  alignment: const Alignment(0.0, 1),
                  child: Text(
                    card.suitSymbol,
                    style: TextStyle(
                      fontSize: widget.width * 0.9, // スートのサイズをカード幅に合わせる
                      color: suitColor.withOpacity(1),
                    ),
                  ),
                ),
                Positioned(
                  top: widget.height * 0.05,
                  left: widget.width * 0.1,
                  child: Text(
                    cardContent,
                    style: TextStyle(
                      fontFamily: 'Cardo',
                      fontSize: widget.width * 0.25, // フォントサイズをカード幅に合わせる
                      fontWeight: FontWeight.bold,
                      color: suitColor,
                    ),
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildStackView(List<SolitaireCard> cards, {bool isGlowing = false}) {
    final double overlap = widget.height * 0.35;
    return Stack(
      children: cards.asMap().entries.map((entry) {
        return Transform.translate(
          offset: Offset(0, entry.key * overlap),
          child: _buildSingleCard(entry.value),
        );
      }).toList(),
    );
  }
}

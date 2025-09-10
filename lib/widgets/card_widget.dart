import 'package:flutter/material.dart';
import '../models/card_model.dart';
import 'package:provider/provider.dart';
import '../utils/deck_manager.dart';

class CardWidget extends StatefulWidget {
  final List<SolitaireCard> cards;
  final bool isDraggable;
  final Function(int)? onCardTapped;
  final DragSource sourceType;
  final int? sourceIndex; // columnの場合の列番号など

  const CardWidget({
    super.key,
    required this.cards,
    this.isDraggable = true,
    this.onCardTapped,
    required this.sourceType, // 必須にする
    this.sourceIndex,
  }) : assert(cards.length > 0);

  @override
  State<CardWidget> createState() => _CardWidgetState();
}

class _CardWidgetState extends State<CardWidget> {
  // --- STATE ---
  // ドラッグ中のカードの開始インデックスを保持する状態変数
  // null の場合はドラッグ中でないことを示す
  int? _draggingIndex;
  // -------------

  @override
  Widget build(BuildContext context) {
    if (!widget.isDraggable) {
      return _buildStackView(widget.cards);
    }
    return _buildTappableStackView(widget.cards);
  }

  Widget _buildTappableStackView(List<SolitaireCard> cards) {
    final double overlap = 40.0;
    final double cardWidth = 80.0;
    final double cardHeight = 110.0;
    final int n = cards.length;
    final double totalHeight = cardHeight + (n - 1) * overlap;

    return SizedBox(
      width: cardWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int index = 0; index < n; index++)
            // --- ここからが重要 ---
            // ドラッグ中のカード束（_draggingIndex以降のカード）は非表示にする
            if (_draggingIndex != null && index >= _draggingIndex!)
              // ドラッグ中のカードがあった場所には、高さを維持するためのSizedBoxを置く
              Positioned(
                top: index * overlap,
                left: 0,
                child: SizedBox(width: cardWidth, height: cardHeight),
              )
            else
              // ドラッグ中でないカード、またはドラッグ対象より上のカードは通常通り描画
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
                        elevation: 4,
                        child: SizedBox(
                          width: cardWidth,
                          height: draggingHeight,
                          child: _buildStackView(dragCards),
                        ),
                      ),
                      // childWhenDraggingは不要になるので削除
                      // 代わりにStateで描画を制御する

                      // ドラッグ開始時に状態を更新
                      onDragStarted: () {
                        // listen: false で DeckManager を取得
                        final deckManager = Provider.of<DeckManager>(
                          context,
                          listen: false,
                        );
                        deckManager.dragSource = widget.sourceType;
                        deckManager.sourceIndex = widget.sourceIndex;

                        // このカードがどの列に属しているかを探す
                        for (int i = 0; i < deckManager.columns.length; i++) {
                          // ドラッグされたカード束の最初のカードがこの列に含まれているかチェック
                          if (deckManager.columns[i].contains(
                            dragCards.first,
                          )) {
                            deckManager.dragSourceColumnIndex =
                                i; // 移動元のインデックスをセット
                            break; // 見つかったらループを抜ける
                          }
                        }

                        setState(() {
                          _draggingIndex = index;
                        });
                      },
                      // ドラッグ終了時（成功・失敗問わず）に状態をリセット
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
                        child: SizedBox(
                          width: cardWidth,
                          height: cardHeight,
                          child: _buildSingleCard(cards[index]),
                        ),
                      ),
                    );
                  },
                ),
              ),
          // --- ここまで ---
        ],
      ),
    );
  }

  // Widget _buildSingleCard(SolitaireCard card) {
  //   // (変更なし)
  //   return Container(
  //     width: 80,
  //     height: 110,
  //     decoration: BoxDecoration(
  //       color: card.isFaceUp ? Colors.white : Colors.grey,
  //       border: Border.all(color: Colors.black),
  //       borderRadius: BorderRadius.circular(10),
  //     ),
  //     alignment: Alignment.center,
  //     child: card.isFaceUp
  //         ? Text(
  //             '${card.displayValue}${card.suitSymbol}',
  //             style: TextStyle(
  //               fontSize: 20,
  //               color: card.suit == Suit.hearts
  //                   ? Colors.red
  //                   : card.suit == Suit.spades
  //                   ? Colors.black
  //                   : Colors.green,
  //             ),
  //           )
  //         : const Text(''),
  //   );
  // }

  Widget _buildSingleCard(SolitaireCard card) {
    // スートに応じて文字色を決定するロジック（変更なし）
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

    // カードの数字とマークを結合した文字列
    final cardContent = '${card.displayValue}${card.suitSymbol}';

    return Container(
      width: 80,
      height: 110,
      decoration: BoxDecoration(
        color: card.isFaceUp ? Colors.white : Colors.grey,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          if (card.isFaceUp) // 表向きのカードにだけ影をつける
            const BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
        ],
      ),
      child: card.isFaceUp
          ? Stack(
              // ← Stackウィジェットで要素を重ねる
              children: [
                // 1. 中央の大きな文字
                Positioned(
                  top: 10.0,
                  left: 3,
                  child: Text(
                    card.suitSymbol,
                    style: TextStyle(
                      fontSize: 100, // 中央は少し大きめに
                      color: suitColor,
                    ),
                  ),
                ),

                // 2. 左上の小さな文字
                Positioned(
                  top: 2.0,
                  left: 8.0,
                  child: Text(
                    cardContent,
                    style: TextStyle(
                      fontFamily: 'Cardo',
                      fontSize: 30, // 左上は小さめに
                      fontWeight: FontWeight.bold,
                      color: suitColor,
                    ),
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(), // 裏向きの場合は何も表示しない
    );
  }

  // (_buildStackViewは変更なし)
  Widget _buildStackView(List<SolitaireCard> cards) {
    double overlap = 40.0;
    return Stack(
      children: cards.asMap().entries.map((entry) {
        int index = entry.key;
        SolitaireCard card = entry.value;
        return Transform.translate(
          offset: Offset(0, index * overlap),
          child: _buildSingleCard(card),
        );
      }).toList(),
    );
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// --- このWidgetを動作させるための仮のモデル ---
// ご自身のプロジェクトのモデルに置き換えてください
enum Suit { hearts, clubs, spades }

class ClearedSolitaireCard {
  final Suit suit;
  final int rank;
  final bool isFaceUp = true; // クリア時は常に表

  ClearedSolitaireCard({required this.suit, required this.rank});

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
      case Suit.clubs:
        return '♣';
      case Suit.spades:
        return '♠';
    }
  }
}
// -----------------------------------------

// アニメーションするカードの状態を管理するクラス
class _FallingCard {
  final ClearedSolitaireCard card;
  Rect? position;
  late Offset velocity;
  late double rotation;
  bool isReleased = false; // 発射されたか

  _FallingCard({required this.card});
}

class GameClearAnimationWidget extends StatefulWidget {
  const GameClearAnimationWidget({super.key});

  @override
  State<GameClearAnimationWidget> createState() =>
      _GameClearAnimationWidgetState();
}

class _GameClearAnimationWidgetState extends State<GameClearAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_FallingCard> _fallingCards = [];
  final Random _random = Random();
  Timer? _releaseTimer;

  // 定数
  static const int totalCards = 39;
  static const double cardWidth = 80.0;
  static const double cardHeight = 110.0;
  static const double gravity = 0.5;
  static const double bounceDamping = 0.7;

  @override
  void initState() {
    super.initState();

    // 52枚のカードを初期化
    for (var suit in Suit.values) {
      for (var rank = 1; rank <= 13; rank++) {
        _fallingCards.add(
          _FallingCard(
            card: ClearedSolitaireCard(suit: suit, rank: rank),
          ),
        );
      }
    }
    _fallingCards.shuffle();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(days: 1), // ほぼ無限
    )..addListener(_updateAnimation);

    // アニメーションの開始とカードの放出
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCardPositions();
      _controller.forward();
      _startReleasingCards();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _releaseTimer?.cancel();
    super.dispose();
  }

  // カードの初期位置をFoundationの位置（画面上部）に設定
  void _initializeCardPositions() {
    final screenWidth = MediaQuery.of(context).size.width;
    for (int i = 0; i < totalCards; i++) {
      _fallingCards[i].position = Rect.fromLTWH(
        screenWidth / 2 - cardWidth / 2, // 中央上部からスタート
        -cardHeight * 1.2, // 画面外から
        cardWidth,
        cardHeight,
      );
      _fallingCards[i].velocity = Offset.zero;
      _fallingCards[i].rotation = _random.nextDouble() * 2 - 1; // -1.0 ~ 1.0
    }
  }

  // 一定間隔でカードを１枚ずつ発射する
  void _startReleasingCards() {
    int cardIndex = 0;
    _releaseTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (cardIndex < totalCards) {
        final card = _fallingCards[cardIndex];
        card.isReleased = true;
        // 初速をランダムに設定
        card.velocity = Offset(
          _random.nextDouble() * 10 - 5, // 横方向の速度 (-5.0 ~ 5.0)
          _random.nextDouble() * 5 + 5, // 下方向の速度 (5.0 ~ 10.0)
        );
        cardIndex++;
      } else {
        timer.cancel();
      }
    });
  }

  // アニメーションの更新ロジック
  void _updateAnimation() {
    if (!mounted) return;

    final screenSize = MediaQuery.of(context).size;

    setState(() {
      for (final card in _fallingCards) {
        if (!card.isReleased) continue;

        // 1. 重力を適用
        card.velocity = card.velocity.translate(0, gravity);

        // 2. 位置を更新
        card.position = card.position!.translate(
          card.velocity.dx,
          card.velocity.dy,
        );

        // 3. 画面の端との衝突判定と跳ね返り
        // 下端
        if (card.position!.bottom > screenSize.height) {
          card.position = Rect.fromLTWH(
            card.position!.left,
            screenSize.height - cardHeight,
            cardWidth,
            cardHeight,
          );
          // 速度を反転し、減衰させる
          card.velocity = Offset(
            card.velocity.dx,
            -card.velocity.dy * bounceDamping,
          );
        }
        // 左右の端
        if (card.position!.left < 0 ||
            card.position!.right > screenSize.width) {
          card.velocity = Offset(-card.velocity.dx, card.velocity.dy);
          // 画面内に押し戻す
          card.position = card.position!.translate(
            card.position!.left < 0
                ? -card.position!.left
                : (screenSize.width - card.position!.right),
            0,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _fallingCards.map((fallingCard) {
        // --- ここからが修正点 ---

        // positionを変数として取り出す
        final position = fallingCard.position;

        // positionがまだ初期化されていない(null)場合は、何も描画しない
        if (position == null) {
          return const SizedBox.shrink(); // 空のWidgetを返す
        }

        // positionがnullでないことが保証されたので、安全に使える
        return Positioned(
          left: position.left, // '!' が不要になる
          top: position.top, // '!' が不要になる
          child: Transform.rotate(
            angle: fallingCard.rotation,
            child: _buildSingleCard(fallingCard.card),
          ),
        );
      }).toList(),
    );
  }

  // カード一枚を描画するWidget（ご自身のプロジェクトのものを使用してください）
  Widget _buildSingleCard(ClearedSolitaireCard card) {
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
                  top: 8.0,
                  left: 8.0,
                  child: Text(
                    cardContent,
                    style: TextStyle(
                      fontFamily: 'Cardo',
                      fontSize: 20, // 左上は小さめに
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
}

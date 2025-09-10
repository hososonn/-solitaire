import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/card_widget.dart';
import '../models/card_model.dart';
import '../utils/deck_manager.dart';
import '../widgets/game_clear_animation_widget.dart';
import 'package:animate_do/animate_do.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        var manager = DeckManager();
        manager.newGame(); // ゲーム開始
        return manager;
      },
      child: Consumer<DeckManager>(
        builder: (context, deckManager, _) {
          // クリア状態を監視し、ダイアログを表示するロジック
          if (deckManager.isGameWon && !deckManager.isWinDialogShown) {
            deckManager.markWinDialogAsShown();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(seconds: 1), () {
                if (context.mounted) {
                  // mountedチェックを追加するとより安全
                  _showWinDialog(context, deckManager);
                }
              });
            });
          }

          // Consumerの内側でScaffoldを返す
          return Scaffold(
            appBar: AppBar(
              toolbarHeight: 45.0,
              backgroundColor: Colors.transparent, // ← 背景色を透明にする
              elevation: 0, // ← 影を消してbodyとの一体感を出す
              // flexibleSpaceに背景と同じContainerを配置
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1,
                    colors: [
                      Colors.green.shade800,
                      Colors.green.shade800, // 外側の色 (濃い緑)
                    ],
                  ),
                ),
              ),
              // titleプロパティにRowウィジェットを指定
              title: Row(
                children: [
                  const Text('ソリティア'), // 元のタイトル
                  const Spacer(), // スペースを空ける
                  const Icon(Icons.timer_outlined, size: 20), // タイマーアイコン
                  const SizedBox(width: 4),
                  // DeckManagerから経過時間を表示
                  Text(
                    deckManager.elapsedTime,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            body: Consumer<DeckManager>(
              builder: (context, deckManager, _) {
                if (deckManager.isGameWon && !deckManager.isWinDialogShown) {
                  // ダイアログが表示済みであることをDeckManagerに通知
                  deckManager.markWinDialogAsShown();

                  // build完了後にダイアログを安全に表示
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Future.delayed(const Duration(seconds: 2), () {
                      // 2秒遅らせる
                      _showWinDialog(context, deckManager);
                    });
                  });
                }
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.9,
                          colors: [
                            Colors.green.shade500, // 中心の色 (明るい緑)
                            Colors.green.shade800, // 外側の色 (濃い緑)
                          ],
                        ),
                      ),
                    ),
                    // 場札
                    // メインの列描画部分の修正
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: deckManager.columns.asMap().entries.map((
                        entry,
                      ) {
                        int colIndex = entry.key;
                        var col = entry.value;

                        return Padding(
                          padding: EdgeInsets.only(
                            top: 150,
                            right: colIndex == deckManager.columns.length - 1
                                ? 0
                                : 3,
                          ),
                          child: DragTarget<List<SolitaireCard>>(
                            onWillAcceptWithDetails: (details) {
                              final dragged = details.data.first;
                              return col.isEmpty
                                  ? dragged.rank == 13
                                  : col.last.suit != dragged.suit &&
                                        dragged.rank == col.last.rank - 1;
                            },
                            onAcceptWithDetails: (details) {
                              // deckManager.moveCardsToColumn(details.data, colIndex);

                              // if (deckManager.dragSourceColumnIndex != null) {
                              //   deckManager.flipTopCardInColumn(
                              //     deckManager.dragSourceColumnIndex!,
                              //   );
                              //   deckManager.dragSourceColumnIndex =
                              //       null; // 次のドラッグのためにリセット
                              // }
                              deckManager.handleDropOnColumn(
                                details.data,
                                colIndex,
                              );
                            },
                            builder: (context, candidateData, rejectedData) {
                              double cardHeight = 90;
                              double overlap = cardHeight * -0.89;

                              if (col.isEmpty) {
                                return Container(
                                  width: 80,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.transparent,
                                  ),
                                );
                              }

                              int firstFaceUp = col.indexWhere(
                                (c) => c.isFaceUp,
                              );
                              if (firstFaceUp == -1) {
                                firstFaceUp = col.length;
                              }

                              return Column(
                                children: [
                                  // 裏カード（ドラッグ不可だが、リストとして統一）
                                  for (int i = 0; i < firstFaceUp; i++)
                                    Transform.translate(
                                      offset: Offset(0, i * overlap),
                                      child: CardWidget(
                                        cards: [col[i]], // 単一カードもリストとして渡す
                                        isDraggable: false,
                                        sourceType: DragSource.column,
                                      ),
                                    ),

                                  // 表カード（タップでドラッグ対象選択可能）
                                  if (firstFaceUp < col.length)
                                    Transform.translate(
                                      offset: Offset(0, firstFaceUp * overlap),
                                      child: CardWidget(
                                        cards: col.sublist(
                                          firstFaceUp,
                                        ), // 複数カードをリストとして渡す
                                        isDraggable: true,
                                        sourceType: DragSource.column, // ← 追加
                                        sourceIndex: colIndex,
                                        onCardTapped: (tappedIndex) {
                                          // タップされたカードのインデックスをログ出力（デバッグ用）
                                          print(
                                            'Tapped card at index: $tappedIndex in column $colIndex',
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),

                    // 山札
                    Positioned(
                      top: 0,
                      right: 5,
                      child: GestureDetector(
                        onTap: () => deckManager.drawCard(),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 110,
                              decoration: BoxDecoration(
                                color: deckManager.hasCards
                                    ? Colors.grey
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black),
                              ),
                            ),
                            Text(
                              deckManager.remainingCards.toString(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: deckManager.remainingCards == 0
                                    ? Colors.black
                                    : Colors.white,
                                shadows: deckManager.remainingCards == 0
                                    ? [] // 0枚のときは影なし
                                    : const [
                                        Shadow(
                                          blurRadius: 2,
                                          color: Colors.black,
                                        ),
                                      ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 表向きカード（山札からめくったカード）
                    Positioned(
                      top: 0,
                      right: 87,
                      child: Stack(
                        children: deckManager.drawed.asMap().entries.map((
                          entry,
                        ) {
                          int index = entry.key;
                          SolitaireCard card = entry.value;

                          // 最上位のカードだけ draggable にする
                          bool isTopCard =
                              index == deckManager.drawed.length - 1;

                          return Transform.translate(
                            offset: Offset(
                              0,
                              -index * 0,
                            ), // 今はずらしてないが重ね仕様なら調整可能
                            child: CardWidget(
                              cards: [card], // ★ 単体でも必ずリストで渡す
                              isDraggable: isTopCard, // ★ 一番上だけドラッグ可能
                              sourceType: DragSource.drawPile,
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // foundationを追加
                    Positioned(
                      top: 5,
                      left: 7,
                      child: Row(
                        children: deckManager.foundations.asMap().entries.map((
                          entry,
                        ) {
                          int index = entry.key;
                          var foundation = entry.value;

                          final suitSymbols = ['♥', '♠', '♣']; // 4種類あるはず
                          final suitColors = [
                            Colors.red.shade400,
                            Colors.black,
                            Colors.green.shade400,
                          ];

                          return DragTarget<List<SolitaireCard>>(
                            onWillAcceptWithDetails: (details) {
                              // ここで foundation ルールを追加チェックするとさらに良い
                              final dragged = details.data.last; // 移動する束の一番下
                              if (foundation.isEmpty) {
                                return dragged.rank == 1; // Aからしか置けない
                              }
                              final top = foundation.last;
                              return dragged.suit == top.suit &&
                                  dragged.rank == top.rank + 1;
                            },
                            onAcceptWithDetails: (details) {
                              deckManager.handleDropOnFoundation(
                                details.data,
                                index,
                              );
                            },
                            builder: (context, candidateData, rejectedData) {
                              return Container(
                                width: 75,
                                height: 105,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.yellow,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: foundation.isEmpty
                                    ? Text(
                                        suitSymbols[index], // 枠内にスート表示
                                        style: TextStyle(
                                          fontSize: 100,
                                          color: suitColors[index], // 薄く表示
                                        ),
                                      )
                                    : IgnorePointer(
                                        child: CardWidget(
                                          cards: [
                                            foundation.last,
                                          ], // ★ 単体でもリストで渡す
                                          isDraggable:
                                              false, // foundation上のカードは動かせない想定
                                          sourceType: DragSource.foundation,
                                        ),
                                      ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    if (deckManager.isGameWon) const GameClearAnimationWidget(),
                  ],
                );
              },
            ),
            bottomNavigationBar: Container(
              height: 90,
              color: Colors.grey[900],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Consumer<DeckManager>(
                    builder: (context, deckManager, _) {
                      return ElevatedButton(
                        onPressed: () {
                          deckManager.resetDeck();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                        ),
                        child: const Text(
                          '山札リセット',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                  Consumer<DeckManager>(
                    builder: (context, deckManager, _) {
                      return ElevatedButton(
                        onPressed: () {
                          deckManager.newGame();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade900,
                        ),
                        child: const Text(
                          '新しいゲーム',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showWinDialog(BuildContext context, DeckManager deckManager) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'クリアダイアログ',
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              // ★★★ 背景デザイン ★★★
              gradient: LinearGradient(
                colors: [Colors.red.shade900, Colors.black],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: Colors.amber, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            // 新しく作ったWidgetを呼び出す
            child: _JackpotDialogContent(
              onPlayAgain: () {
                Navigator.of(context).pop();
                deckManager.newGame();
              },
              clearTime: deckManager.elapsedTime,
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.bounceOut,
            ), // バウンドしながら登場
            child: child,
          ),
        );
      },
    );
  }
}

class _JackpotDialogContent extends StatefulWidget {
  final VoidCallback onPlayAgain; // 「もう一度遊ぶ」ボタンのコールバック
  final String clearTime;

  const _JackpotDialogContent({
    required this.onPlayAgain,
    required this.clearTime,
  });

  @override
  State<_JackpotDialogContent> createState() => _JackpotDialogContentState();
}

class _JackpotDialogContentState extends State<_JackpotDialogContent> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );

    // ダイアログ表示と同時にコインを発射
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // ★★★ コイン噴射エフェクト ★★★
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.directional,
          blastDirection: -pi / 2, // 真上に発射
          emissionFrequency: 0.05,
          numberOfParticles: 20,
          gravity: 0.1,
          shouldLoop: false,
          colors: const [Colors.amber, Colors.orange, Colors.yellow],
          createParticlePath: (size) {
            // パーティクルの形を円（コイン）にする
            return Path()
              ..addOval(Rect.fromCircle(center: Offset.zero, radius: 7));
          },
        ),

        // ダイアログ本体
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),

            // ★★★ テキストアニメーション ★★★
            BounceInDown(
              // 上からバウンドしながら登場
              duration: const Duration(milliseconds: 1200),
              child: Flash(
                // キラキラ点滅
                infinite: true,
                duration: const Duration(seconds: 3),
                child: const Text(
                  'CLEAR!',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                    shadows: [Shadow(blurRadius: 5, color: Colors.black)],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            JelloIn(
              // プルプルしながら登場
              child: const Text(
                '全てのカードを揃えました！',
                style: TextStyle(color: Colors.white, fontSize: 20),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            // --- クリアタイムを表示するTextウィジェットを追加 ---
            Text(
              'CLEAR TIME: ${widget.clearTime}', // 受け取った時間を表示
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 48),

            // ボタンもアニメーション
            Pulse(
              infinite: true,
              delay: const Duration(seconds: 2),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  side: const BorderSide(color: Colors.amber, width: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                ),
                onPressed: widget.onPlayAgain,
                child: const Text('Play Again', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 35),
          ],
        ),
      ],
    );
  }
}

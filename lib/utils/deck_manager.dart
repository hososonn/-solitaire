import 'package:flutter/material.dart';
import 'package:solitaire/models/deck.dart';
import '../models/card_model.dart';
import 'dart:async';

enum DragSource {
  column,
  drawPile,
  foundation, // 将来的に使う可能性も考慮
}

class DeckManager extends ChangeNotifier {
  late List<SolitaireCard> _stock; // 山札
  late List<List<SolitaireCard>> _columns; // 場札
  SolitaireCard? _faceUpCard;
  final List<SolitaireCard> _drawed = [];
  int? dragSourceColumnIndex;
  bool _isGameWon = false;
  bool get isGameWon => _isGameWon;
  bool _isWinDialogShown = false;
  bool get isWinDialogShown => _isWinDialogShown;

  DragSource? dragSource; // 移動元の種類（列 or 山札）
  int? sourceIndex; // 移動元のインデックス（列番号など）

  // ファウンデーション 3列（ハート、スペード、クローバー）
  List<List<SolitaireCard>> foundations = List.generate(3, (_) => []);

  final List<Suit> foundationSuits = [Suit.hearts, Suit.spades, Suit.clubs];

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _elapsedTime = "00:00"; // UI表示用の時間文字列

  String get elapsedTime => _elapsedTime;

  List<List<SolitaireCard>> get columns => _columns;
  SolitaireCard? get faceUpCard => _faceUpCard;
  bool get hasCards => _stock.isNotEmpty;
  int get remainingCards => _stock.length;
  List<SolitaireCard> get drawed => _drawed;
  List<SolitaireCard>? draggingCards;

  // タップしたカードから下をドラッグ開始
  void startDragging(List<SolitaireCard> cards) {
    draggingCards = cards;
    notifyListeners();
  }

  // ドラッグ終了
  void stopDragging() {
    draggingCards = null;
    notifyListeners();
  }

  void newGame() {
    final deck = SolitaireDeck(); // 新しいデッキ作成
    deck.shuffle(); // シャッフル

    // 場札 15枚
    _columns = deck.dealToColumns();

    // 山札 = 残り
    _stock = deck.cards;

    _faceUpCard = null;

    _drawed.clear();

    _isGameWon = false;

    _isWinDialogShown = false;

    _timer?.cancel(); // 以前のタイマーが残っていればキャンセル
    _stopwatch.reset();
    _stopwatch.start();
    _elapsedTime = "00:00";
    _startTimer();

    // ファウンデーションも空に
    foundations = List.generate(3, (_) => <SolitaireCard>[]);
    notifyListeners();
  }

  void drawCard() {
    if (_stock.isNotEmpty) {
      _faceUpCard = _stock.removeLast();
      _faceUpCard!.isFaceUp = true;
      _drawed.add(_faceUpCard!);
      notifyListeners();
    }
  }

  // --- タイマーを開始・更新するためのメソッドを追加 ---
  void _startTimer() {
    // 1秒ごとに実行されるタイマーを作成
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // 経過時間を MM:SS 形式の文字列にフォーマット
      final minutes = _stopwatch.elapsed.inMinutes.toString().padLeft(2, '0');
      final seconds = (_stopwatch.elapsed.inSeconds % 60).toString().padLeft(
        2,
        '0',
      );
      _elapsedTime = "$minutes:$seconds";
      notifyListeners(); // UIに変更を通知
    });
  }

  void resetDeck() {
    // 山札とドロー済みカードをまとめる
    List<SolitaireCard> cardsToShuffle = [..._stock, ..._drawed];

    // 全部シャッフル
    cardsToShuffle.shuffle();

    // 山札に戻す
    _stock = cardsToShuffle;

    // ドロー済みカードは空に
    _drawed.clear();
    _faceUpCard = null;

    // 場札(_columns)とファウンデーション(foundations)はそのまま維持
    notifyListeners();
  }

  // void moveCardsToColumn(List<SolitaireCard> cards, int columnIndex) {
  //   // 元の列や drawed から削除
  //   for (var col in _columns) {
  //     col.removeWhere((c) => cards.contains(c));
  //   }
  //   _drawed.removeWhere((c) => cards.contains(c));

  //   // 目的列にまとめて追加
  //   _columns[columnIndex].addAll(cards);

  //   notifyListeners();
  // }

  void handleDropOnFoundation(
    List<SolitaireCard> cardsToMove,
    int foundationIndex,
  ) {
    // Foundationに移動できるのは常に1枚のカード
    if (cardsToMove.length != 1) return;

    final card = cardsToMove.first;
    final foundation = foundations[foundationIndex];

    print("--- FoundationへのDrop処理開始 ---");
    print("移動するカード: $card");
    print("移動先のFoundation: $foundationIndex");

    // --- 1. ルールチェック (念のため) ---
    final topCard = foundation.isEmpty ? null : foundation.last;
    // ルールに合わない場合は処理を中断
    if (!((topCard == null && card.rank == 1) || // A(ランク1)は空の場所に置ける
        (topCard != null &&
            card.suit == topCard.suit &&
            card.rank == topCard.rank + 1))) {
      print("ルール違反のため移動できません。");
      return;
    }

    // --- 2. 移動元からカードを削除 ---
    if (dragSource == null) {
      print("エラー: 移動元が特定できませんでした。");
      return;
    }
    print("移動元の種類: $dragSource, インデックス: $sourceIndex");

    bool removed = false;
    switch (dragSource!) {
      case DragSource.column:
        if (sourceIndex != null) {
          final sourceColumn = columns[sourceIndex!];
          // 列の一番最後のカードか確認
          if (sourceColumn.isNotEmpty && sourceColumn.last == card) {
            sourceColumn.removeLast();
            // ★移動後にカードをめくる処理★
            if (sourceColumn.isNotEmpty && !sourceColumn.last.isFaceUp) {
              print("移動元のカードをめくります: ${sourceColumn.last}");
              sourceColumn.last.isFaceUp = true;
            }
            removed = true;
          }
        }
        break;
      case DragSource.drawPile:
        if (drawed.isNotEmpty && drawed.last == card) {
          drawed.removeLast();
          removed = true;
        }
        break;
      case DragSource.foundation:
        break;
    }

    if (!removed) {
      print("致命的エラー: 移動元のカードが見つからず、削除できませんでした。");
      dragSource = null;
      sourceIndex = null;
      return;
    }

    // --- 3. 移動先に追加 ---
    foundation.add(card);
    print("移動後のFoundation: $foundation");

    // --- 4. 状態をリセットし、UIを更新 ---
    dragSource = null;
    sourceIndex = null;
    notifyListeners();
    print("--- FoundationへのDrop処理完了 ---");
    checkGameWin();
  }

  // ドラッグ開始時に元の列から削除
  void removeCardsFromColumn(List<SolitaireCard> cards, int columnIndex) {
    _columns[columnIndex].removeWhere((c) => cards.contains(c));
    _drawed.removeWhere((c) => cards.contains(c));
    notifyListeners();
  }

  // ドラッグ失敗時に元の列に戻す
  void returnCardsToColumn(List<SolitaireCard> cards, int columnIndex) {
    _columns[columnIndex].addAll(cards);
    notifyListeners();
  }

  // void flipTopCardInColumn(int columnIndex) {
  //   if (columnIndex < 0 || columnIndex >= columns.length) return;

  //   var column = columns[columnIndex];
  //   // 列が空ではなく、かつ一番最後のカードが裏向きの場合
  //   if (column.isNotEmpty && !column.last.isFaceUp) {
  //     column.last.isFaceUp = true;
  //     notifyListeners(); // UIを更新
  //   }
  // }

  void handleDropOnColumn(
    List<SolitaireCard> cardsToMove,
    int destinationColumnIndex,
  ) {
    print("--- Drop処理開始 ---");
    print("移動するカード: $cardsToMove");
    print("移動先の列: $destinationColumnIndex");

    // 移動元が不明な場合は何もしない
    if (dragSource == null) {
      print("エラー: 移動元が特定できませんでした。");
      return;
    }
    print("移動元の種類: $dragSource, インデックス: $sourceIndex");

    // 移動元のリストからカードを削除
    bool removed = false;
    switch (dragSource!) {
      case DragSource.column:
        if (sourceIndex != null) {
          final sourceColumn = columns[sourceIndex!];
          final startIndex = sourceColumn.indexOf(cardsToMove.first);
          if (startIndex != -1) {
            sourceColumn.removeRange(startIndex, sourceColumn.length);
            // 移動後にカードをめくる処理
            if (sourceColumn.isNotEmpty && !sourceColumn.last.isFaceUp) {
              sourceColumn.last.isFaceUp = true;
            }
            removed = true;
          }
        }
        break;
      case DragSource.drawPile:
        // 山札からは常に一番上のカードが移動する
        if (drawed.isNotEmpty && drawed.last == cardsToMove.first) {
          drawed.removeLast();
          removed = true;
        }
        break;
      case DragSource.foundation:
        // 今回は実装しないが、将来の拡張用
        break;
    }

    if (!removed) {
      print("致命的エラー: 移動元のカードが見つからず、削除できませんでした。");
      dragSource = null;
      sourceIndex = null;
      return;
    }

    // 移動先の列にカードを追加
    final destinationColumn = columns[destinationColumnIndex];
    destinationColumn.addAll(cardsToMove);

    // 状態をリセットし、UIを更新
    dragSource = null;
    sourceIndex = null;
    notifyListeners();
    print("--- Drop処理完了 ---");
  }

  void checkGameWin() {
    final totalCardsInFoundations = foundations.fold<int>(
      0,
      (sum, f) => sum + f.length,
    );
    if (totalCardsInFoundations == 1) {
      _isGameWon = true;
      _stopwatch.stop();
      _timer?.cancel();
      notifyListeners(); // UIにクリアを通知
    }
  }

  void markWinDialogAsShown() {
    _isWinDialogShown = true;
    // ここでは notifyListeners() を呼ばないのがポイント
    // UIの再描画はisGameWonがtrueになった時に既に行われているため
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}

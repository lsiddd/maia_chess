import 'package:dartchess/dartchess.dart';

import '../../../data/repositories/game_repository.dart';

/// Resultado de uma partida, do ponto de vista de "quem ganhou" (não do
/// jogador humano especificamente — isso é resolvido em `features/stats`
/// cruzando com o lado escolhido pelo jogador).
enum GameResult { emAndamento, vitoriaBrancas, vitoriaPretas, empate }

/// Estado imutável de uma partida em andamento.
///
/// [position] é a fonte da verdade das regras (pacote `dartchess`, ver
/// ADR-004). [positionHistory] guarda as posições anteriores para permitir
/// desfazer jogadas; [sanHistory] guarda a notação de cada lance já jogado
/// para exibição na lista de lances.
///
/// [aiSide] é `null` numa partida de dois humanos (Fase 1). Numa partida
/// contra a IA (Fase 2), indica qual lado o motor lc0/Maia joga; o lado
/// oposto é o do jogador humano.
class GameState {
  GameState({
    required this.position,
    required List<Chess> positionHistory,
    required List<String> sanHistory,
    required List<String> uciHistory,
    required List<GameMoveActor> moveActorHistory,
    required List<DateTime> moveTimeHistoryUtc,
    this.selectedSquare,
    this.evaluated = true,
    this.aiSide,
    this.levelRating,
    this.aiThinking = false,
    this.hintThinking = false,
    this.engineError,
    this.persistenceError,
    this.gameId,
    this.startedAtUtc,
    this.campaignMode = false,
    this.clockEnabled = false,
    this.initialTimeMs,
    this.whiteTimeMs,
    this.blackTimeMs,
  }) : positionHistory = List.unmodifiable(positionHistory),
       sanHistory = List.unmodifiable(sanHistory),
       uciHistory = List.unmodifiable(uciHistory),
       moveActorHistory = List.unmodifiable(moveActorHistory),
       moveTimeHistoryUtc = List.unmodifiable(moveTimeHistoryUtc) {
    final length = sanHistory.length;
    if (positionHistory.length != length ||
        uciHistory.length != length ||
        moveActorHistory.length != length ||
        moveTimeHistoryUtc.length != length) {
      throw ArgumentError(
        'Os históricos da partida devem ter o mesmo tamanho.',
      );
    }
  }

  factory GameState.initial() => GameState(
    position: Chess.initial,
    positionHistory: const [],
    sanHistory: const [],
    uciHistory: const [],
    moveActorHistory: const [],
    moveTimeHistoryUtc: const [],
  );

  final Chess position;

  /// Posições anteriores (uma por lance jogado), na ordem em que ocorreram.
  /// Usada para desfazer jogadas (`undo`).
  final List<Chess> positionHistory;

  /// Notação SAN de cada lance já jogado (ex: "Cf3", "e4", "O-O").
  final List<String> sanHistory;

  /// UCI é a representação canônica usada para reconstruir a partida.
  final List<String> uciHistory;

  /// Origem de cada lance, alinhada aos demais históricos.
  final List<GameMoveActor> moveActorHistory;

  /// Instante UTC de cada lance, alinhado aos demais históricos.
  final List<DateTime> moveTimeHistoryUtc;

  /// Casa selecionada pelo jogador (para o fluxo "toque": seleciona a
  /// origem, depois toca no destino). `null` se nada selecionado.
  final Square? selectedSquare;

  /// `false` quando undo ou dica foram usados nesta partida — nesse caso a
  /// partida entra no histórico mas fica fora do cálculo de rating/streaks
  /// (ver seção 7 da especificação e `features/stats`).
  final bool evaluated;

  /// Lado jogado pela IA (Maia via lc0). `null` = partida entre dois
  /// jogadores humanos.
  final Side? aiSide;

  /// Nível de dificuldade (1100-1900) da partida atual contra a IA, ou
  /// `null` fora do modo vs. IA.
  final int? levelRating;

  /// `true` enquanto o motor está calculando o próximo lance da IA — usado
  /// para bloquear interação do jogador e mostrar indicador de progresso.
  final bool aiThinking;

  /// `true` enquanto a dica dupla está sendo calculada. A posição fica
  /// bloqueada nesse intervalo para que a FEN consultada pelos motores e a
  /// posição usada na conversão UCI -> SAN permaneçam consistentes.
  final bool hintThinking;

  /// Mensagem de erro do motor (ex: falha ao carregar peso), ou `null`.
  final String? engineError;

  /// Falha do autosave. Não é misturada aos erros dos motores para permitir
  /// que a UI explique corretamente qual subsistema precisa de atenção.
  final String? persistenceError;

  /// Metadados do autosave da partida em andamento.
  final String? gameId;
  final DateTime? startedAtUtc;
  final bool campaignMode;
  final bool clockEnabled;
  final int? initialTimeMs;
  final int? whiteTimeMs;
  final int? blackTimeMs;

  /// A biblioteca de regras cobre mate, afogamento e material insuficiente,
  /// mas deliberadamente não mantém histórico para repetição nem adjudica a
  /// regra dos 50 lances. Essas duas regras dependentes da partida são
  /// resolvidas aqui.
  bool get isDrawByFiftyMoveRule => position.halfmoves >= 100;

  bool get isDrawByThreefoldRepetition {
    final currentKey = _repetitionKey(position);
    var occurrences = 1; // A posição atual não está em positionHistory.
    for (final previous in positionHistory) {
      if (_repetitionKey(previous) == currentKey) {
        occurrences++;
        if (occurrences >= 3) return true;
      }
    }
    return false;
  }

  bool get isGameOver =>
      position.isGameOver ||
      isDrawByFiftyMoveRule ||
      isDrawByThreefoldRepetition;

  bool get canUndo {
    if (positionHistory.isEmpty) return false;
    if (aiSide == null) return true;

    // Se a IA abriu de brancas e o humano ainda não jogou, não há uma
    // decisão do jogador para desfazer. Permitir undo nesse ponto deixaria
    // a posição inicial na vez da IA, mas sem disparar seu lance: um estado
    // travado.
    var index = positionHistory.length - 1;
    var previous = positionHistory[index];
    while (previous.turn == aiSide) {
      index--;
      if (index < 0) return false;
      previous = positionHistory[index];
    }
    return true;
  }

  /// Se a casa a mover agora é a da IA (bloqueia interação do jogador).
  bool get isAiTurn => aiSide != null && position.turn == aiSide;

  GameResult get result {
    if (!isGameOver) return GameResult.emAndamento;
    if (isDrawByFiftyMoveRule || isDrawByThreefoldRepetition) {
      return GameResult.empate;
    }
    final outcome = position.outcome;
    if (outcome == null || outcome.winner == null) return GameResult.empate;
    return outcome.winner == Side.white
        ? GameResult.vitoriaBrancas
        : GameResult.vitoriaPretas;
  }

  /// Por que a partida terminou, ou `null` se ela ainda está em andamento.
  ///
  /// Repetição e regra dos 50 lances vêm antes das condições da biblioteca
  /// de regras porque são adjudicadas aqui (ver [isDrawByFiftyMoveRule]) e
  /// podem coincidir com uma posição que também é afogamento.
  GameTermination? get termination {
    if (!isGameOver) return null;
    if (isDrawByThreefoldRepetition) {
      return GameTermination.threefoldRepetition;
    }
    if (isDrawByFiftyMoveRule) return GameTermination.fiftyMoveRule;
    if (position.isCheckmate) return GameTermination.checkmate;
    if (position.isStalemate) return GameTermination.stalemate;
    if (position.isInsufficientMaterial) {
      return GameTermination.insufficientMaterial;
    }
    return GameTermination.unknown;
  }

  /// Casas de destino legais a partir de [square], ou vazio se não houver
  /// peça do lado a mover ali.
  Iterable<Square> legalDestinationsFrom(Square square) {
    final destinations =
        position.legalMoves[square]?.squares.toSet() ?? <Square>{};

    // dartchess representa internamente o roque como rei -> torre para
    // também suportar Chess960. A UI deste app é de xadrez clássico, onde o
    // usuário naturalmente move o rei para g/c. Expomos os destinos
    // convencionais e deixamos `makeSan` fazer a validação final.
    final piece = position.board.pieceAt(square);
    if (piece?.role == Role.king) {
      final rank = piece!.color == Side.white ? Rank.first : Rank.eighth;
      final kingSideRook = Square.fromCoords(File.h, rank);
      final queenSideRook = Square.fromCoords(File.a, rank);
      // Um destino no canto também pode ser um passo normal do rei,
      // inclusive uma fuga de xeque ou captura. Só converte rei -> torre
      // quando a casa realmente contém uma torre da mesma cor.
      final ownRook = Piece(color: piece.color, role: Role.rook);
      if (position.board.pieceAt(kingSideRook) == ownRook &&
          destinations.remove(kingSideRook)) {
        destinations.add(Square.fromCoords(File.g, rank));
      }
      if (position.board.pieceAt(queenSideRook) == ownRook &&
          destinations.remove(queenSideRook)) {
        destinations.add(Square.fromCoords(File.c, rank));
      }
    }
    return destinations;
  }

  /// Se o lance de [from] para [to] exige escolha de peça de promoção
  /// (peão alcançando a última fileira).
  bool isPromotion(Square from, Square to) {
    final piece = position.board.pieceAt(from);
    if (piece == null || piece.role != Role.pawn) return false;
    final destRank = to.rank;
    return destRank == Rank.first || destRank == Rank.eighth;
  }

  GameState copyWith({
    Chess? position,
    List<Chess>? positionHistory,
    List<String>? sanHistory,
    List<String>? uciHistory,
    List<GameMoveActor>? moveActorHistory,
    List<DateTime>? moveTimeHistoryUtc,
    Square? selectedSquare,
    bool clearSelection = false,
    bool? evaluated,
    Side? aiSide,
    bool clearAiSide = false,
    int? levelRating,
    bool? aiThinking,
    bool? hintThinking,
    String? engineError,
    bool clearEngineError = false,
    String? persistenceError,
    bool clearPersistenceError = false,
    String? gameId,
    bool clearGameId = false,
    DateTime? startedAtUtc,
    bool? campaignMode,
    bool? clockEnabled,
    int? initialTimeMs,
    int? whiteTimeMs,
    int? blackTimeMs,
  }) {
    return GameState(
      position: position ?? this.position,
      positionHistory: positionHistory ?? this.positionHistory,
      sanHistory: sanHistory ?? this.sanHistory,
      uciHistory: uciHistory ?? this.uciHistory,
      moveActorHistory: moveActorHistory ?? this.moveActorHistory,
      moveTimeHistoryUtc: moveTimeHistoryUtc ?? this.moveTimeHistoryUtc,
      selectedSquare: clearSelection
          ? null
          : (selectedSquare ?? this.selectedSquare),
      evaluated: evaluated ?? this.evaluated,
      aiSide: clearAiSide ? null : (aiSide ?? this.aiSide),
      levelRating: levelRating ?? this.levelRating,
      aiThinking: aiThinking ?? this.aiThinking,
      hintThinking: hintThinking ?? this.hintThinking,
      engineError: clearEngineError ? null : (engineError ?? this.engineError),
      persistenceError: clearPersistenceError
          ? null
          : (persistenceError ?? this.persistenceError),
      gameId: clearGameId ? null : (gameId ?? this.gameId),
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      campaignMode: campaignMode ?? this.campaignMode,
      clockEnabled: clockEnabled ?? this.clockEnabled,
      initialTimeMs: initialTimeMs ?? this.initialTimeMs,
      whiteTimeMs: whiteTimeMs ?? this.whiteTimeMs,
      blackTimeMs: blackTimeMs ?? this.blackTimeMs,
    );
  }

  /// Identidade de posição usada pela regra de repetição: colocação das
  /// peças, lado a jogar, direitos de roque e en passant legal. Relógios de
  /// meio-lance/lance completo não fazem parte da identidade.
  static String _repetitionKey(Chess position) =>
      position.fen.split(' ').take(4).join(' ');
}

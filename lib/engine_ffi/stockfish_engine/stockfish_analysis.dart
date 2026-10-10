/// A ranked principal variation. Scores are from the side to move's perspective.
class StockfishLine {
  StockfishLine({
    required this.rank,
    required this.depth,
    required List<String> moves,
    this.centipawns,
    this.mate,
  }) : moves = List.unmodifiable(moves);

  final int rank;
  final int depth;
  final List<String> moves;
  final int? centipawns;
  final int? mate;

  static StockfishLine? parse(String line) {
    final tokens = line.trim().split(RegExp(r'\s+'));
    if (tokens.first != 'info' ||
        tokens.contains('string') ||
        tokens.contains('lowerbound') ||
        tokens.contains('upperbound')) {
      return null;
    }
    int? numberAfter(String token) {
      final index = tokens.indexOf(token);
      return index < 0 || index + 1 >= tokens.length
          ? null
          : int.tryParse(tokens[index + 1]);
    }

    final pv = tokens.indexOf('pv');
    final depth = numberAfter('depth');
    final rank = numberAfter('multipv') ?? 1;
    final cp = numberAfter('cp');
    final mate = numberAfter('mate');
    if (pv < 0 ||
        pv + 1 >= tokens.length ||
        depth == null ||
        depth < 1 ||
        rank < 1 ||
        (cp == null && mate == null)) {
      return null;
    }
    return StockfishLine(
      rank: rank,
      depth: depth,
      moves: tokens.sublist(pv + 1),
      centipawns: cp,
      mate: mate,
    );
  }
}

/// Keeps a coherent iteration instead of mixing ranks from different depths.
/// At most two iterations are retained, regardless of search duration.
class StockfishAnalysisCollector {
  StockfishAnalysisCollector(this.count);

  final int count;
  int _depth = 0;
  Map<int, StockfishLine> _current = {};
  List<StockfishLine> _complete = const [];

  void add(String message) {
    final line = StockfishLine.parse(message);
    if (line == null || line.rank > count || line.depth < _depth) return;
    if (line.depth > _depth) {
      _retainIteration();
      _current = {};
      _depth = line.depth;
    }
    _current[line.rank] = line;
  }

  void _retainIteration() {
    final lines = _current.values.toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    if (lines.length < _complete.length) return;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].rank != i + 1) return;
    }
    if (lines.map((line) => line.moves.first).toSet().length != lines.length) {
      return;
    }
    _complete = List.unmodifiable(lines);
  }

  List<StockfishLine> get lines {
    _retainIteration();
    return _complete;
  }
}

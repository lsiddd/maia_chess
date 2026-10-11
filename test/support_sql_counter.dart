import 'package:drift/drift.dart';

class SqlCounter extends QueryInterceptor {
  final selects = <String>[];
  final deletes = <String>[];
  int batchRows = 0;

  void reset() {
    selects.clear();
    deletes.clear();
    batchRows = 0;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selects.add(statement);
    return executor.runSelect(statement, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    deletes.add(statement);
    return executor.runDelete(statement, args);
  }

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) {
    batchRows += statements.arguments.length;
    return executor.runBatched(statements);
  }
}

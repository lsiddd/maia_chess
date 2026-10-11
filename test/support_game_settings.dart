import 'dart:async';
import 'package:maia_chess/data/repositories/settings_repository.dart';

class MemorySettings implements SettingsRepository {
  MemorySettings([this.value = const StoredAppSettings()]);
  StoredAppSettings value;
  final _changes = StreamController<StoredAppSettings>.broadcast();
  @override
  Future<StoredAppSettings> get() async => value;
  @override
  Future<void> save(StoredAppSettings settings) async {
    value = settings;
    _changes.add(value);
  }

  @override
  Stream<StoredAppSettings> watch() async* {
    yield value;
    yield* _changes.stream;
  }

  Future<void> close() => _changes.close();
}

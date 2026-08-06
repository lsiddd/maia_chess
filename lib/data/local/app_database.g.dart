// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $GamesTable extends Games with TableInfo<$GamesTable, GameRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GamesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtUtcMeta = const VerificationMeta(
    'startedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> startedAtUtc = GeneratedColumn<DateTime>(
    'started_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtUtcMeta = const VerificationMeta(
    'endedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> endedAtUtc = GeneratedColumn<DateTime>(
    'ended_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastModifiedAtUtcMeta = const VerificationMeta(
    'lastModifiedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> lastModifiedAtUtc =
      GeneratedColumn<DateTime>(
        'last_modified_at_utc',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ongoing'),
  );
  static const VerificationMeta _levelRatingMeta = const VerificationMeta(
    'levelRating',
  );
  @override
  late final GeneratedColumn<int> levelRating = GeneratedColumn<int>(
    'level_rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _playerSideMeta = const VerificationMeta(
    'playerSide',
  );
  @override
  late final GeneratedColumn<String> playerSide = GeneratedColumn<String>(
    'player_side',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ongoing'),
  );
  static const VerificationMeta _terminationMeta = const VerificationMeta(
    'termination',
  );
  @override
  late final GeneratedColumn<String> termination = GeneratedColumn<String>(
    'termination',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _evaluatedMeta = const VerificationMeta(
    'evaluated',
  );
  @override
  late final GeneratedColumn<bool> evaluated = GeneratedColumn<bool>(
    'evaluated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("evaluated" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _campaignModeMeta = const VerificationMeta(
    'campaignMode',
  );
  @override
  late final GeneratedColumn<bool> campaignMode = GeneratedColumn<bool>(
    'campaign_mode',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("campaign_mode" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _initialFenMeta = const VerificationMeta(
    'initialFen',
  );
  @override
  late final GeneratedColumn<String> initialFen = GeneratedColumn<String>(
    'initial_fen',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentFenMeta = const VerificationMeta(
    'currentFen',
  );
  @override
  late final GeneratedColumn<String> currentFen = GeneratedColumn<String>(
    'current_fen',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pgnMeta = const VerificationMeta('pgn');
  @override
  late final GeneratedColumn<String> pgn = GeneratedColumn<String>(
    'pgn',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clockEnabledMeta = const VerificationMeta(
    'clockEnabled',
  );
  @override
  late final GeneratedColumn<bool> clockEnabled = GeneratedColumn<bool>(
    'clock_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("clock_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _initialTimeMsMeta = const VerificationMeta(
    'initialTimeMs',
  );
  @override
  late final GeneratedColumn<int> initialTimeMs = GeneratedColumn<int>(
    'initial_time_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _whiteTimeMsMeta = const VerificationMeta(
    'whiteTimeMs',
  );
  @override
  late final GeneratedColumn<int> whiteTimeMs = GeneratedColumn<int>(
    'white_time_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blackTimeMsMeta = const VerificationMeta(
    'blackTimeMs',
  );
  @override
  late final GeneratedColumn<int> blackTimeMs = GeneratedColumn<int>(
    'black_time_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAtUtc,
    endedAtUtc,
    lastModifiedAtUtc,
    status,
    levelRating,
    playerSide,
    result,
    termination,
    evaluated,
    campaignMode,
    initialFen,
    currentFen,
    pgn,
    clockEnabled,
    initialTimeMs,
    whiteTimeMs,
    blackTimeMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'games';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at_utc')) {
      context.handle(
        _startedAtUtcMeta,
        startedAtUtc.isAcceptableOrUnknown(
          data['started_at_utc']!,
          _startedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtUtcMeta);
    }
    if (data.containsKey('ended_at_utc')) {
      context.handle(
        _endedAtUtcMeta,
        endedAtUtc.isAcceptableOrUnknown(
          data['ended_at_utc']!,
          _endedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('last_modified_at_utc')) {
      context.handle(
        _lastModifiedAtUtcMeta,
        lastModifiedAtUtc.isAcceptableOrUnknown(
          data['last_modified_at_utc']!,
          _lastModifiedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastModifiedAtUtcMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('level_rating')) {
      context.handle(
        _levelRatingMeta,
        levelRating.isAcceptableOrUnknown(
          data['level_rating']!,
          _levelRatingMeta,
        ),
      );
    }
    if (data.containsKey('player_side')) {
      context.handle(
        _playerSideMeta,
        playerSide.isAcceptableOrUnknown(data['player_side']!, _playerSideMeta),
      );
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    }
    if (data.containsKey('termination')) {
      context.handle(
        _terminationMeta,
        termination.isAcceptableOrUnknown(
          data['termination']!,
          _terminationMeta,
        ),
      );
    }
    if (data.containsKey('evaluated')) {
      context.handle(
        _evaluatedMeta,
        evaluated.isAcceptableOrUnknown(data['evaluated']!, _evaluatedMeta),
      );
    }
    if (data.containsKey('campaign_mode')) {
      context.handle(
        _campaignModeMeta,
        campaignMode.isAcceptableOrUnknown(
          data['campaign_mode']!,
          _campaignModeMeta,
        ),
      );
    }
    if (data.containsKey('initial_fen')) {
      context.handle(
        _initialFenMeta,
        initialFen.isAcceptableOrUnknown(data['initial_fen']!, _initialFenMeta),
      );
    } else if (isInserting) {
      context.missing(_initialFenMeta);
    }
    if (data.containsKey('current_fen')) {
      context.handle(
        _currentFenMeta,
        currentFen.isAcceptableOrUnknown(data['current_fen']!, _currentFenMeta),
      );
    } else if (isInserting) {
      context.missing(_currentFenMeta);
    }
    if (data.containsKey('pgn')) {
      context.handle(
        _pgnMeta,
        pgn.isAcceptableOrUnknown(data['pgn']!, _pgnMeta),
      );
    }
    if (data.containsKey('clock_enabled')) {
      context.handle(
        _clockEnabledMeta,
        clockEnabled.isAcceptableOrUnknown(
          data['clock_enabled']!,
          _clockEnabledMeta,
        ),
      );
    }
    if (data.containsKey('initial_time_ms')) {
      context.handle(
        _initialTimeMsMeta,
        initialTimeMs.isAcceptableOrUnknown(
          data['initial_time_ms']!,
          _initialTimeMsMeta,
        ),
      );
    }
    if (data.containsKey('white_time_ms')) {
      context.handle(
        _whiteTimeMsMeta,
        whiteTimeMs.isAcceptableOrUnknown(
          data['white_time_ms']!,
          _whiteTimeMsMeta,
        ),
      );
    }
    if (data.containsKey('black_time_ms')) {
      context.handle(
        _blackTimeMsMeta,
        blackTimeMs.isAcceptableOrUnknown(
          data['black_time_ms']!,
          _blackTimeMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GameRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at_utc'],
      )!,
      endedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at_utc'],
      ),
      lastModifiedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_modified_at_utc'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      levelRating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level_rating'],
      ),
      playerSide: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_side'],
      ),
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      )!,
      termination: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}termination'],
      ),
      evaluated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}evaluated'],
      )!,
      campaignMode: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}campaign_mode'],
      )!,
      initialFen: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}initial_fen'],
      )!,
      currentFen: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_fen'],
      )!,
      pgn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pgn'],
      ),
      clockEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}clock_enabled'],
      )!,
      initialTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}initial_time_ms'],
      ),
      whiteTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}white_time_ms'],
      ),
      blackTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}black_time_ms'],
      ),
    );
  }

  @override
  $GamesTable createAlias(String alias) {
    return $GamesTable(attachedDatabase, alias);
  }
}

class GameRow extends DataClass implements Insertable<GameRow> {
  final String id;
  final DateTime startedAtUtc;
  final DateTime? endedAtUtc;
  final DateTime lastModifiedAtUtc;
  final String status;
  final int? levelRating;
  final String? playerSide;
  final String result;
  final String? termination;
  final bool evaluated;
  final bool campaignMode;
  final String initialFen;
  final String currentFen;
  final String? pgn;
  final bool clockEnabled;
  final int? initialTimeMs;
  final int? whiteTimeMs;
  final int? blackTimeMs;
  const GameRow({
    required this.id,
    required this.startedAtUtc,
    this.endedAtUtc,
    required this.lastModifiedAtUtc,
    required this.status,
    this.levelRating,
    this.playerSide,
    required this.result,
    this.termination,
    required this.evaluated,
    required this.campaignMode,
    required this.initialFen,
    required this.currentFen,
    this.pgn,
    required this.clockEnabled,
    this.initialTimeMs,
    this.whiteTimeMs,
    this.blackTimeMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at_utc'] = Variable<DateTime>(startedAtUtc);
    if (!nullToAbsent || endedAtUtc != null) {
      map['ended_at_utc'] = Variable<DateTime>(endedAtUtc);
    }
    map['last_modified_at_utc'] = Variable<DateTime>(lastModifiedAtUtc);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || levelRating != null) {
      map['level_rating'] = Variable<int>(levelRating);
    }
    if (!nullToAbsent || playerSide != null) {
      map['player_side'] = Variable<String>(playerSide);
    }
    map['result'] = Variable<String>(result);
    if (!nullToAbsent || termination != null) {
      map['termination'] = Variable<String>(termination);
    }
    map['evaluated'] = Variable<bool>(evaluated);
    map['campaign_mode'] = Variable<bool>(campaignMode);
    map['initial_fen'] = Variable<String>(initialFen);
    map['current_fen'] = Variable<String>(currentFen);
    if (!nullToAbsent || pgn != null) {
      map['pgn'] = Variable<String>(pgn);
    }
    map['clock_enabled'] = Variable<bool>(clockEnabled);
    if (!nullToAbsent || initialTimeMs != null) {
      map['initial_time_ms'] = Variable<int>(initialTimeMs);
    }
    if (!nullToAbsent || whiteTimeMs != null) {
      map['white_time_ms'] = Variable<int>(whiteTimeMs);
    }
    if (!nullToAbsent || blackTimeMs != null) {
      map['black_time_ms'] = Variable<int>(blackTimeMs);
    }
    return map;
  }

  GamesCompanion toCompanion(bool nullToAbsent) {
    return GamesCompanion(
      id: Value(id),
      startedAtUtc: Value(startedAtUtc),
      endedAtUtc: endedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAtUtc),
      lastModifiedAtUtc: Value(lastModifiedAtUtc),
      status: Value(status),
      levelRating: levelRating == null && nullToAbsent
          ? const Value.absent()
          : Value(levelRating),
      playerSide: playerSide == null && nullToAbsent
          ? const Value.absent()
          : Value(playerSide),
      result: Value(result),
      termination: termination == null && nullToAbsent
          ? const Value.absent()
          : Value(termination),
      evaluated: Value(evaluated),
      campaignMode: Value(campaignMode),
      initialFen: Value(initialFen),
      currentFen: Value(currentFen),
      pgn: pgn == null && nullToAbsent ? const Value.absent() : Value(pgn),
      clockEnabled: Value(clockEnabled),
      initialTimeMs: initialTimeMs == null && nullToAbsent
          ? const Value.absent()
          : Value(initialTimeMs),
      whiteTimeMs: whiteTimeMs == null && nullToAbsent
          ? const Value.absent()
          : Value(whiteTimeMs),
      blackTimeMs: blackTimeMs == null && nullToAbsent
          ? const Value.absent()
          : Value(blackTimeMs),
    );
  }

  factory GameRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameRow(
      id: serializer.fromJson<String>(json['id']),
      startedAtUtc: serializer.fromJson<DateTime>(json['startedAtUtc']),
      endedAtUtc: serializer.fromJson<DateTime?>(json['endedAtUtc']),
      lastModifiedAtUtc: serializer.fromJson<DateTime>(
        json['lastModifiedAtUtc'],
      ),
      status: serializer.fromJson<String>(json['status']),
      levelRating: serializer.fromJson<int?>(json['levelRating']),
      playerSide: serializer.fromJson<String?>(json['playerSide']),
      result: serializer.fromJson<String>(json['result']),
      termination: serializer.fromJson<String?>(json['termination']),
      evaluated: serializer.fromJson<bool>(json['evaluated']),
      campaignMode: serializer.fromJson<bool>(json['campaignMode']),
      initialFen: serializer.fromJson<String>(json['initialFen']),
      currentFen: serializer.fromJson<String>(json['currentFen']),
      pgn: serializer.fromJson<String?>(json['pgn']),
      clockEnabled: serializer.fromJson<bool>(json['clockEnabled']),
      initialTimeMs: serializer.fromJson<int?>(json['initialTimeMs']),
      whiteTimeMs: serializer.fromJson<int?>(json['whiteTimeMs']),
      blackTimeMs: serializer.fromJson<int?>(json['blackTimeMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAtUtc': serializer.toJson<DateTime>(startedAtUtc),
      'endedAtUtc': serializer.toJson<DateTime?>(endedAtUtc),
      'lastModifiedAtUtc': serializer.toJson<DateTime>(lastModifiedAtUtc),
      'status': serializer.toJson<String>(status),
      'levelRating': serializer.toJson<int?>(levelRating),
      'playerSide': serializer.toJson<String?>(playerSide),
      'result': serializer.toJson<String>(result),
      'termination': serializer.toJson<String?>(termination),
      'evaluated': serializer.toJson<bool>(evaluated),
      'campaignMode': serializer.toJson<bool>(campaignMode),
      'initialFen': serializer.toJson<String>(initialFen),
      'currentFen': serializer.toJson<String>(currentFen),
      'pgn': serializer.toJson<String?>(pgn),
      'clockEnabled': serializer.toJson<bool>(clockEnabled),
      'initialTimeMs': serializer.toJson<int?>(initialTimeMs),
      'whiteTimeMs': serializer.toJson<int?>(whiteTimeMs),
      'blackTimeMs': serializer.toJson<int?>(blackTimeMs),
    };
  }

  GameRow copyWith({
    String? id,
    DateTime? startedAtUtc,
    Value<DateTime?> endedAtUtc = const Value.absent(),
    DateTime? lastModifiedAtUtc,
    String? status,
    Value<int?> levelRating = const Value.absent(),
    Value<String?> playerSide = const Value.absent(),
    String? result,
    Value<String?> termination = const Value.absent(),
    bool? evaluated,
    bool? campaignMode,
    String? initialFen,
    String? currentFen,
    Value<String?> pgn = const Value.absent(),
    bool? clockEnabled,
    Value<int?> initialTimeMs = const Value.absent(),
    Value<int?> whiteTimeMs = const Value.absent(),
    Value<int?> blackTimeMs = const Value.absent(),
  }) => GameRow(
    id: id ?? this.id,
    startedAtUtc: startedAtUtc ?? this.startedAtUtc,
    endedAtUtc: endedAtUtc.present ? endedAtUtc.value : this.endedAtUtc,
    lastModifiedAtUtc: lastModifiedAtUtc ?? this.lastModifiedAtUtc,
    status: status ?? this.status,
    levelRating: levelRating.present ? levelRating.value : this.levelRating,
    playerSide: playerSide.present ? playerSide.value : this.playerSide,
    result: result ?? this.result,
    termination: termination.present ? termination.value : this.termination,
    evaluated: evaluated ?? this.evaluated,
    campaignMode: campaignMode ?? this.campaignMode,
    initialFen: initialFen ?? this.initialFen,
    currentFen: currentFen ?? this.currentFen,
    pgn: pgn.present ? pgn.value : this.pgn,
    clockEnabled: clockEnabled ?? this.clockEnabled,
    initialTimeMs: initialTimeMs.present
        ? initialTimeMs.value
        : this.initialTimeMs,
    whiteTimeMs: whiteTimeMs.present ? whiteTimeMs.value : this.whiteTimeMs,
    blackTimeMs: blackTimeMs.present ? blackTimeMs.value : this.blackTimeMs,
  );
  GameRow copyWithCompanion(GamesCompanion data) {
    return GameRow(
      id: data.id.present ? data.id.value : this.id,
      startedAtUtc: data.startedAtUtc.present
          ? data.startedAtUtc.value
          : this.startedAtUtc,
      endedAtUtc: data.endedAtUtc.present
          ? data.endedAtUtc.value
          : this.endedAtUtc,
      lastModifiedAtUtc: data.lastModifiedAtUtc.present
          ? data.lastModifiedAtUtc.value
          : this.lastModifiedAtUtc,
      status: data.status.present ? data.status.value : this.status,
      levelRating: data.levelRating.present
          ? data.levelRating.value
          : this.levelRating,
      playerSide: data.playerSide.present
          ? data.playerSide.value
          : this.playerSide,
      result: data.result.present ? data.result.value : this.result,
      termination: data.termination.present
          ? data.termination.value
          : this.termination,
      evaluated: data.evaluated.present ? data.evaluated.value : this.evaluated,
      campaignMode: data.campaignMode.present
          ? data.campaignMode.value
          : this.campaignMode,
      initialFen: data.initialFen.present
          ? data.initialFen.value
          : this.initialFen,
      currentFen: data.currentFen.present
          ? data.currentFen.value
          : this.currentFen,
      pgn: data.pgn.present ? data.pgn.value : this.pgn,
      clockEnabled: data.clockEnabled.present
          ? data.clockEnabled.value
          : this.clockEnabled,
      initialTimeMs: data.initialTimeMs.present
          ? data.initialTimeMs.value
          : this.initialTimeMs,
      whiteTimeMs: data.whiteTimeMs.present
          ? data.whiteTimeMs.value
          : this.whiteTimeMs,
      blackTimeMs: data.blackTimeMs.present
          ? data.blackTimeMs.value
          : this.blackTimeMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameRow(')
          ..write('id: $id, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('endedAtUtc: $endedAtUtc, ')
          ..write('lastModifiedAtUtc: $lastModifiedAtUtc, ')
          ..write('status: $status, ')
          ..write('levelRating: $levelRating, ')
          ..write('playerSide: $playerSide, ')
          ..write('result: $result, ')
          ..write('termination: $termination, ')
          ..write('evaluated: $evaluated, ')
          ..write('campaignMode: $campaignMode, ')
          ..write('initialFen: $initialFen, ')
          ..write('currentFen: $currentFen, ')
          ..write('pgn: $pgn, ')
          ..write('clockEnabled: $clockEnabled, ')
          ..write('initialTimeMs: $initialTimeMs, ')
          ..write('whiteTimeMs: $whiteTimeMs, ')
          ..write('blackTimeMs: $blackTimeMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAtUtc,
    endedAtUtc,
    lastModifiedAtUtc,
    status,
    levelRating,
    playerSide,
    result,
    termination,
    evaluated,
    campaignMode,
    initialFen,
    currentFen,
    pgn,
    clockEnabled,
    initialTimeMs,
    whiteTimeMs,
    blackTimeMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameRow &&
          other.id == this.id &&
          other.startedAtUtc == this.startedAtUtc &&
          other.endedAtUtc == this.endedAtUtc &&
          other.lastModifiedAtUtc == this.lastModifiedAtUtc &&
          other.status == this.status &&
          other.levelRating == this.levelRating &&
          other.playerSide == this.playerSide &&
          other.result == this.result &&
          other.termination == this.termination &&
          other.evaluated == this.evaluated &&
          other.campaignMode == this.campaignMode &&
          other.initialFen == this.initialFen &&
          other.currentFen == this.currentFen &&
          other.pgn == this.pgn &&
          other.clockEnabled == this.clockEnabled &&
          other.initialTimeMs == this.initialTimeMs &&
          other.whiteTimeMs == this.whiteTimeMs &&
          other.blackTimeMs == this.blackTimeMs);
}

class GamesCompanion extends UpdateCompanion<GameRow> {
  final Value<String> id;
  final Value<DateTime> startedAtUtc;
  final Value<DateTime?> endedAtUtc;
  final Value<DateTime> lastModifiedAtUtc;
  final Value<String> status;
  final Value<int?> levelRating;
  final Value<String?> playerSide;
  final Value<String> result;
  final Value<String?> termination;
  final Value<bool> evaluated;
  final Value<bool> campaignMode;
  final Value<String> initialFen;
  final Value<String> currentFen;
  final Value<String?> pgn;
  final Value<bool> clockEnabled;
  final Value<int?> initialTimeMs;
  final Value<int?> whiteTimeMs;
  final Value<int?> blackTimeMs;
  final Value<int> rowid;
  const GamesCompanion({
    this.id = const Value.absent(),
    this.startedAtUtc = const Value.absent(),
    this.endedAtUtc = const Value.absent(),
    this.lastModifiedAtUtc = const Value.absent(),
    this.status = const Value.absent(),
    this.levelRating = const Value.absent(),
    this.playerSide = const Value.absent(),
    this.result = const Value.absent(),
    this.termination = const Value.absent(),
    this.evaluated = const Value.absent(),
    this.campaignMode = const Value.absent(),
    this.initialFen = const Value.absent(),
    this.currentFen = const Value.absent(),
    this.pgn = const Value.absent(),
    this.clockEnabled = const Value.absent(),
    this.initialTimeMs = const Value.absent(),
    this.whiteTimeMs = const Value.absent(),
    this.blackTimeMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GamesCompanion.insert({
    required String id,
    required DateTime startedAtUtc,
    this.endedAtUtc = const Value.absent(),
    required DateTime lastModifiedAtUtc,
    this.status = const Value.absent(),
    this.levelRating = const Value.absent(),
    this.playerSide = const Value.absent(),
    this.result = const Value.absent(),
    this.termination = const Value.absent(),
    this.evaluated = const Value.absent(),
    this.campaignMode = const Value.absent(),
    required String initialFen,
    required String currentFen,
    this.pgn = const Value.absent(),
    this.clockEnabled = const Value.absent(),
    this.initialTimeMs = const Value.absent(),
    this.whiteTimeMs = const Value.absent(),
    this.blackTimeMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAtUtc = Value(startedAtUtc),
       lastModifiedAtUtc = Value(lastModifiedAtUtc),
       initialFen = Value(initialFen),
       currentFen = Value(currentFen);
  static Insertable<GameRow> custom({
    Expression<String>? id,
    Expression<DateTime>? startedAtUtc,
    Expression<DateTime>? endedAtUtc,
    Expression<DateTime>? lastModifiedAtUtc,
    Expression<String>? status,
    Expression<int>? levelRating,
    Expression<String>? playerSide,
    Expression<String>? result,
    Expression<String>? termination,
    Expression<bool>? evaluated,
    Expression<bool>? campaignMode,
    Expression<String>? initialFen,
    Expression<String>? currentFen,
    Expression<String>? pgn,
    Expression<bool>? clockEnabled,
    Expression<int>? initialTimeMs,
    Expression<int>? whiteTimeMs,
    Expression<int>? blackTimeMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAtUtc != null) 'started_at_utc': startedAtUtc,
      if (endedAtUtc != null) 'ended_at_utc': endedAtUtc,
      if (lastModifiedAtUtc != null) 'last_modified_at_utc': lastModifiedAtUtc,
      if (status != null) 'status': status,
      if (levelRating != null) 'level_rating': levelRating,
      if (playerSide != null) 'player_side': playerSide,
      if (result != null) 'result': result,
      if (termination != null) 'termination': termination,
      if (evaluated != null) 'evaluated': evaluated,
      if (campaignMode != null) 'campaign_mode': campaignMode,
      if (initialFen != null) 'initial_fen': initialFen,
      if (currentFen != null) 'current_fen': currentFen,
      if (pgn != null) 'pgn': pgn,
      if (clockEnabled != null) 'clock_enabled': clockEnabled,
      if (initialTimeMs != null) 'initial_time_ms': initialTimeMs,
      if (whiteTimeMs != null) 'white_time_ms': whiteTimeMs,
      if (blackTimeMs != null) 'black_time_ms': blackTimeMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GamesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? startedAtUtc,
    Value<DateTime?>? endedAtUtc,
    Value<DateTime>? lastModifiedAtUtc,
    Value<String>? status,
    Value<int?>? levelRating,
    Value<String?>? playerSide,
    Value<String>? result,
    Value<String?>? termination,
    Value<bool>? evaluated,
    Value<bool>? campaignMode,
    Value<String>? initialFen,
    Value<String>? currentFen,
    Value<String?>? pgn,
    Value<bool>? clockEnabled,
    Value<int?>? initialTimeMs,
    Value<int?>? whiteTimeMs,
    Value<int?>? blackTimeMs,
    Value<int>? rowid,
  }) {
    return GamesCompanion(
      id: id ?? this.id,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      endedAtUtc: endedAtUtc ?? this.endedAtUtc,
      lastModifiedAtUtc: lastModifiedAtUtc ?? this.lastModifiedAtUtc,
      status: status ?? this.status,
      levelRating: levelRating ?? this.levelRating,
      playerSide: playerSide ?? this.playerSide,
      result: result ?? this.result,
      termination: termination ?? this.termination,
      evaluated: evaluated ?? this.evaluated,
      campaignMode: campaignMode ?? this.campaignMode,
      initialFen: initialFen ?? this.initialFen,
      currentFen: currentFen ?? this.currentFen,
      pgn: pgn ?? this.pgn,
      clockEnabled: clockEnabled ?? this.clockEnabled,
      initialTimeMs: initialTimeMs ?? this.initialTimeMs,
      whiteTimeMs: whiteTimeMs ?? this.whiteTimeMs,
      blackTimeMs: blackTimeMs ?? this.blackTimeMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startedAtUtc.present) {
      map['started_at_utc'] = Variable<DateTime>(startedAtUtc.value);
    }
    if (endedAtUtc.present) {
      map['ended_at_utc'] = Variable<DateTime>(endedAtUtc.value);
    }
    if (lastModifiedAtUtc.present) {
      map['last_modified_at_utc'] = Variable<DateTime>(lastModifiedAtUtc.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (levelRating.present) {
      map['level_rating'] = Variable<int>(levelRating.value);
    }
    if (playerSide.present) {
      map['player_side'] = Variable<String>(playerSide.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (termination.present) {
      map['termination'] = Variable<String>(termination.value);
    }
    if (evaluated.present) {
      map['evaluated'] = Variable<bool>(evaluated.value);
    }
    if (campaignMode.present) {
      map['campaign_mode'] = Variable<bool>(campaignMode.value);
    }
    if (initialFen.present) {
      map['initial_fen'] = Variable<String>(initialFen.value);
    }
    if (currentFen.present) {
      map['current_fen'] = Variable<String>(currentFen.value);
    }
    if (pgn.present) {
      map['pgn'] = Variable<String>(pgn.value);
    }
    if (clockEnabled.present) {
      map['clock_enabled'] = Variable<bool>(clockEnabled.value);
    }
    if (initialTimeMs.present) {
      map['initial_time_ms'] = Variable<int>(initialTimeMs.value);
    }
    if (whiteTimeMs.present) {
      map['white_time_ms'] = Variable<int>(whiteTimeMs.value);
    }
    if (blackTimeMs.present) {
      map['black_time_ms'] = Variable<int>(blackTimeMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GamesCompanion(')
          ..write('id: $id, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('endedAtUtc: $endedAtUtc, ')
          ..write('lastModifiedAtUtc: $lastModifiedAtUtc, ')
          ..write('status: $status, ')
          ..write('levelRating: $levelRating, ')
          ..write('playerSide: $playerSide, ')
          ..write('result: $result, ')
          ..write('termination: $termination, ')
          ..write('evaluated: $evaluated, ')
          ..write('campaignMode: $campaignMode, ')
          ..write('initialFen: $initialFen, ')
          ..write('currentFen: $currentFen, ')
          ..write('pgn: $pgn, ')
          ..write('clockEnabled: $clockEnabled, ')
          ..write('initialTimeMs: $initialTimeMs, ')
          ..write('whiteTimeMs: $whiteTimeMs, ')
          ..write('blackTimeMs: $blackTimeMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GameMovesTable extends GameMoves
    with TableInfo<$GameMovesTable, GameMoveRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameMovesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<String> gameId = GeneratedColumn<String>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES games (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _plyMeta = const VerificationMeta('ply');
  @override
  late final GeneratedColumn<int> ply = GeneratedColumn<int>(
    'ply',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uciMeta = const VerificationMeta('uci');
  @override
  late final GeneratedColumn<String> uci = GeneratedColumn<String>(
    'uci',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sanMeta = const VerificationMeta('san');
  @override
  late final GeneratedColumn<String> san = GeneratedColumn<String>(
    'san',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fenAfterMeta = const VerificationMeta(
    'fenAfter',
  );
  @override
  late final GeneratedColumn<String> fenAfter = GeneratedColumn<String>(
    'fen_after',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorMeta = const VerificationMeta('actor');
  @override
  late final GeneratedColumn<String> actor = GeneratedColumn<String>(
    'actor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playedAtUtcMeta = const VerificationMeta(
    'playedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> playedAtUtc = GeneratedColumn<DateTime>(
    'played_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    gameId,
    ply,
    uci,
    san,
    fenAfter,
    actor,
    playedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_moves';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameMoveRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    if (data.containsKey('ply')) {
      context.handle(
        _plyMeta,
        ply.isAcceptableOrUnknown(data['ply']!, _plyMeta),
      );
    } else if (isInserting) {
      context.missing(_plyMeta);
    }
    if (data.containsKey('uci')) {
      context.handle(
        _uciMeta,
        uci.isAcceptableOrUnknown(data['uci']!, _uciMeta),
      );
    } else if (isInserting) {
      context.missing(_uciMeta);
    }
    if (data.containsKey('san')) {
      context.handle(
        _sanMeta,
        san.isAcceptableOrUnknown(data['san']!, _sanMeta),
      );
    } else if (isInserting) {
      context.missing(_sanMeta);
    }
    if (data.containsKey('fen_after')) {
      context.handle(
        _fenAfterMeta,
        fenAfter.isAcceptableOrUnknown(data['fen_after']!, _fenAfterMeta),
      );
    } else if (isInserting) {
      context.missing(_fenAfterMeta);
    }
    if (data.containsKey('actor')) {
      context.handle(
        _actorMeta,
        actor.isAcceptableOrUnknown(data['actor']!, _actorMeta),
      );
    } else if (isInserting) {
      context.missing(_actorMeta);
    }
    if (data.containsKey('played_at_utc')) {
      context.handle(
        _playedAtUtcMeta,
        playedAtUtc.isAcceptableOrUnknown(
          data['played_at_utc']!,
          _playedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_playedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gameId, ply};
  @override
  GameMoveRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameMoveRow(
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_id'],
      )!,
      ply: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ply'],
      )!,
      uci: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uci'],
      )!,
      san: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}san'],
      )!,
      fenAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fen_after'],
      )!,
      actor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor'],
      )!,
      playedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}played_at_utc'],
      )!,
    );
  }

  @override
  $GameMovesTable createAlias(String alias) {
    return $GameMovesTable(attachedDatabase, alias);
  }
}

class GameMoveRow extends DataClass implements Insertable<GameMoveRow> {
  final String gameId;
  final int ply;
  final String uci;
  final String san;
  final String fenAfter;
  final String actor;
  final DateTime playedAtUtc;
  const GameMoveRow({
    required this.gameId,
    required this.ply,
    required this.uci,
    required this.san,
    required this.fenAfter,
    required this.actor,
    required this.playedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['game_id'] = Variable<String>(gameId);
    map['ply'] = Variable<int>(ply);
    map['uci'] = Variable<String>(uci);
    map['san'] = Variable<String>(san);
    map['fen_after'] = Variable<String>(fenAfter);
    map['actor'] = Variable<String>(actor);
    map['played_at_utc'] = Variable<DateTime>(playedAtUtc);
    return map;
  }

  GameMovesCompanion toCompanion(bool nullToAbsent) {
    return GameMovesCompanion(
      gameId: Value(gameId),
      ply: Value(ply),
      uci: Value(uci),
      san: Value(san),
      fenAfter: Value(fenAfter),
      actor: Value(actor),
      playedAtUtc: Value(playedAtUtc),
    );
  }

  factory GameMoveRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameMoveRow(
      gameId: serializer.fromJson<String>(json['gameId']),
      ply: serializer.fromJson<int>(json['ply']),
      uci: serializer.fromJson<String>(json['uci']),
      san: serializer.fromJson<String>(json['san']),
      fenAfter: serializer.fromJson<String>(json['fenAfter']),
      actor: serializer.fromJson<String>(json['actor']),
      playedAtUtc: serializer.fromJson<DateTime>(json['playedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gameId': serializer.toJson<String>(gameId),
      'ply': serializer.toJson<int>(ply),
      'uci': serializer.toJson<String>(uci),
      'san': serializer.toJson<String>(san),
      'fenAfter': serializer.toJson<String>(fenAfter),
      'actor': serializer.toJson<String>(actor),
      'playedAtUtc': serializer.toJson<DateTime>(playedAtUtc),
    };
  }

  GameMoveRow copyWith({
    String? gameId,
    int? ply,
    String? uci,
    String? san,
    String? fenAfter,
    String? actor,
    DateTime? playedAtUtc,
  }) => GameMoveRow(
    gameId: gameId ?? this.gameId,
    ply: ply ?? this.ply,
    uci: uci ?? this.uci,
    san: san ?? this.san,
    fenAfter: fenAfter ?? this.fenAfter,
    actor: actor ?? this.actor,
    playedAtUtc: playedAtUtc ?? this.playedAtUtc,
  );
  GameMoveRow copyWithCompanion(GameMovesCompanion data) {
    return GameMoveRow(
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      ply: data.ply.present ? data.ply.value : this.ply,
      uci: data.uci.present ? data.uci.value : this.uci,
      san: data.san.present ? data.san.value : this.san,
      fenAfter: data.fenAfter.present ? data.fenAfter.value : this.fenAfter,
      actor: data.actor.present ? data.actor.value : this.actor,
      playedAtUtc: data.playedAtUtc.present
          ? data.playedAtUtc.value
          : this.playedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameMoveRow(')
          ..write('gameId: $gameId, ')
          ..write('ply: $ply, ')
          ..write('uci: $uci, ')
          ..write('san: $san, ')
          ..write('fenAfter: $fenAfter, ')
          ..write('actor: $actor, ')
          ..write('playedAtUtc: $playedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(gameId, ply, uci, san, fenAfter, actor, playedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameMoveRow &&
          other.gameId == this.gameId &&
          other.ply == this.ply &&
          other.uci == this.uci &&
          other.san == this.san &&
          other.fenAfter == this.fenAfter &&
          other.actor == this.actor &&
          other.playedAtUtc == this.playedAtUtc);
}

class GameMovesCompanion extends UpdateCompanion<GameMoveRow> {
  final Value<String> gameId;
  final Value<int> ply;
  final Value<String> uci;
  final Value<String> san;
  final Value<String> fenAfter;
  final Value<String> actor;
  final Value<DateTime> playedAtUtc;
  final Value<int> rowid;
  const GameMovesCompanion({
    this.gameId = const Value.absent(),
    this.ply = const Value.absent(),
    this.uci = const Value.absent(),
    this.san = const Value.absent(),
    this.fenAfter = const Value.absent(),
    this.actor = const Value.absent(),
    this.playedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GameMovesCompanion.insert({
    required String gameId,
    required int ply,
    required String uci,
    required String san,
    required String fenAfter,
    required String actor,
    required DateTime playedAtUtc,
    this.rowid = const Value.absent(),
  }) : gameId = Value(gameId),
       ply = Value(ply),
       uci = Value(uci),
       san = Value(san),
       fenAfter = Value(fenAfter),
       actor = Value(actor),
       playedAtUtc = Value(playedAtUtc);
  static Insertable<GameMoveRow> custom({
    Expression<String>? gameId,
    Expression<int>? ply,
    Expression<String>? uci,
    Expression<String>? san,
    Expression<String>? fenAfter,
    Expression<String>? actor,
    Expression<DateTime>? playedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (gameId != null) 'game_id': gameId,
      if (ply != null) 'ply': ply,
      if (uci != null) 'uci': uci,
      if (san != null) 'san': san,
      if (fenAfter != null) 'fen_after': fenAfter,
      if (actor != null) 'actor': actor,
      if (playedAtUtc != null) 'played_at_utc': playedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GameMovesCompanion copyWith({
    Value<String>? gameId,
    Value<int>? ply,
    Value<String>? uci,
    Value<String>? san,
    Value<String>? fenAfter,
    Value<String>? actor,
    Value<DateTime>? playedAtUtc,
    Value<int>? rowid,
  }) {
    return GameMovesCompanion(
      gameId: gameId ?? this.gameId,
      ply: ply ?? this.ply,
      uci: uci ?? this.uci,
      san: san ?? this.san,
      fenAfter: fenAfter ?? this.fenAfter,
      actor: actor ?? this.actor,
      playedAtUtc: playedAtUtc ?? this.playedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gameId.present) {
      map['game_id'] = Variable<String>(gameId.value);
    }
    if (ply.present) {
      map['ply'] = Variable<int>(ply.value);
    }
    if (uci.present) {
      map['uci'] = Variable<String>(uci.value);
    }
    if (san.present) {
      map['san'] = Variable<String>(san.value);
    }
    if (fenAfter.present) {
      map['fen_after'] = Variable<String>(fenAfter.value);
    }
    if (actor.present) {
      map['actor'] = Variable<String>(actor.value);
    }
    if (playedAtUtc.present) {
      map['played_at_utc'] = Variable<DateTime>(playedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameMovesCompanion(')
          ..write('gameId: $gameId, ')
          ..write('ply: $ply, ')
          ..write('uci: $uci, ')
          ..write('san: $san, ')
          ..write('fenAfter: $fenAfter, ')
          ..write('actor: $actor, ')
          ..write('playedAtUtc: $playedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DifficultyProgressTable extends DifficultyProgress
    with TableInfo<$DifficultyProgressTable, DifficultyProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DifficultyProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _validWinsMeta = const VerificationMeta(
    'validWins',
  );
  @override
  late final GeneratedColumn<int> validWins = GeneratedColumn<int>(
    'valid_wins',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _windowGamesMeta = const VerificationMeta(
    'windowGames',
  );
  @override
  late final GeneratedColumn<int> windowGames = GeneratedColumn<int>(
    'window_games',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _unlockedMeta = const VerificationMeta(
    'unlocked',
  );
  @override
  late final GeneratedColumn<bool> unlocked = GeneratedColumn<bool>(
    'unlocked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("unlocked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    rating,
    validWins,
    windowGames,
    unlocked,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'difficulty_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<DifficultyProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('valid_wins')) {
      context.handle(
        _validWinsMeta,
        validWins.isAcceptableOrUnknown(data['valid_wins']!, _validWinsMeta),
      );
    }
    if (data.containsKey('window_games')) {
      context.handle(
        _windowGamesMeta,
        windowGames.isAcceptableOrUnknown(
          data['window_games']!,
          _windowGamesMeta,
        ),
      );
    }
    if (data.containsKey('unlocked')) {
      context.handle(
        _unlockedMeta,
        unlocked.isAcceptableOrUnknown(data['unlocked']!, _unlockedMeta),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rating};
  @override
  DifficultyProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DifficultyProgressRow(
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      )!,
      validWins: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}valid_wins'],
      )!,
      windowGames: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}window_games'],
      )!,
      unlocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}unlocked'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $DifficultyProgressTable createAlias(String alias) {
    return $DifficultyProgressTable(attachedDatabase, alias);
  }
}

class DifficultyProgressRow extends DataClass
    implements Insertable<DifficultyProgressRow> {
  final int rating;
  final int validWins;
  final int windowGames;
  final bool unlocked;
  final DateTime updatedAtUtc;
  const DifficultyProgressRow({
    required this.rating,
    required this.validWins,
    required this.windowGames,
    required this.unlocked,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['rating'] = Variable<int>(rating);
    map['valid_wins'] = Variable<int>(validWins);
    map['window_games'] = Variable<int>(windowGames);
    map['unlocked'] = Variable<bool>(unlocked);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  DifficultyProgressCompanion toCompanion(bool nullToAbsent) {
    return DifficultyProgressCompanion(
      rating: Value(rating),
      validWins: Value(validWins),
      windowGames: Value(windowGames),
      unlocked: Value(unlocked),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory DifficultyProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DifficultyProgressRow(
      rating: serializer.fromJson<int>(json['rating']),
      validWins: serializer.fromJson<int>(json['validWins']),
      windowGames: serializer.fromJson<int>(json['windowGames']),
      unlocked: serializer.fromJson<bool>(json['unlocked']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rating': serializer.toJson<int>(rating),
      'validWins': serializer.toJson<int>(validWins),
      'windowGames': serializer.toJson<int>(windowGames),
      'unlocked': serializer.toJson<bool>(unlocked),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  DifficultyProgressRow copyWith({
    int? rating,
    int? validWins,
    int? windowGames,
    bool? unlocked,
    DateTime? updatedAtUtc,
  }) => DifficultyProgressRow(
    rating: rating ?? this.rating,
    validWins: validWins ?? this.validWins,
    windowGames: windowGames ?? this.windowGames,
    unlocked: unlocked ?? this.unlocked,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  DifficultyProgressRow copyWithCompanion(DifficultyProgressCompanion data) {
    return DifficultyProgressRow(
      rating: data.rating.present ? data.rating.value : this.rating,
      validWins: data.validWins.present ? data.validWins.value : this.validWins,
      windowGames: data.windowGames.present
          ? data.windowGames.value
          : this.windowGames,
      unlocked: data.unlocked.present ? data.unlocked.value : this.unlocked,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DifficultyProgressRow(')
          ..write('rating: $rating, ')
          ..write('validWins: $validWins, ')
          ..write('windowGames: $windowGames, ')
          ..write('unlocked: $unlocked, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(rating, validWins, windowGames, unlocked, updatedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DifficultyProgressRow &&
          other.rating == this.rating &&
          other.validWins == this.validWins &&
          other.windowGames == this.windowGames &&
          other.unlocked == this.unlocked &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class DifficultyProgressCompanion
    extends UpdateCompanion<DifficultyProgressRow> {
  final Value<int> rating;
  final Value<int> validWins;
  final Value<int> windowGames;
  final Value<bool> unlocked;
  final Value<DateTime> updatedAtUtc;
  const DifficultyProgressCompanion({
    this.rating = const Value.absent(),
    this.validWins = const Value.absent(),
    this.windowGames = const Value.absent(),
    this.unlocked = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
  });
  DifficultyProgressCompanion.insert({
    this.rating = const Value.absent(),
    this.validWins = const Value.absent(),
    this.windowGames = const Value.absent(),
    this.unlocked = const Value.absent(),
    required DateTime updatedAtUtc,
  }) : updatedAtUtc = Value(updatedAtUtc);
  static Insertable<DifficultyProgressRow> custom({
    Expression<int>? rating,
    Expression<int>? validWins,
    Expression<int>? windowGames,
    Expression<bool>? unlocked,
    Expression<DateTime>? updatedAtUtc,
  }) {
    return RawValuesInsertable({
      if (rating != null) 'rating': rating,
      if (validWins != null) 'valid_wins': validWins,
      if (windowGames != null) 'window_games': windowGames,
      if (unlocked != null) 'unlocked': unlocked,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
    });
  }

  DifficultyProgressCompanion copyWith({
    Value<int>? rating,
    Value<int>? validWins,
    Value<int>? windowGames,
    Value<bool>? unlocked,
    Value<DateTime>? updatedAtUtc,
  }) {
    return DifficultyProgressCompanion(
      rating: rating ?? this.rating,
      validWins: validWins ?? this.validWins,
      windowGames: windowGames ?? this.windowGames,
      unlocked: unlocked ?? this.unlocked,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (validWins.present) {
      map['valid_wins'] = Variable<int>(validWins.value);
    }
    if (windowGames.present) {
      map['window_games'] = Variable<int>(windowGames.value);
    }
    if (unlocked.present) {
      map['unlocked'] = Variable<bool>(unlocked.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DifficultyProgressCompanion(')
          ..write('rating: $rating, ')
          ..write('validWins: $validWins, ')
          ..write('windowGames: $windowGames, ')
          ..write('unlocked: $unlocked, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }
}

class $RatingHistoryTable extends RatingHistory
    with TableInfo<$RatingHistoryTable, RatingHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RatingHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<String> gameId = GeneratedColumn<String>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES games (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _recordedAtUtcMeta = const VerificationMeta(
    'recordedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAtUtc =
      GeneratedColumn<DateTime>(
        'recorded_at_utc',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, gameId, recordedAtUtc, rating];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rating_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<RatingHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    if (data.containsKey('recorded_at_utc')) {
      context.handle(
        _recordedAtUtcMeta,
        recordedAtUtc.isAcceptableOrUnknown(
          data['recorded_at_utc']!,
          _recordedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordedAtUtcMeta);
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    } else if (isInserting) {
      context.missing(_ratingMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RatingHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RatingHistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_id'],
      )!,
      recordedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at_utc'],
      )!,
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rating'],
      )!,
    );
  }

  @override
  $RatingHistoryTable createAlias(String alias) {
    return $RatingHistoryTable(attachedDatabase, alias);
  }
}

class RatingHistoryRow extends DataClass
    implements Insertable<RatingHistoryRow> {
  final String id;
  final String gameId;
  final DateTime recordedAtUtc;
  final double rating;
  const RatingHistoryRow({
    required this.id,
    required this.gameId,
    required this.recordedAtUtc,
    required this.rating,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['game_id'] = Variable<String>(gameId);
    map['recorded_at_utc'] = Variable<DateTime>(recordedAtUtc);
    map['rating'] = Variable<double>(rating);
    return map;
  }

  RatingHistoryCompanion toCompanion(bool nullToAbsent) {
    return RatingHistoryCompanion(
      id: Value(id),
      gameId: Value(gameId),
      recordedAtUtc: Value(recordedAtUtc),
      rating: Value(rating),
    );
  }

  factory RatingHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RatingHistoryRow(
      id: serializer.fromJson<String>(json['id']),
      gameId: serializer.fromJson<String>(json['gameId']),
      recordedAtUtc: serializer.fromJson<DateTime>(json['recordedAtUtc']),
      rating: serializer.fromJson<double>(json['rating']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'gameId': serializer.toJson<String>(gameId),
      'recordedAtUtc': serializer.toJson<DateTime>(recordedAtUtc),
      'rating': serializer.toJson<double>(rating),
    };
  }

  RatingHistoryRow copyWith({
    String? id,
    String? gameId,
    DateTime? recordedAtUtc,
    double? rating,
  }) => RatingHistoryRow(
    id: id ?? this.id,
    gameId: gameId ?? this.gameId,
    recordedAtUtc: recordedAtUtc ?? this.recordedAtUtc,
    rating: rating ?? this.rating,
  );
  RatingHistoryRow copyWithCompanion(RatingHistoryCompanion data) {
    return RatingHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      recordedAtUtc: data.recordedAtUtc.present
          ? data.recordedAtUtc.value
          : this.recordedAtUtc,
      rating: data.rating.present ? data.rating.value : this.rating,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RatingHistoryRow(')
          ..write('id: $id, ')
          ..write('gameId: $gameId, ')
          ..write('recordedAtUtc: $recordedAtUtc, ')
          ..write('rating: $rating')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, gameId, recordedAtUtc, rating);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RatingHistoryRow &&
          other.id == this.id &&
          other.gameId == this.gameId &&
          other.recordedAtUtc == this.recordedAtUtc &&
          other.rating == this.rating);
}

class RatingHistoryCompanion extends UpdateCompanion<RatingHistoryRow> {
  final Value<String> id;
  final Value<String> gameId;
  final Value<DateTime> recordedAtUtc;
  final Value<double> rating;
  final Value<int> rowid;
  const RatingHistoryCompanion({
    this.id = const Value.absent(),
    this.gameId = const Value.absent(),
    this.recordedAtUtc = const Value.absent(),
    this.rating = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RatingHistoryCompanion.insert({
    required String id,
    required String gameId,
    required DateTime recordedAtUtc,
    required double rating,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       gameId = Value(gameId),
       recordedAtUtc = Value(recordedAtUtc),
       rating = Value(rating);
  static Insertable<RatingHistoryRow> custom({
    Expression<String>? id,
    Expression<String>? gameId,
    Expression<DateTime>? recordedAtUtc,
    Expression<double>? rating,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (gameId != null) 'game_id': gameId,
      if (recordedAtUtc != null) 'recorded_at_utc': recordedAtUtc,
      if (rating != null) 'rating': rating,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RatingHistoryCompanion copyWith({
    Value<String>? id,
    Value<String>? gameId,
    Value<DateTime>? recordedAtUtc,
    Value<double>? rating,
    Value<int>? rowid,
  }) {
    return RatingHistoryCompanion(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      recordedAtUtc: recordedAtUtc ?? this.recordedAtUtc,
      rating: rating ?? this.rating,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<String>(gameId.value);
    }
    if (recordedAtUtc.present) {
      map['recorded_at_utc'] = Variable<DateTime>(recordedAtUtc.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RatingHistoryCompanion(')
          ..write('id: $id, ')
          ..write('gameId: $gameId, ')
          ..write('recordedAtUtc: $recordedAtUtc, ')
          ..write('rating: $rating, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _pieceSetMeta = const VerificationMeta(
    'pieceSet',
  );
  @override
  late final GeneratedColumn<String> pieceSet = GeneratedColumn<String>(
    'piece_set',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('classic'),
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  static const VerificationMeta _defaultClockEnabledMeta =
      const VerificationMeta('defaultClockEnabled');
  @override
  late final GeneratedColumn<bool> defaultClockEnabled = GeneratedColumn<bool>(
    'default_clock_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("default_clock_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _defaultTimeMinutesMeta =
      const VerificationMeta('defaultTimeMinutes');
  @override
  late final GeneratedColumn<int> defaultTimeMinutes = GeneratedColumn<int>(
    'default_time_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    pieceSet,
    themeMode,
    defaultClockEnabled,
    defaultTimeMinutes,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('piece_set')) {
      context.handle(
        _pieceSetMeta,
        pieceSet.isAcceptableOrUnknown(data['piece_set']!, _pieceSetMeta),
      );
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('default_clock_enabled')) {
      context.handle(
        _defaultClockEnabledMeta,
        defaultClockEnabled.isAcceptableOrUnknown(
          data['default_clock_enabled']!,
          _defaultClockEnabledMeta,
        ),
      );
    }
    if (data.containsKey('default_time_minutes')) {
      context.handle(
        _defaultTimeMinutesMeta,
        defaultTimeMinutes.isAcceptableOrUnknown(
          data['default_time_minutes']!,
          _defaultTimeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      pieceSet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}piece_set'],
      )!,
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      defaultClockEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}default_clock_enabled'],
      )!,
      defaultTimeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_time_minutes'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingsRow extends DataClass implements Insertable<AppSettingsRow> {
  final int id;
  final String pieceSet;
  final String themeMode;
  final bool defaultClockEnabled;
  final int defaultTimeMinutes;
  final DateTime updatedAtUtc;
  const AppSettingsRow({
    required this.id,
    required this.pieceSet,
    required this.themeMode,
    required this.defaultClockEnabled,
    required this.defaultTimeMinutes,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['piece_set'] = Variable<String>(pieceSet);
    map['theme_mode'] = Variable<String>(themeMode);
    map['default_clock_enabled'] = Variable<bool>(defaultClockEnabled);
    map['default_time_minutes'] = Variable<int>(defaultTimeMinutes);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      pieceSet: Value(pieceSet),
      themeMode: Value(themeMode),
      defaultClockEnabled: Value(defaultClockEnabled),
      defaultTimeMinutes: Value(defaultTimeMinutes),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory AppSettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingsRow(
      id: serializer.fromJson<int>(json['id']),
      pieceSet: serializer.fromJson<String>(json['pieceSet']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      defaultClockEnabled: serializer.fromJson<bool>(
        json['defaultClockEnabled'],
      ),
      defaultTimeMinutes: serializer.fromJson<int>(json['defaultTimeMinutes']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'pieceSet': serializer.toJson<String>(pieceSet),
      'themeMode': serializer.toJson<String>(themeMode),
      'defaultClockEnabled': serializer.toJson<bool>(defaultClockEnabled),
      'defaultTimeMinutes': serializer.toJson<int>(defaultTimeMinutes),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  AppSettingsRow copyWith({
    int? id,
    String? pieceSet,
    String? themeMode,
    bool? defaultClockEnabled,
    int? defaultTimeMinutes,
    DateTime? updatedAtUtc,
  }) => AppSettingsRow(
    id: id ?? this.id,
    pieceSet: pieceSet ?? this.pieceSet,
    themeMode: themeMode ?? this.themeMode,
    defaultClockEnabled: defaultClockEnabled ?? this.defaultClockEnabled,
    defaultTimeMinutes: defaultTimeMinutes ?? this.defaultTimeMinutes,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  AppSettingsRow copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingsRow(
      id: data.id.present ? data.id.value : this.id,
      pieceSet: data.pieceSet.present ? data.pieceSet.value : this.pieceSet,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      defaultClockEnabled: data.defaultClockEnabled.present
          ? data.defaultClockEnabled.value
          : this.defaultClockEnabled,
      defaultTimeMinutes: data.defaultTimeMinutes.present
          ? data.defaultTimeMinutes.value
          : this.defaultTimeMinutes,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsRow(')
          ..write('id: $id, ')
          ..write('pieceSet: $pieceSet, ')
          ..write('themeMode: $themeMode, ')
          ..write('defaultClockEnabled: $defaultClockEnabled, ')
          ..write('defaultTimeMinutes: $defaultTimeMinutes, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    pieceSet,
    themeMode,
    defaultClockEnabled,
    defaultTimeMinutes,
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingsRow &&
          other.id == this.id &&
          other.pieceSet == this.pieceSet &&
          other.themeMode == this.themeMode &&
          other.defaultClockEnabled == this.defaultClockEnabled &&
          other.defaultTimeMinutes == this.defaultTimeMinutes &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingsRow> {
  final Value<int> id;
  final Value<String> pieceSet;
  final Value<String> themeMode;
  final Value<bool> defaultClockEnabled;
  final Value<int> defaultTimeMinutes;
  final Value<DateTime> updatedAtUtc;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.pieceSet = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.defaultClockEnabled = const Value.absent(),
    this.defaultTimeMinutes = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.pieceSet = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.defaultClockEnabled = const Value.absent(),
    this.defaultTimeMinutes = const Value.absent(),
    required DateTime updatedAtUtc,
  }) : updatedAtUtc = Value(updatedAtUtc);
  static Insertable<AppSettingsRow> custom({
    Expression<int>? id,
    Expression<String>? pieceSet,
    Expression<String>? themeMode,
    Expression<bool>? defaultClockEnabled,
    Expression<int>? defaultTimeMinutes,
    Expression<DateTime>? updatedAtUtc,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pieceSet != null) 'piece_set': pieceSet,
      if (themeMode != null) 'theme_mode': themeMode,
      if (defaultClockEnabled != null)
        'default_clock_enabled': defaultClockEnabled,
      if (defaultTimeMinutes != null)
        'default_time_minutes': defaultTimeMinutes,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? pieceSet,
    Value<String>? themeMode,
    Value<bool>? defaultClockEnabled,
    Value<int>? defaultTimeMinutes,
    Value<DateTime>? updatedAtUtc,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      pieceSet: pieceSet ?? this.pieceSet,
      themeMode: themeMode ?? this.themeMode,
      defaultClockEnabled: defaultClockEnabled ?? this.defaultClockEnabled,
      defaultTimeMinutes: defaultTimeMinutes ?? this.defaultTimeMinutes,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (pieceSet.present) {
      map['piece_set'] = Variable<String>(pieceSet.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (defaultClockEnabled.present) {
      map['default_clock_enabled'] = Variable<bool>(defaultClockEnabled.value);
    }
    if (defaultTimeMinutes.present) {
      map['default_time_minutes'] = Variable<int>(defaultTimeMinutes.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('pieceSet: $pieceSet, ')
          ..write('themeMode: $themeMode, ')
          ..write('defaultClockEnabled: $defaultClockEnabled, ')
          ..write('defaultTimeMinutes: $defaultTimeMinutes, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $GamesTable games = $GamesTable(this);
  late final $GameMovesTable gameMoves = $GameMovesTable(this);
  late final $DifficultyProgressTable difficultyProgress =
      $DifficultyProgressTable(this);
  late final $RatingHistoryTable ratingHistory = $RatingHistoryTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final Index gamesStatusModified = Index(
    'games_status_modified',
    'CREATE INDEX games_status_modified ON games (status, last_modified_at_utc)',
  );
  late final Index gameMovesGame = Index(
    'game_moves_game',
    'CREATE INDEX game_moves_game ON game_moves (game_id, ply)',
  );
  late final Index ratingHistoryRecorded = Index(
    'rating_history_recorded',
    'CREATE INDEX rating_history_recorded ON rating_history (recorded_at_utc)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    games,
    gameMoves,
    difficultyProgress,
    ratingHistory,
    appSettings,
    gamesStatusModified,
    gameMovesGame,
    ratingHistoryRecorded,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'games',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('game_moves', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'games',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('rating_history', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$GamesTableCreateCompanionBuilder =
    GamesCompanion Function({
      required String id,
      required DateTime startedAtUtc,
      Value<DateTime?> endedAtUtc,
      required DateTime lastModifiedAtUtc,
      Value<String> status,
      Value<int?> levelRating,
      Value<String?> playerSide,
      Value<String> result,
      Value<String?> termination,
      Value<bool> evaluated,
      Value<bool> campaignMode,
      required String initialFen,
      required String currentFen,
      Value<String?> pgn,
      Value<bool> clockEnabled,
      Value<int?> initialTimeMs,
      Value<int?> whiteTimeMs,
      Value<int?> blackTimeMs,
      Value<int> rowid,
    });
typedef $$GamesTableUpdateCompanionBuilder =
    GamesCompanion Function({
      Value<String> id,
      Value<DateTime> startedAtUtc,
      Value<DateTime?> endedAtUtc,
      Value<DateTime> lastModifiedAtUtc,
      Value<String> status,
      Value<int?> levelRating,
      Value<String?> playerSide,
      Value<String> result,
      Value<String?> termination,
      Value<bool> evaluated,
      Value<bool> campaignMode,
      Value<String> initialFen,
      Value<String> currentFen,
      Value<String?> pgn,
      Value<bool> clockEnabled,
      Value<int?> initialTimeMs,
      Value<int?> whiteTimeMs,
      Value<int?> blackTimeMs,
      Value<int> rowid,
    });

final class $$GamesTableReferences
    extends BaseReferences<_$AppDatabase, $GamesTable, GameRow> {
  $$GamesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$GameMovesTable, List<GameMoveRow>>
  _gameMovesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.gameMoves,
    aliasName: 'games__id__game_moves__game_id',
  );

  $$GameMovesTableProcessedTableManager get gameMovesRefs {
    final manager = $$GameMovesTableTableManager(
      $_db,
      $_db.gameMoves,
    ).filter((f) => f.gameId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_gameMovesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RatingHistoryTable, List<RatingHistoryRow>>
  _ratingHistoryRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.ratingHistory,
    aliasName: 'games__id__rating_history__game_id',
  );

  $$RatingHistoryTableProcessedTableManager get ratingHistoryRefs {
    final manager = $$RatingHistoryTableTableManager(
      $_db,
      $_db.ratingHistory,
    ).filter((f) => f.gameId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_ratingHistoryRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GamesTableFilterComposer extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAtUtc => $composableBuilder(
    column: $table.endedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastModifiedAtUtc => $composableBuilder(
    column: $table.lastModifiedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get levelRating => $composableBuilder(
    column: $table.levelRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playerSide => $composableBuilder(
    column: $table.playerSide,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get termination => $composableBuilder(
    column: $table.termination,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get evaluated => $composableBuilder(
    column: $table.evaluated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get campaignMode => $composableBuilder(
    column: $table.campaignMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get initialFen => $composableBuilder(
    column: $table.initialFen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentFen => $composableBuilder(
    column: $table.currentFen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pgn => $composableBuilder(
    column: $table.pgn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get clockEnabled => $composableBuilder(
    column: $table.clockEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get initialTimeMs => $composableBuilder(
    column: $table.initialTimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get whiteTimeMs => $composableBuilder(
    column: $table.whiteTimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blackTimeMs => $composableBuilder(
    column: $table.blackTimeMs,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> gameMovesRefs(
    Expression<bool> Function($$GameMovesTableFilterComposer f) f,
  ) {
    final $$GameMovesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gameMoves,
      getReferencedColumn: (t) => t.gameId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GameMovesTableFilterComposer(
            $db: $db,
            $table: $db.gameMoves,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> ratingHistoryRefs(
    Expression<bool> Function($$RatingHistoryTableFilterComposer f) f,
  ) {
    final $$RatingHistoryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ratingHistory,
      getReferencedColumn: (t) => t.gameId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RatingHistoryTableFilterComposer(
            $db: $db,
            $table: $db.ratingHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GamesTableOrderingComposer
    extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAtUtc => $composableBuilder(
    column: $table.endedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastModifiedAtUtc => $composableBuilder(
    column: $table.lastModifiedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get levelRating => $composableBuilder(
    column: $table.levelRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playerSide => $composableBuilder(
    column: $table.playerSide,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get termination => $composableBuilder(
    column: $table.termination,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get evaluated => $composableBuilder(
    column: $table.evaluated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get campaignMode => $composableBuilder(
    column: $table.campaignMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get initialFen => $composableBuilder(
    column: $table.initialFen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentFen => $composableBuilder(
    column: $table.currentFen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pgn => $composableBuilder(
    column: $table.pgn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get clockEnabled => $composableBuilder(
    column: $table.clockEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get initialTimeMs => $composableBuilder(
    column: $table.initialTimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get whiteTimeMs => $composableBuilder(
    column: $table.whiteTimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blackTimeMs => $composableBuilder(
    column: $table.blackTimeMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GamesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get endedAtUtc => $composableBuilder(
    column: $table.endedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastModifiedAtUtc => $composableBuilder(
    column: $table.lastModifiedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get levelRating => $composableBuilder(
    column: $table.levelRating,
    builder: (column) => column,
  );

  GeneratedColumn<String> get playerSide => $composableBuilder(
    column: $table.playerSide,
    builder: (column) => column,
  );

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get termination => $composableBuilder(
    column: $table.termination,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get evaluated =>
      $composableBuilder(column: $table.evaluated, builder: (column) => column);

  GeneratedColumn<bool> get campaignMode => $composableBuilder(
    column: $table.campaignMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get initialFen => $composableBuilder(
    column: $table.initialFen,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currentFen => $composableBuilder(
    column: $table.currentFen,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pgn =>
      $composableBuilder(column: $table.pgn, builder: (column) => column);

  GeneratedColumn<bool> get clockEnabled => $composableBuilder(
    column: $table.clockEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get initialTimeMs => $composableBuilder(
    column: $table.initialTimeMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get whiteTimeMs => $composableBuilder(
    column: $table.whiteTimeMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get blackTimeMs => $composableBuilder(
    column: $table.blackTimeMs,
    builder: (column) => column,
  );

  Expression<T> gameMovesRefs<T extends Object>(
    Expression<T> Function($$GameMovesTableAnnotationComposer a) f,
  ) {
    final $$GameMovesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gameMoves,
      getReferencedColumn: (t) => t.gameId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GameMovesTableAnnotationComposer(
            $db: $db,
            $table: $db.gameMoves,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> ratingHistoryRefs<T extends Object>(
    Expression<T> Function($$RatingHistoryTableAnnotationComposer a) f,
  ) {
    final $$RatingHistoryTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ratingHistory,
      getReferencedColumn: (t) => t.gameId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RatingHistoryTableAnnotationComposer(
            $db: $db,
            $table: $db.ratingHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GamesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GamesTable,
          GameRow,
          $$GamesTableFilterComposer,
          $$GamesTableOrderingComposer,
          $$GamesTableAnnotationComposer,
          $$GamesTableCreateCompanionBuilder,
          $$GamesTableUpdateCompanionBuilder,
          (GameRow, $$GamesTableReferences),
          GameRow,
          PrefetchHooks Function({bool gameMovesRefs, bool ratingHistoryRefs})
        > {
  $$GamesTableTableManager(_$AppDatabase db, $GamesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GamesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> startedAtUtc = const Value.absent(),
                Value<DateTime?> endedAtUtc = const Value.absent(),
                Value<DateTime> lastModifiedAtUtc = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> levelRating = const Value.absent(),
                Value<String?> playerSide = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<String?> termination = const Value.absent(),
                Value<bool> evaluated = const Value.absent(),
                Value<bool> campaignMode = const Value.absent(),
                Value<String> initialFen = const Value.absent(),
                Value<String> currentFen = const Value.absent(),
                Value<String?> pgn = const Value.absent(),
                Value<bool> clockEnabled = const Value.absent(),
                Value<int?> initialTimeMs = const Value.absent(),
                Value<int?> whiteTimeMs = const Value.absent(),
                Value<int?> blackTimeMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GamesCompanion(
                id: id,
                startedAtUtc: startedAtUtc,
                endedAtUtc: endedAtUtc,
                lastModifiedAtUtc: lastModifiedAtUtc,
                status: status,
                levelRating: levelRating,
                playerSide: playerSide,
                result: result,
                termination: termination,
                evaluated: evaluated,
                campaignMode: campaignMode,
                initialFen: initialFen,
                currentFen: currentFen,
                pgn: pgn,
                clockEnabled: clockEnabled,
                initialTimeMs: initialTimeMs,
                whiteTimeMs: whiteTimeMs,
                blackTimeMs: blackTimeMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime startedAtUtc,
                Value<DateTime?> endedAtUtc = const Value.absent(),
                required DateTime lastModifiedAtUtc,
                Value<String> status = const Value.absent(),
                Value<int?> levelRating = const Value.absent(),
                Value<String?> playerSide = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<String?> termination = const Value.absent(),
                Value<bool> evaluated = const Value.absent(),
                Value<bool> campaignMode = const Value.absent(),
                required String initialFen,
                required String currentFen,
                Value<String?> pgn = const Value.absent(),
                Value<bool> clockEnabled = const Value.absent(),
                Value<int?> initialTimeMs = const Value.absent(),
                Value<int?> whiteTimeMs = const Value.absent(),
                Value<int?> blackTimeMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GamesCompanion.insert(
                id: id,
                startedAtUtc: startedAtUtc,
                endedAtUtc: endedAtUtc,
                lastModifiedAtUtc: lastModifiedAtUtc,
                status: status,
                levelRating: levelRating,
                playerSide: playerSide,
                result: result,
                termination: termination,
                evaluated: evaluated,
                campaignMode: campaignMode,
                initialFen: initialFen,
                currentFen: currentFen,
                pgn: pgn,
                clockEnabled: clockEnabled,
                initialTimeMs: initialTimeMs,
                whiteTimeMs: whiteTimeMs,
                blackTimeMs: blackTimeMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$GamesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({gameMovesRefs = false, ratingHistoryRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (gameMovesRefs) db.gameMoves,
                    if (ratingHistoryRefs) db.ratingHistory,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (gameMovesRefs)
                        await $_getPrefetchedData<
                          GameRow,
                          $GamesTable,
                          GameMoveRow
                        >(
                          currentTable: table,
                          referencedTable: $$GamesTableReferences
                              ._gameMovesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GamesTableReferences(
                                db,
                                table,
                                p0,
                              ).gameMovesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.gameId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (ratingHistoryRefs)
                        await $_getPrefetchedData<
                          GameRow,
                          $GamesTable,
                          RatingHistoryRow
                        >(
                          currentTable: table,
                          referencedTable: $$GamesTableReferences
                              ._ratingHistoryRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GamesTableReferences(
                                db,
                                table,
                                p0,
                              ).ratingHistoryRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.gameId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$GamesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GamesTable,
      GameRow,
      $$GamesTableFilterComposer,
      $$GamesTableOrderingComposer,
      $$GamesTableAnnotationComposer,
      $$GamesTableCreateCompanionBuilder,
      $$GamesTableUpdateCompanionBuilder,
      (GameRow, $$GamesTableReferences),
      GameRow,
      PrefetchHooks Function({bool gameMovesRefs, bool ratingHistoryRefs})
    >;
typedef $$GameMovesTableCreateCompanionBuilder =
    GameMovesCompanion Function({
      required String gameId,
      required int ply,
      required String uci,
      required String san,
      required String fenAfter,
      required String actor,
      required DateTime playedAtUtc,
      Value<int> rowid,
    });
typedef $$GameMovesTableUpdateCompanionBuilder =
    GameMovesCompanion Function({
      Value<String> gameId,
      Value<int> ply,
      Value<String> uci,
      Value<String> san,
      Value<String> fenAfter,
      Value<String> actor,
      Value<DateTime> playedAtUtc,
      Value<int> rowid,
    });

final class $$GameMovesTableReferences
    extends BaseReferences<_$AppDatabase, $GameMovesTable, GameMoveRow> {
  $$GameMovesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GamesTable _gameIdTable(_$AppDatabase db) =>
      db.games.createAlias('game_moves__game_id__games__id');

  $$GamesTableProcessedTableManager get gameId {
    final $_column = $_itemColumn<String>('game_id')!;

    final manager = $$GamesTableTableManager(
      $_db,
      $_db.games,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_gameIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GameMovesTableFilterComposer
    extends Composer<_$AppDatabase, $GameMovesTable> {
  $$GameMovesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get ply => $composableBuilder(
    column: $table.ply,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uci => $composableBuilder(
    column: $table.uci,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get san => $composableBuilder(
    column: $table.san,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fenAfter => $composableBuilder(
    column: $table.fenAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actor => $composableBuilder(
    column: $table.actor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get playedAtUtc => $composableBuilder(
    column: $table.playedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$GamesTableFilterComposer get gameId {
    final $$GamesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableFilterComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GameMovesTableOrderingComposer
    extends Composer<_$AppDatabase, $GameMovesTable> {
  $$GameMovesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get ply => $composableBuilder(
    column: $table.ply,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uci => $composableBuilder(
    column: $table.uci,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get san => $composableBuilder(
    column: $table.san,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fenAfter => $composableBuilder(
    column: $table.fenAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actor => $composableBuilder(
    column: $table.actor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get playedAtUtc => $composableBuilder(
    column: $table.playedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$GamesTableOrderingComposer get gameId {
    final $$GamesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableOrderingComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GameMovesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GameMovesTable> {
  $$GameMovesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get ply =>
      $composableBuilder(column: $table.ply, builder: (column) => column);

  GeneratedColumn<String> get uci =>
      $composableBuilder(column: $table.uci, builder: (column) => column);

  GeneratedColumn<String> get san =>
      $composableBuilder(column: $table.san, builder: (column) => column);

  GeneratedColumn<String> get fenAfter =>
      $composableBuilder(column: $table.fenAfter, builder: (column) => column);

  GeneratedColumn<String> get actor =>
      $composableBuilder(column: $table.actor, builder: (column) => column);

  GeneratedColumn<DateTime> get playedAtUtc => $composableBuilder(
    column: $table.playedAtUtc,
    builder: (column) => column,
  );

  $$GamesTableAnnotationComposer get gameId {
    final $$GamesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableAnnotationComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GameMovesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GameMovesTable,
          GameMoveRow,
          $$GameMovesTableFilterComposer,
          $$GameMovesTableOrderingComposer,
          $$GameMovesTableAnnotationComposer,
          $$GameMovesTableCreateCompanionBuilder,
          $$GameMovesTableUpdateCompanionBuilder,
          (GameMoveRow, $$GameMovesTableReferences),
          GameMoveRow,
          PrefetchHooks Function({bool gameId})
        > {
  $$GameMovesTableTableManager(_$AppDatabase db, $GameMovesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GameMovesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GameMovesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GameMovesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> gameId = const Value.absent(),
                Value<int> ply = const Value.absent(),
                Value<String> uci = const Value.absent(),
                Value<String> san = const Value.absent(),
                Value<String> fenAfter = const Value.absent(),
                Value<String> actor = const Value.absent(),
                Value<DateTime> playedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GameMovesCompanion(
                gameId: gameId,
                ply: ply,
                uci: uci,
                san: san,
                fenAfter: fenAfter,
                actor: actor,
                playedAtUtc: playedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String gameId,
                required int ply,
                required String uci,
                required String san,
                required String fenAfter,
                required String actor,
                required DateTime playedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => GameMovesCompanion.insert(
                gameId: gameId,
                ply: ply,
                uci: uci,
                san: san,
                fenAfter: fenAfter,
                actor: actor,
                playedAtUtc: playedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GameMovesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({gameId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (gameId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.gameId,
                                referencedTable: $$GameMovesTableReferences
                                    ._gameIdTable(db),
                                referencedColumn: $$GameMovesTableReferences
                                    ._gameIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GameMovesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GameMovesTable,
      GameMoveRow,
      $$GameMovesTableFilterComposer,
      $$GameMovesTableOrderingComposer,
      $$GameMovesTableAnnotationComposer,
      $$GameMovesTableCreateCompanionBuilder,
      $$GameMovesTableUpdateCompanionBuilder,
      (GameMoveRow, $$GameMovesTableReferences),
      GameMoveRow,
      PrefetchHooks Function({bool gameId})
    >;
typedef $$DifficultyProgressTableCreateCompanionBuilder =
    DifficultyProgressCompanion Function({
      Value<int> rating,
      Value<int> validWins,
      Value<int> windowGames,
      Value<bool> unlocked,
      required DateTime updatedAtUtc,
    });
typedef $$DifficultyProgressTableUpdateCompanionBuilder =
    DifficultyProgressCompanion Function({
      Value<int> rating,
      Value<int> validWins,
      Value<int> windowGames,
      Value<bool> unlocked,
      Value<DateTime> updatedAtUtc,
    });

class $$DifficultyProgressTableFilterComposer
    extends Composer<_$AppDatabase, $DifficultyProgressTable> {
  $$DifficultyProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get validWins => $composableBuilder(
    column: $table.validWins,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get windowGames => $composableBuilder(
    column: $table.windowGames,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get unlocked => $composableBuilder(
    column: $table.unlocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DifficultyProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $DifficultyProgressTable> {
  $$DifficultyProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get validWins => $composableBuilder(
    column: $table.validWins,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get windowGames => $composableBuilder(
    column: $table.windowGames,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get unlocked => $composableBuilder(
    column: $table.unlocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DifficultyProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $DifficultyProgressTable> {
  $$DifficultyProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<int> get validWins =>
      $composableBuilder(column: $table.validWins, builder: (column) => column);

  GeneratedColumn<int> get windowGames => $composableBuilder(
    column: $table.windowGames,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get unlocked =>
      $composableBuilder(column: $table.unlocked, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );
}

class $$DifficultyProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DifficultyProgressTable,
          DifficultyProgressRow,
          $$DifficultyProgressTableFilterComposer,
          $$DifficultyProgressTableOrderingComposer,
          $$DifficultyProgressTableAnnotationComposer,
          $$DifficultyProgressTableCreateCompanionBuilder,
          $$DifficultyProgressTableUpdateCompanionBuilder,
          (
            DifficultyProgressRow,
            BaseReferences<
              _$AppDatabase,
              $DifficultyProgressTable,
              DifficultyProgressRow
            >,
          ),
          DifficultyProgressRow,
          PrefetchHooks Function()
        > {
  $$DifficultyProgressTableTableManager(
    _$AppDatabase db,
    $DifficultyProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DifficultyProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DifficultyProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DifficultyProgressTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> rating = const Value.absent(),
                Value<int> validWins = const Value.absent(),
                Value<int> windowGames = const Value.absent(),
                Value<bool> unlocked = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
              }) => DifficultyProgressCompanion(
                rating: rating,
                validWins: validWins,
                windowGames: windowGames,
                unlocked: unlocked,
                updatedAtUtc: updatedAtUtc,
              ),
          createCompanionCallback:
              ({
                Value<int> rating = const Value.absent(),
                Value<int> validWins = const Value.absent(),
                Value<int> windowGames = const Value.absent(),
                Value<bool> unlocked = const Value.absent(),
                required DateTime updatedAtUtc,
              }) => DifficultyProgressCompanion.insert(
                rating: rating,
                validWins: validWins,
                windowGames: windowGames,
                unlocked: unlocked,
                updatedAtUtc: updatedAtUtc,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DifficultyProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DifficultyProgressTable,
      DifficultyProgressRow,
      $$DifficultyProgressTableFilterComposer,
      $$DifficultyProgressTableOrderingComposer,
      $$DifficultyProgressTableAnnotationComposer,
      $$DifficultyProgressTableCreateCompanionBuilder,
      $$DifficultyProgressTableUpdateCompanionBuilder,
      (
        DifficultyProgressRow,
        BaseReferences<
          _$AppDatabase,
          $DifficultyProgressTable,
          DifficultyProgressRow
        >,
      ),
      DifficultyProgressRow,
      PrefetchHooks Function()
    >;
typedef $$RatingHistoryTableCreateCompanionBuilder =
    RatingHistoryCompanion Function({
      required String id,
      required String gameId,
      required DateTime recordedAtUtc,
      required double rating,
      Value<int> rowid,
    });
typedef $$RatingHistoryTableUpdateCompanionBuilder =
    RatingHistoryCompanion Function({
      Value<String> id,
      Value<String> gameId,
      Value<DateTime> recordedAtUtc,
      Value<double> rating,
      Value<int> rowid,
    });

final class $$RatingHistoryTableReferences
    extends
        BaseReferences<_$AppDatabase, $RatingHistoryTable, RatingHistoryRow> {
  $$RatingHistoryTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $GamesTable _gameIdTable(_$AppDatabase db) =>
      db.games.createAlias('rating_history__game_id__games__id');

  $$GamesTableProcessedTableManager get gameId {
    final $_column = $_itemColumn<String>('game_id')!;

    final manager = $$GamesTableTableManager(
      $_db,
      $_db.games,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_gameIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RatingHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $RatingHistoryTable> {
  $$RatingHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAtUtc => $composableBuilder(
    column: $table.recordedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  $$GamesTableFilterComposer get gameId {
    final $$GamesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableFilterComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RatingHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $RatingHistoryTable> {
  $$RatingHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAtUtc => $composableBuilder(
    column: $table.recordedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  $$GamesTableOrderingComposer get gameId {
    final $$GamesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableOrderingComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RatingHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $RatingHistoryTable> {
  $$RatingHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAtUtc => $composableBuilder(
    column: $table.recordedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  $$GamesTableAnnotationComposer get gameId {
    final $$GamesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableAnnotationComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RatingHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RatingHistoryTable,
          RatingHistoryRow,
          $$RatingHistoryTableFilterComposer,
          $$RatingHistoryTableOrderingComposer,
          $$RatingHistoryTableAnnotationComposer,
          $$RatingHistoryTableCreateCompanionBuilder,
          $$RatingHistoryTableUpdateCompanionBuilder,
          (RatingHistoryRow, $$RatingHistoryTableReferences),
          RatingHistoryRow,
          PrefetchHooks Function({bool gameId})
        > {
  $$RatingHistoryTableTableManager(_$AppDatabase db, $RatingHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RatingHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RatingHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RatingHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> gameId = const Value.absent(),
                Value<DateTime> recordedAtUtc = const Value.absent(),
                Value<double> rating = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RatingHistoryCompanion(
                id: id,
                gameId: gameId,
                recordedAtUtc: recordedAtUtc,
                rating: rating,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String gameId,
                required DateTime recordedAtUtc,
                required double rating,
                Value<int> rowid = const Value.absent(),
              }) => RatingHistoryCompanion.insert(
                id: id,
                gameId: gameId,
                recordedAtUtc: recordedAtUtc,
                rating: rating,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RatingHistoryTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({gameId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (gameId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.gameId,
                                referencedTable: $$RatingHistoryTableReferences
                                    ._gameIdTable(db),
                                referencedColumn: $$RatingHistoryTableReferences
                                    ._gameIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RatingHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RatingHistoryTable,
      RatingHistoryRow,
      $$RatingHistoryTableFilterComposer,
      $$RatingHistoryTableOrderingComposer,
      $$RatingHistoryTableAnnotationComposer,
      $$RatingHistoryTableCreateCompanionBuilder,
      $$RatingHistoryTableUpdateCompanionBuilder,
      (RatingHistoryRow, $$RatingHistoryTableReferences),
      RatingHistoryRow,
      PrefetchHooks Function({bool gameId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<String> pieceSet,
      Value<String> themeMode,
      Value<bool> defaultClockEnabled,
      Value<int> defaultTimeMinutes,
      required DateTime updatedAtUtc,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<String> pieceSet,
      Value<String> themeMode,
      Value<bool> defaultClockEnabled,
      Value<int> defaultTimeMinutes,
      Value<DateTime> updatedAtUtc,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pieceSet => $composableBuilder(
    column: $table.pieceSet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get defaultClockEnabled => $composableBuilder(
    column: $table.defaultClockEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultTimeMinutes => $composableBuilder(
    column: $table.defaultTimeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pieceSet => $composableBuilder(
    column: $table.pieceSet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get defaultClockEnabled => $composableBuilder(
    column: $table.defaultClockEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultTimeMinutes => $composableBuilder(
    column: $table.defaultTimeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get pieceSet =>
      $composableBuilder(column: $table.pieceSet, builder: (column) => column);

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<bool> get defaultClockEnabled => $composableBuilder(
    column: $table.defaultClockEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultTimeMinutes => $composableBuilder(
    column: $table.defaultTimeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSettingsRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSettingsRow,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingsRow>,
          ),
          AppSettingsRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> pieceSet = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<bool> defaultClockEnabled = const Value.absent(),
                Value<int> defaultTimeMinutes = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                pieceSet: pieceSet,
                themeMode: themeMode,
                defaultClockEnabled: defaultClockEnabled,
                defaultTimeMinutes: defaultTimeMinutes,
                updatedAtUtc: updatedAtUtc,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> pieceSet = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<bool> defaultClockEnabled = const Value.absent(),
                Value<int> defaultTimeMinutes = const Value.absent(),
                required DateTime updatedAtUtc,
              }) => AppSettingsCompanion.insert(
                id: id,
                pieceSet: pieceSet,
                themeMode: themeMode,
                defaultClockEnabled: defaultClockEnabled,
                defaultTimeMinutes: defaultTimeMinutes,
                updatedAtUtc: updatedAtUtc,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSettingsRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSettingsRow,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingsRow>,
      ),
      AppSettingsRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$GamesTableTableManager get games =>
      $$GamesTableTableManager(_db, _db.games);
  $$GameMovesTableTableManager get gameMoves =>
      $$GameMovesTableTableManager(_db, _db.gameMoves);
  $$DifficultyProgressTableTableManager get difficultyProgress =>
      $$DifficultyProgressTableTableManager(_db, _db.difficultyProgress);
  $$RatingHistoryTableTableManager get ratingHistory =>
      $$RatingHistoryTableTableManager(_db, _db.ratingHistory);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}

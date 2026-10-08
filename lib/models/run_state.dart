/// État d'une Netrun (Dart pur).
library;

class IceState {
  IceState({this.st = 'waiting', required this.at, required this.rez, this.hit = false});

  /// "waiting" | "chasing" | "down"
  String st;

  /// Étage où il attend.
  String at;
  int rez;

  /// Il a déjà touché le netrunner (malus du Putois).
  bool hit;

  bool get waiting => st == 'waiting';
  bool get chasing => st == 'chasing';
  bool get down => st == 'down';

  factory IceState.fromJson(Map<String, dynamic> j) => IceState(
    st: j['st'] as String? ?? 'waiting',
    at: j['at'] as String? ?? '',
    rez: (j['rez'] as num?)?.toInt() ?? 0,
    hit: j['hit'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {'st': st, 'at': at, 'rez': rez, 'hit': hit};
}

class DemonState {
  DemonState({this.st = 'waiting', required this.rez});

  /// "waiting" | "active" | "down"
  String st;
  int rez;

  bool get waiting => st == 'waiting';
  bool get active => st == 'active';
  bool get down => st == 'down';

  factory DemonState.fromJson(Map<String, dynamic> j) =>
      DemonState(st: j['st'] as String? ?? 'waiting', rez: (j['rez'] as num?)?.toInt() ?? 0);

  Map<String, dynamic> toJson() => {'st': st, 'rez': rez};
}

class ProgState {
  ProgState({this.on = false, required this.rez, this.used = false, this.rezRound, this.tgt});

  bool on;
  int rez;

  /// Programme "une fois par Netrun" déjà utilisé.
  bool used;

  /// Tour de la dernière activation.
  int? rezRound;

  /// Cible (clé de GLACE ennemi) pour un GLACE installé.
  String? tgt;

  factory ProgState.fromJson(Map<String, dynamic> j) => ProgState(
    on: j['on'] as bool? ?? false,
    rez: (j['rez'] as num?)?.toInt() ?? 0,
    used: j['used'] as bool? ?? false,
    rezRound: (j['rezRound'] as num?)?.toInt(),
    tgt: j['tgt'] as String?,
  );

  Map<String, dynamic> toJson() => {'on': on, 'rez': rez, 'used': used, 'rezRound': rezRound, 'tgt': tgt};
}

class LogEntry {
  LogEntry({required this.t, required this.txt, this.c = ''});

  final int t;
  final String txt;

  /// "" | "ok" | "ko"
  final String c;

  factory LogEntry.fromJson(Map<String, dynamic> j) =>
      LogEntry(t: (j['t'] as num?)?.toInt() ?? 0, txt: j['txt'] as String? ?? '', c: j['c'] as String? ?? '');

  Map<String, dynamic> toJson() => {'t': t, 'txt': txt, 'c': c};
}

class DamageSummary {
  DamageSummary({required this.tot, this.from, this.to});

  final int tot;
  final int? from;
  final int? to;

  factory DamageSummary.fromJson(Map<String, dynamic> j) => DamageSummary(
    tot: (j['tot'] as num?)?.toInt() ?? 0,
    from: (j['from'] as num?)?.toInt(),
    to: (j['to'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {'tot': tot, 'from': from, 'to': to};
}

class RunResult {
  RunResult({required this.h, List<String>? lines, this.ok, this.sum}) : lines = lines ?? [];

  final String h;
  final List<String> lines;

  /// true vert, false rouge, null neutre.
  final bool? ok;
  final DamageSummary? sum;

  factory RunResult.fromJson(Map<String, dynamic> j) => RunResult(
    h: j['h'] as String? ?? '',
    lines: (j['lines'] as List? ?? []).map((e) => e.toString()).toList(),
    ok: j['ok'] as bool?,
    sum: j['sum'] == null ? null : DamageSummary.fromJson(Map<String, dynamic>.from(j['sum'] as Map)),
  );

  Map<String, dynamic> toJson() => {'h': h, 'lines': lines, 'ok': ok, 'sum': sum?.toJson()};
}

class RunState {
  RunState({
    this.status = 'off',
    this.pos,
    Set<String>? seen,
    Set<String>? carto,
    Set<String>? done,
    Map<String, IceState>? ice,
    Map<String, DemonState>? demon,
    Map<String, ProgState>? prog,
    this.turn = 0,
    this.actions = 0,
    this.spent = 0,
    this.slid = false,
    this.pen = 0,
    this.kraken = 0,
    this.burning = false,
    this.ps,
    this.masq,
    this.virus,
    List<LogEntry>? log,
    this.last,
  }) : seen = seen ?? {},
       carto = carto ?? {},
       done = done ?? {},
       ice = ice ?? {},
       demon = demon ?? {},
       prog = prog ?? {},
       log = log ?? [];

  static const int maxLog = 40;

  /// "off" | "on" | "out"
  String status;
  String? pos;
  Set<String> seen;
  Set<String> carto;
  Set<String> done;
  Map<String, IceState> ice;
  Map<String, DemonState> demon;
  Map<String, ProgState> prog;
  int turn;
  int actions;
  int spent;
  bool slid;
  int pen;
  int kraken;
  bool burning;
  int? ps;
  int? masq;
  int? virus;
  List<LogEntry> log;
  RunResult? last;

  bool get isOn => status == 'on';
  bool get isOff => status == 'off';
  bool get isOut => status == 'out';

  factory RunState.fromJson(Map<String, dynamic> j) {
    Map<String, T> map<T>(Object? raw, T Function(Map<String, dynamic>) f) => {
      for (final e in (raw as Map? ?? {}).entries) e.key.toString(): f(Map<String, dynamic>.from(e.value as Map)),
    };
    Set<String> set(Object? raw) => (raw as List? ?? []).map((e) => e.toString()).toSet();
    return RunState(
      status: j['status'] as String? ?? 'off',
      pos: j['pos'] as String?,
      seen: set(j['seen']),
      carto: set(j['carto']),
      done: set(j['done']),
      ice: map(j['ice'], IceState.fromJson),
      demon: map(j['demon'], DemonState.fromJson),
      prog: map(j['prog'], ProgState.fromJson),
      turn: (j['turn'] as num?)?.toInt() ?? 0,
      actions: (j['actions'] as num?)?.toInt() ?? 0,
      spent: (j['spent'] as num?)?.toInt() ?? 0,
      slid: j['slid'] as bool? ?? false,
      pen: (j['pen'] as num?)?.toInt() ?? 0,
      kraken: (j['kraken'] as num?)?.toInt() ?? 0,
      burning: j['burning'] as bool? ?? false,
      ps: (j['ps'] as num?)?.toInt(),
      masq: (j['masq'] as num?)?.toInt(),
      virus: (j['virus'] as num?)?.toInt(),
      log: (j['log'] as List? ?? []).map((e) => LogEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      last: j['last'] == null ? null : RunResult.fromJson(Map<String, dynamic>.from(j['last'] as Map)),
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'pos': pos,
    'seen': seen.toList(),
    'carto': carto.toList(),
    'done': done.toList(),
    'ice': ice.map((k, v) => MapEntry(k, v.toJson())),
    'demon': demon.map((k, v) => MapEntry(k, v.toJson())),
    'prog': prog.map((k, v) => MapEntry(k, v.toJson())),
    'turn': turn,
    'actions': actions,
    'spent': spent,
    'slid': slid,
    'pen': pen,
    'kraken': kraken,
    'burning': burning,
    'ps': ps,
    'masq': masq,
    'virus': virus,
    'log': log.map((e) => e.toJson()).toList(),
    'last': last?.toJson(),
  };
}

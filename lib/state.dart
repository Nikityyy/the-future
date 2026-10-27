import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'demo.dart';
import 'format.dart' as fmt;
import 'platform/bio.dart';
import 'projection.dart';
import 'snapshot.dart';
import 'vault.dart';

enum Mode { none, demo, live }

class SnapshotMissing implements Exception {
  const SnapshotMissing();
}

typedef OneOffEntry = ({int year, int month, double amount});

/// Everything the screens read. Plans and scenarios live here and are saved
/// as you change them; the portfolio itself only ever lives in memory and, as
/// ciphertext, in the browser's storage.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState(this._prefs) {
    mode = Mode.values.byName(_prefs.getString('mode') ?? 'none');
    _loadPlan();
    if (mode == Mode.demo) snapshot = demoSnapshot();
    locked = mode == Mode.live;
    WidgetsBinding.instance.addObserver(this);
  }

  final SharedPreferences _prefs;
  late Mode mode;
  bool locked = false;
  Snapshot? snapshot;
  bool refreshing = false;
  DateTime? checkedAt;
  String? error;
  String? _passphrase;
  DateTime? _hiddenAt;

  // The plan.
  double? monthlyOverride;
  int years = 20;
  int scenario = 1; // 0 cautious, 1 expected, 2 hopeful
  bool realTerms = false;
  double raisePercent = 0;
  double inflation = defaultInflation;
  double savingsRate = defaultSavingsRate;
  Returns returns = {for (final e in defaultReturns.entries) e.key: [...e.value]};
  List<OneOffEntry> oneOffs = [];

  /// Which asset kinds the Portfolio and Future pages show. Empty means all.
  Set<Kind> filter = {};

  /// Amounts show as dots.
  bool hide = false;

  static const autoLock = Duration(minutes: 2);

  bool get ready => snapshot != null && !locked;

  /// The kinds in use: the filter, limited to what the portfolio holds.
  Set<Kind> get active {
    final present = snapshot?.kinds ?? Kind.values.toSet();
    final f = filter.intersection(present);
    return f.isEmpty ? present : f;
  }

  double get usual => snapshot?.usualFor(active).roundToDouble() ?? 0;

  double get monthly => monthlyOverride ?? usual;

  List<OneOff> get _oneOffsNow {
    final now = DateTime.now();
    return [
      for (final o in oneOffs)
        if ((o.year - now.year) * 12 + o.month - now.month >= 1)
          OneOff((o.year - now.year) * 12 + o.month - now.month, o.amount),
    ];
  }

  Projection projectionFor(int scenario, {double? monthlyAmount, int? yearsAhead}) {
    final s = snapshot!;
    return project(
      start: {for (final k in active) k: s.valueOf(k)},
      mix: s.mixFor(active),
      monthly: monthlyAmount ?? monthly,
      months: (yearsAhead ?? years) * 12,
      yearlyReturn: {for (final k in Kind.values) k: returns[k]![scenario]},
      raisePercent: raisePercent,
      oneOffs: _oneOffsNow,
      realTerms: realTerms,
      inflation: inflation,
    );
  }

  /// The same money and the same monthly amount, left in a savings account.
  Projection savingsFor() {
    final s = snapshot!;
    return project(
      start: {for (final k in active) k: s.valueOf(k)},
      mix: s.mixFor(active),
      monthly: monthly,
      months: years * 12,
      yearlyReturn: {for (final k in Kind.values) k: savingsRate},
      raisePercent: raisePercent,
      oneOffs: _oneOffsNow,
      realTerms: realTerms,
      inflation: inflation,
    );
  }

  // Modes.

  Future<void> startDemo() async {
    mode = Mode.demo;
    snapshot = demoSnapshot();
    locked = false;
    await _prefs.setString('mode', 'demo');
    notifyListeners();
  }

  /// Opens the sealed snapshot with [passphrase] and, if it fits, keeps the
  /// passphrase on this device sealed under [pin].
  Future<void> connect(String passphrase, String pin) async {
    final sealed = await _fetchSealed();
    final snap = Snapshot.fromJson(jsonDecode(await open(sealed, passphrase)) as Map<String, dynamic>);
    await _prefs.setString('vault', jsonEncode(await seal(passphrase, pin)));
    await _prefs.setString('cache', jsonEncode(sealed));
    await _prefs.setString('mode', 'live');
    mode = Mode.live;
    _passphrase = passphrase;
    snapshot = snap;
    locked = false;
    notifyListeners();
  }

  /// Checks the passphrase against the published snapshot before asking for a PIN.
  Future<void> checkPassphrase(String passphrase) async => open(await _fetchSealed(), passphrase);

  Future<bool> unlock(String pin) async {
    try {
      _passphrase = await open(jsonDecode(_prefs.getString('vault')!) as Map<String, dynamic>, pin);
    } on WrongSecret {
      return false;
    }
    await _finishUnlock();
    return true;
  }

  // Face ID, Touch ID or fingerprint: the passkey's secret seals the passphrase a second time.

  bool bioSupported = false;

  bool get hasBio => _prefs.containsKey('bio');

  Future<void> checkBio() async {
    bioSupported = await Bio.supported();
    notifyListeners();
  }

  /// Needs the app unlocked. Returns an error message, or null when it worked.
  Future<String?> enableBio() async {
    final pass = _passphrase;
    if (pass == null) return 'Unlock the app first.';
    final id = await Bio.enroll();
    if (id == null) return 'This device cannot unlock with ${Bio.label} here. On iPhone it needs iOS 18 or later.';
    final secret = await Bio.secret(id);
    if (secret == null) return 'Cancelled.';
    await _prefs.setString('bio', jsonEncode({'id': id, 'vault': await seal(pass, secret)}));
    notifyListeners();
    return null;
  }

  Future<void> disableBio() async {
    await _prefs.remove('bio');
    notifyListeners();
  }

  /// Asks for the face or finger. False when it was cancelled or failed.
  Future<bool> unlockWithBio() async {
    try {
      final b = jsonDecode(_prefs.getString('bio')!) as Map<String, dynamic>;
      final secret = await Bio.secret(b['id'] as String);
      if (secret == null) return false;
      _passphrase = await open(b['vault'] as Map<String, dynamic>, secret);
    } catch (_) {
      return false;
    }
    await _finishUnlock();
    return true;
  }

  Future<void> _finishUnlock() async {
    final cache = _prefs.getString('cache');
    if (cache != null) {
      final text = await open(jsonDecode(cache) as Map<String, dynamic>, _passphrase!);
      snapshot = Snapshot.fromJson(jsonDecode(text) as Map<String, dynamic>);
    }
    locked = false;
    notifyListeners();
    unawaited(refresh());
  }

  void lock() {
    if (mode != Mode.live || locked) return;
    locked = true;
    snapshot = null;
    _passphrase = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (mode != Mode.live || _passphrase == null || refreshing) return;
    refreshing = true;
    error = null;
    notifyListeners();
    try {
      final sealed = await _fetchSealed();
      snapshot = Snapshot.fromJson(jsonDecode(await open(sealed, _passphrase!)) as Map<String, dynamic>);
      await _prefs.setString('cache', jsonEncode(sealed));
      checkedAt = DateTime.now();
    } on SnapshotMissing {
      error = 'No snapshot published yet. Run the sync workflow on GitHub.';
    } on WrongSecret {
      error = 'The passphrase no longer fits the published snapshot. Disconnect and connect again.';
    } catch (_) {
      error = snapshot == null ? 'Could not load your portfolio.' : 'Offline. Showing your last update.';
    }
    refreshing = false;
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _prefs.clear();
    mode = Mode.none;
    snapshot = null;
    _passphrase = null;
    locked = false;
    error = null;
    monthlyOverride = null;
    oneOffs = [];
    filter = {};
    hide = fmt.hideAmounts = false;
    realTerms = false;
    raisePercent = 0;
    inflation = defaultInflation;
    savingsRate = defaultSavingsRate;
    returns = {for (final e in defaultReturns.entries) e.key: [...e.value]};
    notifyListeners();
  }

  Future<Map<String, dynamic>> _fetchSealed() async {
    final res = await http.get(Uri.base.resolve('data.enc?t=${DateTime.now().millisecondsSinceEpoch}'));
    // GitHub Pages answers a missing file with its 404 page.
    if (res.statusCode != 200 || !res.body.trimLeft().startsWith('{')) throw const SnapshotMissing();
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // The plan, saved.

  static const _keep = Object();

  /// One kind at a time: a tap shows just that kind, a tap on it again shows everything.
  void toggleKind(Kind k) {
    filter = filter.length == 1 && filter.contains(k) ? {} : {k};
    _save();
    notifyListeners();
  }

  void showAllKinds() {
    filter = {};
    _save();
    notifyListeners();
  }

  void setHide(bool v) {
    hide = fmt.hideAmounts = v;
    _save();
    notifyListeners();
  }

  void setPlan({
    Object? monthly = _keep,
    int? years,
    int? scenario,
    bool? realTerms,
    double? raisePercent,
    double? inflation,
    double? savingsRate,
    Returns? returns,
    List<OneOffEntry>? oneOffs,
  }) {
    if (monthly != _keep) monthlyOverride = monthly as double?;
    this.years = years ?? this.years;
    this.scenario = scenario ?? this.scenario;
    this.realTerms = realTerms ?? this.realTerms;
    this.raisePercent = raisePercent ?? this.raisePercent;
    this.inflation = inflation ?? this.inflation;
    this.savingsRate = savingsRate ?? this.savingsRate;
    this.returns = returns ?? this.returns;
    this.oneOffs = oneOffs ?? this.oneOffs;
    notifyListeners();
    _save();
  }

  void _save() {
    _prefs.setString(
      'plan',
      jsonEncode({
        'filter': [for (final k in filter) k.name],
        'hide': hide,
        'monthly': monthlyOverride,
        'years': years,
        'scenario': scenario,
        'real': realTerms,
        'raise': raisePercent,
        'inflation': inflation,
        'savings': savingsRate,
        'returns': {for (final e in returns.entries) e.key.name: e.value},
        'oneOffs': [
          for (final o in oneOffs) [o.year, o.month, o.amount],
        ],
      }),
    );
  }

  void _loadPlan() {
    try {
      final j = jsonDecode(_prefs.getString('plan') ?? '{}') as Map<String, dynamic>;
      monthlyOverride = (j['monthly'] as num?)?.toDouble();
      filter = {for (final n in (j['filter'] as List? ?? [])) Kind.values.byName(n as String)};
      hide = fmt.hideAmounts = j['hide'] as bool? ?? false;
      years = j['years'] as int? ?? years;
      scenario = j['scenario'] as int? ?? scenario;
      realTerms = j['real'] as bool? ?? false;
      raisePercent = (j['raise'] as num?)?.toDouble() ?? 0;
      inflation = (j['inflation'] as num?)?.toDouble() ?? defaultInflation;
      savingsRate = (j['savings'] as num?)?.toDouble() ?? defaultSavingsRate;
      final r = j['returns'] as Map<String, dynamic>?;
      if (r != null) {
        returns = {
          for (final k in Kind.values) k: [for (final v in r[k.name] as List) (v as num).toDouble()],
        };
      }
      oneOffs = [
        for (final o in (j['oneOffs'] as List? ?? []))
          (year: (o as List)[0] as int, month: o[1] as int, amount: (o[2] as num).toDouble()),
      ];
    } catch (_) {
      // A broken plan falls back to the defaults.
    }
  }

  // Locks itself two minutes after the app went to the background.

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final s = state;
    if (s == AppLifecycleState.hidden || s == AppLifecycleState.paused) {
      _hiddenAt ??= DateTime.now();
    } else if (s == AppLifecycleState.resumed) {
      final at = _hiddenAt;
      _hiddenAt = null;
      if (at != null && DateTime.now().difference(at) > autoLock) lock();
    }
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One high-score entry for the unlock-screen Zerpland runner.
class RunnerScoreEntry {
  const RunnerScoreEntry({
    required this.score,
    required this.distanceM,
    required this.at,
  });

  final int score;
  final int distanceM;
  final DateTime at;

  Map<String, Object?> toJson() => {
        'score': score,
        'distanceM': distanceM,
        'at': at.toIso8601String(),
      };

  factory RunnerScoreEntry.fromJson(Map<String, dynamic> json) {
    return RunnerScoreEntry(
      score: json['score'] as int? ?? 0,
      distanceM: json['distanceM'] as int? ?? 0,
      at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Persists top scores locally (no network). Top 5 only.
class RunnerScoreboard {
  RunnerScoreboard({SharedPreferences? prefs}) : _prefs = prefs;

  static const _key = 'robot_runner_scores_v1';
  static const maxEntries = 5;

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<RunnerScoreEntry>> load() async {
    final p = await _ensure();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RunnerScoreEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));
    } catch (_) {
      return const [];
    }
  }

  /// Inserts [entry], keeps top [maxEntries], returns updated board.
  Future<List<RunnerScoreEntry>> submit(RunnerScoreEntry entry) async {
    final board = [...await load(), entry]
      ..sort((a, b) => b.score.compareTo(a.score));
    final trimmed = board.take(maxEntries).toList();
    final p = await _ensure();
    await p.setString(
      _key,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
    return trimmed;
  }

  Future<int> bestScore() async {
    final board = await load();
    if (board.isEmpty) return 0;
    return board.first.score;
  }
}

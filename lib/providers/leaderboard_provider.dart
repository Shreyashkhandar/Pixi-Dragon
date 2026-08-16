// lib/providers/leaderboard_provider.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/leaderboard_service.dart';

class LeaderboardProvider extends ChangeNotifier {
  List<LeaderboardEntry> _entries = [];
  LeaderboardEntry? _userEntry;
  int _userRank = 0;
  bool _isLoading = false;
  String? _error;

  // ── Getters ────────────────────────────────────────────────────────────────────

  List<LeaderboardEntry> get entries    => List.unmodifiable(_entries);
  LeaderboardEntry?       get userEntry  => _userEntry;
  int                     get userRank   => _userRank;
  bool                    get isLoading  => _isLoading;
  String?                 get error      => _error;

  // ── Public API ─────────────────────────────────────────────────────────────────

  /// Fetches the top-5 leaderboard entries and the current user's entry/rank.
  Future<void> fetchLeaderboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fire top-entries query immediately; start user queries in parallel if signed in.
      final topFuture = LeaderboardService.getTopEntries();

      final user = Supabase.instance.client.auth.currentUser;
      Future<LeaderboardEntry?>? entryFuture;
      Future<int>? rankFuture;

      if (user != null) {
        entryFuture = LeaderboardService.getUserEntry(user.id);
        rankFuture  = LeaderboardService.getUserRank(user.id);
      }

      _entries = await topFuture;
      debugPrint('NETWORK TEST RESULT: $_entries');

      if (entryFuture != null) _userEntry = await entryFuture;
      if (rankFuture  != null) _userRank  = await rankFuture;

      _isLoading = false;
    } catch (e, stackTrace) {
      debugPrint('SUPABASE LEADERBOARD ERROR: $e');
      debugPrint('STACK TRACE: $stackTrace');
      _isLoading = false;
      _error = 'Failed to load leaderboard: $e';
    }

    notifyListeners();
  }

  /// Syncs [score] to Supabase if it beats the stored best.
  /// Silently no-ops when the user is not signed in.
  Future<void> syncScore(int score) async {
    try {
      await LeaderboardService.syncScore(score);
    } catch (e, st) {
      // Never disrupt gameplay — but always log.
      debugPrint('SUPABASE SYNC SCORE ERROR: $e');
      debugPrint('STACK TRACE: $st');
    }
  }
}

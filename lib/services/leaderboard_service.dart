// lib/services/leaderboard_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents one row in the `leaderboard` table.
class LeaderboardEntry {
  final String id;
  final String userId;
  final String username;
  final int score;
  final DateTime createdAt;
  final String? avatarUrl;

  const LeaderboardEntry({
    required this.id,
    required this.userId,
    required this.username,
    required this.score,
    required this.createdAt,
    this.avatarUrl,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      username: (map['username'] as String?) ?? 'Player',
      score: (map['score'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}

class LeaderboardService {
  static final _client = Supabase.instance.client;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Fetches the top 5 players ordered by score descending.
  static Future<List<LeaderboardEntry>> getTopEntries() async {
    final response = await _client
        .from('leaderboard')
        .select('id, user_id, username, score, created_at, avatar_url')
        .order('score', ascending: false)
        .limit(5);

    return (response as List<dynamic>)
        .map((row) => LeaderboardEntry.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches the leaderboard entry for a specific user.
  static Future<LeaderboardEntry?> getUserEntry(String userId) async {
    final response = await _client
        .from('leaderboard')
        .select('id, user_id, username, score, created_at, avatar_url')
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return LeaderboardEntry.fromMap(response as Map<String, dynamic>);
  }

  /// Returns the 1-based rank of the user.
  /// Rank = (number of players with strictly higher score) + 1.
  static Future<int> getUserRank(String userId) async {
    // Get this user's score.
    final userRow = await _client
        .from('leaderboard')
        .select('score')
        .eq('user_id', userId)
        .maybeSingle();

    if (userRow == null) return 0;
    final userScore = (userRow['score'] as int?) ?? 0;

    // Count rows with a strictly higher score.
    final above = await _client
        .from('leaderboard')
        .select('id')
        .gt('score', userScore);

    return (above as List).length + 1;
  }

  /// Syncs [newScore] to Supabase only when it beats the current stored score.
  /// Safe to call when not signed in — returns early silently.
  static Future<void> syncScore(int newScore) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    if (newScore <= 0) return;

    // Read stored score.
    final existing = await _client
        .from('leaderboard')
        .select('score')
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing == null) {
      // First time user → INSERT
      await _client.from('leaderboard').insert({
        'user_id': user.id,
        'username': user.userMetadata?['username'] ?? 'Player',
        'score': newScore,
      });
      return;
    }
    final current = (existing['score'] as int?) ?? 0;

    if (newScore > current) {
      await _client
          .from('leaderboard')
          .update({'score': newScore})
          .eq('user_id', user.id);
    }
  }
}

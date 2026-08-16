// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _client = Supabase.instance.client;

  // ── Convenience getters ─────────────────────────────────────────────────────

  /// Returns the currently signed-in Supabase [User], or null.
  static User? get currentUser => _client.auth.currentUser;

  /// True when a session exists.
  static bool get isSignedIn => currentUser != null;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Signs in with email + password.
  /// If the account does not yet exist, creates it via sign-up.
  /// On success, upserts/inserts a row in the `leaderboard` table.
  ///
  /// Returns the authenticated [User] or throws on failure.
  static Future<User> signInWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    AuthResponse response;

    try {
      // Attempt sign-in first.
      response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      // If the credentials are wrong / user not found → try sign-up.
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid') ||
          msg.contains('not found') ||
          e.statusCode == '400') {
        response = await _client.auth.signUp(
          email: email.trim(),
          password: password,
        );
      } else {
        rethrow;
      }
    }

    final user = response.user;
    if (user == null) {
      throw Exception('Authentication returned a null user.');
    }

    // Check whether a leaderboard row already exists for this user.
    final existing = await _client
        .from('leaderboard')
        .select('id, score')
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing == null) {
      // New user → insert a fresh row.
      await _client.from('leaderboard').insert({
        'user_id': user.id,
        'username': username.trim(),
        'score': 0,
      });
    } else {
      // Returning user → refresh username only (never downgrade score).
      await _client
          .from('leaderboard')
          .update({'username': username.trim()})
          .eq('user_id', user.id);
    }

    // Persist username locally for fast display.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pixi_dragon_username', username.trim());

    return user;
  }

  /// Initiates Google Sign-In using Supabase OAuth.
  static Future<bool> signInWithGoogle() async {
    try {
      final redirectUrl = _getRedirectUrl();
      debugPrint(
          '[OAuth] Initiating Google Sign-In with redirect: $redirectUrl');

      final result = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        scopes: 'email profile',
      );

      debugPrint('[OAuth] OAuth flow initiated successfully: $result');
      return result;
    } catch (e) {
      debugPrint('[OAuth] Error initiating OAuth: $e');
      rethrow;
    }
  }

  /// Generates the redirect URI for OAuth callback.
  static String _getRedirectUrl() {
    return 'com.pixi.dragon://login-callback';
  }

  /// Called after successful OAuth login to update leaderboard.
  static Future<void> upsertLeaderboardForUser(User user) async {
    debugPrint('[Leaderboard:Upsert] Starting upsert for user: ${user.id}');

    try {
      final username = user.userMetadata?['name'] as String? ??
          user.userMetadata?['email'] as String? ??
          user.email?.split('@').first ??
          'GoogleUser';

      debugPrint(
          '[Leaderboard:Username] Extracted username: $username');

      final existing = await _client
          .from('leaderboard')
          .select('id, score')
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing == null) {
        debugPrint(
            '[Leaderboard:Insert] New user detected, creating leaderboard entry');

        await _client.from('leaderboard').insert({
          'user_id': user.id,
          'username': username,
          'score': 0,
        });

        debugPrint('[Leaderboard:Insert] Entry created successfully');
      } else {
        debugPrint(
            '[Leaderboard:Update] Existing user detected with score: ${existing['score']}');

        await _client
            .from('leaderboard')
            .update({'username': username})
            .eq('user_id', user.id);

        debugPrint('[Leaderboard:Update] Username updated successfully');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pixi_dragon_username', username);

      debugPrint('[SharedPrefs] Username cached locally: $username');
      debugPrint('[Leaderboard:Upsert] Completed successfully');
    } catch (e, st) {
      debugPrint('[Leaderboard:Error] Exception: $e');
      debugPrint('[Stack Trace] $st');
      rethrow;
    }
  }

  /// Signs out the current user and clears local cache.
  static Future<void> signOut() async {
    await _client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pixi_dragon_username');
  }

  /// Returns the locally cached username, or null if not signed in.
  static Future<String?> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pixi_dragon_username');
  }
}
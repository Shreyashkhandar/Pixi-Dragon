// lib/services/profile_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles avatar upload to Supabase Storage and avatar_url persistence
/// in the leaderboard table.
class ProfileService {
  static final _client = Supabase.instance.client;

  // ── Upload ──────────────────────────────────────────────────────────────────

  /// Uploads [imageFile] to `avatars/{userId}/avatar.jpg` (upsert).
  /// Returns the public URL of the uploaded file.
  ///
  /// Throws if the user is not authenticated or the upload fails.
  static Future<String> uploadAvatar(String userId, File imageFile) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to upload an avatar.');
    }

    final filePath = '$userId/avatar.jpg';
    final bytes = await imageFile.readAsBytes();

    try {
      await _client.storage.from('avatars').uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
    } catch (e, st) {
      debugPrint('PROFILE ERROR: Avatar upload failed – $e');
      debugPrint('STACK TRACE: $st');
      rethrow;
    }

    // Build the public URL and bust browser/CDN cache with a timestamp.
    final publicUrl = _client.storage.from('avatars').getPublicUrl(filePath);
    final cacheBustedUrl =
        '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    return cacheBustedUrl;
  }

  // ── Database ────────────────────────────────────────────────────────────────

  /// Persists [url] in the `avatar_url` column of the `leaderboard` table
  /// for the given [userId].
  static Future<void> updateAvatarUrl(String userId, String url) async {
    try {
      await _client
          .from('leaderboard')
          .update({'avatar_url': url})
          .eq('user_id', userId);
    } catch (e, st) {
      debugPrint('PROFILE ERROR: Failed to save avatar URL – $e');
      debugPrint('STACK TRACE: $st');
      rethrow;
    }
  }

  /// Reads the stored `avatar_url` for [userId] from the `leaderboard` table.
  /// Returns `null` when no row exists or the column is empty.
  static Future<String?> fetchAvatarUrl(String userId) async {
    try {
      final row = await _client
          .from('leaderboard')
          .select('avatar_url')
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) return null;
      return row['avatar_url'] as String?;
    } catch (e, st) {
      debugPrint('PROFILE ERROR: Failed to fetch avatar URL – $e');
      debugPrint('STACK TRACE: $st');
      return null;
    }
  }
}

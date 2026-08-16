// lib/providers/profile_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/profile_service.dart';

/// Manages avatar state: picking, uploading, caching, and error handling.
class ProfileProvider extends ChangeNotifier {
  String? _avatarUrl;
  bool _isUploading = false;
  String? _error;

  // ── Getters ────────────────────────────────────────────────────────────────

  String? get avatarUrl   => _avatarUrl;
  bool    get isUploading => _isUploading;
  String? get error       => _error;

  // ── Load (cached) ──────────────────────────────────────────────────────────

  /// Fetches the avatar URL from the database and caches it locally.
  /// Safe to call multiple times — skips the network call when a URL is
  /// already cached unless [force] is true.
  Future<void> loadAvatar(String userId, {bool force = false}) async {
    if (_avatarUrl != null && !force) return;

    final url = await ProfileService.fetchAvatarUrl(userId);
    if (url != null && url != _avatarUrl) {
      _avatarUrl = url;
      notifyListeners();
    }
  }

  // ── Pick + Upload ──────────────────────────────────────────────────────────

  /// Full flow: permission → pick → upload → DB update → notify.
  ///
  /// [source] should be [ImageSource.camera] or [ImageSource.gallery].
  /// Returns `true` on success, `false` on failure/cancellation.
  Future<bool> pickAndUploadAvatar(ImageSource source) async {
    // ── Auth guard ───────────────────────────────────────────────────────────
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _error = 'You must be signed in to change your avatar.';
      notifyListeners();
      return false;
    }

    // ── Permission check ─────────────────────────────────────────────────────
    final permissionGranted = await _requestPermission(source);
    if (!permissionGranted) return false;

    // ── Pick image ───────────────────────────────────────────────────────────
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
    } catch (e, st) {
      debugPrint('PROFILE ERROR: Image picker failed – $e');
      debugPrint('STACK TRACE: $st');
      _error = 'Could not open the image picker.';
      notifyListeners();
      return false;
    }

    if (picked == null) {
      // User cancelled — not an error.
      return false;
    }

    // ── Upload ───────────────────────────────────────────────────────────────
    _isUploading = true;
    _error = null;
    notifyListeners();

    try {
      final file = File(picked.path);
      final publicUrl = await ProfileService.uploadAvatar(user.id, file);
      await ProfileService.updateAvatarUrl(user.id, publicUrl);

      _avatarUrl = publicUrl;
      _isUploading = false;
      notifyListeners();
      return true;
    } on SocketException {
      _error = 'No internet connection. Please check your network and retry.';
    } catch (e, st) {
      debugPrint('PROFILE ERROR: Upload pipeline failed – $e');
      debugPrint('STACK TRACE: $st');
      _error = _friendlyMessage(e);
    }

    _isUploading = false;
    notifyListeners();
    return false;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clears the cached avatar (e.g. on logout).
  void reset() {
    _avatarUrl = null;
    _error = null;
    _isUploading = false;
    notifyListeners();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<bool> _requestPermission(ImageSource source) async {
    late Permission permission;

    if (source == ImageSource.camera) {
      permission = Permission.camera;
    } else {
      // Android 13+ uses granular media permissions.
      permission = Permission.photos;
    }

    var status = await permission.status;

    if (status.isGranted || status.isLimited) return true;

    if (status.isPermanentlyDenied) {
      _error =
          'Permission permanently denied. Please enable it in your device settings.';
      notifyListeners();
      // Offer to open settings.
      await openAppSettings();
      return false;
    }

    // Ask the user.
    status = await permission.request();

    if (status.isGranted || status.isLimited) return true;

    if (status.isPermanentlyDenied) {
      _error =
          'Permission permanently denied. Please enable it in your device settings.';
      notifyListeners();
      await openAppSettings();
      return false;
    }

    _error = 'Permission denied. Cannot access ${source == ImageSource.camera ? 'camera' : 'gallery'}.';
    notifyListeners();
    return false;
  }

  String _friendlyMessage(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('failed host lookup')) {
      return 'No internet connection. Please try again.';
    }
    if (msg.contains('storage') || msg.contains('bucket')) {
      return 'Storage error. Please try again later.';
    }
    return 'Failed to upload avatar. Please try again.';
  }
}

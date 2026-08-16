// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  String? _username;
  bool _isLoading = false;
  String? _error;

  // ── Getters ──────────────────────────────────────────────────────────────────

  User?   get currentUser => _currentUser;
  String? get username    => _username;
  bool    get isSignedIn  => _currentUser != null;
  bool    get isLoading   => _isLoading;
  String? get error       => _error;

  // ── Constructor ───────────────────────────────────────────────────────────────

  AuthProvider() {
    _currentUser = AuthService.currentUser;
    if (_currentUser != null) _loadUsername();

    // Keep in sync with Supabase session changes (token refresh, external sign-out).
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _currentUser = data.session?.user;
      if (_currentUser == null) _username = null;
      notifyListeners();
    });
  }

  // ── Private helpers ────────────────────────────────────────────────────────────

  Future<void> _loadUsername() async {
    _username = await AuthService.getSavedUsername();
    notifyListeners();
  }

  String _parseError(dynamic e, [StackTrace? st]) {
    // Always print full error so it is visible in logcat / console.
    debugPrint('SUPABASE AUTH ERROR: $e');
    if (st != null) debugPrint('STACK TRACE: $st');

    if (e is AuthException) return e.message;
    final msg = e.toString().toLowerCase();
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('failed host lookup')) {
      return 'No internet connection. Please try again.';
    }
    // Show the raw error in debug mode so nothing is hidden.
    return e.toString();
  }

  // ── Public API ─────────────────────────────────────────────────────────────────

  /// Logs in (or creates an account) with email + password.
  /// Returns true on success, false on failure (error is set in [error]).
  Future<bool> loginWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await AuthService.signInWithEmail(
        email: email,
        password: password,
        username: username,
      );
      _currentUser = user;
      _username = username.trim();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _isLoading = false;
      _error = _parseError(e, stackTrace);
      notifyListeners();
      return false;
    }
  }

  /// Initiates Google Sign-In using Supabase OAuth.
  /// 
  /// This method:
  /// 1. Calls [AuthService.signInWithGoogle()] which opens a browser
  /// 2. User authenticates with Google in the browser
  /// 3. Browser redirects back to app via deep link (com.pixi.dragon://login-callback)
  /// 4. Supabase automatically handles the OAuth callback
  /// 5. Auth state listener fires and session is established
  /// 6. Return value indicates if OAuth flow was initiated (not if login completed)
  ///
  /// Note: The actual session creation happens after the redirect.
  /// Listen to [isSignedIn] or provide feedback via auth state listener.
  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await AuthService.signInWithGoogle();
      // OAuth flow initiated successfully
      // Session will be set automatically by Supabase after redirect
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _isLoading = false;
      _error = _parseError(e, stackTrace);
      notifyListeners();
      return false;
    }
  }

  /// Logs out and clears local state.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await AuthService.signOut();
    } catch (e, st) {
      debugPrint('SUPABASE LOGOUT ERROR: $e');
      debugPrint('STACK TRACE: $st');
    }
    _currentUser = null;
    _username = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Clears any displayed error message.
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

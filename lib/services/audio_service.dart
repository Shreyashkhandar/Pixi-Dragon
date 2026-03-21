// lib/services/audio_service.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService extends ChangeNotifier {
  static const String _volumeKey = 'pixi_dragon_volume';
  static const String _mutedKey  = 'pixi_dragon_muted';

  final AudioPlayer _player = AudioPlayer();

  double _volume = 0.7;
  bool   _muted  = false;

  double get volume => _volume;
  bool   get muted  => _muted;

  AudioService() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _volume = prefs.getDouble(_volumeKey) ?? 0.7;
    _muted  = prefs.getBool(_mutedKey)   ?? false;

    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(_muted ? 0.0 : _volume);

    notifyListeners();
    // Music does NOT start here — GameScreen calls startMusic() on mount.
  }

  // ── Playback control ──────────────────────────────────────────────────────

  /// Start looping music. Called when GameScreen mounts.
  Future<void> startMusic() async {
    if (_muted) return;
    await _player.play(AssetSource('audio/liberation.mpeg'));
  }

  /// Stop music completely. Called when app is closing.
  Future<void> stopMusic() async {
    await _player.stop();
  }

  // ── Volume control ────────────────────────────────────────────────────────

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    if (!_muted) await _player.setVolume(_volume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, _volume);
    notifyListeners();
  }

  // ── Mute toggle ───────────────────────────────────────────────────────────

  Future<void> toggleMute() async {
    _muted = !_muted;
    if (_muted) {
      await _player.setVolume(0.0);
    } else {
      await _player.setVolume(_volume);
      // Resume playback if it was stopped by mute.
      final state = _player.state;
      if (state == PlayerState.stopped || state == PlayerState.completed) {
        await _player.play(AssetSource('audio/liberation.mpeg'));
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mutedKey, _muted);
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
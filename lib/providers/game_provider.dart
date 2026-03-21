// lib/providers/game_provider.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GameState { ready, playing, gameOver }

class GameProvider extends ChangeNotifier {
  // ─── Gap & hitbox tuning ──────────────────────────────────────────────────

  // Increase gapHalfHeight  → bigger gap, easier to fly through
  // Decrease _dragonBodyFraction → smaller hitbox, more forgiving collisions
  // Decrease _pipeBodyFraction   → narrower pipe hitbox, easier to squeeze past

  /// Half the gap height in normalized units.
  /// Full gap = gapHalfHeight × 2 out of 2.0 total screen height.
  /// 0.22 was too tight. 0.28 gives a noticeably wider gap.
  /// increase it if you want to stop dragon before it
  /// reaches the obstacle in the area between the pipes

  static const double gapHalfHeight = 0.28;

  /// Visible dragon body as a fraction of the 85px image.
  /// Lowered from 0.60 → 0.45 so the hitbox is tight around the body core
  /// and ignores wing tips / tail which are semi-transparent.
  static const double _dragonBodyFraction = 0.40;

  /// Visible pipe column as a fraction of the 80px image.
  /// Lowered from 0.75 → 0.65 so edge pixels of the pipe don't kill the dragon.
  static const double _pipeBodyFraction = 0.50;

  // ─── Other constants ──────────────────────────────────────────────────────

  static const double _dragonImagePx        = 85.0;
  static const double pipeWidthPx           = 80.0;
  static const double _groundImageHeightPx  = 120.0;
  static const double _groundSurfaceFraction = 0.50;

  static const double _pipeSpawnX     = 1.3;
  static const double _pipeRecycleX   = -1.4;
  static const int    _pipeCount      = 2;
  static const double _pipeSeparation = 1.8;

  static const double _gravity       = 3.8;
  static const double _jumpVelocity  = -1.4;
  static const double _basePipeSpeed = 0.9;
  static const double _fastPipeSpeed = 1.4;

  static const String _bestScoreKey = 'pixi_dragon_best_score';

  // ─── State ────────────────────────────────────────────────────────────────

  GameState _state = GameState.ready;
  GameState get state => _state;

  double _dragonY = 0.0;
  double get dragonY => _dragonY;

  double _velocity = 0.0;

  final List<double> _pipeX      = [];
  final List<double> _pipeGapY   = [];
  final List<bool>   _pipeScored = [];

  List<double> get pipeX    => List.unmodifiable(_pipeX);
  List<double> get pipeGapY => List.unmodifiable(_pipeGapY);

  int _score     = 0;
  int get score  => _score;

  int _bestScore    = 0;
  int get bestScore => _bestScore;

  Timer?    _timer;
  DateTime? _lastTick;

  Size _screenSize = const Size(400, 800);

  // ─── Constructor ──────────────────────────────────────────────────────────

  GameProvider() {
    _loadBestScore();
  }

  // ─── Derived geometry ─────────────────────────────────────────────────────

  double get _groundTopNorm {
    final visibleGroundFromBottom =
        _groundImageHeightPx * (1.0 - _groundSurfaceFraction);
    final brickTopPxFromTop = _screenSize.height - visibleGroundFromBottom;
    return (brickTopPxFromTop / (_screenSize.height / 2)) - 1.0;
  }

  double get _dragonHalfH {
    final visiblePx = _dragonImagePx * _dragonBodyFraction;
    return visiblePx / (_screenSize.height / 2);
  }

  double get _pipeHalfW {
    final visiblePx = pipeWidthPx * _pipeBodyFraction;
    return (visiblePx / 2.0) / (_screenSize.width / 2.0);
  }

  // ─── Persistence ─────────────────────────────────────────────────────────

  Future<void> _loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    _bestScore = prefs.getInt(_bestScoreKey) ?? 0;
    notifyListeners();
  }

  Future<void> _saveBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bestScoreKey, _bestScore);
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  void updateScreenSize(Size size) {
    _screenSize = size;
  }

  void startGame() {
    if (_state == GameState.playing) return;
    _state    = GameState.playing;
    _dragonY  = 0.0;
    _velocity = 0.0;
    _score    = 0;
    _initPipes();
    _startLoop();
    notifyListeners();
  }

  void flap() {
    if (_state != GameState.playing) return;
    _velocity = _jumpVelocity;
    notifyListeners();
  }

  void reset() {
    _stopLoop();
    _state    = GameState.ready;
    _dragonY  = 0.0;
    _velocity = 0.0;
    _score    = 0;
    _pipeX.clear();
    _pipeGapY.clear();
    _pipeScored.clear();
    notifyListeners();
  }

  // ─── Pipe initialisation ─────────────────────────────────────────────────

  void _initPipes() {
    _pipeX.clear();
    _pipeGapY.clear();
    _pipeScored.clear();
    for (int i = 0; i < _pipeCount; i++) {
      _pipeX.add(_pipeSpawnX + i * _pipeSeparation);
      _pipeGapY.add(_randomGapY());
      _pipeScored.add(false);
    }
  }

  double _randomGapY() {
    // Keep gap centre away from extreme top/bottom so the full gap is visible.
    const min = -0.25;
    const max = 0.25;
    return min + Random().nextDouble() * (max - min);
  }

  // ─── Game loop ────────────────────────────────────────────────────────────

  void _startLoop() {
    _lastTick = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 16), _tick);
  }

  void _stopLoop() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick(Timer _) {
    final now = DateTime.now();
    final dt  =
    (now.difference(_lastTick!).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = now;
    _updateDragon(dt);
    _updatePipes(dt);
    _checkCollisions();
    notifyListeners();
  }

  void _updateDragon(double dt) {
    _velocity += _gravity * dt;
    _dragonY  += _velocity * dt;
  }

  void _updatePipes(double dt) {
    final speed = _score >= 10 ? _fastPipeSpeed : _basePipeSpeed;
    for (int i = 0; i < _pipeX.length; i++) {
      _pipeX[i] -= speed * dt;

      if (!_pipeScored[i] && (_pipeX[i] + _pipeHalfW) < 0.0) {
        _pipeScored[i] = true;
        _score++;
        if (_score > _bestScore) {
          _bestScore = _score;
          _saveBestScore();
        }
      }

      if (_pipeX[i] < _pipeRecycleX) {
        final maxX = _pipeX.reduce(max);
        // Randomise gap between pipes (1.6–2.2) so they never feel patterned.
        final randomSep = 1.6 + Random().nextDouble() * 0.6;
        _pipeX[i]      = maxX + randomSep;
        _pipeGapY[i]   = _randomGapY();
        _pipeScored[i] = false;
      }
    }
  }

  // ─── Collision detection ──────────────────────────────────────────────────

  void _checkCollisions() {
    final dHalfH = _dragonHalfH;
    final dTop    = _dragonY - dHalfH;
    final dBottom = _dragonY + dHalfH;
    // Horizontal hitbox is 70% of the vertical — forgiving on the sides.
    final dHalfW = dHalfH * 0.70;
    final dLeft  = -dHalfW;
    final dRight =  dHalfW;

    // Ceiling
    if (dTop <= -1.0) { _triggerGameOver(); return; }

    // Ground
    if (dBottom >= _groundTopNorm) { _triggerGameOver(); return; }

    // Pipes
    final phw = _pipeHalfW;
    for (int i = 0; i < _pipeX.length; i++) {
      final pLeft  = _pipeX[i] - phw;
      final pRight = _pipeX[i] + phw;

      if (dRight <= pLeft || dLeft >= pRight) continue;

      final gapTop    = _pipeGapY[i] - gapHalfHeight;
      final gapBottom = _pipeGapY[i] + gapHalfHeight;

      if (dTop < gapTop || dBottom > gapBottom) {
        _triggerGameOver();
        return;
      }
    }
  }

  void _triggerGameOver() {
    _stopLoop();
    _state = GameState.gameOver;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopLoop();
    super.dispose();
  }
}
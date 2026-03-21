// lib/screens/game_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../services/audio_service.dart';
import '../constants/app_assets.dart';
import '../widgets/dragon.dart';
import '../widgets/pipe.dart';
import '../widgets/score_bar.dart';
import 'settings_screen.dart';

// GameScreen is StatefulWidget so we can start/stop music with the widget lifecycle.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  @override
  void initState() {
    super.initState();
    // Start music as soon as GameScreen mounts (splash has already finished).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AudioService>().startMusic();
    });
  }

  @override
  void dispose() {
    // Stop music when the screen is disposed (app closing or navigating away).
    context.read<AudioService>().stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();

    // Inject real screen size every frame for accurate collision geometry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameProvider>().updateScreenSize(
        MediaQuery.of(context).size,
      );
    });

    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background ───────────────────────────────────────────────────
          Positioned.fill(
            child: Image.asset(
              AppAssets.background,
              fit: BoxFit.cover,
            ),
          ),

          // ── Pipes ────────────────────────────────────────────────────────
          if (game.state == GameState.playing)
            ...List.generate(
              game.pipeX.length,
                  (i) => Pipe(x: game.pipeX[i], gapY: game.pipeGapY[i]),
            ),

          // ── Ground ───────────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              AppAssets.ground,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),

          // ── Dragon ───────────────────────────────────────────────────────
          Dragon(y: game.dragonY),

          // ── Score bar — always visible ────────────────────────────────────
          Positioned(
            top: topPad + 8,
            left: 0,
            right: 0,
            child: const ScoreBar(),
          ),

          // ── Settings button — ready state only (top-right) ────────────────
          if (game.state == GameState.ready)
            Positioned(
              top: topPad + 4,
              right: 8,
              child: IconButton(
                icon: const Icon(
                  Icons.settings_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 350),
                      pageBuilder: (_, __, ___) => const SettingsScreen(),
                      transitionsBuilder: (_, animation, __, child) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1.0, 0.0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: child,
                        );
                      },
                    ),
                  );
                },
              ),
            ),

          // ── Ready state — START button ────────────────────────────────────
          if (game.state == GameState.ready)
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 100),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.85),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 52, vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: game.startGame,
                    child: const Text('START'),
                  ),
                ],
              ),
            ),

          // ── Game Over overlay ─────────────────────────────────────────────
          if (game.state == GameState.gameOver)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.68),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'GAME OVER',
                      style: TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ResultRow(
                        label: 'Score', value: game.score.toString()),
                    const SizedBox(height: 8),
                    _ResultRow(
                        label: 'Best', value: game.bestScore.toString()),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 44, vertical: 12),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: game.reset,
                      child: const Text('RESTART'),
                    ),
                  ],
                ),
              ),
            ),

          // ── Tap-to-flap ───────────────────────────────────────────────────
          if (game.state == GameState.playing)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: game.flap,
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 18,
                color: Colors.white70,
                fontWeight: FontWeight.w500)),
        Text(value,
            style: const TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
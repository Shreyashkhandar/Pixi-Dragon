// lib/widgets/score_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';

/// Displays best score (top-left) and current score (top-center).
/// Shown during all game states from GameScreen.
class ScoreBar extends StatelessWidget {
  const ScoreBar({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Best score — left ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _ScoreColumn(
            label: 'BEST',
            value: game.bestScore.toString(),
          ),
        ),

        // ── Current score — centre ────────────────────────────────────────
        Expanded(
          child: Center(
            child: _ScoreColumn(
              label: 'SCORE',
              value: game.score.toString(),
              valueFontSize: 42,
            ),
          ),
        ),

        // Invisible right-side padding to mirror the left so centre stays true.
        const SizedBox(width: 80),
      ],
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  final String label;
  final String value;
  final double valueFontSize;

  const _ScoreColumn({
    required this.label,
    required this.value,
    this.valueFontSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.85),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            shadows: const [
              Shadow(
                  blurRadius: 3,
                  color: Colors.black54,
                  offset: Offset(1, 1)),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: valueFontSize,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(
                  blurRadius: 6,
                  color: Colors.black87,
                  offset: Offset(2, 2)),
            ],
          ),
        ),
      ],
    );
  }
}
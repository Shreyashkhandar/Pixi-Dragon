// lib/widgets/pipe.dart
import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../providers/game_provider.dart';

class Pipe extends StatelessWidget {
  /// Pipe centre x in normalized -1..1 space.
  final double x;

  /// Gap centre y in normalized -1..1 space.
  final double gapY;

  const Pipe({super.key, required this.x, required this.gapY});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // ── Convert normalized coords → pixel coords ──────────────────────────
    // x is pipe centre; subtract half-width to get left edge.
    final pipeLeftPx =
        (x + 1) / 2 * size.width - GameProvider.pipeWidthPx / 2;

    // Gap centre in pixels.
    final gapCenterPx = (gapY + 1) / 2 * size.height;

    // Half-gap in pixels.
    final gapHalfPx = GameProvider.gapHalfHeight * (size.height / 2);
    final gapTopPx = gapCenterPx - gapHalfPx;
    final gapBottomPx = gapCenterPx + gapHalfPx;

    final topPipeHeight = gapTopPx;
    final bottomPipeHeight = size.height - gapBottomPx;

    if (topPipeHeight <= 0 && bottomPipeHeight <= 0) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // ── Top pipe (flipped) ────────────────────────────────────────────
        if (topPipeHeight > 0)
          Positioned(
            left: pipeLeftPx,
            top: 0,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationX(3.14159265),
              child: Image.asset(
                AppAssets.pipe,
                width: GameProvider.pipeWidthPx,
                height: topPipeHeight,
                fit: BoxFit.fill,
              ),
            ),
          ),

        // ── Bottom pipe ───────────────────────────────────────────────────
        if (bottomPipeHeight > 0)
          Positioned(
            left: pipeLeftPx,
            top: gapBottomPx,
            child: Image.asset(
              AppAssets.pipe,
              width: GameProvider.pipeWidthPx,
              height: bottomPipeHeight,
              fit: BoxFit.fill,
            ),
          ),
      ],
    );
  }
}
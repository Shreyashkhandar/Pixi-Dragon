// lib/widgets/dragon.dart
import 'package:flutter/material.dart';
import '../constants/app_assets.dart';

class Dragon extends StatelessWidget {
  final double y;

  const Dragon({super.key, required this.y});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(0, y),
      child: Image.asset(
        AppAssets.dragon,
        width: 85, // slightly smaller as finalized
        fit: BoxFit.contain,
      ),
    );
  }
}

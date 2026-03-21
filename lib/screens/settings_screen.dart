// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioService>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section header ──────────────────────────────────────────────
            const Text(
              'AUDIO',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 16),

            // ── Audio card ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // ── Mute toggle row ───────────────────────────────────────
                  Row(
                    children: [
                      Icon(
                        audio.muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: audio.muted ? Colors.white38 : Colors.white,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Background Music',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Mute / unmute switch
                      GestureDetector(
                        onTap: audio.toggleMute,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 52,
                          height: 28,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: audio.muted
                                ? Colors.white24
                                : Colors.deepPurpleAccent,
                          ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 250),
                            alignment: audio.muted
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.all(3),
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 24),

                  // ── Volume slider row ─────────────────────────────────────
                  Row(
                    children: [
                      const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Volume',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(audio.volume * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Horizontal slider — drag left to decrease, right to increase.
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: audio.muted
                          ? Colors.white24
                          : Colors.deepPurpleAccent,
                      inactiveTrackColor: Colors.white12,
                      thumbColor: audio.muted
                          ? Colors.white38
                          : Colors.white,
                      overlayColor:
                      Colors.deepPurpleAccent.withOpacity(0.2),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                    ),
                    child: Slider(
                      value: audio.volume,
                      min: 0.0,
                      max: 1.0,
                      onChanged: audio.muted
                          ? null // disabled when muted
                          : (val) => audio.setVolume(val),
                    ),
                  ),

                  // Left / right labels
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quieter',
                        style: TextStyle(
                          color: Colors.white24,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'Louder',
                        style: TextStyle(
                          color: Colors.white24,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
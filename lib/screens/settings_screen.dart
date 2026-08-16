// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/audio_service.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../services/security_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Load avatar once when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isSignedIn && auth.currentUser != null) {
        context.read<ProfileProvider>().loadAvatar(auth.currentUser!.id);
      }
    });
  }

  void _showImageSourceSheet() {
    final profile = context.read<ProfileProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'CHANGE PROFILE PICTURE',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Colors.deepPurpleAccent),
                ),
                title: const Text('Camera',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
                subtitle: const Text('Take a new photo',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(profile, ImageSource.camera);
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(color: Colors.white10, height: 1),
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: Colors.deepPurpleAccent),
                ),
                title: const Text('Gallery',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
                subtitle: const Text('Choose from photos',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(profile, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ProfileProvider profile, ImageSource source) async {
    final success = await profile.pickAndUploadAvatar(source);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (profile.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(profile.error!),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      profile.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio   = context.watch<AudioService>();
    final auth    = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>();

    // adroid flag secure start here
    return SecureScreen(
      child: Scaffold(
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

            // ── User card (visible only when signed in) ─────────────────────
            if (auth.isSignedIn) ...[
              const Text(
                'PLAYER',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    // Avatar with tap-to-change overlay
                    GestureDetector(
                      onTap: profile.isUploading ? null : _showImageSourceSheet,
                      child: Stack(
                        children: [
                          // Profile image or fallback letter
                          if (profile.isUploading)
                            CircleAvatar(
                              radius: 28,
                              backgroundColor:
                                  Colors.deepPurpleAccent.withValues(alpha: 0.2),
                              child: const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.deepPurpleAccent,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          else if (profile.avatarUrl != null)
                            CircleAvatar(
                              radius: 28,
                              backgroundColor:
                                  Colors.deepPurpleAccent.withValues(alpha: 0.2),
                              backgroundImage:
                                  NetworkImage(profile.avatarUrl!),
                              onBackgroundImageError: (_, __) {},
                            )
                          else
                            CircleAvatar(
                              radius: 28,
                              backgroundColor:
                                  Colors.deepPurpleAccent.withValues(alpha: 0.2),
                              child: Text(
                                (auth.username?.isNotEmpty == true)
                                    ? auth.username![0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.deepPurpleAccent,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          // Camera badge
                          if (!profile.isUploading)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: Colors.deepPurpleAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF16213E),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.username ?? '—',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            auth.currentUser?.email ?? '',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.verified_user_rounded,
                        color: Colors.deepPurpleAccent, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Change Profile Picture button ──────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurpleAccent,
                    side: BorderSide(
                      color: Colors.deepPurpleAccent.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  onPressed:
                      profile.isUploading ? null : _showImageSourceSheet,
                  icon: profile.isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.deepPurpleAccent,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.photo_camera_rounded, size: 18),
                  label: Text(
                    profile.isUploading
                        ? 'UPLOADING...'
                        : 'CHANGE PROFILE PICTURE',
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],

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

                  // Horizontal slider.
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: audio.muted
                          ? Colors.white24
                          : Colors.deepPurpleAccent,
                      inactiveTrackColor: Colors.white12,
                      thumbColor:
                          audio.muted ? Colors.white38 : Colors.white,
                      overlayColor:
                          Colors.deepPurpleAccent.withValues(alpha: 0.2),
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
                          ? null
                          : (val) => audio.setVolume(val),
                    ),
                  ),

                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quieter',
                        style:
                            TextStyle(color: Colors.white24, fontSize: 11),
                      ),
                      Text(
                        'Louder',
                        style:
                            TextStyle(color: Colors.white24, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Logout button (visible only when signed in) ─────────────────
            if (auth.isSignedIn)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  onPressed: auth.isLoading
                      ? null
                      : () async {
                          context.read<ProfileProvider>().reset();
                          await context.read<AuthProvider>().logout();
                          if (context.mounted) Navigator.pop(context);
                        },
                  icon: auth.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.redAccent,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: const Text('LOGOUT'),
                ),
              ),

            if (auth.isSignedIn) const SizedBox(height: 8),
          ],
        ),
      ),
    ));
    // android flag secure ends here
  }
}
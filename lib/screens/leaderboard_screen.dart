// lib/screens/leaderboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/leaderboard_provider.dart';
import '../services/leaderboard_service.dart';
import '../services/security_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaderboardProvider>().fetchLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lb   = context.watch<LeaderboardProvider>();
    final auth = context.watch<AuthProvider>();

    // adroid flag secure start here
    return SecureScreen(
      child: Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        title: const Text(
          'Leaderboard',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: lb.isLoading
                ? null
                : () => context.read<LeaderboardProvider>().fetchLeaderboard(),
          ),
        ],
      ),
      body: lb.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
            )
          : lb.error != null
              ? _ErrorView(
                  message: lb.error!,
                  onRetry: () =>
                      context.read<LeaderboardProvider>().fetchLeaderboard(),
                )
              : _LeaderboardBody(
                  entries:   lb.entries,
                  userEntry: lb.userEntry,
                  userRank:  lb.userRank,
                  auth:      auth,
                ),
    ));
    // android flag secure ends here
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────────

class _LeaderboardBody extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? userEntry;
  final int userRank;
  final AuthProvider auth;

  const _LeaderboardBody({
    required this.entries,
    required this.userEntry,
    required this.userRank,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    // Is the current user already visible in the top-5 list?
    final userId = auth.currentUser?.id;
    final userInTop5 =
        userId != null && entries.any((e) => e.userId == userId);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Trophy banner ────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.emoji_events_rounded,
                  color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'TOP PLAYERS',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Top 5 list ────────────────────────────────────────────────────────
          if (entries.isEmpty)
            const Center(
              child: Text(
                'No scores yet — be the first!',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: List.generate(entries.length, (i) {
                  final isLast = i == entries.length - 1;
                  final isCurrentUser = entries[i].userId == userId;
                  return _EntryRow(
                    rank:          i + 1,
                    entry:         entries[i],
                    isCurrentUser: isCurrentUser,
                    showDivider:   !isLast,
                  );
                }),
              ),
            ),

          // ── Current user row (if not in top 5) ──────────────────────────────
          if (!userInTop5 && userEntry != null) ...[
            const SizedBox(height: 20),
            const Row(
              children: [
                Expanded(child: Divider(color: Colors.white12)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'YOUR RANK',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.white12)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.4),
                ),
              ),
              child: _EntryRow(
                rank:          userRank,
                entry:         userEntry!,
                isCurrentUser: true,
                showDivider:   false,
              ),
            ),
          ],

          // ── Not signed in note ───────────────────────────────────────────────
          if (!auth.isSignedIn) ...[
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Sign in to track your rank',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Row widget ────────────────────────────────────────────────────────────────────

class _EntryRow extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final bool isCurrentUser;
  final bool showDivider;

  const _EntryRow({
    required this.rank,
    required this.entry,
    required this.isCurrentUser,
    required this.showDivider,
  });

  Color get _rankColor {
    if (rank == 1) return const Color(0xFFFFD700);   // gold
    if (rank == 2) return const Color(0xFFC0C0C0);   // silver
    if (rank == 3) return const Color(0xFFCD7F32);   // bronze
    return Colors.white38;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Rank badge
              SizedBox(
                width: 36,
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: _rankColor,
                    fontSize: rank <= 3 ? 17 : 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: isCurrentUser
                    ? Colors.deepPurpleAccent.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.07),
                backgroundImage: entry.avatarUrl != null
                    ? NetworkImage(entry.avatarUrl!)
                    : null,
                onBackgroundImageError: entry.avatarUrl != null
                    ? (_, __) {}
                    : null,
                child: entry.avatarUrl == null
                    ? Text(
                        entry.username.isNotEmpty
                            ? entry.username[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: isCurrentUser
                              ? Colors.deepPurpleAccent
                              : Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Username
              Expanded(
                child: Text(
                  entry.username,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : Colors.white70,
                    fontSize: 15,
                    fontWeight: isCurrentUser
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),

              // Score
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isCurrentUser
                      ? Colors.deepPurpleAccent.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  entry.score.toString(),
                  style: TextStyle(
                    color: isCurrentUser
                        ? Colors.deepPurpleAccent
                        : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: Colors.white10, height: 1),
          ),
      ],
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: Colors.white38, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurpleAccent,
                side: const BorderSide(color: Colors.deepPurpleAccent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

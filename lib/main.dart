// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/game_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/leaderboard_provider.dart';
import 'providers/profile_provider.dart';
import 'services/auth_service.dart';
import 'services/audio_service.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const PixiDragonApp());
}

class PixiDragonApp extends StatefulWidget {
  const PixiDragonApp({super.key});

  @override
  State<PixiDragonApp> createState() => _PixiDragonAppState();
}

class _PixiDragonAppState extends State<PixiDragonApp> {
  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    final supabase = Supabase.instance.client;

    debugPrint('🔵 [Auth Listener] Initialized');

    supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      final event = data.event;
      final user = session?.user;

      debugPrint(
        ' Event: $event | Session: ${session != null ? "YES" : "NO"}',
      );

      // Handle signed in
      if (event == AuthChangeEvent.signedIn && user != null) {
        debugPrint(
          ' User logged in: ${user.email ?? "N/A"} (ID: ${user.id})',
        );

        final provider = user.appMetadata?['provider'];
        final identities = user.identities ?? [];

        debugPrint(
          ' Provider: $provider | Identities: ${identities.length}',
        );

        try {
          await AuthService.upsertLeaderboardForUser(user);
          debugPrint('Leaderboard synced');
        } catch (e) {
          debugPrint(' Leaderboard error: $e');
        }
      }

      // Handle sign out
      else if (event == AuthChangeEvent.signedOut) {
        debugPrint(' User signed out');
      }

      // Handle updates
      else if (event == AuthChangeEvent.userUpdated) {
        debugPrint(' User updated');
      }

      else if (event == AuthChangeEvent.tokenRefreshed) {
        debugPrint('Token refreshed');
      }

      else if (event == AuthChangeEvent.initialSession) {
        debugPrint('Initial session loaded');
      }

      else {
        debugPrint(' Unhandled event: $event');
      }
    }, onError: (error) {
      debugPrint(' Auth listener error: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioService()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LeaderboardProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ],
      child: MaterialApp(
        title: 'Pixi Dragon',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
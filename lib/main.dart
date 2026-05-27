import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'core/theme/theme_provider.dart';
import 'data/repositories/quran_repository.dart';
import 'data/sources/local/quran_seeder.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.quranapp.audio',
      androidNotificationChannelName: 'Quran Audio',
      androidNotificationOngoing: true,
    );
  } catch (_) {
    // Audio background init is non-critical; continue without it.
  }

  runApp(
    const ProviderScope(
      child: QuranApp(),
    ),
  );
}

class QuranApp extends ConsumerWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Salah',
      debugShowCheckedModeBanner: false,
      theme: themeDataFor(themeMode),
      home: const _AppStartup(),
    );
  }
}

/// Seeds the DB and checks onboarding status before showing any UI.
class _AppStartup extends ConsumerStatefulWidget {
  const _AppStartup();

  @override
  ConsumerState<_AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends ConsumerState<_AppStartup> {
  bool _ready = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final db = ref.read(quranDatabaseProvider);
      // Seed DB and check onboarding status in parallel.
      final results = await Future.wait([
        QuranSeeder(db).seedIfNeeded(),
        hasSeenOnboarding(),
      ]);
      if (mounted) {
        setState(() {
          _showOnboarding = !(results[1] as bool);
          _ready = true;
        });
      }
    } catch (_) {
      // If seeding fails, proceed to the app rather than hanging on the splash.
      if (mounted) {
        setState(() {
          _showOnboarding = false;
          _ready = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const _SplashScreen();

    if (_showOnboarding) {
      return OnboardingScreen(
        onDone: () => setState(() => _showOnboarding = false),
      );
    }

    return const MainShell();
  }
}

// ─── Splash screen ────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A3D2E),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mosque, size: 64, color: Color(0xFFD4AF37)),
            SizedBox(height: 20),
            Text(
              'Salah',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 32),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFFD4AF37),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

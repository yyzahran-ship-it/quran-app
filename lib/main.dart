import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'core/theme/theme_provider.dart';
import 'data/repositories/quran_repository.dart';
import 'data/sources/local/quran_seeder.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init background audio. Wrapped in try-catch + timeout so a service
  // binding failure (seen on some Android versions) cannot block app launch.
  // Audio still plays in-app; lock-screen controls may be unavailable.
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.quranapp.audio',
      androidNotificationChannelName: 'Quran Audio',
      androidNotificationOngoing: true,
    ).timeout(const Duration(seconds: 5));
  } catch (_) {
    // Background audio unavailable — continue launching.
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
      title: 'Quran',
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
      // On any error, still proceed to the app so it doesn't stay stuck.
      if (mounted) setState(() => _ready = true);
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

    return const HomeScreen();
  }
}

// ─── Splash screen ────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primaryContainer,
              ),
              child: Icon(Icons.menu_book, size: 44, color: colors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'Quran',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

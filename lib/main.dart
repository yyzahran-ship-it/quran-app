import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/arabic_font_service.dart';
import 'core/theme/theme_provider.dart';
import 'data/repositories/quran_repository.dart';
import 'data/sources/local/quran_seeder.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      title: 'The Holy Quran',
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
        // Load KFGQPC font from cache if available (instant).
        // On first install, starts a background download and returns false.
        ArabicFontService.tryLoadCached(),
      ]);
      if (mounted) {
        setState(() {
          _showOnboarding = !(results[1] as bool);
          _ready = true;
        });
      }
      // results[2] is the font-loaded flag — no action needed;
      // if true the font was overridden via FontLoader already.
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
      backgroundColor: const Color(0xFF0a0a0a),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/icon/icon.png',
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'The Holy Quran',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD4A017),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFD4A017),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'features/dhikr/dhikr_screen.dart';
import 'features/mushaf/mushaf_screen.dart';
import 'features/prayer_times/prayer_times_screen.dart';
import 'features/qibla/qibla_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _screens = [
    PrayerTimesScreen(),
    MushafScreen(),
    QiblaScreen(),
    DhikrScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: _SalatukNavBar(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

class _SalatukNavBar extends StatelessWidget {
  const _SalatukNavBar({
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onTap,
      backgroundColor: const Color(0xFF0D1117),
      indicatorColor: const Color(0xFF0A7B83).withValues(alpha: 0.3),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return TextStyle(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.white38,
          fontSize: 11,
          fontWeight:
              isSelected ? FontWeight.w600 : FontWeight.normal,
        );
      }),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.access_time_outlined, color: Colors.white38),
          selectedIcon:
              Icon(Icons.access_time_filled, color: Color(0xFFD4AF37)),
          label: 'Prayer',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined, color: Colors.white38),
          selectedIcon:
              Icon(Icons.menu_book, color: Color(0xFFD4AF37)),
          label: 'Quran',
        ),
        NavigationDestination(
          icon: Icon(Icons.explore_outlined, color: Colors.white38),
          selectedIcon:
              Icon(Icons.explore, color: Color(0xFFD4AF37)),
          label: 'Qibla',
        ),
        NavigationDestination(
          icon: Icon(Icons.spa_outlined, color: Colors.white38),
          selectedIcon: Icon(Icons.spa, color: Color(0xFFD4AF37)),
          label: 'Dhikr',
        ),
      ],
    );
  }
}


import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/memories_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnimeMemoryApp());
}

class AnimeMemoryApp extends StatelessWidget {
  const AnimeMemoryApp({super.key});

  static const Color darkRed = Color(0xFF741C2B);
  static const Color background = Color(0xFF111318);
  static const Color panel = Color(0xFF1B1F28);
  static const Color border = Color(0xFF303541);
  static const Color textColor = Color(0xFFF4F5F8);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ذاكرة الأوتاكو',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: darkRed,
          secondary: Color(0xFF3A91B5),
          surface: panel,
          error: Color(0xFFFF5A65),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: textColor,
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: panel,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: border),
          ),
        ),
        dividerColor: border,
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: panel,
          indicatorColor: darkRed,
          labelBehavior:
              NavigationDestinationLabelBehavior.alwaysShow,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          hintStyle: const TextStyle(color: Colors.white38),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: darkRed,
              width: 1.8,
            ),
          ),
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int selectedIndex = 0;

  final List<Widget> screens = const [
    HomeScreen(),
    LibraryScreen(),
    MemoriesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: IndexedStack(
            index: selectedIndex,
            children: screens,
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.movie_creation_outlined),
              selectedIcon: Icon(Icons.movie_creation),
              label: 'المكتبة',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'ذكرياتي',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/memories_screen.dart';
import 'screens/settings_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkMode') ?? true;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  runApp(const AnimeMemoryApp());
}

class AnimeMemoryApp extends StatelessWidget {
  const AnimeMemoryApp({super.key});
  static const Color darkRed = Color(0xFF741C2B);
  static const Color background = Color(0xFF111318);
  static const Color panel = Color(0xFF1B1F28);
  static const Color border = Color(0xFF303541);
  static const Color textColor = Color(0xFFF4F5F8);
  static const Color glowColor = Color(0xFFFF4D6D); // لون التوهج الواضح

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ذاكرة الأوتاكو',
          themeMode: currentMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF4F5F8),
            colorScheme: const ColorScheme.light(
              primary: darkRed,
              secondary: Color(0xFF3A91B5),
              surface: Colors.white,
              error: Color(0xFFFF5A65),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: background,
            colorScheme: const ColorScheme.dark(
              primary: darkRed,
              secondary: Color(0xFF3A91B5),
              surface: panel,
              error: Color(0xFFFF5A65),
            ),
            // توهج الأزرار العامة
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: darkRed,
                foregroundColor: Colors.white,
                elevation: 12,
                shadowColor: glowColor.withOpacity(0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: glowColor, width: 1),
                ),
              ),
            ),
            // توهج شريط التنقل
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: panel,
              indicatorColor: darkRed,
              elevation: 15,
              shadowColor: glowColor.withOpacity(0.6),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              height: 72,
            ),
          ),
          home: const MainNavigation(),
        );
      },
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
        body: SafeArea(child: IndexedStack(index: selectedIndex, children: screens)),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => setState(() => selectedIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.movie_creation_outlined), selectedIcon: Icon(Icons.movie_creation), label: 'المكتبة'),
            NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'ذكرياتي'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
          ],
        ),
      ),
    );
  }
}
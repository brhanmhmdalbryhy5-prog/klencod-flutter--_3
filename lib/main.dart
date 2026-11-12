import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/memories_screen.dart';
import 'screens/settings_screen.dart';

// المتغير العام للتحكم في الثيم
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ذاكرة الأوتاكو',
          themeMode: currentMode,
          // الثيم الفاتح
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
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              centerTitle: false,
              elevation: 0,
            ),
            cardTheme: CardTheme( // تم التعديل
              color: Colors.white,
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
            ),
            dividerColor: const Color(0xFFE0E0E0),
            iconTheme: const IconThemeData(color: Colors.black54),
            navigationBarTheme: const NavigationBarThemeData(
              backgroundColor: Colors.white,
              indicatorColor: darkRed,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              elevation: 0,
              height: 72,
            ),
          ),
          // الثيم الداكن
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
            appBarTheme: const AppBarTheme(
              backgroundColor: background,
              foregroundColor: textColor,
              centerTitle: false,
              elevation: 0,
            ),
            cardTheme: CardTheme( // تم التعديل
              color: panel,
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: border),
              ),
            ),
            dividerColor: border,
            iconTheme: const IconThemeData(color: Colors.white70),
            navigationBarTheme: const NavigationBarThemeData(
              backgroundColor: panel,
              indicatorColor: darkRed,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              elevation: 0,
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
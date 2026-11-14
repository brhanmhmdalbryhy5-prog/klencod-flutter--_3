import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/memories_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart'; // 🆕 استيراد خدمة الإشعارات

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<Color> primaryColorNotifier = ValueNotifier(const Color(0xFF741C2B));
// 🔥 متغيرات الخط واللون
final ValueNotifier<String> fontNotifier = ValueNotifier('Cairo');
final ValueNotifier<Color> titleColorNotifier = ValueNotifier(const Color(0xFFFFD700));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🆕 تهيئة الإشعارات + طلب الإذن
  try {
    await NotificationService().init();
    await NotificationService().requestPermission();
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();

  final isDark = prefs.getBool('isDarkMode') ?? true;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  final savedColorValue = prefs.getInt('primaryColorValue') ?? 0xFF741C2B;
  primaryColorNotifier.value = Color(savedColorValue);

  fontNotifier.value = prefs.getString('app_font') ?? 'Cairo';
  final titleColorValue = prefs.getInt('title_color') ?? 0xFFFFD700;
  titleColorNotifier.value = Color(titleColorValue);

  runApp(const AnimeMemoryApp());
}

class AnimeMemoryApp extends StatelessWidget {
  const AnimeMemoryApp({super.key});

  static const Color background = Color(0xFF111318);
  static const Color panel = Color(0xFF1B1F28);
  static const Color border = Color(0xFF303541);
  static const Color textColor = Color(0xFFF4F5F8);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return ValueListenableBuilder<Color>(
          valueListenable: primaryColorNotifier,
          builder: (context, primaryColor, __) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'ذاكرة الأوتاكو',
              themeMode: currentMode,
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                scaffoldBackgroundColor: const Color(0xFFF4F5F8),
                colorScheme: ColorScheme.light(primary: primaryColor, secondary: primaryColor.withOpacity(0.7), surface: Colors.white, error: const Color(0xFFFF5A65)),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                scaffoldBackgroundColor: background,
                colorScheme: ColorScheme.dark(primary: primaryColor, secondary: primaryColor.withOpacity(0.7), surface: panel, error: const Color(0xFFFF5A65)),
                filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, elevation: 12, shadowColor: primaryColor.withOpacity(0.8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: primaryColor.withOpacity(0.6), width: 1)))),
                navigationBarTheme: NavigationBarThemeData(backgroundColor: panel, indicatorColor: primaryColor, elevation: 15, shadowColor: primaryColor.withOpacity(0.6), labelBehavior: NavigationDestinationLabelBehavior.alwaysShow, height: 72),
              ),
              home: const MainNavigation(),
            );
          },
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
  final List<Widget> screens = const [HomeScreen(), LibraryScreen(), MemoriesScreen(), SettingsScreen()];

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
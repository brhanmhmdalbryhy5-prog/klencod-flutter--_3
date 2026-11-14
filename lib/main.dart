import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/memories_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<Color> primaryColorNotifier = ValueNotifier(const Color(0xFF741C2B));
final ValueNotifier<String> fontNotifier = ValueNotifier('Cairo');
final ValueNotifier<Color> titleColorNotifier = ValueNotifier(const Color(0xFFFFD700));

// ══════════════════════════════════════════════════════════════
// 🆕 الطبقة العائمة (مع زر النقاط الثلاث)
// ══════════════════════════════════════════════════════════════
@pragma("vm:entry-point")
void overlayMain() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayWidget(),
    ),
  );
}

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});
  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  String _title = 'جاري المعالجة...';
  String _status = 'تهيئة...';
  double _progress = 0.0;
  StreamSubscription? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _dataSubscription = FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map) {
        setState(() {
          _title = event['title'] ?? _title;
          _status = event['status'] ?? _status;
          _progress = (event['progress'] as num?)?.toDouble() ?? _progress;
        });
      }
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1F28).withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.cyan.withOpacity(0.6), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_download, color: Colors.cyan, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _title,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 🆕 زر النقاط الثلاث
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white70),
                      padding: EdgeInsets.zero,
                      onSelected: (value) async {
                        if (value == 'cancel') {
                          // إرسال أمر إلغاء للتطبيق الأساسي
                          await FlutterOverlayWindow.shareData({'action': 'cancel'});
                          await FlutterOverlayWindow.closeOverlay();
                        } else if (value == 'hide') {
                          // إخفاء النافذة فقط (العملية تستمر في الخلفية)
                          await FlutterOverlayWindow.closeOverlay();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('إلغاء العملية'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'hide',
                          child: Row(
                            children: [
                              Icon(Icons.close, color: Colors.white70),
                              SizedBox(width: 8),
                              Text('إخفاء النافذة فقط'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _status,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 10,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyan),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${(_progress * 100).toInt()}%',
                    style: const TextStyle(color: Colors.cyan, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// التطبيق الأساسي
// ══════════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
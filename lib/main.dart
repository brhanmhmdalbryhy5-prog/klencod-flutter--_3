import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_events.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/memories_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';
import 'widgets/manga_character.dart';
import 'widgets/manga_character_settings.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<Color> primaryColorNotifier =
    ValueNotifier(const Color(0xFF741C2B));
final ValueNotifier<String> fontNotifier = ValueNotifier('Cairo');
final ValueNotifier<Color> titleColorNotifier =
    ValueNotifier(const Color(0xFFFFD700));

bool isAutoDarkModeEnabled = false;

void checkAutoTheme() {
  if (!isAutoDarkModeEnabled) return;
  final hour = DateTime.now().hour;
  final shouldBeDark = hour >= 18 || hour < 6;
  themeNotifier.value = shouldBeDark ? ThemeMode.dark : ThemeMode.light;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await NotificationService().init();
    await NotificationService().requestPermission();
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();
  isAutoDarkModeEnabled = prefs.getBool('auto_dark_mode') ?? false;

  if (isAutoDarkModeEnabled) {
    checkAutoTheme();
    Timer.periodic(const Duration(minutes: 30), (_) => checkAutoTheme());
  } else {
    final isDark = prefs.getBool('isDarkMode') ?? true;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  final savedColorValue = prefs.getInt('primaryColorValue') ?? 0xFF741C2B;
  primaryColorNotifier.value = Color(savedColorValue);
  fontNotifier.value = prefs.getString('app_font') ?? 'Cairo';
  final titleColorValue = prefs.getInt('title_color') ?? 0xFFFFD700;
  titleColorNotifier.value = Color(titleColorValue);

  await MangaConfigService.load();

  runApp(const AnimeMemoryApp());
}

class AnimeMemoryApp extends StatefulWidget {
  const AnimeMemoryApp({super.key});

  @override
  State<AnimeMemoryApp> createState() => _AnimeMemoryAppState();
}

class _AnimeMemoryAppState extends State<AnimeMemoryApp>
    with WidgetsBindingObserver {
  StreamSubscription? _eventSub;

  static const Color background = Color(0xFF111318);
  static const Color panel = Color(0xFF1B1F28);

  // 🔗 هنا يتم ربط كل حدث في التطبيق بالرد المناسب للشخصية
  // لتغيير أي رد: عدّل الكلمة على اليسار (الحدث) أو اليمين (مفتاح الرسالة)
  static const Map<String, String> _eventToMessage = {
    // أحداث الأنمي
    'anime_added': 'add_anime',
    'anime_deleted': 'delete_anime',
    'anime_edited': 'edit_anime',
    'anime_completed': 'complete',
    'one_episode_left': 'one_episode_left',
    'episode_done': 'progress_congrats',
    'added_to_plan': 'added_to_plan',
    'added_to_watching': 'add_anime',

    // المفضلة والتقييم
    'favorite_added': 'favorite_added',
    'favorite_removed': 'remove_from_favorites',
    'high_rate': 'high_rate',
    'low_rate': 'low_rate',
    'rated': 'rated_anime',

    // النسخ الاحتياطي
    'backup_success': 'backup_success',
    'backup_failed': 'backup_fail',
    'restore_success': 'restore_success',
    'restore_failed': 'restore_fail',
    'export_success': 'backup_success',
    'import_success': 'restore_success',

    // التنقل
    'entered_home': 'idle',
    'entered_library': 'search_mode',
    'entered_memories': 'idle',
    'entered_settings': 'thinking',

    // الإعدادات
    'settings_changed': 'new_day',

    // أخرى
    'no_internet': 'no_internet',
    'empty_library': 'empty_library',
    'random_pick': 'random_pick',
    'thinking': 'thinking',
    'excited': 'excited',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _eventSub = AppEvents.stream.listen(_handleEvent);
  }

  void _handleEvent(String event) {
    final msgKey = _eventToMessage[event];
    if (msgKey != null && MangaMessages.all.containsKey(msgKey)) {
      FloatingMangaCharacter.say(msgKey);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FloatingMangaCharacter.say('welcome_back');
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

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
                colorScheme: ColorScheme.light(
                    primary: primaryColor,
                    secondary: primaryColor.withOpacity(0.7),
                    surface: Colors.white,
                    error: const Color(0xFFFF5A65)),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                scaffoldBackgroundColor: background,
                colorScheme: ColorScheme.dark(
                    primary: primaryColor,
                    secondary: primaryColor.withOpacity(0.7),
                    surface: panel,
                    error: const Color(0xFFFF5A65)),
                filledButtonTheme: FilledButtonThemeData(
                    style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 12,
                        shadowColor: primaryColor.withOpacity(0.8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                                color: primaryColor.withOpacity(0.6),
                                width: 1)))),
                navigationBarTheme: NavigationBarThemeData(
                    backgroundColor: panel,
                    indicatorColor: primaryColor,
                    elevation: 15,
                    shadowColor: primaryColor.withOpacity(0.6),
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    height: 72),
              ),
              builder: (context, child) {
                return Stack(
                  children: [
                    if (child != null) child,
                    ValueListenableBuilder<MangaCharacterConfig>(
                      valueListenable: mangaConfigNotifier,
                      builder: (context, config, _) {
                        if (!config.isVisible) return const SizedBox.shrink();
                        return Positioned.fill(
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: MangaCharacter(
                              size: config.size,
                              autoMove: config.autoMove,
                              enableBlink: config.enableBlink,
                              initialMessage: 'welcome_back',
                              margin: const EdgeInsets.only(
                                top: 16,
                                bottom: 100,
                                left: 16,
                                right: 16,
                              ),
                              hairColor: config.hairColor,
                              eyeColor: config.eyeColor,
                              skinTone: config.skinTone,
                              faceShape: config.faceShape,
                              hairStyle: config.hairStyle,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
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

  final List<Widget> screens = const [
    HomeScreen(),
    LibraryScreen(),
    MemoriesScreen(),
    SettingsScreen()
  ];

  // 🆕 حدث التنقل لكل تبويب
  static const List<String> _tabEvents = [
    'entered_home',
    'entered_library',
    'entered_memories',
    'entered_settings',
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
            child: IndexedStack(index: selectedIndex, children: screens)),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            setState(() => selectedIndex = index);
            AppEvents.fire(_tabEvents[index]); // 🆕 الشخصية تتفاعل مع التنقل
          },
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'الرئيسية'),
            NavigationDestination(
                icon: Icon(Icons.movie_creation_outlined),
                selectedIcon: Icon(Icons.movie_creation),
                label: 'المكتبة'),
            NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: 'ذكرياتي'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'الإعدادات'),
          ],
        ),
      ),
    );
  }
}
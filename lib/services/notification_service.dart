import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const int backupNotificationId = 1001;
  static const String _channelId = 'backup_channel';
  static const String _channelName = 'النسخ الاحتياطي';
  static const String _channelDesc = 'إشعارات تقدّم النسخ الاحتياطي';

  /// تهيئة الخدمة (تُستدعى مرة واحدة عند بدء التطبيق)
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// طلب إذن الإشعارات (Android 13+)
  Future<void> requestPermission() async {
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    } catch (_) {}
  }

  /// إشعار تقدّم مستمر (يبقى ظاهراً أثناء العملية)
  Future<void> showProgress({
    required String title,
    required String body,
    required int progress,
    required int total,
  }) async {
    await init();

    final safeTotal = total < 1 ? 1 : total;
    final safeProgress = progress.clamp(0, safeTotal);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: safeTotal,
      progress: safeProgress,
      indeterminate: false,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentSound: false,
      presentBadge: false,
    );

    await _plugin.show(
      backupNotificationId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  /// إشعار اكتمال (يختفي عند الضغط عليه)
  Future<void> showCompleted({required String body}) async {
    await init();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      autoCancel: true,
      ongoing: false,
      playSound: false,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: false,
    );

    await _plugin.show(
      backupNotificationId,
      '✅ اكتملت النسخة الاحتياطية',
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  /// إشعار فشل
  Future<void> showFailed({required String body}) async {
    await init();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
      ongoing: false,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    await _plugin.show(
      backupNotificationId,
      '❌ فشلت النسخة الاحتياطية',
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  /// إلغاء الإشعار الحالي (مثلاً عند إلغاء المستخدم للعملية)
  Future<void> cancelProgress() async {
    await init();
    await _plugin.cancel(backupNotificationId);
  }

  /// إلغاء كل الإشعارات
  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
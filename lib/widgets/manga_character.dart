import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
// 20 تعبير
// ══════════════════════════════════════════════════════════════
enum MangaExpression {
  neutral, happy, veryHappy, sad, angry, surprised, sleepy,
  love, starstruck, cool, thinking, confused, excited,
  sleepyHappy, wink, laugh, shy, determined, proud, silly,
}

class MangaMessage {
  final String text;
  final MangaExpression expression;
  const MangaMessage(this.text, this.expression);
}

// ══════════════════════════════════════════════════════════════
// 100 رسالة مصنفة
// ══════════════════════════════════════════════════════════════
class MangaMessages {
  static const Map<String, MangaMessage> all = {
    // ═══ 1. تحيات وترحيب (8) ═══
    'welcome_back': MangaMessage('مرحباً بعودتك! 👋\nاشتقت إليك!', MangaExpression.veryHappy),
    'morning_greeting': MangaMessage('صباح الخير يا أوتاكو! ☀️\nهل شاهدت شيئاً جديداً؟', MangaExpression.happy),
    'evening_greeting': MangaMessage('مساء الأنمي الجميل! 🌙\nوقت المشاهدة!', MangaExpression.sleepyHappy),
    'new_day': MangaMessage('يوم جديد! 🌅\nماذا ستشاهد؟', MangaExpression.happy),
    'good_night': MangaMessage('تصبح على خير! 😴\nأحلاماً أنمية!', MangaExpression.sleepy),
    'weekend_vibes': MangaMessage('نهاية الأسبوع! 🎉\nوقت الماراثون!', MangaExpression.excited),
    'friday_blessing': MangaMessage('جمعة مباركة! 🤲\nأنمي بعد الصلاة؟', MangaExpression.happy),
    'monday_blues': MangaMessage('اثنين... ثقيل! 😩\nخففه بأنمي!', MangaExpression.sad),

    // ═══ 2. حسب الوقت (8) ═══
    'late_night': MangaMessage('متأخر جداً! 🌃\nاذهب للنوم!', MangaExpression.sleepy),
    'early_morning': MangaMessage('فجراً؟! 😳\nأنت مجنون بالأنمي!', MangaExpression.surprised),
    'noon_break': MangaMessage('استراحة غداء؟ 🍱\nحلقة سريعة!', MangaExpression.happy),
    'afternoon_tea': MangaMessage('شاي العصر! ☕\nمع حلقة ممتعة!', MangaExpression.sleepyHappy),
    'sunset_glow': MangaMessage('وقت الغروب! 🌇\nمثالي للأنمي!', MangaExpression.love),
    'midnight': MangaMessage('منتصف الليل! 🕛\nهل ما زلت مستيقظاً؟', MangaExpression.sleepy),
    'before_dawn': MangaMessage('قبل الفجر؟! 🌌\nأسطورة حقيقية!', MangaExpression.starstruck),
    'lunchtime': MangaMessage('وقت الغداء! 🍜\nأنمي + أكل = سعادة!', MangaExpression.happy),

    // ═══ 3. إضافة/تعديل محتوى (15) ═══
    'add_anime': MangaMessage('أنمي جديد! رائع! 🎬\nأضفه للمكتبة!', MangaExpression.excited),
    'add_season': MangaMessage('موسم جديد! 📺\nمتابعة مستمرة!', MangaExpression.happy),
    'add_movie': MangaMessage('فيلم أنمي! 🎥\nاستمتع بالسينما!', MangaExpression.starstruck),
    'edit_anime': MangaMessage('تعديل بيانات؟ ✏️\nالبيانات محدّثة!', MangaExpression.thinking),
    'delete_anime': MangaMessage('حذفت أنمي؟ 😢\nستفتقده!', MangaExpression.sad),
    'favorite_added': MangaMessage('المفضلة! ❤️\nذوق رفيع!', MangaExpression.love),
    'remove_from_favorites': MangaMessage('أزلته من المفضلة؟ 💔\nتأكد من قرارك!', MangaExpression.shy),
    'import_backup': MangaMessage('نسخة مستوردة! 📥\nعاد كل شيء!', MangaExpression.veryHappy),
    'export_backup': MangaMessage('نسخة مصدّرة! 📤\nبياناتك آمنة!', MangaExpression.happy),
    'bulk_add': MangaMessage('إضافة جماعية؟! 🔥\nيا محترف!', MangaExpression.proud),
    'bulk_delete': MangaMessage('حذف جماعي؟! 😱\nكن حذراً!', MangaExpression.surprised),
    'update_cover': MangaMessage('غلاف جديد! 🖼️\nجميل جداً!', MangaExpression.happy),
    'update_rating': MangaMessage('تقييم جديد! ⭐\nدقة ملحوظة!', MangaExpression.determined),
    'mark_completed': MangaMessage('أكملته! ✅\nإنجاز رائع!', MangaExpression.veryHappy),
    'add_to_watching': MangaMessage('بدأت المتابعة! ▶️\nرحلة جديدة!', MangaExpression.excited),

    // ═══ 4. مشاهدة وتقدم (15) ═══
    'progress_congrats': MangaMessage('أكمل الحلقة! 🎯\nأنت تستطيع!', MangaExpression.determined),
    'episode_done': MangaMessage('حلقة إضافية! 📺\nمستمر بقوة!', MangaExpression.happy),
    'season_done': MangaMessage('أنهيت الموسم! 🎉\nأسطورة!', MangaExpression.veryHappy),
    'complete': MangaMessage('مبروك! أكملت أنمي! 🎉\nأنت أسطورة!', MangaExpression.veryHappy),
    'all_caught_up': MangaMessage('لحقت كل شيء! 🏃\nفي انتظار الجديد!', MangaExpression.proud),
    'watching_list': MangaMessage('لديك أنميات قيد المشاهدة!\nأكملها! 💪', MangaExpression.determined),
    'paused_watch': MangaMessage('توقفت مؤقتاً؟ ⏸️\nلا بأس، ارجع!', MangaExpression.shy),
    'dropped_anime': MangaMessage('أسقطته؟ 🗑️\nكان طويلاً؟', MangaExpression.thinking),
    'rewatch': MangaMessage('إعادة مشاهدة؟ 🔁\nأنمي يستحق!', MangaExpression.starstruck),
    'on_hold': MangaMessage('معلّق مؤقتاً! 📌\nلا تنساه!', MangaExpression.thinking),
    'one_more_episode': MangaMessage('حلقة أخرى فقط! 🌟\nهذه المرة الأخيرة!', MangaExpression.wink),
    'marathon_mode': MangaMessage('وضع الماراثون! 🏃‍♂️💨\nيلا نبدأ!', MangaExpression.excited),
    'halfway_there': MangaMessage('منتصف الطريق! 🌗\nاستمر!', MangaExpression.determined),
    'almost_done': MangaMessage('قريب جداً! 🌟\nالحلقة الأخيرة!', MangaExpression.excited),
    'started_new': MangaMessage('بداية جديدة! 🌱\nماذا سيحدث؟', MangaExpression.thinking),

    // ═══ 5. تقييمات (10) ═══
    'high_rate': MangaMessage('تقييم عالٍ! أعجبك حقاً! ⭐\nذوق رفيع!', MangaExpression.starstruck),
    'low_rate': MangaMessage('لم يعجبك؟ لا بأس،\nلكل ذوقه! 😅', MangaExpression.shy),
    'perfect_rate': MangaMessage('10/10؟! 👑\nيا لها من تحفة!', MangaExpression.starstruck),
    'mixed_feelings': MangaMessage('متردد؟ 🤔\nمتوسط التقييم؟', MangaExpression.thinking),
    'will_rewatch': MangaMessage('ستعيد مشاهدته؟ 🔁\nأنمي خالد!', MangaExpression.proud),
    'never_again': MangaMessage('لن تراه مجدداً! 🙅\nتعلمت الدرس!', MangaExpression.angry),
    'fair_rating': MangaMessage('تقييم عادل! ⚖️\nحكيم!', MangaExpression.proud),
    'emotionally_damaged': MangaMessage('أثر فيك؟ 😭\nأنمي يبقى بالقلب!', MangaExpression.sad),
    'masterpiece': MangaMessage('تحفة فنية! 🏆\nيستحق التاج!', MangaExpression.veryHappy),
    'overrated': MangaMessage('مبالغ فيه؟ 🤨\nرأيك يحترم!', MangaExpression.cool),

    // ═══ 6. إحصائيات المكتبة (10) ═══
    'many_animes': MangaMessage('مكتبتك تكبر! 📚\nيا لها من مجموعة!', MangaExpression.proud),
    'empty_library': MangaMessage('مكتبتك فارغة! 🌟\nأضف أول أنمي!', MangaExpression.sad),
    'library_growing': MangaMessage('المكتبة تنمو! 🌱\nاستمر هكذا!', MangaExpression.happy),
    'milestone_50': MangaMessage('50 أنمي؟! 🎊\nيا محترف!', MangaExpression.veryHappy),
    'milestone_100': MangaMessage('100 أنمي! 💯\nأسطورة حقيقية!', MangaExpression.starstruck),
    'milestone_500': MangaMessage('500 أنمي! 🏆\nيا إلهي!', MangaExpression.surprised),
    'milestone_1000': MangaMessage('1000 أنمي! 👑\nإمبراطور الأوتاكو!', MangaExpression.proud),
    'favorite_genre': MangaMessage('نوعك المفضل واضح! 🎯\nذوق مميز!', MangaExpression.cool),
    'genre_explorer': MangaMessage('تستكشف أنواعاً؟ 🧭\nمغامر!', MangaExpression.excited),
    'most_watched_genre': MangaMessage('هذا نوعك الأكثر! 📊\nتحليل دقيق!', MangaExpression.thinking),

    // ═══ 7. نسخ احتياطي (8) ═══
    'backup_success': MangaMessage('بياناتك آمنة! 💾\nعظيم جداً!', MangaExpression.happy),
    'backup_fail': MangaMessage('فشل النسخ! 😱\nلا تقلق، حاول مجدداً.', MangaExpression.surprised),
    'backup_in_progress': MangaMessage('جاري النسخ... ⏳\nانتظر قليلاً!', MangaExpression.thinking),
    'restore_success': MangaMessage('الاستعادة نجحت! 🎉\nكل شيء عاد!', MangaExpression.veryHappy),
    'restore_fail': MangaMessage('فشلت الاستعادة! 😢\nحاول مرة أخرى!', MangaExpression.sad),
    'backup_reminder': MangaMessage('تذكير: اعمل نسخة! 💾\nلا تفقد بياناتك!', MangaExpression.determined),
    'backup_taken': MangaMessage('نسخة أخيرة! 📸\nيوم محفوظ!', MangaExpression.proud),
    'backup_storage_full': MangaMessage('التخزين ممتلئ! 💽\nمساحة مطلوبة!', MangaExpression.surprised),

    // ═══ 8. أخطاء (8) ═══
    'no_internet': MangaMessage('لا إنترنت! 📖\nاقرأ مانغا بدلاً من ذلك!', MangaExpression.sad),
    'server_error': MangaMessage('خطأ في السيرفر! 🔧\nحاول لاحقاً!', MangaExpression.angry),
    'download_failed': MangaMessage('فشل التحميل! ⬇️\nأعد المحاولة!', MangaExpression.surprised),
    'upload_failed': MangaMessage('فشل الرفع! ⬆️\nلا تقلق!', MangaExpression.shy),
    'image_missing': MangaMessage('صورة مفقودة! 🖼️\nأضف واحدة!', MangaExpression.confused),
    'file_corrupted': MangaMessage('ملف تالف! 📁\nمشكلة خطيرة!', MangaExpression.angry),
    'permission_denied': MangaMessage('إذن مرفوض! 🔒\nافتح الإعدادات!', MangaExpression.determined),
    'api_limit': MangaMessage('تجاوزت الحد! 📊\nانتظر قليلاً!', MangaExpression.thinking),

    // ═══ 9. تفاعلات مباشرة (8) ═══
    'idle': MangaMessage('هل شاهدت شيئاً جديداً اليوم؟', MangaExpression.thinking),
    'random_pick': MangaMessage('اختيار عشوائي؟\nأنا أحب المفاجآت! 🎲', MangaExpression.wink),
    'filter_active': MangaMessage('تبحث عن شيء محدد؟ 👀\nدعني أساعدك!', MangaExpression.thinking),
    'search_mode': MangaMessage('ماذا تبحث عنه؟ 🔍\nأنا هنا!', MangaExpression.excited),
    'sort_change': MangaMessage('غيرت الترتيب! 🔄\nحسناً!', MangaExpression.happy),
    'view_change': MangaMessage('عرض جديد! 👁️\nأعجبك؟', MangaExpression.cool),
    'tickle_me': MangaMessage('هههه! دغدغتني! 😂\nتوقف!', MangaExpression.laugh),
    'peek_a_boo': MangaMessage('اختبأت! 🙈\nوجدتني؟', MangaExpression.silly),

    // ═══ 10. تحفيز (5) ═══
    'keep_watching': MangaMessage('استمر بالمشاهدة! 📺\nأنت رائع!', MangaExpression.determined),
    'you_can_do_it': MangaMessage('أنت تستطيع! 💪\nثق بنفسك!', MangaExpression.veryHappy),
    'take_a_break': MangaMessage('خذ استراحة! ☕\nصحتك أولاً!', MangaExpression.sleepyHappy),
    'drink_water': MangaMessage('اشرب ماء! 💧\nالعينان تحتاجان!', MangaExpression.happy),
    'be_proud': MangaMessage('كن فخوراً بنفسك! 🌟\nإنجازاتك رائعة!', MangaExpression.proud),

    // ═══ 11. مرح/فكاهي (5) ═══
    'plot_twist': MangaMessage('تويست في الأفق! 🌀\nشعرت بذلك!', MangaExpression.surprised),
    'spoiler_alert': MangaMessage('ممنوع الحرق! 🤐\nاحترم الآخرين!', MangaExpression.angry),
    'otaku_pride': MangaMessage('فخور بأوتاكويتك! 🎌\nلا تخفِها!', MangaExpression.proud),
    'anime_addict': MangaMessage('مدمن أنمي؟ 😅\nنحن كلنا!', MangaExpression.laugh),
    'waifu_husbando': MangaMessage('شخصيتك المفضلة؟ 💖\nقل لي!', MangaExpression.love),
  };

  /// إرجاع مفتاح رسالة عشوائي (يمكن استبعاد مفاتيح معينة)
  static String randomKey({Set<String> exclude = const {}}) {
    final keys = all.keys.where((k) => !exclude.contains(k)).toList();
    return keys[Random().nextInt(keys.length)];
  }
}

// ══════════════════════════════════════════════════════════════
// Widget الشخصية العائمة
// ══════════════════════════════════════════════════════════════
class MangaCharacter extends StatefulWidget {
  final double size;
  final String initialMessage;
  final bool autoMove;
  final bool enableBlink;
  final EdgeInsets margin;

  const MangaCharacter({
    super.key,
    this.size = 90,
    this.initialMessage = 'welcome_back',
    this.autoMove = true,
    this.enableBlink = true,
    this.margin = const EdgeInsets.all(16),
  });

  @override
  State<MangaCharacter> createState() => MangaCharacterState();
}

class MangaCharacterState extends State<MangaCharacter>
    with TickerProviderStateMixin {
  MangaExpression _expression = MangaExpression.happy;
  String? _currentMessage;
  bool? _bubbleOnLeft; // 🔒 تثبيت جهة الفقاعة عند أول ظهور

  Timer? _hideTimer;
  Timer? _idleTimer;
  Timer? _blinkTimer;

  // ─── حركة العوم (Lissajous) ──────────────
  late AnimationController _moveXController;
  late AnimationController _moveYController;

  // ─── الرمش ───────────────────────────────
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();

    // حركتان بترددين مختلفين → مسار عضوي لا يتكرر
    _moveXController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _moveYController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    )..repeat(reverse: true);

    // الرمش (180ms لكل رمشة)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _scheduleBlink();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showMessage(widget.initialMessage);
    });

    _startIdleTimer();
  }

  // ═══ منطق الرمش ═══
  void _scheduleBlink() {
    _blinkTimer?.cancel();
    if (!widget.enableBlink) return;
    // 2-6 ثوانٍ بين الرمشات
    final delay = Duration(milliseconds: 2000 + Random().nextInt(4000));
    _blinkTimer = Timer(delay, _doBlink);
  }

  Future<void> _doBlink() async {
    if (!mounted || !widget.enableBlink) return;
    await _blinkController.forward();
    if (!mounted) return;
    await _blinkController.reverse();
    if (!mounted) return;
    _scheduleBlink();
  }

  // ═══ رسائل تلقائية كل 40 ثانية ═══
  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(const Duration(seconds: 40), (timer) {
      if (_currentMessage == null && mounted) {
        _showRandomIdleMessage();
      }
    });
  }

  void _showRandomIdleMessage() {
    final now = DateTime.now();
    String msgKey;

    if (now.hour >= 22 || now.hour < 6) {
      msgKey = 'late_night';
    } else if (now.hour < 12) {
      msgKey = 'morning_greeting';
    } else if (now.hour >= 18) {
      msgKey = 'evening_greeting';
    } else {
      msgKey = MangaMessages.randomKey(exclude: {
        'welcome_back', 'good_night', 'late_night',
      });
    }

    showMessage(msgKey);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _idleTimer?.cancel();
    _blinkTimer?.cancel();
    _moveXController.dispose();
    _moveYController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  /// عرض رسالة محددة
  void showMessage(String messageKey) {
    final msg = MangaMessages.all[messageKey];
    if (msg == null || !mounted) return;

    _hideTimer?.cancel();
    setState(() {
      _currentMessage = msg.text;
      _expression = msg.expression;
      _bubbleOnLeft = null; // سيُحدَّد في أول build
    });

    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _currentMessage = null;
          _expression = MangaExpression.neutral;
          _bubbleOnLeft = null;
        });
      }
    });
  }

  /// عرض رسالة مخصصة
  void showCustomMessage(String text, MangaExpression expression) {
    if (!mounted) return;
    _hideTimer?.cancel();
    setState(() {
      _currentMessage = text;
      _expression = expression;
      _bubbleOnLeft = null;
    });

    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _currentMessage = null;
          _expression = MangaExpression.neutral;
          _bubbleOnLeft = null;
        });
      }
    });
  }

  void setExpression(MangaExpression expression) {
    if (!mounted) return;
    setState(() => _expression = expression);
  }

  void _onTap() {
    if (_currentMessage != null) {
      _hideTimer?.cancel();
      setState(() {
        _currentMessage = null;
        _expression = MangaExpression.wink;
        _bubbleOnLeft = null;
      });
    } else {
      showMessage(MangaMessages.randomKey());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.autoMove) {
      // نسخة ثابتة (توضع في Stack عادي مع Positioned)
      return _buildCharacterAndBubble(blinkValue: 0, tilt: 0, perspective: 1.0);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // الحماية من القيود اللانهائية
        if (!constraints.maxWidth.isFinite ||
            !constraints.maxHeight.isFinite ||
            constraints.maxWidth < widget.size + 60 ||
            constraints.maxHeight < widget.size + 60) {
          return _buildCharacterAndBubble(
              blinkValue: 0, tilt: 0, perspective: 1.0);
        }

        return AnimatedBuilder(
          animation: Listenable.merge([_moveXController, _moveYController, _blinkController]),
          builder: (context, _) {
            final tX = Curves.easeInOut.transform(_moveXController.value);
            final tY = Curves.easeInOut.transform(_moveYController.value);

            final maxX = max(0.0,
                constraints.maxWidth - widget.size - widget.margin.horizontal);
            final maxY = max(0.0,
                constraints.maxHeight - widget.size - widget.margin.vertical);

            final dx = widget.margin.left + maxX * tX;
            final dy = widget.margin.top + maxY * tY;

            // 🔮 منظور بسيط: يبدو أقرب (أكبر) في الأسفل، أبعد (أصغر) في الأعلى
            final perspective = 0.88 + tY * 0.24; // 0.88 → 1.12

            // 🌀 ميل بسيط حسب اتجاه الحركة
            final velocityX = _moveXController.value - tX; // تقريب
            final tilt = (velocityX * 0.3).clamp(-0.12, 0.12);

            // 🎯 تحديد جهة الفقاعة (مرة واحدة عند الظهور)
            _bubbleOnLeft ??= dx > constraints.maxWidth / 2;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // ظل أرضي
                Positioned(
                  left: dx + widget.size * 0.2 * perspective,
                  top: dy + widget.size * 0.95 * perspective,
                  child: Container(
                    width: widget.size * 0.6 * perspective,
                    height: 8 * perspective,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                // الشخصية + الفقاعة
                Positioned(
                  left: dx,
                  top: dy,
                  child: _buildCharacterAndBubble(
                    blinkValue: _blinkController.value,
                    tilt: tilt,
                    perspective: perspective,
                    bubbleOnLeft: _bubbleOnLeft ?? false,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCharacterAndBubble({
    required double blinkValue,
    required double tilt,
    required double perspective,
    bool bubbleOnLeft = false,
  }) {
    final character = GestureDetector(
      onTap: _onTap,
      child: Transform.rotate(
        angle: tilt,
        child: SizedBox(
          width: widget.size * perspective,
          height: widget.size * perspective,
          child: CustomPaint(
            painter: _MangaFacePainter(
              expression: _expression,
              blinkValue: blinkValue,
            ),
          ),
        ),
      ),
    );

    if (_currentMessage == null) return character;

    final bubble = Flexible(
      child: _buildSpeechBubble(_currentMessage!, bubbleOnLeft: bubbleOnLeft),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        textDirection: bubbleOnLeft ? TextDirection.rtl : TextDirection.ltr,
        children: [
          bubbleOnLeft ? bubble : character,
          if (bubbleOnLeft) character else bubble,
          if (bubbleOnLeft) const SizedBox(width: 4) else const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSpeechBubble(String message, {bool bubbleOnLeft = false}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: bubbleOnLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF202431), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// الرسم (مع تأثير 3D + رمش)
// ══════════════════════════════════════════════════════════════
class _MangaFacePainter extends CustomPainter {
  final MangaExpression expression;
  final double blinkValue;

  _MangaFacePainter({required this.expression, this.blinkValue = 0});

  bool get _isBlinking => blinkValue > 0.5;

  // التعبيرات التي تملك عيوناً "عادية" يمكنها أن ترمش
  static const Set<MangaExpression> _blinkable = {
    MangaExpression.neutral,
    MangaExpression.angry,
    MangaExpression.surprised,
    MangaExpression.thinking,
    MangaExpression.confused,
    MangaExpression.excited,
    MangaExpression.determined,
    MangaExpression.shy,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;

    // ─── ظل الوجه (خلفي - يمنح عمقاً) ────────
    canvas.drawCircle(
      Offset(cx + 2, cy + 4),
      r * 1.02,
      Paint()
        ..color = Colors.black.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // ─── الرأس بتدرج ثلاثي الأبعاد ────────────
    final faceRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final facePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35), // الإضاءة من أعلى اليسار
        radius: 1.3,
        colors: const [
          Color(0xFFFFF2D6), // إضاءة
          Color(0xFFFFE0BD), // متوسط
          Color(0xFFF0C096), // ظل
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(faceRect);
    canvas.drawCircle(Offset(cx, cy), r, facePaint);

    // ─── خط الرأس ────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // ─── الشعر بتدرج ─────────────────────────
    final hairRect = Rect.fromCircle(
        center: Offset(cx, cy - r * 0.5), radius: r * 1.1);
    final hairPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFF3A1F12), // داكن في الجذور
          Color(0xFF5A3222), // متوسط
          Color(0xFF2C1810), // ظل
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(hairRect);

    final hairPath = Path()
      ..moveTo(cx - r, cy - r * 0.3)
      ..quadraticBezierTo(cx - r * 0.9, cy - r * 1.15, cx, cy - r)
      ..quadraticBezierTo(cx + r * 0.9, cy - r * 1.15, cx + r, cy - r * 0.3)
      ..quadraticBezierTo(
          cx + r * 0.8, cy - r * 0.7, cx + r * 0.3, cy - r * 0.75)
      ..quadraticBezierTo(cx, cy - r * 0.95, cx - r * 0.3, cy - r * 0.75)
      ..quadraticBezierTo(
          cx - r * 0.8, cy - r * 0.7, cx - r, cy - r * 0.3)
      ..close();
    canvas.drawPath(hairPath, hairPaint);

    // لمعان على الشعر (specular highlight)
    canvas.drawPath(
      hairPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.5, -0.7),
          radius: 0.6,
          colors: [
            Colors.white.withOpacity(0.35),
            Colors.transparent,
          ],
        ).createShader(hairRect)
        ..blendMode = BlendMode.overlay,
    );

    // ─── وجنات (blush ناعم) ──────────────────
    if (expression == MangaExpression.love ||
        expression == MangaExpression.shy ||
        expression == MangaExpression.veryHappy ||
        expression == MangaExpression.laugh) {
      final blushRect = Rect.fromCenter(
          center: Offset(cx - r * 0.55, cy + r * 0.2),
          width: r * 0.4,
          height: r * 0.24);
      canvas.drawOval(
        blushRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFF9E9E).withOpacity(0.9),
              const Color(0xFFFF9E9E).withOpacity(0.0),
            ],
          ).createShader(blushRect),
      );
      final blushRect2 = Rect.fromCenter(
          center: Offset(cx + r * 0.55, cy + r * 0.2),
          width: r * 0.4,
          height: r * 0.24);
      canvas.drawOval(
        blushRect2,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFF9E9E).withOpacity(0.9),
              const Color(0xFFFF9E9E).withOpacity(0.0),
            ],
          ).createShader(blushRect2),
      );
    }

    // ─── العيون + الفم ───────────────────────
    _drawEyes(canvas, cx, cy, r);
    _drawMouth(canvas, cx, cy, r);

    // ─── الإكسسوارات ────────────────────────
    _drawAccessories(canvas, cx, cy, r);
  }

  void _drawEyes(Canvas canvas, double cx, double cy, double r) {
    // 🔮 الرمش يطغى على العيون (لكن فقط للأنواع القابلة للرمش)
    if (_isBlinking && _blinkable.contains(expression)) {
      final eyeY = cy - r * 0.05;
      final leftEyeX = cx - r * 0.35;
      final rightEyeX = cx + r * 0.35;
      final eyeSize = r * 0.18;
      final paint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(leftEyeX, eyeY),
            width: eyeSize * 2,
            height: eyeSize * 0.8),
        0,
        pi,
        false,
        paint,
      );
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(rightEyeX, eyeY),
            width: eyeSize * 2,
            height: eyeSize * 0.8),
        0,
        pi,
        false,
        paint,
      );
      return;
    }

    final eyeY = cy - r * 0.05;
    final leftEyeX = cx - r * 0.35;
    final rightEyeX = cx + r * 0.35;
    final eyeSize = r * 0.18;

    final blackPaint = Paint()..color = Colors.black;
    final whitePaint = Paint()..color = Colors.white;

    // 🎨 دالة مساعدة لرسم عين عادية بتدرج
    void drawNormalEye(double x) {
      final irisRect = Rect.fromCircle(
          center: Offset(x, eyeY), radius: eyeSize * 0.65);
      canvas.drawCircle(Offset(x, eyeY), eyeSize, whitePaint);
      canvas.drawCircle(
        Offset(x, eyeY),
        eyeSize * 0.65,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6B4423),
              Color(0xFF1A0F06),
            ],
          ).createShader(irisRect),
      );
      // لمعة العين
      canvas.drawCircle(
        Offset(x - eyeSize * 0.22, eyeY - eyeSize * 0.28),
        eyeSize * 0.28,
        whitePaint,
      );
    }

    switch (expression) {
      case MangaExpression.happy:
      case MangaExpression.veryHappy:
      case MangaExpression.laugh:
        final paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(leftEyeX, eyeY),
                width: eyeSize * 1.5,
                height: eyeSize),
            pi, pi, false, paint);
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(rightEyeX, eyeY),
                width: eyeSize * 1.5,
                height: eyeSize),
            pi, pi, false, paint);
        break;

      case MangaExpression.wink:
        drawNormalEye(leftEyeX);
        final paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(rightEyeX, eyeY),
                width: eyeSize * 1.5,
                height: eyeSize),
            pi, pi, false, paint);
        break;

      case MangaExpression.sleepy:
      case MangaExpression.sleepyHappy:
        final paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
            Offset(leftEyeX - eyeSize * 0.7, eyeY),
            Offset(leftEyeX + eyeSize * 0.7, eyeY), paint);
        canvas.drawLine(
            Offset(rightEyeX - eyeSize * 0.7, eyeY),
            Offset(rightEyeX + eyeSize * 0.7, eyeY), paint);
        break;

      case MangaExpression.sad:
        final paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(leftEyeX, eyeY + eyeSize * 0.3),
                width: eyeSize * 1.5,
                height: eyeSize),
            0, pi, false, paint);
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(rightEyeX, eyeY + eyeSize * 0.3),
                width: eyeSize * 1.5,
                height: eyeSize),
            0, pi, false, paint);
        // دمعة بتدرج
        final tearRect = Rect.fromCircle(
            center: Offset(rightEyeX + eyeSize * 0.6, eyeY + eyeSize * 1.2),
            radius: eyeSize * 0.35);
        canvas.drawCircle(
          Offset(rightEyeX + eyeSize * 0.6, eyeY + eyeSize * 1.2),
          eyeSize * 0.3,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.4, -0.4),
              colors: [Color(0xFFB3E5FC), Color(0xFF4FC3F7)],
            ).createShader(tearRect),
        );
        break;

      case MangaExpression.angry:
        drawNormalEye(leftEyeX);
        drawNormalEye(rightEyeX);
        final browPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
            Offset(leftEyeX - eyeSize, eyeY - eyeSize * 1.5),
            Offset(leftEyeX + eyeSize, eyeY - eyeSize * 0.8), browPaint);
        canvas.drawLine(
            Offset(rightEyeX + eyeSize, eyeY - eyeSize * 1.5),
            Offset(rightEyeX - eyeSize, eyeY - eyeSize * 0.8), browPaint);
        break;

      case MangaExpression.surprised:
        canvas.drawCircle(Offset(leftEyeX, eyeY), eyeSize * 1.3, whitePaint);
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize * 0.5, blackPaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize * 1.3, whitePaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize * 0.5, blackPaint);
        final linesPaint = Paint()
          ..color = Colors.black
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        for (int i = 0; i < 4; i++) {
          final a = i * pi / 2;
          canvas.drawLine(
              Offset(cx + cos(a) * (r * 0.55), eyeY + sin(a) * (r * 0.55)),
              Offset(cx + cos(a) * (r * 0.75), eyeY + sin(a) * (r * 0.75)),
              linesPaint);
        }
        break;

      case MangaExpression.love:
        _drawHeart(canvas, Offset(leftEyeX, eyeY), eyeSize * 1.5, Colors.pink);
        _drawHeart(
            canvas, Offset(rightEyeX, eyeY), eyeSize * 1.5, Colors.pink);
        break;

      case MangaExpression.starstruck:
        _drawStar(canvas, Offset(leftEyeX, eyeY), eyeSize * 1.5, Colors.amber);
        _drawStar(
            canvas, Offset(rightEyeX, eyeY), eyeSize * 1.5, Colors.amber);
        break;

      case MangaExpression.cool:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx, eyeY),
                width: r * 1.4,
                height: r * 0.4),
            const Radius.circular(4),
          ),
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A1A), Color(0xFF3A3A3A)],
            ).createShader(Rect.fromCenter(
                center: Offset(cx, eyeY),
                width: r * 1.4,
                height: r * 0.4)),
        );
        // انعكاس على النظارة
        canvas.drawLine(
            Offset(cx - r * 0.5, eyeY - r * 0.1),
            Offset(cx - r * 0.2, eyeY - r * 0.1),
            Paint()
              ..color = Colors.white.withOpacity(0.5)
              ..strokeWidth = 2);
        break;

      case MangaExpression.thinking:
        drawNormalEye(leftEyeX);
        canvas.drawCircle(Offset(rightEyeX, eyeY), eyeSize, whitePaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize * 0.4, blackPaint);
        break;

      case MangaExpression.confused:
        canvas.drawCircle(Offset(leftEyeX, eyeY), eyeSize * 1.2, whitePaint);
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize * 0.6, blackPaint);
        canvas.drawCircle(Offset(rightEyeX, eyeY), eyeSize * 0.8, whitePaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize * 0.5, blackPaint);
        break;

      case MangaExpression.excited:
        canvas.drawCircle(Offset(leftEyeX, eyeY), eyeSize * 1.2, whitePaint);
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize * 0.8, blackPaint);
        canvas.drawCircle(
            Offset(leftEyeX - eyeSize * 0.2, eyeY - eyeSize * 0.2),
            eyeSize * 0.3, whitePaint);
        canvas.drawCircle(Offset(rightEyeX, eyeY), eyeSize * 1.2, whitePaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize * 0.8, blackPaint);
        canvas.drawCircle(
            Offset(rightEyeX - eyeSize * 0.2, eyeY - eyeSize * 0.2),
            eyeSize * 0.3, whitePaint);
        break;

      case MangaExpression.determined:
        drawNormalEye(leftEyeX);
        drawNormalEye(rightEyeX);
        final browPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
            Offset(leftEyeX - eyeSize, eyeY - eyeSize * 1.3),
            Offset(leftEyeX + eyeSize, eyeY - eyeSize * 1.5), browPaint);
        canvas.drawLine(
            Offset(rightEyeX + eyeSize, eyeY - eyeSize * 1.3),
            Offset(rightEyeX - eyeSize, eyeY - eyeSize * 1.5), browPaint);
        break;

      case MangaExpression.proud:
        drawNormalEye(leftEyeX);
        drawNormalEye(rightEyeX);
        final lidPaint = Paint()..color = const Color(0xFFFFE0BD);
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset(leftEyeX, eyeY - eyeSize * 0.6),
                width: eyeSize * 2,
                height: eyeSize * 0.9),
            lidPaint);
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset(rightEyeX, eyeY - eyeSize * 0.6),
                width: eyeSize * 2,
                height: eyeSize * 0.9),
            lidPaint);
        break;

      case MangaExpression.silly:
        final paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(leftEyeX, eyeY),
                width: eyeSize * 1.5,
                height: eyeSize),
            pi, pi, false, paint);
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(rightEyeX, eyeY),
                width: eyeSize * 1.5,
                height: eyeSize),
            pi, pi, false, paint);
        break;

      case MangaExpression.neutral:
      case MangaExpression.shy:
      default:
        drawNormalEye(leftEyeX);
        drawNormalEye(rightEyeX);
    }
  }

  void _drawMouth(Canvas canvas, double cx, double cy, double r) {
    final mouthY = cy + r * 0.35;
    final blackPaint = Paint()..color = Colors.black;
    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    switch (expression) {
      case MangaExpression.happy:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, mouthY),
                width: r * 0.5,
                height: r * 0.3),
            0, pi, false, strokePaint);
        break;
      case MangaExpression.veryHappy:
      case MangaExpression.laugh:
        final path = Path()
          ..moveTo(cx - r * 0.35, mouthY)
          ..quadraticBezierTo(cx, mouthY + r * 0.5, cx + r * 0.35, mouthY)
          ..close();
        canvas.drawPath(path, blackPaint);
        break;
      case MangaExpression.sad:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, mouthY + r * 0.1),
                width: r * 0.4,
                height: r * 0.2),
            pi, pi, false, strokePaint);
        break;
      case MangaExpression.angry:
        final path = Path()
          ..moveTo(cx - r * 0.3, mouthY)
          ..lineTo(cx + r * 0.3, mouthY)
          ..lineTo(cx, mouthY + r * 0.2)
          ..close();
        canvas.drawPath(path, blackPaint);
        break;
      case MangaExpression.surprised:
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(cx, mouthY),
                width: r * 0.25,
                height: r * 0.35),
            blackPaint);
        break;
      case MangaExpression.sleepy:
      case MangaExpression.sleepyHappy:
      case MangaExpression.shy:
        canvas.drawLine(
            Offset(cx - r * 0.15, mouthY),
            Offset(cx + r * 0.15, mouthY), strokePaint);
        break;
      case MangaExpression.love:
        canvas.drawCircle(Offset(cx, mouthY), r * 0.12, blackPaint);
        break;
      case MangaExpression.starstruck:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, mouthY),
                width: r * 0.6,
                height: r * 0.4),
            0, pi, false, strokePaint);
        break;
      case MangaExpression.cool:
      case MangaExpression.wink:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, mouthY),
                width: r * 0.4,
                height: r * 0.2),
            0, pi, false, strokePaint);
        break;
      case MangaExpression.thinking:
        canvas.drawCircle(
            Offset(cx + r * 0.1, mouthY), r * 0.08, blackPaint);
        break;
      case MangaExpression.confused:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, mouthY),
                width: r * 0.4,
                height: r * 0.2),
            0, pi, false, strokePaint);
        break;
      case MangaExpression.excited:
        final path = Path()
          ..moveTo(cx - r * 0.3, mouthY)
          ..quadraticBezierTo(cx, mouthY + r * 0.35, cx + r * 0.3, mouthY)
          ..close();
        canvas.drawPath(path, blackPaint);
        break;
      case MangaExpression.determined:
        final path = Path()
          ..moveTo(cx - r * 0.3, mouthY)
          ..lineTo(cx + r * 0.3, mouthY)
          ..lineTo(cx, mouthY + r * 0.15)
          ..close();
        canvas.drawPath(path, blackPaint);
        break;
      case MangaExpression.proud:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, mouthY),
                width: r * 0.5,
                height: r * 0.25),
            0, pi, false, strokePaint);
        break;
      case MangaExpression.silly:
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(cx, mouthY),
                width: r * 0.4,
                height: r * 0.3),
            blackPaint);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(cx, mouthY + r * 0.1),
                width: r * 0.25,
                height: r * 0.18),
            Paint()..color = Colors.pink);
        break;
      case MangaExpression.neutral:
      default:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, mouthY),
                width: r * 0.3,
                height: r * 0.15),
            0, pi, false, strokePaint);
    }
  }

  void _drawAccessories(Canvas canvas, double cx, double cy, double r) {
    switch (expression) {
      case MangaExpression.surprised:
        final path = Path()
          ..moveTo(cx + r * 0.8, cy - r * 0.3)
          ..quadraticBezierTo(
              cx + r * 0.9, cy - r * 0.1, cx + r * 0.8, cy)
          ..quadraticBezierTo(
              cx + r * 0.7, cy - r * 0.1, cx + r * 0.8, cy - r * 0.3);
        canvas.drawPath(path, Paint()..color = Colors.lightBlue);
        break;
      case MangaExpression.angry:
        final angerPaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        final ax = cx + r * 0.7;
        final ay = cy - r * 0.7;
        canvas.drawLine(
            Offset(ax - 6, ay - 6), Offset(ax + 6, ay + 6), angerPaint);
        canvas.drawLine(
            Offset(ax + 6, ay - 6), Offset(ax - 6, ay + 6), angerPaint);
        break;
      case MangaExpression.thinking:
        canvas.drawCircle(Offset(cx + r * 0.9, cy - r * 0.7), r * 0.12,
            Paint()..color = Colors.white);
        canvas.drawCircle(
            Offset(cx + r * 0.9, cy - r * 0.7),
            r * 0.12,
            Paint()
              ..color = Colors.black26
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
        break;
      case MangaExpression.starstruck:
      case MangaExpression.excited:
        _drawStar(
            canvas, Offset(cx + r * 0.7, cy - r * 0.7), r * 0.2, Colors.amber);
        _drawStar(
            canvas, Offset(cx - r * 0.7, cy - r * 0.5), r * 0.15, Colors.amber);
        break;
      default:
        break;
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(center.dx, center.dy + size * 0.3);
    path.cubicTo(
      center.dx - size,
      center.dy - size * 0.5,
      center.dx - size * 0.5,
      center.dy - size,
      center.dx,
      center.dy - size * 0.3,
    );
    path.cubicTo(
      center.dx + size * 0.5,
      center.dy - size,
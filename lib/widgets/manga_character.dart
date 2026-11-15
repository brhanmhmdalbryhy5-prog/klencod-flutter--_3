import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../main.dart';

// ══════════════════════════════════════════════════════════════
// 20 تعبير
// ══════════════════════════════════════════════════════════════
enum MangaExpression {
  neutral, happy, veryHappy, sad, angry, surprised, sleepy,
  love, starstruck, cool, thinking, confused, excited,
  sleepyHappy, wink, laugh, shy, determined, proud, silly,
}

// ══════════════════════════════════════════════════════════════
// 20 رسالة مع تعبيرها المناسب
// ══════════════════════════════════════════════════════════════
class MangaMessage {
  final String text;
  final MangaExpression expression;
  const MangaMessage(this.text, this.expression);
}

// ══════════════════════════════════════════════════════════════
// الرسائل الـ20
// ══════════════════════════════════════════════════════════════
class MangaMessages {
  static const Map<String, MangaMessage> all = {
    'morning_greeting': MangaMessage('صباح الخير يا أوتاكو! ☀️\nهل شاهدت شيئاً جديداً؟', MangaExpression.happy),
    'evening_greeting': MangaMessage('مساء الأنمي الجميل! 🌙\nوقت المشاهدة!', MangaExpression.sleepyHappy),
    'idle': MangaMessage('هل شاهدت شيئاً جديداً اليوم؟', MangaExpression.thinking),
    'add_anime': MangaMessage('أنمي جديد! رائع! 🎬\nأضفه للمكتبة!', MangaExpression.excited),
    'complete': MangaMessage('مبروك! أكملت أنمي! 🎉\nأنت أسطورة!', MangaExpression.veryHappy),
    'high_rate': MangaMessage('تقييم عالٍ! أعجبك حقاً! ⭐\nذوق رفيع!', MangaExpression.starstruck),
    'low_rate': MangaMessage('لم يعجبك؟ لا بأس،\nلكل ذوقه! 😅', MangaExpression.shy),
    'many_animes': MangaMessage('مكتبتك تكبر! 📚\nيا لها من مجموعة!', MangaExpression.proud),
    'watching_list': MangaMessage('لديك أنميات قيد المشاهدة!\nأكملها! 💪', MangaExpression.determined),
    'no_internet': MangaMessage('لا إنترنت! 📖\nاقرأ مانغا بدلاً من ذلك!', MangaExpression.sad),
    'backup_success': MangaMessage('بياناتك آمنة! 💾\nعظيم جداً!', MangaExpression.happy),
    'backup_fail': MangaMessage('فشل النسخ! 😱\nلا تقلق، حاول مجدداً.', MangaExpression.surprised),
    'random_pick': MangaMessage('اختيار عشوائي؟\nأنا أحب المفاجآت! 🎲', MangaExpression.wink),
    'filter_active': MangaMessage('تبحث عن شيء محدد؟ 👀\nدعني أساعدك!', MangaExpression.thinking),
    'empty_library': MangaMessage('مكتبتك فارغة! 🌟\nأضف أول أنمي!', MangaExpression.sad),
    'favorite_added': MangaMessage('المفضلة! ❤️\nذوق رفيع!', MangaExpression.love),
    'progress_congrats': MangaMessage('أكمل الحلقة! 🎯\nأنت تستطيع!', MangaExpression.determined),
    'late_night': MangaMessage('متأخر! 😴\nاذهب للنوم!', MangaExpression.sleepy),
    'new_day': MangaMessage('يوم جديد! 🌅\nماذا ستشاهد؟', MangaExpression.happy),
    'welcome_back': MangaMessage('مرحباً بعودتك! 👋\nاشتقت إليك!', MangaExpression.veryHappy),
  };
}

// ══════════════════════════════════════════════════════════════
// Widget الشخصية العائمة
// ══════════════════════════════════════════════════════════════
class MangaCharacter extends StatefulWidget {
  final double size;
  final String initialMessage;

  const MangaCharacter({
    super.key,
    this.size = 90,
    this.initialMessage = 'welcome_back',
  });

  @override
  State<MangaCharacter> createState() => MangaCharacterState();
}

class MangaCharacterState extends State<MangaCharacter>
    with SingleTickerProviderStateMixin {
  MangaExpression _expression = MangaExpression.happy;
  String? _currentMessage;
  Timer? _hideTimer;
  Timer? _idleTimer;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: -3, end: 3).animate(
      CurvedAnimation(
          parent: _bounceController, curve: Curves.easeInOut),
    );

    // رسالة الترحيب
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showMessage(widget.initialMessage);
    });

    // جلب رسالة تلقائية كل 40 ثانية
    _startIdleTimer();
  }

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
      const idleOptions = [
        'idle',
        'progress_congrats',
        'watching_list',
        'random_pick',
      ];
      msgKey =
          idleOptions[Random().nextInt(idleOptions.length)];
    }

    showMessage(msgKey);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _idleTimer?.cancel();
    _bounceController.dispose();
    super.dispose();
  }

  /// عرض رسالة محددة
  void showMessage(String messageKey) {
    final msg = MangaMessages.all[messageKey];
    if (msg == null) return;

    _hideTimer?.cancel();
    if (!mounted) return;

    setState(() {
      _currentMessage = msg.text;
      _expression = msg.expression;
    });

    // إخفاء بعد 5 ثوانٍ
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _currentMessage = null;
          _expression = MangaExpression.neutral;
        });
      }
    });
  }

  /// عرض رسالة مخصصة
  void showCustomMessage(String text, MangaExpression expression) {
    _hideTimer?.cancel();
    if (!mounted) return;

    setState(() {
      _currentMessage = text;
      _expression = expression;
    });

    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _currentMessage = null;
          _expression = MangaExpression.neutral;
        });
      }
    });
  }

  /// تغيير التعبير فقط
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
      });
    } else {
      final allKeys = MangaMessages.all.keys.toList();
      showMessage(allKeys[Random().nextInt(allKeys.length)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: SizedBox(
        height: widget.size + 40,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // الشخصية
            AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _bounceAnimation.value),
                  child: child,
                );
              },
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _MangaFacePainter(_expression),
                ),
              ),
            ),

            // فقاعة الكلام
            if (_currentMessage != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: _buildSpeechBubble(_currentMessage!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpeechBubble(String message) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.centerRight,
          child: child,
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // الفقاعة
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF202431), width: 2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 1),
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
          // السهم (مثلث صغير)
          Positioned(
            left: -6,
            top: 16,
            child: CustomPaint(
              size: const Size(10, 12),
              painter: _BubbleTailPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// رسم سهم الفقاعة
// ══════════════════════════════════════════════════════════════
class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF202431)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════
// رسم الوجه (20 تعبير)
// ══════════════════════════════════════════════════════════════
class _MangaFacePainter extends CustomPainter {
  final MangaExpression expression;

  _MangaFacePainter(this.expression);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;

    // ─── الرأس ───────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = const Color(0xFFFFE0BD),
    );

    // ─── خطوط الرأس ─────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // ─── الشعر ───────────────────────────────────
    final hairPaint = Paint()..color = const Color(0xFF2C1810);
    final hairPath = Path()
      ..moveTo(cx - r, cy - r * 0.3)
      ..quadraticBezierTo(cx - r * 0.9, cy - r * 1.15, cx, cy - r)
      ..quadraticBezierTo(cx + r * 0.9, cy - r * 1.15, cx + r, cy - r * 0.3)
      ..quadraticBezierTo(cx + r * 0.8, cy - r * 0.7, cx + r * 0.3, cy - r * 0.75)
      ..quadraticBezierTo(cx, cy - r * 0.95, cx - r * 0.3, cy - r * 0.75)
      ..quadraticBezierTo(cx - r * 0.8, cy - r * 0.7, cx - r, cy - r * 0.3)
      ..close();
    canvas.drawPath(hairPath, hairPaint);

    // ─── الوجنتان ────────────────────────────────
    if (expression == MangaExpression.love ||
        expression == MangaExpression.shy ||
        expression == MangaExpression.veryHappy ||
        expression == MangaExpression.laugh) {
      final blushPaint = Paint()..color = const Color(0xFFFF9E9E);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx - r * 0.55, cy + r * 0.2),
              width: r * 0.35,
              height: r * 0.2),
          blushPaint);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx + r * 0.55, cy + r * 0.2),
              width: r * 0.35,
              height: r * 0.2),
          blushPaint);
    }

    // ─── العيون + الفم ───────────────────────────
    _drawEyes(canvas, cx, cy, r);
    _drawMouth(canvas, cx, cy, r);

    // ─── الإكسسوارات ────────────────────────────
    _drawAccessories(canvas, cx, cy, r);
  }

  void _drawEyes(Canvas canvas, double cx, double cy, double r) {
    final eyeY = cy - r * 0.05;
    final leftEyeX = cx - r * 0.35;
    final rightEyeX = cx + r * 0.35;
    final eyeSize = r * 0.18;

    final blackPaint = Paint()..color = Colors.black;
    final whitePaint = Paint()..color = Colors.white;

    switch (expression) {
      case MangaExpression.happy:
      case MangaExpression.veryHappy:
      case MangaExpression.laugh:
        // عيون مقوسة (^_^)
        final paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(leftEyeX, eyeY),
                width: eyeSize * 1.5,
                height: eyeSize),
            pi,
            pi,
            false,
            paint);
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(rightEyeX, eyeY),
                width: eyeSize * 1.5,
                height: eyeSize),
            pi,
            pi,
            false,
            paint);
        break;

      case MangaExpression.wink:
        // يسار مفتوح، يمين مغمض
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize, whitePaint);
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize * 0.6, blackPaint);
        final paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(rightEyeX, eyeY),
                width: eyeSize * 1.5,
                height: eyeSize),
            pi,
            pi,
            false,
            paint);
        break;

      case MangaExpression.sleepy:
      case MangaExpression.sleepyHappy:
        // عيون مغلقة تماماً
        final paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(leftEyeX - eyeSize * 0.7, eyeY),
          Offset(leftEyeX + eyeSize * 0.7, eyeY),
          paint,
        );
        canvas.drawLine(
          Offset(rightEyeX - eyeSize * 0.7, eyeY),
          Offset(rightEyeX + eyeSize * 0.7, eyeY),
          paint,
        );
        break;

      case MangaExpression.sad:
        // عيون منحنية للأسفل
        final paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(leftEyeX, eyeY + eyeSize * 0.3),
                width: eyeSize * 1.5,
                height: eyeSize),
            0,
            pi,
            false,
            paint);
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(rightEyeX, eyeY + eyeSize * 0.3),
                width: eyeSize * 1.5,
                height: eyeSize),
            0,
            pi,
            false,
            paint);
        // دمعة
        final tearPaint = Paint()..color = Colors.lightBlue;
        canvas.drawCircle(
            Offset(rightEyeX + eyeSize * 0.6, eyeY + eyeSize * 1.2),
            eyeSize * 0.3,
            tearPaint);
        break;

      case MangaExpression.angry:
        // عيون حادة + حواجب
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize, whitePaint);
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize * 0.6, blackPaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize, whitePaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize * 0.6, blackPaint);
        final browPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(leftEyeX - eyeSize, eyeY - eyeSize * 1.5),
          Offset(leftEyeX + eyeSize, eyeY - eyeSize * 0.8),
          browPaint,
        );
        canvas.drawLine(
          Offset(rightEyeX + eyeSize, eyeY - eyeSize * 1.5),
          Offset(rightEyeX - eyeSize, eyeY - eyeSize * 0.8),
          browPaint,
        );
        break;

      case MangaExpression.surprised:
        // عيون كبيرة جداً
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize * 1.3, whitePaint);
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize * 0.5, blackPaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize * 1.3, whitePaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize * 0.5, blackPaint);
        // خطوط حول العين
        final linesPaint = Paint()
          ..color = Colors.black
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        for (int i = 0; i < 4; i++) {
          final a = i * pi / 2;
          canvas.drawLine(
            Offset(cx + cos(a) * (r * 0.55),
                eyeY + sin(a) * (r * 0.55)),
            Offset(cx + cos(a) * (r * 0.75),
                eyeY + sin(a) * (r * 0.75)),
            linesPaint,
          );
        }
        break;

      case MangaExpression.love:
        // عيون قلوب
        _drawHeart(canvas,
            Offset(leftEyeX, eyeY), eyeSize * 1.5, Colors.pink);
        _drawHeart(canvas,
            Offset(rightEyeX, eyeY), eyeSize * 1.5, Colors.pink);
        break;

      case MangaExpression.starstruck:
        // عيون نجوم
        _drawStar(canvas,
            Offset(leftEyeX, eyeY), eyeSize * 1.5, Colors.amber);
        _drawStar(canvas,
            Offset(rightEyeX, eyeY), eyeSize * 1.5, Colors.amber);
        break;

      case MangaExpression.cool:
        // نظارة سوداء
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx, eyeY),
                width: r * 1.4,
                height: r * 0.4),
            const Radius.circular(4),
          ),
          blackPaint,
        );
        break;

      case MangaExpression.thinking:
        // عين واحدة مفتوحة، الأخرى نصف مغمضة
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize, whitePaint);
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize * 0.6, blackPaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize, whitePaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize * 0.4, blackPaint);
        break;

      case MangaExpression.confused:
        // عيون بأحجام مختلفة
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize * 1.2, whitePaint);
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize * 0.6, blackPaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize * 0.8, whitePaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize * 0.5, blackPaint);
        break;

      case MangaExpression.excited:
        // عيون كبيرة مشعة
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize * 1.2, whitePaint);
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize * 0.8, blackPaint);
        canvas.drawCircle(
            Offset(leftEyeX - eyeSize * 0.2,
                eyeY - eyeSize * 0.2),
            eyeSize * 0.3,
            whitePaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize * 1.2, whitePaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize * 0.8, blackPaint);
        canvas.drawCircle(
            Offset(rightEyeX - eyeSize * 0.2,
                eyeY - eyeSize * 0.2),
            eyeSize * 0.3,
            whitePaint);
        break;

      case MangaExpression.determined:
        // عيون مشددة
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize, whitePaint);
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize * 0.7, blackPaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize, whitePaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize * 0.7, blackPaint);
        final browPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(leftEyeX - eyeSize, eyeY - eyeSize * 1.3),
          Offset(leftEyeX + eyeSize, eyeY - eyeSize * 1.5),
          browPaint,
        );
        canvas.drawLine(
          Offset(rightEyeX + eyeSize, eyeY - eyeSize * 1.3),
          Offset(rightEyeX - eyeSize, eyeY - eyeSize * 1.5),
          browPaint,
        );
        break;

      case MangaExpression.proud:
        // عيون نصف مغمضة بثقة
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize, whitePaint);
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize * 0.6, blackPaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize, whitePaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize * 0.6, blackPaint);
        // نصف جفن
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
        // عينان مغمضتان + لسان
        final paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(leftEyeX, eyeY),
                width: eyeSize * 1.5,
                height: eyeSize),
            pi,
            pi,
            false,
            paint);
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(rightEyeX, eyeY),
                width: eyeSize * 1.5,
                height: eyeSize),
            pi,
            pi,
            false,
            paint);
        break;

      case MangaExpression.neutral:
      default:
        // عيون عادية
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize, whitePaint);
        canvas.drawCircle(
            Offset(leftEyeX, eyeY), eyeSize * 0.65, blackPaint);
        canvas.drawCircle(
            Offset(leftEyeX - eyeSize * 0.2,
                eyeY - eyeSize * 0.25),
            eyeSize * 0.25,
            whitePaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize, whitePaint);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize * 0.65, blackPaint);
        canvas.drawCircle(
            Offset(rightEyeX - eyeSize * 0.2,
                eyeY - eyeSize * 0.25),
            eyeSize * 0.25,
            whitePaint);
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
            0,
            pi,
            false,
            strokePaint);
        break;

      case MangaExpression.veryHappy:
      case MangaExpression.laugh:
        // فم كبير مفتوح
        final path = Path()
          ..moveTo(cx - r * 0.35, mouthY)
          ..quadraticBezierTo(
              cx, mouthY + r * 0.5, cx + r * 0.35, mouthY)
          ..close();
        canvas.drawPath(path, blackPaint);
        break;

      case MangaExpression.sad:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, mouthY + r * 0.1),
                width: r * 0.4,
                height: r * 0.2),
            pi,
            pi,
            false,
            strokePaint);
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
        canvas.drawLine(
          Offset(cx - r * 0.15, mouthY),
          Offset(cx + r * 0.15, mouthY),
          strokePaint,
        );
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
            0,
            pi,
            false,
            strokePaint);
        break;

      case MangaExpression.cool:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, mouthY),
                width: r * 0.3,
                height: r * 0.15),
            0,
            pi,
            false,
            strokePaint);
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
            0,
            pi,
            false,
            strokePaint);
        break;

      case MangaExpression.excited:
        final path = Path()
          ..moveTo(cx - r * 0.3, mouthY)
          ..quadraticBezierTo(
              cx, mouthY + r * 0.35, cx + r * 0.3, mouthY)
          ..close();
        canvas.drawPath(path, blackPaint);
        break;

      case MangaExpression.wink:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, mouthY),
                width: r * 0.4,
                height: r * 0.2),
            0,
            pi,
            false,
            strokePaint);
        break;

      case MangaExpression.shy:
        canvas.drawLine(
          Offset(cx - r * 0.1, mouthY),
          Offset(cx + r * 0.1, mouthY),
          strokePaint,
        );
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
            0,
            pi,
            false,
            strokePaint);
        break;

      case MangaExpression.silly:
        // فم مفتوح + لسان
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
            0,
            pi,
            false,
            strokePaint);
    }
  }

  void _drawAccessories(Canvas canvas, double cx, double cy, double r) {
    switch (expression) {
      case MangaExpression.surprised:
        // قطرة عرق
        final sweatPaint = Paint()..color = Colors.lightBlue;
        final path = Path()
          ..moveTo(cx + r * 0.8, cy - r * 0.3)
          ..quadraticBezierTo(
              cx + r * 0.9, cy - r * 0.1, cx + r * 0.8, cy)
          ..quadraticBezierTo(
              cx + r * 0.7, cy - r * 0.1, cx + r * 0.8, cy - r * 0.3);
        canvas.drawPath(path, sweatPaint);
        break;

      case MangaExpression.angry:
        // علامة غضب
        final angerPaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        final ax = cx + r * 0.7;
        final ay = cy - r * 0.7;
        canvas.drawLine(Offset(ax - 6, ay - 6),
            Offset(ax + 6, ay + 6), angerPaint);
        canvas.drawLine(Offset(ax + 6, ay - 6),
            Offset(ax - 6, ay + 6), angerPaint);
        break;

      case MangaExpression.thinking:
        // نقطة تفكير
        canvas.drawCircle(Offset(cx + r * 0.9, cy - r * 0.7),
            r * 0.12, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(cx + r * 0.9, cy - r * 0.7),
            r * 0.12,
            Paint()
              ..color = Colors.black26
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
        break;

      case MangaExpression.starstruck:
      case MangaExpression.excited:
        // بريق
        final sparklePaint = Paint()..color = Colors.amber;
        _drawStar(canvas, Offset(cx + r * 0.7, cy - r * 0.7),
            r * 0.2, Colors.amber);
        _drawStar(canvas, Offset(cx - r * 0.7, cy - r * 0.5),
            r * 0.15, Colors.amber);
        break;

      default:
        break;
    }
  }

  void _drawHeart(
      Canvas canvas, Offset center, double size, Color color) {
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
      center.dx + size,
      center.dy - size * 0.5,
      center.dx,
      center.dy + size * 0.3,
    );
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawStar(
      Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = -pi / 2 + i * 2 * pi / 5;
      final innerAngle = outerAngle + pi / 5;
      final outerX = center.dx + cos(outerAngle) * size;
      final outerY = center.dy + sin(outerAngle) * size;
      final innerX = center.dx + cos(innerAngle) * size * 0.4;
      final innerY = center.dy + sin(innerAngle) * size * 0.4;
      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MangaFacePainter oldDelegate) =>
      oldDelegate.expression != expression;
}
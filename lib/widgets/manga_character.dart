import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
// أنماط الوجه والشعر
// ══════════════════════════════════════════════════════════════
enum FaceShape { round, oval, square }
enum HairStyle { spiky, short, long, ponytail }

extension FaceShapeLabel on FaceShape {
  String get label => switch (this) {
        FaceShape.round => 'دائري',
        FaceShape.oval => 'بيضاوي',
        FaceShape.square => 'مربع',
      };
  IconData get icon => switch (this) {
        FaceShape.round => Icons.circle_outlined,
        FaceShape.oval => Icons.crop_portrait,
        FaceShape.square => Icons.crop_square,
      };
}

extension HairStyleLabel on HairStyle {
  String get label => switch (this) {
        HairStyle.spiky => 'شائك',
        HairStyle.short => 'قصير',
        HairStyle.long => 'طويل',
        HairStyle.ponytail => 'ذيل فرس',
      };
  IconData get icon => switch (this) {
        HairStyle.spiky => Icons.flare,
        HairStyle.short => Icons.short_text,
        HairStyle.long => Icons.gradient,
        HairStyle.ponytail => Icons.alt_route,
      };
}

// ══════════════════════════════════════════════════════════════
// التعبيرات
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
// الرسائل (تمت إضافة رسائل للأحداث الجديدة)
// ══════════════════════════════════════════════════════════════
class MangaMessages {
  static const Map<String, MangaMessage> all = {
    'welcome_back': MangaMessage('مرحباً بعودتك! 👋\nاشتقت إليك!', MangaExpression.veryHappy),
    'morning_greeting': MangaMessage('صباح الخير يا أوتاكو! ☀️\nهل شاهدت شيئاً جديداً؟', MangaExpression.happy),
    'evening_greeting': MangaMessage('مساء الأنمي الجميل! 🌙\nوقت المشاهدة!', MangaExpression.sleepyHappy),
    'new_day': MangaMessage('يوم جديد! 🌅\nماذا ستشاهد؟', MangaExpression.happy),
    'good_night': MangaMessage('تصبح على خير! 😴\nأحلاماً أنمية!', MangaExpression.sleepy),
    'weekend_vibes': MangaMessage('نهاية الأسبوع! 🎉\nوقت الماراثون!', MangaExpression.excited),
    'friday_blessing': MangaMessage('جمعة مباركة! 🤲\nأنمي بعد الصلاة؟', MangaExpression.happy),
    'monday_blues': MangaMessage('اثنين... ثقيل! 😩\nخففه بأنمي!', MangaExpression.sad),
    'late_night': MangaMessage('متأخر جداً! 🌃\nاذهب للنوم!', MangaExpression.sleepy),
    'early_morning': MangaMessage('فجراً؟! 😳\nأنت مجنون بالأنمي!', MangaExpression.surprised),
    'noon_break': MangaMessage('استراحة غداء؟ 🍱\nحلقة سريعة!', MangaExpression.happy),
    'afternoon_tea': MangaMessage('شاي العصر! ☕\nمع حلقة ممتعة!', MangaExpression.sleepyHappy),
    'sunset_glow': MangaMessage('وقت الغروب! 🌇\nمثالي للأنمي!', MangaExpression.love),
    'midnight': MangaMessage('منتصف الليل! 🕛\nهل ما زلت مستيقظاً؟', MangaExpression.sleepy),
    'before_dawn': MangaMessage('قبل الفجر؟! 🌌\nأسطورة حقيقية!', MangaExpression.starstruck),
    'lunchtime': MangaMessage('وقت الغداء! 🍜\nأنمي + أكل = سعادة!', MangaExpression.happy),
    
    // أحداث إضافة وتعديل
    'add_anime': MangaMessage('أنمي جديد! رائع! 🎬\nأضفه للمكتبة!', MangaExpression.excited),
    'add_season': MangaMessage('موسم جديد! 📺\nمتابعة مستمرة!', MangaExpression.happy),
    'add_movie': MangaMessage('فيلم أنمي! 🎥\nاستمتع بالسينما!', MangaExpression.starstruck),
    'edit_anime': MangaMessage('تعديل بيانات؟ ✏️\nالبيانات محدّثة!', MangaExpression.thinking),
    'delete_anime': MangaMessage('حذفت أنمي؟ 😢\nستفتقده!', MangaExpression.sad),
    'favorite_added': MangaMessage('المفضلة! ❤️\nذوق رفيع!', MangaExpression.love),
    'remove_from_favorites': MangaMessage('أزلته من المفضلة؟ 💔\nتأكد من قرارك!', MangaExpression.shy),
    
    // أحداث المشاهدة والتقييم
    'progress_congrats': MangaMessage('أكمل الحلقة! 🎯\nأنت تستطيع!', MangaExpression.determined),
    'episode_done': MangaMessage('حلقة إضافية! 📺\nمستمر بقوة!', MangaExpression.happy),
    'one_episode_left': MangaMessage('متبقي حلقة واحدة فقط! 🔥\nلا تتوقف الآن!', MangaExpression.excited),
    'complete': MangaMessage('مبروك! أكملت الأنمي! 🎉\nأنت أسطورة!', MangaExpression.veryHappy),
    'added_to_plan': MangaMessage('أضفته للمخطط؟ 📌\nلا تنساه!', MangaExpression.determined),
    'rated_anime': MangaMessage('تقييم جديد! ⭐\nرأيك يهمنا!', MangaExpression.thinking),
    'high_rate': MangaMessage('تقييم عالٍ! أعجبك حقاً! ⭐\nذوق رفيع!', MangaExpression.starstruck),
    'low_rate': MangaMessage('لم يعجبك؟ لا بأس،\nلكل ذوقه! 😅', MangaExpression.shy),
    
    // رسائل أخرى
    'idle': MangaMessage('هل شاهدت شيئاً جديداً اليوم؟', MangaExpression.thinking),
    'random_pick': MangaMessage('اختيار عشوائي؟\nأنا أحب المفاجآت! 🎲', MangaExpression.wink),
    'empty_library': MangaMessage('مكتبتك فارغة! 🌟\nأضف أول أنمي!', MangaExpression.sad),
    'backup_success': MangaMessage('بياناتك آمنة! 💾\nعظيم جداً!', MangaExpression.happy),
    'backup_fail': MangaMessage('فشل النسخ! 😱\nلا تقلق، حاول مجدداً.', MangaExpression.surprised),
    'no_internet': MangaMessage('لا إنترنت! 📖\nاقرأ مانغا بدلاً من ذلك!', MangaExpression.sad),
    'thinking': MangaMessage('دعني أفكر معك... 🤔', MangaExpression.thinking),
    'excited': MangaMessage('ياي! هذا رائع! 🎉', MangaExpression.veryHappy),
  };

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
  final Color hairColor;
  final Color eyeColor;
  final Color skinTone;
  final FaceShape faceShape;
  final HairStyle hairStyle;

  const MangaCharacter({
    super.key,
    this.size = 90,
    this.initialMessage = 'welcome_back',
    this.autoMove = true,
    this.enableBlink = true,
    this.margin = const EdgeInsets.all(16),
    this.hairColor = const Color(0xFF2C1810),
    this.eyeColor = const Color(0xFF1A0F06),
    this.skinTone = const Color(0xFFFFE0BD),
    this.faceShape = FaceShape.round,
    this.hairStyle = HairStyle.spiky,
  });

  @override
  State<MangaCharacter> createState() => MangaCharacterState();
}

class MangaCharacterState extends State<MangaCharacter>
    with TickerProviderStateMixin {
  MangaExpression _expression = MangaExpression.happy;
  String? _currentMessage;
  bool? _bubbleOnLeft;

  Timer? _hideTimer;
  Timer? _idleTimer;
  Timer? _blinkTimer;

  late AnimationController _moveXController;
  late AnimationController _moveYController;
  late AnimationController _blinkController;

  // 🆕 متغيرات السحب اليدوي
  Offset _manualOffset = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();

    _moveXController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _moveYController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    )..repeat(reverse: true);

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

  @override
  void didUpdateWidget(covariant MangaCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.autoMove != oldWidget.autoMove) {
      if (widget.autoMove) {
        _moveXController.repeat(reverse: true);
        _moveYController.repeat(reverse: true);
      } else {
        _moveXController.stop();
        _moveYController.stop();
      }
    }

    if (widget.enableBlink != oldWidget.enableBlink) {
      if (widget.enableBlink) {
        _scheduleBlink();
      } else {
        _blinkTimer?.cancel();
        _blinkController.reset();
      }
    }
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    if (!widget.enableBlink) return;
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

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(const Duration(seconds: 40), (timer) {
      if (_currentMessage == null && mounted) _showRandomIdleMessage();
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

  void showMessage(String messageKey) {
    final msg = MangaMessages.all[messageKey];
    if (msg == null || !mounted) return;

    _hideTimer?.cancel();
    setState(() {
      _currentMessage = msg.text;
      _expression = msg.expression;
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

  // 🆕 معالجة السحب
  void _onPanStart(DragStartDetails details) {
    if (widget.autoMove) {
      _moveXController.stop();
      _moveYController.stop();
    }
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _manualOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
    if (widget.autoMove) {
      _moveXController.repeat(reverse: true);
      _moveYController.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.autoMove && _manualOffset == Offset.zero) {
      return Align(
        alignment: Alignment.bottomLeft,
        child: _buildCharacterAndBubble(
            blinkValue: 0, tilt: 0, perspective: 1.0),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite ||
            !constraints.maxHeight.isFinite) {
          return Align(
            alignment: Alignment.bottomLeft,
            child: _buildCharacterAndBubble(
                blinkValue: 0, tilt: 0, perspective: 1.0),
          );
        }

        return AnimatedBuilder(
          animation: Listenable.merge(
              [_moveXController, _moveYController, _blinkController]),
          builder: (context, _) {
            final tX = widget.autoMove && !_isDragging
                ? Curves.easeInOut.transform(_moveXController.value)
                : _moveXController.value;
            final tY = widget.autoMove && !_isDragging
                ? Curves.easeInOut.transform(_moveYController.value)
                : _moveYController.value;

            final maxX = max(0.0,
                constraints.maxWidth - widget.size - widget.margin.horizontal);
            final maxY = max(0.0,
                constraints.maxHeight - widget.size - widget.margin.vertical);

            // 🆕 دمج الحركة التلقائية مع السحب اليدوي مع منع الخروج عن الشاشة
            double dx = (widget.margin.left + maxX * tX + _manualOffset.dx)
                .clamp(widget.margin.left, widget.margin.left + maxX);
            double dy = (widget.margin.top + maxY * tY + _manualOffset.dy)
                .clamp(widget.margin.top, widget.margin.top + maxY);

            final perspective = 0.88 + tY * 0.24;
            final velocityX = _moveXController.value - tX;
            final tilt = (velocityX * 0.3).clamp(-0.12, 0.12);

            _bubbleOnLeft ??= dx > constraints.maxWidth / 2;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: dx + widget.size * 0.2 * perspective,
                  top: dy + widget.size * 0.95 * perspective,
                  child: IgnorePointer(
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
                ),
                Positioned(
                  left: dx,
                  top: dy,
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: _buildCharacterAndBubble(
                      blinkValue: _blinkController.value,
                      tilt: _isDragging ? 0 : tilt,
                      perspective: perspective,
                      bubbleOnLeft: _bubbleOnLeft ?? false,
                    ),
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
              hairColor: widget.hairColor,
              eyeColor: widget.eyeColor,
              skinTone: widget.skinTone,
              faceShape: widget.faceShape,
              hairStyle: widget.hairStyle,
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
      child: IgnorePointer(
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
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Preview للشخصية
// ══════════════════════════════════════════════════════════════
class MangaCharacterPreview extends StatelessWidget {
  final double size;
  final Color hairColor;
  final Color eyeColor;
  final Color skinTone;
  final FaceShape faceShape;
  final HairStyle hairStyle;
  final MangaExpression expression;

  const MangaCharacterPreview({
    super.key,
    this.size = 120,
    this.hairColor = const Color(0xFF2C1810),
    this.eyeColor = const Color(0xFF1A0F06),
    this.skinTone = const Color(0xFFFFE0BD),
    this.faceShape = FaceShape.round,
    this.hairStyle = HairStyle.spiky,
    this.expression = MangaExpression.happy,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MangaFacePainter(
          expression: expression,
          blinkValue: 0,
          hairColor: hairColor,
          eyeColor: eyeColor,
          skinTone: skinTone,
          faceShape: faceShape,
          hairStyle: hairStyle,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// رسم الوجه (يحتوي على كل التعبيرات كما هي في الكود السابق)
// ══════════════════════════════════════════════════════════════
class _MangaFacePainter extends CustomPainter {
  final MangaExpression expression;
  final double blinkValue;
  final Color hairColor;
  final Color eyeColor;
  final Color skinTone;
  final FaceShape faceShape;
  final HairStyle hairStyle;

  _MangaFacePainter({
    required this.expression,
    this.blinkValue = 0,
    this.hairColor = const Color(0xFF2C1810),
    this.eyeColor = const Color(0xFF1A0F06),
    this.skinTone = const Color(0xFFFFE0BD),
    this.faceShape = FaceShape.round,
    this.hairStyle = HairStyle.spiky,
  });

  bool get _isBlinking => blinkValue > 0.5;

  static const Set<MangaExpression> _blinkable = {
    MangaExpression.neutral, MangaExpression.angry,
    MangaExpression.surprised, MangaExpression.thinking,
    MangaExpression.confused, MangaExpression.excited,
    MangaExpression.determined, MangaExpression.shy,
  };

  Color _light(Color c, [double t = 0.3]) => Color.lerp(c, Colors.white, t)!;
  Color _dark(Color c, [double t = 0.3]) => Color.lerp(c, Colors.black, t)!;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;

    final facePath = _getFacePath(cx, cy, r);
    final faceRect = _getFaceRect(cx, cy, r);

    _drawDropShadow(canvas, cx, cy, r);
    _drawBackHair(canvas, cx, cy, r);
    _drawFaceBase(canvas, facePath, faceRect);
    _drawFaceShading(canvas, facePath, faceRect, cx, cy, r);
    _drawEyebrows(canvas, cx, cy, r);
    _drawEyes(canvas, cx, cy, r);
    _drawNose(canvas, cx, cy, r);

    if (expression == MangaExpression.love ||
        expression == MangaExpression.shy ||
        expression == MangaExpression.veryHappy ||
        expression == MangaExpression.laugh) {
      _drawBlush(canvas, cx, cy, r);
    }

    _drawMouth(canvas, cx, cy, r);
    _drawFrontHair(canvas, cx, cy, r);
    _drawHairShadowOnFace(canvas, cx, cy, r);
    _drawAccessories(canvas, cx, cy, r);
  }

  Path _getFacePath(double cx, double cy, double r) {
    switch (faceShape) {
      case FaceShape.round:
        return Path()
          ..moveTo(cx, cy - r)
          ..cubicTo(cx + r * 1.0, cy - r, cx + r * 1.08, cy + r * 0.15,
              cx + r * 0.7, cy + r * 0.78)
          ..cubicTo(cx + r * 0.4, cy + r * 1.05, cx - r * 0.4, cy + r * 1.05,
              cx - r * 0.7, cy + r * 0.78)
          ..cubicTo(cx - r * 1.08, cy + r * 0.15, cx - r * 1.0, cy - r,
              cx, cy - r)
          ..close();
      case FaceShape.oval:
        return Path()
          ..moveTo(cx, cy - r * 1.1)
          ..cubicTo(cx + r * 0.9, cy - r * 1.1, cx + r * 1.02, cy + r * 0.2,
              cx + r * 0.62, cy + r * 0.95)
          ..cubicTo(cx + r * 0.32, cy + r * 1.2, cx - r * 0.32, cy + r * 1.2,
              cx - r * 0.62, cy + r * 0.95)
          ..cubicTo(cx - r * 1.02, cy + r * 0.2, cx - r * 0.9, cy - r * 1.1,
              cx, cy - r * 1.1)
          ..close();
      case FaceShape.square:
        return Path()
          ..moveTo(cx - r * 0.82, cy - r * 0.9)
          ..quadraticBezierTo(cx, cy - r * 1.1, cx + r * 0.82, cy - r * 0.9)
          ..lineTo(cx + r * 0.92, cy + r * 0.5)
          ..quadraticBezierTo(cx + r * 0.92, cy + r * 0.98, cx + r * 0.5,
              cy + r * 0.98)
          ..lineTo(cx - r * 0.5, cy + r * 0.98)
          ..quadraticBezierTo(cx - r * 0.92, cy + r * 0.98, cx - r * 0.92,
              cy + r * 0.5)
          ..close();
    }
  }

  Rect _getFaceRect(double cx, double cy, double r) {
    return Rect.fromCenter(
      center: Offset(cx, cy),
      width: r * 2.2,
      height: r * 2.2,
    );
  }

  void _drawDropShadow(Canvas canvas, double cx, double cy, double r) {
    final rect = Rect.fromCenter(
      center: Offset(cx, cy + r * 0.95),
      width: r * 1.6,
      height: r * 0.25,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withOpacity(0.35),
            Colors.black.withOpacity(0.0),
          ],
        ).createShader(rect),
    );
  }

  void _drawBackHair(Canvas canvas, double cx, double cy, double r) {
    final backPath = Path()
      ..moveTo(cx - r * 1.18, cy - r * 0.25)
      ..cubicTo(cx - r * 1.22, cy - r * 1.35, cx + r * 1.22, cy - r * 1.35,
          cx + r * 1.18, cy - r * 0.25)
      ..lineTo(cx + r * 1.12, cy + r * 0.55)
      ..lineTo(cx - r * 1.12, cy + r * 0.55)
      ..close();

    final hairRect =
        Rect.fromCircle(center: Offset(cx, cy - r * 0.5), radius: r * 1.3);

    canvas.drawPath(
      backPath,
      Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawPath(
      backPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _dark(hairColor, 0.5),
            hairColor,
            _dark(hairColor, 0.3),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(hairRect),
    );
  }

  void _drawFaceBase(Canvas canvas, Path facePath, Rect faceRect) {
    canvas.save();
    canvas.translate(2.5, 5);
    canvas.drawPath(
      facePath,
      Paint()
        ..color = Colors.black.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.restore();

    canvas.drawPath(
      facePath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.4,
          colors: [
            _light(skinTone, 0.35),
            skinTone,
            _dark(skinTone, 0.12),
            _dark(skinTone, 0.25),
          ],
          stops: const [0.0, 0.5, 0.85, 1.0],
        ).createShader(faceRect),
    );

    canvas.drawPath(
      facePath,
      Paint()
        ..color = _dark(skinTone, 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawFaceShading(
      Canvas canvas, Path facePath, Rect faceRect, double cx, double cy, double r) {
    canvas.save();
    canvas.clipPath(facePath);

    final shadowRect = Rect.fromCircle(
      center: Offset(cx + r * 0.5, cy + r * 0.5),
      radius: r * 1.1,
    );
    canvas.drawCircle(
      Offset(cx + r * 0.55, cy + r * 0.55),
      r * 1.0,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            _dark(skinTone, 0.2).withOpacity(0.45),
          ],
          stops: const [0.5, 1.0],
        ).createShader(shadowRect),
    );

    final chinRect = Rect.fromCenter(
      center: Offset(cx, cy + r * 0.88),
      width: r * 1.3,
      height: r * 0.5,
    );
    canvas.drawOval(
      chinRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            _dark(skinTone, 0.35).withOpacity(0.5),
          ],
          stops: const [0.3, 1.0],
        ).createShader(chinRect),
    );

    canvas.restore();
  }

  void _drawEyebrows(Canvas canvas, double cx, double cy, double r) {
    final eyebrowY = cy - r * 0.35;
    final leftX = cx - r * 0.35;
    final rightX = cx + r * 0.35;

    final paint = Paint()
      ..color = _dark(hairColor, 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.055
      ..strokeCap = StrokeCap.round;

    switch (expression) {
      case MangaExpression.angry:
        canvas.drawLine(Offset(leftX - r * 0.15, eyebrowY - r * 0.04),
            Offset(leftX + r * 0.15, eyebrowY + r * 0.06), paint);
        canvas.drawLine(Offset(rightX + r * 0.15, eyebrowY - r * 0.04),
            Offset(rightX - r * 0.15, eyebrowY + r * 0.06), paint);
        break;
      case MangaExpression.sad:
        canvas.drawLine(Offset(leftX - r * 0.15, eyebrowY + r * 0.06),
            Offset(leftX + r * 0.15, eyebrowY - r * 0.04), paint);
        canvas.drawLine(Offset(rightX + r * 0.15, eyebrowY + r * 0.06),
            Offset(rightX - r * 0.15, eyebrowY - r * 0.04), paint);
        break;
      case MangaExpression.surprised:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(leftX, eyebrowY - r * 0.02),
                width: r * 0.4,
                height: r * 0.18),
            pi, pi, false, paint);
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(rightX, eyebrowY - r * 0.02),
                width: r * 0.4,
                height: r * 0.18),
            pi, pi, false, paint);
        break;
      case MangaExpression.happy:
      case MangaExpression.veryHappy:
      case MangaExpression.laugh:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(leftX, eyebrowY + r * 0.04),
                width: r * 0.36,
                height: r * 0.1),
            pi * 1.1, pi * 0.8, false, paint);
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(rightX, eyebrowY + r * 0.04),
                width: r * 0.36,
                height: r * 0.1),
            pi * 1.1, pi * 0.8, false, paint);
        break;
      case MangaExpression.cool:
        canvas.drawLine(Offset(leftX - r * 0.18, eyebrowY),
            Offset(leftX + r * 0.18, eyebrowY + r * 0.03), paint);
        canvas.drawLine(Offset(rightX + r * 0.18, eyebrowY),
            Offset(rightX - r * 0.18, eyebrowY + r * 0.03), paint);
        break;
      case MangaExpression.determined:
        canvas.drawLine(Offset(leftX - r * 0.15, eyebrowY - r * 0.08),
            Offset(leftX + r * 0.15, eyebrowY), paint);
        canvas.drawLine(Offset(rightX + r * 0.15, eyebrowY - r * 0.08),
            Offset(rightX - r * 0.15, eyebrowY), paint);
        break;
      case MangaExpression.sleepy:
      case MangaExpression.sleepyHappy:
        canvas.drawLine(Offset(leftX - r * 0.15, eyebrowY + r * 0.02),
            Offset(leftX + r * 0.15, eyebrowY + r * 0.02), paint);
        canvas.drawLine(Offset(rightX - r * 0.15, eyebrowY + r * 0.02),
            Offset(rightX + r * 0.15, eyebrowY + r * 0.02), paint);
        break;
      default:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(leftX, eyebrowY + r * 0.03),
                width: r * 0.36,
                height: r * 0.12),
            pi * 1.15, pi * 0.7, false, paint);
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(rightX, eyebrowY + r * 0.03),
                width: r * 0.36,
                height: r * 0.12),
            pi * 1.15, pi * 0.7, false, paint);
    }
  }

  void _drawDetailedEye(Canvas canvas, Offset center, double size) {
    final rect = Rect.fromCircle(center: center, radius: size);

    canvas.drawCircle(
      center,
      size * 1.15,
      Paint()
        ..color = _dark(skinTone, 0.25).withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawCircle(center, size, Paint()..color = Colors.white);

    final irisRect = Rect.fromCircle(center: center, radius: size * 0.72);
    canvas.drawCircle(
      center,
      size * 0.72,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _dark(eyeColor, 0.45),
            eyeColor,
            _light(eyeColor, 0.35),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(irisRect),
    );

    canvas.drawCircle(
      center,
      size * 0.38,
      Paint()..color = _dark(eyeColor, 0.8),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - size * 0.28, center.dy - size * 0.35),
        width: size * 0.42,
        height: size * 0.35,
      ),
      Paint()..color = Colors.white,
    );

    canvas.drawCircle(
      Offset(center.dx + size * 0.28, center.dy + size * 0.32),
      size * 0.13,
      Paint()..color = Colors.white.withOpacity(0.85),
    );

    final lidPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.16
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size * 0.95),
      pi * 1.1,
      pi * 0.8,
      false,
      lidPaint,
    );
  }

  void _drawEyes(Canvas canvas, double cx, double cy, double r) {
    final eyeY = cy - r * 0.05;
    final leftEyeX = cx - r * 0.35;
    final rightEyeX = cx + r * 0.35;
    final eyeSize = r * 0.18;

    if (_isBlinking && _blinkable.contains(expression)) {
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
          0, pi, false, paint);
      canvas.drawArc(
          Rect.fromCenter(
              center: Offset(rightEyeX, eyeY),
              width: eyeSize * 2,
              height: eyeSize * 0.8),
          0, pi, false, paint);
      return;
    }

    switch (expression) {
      case MangaExpression.neutral:
      case MangaExpression.shy:
        _drawDetailedEye(canvas, Offset(leftEyeX, eyeY), eyeSize);
        _drawDetailedEye(canvas, Offset(rightEyeX, eyeY), eyeSize);
        break;
      case MangaExpression.happy:
      case MangaExpression.veryHappy:
      case MangaExpression.laugh:
        final paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(leftEyeX, eyeY),
                width: eyeSize * 1.6,
                height: eyeSize * 1.1),
            pi, pi, false, paint);
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(rightEyeX, eyeY),
                width: eyeSize * 1.6,
                height: eyeSize * 1.1),
            pi, pi, false, paint);
        break;
      case MangaExpression.wink:
        _drawDetailedEye(canvas, Offset(leftEyeX, eyeY), eyeSize);
        final paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(rightEyeX, eyeY),
                width: eyeSize * 1.6,
                height: eyeSize * 1.1),
            pi, pi, false, paint);
        break;
      case MangaExpression.sleepy:
      case MangaExpression.sleepyHappy:
        final paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
            Offset(leftEyeX - eyeSize * 0.8, eyeY),
            Offset(leftEyeX + eyeSize * 0.8, eyeY), paint);
        canvas.drawLine(
            Offset(rightEyeX - eyeSize * 0.8, eyeY),
            Offset(rightEyeX + eyeSize * 0.8, eyeY), paint);
        break;
      case MangaExpression.sad:
        final paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(leftEyeX, eyeY + eyeSize * 0.3),
                width: eyeSize * 1.6,
                height: eyeSize * 1.1),
            0, pi, false, paint);
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(rightEyeX, eyeY + eyeSize * 0.3),
                width: eyeSize * 1.6,
                height: eyeSize * 1.1),
            0, pi, false, paint);
        final tearRect = Rect.fromCenter(
            center: Offset(rightEyeX + eyeSize * 0.7, eyeY + eyeSize * 1.3),
            width: eyeSize * 0.7,
            height: eyeSize * 1.0);
        canvas.drawOval(
          tearRect,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.3, -0.3),
              colors: [Color(0xFFE1F5FE), Color(0xFF4FC3F7)],
            ).createShader(tearRect),
        );
        break;
      case MangaExpression.angry:
        _drawDetailedEye(canvas, Offset(leftEyeX, eyeY), eyeSize);
        _drawDetailedEye(canvas, Offset(rightEyeX, eyeY), eyeSize);
        break;
      case MangaExpression.surprised:
        final bigEyeSize = eyeSize * 1.3;
        _drawDetailedEye(canvas, Offset(leftEyeX, eyeY), bigEyeSize);
        _drawDetailedEye(canvas, Offset(rightEyeX, eyeY), bigEyeSize);
        final linesPaint = Paint()
          ..color = Colors.black87
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;
        for (int i = 0; i < 4; i++) {
          final a = i * pi / 2 + pi / 4;
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
        _drawStar(
            canvas, Offset(leftEyeX, eyeY), eyeSize * 1.5, Colors.amber);
        _drawStar(
            canvas, Offset(rightEyeX, eyeY), eyeSize * 1.5, Colors.amber);
        break;
      case MangaExpression.cool:
        final glassesRect = Rect.fromCenter(
            center: Offset(cx, eyeY), width: r * 1.5, height: r * 0.42);
        canvas.drawRRect(
          RRect.fromRectAndRadius(glassesRect, Radius.circular(r * 0.1)),
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0A0A), Color(0xFF3A3A3A)],
            ).createShader(glassesRect),
        );
        canvas.drawLine(
            Offset(cx - r * 0.55, eyeY - r * 0.1),
            Offset(cx - r * 0.2, eyeY - r * 0.1),
            Paint()
              ..color = Colors.white.withOpacity(0.6)
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round);
        break;
      case MangaExpression.thinking:
        _drawDetailedEye(canvas, Offset(leftEyeX, eyeY), eyeSize);
        canvas.drawCircle(
            Offset(rightEyeX, eyeY), eyeSize, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(rightEyeX, eyeY), eyeSize * 0.45,
            Paint()..color = eyeColor);
        break;
      case MangaExpression.confused:
        _drawDetailedEye(canvas, Offset(leftEyeX, eyeY), eyeSize * 1.15);
        _drawDetailedEye(canvas, Offset(rightEyeX, eyeY), eyeSize * 0.8);
        break;
      case MangaExpression.excited:
        _drawDetailedEye(canvas, Offset(leftEyeX, eyeY), eyeSize * 1.2);
        _drawDetailedEye(canvas, Offset(rightEyeX, eyeY), eyeSize * 1.2);
        break;
      case MangaExpression.determined:
        _drawDetailedEye(canvas, Offset(leftEyeX, eyeY), eyeSize);
        _drawDetailedEye(canvas, Offset(rightEyeX, eyeY), eyeSize);
        break;
      case MangaExpression.proud:
        _drawDetailedEye(canvas, Offset(leftEyeX, eyeY), eyeSize);
        _drawDetailedEye(canvas, Offset(rightEyeX, eyeY), eyeSize);
        final lidPaint = Paint()..color = skinTone;
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset(leftEyeX, eyeY - eyeSize * 0.6),
                width: eyeSize * 2.2,
                height: eyeSize * 0.95),
            lidPaint);
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset(rightEyeX, eyeY - eyeSize * 0.6),
                width: eyeSize * 2.2,
                height: eyeSize * 0.95),
            lidPaint);
        break;
      case MangaExpression.silly:
        final paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(leftEyeX, eyeY),
                width: eyeSize * 1.6,
                height: eyeSize * 1.1),
            pi, pi, false, paint);
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(rightEyeX, eyeY),
                width: eyeSize * 1.6,
                height: eyeSize * 1.1),
            pi, pi, false, paint);
        break;
    }
  }

  void _drawNose(Canvas canvas, double cx, double cy, double r) {
    final noseY = cy + r * 0.12;
    final rect = Rect.fromCenter(
      center: Offset(cx + 2, noseY),
      width: r * 0.15,
      height: r * 0.12,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = _dark(skinTone, 0.3).withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  void _drawBlush(Canvas canvas, double cx, double cy, double r) {
    final blushRect1 = Rect.fromCenter(
        center: Offset(cx - r * 0.58, cy + r * 0.22),
        width: r * 0.45,
        height: r * 0.28);
    canvas.drawOval(
      blushRect1,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF9E9E).withOpacity(0.85),
            const Color(0xFFFF9E9E).withOpacity(0.0),
          ],
        ).createShader(blushRect1),
    );

    final blushRect2 = Rect.fromCenter(
        center: Offset(cx + r * 0.58, cy + r * 0.22),
        width: r * 0.45,
        height: r * 0.28);
    canvas.drawOval(
      blushRect2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF9E9E).withOpacity(0.85),
            const Color(0xFFFF9E9E).withOpacity(0.0),
          ],
        ).createShader(blushRect2),
    );
  }

  void _drawMouth(Canvas canvas, double cx, double cy, double r) {
    final mouthY = cy + r * 0.42;
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
                width: r * 0.55,
                height: r * 0.32),
            0, pi, false, strokePaint);
        break;
      case MangaExpression.veryHappy:
      case MangaExpression.laugh:
        final mouthRect = Rect.fromCenter(
            center: Offset(cx, mouthY), width: r * 0.7, height: r * 0.5);
        canvas.drawOval(mouthRect, Paint()..color = const Color(0xFF3D1414));
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx, mouthY + r * 0.1),
              width: r * 0.4,
              height: r * 0.25),
          Paint()..color = const Color(0xFFFF7E7E),
        );
        break;
      case MangaExpression.sad:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, mouthY + r * 0.1),
                width: r * 0.4,
                height: r * 0.22),
            pi, pi, false, strokePaint);
        break;
      case MangaExpression.angry:
        final path = Path()
          ..moveTo(cx - r * 0.3, mouthY)
          ..lineTo(cx + r * 0.3, mouthY)
          ..lineTo(cx, mouthY + r * 0.22)
          ..close();
        canvas.drawPath(path, blackPaint);
        break;
      case MangaExpression.surprised:
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(cx, mouthY),
                width: r * 0.25,
                height: r * 0.4),
            blackPaint);
        break;
      case MangaExpression.sleepy:
      case MangaExpression.sleepyHappy:
      case MangaExpression.shy:
        canvas.drawLine(Offset(cx - r * 0.18, mouthY),
            Offset(cx + r * 0.18, mouthY), strokePaint);
        break;
      case MangaExpression.love:
        canvas.drawCircle(Offset(cx, mouthY), r * 0.14,
            Paint()..color = const Color(0xFF3D1414));
        break;
      case MangaExpression.starstruck:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, mouthY),
                width: r * 0.6,
                height: r * 0.35),
            0, pi, false, strokePaint);
        break;
      case MangaExpression.cool:
        final path = Path()
          ..moveTo(cx - r * 0.25, mouthY)
          ..quadraticBezierTo(
              cx, mouthY + r * 0.1, cx + r * 0.25, mouthY - r * 0.02);
        canvas.drawPath(path, strokePaint);
        break;
      case MangaExpression.wink:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, mouthY),
                width: r * 0.45,
                height: r * 0.22),
            0, pi, false, strokePaint);
        break;
      case MangaExpression.thinking:
        canvas.drawCircle(
            Offset(cx + r * 0.1, mouthY), r * 0.1, blackPaint);
        break;
      case MangaExpression.confused:
        final path = Path()..moveTo(cx - r * 0.25, mouthY);
        for (int i = 1; i <= 3; i++) {
          path.quadraticBezierTo(
            cx - r * 0.25 + (i * r * 0.5 / 3) + r * 0.08,
            mouthY + (i.isEven ? -r * 0.06 : r * 0.06),
            cx - r * 0.25 + (i * r * 0.5 / 3),
            mouthY,
          );
        }
        canvas.drawPath(path, strokePaint);
        break;
      case MangaExpression.excited:
        final path = Path()
          ..moveTo(cx - r * 0.32, mouthY)
          ..quadraticBezierTo(cx, mouthY + r * 0.4, cx + r * 0.32, mouthY)
          ..close();
        canvas.drawPath(path, Paint()..color = const Color(0xFF3D1414));
        break;
      case MangaExpression.determined:
        final path = Path()
          ..moveTo(cx - r * 0.3, mouthY)
          ..lineTo(cx + r * 0.3, mouthY)
          ..lineTo(cx, mouthY + r * 0.16)
          ..close();
        canvas.drawPath(path, blackPaint);
        break;
      case MangaExpression.proud:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, mouthY),
                width: r * 0.55,
                height: r * 0.28),
            0, pi, false, strokePaint);
        break;
      case MangaExpression.silly:
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(cx, mouthY),
                width: r * 0.45,
                height: r * 0.35),
            Paint()..color = const Color(0xFF3D1414));
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(cx, mouthY + r * 0.12),
                width: r * 0.3,
                height: r * 0.22),
            Paint()..color = const Color(0xFFFF7E7E));
        break;
      default:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, mouthY),
                width: r * 0.32,
                height: r * 0.18),
            0, pi, false, strokePaint);
    }
  }

  void _drawFrontHair(Canvas canvas, double cx, double cy, double r) {
    final hairRect =
        Rect.fromCircle(center: Offset(cx, cy - r * 0.5), radius: r * 1.3);

    final hairGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        _light(hairColor, 0.35),
        hairColor,
        _dark(hairColor, 0.35),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(hairRect);

    Path path;
    switch (hairStyle) {
      case HairStyle.spiky:
        path = Path()
          ..moveTo(cx - r * 1.05, cy - r * 0.35)
          ..lineTo(cx - r * 0.88, cy - r * 1.02)
          ..lineTo(cx - r * 0.55, cy - r * 0.6)
          ..lineTo(cx - r * 0.2, cy - r * 1.12)
          ..lineTo(cx + r * 0.15, cy - r * 0.55)
          ..lineTo(cx + r * 0.5, cy - r * 1.08)
          ..lineTo(cx + r * 0.82, cy - r * 0.5)
          ..lineTo(cx + r * 1.05, cy - r * 0.35)
          ..quadraticBezierTo(
              cx + r * 0.95, cy - r * 0.75, cx + r * 0.5, cy - r * 0.78)
          ..quadraticBezierTo(
              cx, cy - r * 0.9, cx - r * 0.5, cy - r * 0.78)
          ..quadraticBezierTo(
              cx - r * 0.95, cy - r * 0.75, cx - r * 1.05, cy - r * 0.35)
          ..close();
        break;
      case HairStyle.short:
        path = Path()
          ..moveTo(cx - r * 1.0, cy - r * 0.4)
          ..quadraticBezierTo(
              cx - r * 0.9, cy - r * 1.1, cx, cy - r * 1.05)
          ..quadraticBezierTo(
              cx + r * 0.9, cy - r * 1.1, cx + r * 1.0, cy - r * 0.4)
          ..quadraticBezierTo(
              cx + r * 0.7, cy - r * 0.65, cx + r * 0.3, cy - r * 0.62)
          ..quadraticBezierTo(
              cx, cy - r * 0.72, cx - r * 0.3, cy - r * 0.62)
          ..quadraticBezierTo(
              cx - r * 0.7, cy - r * 0.65, cx - r * 1.0, cy - r * 0.4)
          ..close();
        break;
      case HairStyle.long:
        path = Path()
          ..moveTo(cx - r * 1.1, cy + r * 0.6)
          ..lineTo(cx - r * 1.08, cy - r * 0.35)
          ..quadraticBezierTo(
              cx - r * 0.9, cy - r * 1.15, cx, cy - r * 1.02)
          ..quadraticBezierTo(
              cx + r * 0.9, cy - r * 1.15, cx + r * 1.08, cy - r * 0.35)
          ..lineTo(cx + r * 1.1, cy + r * 0.6)
          ..quadraticBezierTo(
              cx + r * 0.85, cy + r * 0.35, cx + r * 0.72, cy - r * 0.25)
          ..quadraticBezierTo(
              cx, cy - r * 0.55, cx - r * 0.72, cy - r * 0.25)
          ..quadraticBezierTo(
              cx - r * 0.85, cy + r * 0.35, cx - r * 1.1, cy + r * 0.6)
          ..close();
        break;
      case HairStyle.ponytail:
        path = Path()
          ..moveTo(cx - r * 1.05, cy - r * 0.35)
          ..lineTo(cx - r * 0.88, cy - r * 1.02)
          ..lineTo(cx - r * 0.55, cy - r * 0.6)
          ..lineTo(cx - r * 0.2, cy - r * 1.12)
          ..lineTo(cx + r * 0.15, cy - r * 0.55)
          ..lineTo(cx + r * 0.5, cy - r * 1.08)
          ..lineTo(cx + r * 0.82, cy - r * 0.5)
          ..lineTo(cx + r * 1.05, cy - r * 0.35)
          ..quadraticBezierTo(
              cx + r * 0.95, cy - r * 0.75, cx + r * 0.5, cy - r * 0.78)
          ..quadraticBezierTo(
              cx, cy - r * 0.9, cx - r * 0.5, cy - r * 0.78)
          ..quadraticBezierTo(
              cx - r * 0.95, cy - r * 0.75, cx - r * 1.05, cy - r * 0.35)
          ..close();
        break;
    }

    canvas.save();
    canvas.translate(1.5, 3);
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withOpacity(0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.restore();

    canvas.drawPath(path, Paint()..shader = hairGradient);

    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.5, -0.8),
          radius: 0.7,
          colors: [
            Colors.white.withOpacity(0.45),
            Colors.transparent,
          ],
        ).createShader(hairRect)
        ..blendMode = BlendMode.overlay,
    );

    final highlightPaint = Paint()
      ..color = _light(hairColor, 0.55).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx - r * 0.4, cy - r * 0.75),
            width: r * 0.5,
            height: r * 0.15),
        pi * 1.1, pi * 0.5, false, highlightPaint);

    if (hairStyle == HairStyle.ponytail) {
      final tailPath = Path()
        ..moveTo(cx + r * 0.9, cy - r * 0.45)
        ..cubicTo(cx + r * 1.4, cy - r * 0.25, cx + r * 1.35, cy + r * 0.5,
            cx + r * 1.15, cy + r * 0.55)
        ..cubicTo(cx + r * 1.0, cy + r * 0.5, cx + r * 0.9, cy + r * 0.2,
            cx + r * 0.88, cy + r * 0.05)
        ..close();
      canvas.drawPath(tailPath, Paint()..shader = hairGradient);
    }
  }

  void _drawHairShadowOnFace(Canvas canvas, double cx, double cy, double r) {
    final foreheadRect = Rect.fromCenter(
      center: Offset(cx, cy - r * 0.55),
      width: r * 1.6,
      height: r * 0.55,
    );
    canvas.drawOval(
      foreheadRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _dark(skinTone, 0.3).withOpacity(0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(foreheadRect),
    );
  }

  void _drawAccessories(Canvas canvas, double cx, double cy, double r) {
    switch (expression) {
      case MangaExpression.surprised:
        final path = Path()
          ..moveTo(cx + r * 0.82, cy - r * 0.3)
          ..quadraticBezierTo(
              cx + r * 0.92, cy - r * 0.1, cx + r * 0.82, cy)
          ..quadraticBezierTo(
              cx + r * 0.72, cy - r * 0.1, cx + r * 0.82, cy - r * 0.3);
        canvas.drawPath(
          path,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE1F5FE), Color(0xFF4FC3F7)],
            ).createShader(Rect.fromCircle(
                center: Offset(cx + r * 0.8, cy - r * 0.15),
                radius: r * 0.2)),
        );
        break;
      case MangaExpression.angry:
        final angerPaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        final ax = cx + r * 0.75;
        final ay = cy - r * 0.75;
        canvas.drawLine(
            Offset(ax - 7, ay - 7), Offset(ax + 7, ay + 7), angerPaint);
        canvas.drawLine(
            Offset(ax + 7, ay - 7), Offset(ax - 7, ay + 7), angerPaint);
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
        _drawStar(canvas, Offset(cx + r * 0.7, cy - r * 0.7), r * 0.2,
            Colors.amber);
        _drawStar(
            canvas, Offset(cx - r * 0.7, cy - r * 0.5), r * 0.15, Colors.amber);
        break;
      default:
        break;
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(center.dx, center.dy + size * 0.3)
      ..cubicTo(center.dx - size, center.dy - size * 0.5, center.dx - size * 0.5,
          center.dy - size, center.dx, center.dy - size * 0.3)
      ..cubicTo(center.dx + size * 0.5, center.dy - size, center.dx + size,
          center.dy - size * 0.5, center.dx, center.dy + size * 0.3)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawStar(Canvas canvas, Offset center, double size, Color color) {
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
      oldDelegate.expression != expression ||
      oldDelegate.blinkValue != blinkValue ||
      oldDelegate.hairColor != hairColor ||
      oldDelegate.eyeColor != eyeColor ||
      oldDelegate.skinTone != skinTone ||
      oldDelegate.faceShape != faceShape ||
      oldDelegate.hairStyle != hairStyle;
}

// ══════════════════════════════════════════════════════════════
// مساعد لجعل الشخصية تطفو فوق كل الشاشات
// ══════════════════════════════════════════════════════════════
class FloatingMangaCharacter {
  static final GlobalKey<MangaCharacterState> key =
      GlobalKey<MangaCharacterState>();
  static OverlayEntry? _entry;

  static void show(BuildContext context) {
    if (_entry != null) return;
    _entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: MangaCharacter(
          key: key,
          size: 90,
          autoMove: true,
          enableBlink: true,
          initialMessage: 'welcome_back',
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }

  static void say(String messageKey) =>
      key.currentState?.showMessage(messageKey);

  static void sayCustom(String text, MangaExpression expression) =>
      key.currentState?.showCustomMessage(text, expression);

  static void setExpression(MangaExpression expression) =>
      key.currentState?.setExpression(expression);
}
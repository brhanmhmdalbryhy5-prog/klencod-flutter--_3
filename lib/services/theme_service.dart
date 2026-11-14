import 'package:flutter/material.dart';

class AppThemeColor {
  final String name;
  final Color color;
  const AppThemeColor(this.name, this.color);
}

const List<AppThemeColor> appThemeColors = [
  // ══════════════════════════════════════════════════════════════
  // 🎨 الألوان الأصلية (18 لون - محفوظة كما هي)
  // ══════════════════════════════════════════════════════════════
  AppThemeColor('أحمر دموي', Color(0xFF741C2B)),
  AppThemeColor('أزرق سماوي', Color(0xFF247BA0)),
  AppThemeColor('بنفسجي ملكي', Color(0xFF7651A8)),
  AppThemeColor('ذهبي', Color(0xFFB87928)),
  AppThemeColor('أخضر زمردي', Color(0xFF27866F)),
  AppThemeColor('وردي فاتح', Color(0xFFB34E68)),
  AppThemeColor('برتقالي حار', Color(0xFFE65100)),
  AppThemeColor('أصفر خردلي', Color(0xFFF9A825)),
  AppThemeColor('تركوازي', Color(0xFF00897B)),
  AppThemeColor('أزرق نيلي', Color(0xFF3F51B5)),
  AppThemeColor('أرجواني', Color(0xFF9C27B0)),
  AppThemeColor('رمادي فحمي', Color(0xFF424242)),
  AppThemeColor('بني خشبي', Color(0xFF5D4037)),
  AppThemeColor('أحمر مرجاني', Color(0xFFFF5252)),
  AppThemeColor('أزرق مخضر', Color(0xFF00ACC1)),
  AppThemeColor('ليموني', Color(0xFF827717)),
  AppThemeColor('عنابي', Color(0xFF880E4F)),
  AppThemeColor('أزرق داكن', Color(0xFF1565C0)),

  // ══════════════════════════════════════════════════════════════
  // 🌸 عائلة الوردي — 9 ألوان جديدة
  // ══════════════════════════════════════════════════════════════
  AppThemeColor('وردي', Color(0xFFF06292)),
  AppThemeColor('وردي فوشي', Color(0xFFEC407A)),
  AppThemeColor('وردي غامق', Color(0xFFD81B60)),
  AppThemeColor('وردي ناعم', Color(0xFFF48FB1)),
  AppThemeColor('وردي محمر', Color(0xFFFF80AB)),
  AppThemeColor('بامبي', Color(0xFFFFC1E6)),
  AppThemeColor('زهري', Color(0xFFF8BBD0)),
  AppThemeColor('وردي غبار', Color(0xFFC48B9F)),
  AppThemeColor('وردي كرزي', Color(0xFFC2185B)),

  // ══════════════════════════════════════════════════════════════
  // 🍑 عائلة البرتقالي والخوخي — 8 ألوان جديدة
  // ══════════════════════════════════════════════════════════════
  AppThemeColor('خوخي', Color(0xFFFFA726)),
  AppThemeColor('مشمشي', Color(0xFFFFB74D)),
  AppThemeColor('كهرماني', Color(0xFFFFB300)),
  AppThemeColor('برتقالي فاتح', Color(0xFFFF9800)),
  AppThemeColor('يوسفي', Color(0xFFF57C00)),
  AppThemeColor('قرنفلي', Color(0xFFFFA000)),
  AppThemeColor('برتقالي محروق', Color(0xFFBF360C)),
  AppThemeColor('برتقالي ذهبي', Color(0xFFF57F17)),

  // ══════════════════════════════════════════════════════════════
  // 🌻 عائلة الأصفر والعسلي — 6 ألوان جديدة
  // ══════════════════════════════════════════════════════════════
  AppThemeColor('عسلي', Color(0xFFFFCA28)),
  AppThemeColor('زبدي', Color(0xFFF9E79F)),
  AppThemeColor('كريمي', Color(0xFFFFEB3B)),
  AppThemeColor('ذهبي فاتح', Color(0xFFFFD54F)),
  AppThemeColor('خردلي فاتح', Color(0xFFD4E157)),
  AppThemeColor('أصفر شمسي', Color(0xFFFBC02D)),

  // ══════════════════════════════════════════════════════════════
  // 🍀 عائلة الأخضر — 11 لون جديد
  // ══════════════════════════════════════════════════════════════
  AppThemeColor('أخضر فاتح', Color(0xFF66BB6A)),
  AppThemeColor('أخضر ناعم', Color(0xFF81C784)),
  AppThemeColor('أخضر زيتوني', Color(0xFF689F38)),
  AppThemeColor('أخضر غابي', Color(0xFF388E3C)),
  AppThemeColor('أخضر مرجاني', Color(0xFF43A047)),
  AppThemeColor('أخضر ليموني', Color(0xFF9CCC65)),
  AppThemeColor('أخضر مائي', Color(0xFF4DB6AC)),
  AppThemeColor('أخضر داكن', Color(0xFF1B5E20)),
  AppThemeColor('أخضر بستاني', Color(0xFF4CAF50)),
  AppThemeColor('أخضر تفاحي', Color(0xFF8BC34A)),
  AppThemeColor('أخضر نعناعي', Color(0xFF26A69A)),

  // ══════════════════════════════════════════════════════════════
  // 🌊 عائلة التركواز والفيروزي — 6 ألوان جديدة
  // ══════════════════════════════════════════════════════════════
  AppThemeColor('تركوازي فاتح', Color(0xFF4DD0E1)),
  AppThemeColor('فيروزي', Color(0xFF26C6DA)),
  AppThemeColor('تركوازي سماوي', Color(0xFF00BCD4)),
  AppThemeColor('فيروزي بحري', Color(0xFF0097A7)),
  AppThemeColor('تركوازي غامق', Color(0xFF00695C)),
  AppThemeColor('مائي فاتح', Color(0xFF80DEEA)),

  // ══════════════════════════════════════════════════════════════
  // 💙 عائلة الأزرق — 13 لون جديد
  // ══════════════════════════════════════════════════════════════
  AppThemeColor('أزرق فاتح', Color(0xFF4FC3F7)),
  AppThemeColor('أزرق جليدي', Color(0xFF81D4FA)),
  AppThemeColor('أزرق مائي', Color(0xFF29B6F6)),
  AppThemeColor('أزرق صافي', Color(0xFF2196F3)),
  AppThemeColor('أزرق متوسط', Color(0xFF42A5F5)),
  AppThemeColor('أزرق مخملي', Color(0xFF1E88E5)),
  AppThemeColor('أزرق بحري', Color(0xFF0277BD)),
  AppThemeColor('أزرق محيطي', Color(0xFF01579B)),
  AppThemeColor('أزرق كوبالتي', Color(0xFF5C6BC0)),
  AppThemeColor('أزرق معدني', Color(0xFF4A90A4)),
  AppThemeColor('أزرق رمادي', Color(0xFF546E7A)),
  AppThemeColor('أزرق غروب', Color(0xFF5D9FBB)),
  AppThemeColor('أزرق ملكي', Color(0xFF1A237E)),

  // ══════════════════════════════════════════════════════════════
  // 💜 عائلة البنفسجي — 10 ألوان جديدة
  // ══════════════════════════════════════════════════════════════
  AppThemeColor('لافندر', Color(0xFFB39DDB)),
  AppThemeColor('بنفسجي عتيق', Color(0xFF7E57C2)),
  AppThemeColor('بنفسجي فاتح', Color(0xFF9575CD)),
  AppThemeColor('بنفسجي ناعم', Color(0xFFCE93D8)),
  AppThemeColor('أرجواني فاتح', Color(0xFFBA68C8)),
  AppThemeColor('بنفسجي متوسط', Color(0xFFAB47BC)),
  AppThemeColor('بنفسجي غامق', Color(0xFF8E24AA)),
  AppThemeColor('بنفسجي ملكي غامق', Color(0xFF6A1B9A)),
  AppThemeColor('بنفسجي داكن', Color(0xFF4527A0)),
  AppThemeColor('فوشيا', Color(0xFFD500F9)),

  // ══════════════════════════════════════════════════════════════
  // 🍷 عائلة الأحمر — 8 ألوان جديدة
  // ══════════════════════════════════════════════════════════════
  AppThemeColor('أحمر طوبي', Color(0xFFC62828)),
  AppThemeColor('أحمر ناري', Color(0xFFFF6B35)),
  AppThemeColor('قرمزي', Color(0xFFB71C1C)),
  AppThemeColor('كرزي', Color(0xFFD32F2F)),
  AppThemeColor('أحمر فاتح', Color(0xFFE57373)),
  AppThemeColor('أحمر نبيذي', Color(0xFF722F37)),
  AppThemeColor('أحمر عميق', Color(0xFF992525)),
  AppThemeColor('أحمر صدئ', Color(0xFFC0392B)),

  // ══════════════════════════════════════════════════════════════
  // 🪵 عائلة البني والرمادي — 8 ألوان جديدة
  // ══════════════════════════════════════════════════════════════
  AppThemeColor('رمادي فاتح', Color(0xFF9E9E9E)),
  AppThemeColor('رمادي متوسط', Color(0xFF757575)),
  AppThemeColor('رمادي داكن', Color(0xFF212121)),
  AppThemeColor('فضي', Color(0xFFB0BEC5)),
  AppThemeColor('بني فاتح', Color(0xFFA1887F)),
  AppThemeColor('بني متوسط', Color(0xFF795548)),
  AppThemeColor('بني غامق', Color(0xFF3E2723)),
  AppThemeColor('بيج', Color(0xFFD7CCC8)),

  // ══════════════════════════════════════════════════════════════
  // ✨ ألوان خاصة — 3 ألوان جديدة
  // ══════════════════════════════════════════════════════════════
  AppThemeColor('نحاسي', Color(0xFFB87333)),
  AppThemeColor('برونزي', Color(0xFFCD7F32)),
  AppThemeColor('ذهبي وردي', Color(0xFFE8B4A0)),
];
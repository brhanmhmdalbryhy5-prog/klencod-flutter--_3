import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'manga_character.dart';

class MangaPalettes {
  static const List<Color> hairColors = [
    Color(0xFF2C1810), Color(0xFF4A2C1A), Color(0xFF8B4513),
    Color(0xFFD4A574), Color(0xFFE8B923), Color(0xFFE8B4B8),
    Color(0xFF7B68EE), Color(0xFF4169E1), Color(0xFF2E8B57),
    Color(0xFFF5F5F5), Color(0xFF8B0000), Color(0xFF00CED1),
  ];

  static const List<Color> eyeColors = [
    Color(0xFF1A0F06), Color(0xFF6B4423), Color(0xFF4A90E2),
    Color(0xFF2E8B57), Color(0xFFB8860B), Color(0xFF9932CC),
    Color(0xFFDC143C), Color(0xFFFF69B4), Color(0xFF00CED1),
    Color(0xFF808080),
  ];

  static const List<Color> skinTones = [
    Color(0xFFFFF2D6), Color(0xFFFFE0BD), Color(0xFFF0C096),
    Color(0xFFD4A574), Color(0xFF8D5524), Color(0xFF5C3317),
  ];
}

class MangaCharacterConfig {
  final bool isVisible;
  final bool autoMove;
  final bool enableBlink;
  final double size;
  final Color hairColor;
  final Color eyeColor;
  final Color skinTone;
  final FaceShape faceShape;
  final HairStyle hairStyle;

  const MangaCharacterConfig({
    this.isVisible = true,
    this.autoMove = true,
    this.enableBlink = true,
    this.size = 90.0,
    this.hairColor = const Color(0xFF2C1810),
    this.eyeColor = const Color(0xFF1A0F06),
    this.skinTone = const Color(0xFFFFE0BD),
    this.faceShape = FaceShape.round,
    this.hairStyle = HairStyle.spiky,
  });

  MangaCharacterConfig copyWith({
    bool? isVisible,
    bool? autoMove,
    bool? enableBlink,
    double? size,
    Color? hairColor,
    Color? eyeColor,
    Color? skinTone,
    FaceShape? faceShape,
    HairStyle? hairStyle,
  }) {
    return MangaCharacterConfig(
      isVisible: isVisible ?? this.isVisible,
      autoMove: autoMove ?? this.autoMove,
      enableBlink: enableBlink ?? this.enableBlink,
      size: size ?? this.size,
      hairColor: hairColor ?? this.hairColor,
      eyeColor: eyeColor ?? this.eyeColor,
      skinTone: skinTone ?? this.skinTone,
      faceShape: faceShape ?? this.faceShape,
      hairStyle: hairStyle ?? this.hairStyle,
    );
  }
}

final ValueNotifier<MangaCharacterConfig> mangaConfigNotifier =
    ValueNotifier(const MangaCharacterConfig());

class MangaConfigService {
  static const _kVisible = 'manga_visible';
  static const _kAutoMove = 'manga_auto_move';
  static const _kBlink = 'manga_blink';
  static const _kSize = 'manga_size';
  static const _kHairColor = 'manga_hair_color';
  static const _kEyeColor = 'manga_eye_color';
  static const _kSkinTone = 'manga_skin_tone';
  static const _kFaceShape = 'manga_face_shape';
  static const _kHairStyle = 'manga_hair_style';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mangaConfigNotifier.value = MangaCharacterConfig(
      isVisible: prefs.getBool(_kVisible) ?? true,
      autoMove: prefs.getBool(_kAutoMove) ?? true,
      enableBlink: prefs.getBool(_kBlink) ?? true,
      size: prefs.getDouble(_kSize) ?? 90.0,
      hairColor: Color(prefs.getInt(_kHairColor) ?? 0xFF2C1810),
      eyeColor: Color(prefs.getInt(_kEyeColor) ?? 0xFF1A0F06),
      skinTone: Color(prefs.getInt(_kSkinTone) ?? 0xFFFFE0BD),
      faceShape: FaceShape.values[prefs.getInt(_kFaceShape) ?? 0],
      hairStyle: HairStyle.values[prefs.getInt(_kHairStyle) ?? 0],
    );
  }

  static Future<void> save(MangaCharacterConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVisible, config.isVisible);
    await prefs.setBool(_kAutoMove, config.autoMove);
    await prefs.setBool(_kBlink, config.enableBlink);
    await prefs.setDouble(_kSize, config.size);
    await prefs.setInt(_kHairColor, config.hairColor.value);
    await prefs.setInt(_kEyeColor, config.eyeColor.value);
    await prefs.setInt(_kSkinTone, config.skinTone.value);
    await prefs.setInt(_kFaceShape, config.faceShape.index);
    await prefs.setInt(_kHairStyle, config.hairStyle.index);
    mangaConfigNotifier.value = config;
  }
}

Future<void> showMangaSettingsDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (context) => const _MangaSettingsDialog(),
  );
}

class _MangaSettingsDialog extends StatefulWidget {
  const _MangaSettingsDialog();

  @override
  State<_MangaSettingsDialog> createState() => _MangaSettingsDialogState();
}

class _MangaSettingsDialogState extends State<_MangaSettingsDialog> {
  late MangaCharacterConfig _config;

  @override
  void initState() {
    super.initState();
    _config = mangaConfigNotifier.value;
  }

  void _update(MangaCharacterConfig newConfig) {
    setState(() => _config = newConfig);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = primaryColorNotifier.value;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: const Color(0xFF1B1F28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy, color: Color(0xFFFFC857)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('إعدادات الشخصية',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.15),
                    primaryColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: MangaCharacterPreview(
                      size: 110,
                      hairColor: _config.hairColor,
                      eyeColor: _config.eyeColor,
                      skinTone: _config.skinTone,
                      faceShape: _config.faceShape,
                      hairStyle: _config.hairStyle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('معاينة حية',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70)),
                        const SizedBox(height: 6),
                        Text(
                          _config.isVisible
                              ? 'شخصيتك كما ستظهر الآن'
                              : 'الشخصية مخفية حالياً',
                          style: TextStyle(
                              fontSize: 12,
                              color: _config.isVisible
                                  ? Colors.white54
                                  : Colors.redAccent),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_config.faceShape.label} • ${_config.hairStyle.label}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('التحكم العام', Icons.tune),
                    SwitchListTile(
                      title: const Text('إظهار الشخصية'),
                      subtitle: const Text('تشغيل أو إخفاء الشخصية العائمة'),
                      value: _config.isVisible,
                      activeColor: primaryColor,
                      onChanged: (v) => _update(_config.copyWith(isVisible: v)),
                    ),
                    SwitchListTile(
                      title: const Text('الحركة التلقائية'),
                      subtitle: const Text('جعل الشخصية تطفو في أنحاء الشاشة'),
                      value: _config.autoMove,
                      activeColor: primaryColor,
                      onChanged: _config.isVisible
                          ? (v) => _update(_config.copyWith(autoMove: v))
                          : null,
                    ),
                    SwitchListTile(
                      title: const Text('الرمش التلقائي'),
                      subtitle: const Text('جعل الشخصية ترمش بين الحين والآخر'),
                      value: _config.enableBlink,
                      activeColor: primaryColor,
                      onChanged: _config.isVisible
                          ? (v) => _update(_config.copyWith(enableBlink: v))
                          : null,
                    ),
                    ListTile(
                      title: const Text('حجم الشخصية'),
                      subtitle: Slider(
                        value: _config.size,
                        min: 50,
                        max: 150,
                        divisions: 10,
                        label: _config.size.round().toString(),
                        activeColor: primaryColor,
                        onChanged: _config.isVisible
                            ? (v) => _update(_config.copyWith(size: v))
                            : null,
                      ),
                      trailing: Text('${_config.size.round()}'),
                    ),
                    const SizedBox(height: 8),
                    _sectionTitle('شكل الوجه', Icons.face),
                    _buildShapeSelector(),
                    const SizedBox(height: 12),
                    _sectionTitle('تصفيفة الشعر', Icons.content_cut),
                    _buildHairStyleSelector(),
                    const SizedBox(height: 12),
                    _sectionTitle('لون الشعر', Icons.palette),
                    _buildColorGrid(
                      colors: MangaPalettes.hairColors,
                      selected: _config.hairColor,
                      onSelected: (c) =>
                          _update(_config.copyWith(hairColor: c)),
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle('لون العيون', Icons.remove_red_eye),
                    _buildColorGrid(
                      colors: MangaPalettes.eyeColors,
                      selected: _config.eyeColor,
                      onSelected: (c) =>
                          _update(_config.copyWith(eyeColor: c)),
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle('لون البشرة', Icons.face_retouching_natural),
                    _buildColorGrid(
                      colors: MangaPalettes.skinTones,
                      selected: _config.skinTone,
                      onSelected: (c) =>
                          _update(_config.copyWith(skinTone: c)),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.cyan,
                          side: const BorderSide(color: Colors.cyan),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Future.delayed(const Duration(milliseconds: 300), () {
                            FloatingMangaCharacter.say('excited');
                          });
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('تجربة رسالة'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        _update(const MangaCharacterConfig());
                      },
                      child: const Text('إعادة تعيين'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: primaryColor),
                      onPressed: () async {
                        await MangaConfigService.save(_config);
                        if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('حفظ التغييرات'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryColorNotifier.value),
          const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildShapeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FaceShape.values.map((shape) {
        final isSelected = _config.faceShape == shape;
        return ChoiceChip(
          avatar: Icon(shape.icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.white54),
          label: Text(shape.label),
          selected: isSelected,
          selectedColor: primaryColorNotifier.value,
          backgroundColor: const Color(0xFF111318),
          labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 12),
          side: BorderSide(
              color: isSelected
                  ? primaryColorNotifier.value
                  : Colors.white24),
          onSelected: (_) =>
              _update(_config.copyWith(faceShape: shape)),
        );
      }).toList(),
    );
  }

  Widget _buildHairStyleSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: HairStyle.values.map((style) {
        final isSelected = _config.hairStyle == style;
        return ChoiceChip(
          avatar: Icon(style.icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.white54),
          label: Text(style.label),
          selected: isSelected,
          selectedColor: primaryColorNotifier.value,
          backgroundColor: const Color(0xFF111318),
          labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 12),
          side: BorderSide(
              color: isSelected
                  ? primaryColorNotifier.value
                  : Colors.white24),
          onSelected: (_) =>
              _update(_config.copyWith(hairStyle: style)),
        );
      }).toList(),
    );
  }

  Widget _buildColorGrid({
    required List<Color> colors,
    required Color selected,
    required ValueChanged<Color> onSelected,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((color) {
        final isSelected = color == selected;
        return GestureDetector(
          onTap: () => onSelected(color),
          child: Tooltip(
            message: _colorHex(color),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white24,
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.7),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _colorHex(Color c) =>
      '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
}
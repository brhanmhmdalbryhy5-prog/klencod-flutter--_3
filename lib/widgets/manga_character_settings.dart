import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // للوصول إلى primaryColorNotifier
import 'manga_character.dart'; // للوصول إلى FloatingMangaCharacter.say

// ══════════════════════════════════════════════════════════════
// نموذج إعدادات الشخصية
// ══════════════════════════════════════════════════════════════
class MangaCharacterConfig {
  final bool isVisible;
  final bool autoMove;
  final bool enableBlink;
  final double size;

  const MangaCharacterConfig({
    this.isVisible = true,
    this.autoMove = true,
    this.enableBlink = true,
    this.size = 90.0,
  });
}

final ValueNotifier<MangaCharacterConfig> mangaConfigNotifier =
    ValueNotifier(const MangaCharacterConfig());

// ══════════════════════════════════════════════════════════════
// خدمة الحفظ والاسترجاع
// ══════════════════════════════════════════════════════════════
class MangaConfigService {
  static const _kVisible = 'manga_visible';
  static const _kAutoMove = 'manga_auto_move';
  static const _kBlink = 'manga_blink';
  static const _kSize = 'manga_size';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mangaConfigNotifier.value = MangaCharacterConfig(
      isVisible: prefs.getBool(_kVisible) ?? true,
      autoMove: prefs.getBool(_kAutoMove) ?? true,
      enableBlink: prefs.getBool(_kBlink) ?? true,
      size: prefs.getDouble(_kSize) ?? 90.0,
    );
  }

  static Future<void> save(MangaCharacterConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVisible, config.isVisible);
    await prefs.setBool(_kAutoMove, config.autoMove);
    await prefs.setBool(_kBlink, config.enableBlink);
    await prefs.setDouble(_kSize, config.size);
    mangaConfigNotifier.value = config;
  }
}

// ══════════════════════════════════════════════════════════════
// نافذة الإعدادات (Dialog)
// ══════════════════════════════════════════════════════════════
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
  late bool _isVisible;
  late bool _autoMove;
  late bool _enableBlink;
  late double _size;

  @override
  void initState() {
    super.initState();
    final config = mangaConfigNotifier.value;
    _isVisible = config.isVisible;
    _autoMove = config.autoMove;
    _enableBlink = config.enableBlink;
    _size = config.size;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = primaryColorNotifier.value;

    return AlertDialog(
      backgroundColor: const Color(0xFF1B1F28),
      title: const Row(
        children: [
          Icon(Icons.smart_toy, color: Color(0xFFFFC857)),
          SizedBox(width: 8),
          Text('إعدادات الشخصية'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('إظهار الشخصية'),
              subtitle: const Text('تشغيل أو إخفاء الشخصية العائمة'),
              value: _isVisible,
              activeColor: primaryColor,
              onChanged: (val) => setState(() => _isVisible = val),
            ),
            SwitchListTile(
              title: const Text('الحركة التلقائية'),
              subtitle: const Text('جعل الشخصية تطفو في أنحاء الشاشة'),
              value: _autoMove,
              activeColor: primaryColor,
              onChanged: _isVisible ? (val) => setState(() => _autoMove = val) : null,
            ),
            SwitchListTile(
              title: const Text('الرمش التلقائي'),
              subtitle: const Text('جعل الشخصية ترمش بين الحين والآخر'),
              value: _enableBlink,
              activeColor: primaryColor,
              onChanged: _isVisible ? (val) => setState(() => _enableBlink = val) : null,
            ),
            ListTile(
              title: const Text('حجم الشخصية'),
              subtitle: Slider(
                value: _size,
                min: 50,
                max: 150,
                divisions: 10,
                label: _size.round().toString(),
                activeColor: primaryColor,
                onChanged: _isVisible ? (val) => setState(() => _size = val) : null,
              ),
              trailing: Text('${_size.round()}'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.cyan,
                side: const BorderSide(color: Colors.cyan),
                minimumSize: const Size(double.infinity, 45),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: primaryColor),
          onPressed: () async {
            final newConfig = MangaCharacterConfig(
              isVisible: _isVisible,
              autoMove: _autoMove,
              enableBlink: _enableBlink,
              size: _size,
            );
            await MangaConfigService.save(newConfig);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
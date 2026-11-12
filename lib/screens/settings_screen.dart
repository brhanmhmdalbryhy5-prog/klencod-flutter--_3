import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/backup_service.dart';
import '../services/theme_service.dart';
import '../services/anime_api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool darkMode = true;
  bool backupBusy = false;
  bool isUpdatingGenres = false;

  final BackupService backupService = BackupService();
  final AnimeApiService apiService = AnimeApiService();

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      darkMode = prefs.getBool('isDarkMode') ?? true;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    setState(() => darkMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _showColorPicker() async {
    final selectedColor = await showDialog<Color>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          title: const Text('اختر لون التطبيق'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: appThemeColors.length,
              itemBuilder: (context, index) {
                final colorItem = appThemeColors[index];
                final isSelected = colorItem.color.value == primaryColorNotifier.value.value;
                return GestureDetector(
                  onTap: () => Navigator.pop(dialogContext, colorItem.color),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorItem.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3),
                      boxShadow: [BoxShadow(color: colorItem.color.withOpacity(0.6), blurRadius: 10, spreadRadius: 1)],
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (selectedColor != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('primaryColorValue', selectedColor.value);
      primaryColorNotifier.value = selectedColor;
    }
  }

  Future<void> _autoUpdateGenres() async {
    if (isUpdatingGenres) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('تحديث البيانات تلقائياً'),
        content: const Text(
          'سيقوم التطبيق بالبحث في الإنترنت عن تصنيفات، قصص، حلقات، وتقييمات الأنميات التي لا تحتوي عليها.\n\n'
          'قد تستغرق العملية بعض الوقت حسب عدد الأنميات. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: primaryColorNotifier.value),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => isUpdatingGenres = true);

    final result = await apiService.autoUpdateLibraryData();

    if (!mounted) return;
    setState(() => isUpdatingGenres = false);

    final updated = result['updated'] ?? 0;
    final failed = result['failed'] ?? 0;
    
    String message;
    if (updated == 0 && failed == 0) {
      message = 'كل الأنميات لديها بيانات بالفعل! لا حاجة للتحديث.';
    } else {
      message = 'تم تحديث $updated أنمي بنجاح.\n'
          'فشل تحديث $failed أنمي.\n\n'
          'ملاحظة: فشل التحديث غالباً بسبب أن اسم الأنمي مكتوب بالعربية. يرجى تعديل الأسماء إلى الإنجليزية.';
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('نتيجة التحديث'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('حسنًا')),
        ],
      ),
    );
  }

  Future<void> _clearAllGenres() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('مسح جميع التصنيفات'),
        content: const Text(
          'سيتم مسح التصنيفات من جميع الأنميات في مكتبتك. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF5A65)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('مسح الكل'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final count = await apiService.clearAllGenres();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم مسح التصنيفات من $count أنمي.')),
    );
  }

  Future<void> runBackupAction({required bool restore}) async {
    if (backupBusy) return;

    if (restore) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          title: const Text('استعادة نسخة احتياطية'),
          content: const Text('ستُستبدل قائمة الأنميات الحالية بالأنميات الموجودة في النسخة الاحتياطية.\n\nهل تريد المتابعة؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColorNotifier.value, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('متابعة'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => backupBusy = true);
    String result;
    try {
      result = restore ? await backupService.restoreBackup() : await backupService.createBackup();
    } catch (e) {
      result = 'حدث خطأ: $e';
    }
    if (!mounted) return;
    setState(() => backupBusy = false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: Text(restore ? 'نتيجة الاستعادة' : 'نتيجة النسخ الاحتياطي'),
        content: Text(result),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('حسنًا'))],
      ),
    );
  }

  void showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'ذاكرة الأوتاكو',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(Icons.shield, color: primaryColorNotifier.value, size: 40),
      children: const [
        Text('مساحتك الشخصية لتسجيل الأنميات التي شاهدتها، وتقييماتك وشخصياتك المفضلة وذكرياتك التي لا تُنسى.'),
        SizedBox(height: 12),
        Text('مع تحياتي لكل أوتاكو يصنع ذكرياته الخاصة.'),
      ],
    );
  }

  void showStorageInfo() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('التخزين المحلي'),
        content: const Text('يحفظ التطبيق بياناتك محليًا على الهاتف. لكن عند حذف التطبيق قد تُحذف بياناته الداخلية أيضًا. استخدم النسخ الاحتياطي واحفظ ملف ZIP في مجلد التنزيلات أو مكان آمن خارج التطبيق.'),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('حسنًا'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = primaryColorNotifier.value;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('الإعدادات', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        const Text('تحكّم في تطبيقك وبياناتك.', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.3), const Color(0xFF202431)], begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 3)],
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 46, color: Colors.white),
              SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ذاكرة الأوتاكو', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('إصدار 1.0.0', style: TextStyle(color: Colors.white70))])),
            ],
          ),
        ),
        const SizedBox(height: 25),
        const Text('التخصيص', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _settingsTile(
          icon: Icons.palette_outlined,
          color: primaryColor,
          title: 'المظهر',
          subtitle: darkMode ? 'الوضع الداكن' : 'الوضع الفاتح',
          trailing: Switch(value: darkMode, activeColor: primaryColor, onChanged: _toggleTheme),
          onTap: null,
        ),
        const SizedBox(height: 10),
        _settingsTile(
          icon: Icons.color_lens_outlined,
          color: primaryColor,
          title: 'لون التطبيق',
          subtitle: 'تغيير اللون الأساسي للتطبيق (18 لوناً)',
          trailing: const Icon(Icons.chevron_left, color: Colors.white38),
          onTap: _showColorPicker,
        ),
        const SizedBox(height: 10),
        _settingsTile(
          icon: Icons.sync_alt,
          color: const Color(0xFF3A91B5),
          title: 'تحديث البيانات تلقائياً',
          subtitle: 'جلب التصنيفات، القصص، الحلقات، والتقييمات من الإنترنت',
          trailing: isUpdatingGenres
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_left, color: Colors.white38),
          onTap: isUpdatingGenres ? null : _autoUpdateGenres,
        ),
        const SizedBox(height: 10),
        _settingsTile(
          icon: Icons.delete_sweep_outlined,
          color: const Color(0xFFFF5A65),
          title: 'مسح جميع التصنيفات',
          subtitle: 'حذف التصنيفات من جميع الأنميات (لا يمكن التراجع)',
          trailing: const Icon(Icons.chevron_left, color: Colors.white38),
          onTap: _clearAllGenres,
        ),
        const SizedBox(height: 24),
        const Text('إدارة البيانات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _settingsTile(
          icon: Icons.backup_outlined,
          color: const Color(0xFF35B77A),
          title: 'إنشاء نسخة احتياطية',
          subtitle: 'حفظ بياناتك في ملف ZIP داخل ملفات الهاتف',
          trailing: const Icon(Icons.chevron_left, color: Colors.white38),
          onTap: backupBusy ? null : () => runBackupAction(restore: false),
        ),
        const SizedBox(height: 10),
        _settingsTile(
          icon: Icons.settings_backup_restore,
          color: const Color(0xFFFFC857),
          title: 'استعادة نسخة احتياطية',
          subtitle: 'استرجاع بياناتك من ملف ZIP محفوظ',
          trailing: const Icon(Icons.chevron_left, color: Colors.white38),
          onTap: backupBusy ? null : () => runBackupAction(restore: true),
        ),
        if (backupBusy) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 8),
          const Center(child: Text('جارٍ تجهيز البيانات...', style: TextStyle(color: Colors.white60))),
        ],
        const SizedBox(height: 10),
        _settingsTile(
          icon: Icons.storage_outlined,
          color: const Color(0xFF247BA0),
          title: 'التخزين المحلي',
          subtitle: 'معلومات عن حفظ البيانات على الهاتف',
          trailing: const Icon(Icons.chevron_left, color: Colors.white38),
          onTap: showStorageInfo,
        ),
        const SizedBox(height: 24),
        const Text('حول التطبيق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _settingsTile(
          icon: Icons.info_outline,
          color: const Color(0xFFFFC857),
          title: 'عن ذاكرة الأوتاكو',
          subtitle: 'معلومات عن التطبيق',
          trailing: const Icon(Icons.chevron_left, color: Colors.white38),
          onTap: showAbout,
        ),
        const SizedBox(height: 28),
        const Center(child: Text('صُنع للأوتاكو، ليحفظ كل ذكرى.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12))),
      ],
    );
  }

  Widget _settingsTile({required IconData icon, required Color color, required String title, required String subtitle, required Widget trailing, required VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: Container(
          width: 43, height: 43,
          decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11))),
        trailing: trailing,
      ),
    );
  }
}
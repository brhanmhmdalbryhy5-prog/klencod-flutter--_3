import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/backup_service.dart';
import '../services/theme_service.dart';
import '../services/anime_api_service.dart';
import '../services/bulk_download_service.dart';
import 'trash_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool darkMode = true;
  bool backupBusy = false;
  bool autoFetchEnabled = false;
  bool isUpdatingGenres = false;

  final BackupService backupService = BackupService();
  final AnimeApiService apiService = AnimeApiService();
  final BulkDownloadService bulkService = BulkDownloadService();

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
      autoFetchEnabled = prefs.getBool('auto_fetch_enabled') ?? false;
    });
  }

  Future<void> _toggleAutoFetch(bool value) async {
    setState(() => autoFetchEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_fetch_enabled', value);
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
                    decoration: BoxDecoration(color: colorItem.color, shape: BoxShape.circle, border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3), boxShadow: [BoxShadow(color: colorItem.color.withOpacity(0.6), blurRadius: 10, spreadRadius: 1)]),
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

  Future<void> _showFontPicker() async {
    final fonts = ['Cairo', 'Tajawal', 'Almarai', 'Changa'];
    final selectedFont = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          title: const Text('اختر خط اسم الأنمي'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: fonts.map((font) {
              return ListTile(
                title: Text(font, style: TextStyle(fontFamily: font, color: Colors.white)),
                trailing: fontNotifier.value == font ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () => Navigator.pop(dialogContext, font),
              );
            }).toList(),
          ),
        );
      },
    );

    if (selectedFont != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_font', selectedFont);
      fontNotifier.value = selectedFont;
    }
  }

  Future<void> _showTitleColorPicker() async {
    final colors = [const Color(0xFFFFD700), Colors.white, Colors.cyan, Colors.greenAccent, Colors.pinkAccent, Colors.orangeAccent];
    final selectedColor = await showDialog<Color>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          title: const Text('اختر لون اسم الأنمي'),
          content: Wrap(
            spacing: 10, runSpacing: 10,
            children: colors.map((color) {
              return GestureDetector(
                onTap: () => Navigator.pop(dialogContext, color),
                child: Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: titleColorNotifier.value == color ? Colors.white : Colors.transparent, width: 3)),
                ),
              );
            }).toList(),
          ),
        );
      },
    );

    if (selectedColor != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('title_color', selectedColor.value);
      titleColorNotifier.value = selectedColor;
    }
  }

  Future<void> _showDownloadResult(Map<String, dynamic> result) async {
    final updated = result['updated'] ?? 0;
    final failed = result['failed'] ?? 0;
    final failedNames = (result['failedNames'] as List?)?.cast<String>() ?? [];
    final error = result['error'];

    if (error == 'no_internet') {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          title: const Row(children: [
            Icon(Icons.wifi_off, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('لا يوجد إنترنت'),
          ]),
          content: const Text('يرجى تشغيل الاتصال بالإنترنت ثم المحاولة مرة أخرى.', style: TextStyle(height: 1.6)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
        ),
      );
      return;
    }

    if (error == 'connection_lost') {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          title: const Row(children: [
            Icon(Icons.wifi_off, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('انقطع الاتصال'),
          ]),
          content: Text(
            'انقطع الإنترنت أثناء العملية.\n\n'
            '✅ نجح: $updated أنمي\n'
            '❌ فشل: $failed أنمي',
            style: const TextStyle(height: 1.6),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
        ),
      );
      return;
    }

    if (failedNames.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          title: const Row(children: [
            Icon(Icons.info_outline, color: Colors.amber),
            SizedBox(width: 8),
            Text('نتيجة التحميل'),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ نجح: $updated أنمي', style: const TextStyle(color: Colors.greenAccent)),
                Text('❌ فشل: $failed أنمي', style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 12),
                const Text('الأنميات التي لم يتم العثور عليها:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: failedNames.map((name) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text('• $name', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      )).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'ملاحظة: هذه الأنميات قد لا تكون في قاعدة البيانات أو أسماؤها غير دقيقة. جرّب تغيير الاسم إلى الإنجليزية.',
                  style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.5),
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ اكتمل بنجاح: $updated أنمي')),
      );
    }
  }

  Future<void> _startBulkDownload() async {
    if (bulkService.isRunning) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('تحميل البيانات الكاملة'),
        content: const Text(
          'سيقوم التطبيق بجلب جميع البيانات والصور والمواسم والشخصيات لكل الأنميات في مكتبتك وحفظها محلياً.\n\n'
          'يمكنك الاستمرار في استخدام التطبيق أثناء التحميل.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: primaryColorNotifier.value),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ابدأ التحميل'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    final result = await bulkService.downloadAllData();
    if (!mounted) return;
    await _showDownloadResult(result);
  }

  // 🆕 تحميل المواسم والشخصيات فقط
  Future<void> _startSeasonsAndCharactersDownload() async {
    if (bulkService.isRunning) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('تحميل المواسم والشخصيات فقط'),
        content: const Text(
          'سيقوم التطبيق بجلب المواسم والأفلام المرتبطة والشخصيات الرئيسية لكل الأنميات في مكتبتك.\n\n'
          '✅ سريع (بدون ترجمة ملخص الأنمي الأصلي)\n'
          '✅ لن يتم تعديل بيانات الأنمي الأصلية (القصة، التصنيفات، الصورة)',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: primaryColorNotifier.value),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ابدأ التحميل'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    final result = await bulkService.downloadSeasonsAndCharactersOnly();
    if (!mounted) return;
    await _showDownloadResult(result);
  }

  Future<void> _startImagesDownload() async {
    if (bulkService.isRunning) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('تحميل الصور المفقودة'),
        content: const Text('سيقوم التطبيق بتحميل جميع الصور غير المحفوظة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: primaryColorNotifier.value),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ابدأ'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    final result = await bulkService.downloadImagesOnly();
    if (!mounted) return;
    await _showDownloadResult(result);
  }

  Future<void> _clearAllGenres() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('مسح جميع التصنيفات'),
        content: const Text('سيتم مسح التصنيفات من جميع الأنميات في مكتبتك. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF5A65)), onPressed: () => Navigator.pop(dialogContext, true), child: const Text('مسح الكل')),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    final count = await apiService.clearAllGenres();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم مسح التصنيفات من $count أنمي.')));
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
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: primaryColorNotifier.value, foregroundColor: Colors.white), onPressed: () => Navigator.pop(dialogContext, true), child: const Text('متابعة')),
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

    return ValueListenableBuilder<BulkDownloadProgress?>(
      valueListenable: bulkService.progress,
      builder: (context, progress, _) {
        final isDownloading = bulkService.isRunning && progress != null && !progress.isCompleted;

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('الإعدادات', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            const Text('تحكّم في تطبيقك وبياناتك.', style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(19),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.3), const Color(0xFF202431)], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 3)]),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 46, color: Colors.white),
                  SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ذاكرة الأوتاكو', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('إصدار 1.0.0', style: TextStyle(color: Colors.white70))])),
                ],
              ),
            ),

            if (isDownloading) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: const Color(0xFF1B1F28), borderRadius: BorderRadius.circular(16), border: Border.all(color: primaryColor.withOpacity(0.5))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_download, color: Colors.cyan, size: 24),
                        const SizedBox(width: 10),
                        Expanded(child: Text(progress.status, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(progress.currentTitle, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(value: progress.percentage, minHeight: 8, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => bulkService.cancel(),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('إيقاف العملية'),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 25),
            const Text('التخصيص', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _settingsTile(icon: Icons.palette_outlined, color: primaryColor, title: 'المظهر', subtitle: darkMode ? 'الوضع الداكن' : 'الوضع الفاتح', trailing: Switch(value: darkMode, activeColor: primaryColor, onChanged: _toggleTheme), onTap: null),
            const SizedBox(height: 10),
            _settingsTile(icon: Icons.color_lens_outlined, color: primaryColor, title: 'لون التطبيق', subtitle: 'تغيير اللون الأساسي', trailing: const Icon(Icons.chevron_left, color: Colors.white38), onTap: _showColorPicker),
            const SizedBox(height: 10),
            _settingsTile(icon: Icons.font_download_outlined, color: primaryColor, title: 'خط اسم الأنمي', subtitle: 'اختيار الخط المفضل', trailing: const Icon(Icons.chevron_left, color: Colors.white38), onTap: _showFontPicker),
            const SizedBox(height: 10),
            _settingsTile(icon: Icons.format_color_text, color: titleColorNotifier.value, title: 'لون اسم الأنمي', subtitle: 'تغيير لون النص', trailing: const Icon(Icons.chevron_left, color: Colors.white38), onTap: _showTitleColorPicker),

            const SizedBox(height: 24),
            const Text('التحميل والتحديث', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _settingsTile(
              icon: Icons.sync,
              color: const Color(0xFFFF9F43),
              title: 'التحديث التلقائي عند فتح التطبيق',
              subtitle: autoFetchEnabled ? 'مُفعّل' : 'معطّل (التطبيق لا يعمل إلا بأمرك)',
              trailing: Switch(value: autoFetchEnabled, activeColor: primaryColor, onChanged: _toggleAutoFetch),
              onTap: null,
            ),
            const SizedBox(height: 10),
            _settingsTile(
              icon: Icons.cloud_download_outlined,
              color: const Color(0xFF3A91B5),
              title: 'تحميل شامل (بيانات + صور + مواسم)',
              subtitle: 'يجلب كل شيء ويحفظه محلياً',
              trailing: const Icon(Icons.chevron_left, color: Colors.white38),
              onTap: isDownloading ? null : _startBulkDownload,
            ),
            const SizedBox(height: 10),
            // 🆕 الزر الجديد: تحميل المواسم والشخصيات فقط
            _settingsTile(
              icon: Icons.groups_outlined,
              color: Colors.purpleAccent,
              title: 'تحميل المواسم والشخصيات فقط',
              subtitle: 'يجلب المواسم والأفلام دون تعديل بيانات الأنمي الأصلي',
              trailing: const Icon(Icons.chevron_left, color: Colors.white38),
              onTap: isDownloading ? null : _startSeasonsAndCharactersDownload,
            ),
            const SizedBox(height: 10),
            _settingsTile(
              icon: Icons.image_outlined,
              color: const Color(0xFF9B59B6),
              title: 'تحميل الصور المفقودة فقط',
              subtitle: 'يحمل الصور غير المحفوظة',
              trailing: const Icon(Icons.chevron_left, color: Colors.white38),
              onTap: isDownloading ? null : _startImagesDownload,
            ),
            const SizedBox(height: 10),
            _settingsTile(icon: Icons.delete_sweep_outlined, color: const Color(0xFFFF5A65), title: 'مسح جميع التصنيفات', subtitle: 'حذف التصنيفات من جميع الأنميات', trailing: const Icon(Icons.chevron_left, color: Colors.white38), onTap: _clearAllGenres),
            const SizedBox(height: 10),
            _settingsTile(icon: Icons.delete_outline, color: const Color(0xFFFFB74D), title: 'سلة المهملات', subtitle: 'استعادة الأنميات المحذوفة', trailing: const Icon(Icons.chevron_left, color: Colors.white38), onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const TrashScreen())); }),

            const SizedBox(height: 24),
            const Text('النسخ الاحتياطي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _settingsTile(icon: Icons.backup_outlined, color: const Color(0xFF35B77A), title: 'إنشاء نسخة احتياطية', subtitle: 'حفظ بياناتك (مع الصور والفيديوهات)', trailing: const Icon(Icons.chevron_left, color: Colors.white38), onTap: backupBusy ? null : () => runBackupAction(restore: false)),
            const SizedBox(height: 10),
            _settingsTile(icon: Icons.settings_backup_restore, color: const Color(0xFFFFC857), title: 'استعادة نسخة احتياطية', subtitle: 'استرجاع بياناتك', trailing: const Icon(Icons.chevron_left, color: Colors.white38), onTap: backupBusy ? null : () => runBackupAction(restore: true)),
            if (backupBusy) ...[const SizedBox(height: 16), const Center(child: CircularProgressIndicator()), const SizedBox(height: 8), const Center(child: Text('جارٍ تجهيز البيانات...', style: TextStyle(color: Colors.white60)))],

            const SizedBox(height: 24),
            const Text('حول التطبيق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _settingsTile(icon: Icons.info_outline, color: const Color(0xFFFFC857), title: 'عن ذاكرة الأوتاكو', subtitle: 'معلومات عن التطبيق', trailing: const Icon(Icons.chevron_left, color: Colors.white38), onTap: showAbout),
            const SizedBox(height: 28),
            const Center(child: Text('صُنع للأوتاكو، ليحفظ كل ذكرى.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12))),
          ],
        );
      },
    );
  }

  Widget _settingsTile({required IconData icon, required Color color, required String title, required String subtitle, required Widget trailing, required VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1B1F28), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.4), width: 1), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)]),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: Container(width: 43, height: 43, decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11))),
        trailing: trailing,
      ),
    );
  }
}
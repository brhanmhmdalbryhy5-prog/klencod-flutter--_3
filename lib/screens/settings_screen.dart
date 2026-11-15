import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/backup_service.dart';
import '../services/theme_service.dart';
import '../services/anime_api_service.dart';
import '../services/bulk_download_service.dart';
import '../services/storage_service.dart';
import '../services/video_compression_service.dart';
import '../services/data_health_service.dart';
import '../services/export_service.dart';
import 'trash_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool darkMode = true;
  bool autoDarkMode = false;
  bool backupBusy = false;
  bool autoFetchEnabled = false;
  bool isCheckingHealth = false;
  bool isCompressing = false;
  bool isClassifying = false;

  final BackupService backupService = BackupService();
  final AnimeApiService apiService = AnimeApiService();
  final BulkDownloadService bulkService = BulkDownloadService();
  final StorageService storage = StorageService();

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
      autoDarkMode = prefs.getBool('auto_dark_mode') ?? false;
      autoFetchEnabled = prefs.getBool('auto_fetch_enabled') ?? false;
    });
  }

  Future<void> _toggleAutoDark(bool value) async {
    setState(() => autoDarkMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_dark_mode', value);
    isAutoDarkModeEnabled = value;
    checkAutoTheme();
    if (!value) await _toggleTheme(darkMode);
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

  // ══════════════════════════════════════════════════════════════
  // 🆕 فرز الأفلام تلقائياً
  // ══════════════════════════════════════════════════════════════
  Future<void> _autoClassifyMovies() async {
    if (isClassifying) return;

    final animes = await storage.loadAnimes();
    final toCheck = animes.where((a) => a.parentId == null).toList();

    if (toCheck.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مكتبتك فارغة.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('فرز الأفلام تلقائياً'),
        content: Text(
          'سيقوم التطبيق بفحص ${toCheck.length} أنمي عبر الإنترنت لتحديد إذا كان فيلماً مستقلاً أو مسلسلاً.\n\n'
          'الأفلام المستقلة ستنتقل تلقائياً إلى تبويب "أفلام".\n\n'
          '⚠️ قد تستغرق العملية عدة دقائق حسب سرعة الإنترنت.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: primaryColorNotifier.value),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ابدأ الفرز'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => isClassifying = true);

    final progressNotifier = ValueNotifier<double>(0.0);
    final currentNotifier = ValueNotifier<String>('جاري التحضير...');
    bool dialogClosed = false;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.movie_filter, size: 50, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              const Text('جاري فرز الأفلام...',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: currentNotifier,
                builder: (context, value, _) => Text(value,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: value, minHeight: 10,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        primaryColorNotifier.value),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    int classifiedMovies = 0;
    int classifiedSeries = 0;
    int failed = 0;

    try {
      for (int i = 0; i < toCheck.length; i++) {
        final anime = toCheck[i];
        progressNotifier.value = (i + 1) / toCheck.length;
        currentNotifier.value = '(${i + 1}/${toCheck.length}) ${anime.title}';

        try {
          final data = await apiService.fetchAnimeData(
            anime.title,
            skipTranslation: true,
          );
          final fetchedFormat = data['format'] as String?;
          if (fetchedFormat != null) {
            final idx = animes.indexWhere((a) => a.id == anime.id);
            if (idx != -1) {
              animes[idx].format = fetchedFormat;
              if (fetchedFormat == 'MOVIE') classifiedMovies++;
              else classifiedSeries++;
            }
          } else {
            failed++;
          }
          await storage.saveAnimes(animes);
          await Future.delayed(const Duration(milliseconds: 600));
        } catch (_) {
          failed++;
        }
      }

      dialogClosed = true;
      if (mounted) Navigator.pop(context);

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          title: const Text('نتيجة الفرز'),
          content: Text(
            '🎬 تم تصنيف ${classifiedMovies} كفيلم مستقل.\n'
            '📺 تم تصنيف ${classifiedSeries} كمسلسل.\n'
            '❌ فشل تصنيف $failed أنمي (اسم غير دقيق أو غير موجود).\n\n'
            '💡 الأفلام ظهرت الآن في تبويب "أفلام" داخل المكتبة.',
            style: const TextStyle(height: 1.8),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('حسنًا'))
          ],
        ),
      );
    } catch (e) {
      if (!dialogClosed && mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isClassifying = false);
    }
  }

  Future<void> _checkHealth() async {
    if (isCheckingHealth) return;
    setState(() => isCheckingHealth = true);
    final result = await DataHealthService().checkAndFix();
    if (!mounted) return;
    setState(() => isCheckingHealth = false);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('تقرير فحص البيانات'),
        content: Text(
          'إجمالي الأنميات: ${result.totalAnimes}\n\n'
          '✅ تم إصلاح ${result.fixedPaths} مسار (صور/فيديو مفقود).\n'
          '⚠️ عدد التنبيهات: ${result.issues.length}',
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'))
        ],
      ),
    );
  }

  Future<void> _compressAllVideos() async {
    if (isCompressing) return;

    final animes = await storage.loadAnimes();
    final videosCount = animes
        .where((a) => a.videoPath != null && a.videoPath!.isNotEmpty)
        .length;

    if (videosCount == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد فيديوهات لضغطها.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('ضغط الفيديوهات التذكارية'),
        content: Text(
          'سيتم ضغط $videosCount فيديو بجودة متوسطة (720p).\n\n'
          'ملاحظة: قد تقل الجودة قليلاً، لكن الحجم سينخفض 50-70%.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: primaryColorNotifier.value),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ابدأ الضغط'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => isCompressing = true);

    final progressNotifier = ValueNotifier<String>('جاري التحضير...');
    final percentNotifier = ValueNotifier<double>(0.0);
    bool dialogClosed = false;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.compress, size: 50, color: Colors.purpleAccent),
              const SizedBox(height: 16),
              const Text('جاري ضغط الفيديوهات...',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 16),
              ValueListenableBuilder<String>(
                valueListenable: progressNotifier,
                builder: (context, value, _) => Text(value,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<double>(
                valueListenable: percentNotifier,
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                      value: value,
                      minHeight: 10,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          primaryColorNotifier.value)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    try {
      final result = await VideoCompressionService().compressAllVideos(
        animes: animes,
        onSave: () => storage.saveAnimes(animes),
        onProgress: (current, total, title) {
          percentNotifier.value = current / total;
          progressNotifier.value = '($current/$total) $title';
        },
      );

      dialogClosed = true;
      if (mounted) Navigator.pop(context);

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          title: const Text('نتيجة الضغط'),
          content: Text(
            '✅ تم ضغط: ${result.compressed} فيديو\n'
            '⏭️ تم تخطي: ${result.skipped}\n'
            '❌ فشل: ${result.failed}\n\n'
            '💾 تم توفير: ${result.savedFormatted}',
            style: const TextStyle(height: 1.8),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('حسنًا'))
          ],
        ),
      );
    } catch (e) {
      if (!dialogClosed && mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => isCompressing = false);
    }
  }

  Future<void> _showExportDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('تصدير المكتبة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _exportOption(
                icon: Icons.picture_as_pdf,
                color: Colors.redAccent,
                title: 'PDF احترافي',
                subtitle: 'كتالوج قابل للطباعة',
                onTap: () => Navigator.pop(dialogContext, 'pdf')),
            const SizedBox(height: 8),
            _exportOption(
                icon: Icons.table_chart,
                color: Colors.greenAccent,
                title: 'CSV (Excel)',
                subtitle: 'جدول بيانات قابل للتعديل',
                onTap: () => Navigator.pop(dialogContext, 'csv')),
            const SizedBox(height: 8),
            _exportOption(
                icon: Icons.code,
                color: Colors.blueAccent,
                title: 'Markdown',
                subtitle: 'للمدونات والمواقع',
                onTap: () => Navigator.pop(dialogContext, 'md')),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;
    setState(() => backupBusy = true);

    final exportService = ExportService();
    String result;
    try {
      if (choice == 'pdf') {
        result = await exportService.exportAsPdf();
      } else if (choice == 'csv') {
        result = await exportService.exportAsCsv();
      } else {
        result = await exportService.exportAsMarkdown();
      }
    } catch (e) {
      result = 'حدث خطأ: $e';
    }

    if (!mounted) return;
    setState(() => backupBusy = false);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('نتيجة التصدير'),
        content: Text(result),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسنًا'))
        ],
      ),
    );
  }

  Widget _exportOption(
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFF111318),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4))),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(title,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  Future<void> _showColorPicker() async {
    final selectedColor = await showDialog<Color>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          title: const Text('اختر لون التطبيق', style: TextStyle(fontSize: 18)),
          content: SizedBox(
            width: double.maxFinite,
            height: 450,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10),
              itemCount: appThemeColors.length,
              itemBuilder: (context, index) {
                final colorItem = appThemeColors[index];
                final isSelected = colorItem.color.value ==
                    primaryColorNotifier.value.value;
                return GestureDetector(
                  onTap: () =>
                      Navigator.pop(dialogContext, colorItem.color),
                  child: Tooltip(
                    message: colorItem.name,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorItem.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: 3),
                        boxShadow: [
                          BoxShadow(
                              color: colorItem.color.withOpacity(0.6),
                              blurRadius: 10,
                              spreadRadius: 1)
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
                          : null,
                    ),
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
                title: Text(font,
                    style: TextStyle(fontFamily: font, color: Colors.white)),
                trailing: fontNotifier.value == font
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
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
    final colors = [
      const Color(0xFFFFD700), Colors.white, Colors.cyan,
      Colors.greenAccent, Colors.pinkAccent, Colors.orangeAccent
    ];
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
                  decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: titleColorNotifier.value == color
                              ? Colors.white
                              : Colors.transparent,
                          width: 3)),
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
    final failedNames =
        (result['failedNames'] as List?)?.cast<String>() ?? [];
    final error = result['error'];

    if (error == 'no_internet') {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          title: const Row(children: [
            Icon(Icons.wifi_off, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('لا يوجد إنترنت')
          ]),
          content: const Text(
              'يرجى تشغيل الاتصال بالإنترنت ثم المحاولة مرة أخرى.',
              style: TextStyle(height: 1.6)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'))
          ],
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
            Text('انقطع الاتصال')
          ]),
          content: Text(
            'انقطع الإنترنت أثناء العملية.\n\n'
            '✅ نجح: $updated أنمي\n'
            '❌ فشل: $failed أنمي',
            style: const TextStyle(height: 1.6),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'))
          ],
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
            Text('نتيجة التحميل')
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ نجح: $updated أنمي',
                    style: const TextStyle(color: Colors.greenAccent)),
                Text('❌ فشل: $failed أنمي',
                    style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 12),
                const Text('الأنميات التي لم يتم العثور عليها:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: failedNames
                          .map((name) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
                                child: Text('• $name',
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12)),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'))
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ اكتمل بنجاح: $updated أنمي')));
    }
  }

  Future<void> _runAction(
      {required Future<Map<String, dynamic>> Function() action}) async {
    if (bulkService.isRunning) return;
    try {
      final result = await action();
      if (mounted) await _showDownloadResult(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    }
  }

  Future<void> _startBulkDownload() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('تحميل البيانات الكاملة'),
        content: const Text(
            'سيقوم التطبيق بجلب جميع البيانات والصور والمواسم والشخصيات لكل الأنميات وحفظها محلياً.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: primaryColorNotifier.value),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ابدأ التحميل')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _runAction(action: () => bulkService.downloadAllData());
  }

  Future<void> _startSeasonsAndCharactersDownload() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('تحميل المواسم والشخصيات فقط'),
        content: const Text(
            'سيقوم التطبيق بجلب المواسم والأفلام المرتبطة والشخصيات الرئيسية.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: primaryColorNotifier.value),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ابدأ التحميل')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _runAction(
        action: () => bulkService.downloadSeasonsAndCharactersOnly());
  }

  Future<void> _startSeasonsOnlyDownload() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('جلب المواسم والأفلام فقط'),
        content: const Text(
            'سيجلب المواسم والأفلام المرتبطة بكل أنمي، دون المساس بالشخصيات.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: primaryColorNotifier.value),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ابدأ')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _runAction(action: () => bulkService.downloadSeasonsOnly());
  }

  Future<void> _startCharactersOnlyDownload() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('جلب شخصيات الأنمي فقط'),
        content: const Text(
            'سيجلب شخصيات الأنمي الأصلي فقط، دون المساس بالمواسم.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: primaryColorNotifier.value),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ابدأ')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _runAction(action: () => bulkService.downloadCharactersOnly());
  }

  Future<void> _startImagesDownload() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('تحميل الصور المفقودة'),
        content:
            const Text('سيقوم التطبيق بتحميل جميع الصور غير المحفوظة.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: primaryColorNotifier.value),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ابدأ')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _runAction(action: () => bulkService.downloadImagesOnly());
  }

  Future<void> _startMissingImagesDownload() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('تنشيط صور الشخصيات والمواسم'),
        content: const Text(
            'سيتحقق التطبيق من كل صورة (أغلفة + شخصيات) لكل الأنميات والمواسم.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: primaryColorNotifier.value),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ابدأ')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _runAction(action: () => bulkService.downloadAllMissingImages());
  }

  Future<void> _startScenesDownload() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('جلب صور الأنمي (ملصقات)'),
        content: const Text(
            'سيقوم التطبيق بجلب جميع الصور الترويجية المتاحة لكل الأنمي.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: primaryColorNotifier.value),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ابدأ')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _runAction(action: () => bulkService.downloadAllScenes());
  }

  Future<void> _clearAllGenres() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('مسح جميع التصنيفات'),
        content: const Text(
            'سيتم مسح التصنيفات من جميع الأنميات في مكتبتك. هل أنت متأكد؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5A65)),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('مسح الكل')),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    final count = await apiService.clearAllGenres();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم مسح التصنيفات من $count أنمي.')));
  }

  Future<void> runBackupAction({required bool restore}) async {
    if (backupBusy) return;
    if (restore) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          title: const Text('استعادة نسخة احتياطية'),
          content: const Text(
              'ستُستبدل قائمة الأنميات الحالية بالأنميات الموجودة في النسخة الاحتياطية.\n\nهل تريد المتابعة؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء')),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColorNotifier.value,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('متابعة')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => backupBusy = true);
    String result;
    try {
      result = restore
          ? await backupService.restoreBackup()
          : await backupService.createBackup();
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
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('حسنًا'))
        ],
      ),
    );
  }

  Future<void> _runLiteBackup({required bool restore}) async {
    if (backupBusy) return;
    if (restore) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          title: const Text('استعادة النسخة الخفيفة'),
          content: const Text(
              'ستُستبدل بيانات الأنميات الحالية (الأغلفة والشخصيات).\nالفيديوهات والمشاهد والذكريات ستبقى كما هي.\n\nهل تريد المتابعة؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColorNotifier.value,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('متابعة')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => backupBusy = true);
    String result;
    try {
      result = restore
          ? await backupService.restoreLiteBackup()
          : await backupService.createLiteBackup();
    } catch (e) {
      result = 'حدث خطأ: $e';
    }
    if (!mounted) return;
    setState(() => backupBusy = false);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: Text(restore
            ? 'نتيجة استعادة النسخة الخفيفة'
            : 'نتيجة النسخة الخفيفة'),
        content: Text(result),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('حسنًا'))
        ],
      ),
    );
  }

  void showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'ذاكرة الأوتاكو',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(Icons.shield,
          color: primaryColorNotifier.value, size: 40),
      children: const [
        Text(
            'مساحتك الشخصية لتسجيل الأنميات التي شاهدتها، وتقييماتك وشخصياتك المفضلة وذكرياتك التي لا تُنسى.'),
        SizedBox(height: 12),
        Text('مع تحياتي لكل أوتاكو يصنع ذكرياته الخاصة.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = primaryColorNotifier.value;

    return ValueListenableBuilder<BulkDownloadProgress?>(
      valueListenable: bulkService.progress,
      builder: (context, progress, _) {
        final isDownloading = bulkService.isRunning &&
            progress != null &&
            !progress.isCompleted;

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('الإعدادات',
                style:
                    TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            const Text('تحكّم في تطبيقك وبياناتك.',
                style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(19),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        primaryColor.withOpacity(0.3),
                        const Color(0xFF202431)
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 3)
                  ]),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 46, color: Colors.white),
                  SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('ذاكرة الأوتاكو',
                            style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900)),
                        SizedBox(height: 5),
                        Text('إصدار 1.0.0',
                            style: TextStyle(color: Colors.white70))
                      ])),
                ],
              ),
            ),

            if (isDownloading) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                    color: const Color(0xFF1B1F28),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: primaryColor.withOpacity(0.5))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.cloud_download,
                          color: Colors.cyan, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(progress.status,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)))
                    ]),
                    const SizedBox(height: 10),
                    Text(progress.currentTitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                            value: progress.percentage,
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                primaryColor))),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                          onPressed: () => bulkService.cancel(),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(
                                  color: Colors.redAccent)),
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('إيقاف العملية')),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 25),
            const Text('التخصيص',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),

            _settingsTile(
                icon: Icons.dark_mode_outlined,
                color: primaryColor,
                title: 'الوضع الليلي التلقائي',
                subtitle: autoDarkMode
                    ? 'مُفعّل (يتغير حسب وقت اليوم)'
                    : 'معطّل',
                trailing: Switch(
                    value: autoDarkMode,
                    activeColor: primaryColor,
                    onChanged: _toggleAutoDark),
                onTap: null),
            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.palette_outlined,
                color: primaryColor,
                title: 'المظهر اليدوي',
                subtitle: darkMode ? 'الوضع الداكن' : 'الوضع الفاتح',
                trailing: Switch(
                    value: darkMode,
                    activeColor: primaryColor,
                    onChanged: autoDarkMode ? null : _toggleTheme),
                onTap: null),
            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.color_lens_outlined,
                color: primaryColor,
                title: 'لون التطبيق',
                subtitle: 'تغيير اللون الأساسي',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: _showColorPicker),
            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.font_download_outlined,
                color: primaryColor,
                title: 'خط اسم الأنمي',
                subtitle: 'اختيار الخط المفضل',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: _showFontPicker),
            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.format_color_text,
                color: titleColorNotifier.value,
                title: 'لون اسم الأنمي',
                subtitle: 'تغيير لون النص',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: _showTitleColorPicker),

            const SizedBox(height: 24),
            const Text('التحميل والتحديث',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _settingsTile(
                icon: Icons.sync,
                color: const Color(0xFFFF9F43),
                title: 'التحديث التلقائي عند فتح التطبيق',
                subtitle: autoFetchEnabled
                    ? 'مُفعّل'
                    : 'معطّل (التطبيق لا يعمل إلا بأمرك)',
                trailing: Switch(
                    value: autoFetchEnabled,
                    activeColor: primaryColor,
                    onChanged: _toggleAutoFetch),
                onTap: null),
            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.cloud_download_outlined,
                color: const Color(0xFF3A91B5),
                title: 'تحميل شامل (بيانات + صور + مواسم)',
                subtitle: 'يجلب كل شيء ويحفظه محلياً',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: isDownloading ? null : _startBulkDownload),
            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.groups_outlined,
                color: Colors.purpleAccent,
                title: 'تحميل المواسم والشخصيات فقط',
                subtitle:
                    'يجلب المواسم والأفلام دون تعديل بيانات الأنمي الأصلي',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: isDownloading
                    ? null
                    : _startSeasonsAndCharactersDownload),
            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.movie_filter_outlined,
                color: const Color(0xFFE67E22),
                title: 'جلب المواسم والأفلام فقط',
                subtitle:
                    'يجلب المواسم والأفلام المرتبطة فقط (بدون شخصيات)',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: isDownloading ? null : _startSeasonsOnlyDownload),
            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.people_alt_outlined,
                color: Colors.purpleAccent,
                title: 'جلب شخصيات الأنمي فقط',
                subtitle: 'يجلب شخصيات الأنمي الأصلي فقط (بدون مواسم)',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: isDownloading ? null : _startCharactersOnlyDownload),
            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.image_outlined,
                color: const Color(0xFF9B59B6),
                title: 'تحميل الصور المفقودة فقط',
                subtitle: 'يحمل الصور غير المحفوظة',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: isDownloading ? null : _startImagesDownload),
            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.auto_fix_high,
                color: const Color(0xFF00BFA5),
                title: 'تنشيط صور الشخصيات والمواسم',
                subtitle:
                    'يجلب كل صورة مفقودة (أغلفة + شخصيات) لكل الأنميات والمواسم',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: isDownloading ? null : _startMissingImagesDownload),
            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.collections,
                color: const Color(0xFF00ACC1),
                title: 'جلب صور الأنمي (ملصقات)',
                subtitle: 'يجلب صور ترويجية لكل أنمي',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: isDownloading ? null : _startScenesDownload),

            const SizedBox(height: 24),
            const Text('أدوات الصيانة والفرز',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),

            // 🆕 زر فرز الأفلام
            _settingsTile(
                icon: Icons.movie_filter,
                color: const Color(0xFFF39C12),
                title: 'فرز الأفلام تلقائياً',
                subtitle:
                    'يفحص كل الأنمي ويصنف الأفلام المستقلة في تبويب "أفلام"',
                trailing: isClassifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_left,
                        color: Colors.white38),
                onTap: (isClassifying || isDownloading)
                    ? null
                    : _autoClassifyMovies),

            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.health_and_safety_outlined,
                color: Colors.tealAccent,
                title: 'فحص صحة البيانات',
                subtitle: 'يبحث عن صور/فيديوات مفقودة ويصلحها',
                trailing: isCheckingHealth
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_left,
                        color: Colors.white38),
                onTap: isCheckingHealth ? null : _checkHealth),
            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.compress,
                color: const Color(0xFF9C27B0),
                title: 'ضغط الفيديوهات التذكارية',
                subtitle: 'يقلل حجم الفيديوهات 50-70% لتوفير المساحة',
                trailing: isCompressing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_left,
                        color: Colors.white38),
                onTap: (isCompressing || isDownloading)
                    ? null
                    : _compressAllVideos),

            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.delete_sweep_outlined,
                color: const Color(0xFFFF5A65),
                title: 'مسح جميع التصنيفات',
                subtitle: 'حذف التصنيفات من جميع الأنميات',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: _clearAllGenres),
            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.delete_outline,
                color: const Color(0xFFFFB74D),
                title: 'سلة المهملات',
                subtitle: 'استعادة الأنميات المحذوفة',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TrashScreen()));
                }),

            const SizedBox(height: 24),
            const Text('النسخ الاحتياطي والتصدير',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _settingsTile(
                icon: Icons.backup_outlined,
                color: const Color(0xFF35B77A),
                title: 'إنشاء نسخة احتياطية شاملة',
                subtitle:
                    'كل شيء (بيانات + صور + شخصيات + مشاهد + فيديوهات)',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: backupBusy
                    ? null
                    : () => runBackupAction(restore: false)),
            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.settings_backup_restore,
                color: const Color(0xFFFFC857),
                title: 'استعادة النسخة الشاملة',
                subtitle: 'استرجاع كل شيء',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: backupBusy
                    ? null
                    : () => runBackupAction(restore: true)),
            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.backup_outlined,
                color: const Color(0xFF2196F3),
                title: 'نسخة خفيفة (بيانات + شخصيات + أغلفة)',
                subtitle: 'بدون فيديوهات/مشاهد/ذكريات — أسرع وأصغر',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: backupBusy
                    ? null
                    : () => _runLiteBackup(restore: false)),
            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.restore,
                color: const Color(0xFF03A9F4),
                title: 'استعادة النسخة الخفيفة',
                subtitle: 'استرجاع البيانات والأغلفة والشخصيات فقط',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: backupBusy
                    ? null
                    : () => _runLiteBackup(restore: true)),
            const SizedBox(height: 10),
            _settingsTile(
                icon: Icons.ios_share,
                color: const Color(0xFF00BCD4),
                title: 'تصدير المكتبة',
                subtitle: 'PDF احترافي أو CSV (Excel) أو Markdown',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: backupBusy ? null : _showExportDialog),

            if (backupBusy) ...[
              const SizedBox(height: 16),
              ValueListenableBuilder<BackupProgress?>(
                valueListenable: backupService.progress,
                builder: (context, progress, _) {
                  final pct = progress?.percentage ?? 0.0;
                  return Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1F28),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: primaryColor.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                            progress?.isRestore == true
                                ? Icons.restore
                                : Icons.backup,
                            color: Colors.cyan,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              progress?.isRestore == true
                                  ? 'جاري الاستعادة...'
                                  : 'جاري الإنشاء...',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ),
                          Text('${(pct * 100).toInt()}%',
                              style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 10),
                        Text(progress?.status ?? 'تجهيز...',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 10,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                primaryColor),
                          ),
                        ),
                        if (progress != null && progress.total > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                              '${progress.current} / ${progress.total}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white54)),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 24),
            const Text('حول التطبيق',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _settingsTile(
                icon: Icons.info_outline,
                color: const Color(0xFFFFC857),
                title: 'عن ذاكرة الأوتاكو',
                subtitle: 'معلومات عن التطبيق',
                trailing:
                    const Icon(Icons.chevron_left, color: Colors.white38),
                onTap: showAbout),
            const SizedBox(height: 28),
            const Center(
                child: Text('صُنع للأوتاكو، ليحفظ كل ذكرى.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.white38, fontSize: 12))),
          ],
        );
      },
    );
  }

  Widget _settingsTile(
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required Widget trailing,
      required VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFF1B1F28),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4), width: 1),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2)
          ]),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11))),
        trailing: trailing,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool darkMode = true;
  bool backupBusy = false;

  final BackupService backupService = BackupService();

  Future<void> runBackupAction({required bool restore}) async {
    if (backupBusy) return;

    if (restore) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          title: const Text('استعادة نسخة احتياطية'),
          content: const Text(
            'ستُستبدل قائمة الأنميات الحالية بالأنميات الموجودة '
            'في النسخة الاحتياطية. ستُضاف صور الذكريات المستعادة '
            'دون حذف صور المعرض الحالية.\n\n'
            'هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF741C2B),
                foregroundColor: Colors.white,
              ),
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
        title: Text(
          restore ? 'نتيجة الاستعادة' : 'نتيجة النسخ الاحتياطي',
        ),
        content: Text(result),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );
  }

  void showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'ذاكرة الأوتاكو',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.shield,
        color: Color(0xFF741C2B),
        size: 40,
      ),
      children: const [
        Text(
          'مساحتك الشخصية لتسجيل الأنميات التي شاهدتها، '
          'وتقييماتك وشخصياتك المفضلة وذكرياتك التي لا تُنسى.',
        ),
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
        content: const Text(
          'يحفظ التطبيق بياناتك محليًا على الهاتف. '
          'لكن عند حذف التطبيق قد تُحذف بياناته الداخلية أيضًا. '
          'استخدم النسخ الاحتياطي واحفظ ملف ZIP في مجلد التنزيلات '
          'أو مكان آمن خارج التطبيق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'الإعدادات',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'تحكّم في تطبيقك وبياناتك.',
          style: TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF741C2B),
                Color(0xFF2B202A),
                Color(0xFF202431),
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 46,
                color: Colors.white,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ذاكرة الأوتاكو',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'إصدار 1.0.0',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 25),

        const Text(
          'التخصيص',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),

        _settingsTile(
          icon: Icons.palette_outlined,
          color: const Color(0xFF8B65C6),
          title: 'المظهر',
          subtitle: 'الوضع الداكن والأسلوب القوي',
          trailing: Switch(
            value: darkMode,
            activeColor: const Color(0xFF741C2B),
            onChanged: (value) {
              setState(() => darkMode = value);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('المظهر ثابت في هذا الإصدار.'),
                ),
              );
            },
          ),
          onTap: null,
        ),

        const SizedBox(height: 24),

        const Text(
          'إدارة البيانات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),

        _settingsTile(
          icon: Icons.backup_outlined,
          color: const Color(0xFF35B77A),
          title: 'إنشاء نسخة احتياطية',
          subtitle: 'حفظ بياناتك في ملف ZIP داخل ملفات الهاتف',
          trailing: const Icon(
            Icons.chevron_left,
            color: Colors.white38,
          ),
          onTap: backupBusy
              ? null
              : () => runBackupAction(restore: false),
        ),

        const SizedBox(height: 10),

        _settingsTile(
          icon: Icons.settings_backup_restore,
          color: const Color(0xFFFFC857),
          title: 'استعادة نسخة احتياطية',
          subtitle: 'استرجاع بياناتك من ملف ZIP محفوظ',
          trailing: const Icon(
            Icons.chevron_left,
            color: Colors.white38,
          ),
          onTap: backupBusy
              ? null
              : () => runBackupAction(restore: true),
        ),

        if (backupBusy) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'جارٍ تجهيز البيانات...',
              style: TextStyle(color: Colors.white60),
            ),
          ),
        ],

        const SizedBox(height: 10),

        _settingsTile(
          icon: Icons.storage_outlined,
          color: const Color(0xFF247BA0),
          title: 'التخزين المحلي',
          subtitle: 'معلومات عن حفظ البيانات على الهاتف',
          trailing: const Icon(
            Icons.chevron_left,
            color: Colors.white38,
          ),
          onTap: showStorageInfo,
        ),

        const SizedBox(height: 24),

        const Text(
          'حول التطبيق',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),

        _settingsTile(
          icon: Icons.info_outline,
          color: const Color(0xFFFFC857),
          title: 'عن ذاكرة الأوتاكو',
          subtitle: 'معلومات عن التطبيق',
          trailing: const Icon(
            Icons.chevron_left,
            color: Colors.white38,
          ),
          onTap: showAbout,
        ),

        const SizedBox(height: 28),

        const Center(
          child: Text(
            'صُنع للأوتاكو، ليحفظ كل ذكرى.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 5,
        ),
        leading: Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}

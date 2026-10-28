
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool darkMode = true;

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
        Text(
          'مع تحياتي لكل أوتاكو يصنع ذكرياته الخاصة.',
        ),
      ],
    );
  }

  void showStorageInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('التخزين المحلي'),
        content: const Text(
          'يستخدم التطبيق ذاكرة الهاتف لحفظ الأنميات '
          'والتقييمات والذكريات. لا يحتاج حفظها إلى '
          'اتصال دائم بالإنترنت.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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

        // بطاقة التطبيق
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
                  content: Text(
                    'المظهر الحالي ثابت في هذا الإصدار.',
                  ),
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
          icon: Icons.storage_outlined,
          color: const Color(0xFF247BA0),
          title: 'التخزين المحلي',
          subtitle: 'تُحفظ بياناتك على هذا الجهاز',
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/anime.dart';
import '../services/statistics_service.dart';

class MonthlyWrappedScreen extends StatefulWidget {
  final List<Anime> animes;
  const MonthlyWrappedScreen({super.key, required this.animes});

  @override
  State<MonthlyWrappedScreen> createState() => _MonthlyWrappedScreenState();
}

class _MonthlyWrappedScreenState extends State<MonthlyWrappedScreen> {
  bool _loading = true;
  StatisticsData? _data;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    // هنا يمكننا حساب إحصائيات الشهر، لكن للتبسيط سنعرض الإحصائيات العامة
    final data = await StatisticsService().generateStatistics();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = primaryColorNotifier.value;

    if (_loading || _data == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF111318),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('ملخصك الشهري 🎉', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. البطاقة الأولى: إجمالي الحلقات
            _buildWrappedCard(
              title: 'هذا الشهر، أنت...',
              value: 'شاهدت ${_data!.totalEpisodesWatched} حلقة!',
              icon: Icons.play_circle_fill,
              gradientColors: [primaryColor, Colors.purpleAccent],
            ),
            const SizedBox(height: 16),

            // 2. البطاقة الثانية: أعلى تقييم
            _buildWrappedCard(
              title: 'أنمي الشهر بالنسبة لك',
              value: _data!.topRatedAnime,
              subtitle: 'بتقييم ${_data!.averageRating.toStringAsFixed(1)}/10',
              icon: Icons.star,
              gradientColors: [Colors.orange, Colors.redAccent],
            ),
            const SizedBox(height: 16),

            // 3. البطاقة الثالثة: التصنيف الأكثر
            _buildWrappedCard(
              title: 'روحك الأوتاكو كانت تعشق',
              value: 'تصنيف ${_data!.topGenre}',
              icon: Icons.category,
              gradientColors: [Colors.cyan, Colors.teal],
            ),
            const SizedBox(height: 16),

            // 4. البطاقة الرابعة: الساعات
            _buildWrappedCard(
              title: 'إجمالي وقتك في عالم الأنمي',
              value: '${_data!.totalHoursWatched.toStringAsFixed(1)} ساعة',
              subtitle: 'أي ما يعادل ${(_data!.totalHoursWatched / 24).toStringAsFixed(1)} يوم كامل!',
              icon: Icons.timer,
              gradientColors: [Colors.blue, Colors.indigo],
            ),
            const SizedBox(height: 30),

            Center(
              child: Text(
                'استمر في صنع الذكريات! ✨',
                style: GoogleFonts.cairo(fontSize: 18, color: Colors.white70),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildWrappedCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 26, color: Colors.white, fontWeight: FontWeight.w900),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 14, color: Colors.white60),
            ),
          ]
        ],
      ),
    );
  }
}
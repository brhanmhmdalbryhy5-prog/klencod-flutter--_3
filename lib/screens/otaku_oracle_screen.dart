import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../models/anime.dart';
import '../services/storage_service.dart';
import '../widgets/manga_character.dart';

class OtakuOracleScreen extends StatefulWidget {
  const OtakuOracleScreen({super.key});

  @override
  State<OtakuOracleScreen> createState() => _OtakuOracleScreenState();
}

class _OtakuOracleScreenState extends State<OtakuOracleScreen> {
  final StorageService storage = StorageService();
  final ScrollController _achievementsController = ScrollController();

  List<Anime> _allAnimes = [];
  List<Anime> animes = [];
  bool loading = true;

  static const Color background = Color(0xFF111318);
  static const Color panel = Color(0xFF1B1F28);

  static const String _lastMilestoneKey = 'last_milestone_count';
  static const String _milestonesSeenKey = 'milestones_seen';

  // ══════════════════════════════════════════════════════════════
  // 🆕 2000 لقب فريد — 20 بادئة × 20 صفة × 5 أنواع
  // كل لقب يفتح عند إضافة أنمي واحد | بلا شرك
  // ══════════════════════════════════════════════════════════════
  static const int _titlesPerLevel = 1;

  static const List<String> _prefixes = [
    'حارس', 'أمير', 'سيد', 'بطل', 'فارس',
    'روح', 'قلب', 'ظل', 'نور', 'نجم',
    'صقر', 'تنين', 'فينيق', 'ساموراي', 'محارب',
    'مستكشف', 'فيلسوف', 'مبتكر', 'صياد', 'عرّاف',
  ];

  static const List<String> _adjectives = [
    'لامع', 'ذهبي', 'فضي', 'سريع', 'شجاع',
    'نادر', 'وقور', 'رفيع', 'زاهر', 'باهر',
    'بهيج', 'متوهج', 'مذهل', 'رائع', 'راسخ',
    'مشع', 'مضئ', 'سعيد', 'فاتن', 'جذاب',
  ];

  static const List<String> _cores = [
    'الأنمي', 'المانغا', 'الأوتاكو', 'القصص', 'الأساطير',
  ];

  static const int _totalTitles =
      20 * 20 * 5; // = 2000

  static String _generateTitle(int index) {
    if (index < 0) index = 0;
    final i = index % _totalTitles;
    final prefixIdx = i % 20;
    final adjectiveIdx = (i ~/ 20) % 20;
    final coreIdx = i ~/ 400;
    return '${_prefixes[prefixIdx]} ${_adjectives[adjectiveIdx]} ${_cores[coreIdx]}';
  }

  @override
  void initState() {
    super.initState();
    loadData().then((_) => _scrollToLatestAchievement());
  }

  void _scrollToLatestAchievement() {
    int unlockedIndex = (animes.length / _titlesPerLevel).floor() - 1;
    if (unlockedIndex > _totalTitles - 1) unlockedIndex = _totalTitles - 1;
    if (unlockedIndex < 0) unlockedIndex = 0;

    double offset = (unlockedIndex * 90.0) - 150.0;
    if (offset < 0) offset = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_achievementsController.hasClients) {
        double maxScroll = _achievementsController.position.maxScrollExtent;
        _achievementsController.animateTo(
          offset > maxScroll ? maxScroll : offset,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> loadData() async {
    final saved = await storage.loadAnimes();
    if (!mounted) return;

    final newCount = saved.where((a) => a.parentId == null).length;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCount = prefs.getInt(_lastMilestoneKey) ?? 0;
      final seenBefore = prefs.getBool(_milestonesSeenKey) ?? false;

      if (seenBefore && newCount > lastCount && newCount > 0) {
        final lastTitle = _generateTitle(newCount - 1);
        FloatingMangaCharacter.sayCustom(
          '🏆 لقب جديد!\n$lastTitle',
          MangaExpression.veryHappy,
        );
      }

      await prefs.setBool(_milestonesSeenKey, true);
      await prefs.setInt(_lastMilestoneKey, newCount);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _allAnimes = saved;
      animes = saved.where((a) => a.parentId == null).toList();
      loading = false;
    });
  }

  List<Anime> get ratedAnimes =>
      animes.where((anime) => anime.rating > 0).toList();

  double get averageRating {
    if (ratedAnimes.isEmpty) return 0;
    return ratedAnimes.fold<double>(0, (sum, anime) => sum + anime.rating) /
        ratedAnimes.length;
  }

  int get totalEpisodesWatched {
    return _allAnimes.fold<int>(0, (sum, a) {
      if (a.status == 'مكتمل') {
        return sum + (a.episodes > 0 ? a.episodes : a.watchedEpisodes);
      }
      return sum + a.watchedEpisodes;
    });
  }

  double get completionRate {
    if (animes.isEmpty) return 0;
    final completed = animes.where((a) => a.status == 'مكتمل').length;
    return (completed / animes.length) * 100;
  }

  Map<String, double> get genreScores {
    final scores = <String, double>{};
    for (final anime in ratedAnimes) {
      final genres = anime.genre.trim().isNotEmpty
          ? anime.genre
              .split(RegExp(r'[,،/|]'))
              .map((g) => g.trim())
              .where((g) => g.isNotEmpty)
              .toList()
          : <String>[];
      for (final genre in genres) {
        scores[genre] = (scores[genre] ?? 0.0) + anime.rating;
      }
    }
    return scores;
  }

  Widget _buildAchievements() {
    int totalCount = animes.length;

    final List<Color> colors = [
      const Color(0xFFCD7F32), const Color(0xFFC0C0C0),
      const Color(0xFFFFD700), const Color(0xFF00E5FF),
      const Color(0xFFE040FB), const Color(0xFFFF5252),
      const Color(0xFF69F0AE), const Color(0xFFFFAB40),
      const Color(0xFF448AFF), const Color(0xFFFF4081),
    ];

    final List<IconData> icons = [
      Icons.star_border, Icons.explore, Icons.local_cafe,
      Icons.psychology, Icons.auto_awesome, Icons.verified,
      Icons.workspace_premium, Icons.military_tech,
      Icons.diamond, Icons.emoji_events,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: const Color(0xFFFFC857).withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.emoji_events, color: Color(0xFFFFC857)),
            SizedBox(width: 8),
            Text('الإنجازات والألقاب',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          Text(
              'لقد أضفت $totalCount أنمي. كل أنمي يفتح لقباً جديداً!',
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: ListView.builder(
              controller: _achievementsController,
              scrollDirection: Axis.horizontal,
              itemCount: _totalTitles,
              itemBuilder: (context, index) {
                final count = (index + 1) * _titlesPerLevel;
                final title = _generateTitle(index);
                final icon = icons[index % icons.length];
                final color = colors[index % colors.length];
                final isUnlocked = totalCount >= count;

                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(left: 10),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isUnlocked
                              ? color.withOpacity(0.2)
                              : Colors.white10,
                          border: Border.all(
                              color: isUnlocked ? color : Colors.white24,
                              width: 2),
                          boxShadow: isUnlocked
                              ? [
                                  BoxShadow(
                                      color: color.withOpacity(0.5),
                                      blurRadius: 15,
                                      spreadRadius: 2),
                                ]
                              : [],
                        ),
                        child: Icon(isUnlocked ? icon : Icons.lock,
                            color: isUnlocked ? color : Colors.white38,
                            size: 30),
                      ),
                      const SizedBox(height: 8),
                      Text(title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color:
                                  isUnlocked ? Colors.white : Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                      Text('$count',
                          style: TextStyle(
                              color: isUnlocked ? color : Colors.white38,
                              fontSize: 10)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = primaryColorNotifier.value;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          title: const Text('مرآة الأوتاكو',
              style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildIntroduction(),
                const SizedBox(height: 22),
                const Text('ملامح ذوقك في الأنمي',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildStatistics(),
                const SizedBox(height: 22),
                _buildGenreChart(),
                const SizedBox(height: 22),
                _buildAchievements(),
                const SizedBox(height: 22),
              ],
            ),
    );
  }

  Widget _buildIntroduction() {
    final primaryColor = primaryColorNotifier.value;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withOpacity(0.4)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          border: Border.all(
              color: primaryColor.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: primaryColor.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 3),
          ]),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.psychology_alt, color: Colors.white, size: 42),
          SizedBox(height: 12),
          Text('ماذا تكشف اختياراتك عنك؟',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('تحليل ذوقك من خلال تقييماتك ومفضلاتك.',
              style: TextStyle(color: Colors.white70, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        _statCard('إجمالي الأنميات', '${animes.length}', Icons.movie,
            const Color(0xFF247BA0)),
        _statCard('الحلقات (شاملة المواسم)', '$totalEpisodesWatched',
            Icons.play_circle_fill, const Color(0xFF8B65C6)),
        _statCard('نسبة الإكمال',
            '${completionRate.toStringAsFixed(0)}%',
            Icons.donut_large, const Color(0xFF00ACC1)),
        _statCard(
            'متوسط تقييمك',
            ratedAnimes.isEmpty
                ? '—'
                : averageRating.toStringAsFixed(1),
            Icons.insights,
            const Color(0xFF27866F)),
      ],
    );
  }

  Widget _statCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 15,
                spreadRadius: 2),
          ]),
      child: Row(children: [
        Icon(icon, color: color, size: 27),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 11)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildGenreChart() {
    final scores = genreScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (scores.isEmpty) return Container();

    final topScores = scores.take(5).toList();
    final total = topScores.fold<double>(0, (sum, e) => sum + e.value);
    final List<Color> chartColors = [
      primaryColorNotifier.value,
      const Color(0xFF247BA0),
      const Color(0xFFB87928),
      const Color(0xFF27866F),
      const Color(0xFFB34E68),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.pie_chart, color: Color(0xFFB87928)),
            SizedBox(width: 8),
            Text('الأنواع الأقرب إلى ذوقك',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: List.generate(topScores.length, (index) {
                  final entry = topScores[index];
                  final percentage = (entry.value / total) * 100;
                  return PieChartSectionData(
                    color: chartColors[index % chartColors.length],
                    value: entry.value,
                    title: '${percentage.toStringAsFixed(0)}%',
                    radius: 55,
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: List.generate(topScores.length, (index) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    color: chartColors[index % chartColors.length],
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 6),
                  Text(topScores[index].key,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
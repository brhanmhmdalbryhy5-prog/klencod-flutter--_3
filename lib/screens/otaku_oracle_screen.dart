import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/anime.dart';
import '../services/storage_service.dart';

class OtakuOracleScreen extends StatefulWidget {
  const OtakuOracleScreen({super.key});

  @override
  State<OtakuOracleScreen> createState() => _OtakuOracleScreenState();
}

class _OtakuOracleScreenState extends State<OtakuOracleScreen> {
  final StorageService storage = StorageService();
  final TextEditingController searchController = TextEditingController();

  List<Anime> animes = [];
  List<Map<String, dynamic>> catalog = [];

  bool loading = true;
  String catalogMessage = '';

  static const Color background = Color(0xFF111318);
  static const Color panel = Color(0xFF1B1F28);

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final results = await Future.wait([storage.loadAnimes(), rootBundle.loadString('lib/anime_catalog.json')]);
      final saved = results[0] as List<Anime>;
      final decoded = jsonDecode(results[1] as String);
      if (decoded is! List) throw const FormatException('يجب أن تكون قاعدة البيانات قائمة JSON.');
      final entries = decoded.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      if (!mounted) return;
      setState(() { animes = saved; catalog = entries; catalogMessage = ''; loading = false; });
    } catch (e) {
      final saved = await storage.loadAnimes();
      if (!mounted) return;
      setState(() { animes = saved; catalog = []; catalogMessage = 'تعذرت قراءة قاعدة الأنمي.'; loading = false; });
    }
  }

  List<Anime> get ratedAnimes => animes.where((anime) => anime.rating > 0).toList();

  double get averageRating {
    if (ratedAnimes.isEmpty) return 0;
    return ratedAnimes.fold<double>(0, (sum, anime) => sum + anime.rating) / ratedAnimes.length;
  }

  List<Anime> get favorites => animes.where((anime) => anime.favorite).toList();
  List<Anime> get highRated => ratedAnimes.where((anime) => anime.rating >= 8.0).toList();

  int get totalEpisodesWatched => animes.where((a) => a.status == 'مكتمل').fold<int>(0, (sum, a) => sum + a.episodes);

  double get completionRate {
    if (animes.isEmpty) return 0;
    final completed = animes.where((a) => a.status == 'مكتمل').length;
    return (completed / animes.length) * 100;
  }

  String normalize(String value) {
    return value.toLowerCase().replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا').replaceAll('ى', 'ي').replaceAll('ة', 'ه').replaceAll(RegExp(r'[\s\-_!.,:;؟?]+'), '');
  }

  String catalogTitle(Map<String, dynamic> item) => (item['title'] ?? '').toString();
  List<String> catalogAliases(Map<String, dynamic> item) { final value = item['aliases']; if (value is! List) return []; return value.map((e) => e.toString()).toList(); }
  List<String> catalogGenres(Map<String, dynamic> item) { final value = item['genres']; if (value is! List) return []; return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(); }

  Map<String, dynamic>? findCatalogAnime(String query) {
    final q = normalize(query);
    if (q.isEmpty) return null;
    for (final item in catalog) { final names = [catalogTitle(item), ...catalogAliases(item)]; for (final name in names) { if (normalize(name) == q) return item; } }
    return null;
  }

  Map<String, double> get genreScores {
    final scores = <String, double>{};
    for (final anime in ratedAnimes) {
      final item = findCatalogAnime(anime.title);
      final genres = anime.genre.trim().isNotEmpty ? anime.genre.split(RegExp(r'[,،/|]')).map((g) => g.trim()).where((g) => g.isNotEmpty).toList() : item == null ? <String>[] : catalogGenres(item);
      for (final genre in genres) { scores[genre] = (scores[genre] ?? 0.0) + anime.rating; }
    }
    return scores;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // 🔥 قسم الإنجازات الجديد (يعتمد على عدد الأنميات المضافة)
  Widget _buildAchievements() {
    int totalCount = animes.length;
    // توليد الإنجازات من 10 إلى 1000 كل 10
    final List<int> milestones = List.generate(100, (index) => (index + 1) * 10);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFFFC857).withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events, color: Color(0xFFFFC857)),
              SizedBox(width: 8),
              Text('الإنجازات', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text('لقد أضفت $totalCount أنمي حتى الآن. استمر في جمع الأنميات لفتح المزيد!', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: milestones.length,
              itemBuilder: (context, index) {
                final milestone = milestones[index];
                final isUnlocked = totalCount >= milestone;
                
                return Container(
                  width: 70,
                  margin: const EdgeInsets.only(left: 10),
                  child: Column(
                    children: [
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isUnlocked ? const Color(0xFFFFC857).withOpacity(0.2) : Colors.white10,
                          border: Border.all(color: isUnlocked ? const Color(0xFFFFC857) : Colors.white24, width: 2),
                          boxShadow: isUnlocked ? [BoxShadow(color: const Color(0xFFFFC857).withOpacity(0.4), blurRadius: 10)] : [],
                        ),
                        child: Icon(
                          isUnlocked ? Icons.emoji_events : Icons.lock,
                          color: isUnlocked ? const Color(0xFFFFC857) : Colors.white38,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$milestone',
                        style: TextStyle(color: isUnlocked ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
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
    final query = searchController.text.trim();
    final libraryResults = animes.where((a) => normalize(a.title).contains(normalize(query))).toList();
    final databaseResults = catalog.where((i) => normalize(catalogTitle(i)).contains(normalize(query))).take(15).toList();

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(backgroundColor: primaryColor, foregroundColor: Colors.white, title: const Text('مرآة الأوتاكو', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildIntroduction(),
          const SizedBox(height: 16),
          if (catalogMessage.isNotEmpty) _messageCard(catalogMessage),
          _buildSearch(),
          if (query.isNotEmpty) ...[const SizedBox(height: 12), _buildSearchResults(libraryResults, databaseResults)],
          const SizedBox(height: 22),
          const Text('ملامح ذوقك في الأنمي', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildStatistics(),
          const SizedBox(height: 22),
          _buildGenreChart(),
          const SizedBox(height: 22),
          _buildAchievements(), // 🔥 استدعاء قسم الإنجازات هنا
          const SizedBox(height: 22),
          _buildAnimeSection(title: 'أنمياتك المفضلة', icon: Icons.favorite, items: favorites, emptyMessage: 'لم تضف أنميات إلى المفضلة بعد.'),
          const SizedBox(height: 22),
          _buildAnimeSection(title: 'الأنميات الأعلى تقييمًا (8+)', icon: Icons.star, items: highRated, emptyMessage: 'قيّم أنمياتك بـ 8 أو أكثر لعرضها هنا.'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildIntroduction() {
    final primaryColor = primaryColorNotifier.value;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.4)], begin: Alignment.topRight, end: Alignment.bottomLeft), border: Border.all(color: primaryColor.withOpacity(0.5), width: 1.5), boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 20, spreadRadius: 3)]),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.psychology_alt, color: Colors.white, size: 42), SizedBox(height: 12), Text('ماذا تكشف اختياراتك عنك؟', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('تحليل ذوقك من خلال تقييماتك ومفضلاتك.', style: TextStyle(color: Colors.white70, height: 1.6))]),
    );
  }

  Widget _buildSearch() {
    final primaryColor = primaryColorNotifier.value;
    return TextField(
      controller: searchController,
      style: const TextStyle(color: Colors.white),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(hintText: 'ابحث باسم الأنمي...', hintStyle: const TextStyle(color: Colors.white54, fontSize: 13), prefixIcon: const Icon(Icons.search, color: Colors.white70), filled: true, fillColor: panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryColor, width: 2))),
    );
  }

  Widget _buildSearchResults(List<Anime> libraryResults, List<Map<String, dynamic>> databaseResults) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('نتائج مكتبتك', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          if (libraryResults.isEmpty) const Text('لا توجد نتائج.', style: TextStyle(color: Colors.white54))
          else ...libraryResults.take(5).map((a) => ListTile(contentPadding: EdgeInsets.zero, title: Text(a.title, style: TextStyle(color: Colors.white, fontFamily: GoogleFonts.cairo().fontFamily, fontWeight: FontWeight.bold)), subtitle: Text(a.genre, style: const TextStyle(color: Colors.white60)), trailing: Text(a.rating > 0 ? '${a.rating}★' : '—', style: const TextStyle(color: Colors.amber)))),
          const Divider(color: Colors.white12),
          const Text('نتائج قاعدة البيانات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          if (databaseResults.isEmpty) const Text('لا توجد نتائج.', style: TextStyle(color: Colors.white54))
          else ...databaseResults.map((i) => ListTile(contentPadding: EdgeInsets.zero, title: Text(catalogTitle(i), style: TextStyle(color: Colors.white, fontFamily: GoogleFonts.cairo().fontFamily, fontWeight: FontWeight.bold)), subtitle: Text(catalogGenres(i).join('، '), style: const TextStyle(color: Colors.white60)), trailing: IconButton(icon: const Icon(Icons.search, color: Colors.white70), onPressed: () { searchController.text = catalogTitle(i); setState(() {}); }))),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.5,
      children: [
        _statCard('إجمالي الأنميات', '${animes.length}', Icons.movie, const Color(0xFF247BA0)),
        _statCard('الأنميات المفضلة', '${favorites.length}', Icons.favorite, const Color(0xFFB34E68)),
        _statCard('تقييمات مرتفعة (8+)', '${highRated.length}', Icons.star, const Color(0xFFB87928)),
        _statCard('متوسط تقييمك', ratedAnimes.isEmpty ? '—' : averageRating.toStringAsFixed(1), Icons.insights, const Color(0xFF27866F)),
        _statCard('الحلقات المشاهدة', '$totalEpisodesWatched', Icons.play_circle_fill, const Color(0xFF8B65C6)),
        _statCard('نسبة الإكمال', '${completionRate.toStringAsFixed(0)}%', Icons.donut_large, const Color(0xFF00ACC1)),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(0.5), width: 1.5), boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 15, spreadRadius: 2)]),
      child: Row(children: [Icon(icon, color: color, size: 27), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11))]))]),
    );
  }

  Widget _buildGenreChart() {
    final scores = genreScores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (scores.isEmpty) return _messageCard('لا توجد بيانات كافية لرسم بياني.', title: 'الأنواع الأقرب لذوقك', icon: Icons.pie_chart);

    final topScores = scores.take(5).toList();
    final total = topScores.fold<double>(0, (sum, e) => sum + e.value);
    
    final List<Color> chartColors = [primaryColorNotifier.value, const Color(0xFF247BA0), const Color(0xFFB87928), const Color(0xFF27866F), const Color(0xFFB34E68)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.pie_chart, color: Color(0xFFB87928)), SizedBox(width: 8), Text('الأنواع الأقرب إلى ذوقك', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3, centerSpaceRadius: 40,
                sections: List.generate(topScores.length, (index) {
                  final entry = topScores[index];
                  final percentage = (entry.value / total) * 100;
                  return PieChartSectionData(color: chartColors[index % chartColors.length], value: entry.value, title: '${percentage.toStringAsFixed(1)}%', radius: 60, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white));
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12, runSpacing: 8,
            children: List.generate(topScores.length, (index) {
              return Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 12, height: 12, color: chartColors[index % chartColors.length]), const SizedBox(width: 4), Text(topScores[index].key, style: const TextStyle(color: Colors.white70, fontSize: 12))]);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimeSection({required String title, required IconData icon, required List<Anime> items, required String emptyMessage}) {
    final primaryColor = primaryColorNotifier.value;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: const Color(0xFFB87928)), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)))]),
          const SizedBox(height: 12),
          if (items.isEmpty) Text(emptyMessage, style: const TextStyle(color: Colors.white54, height: 1.6))
          else ...items.take(5).map((anime) => ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: primaryColor, child: Text(anime.rating > 0 ? '${anime.rating.toStringAsFixed(1)}' : '★', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), title: Text(anime.title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: titleColorNotifier.value)), subtitle: Text(anime.genre.isNotEmpty ? anime.genre : 'لم يُحدّد النوع', style: const TextStyle(color: Colors.white54)))),
        ],
      ),
    );
  }

  Widget _messageCard(String message, {String? title, IconData icon = Icons.info_outline, Widget? extra}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[Row(children: [Icon(icon, color: const Color(0xFFB87928)), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]), const SizedBox(height: 12)],
          Text(message, style: const TextStyle(color: Colors.white70, height: 1.8)),
          if (extra != null) extra,
        ],
      ),
    );
  }
}
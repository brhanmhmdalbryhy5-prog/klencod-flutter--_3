
import 'package:flutter/material.dart';

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
  bool loading = true;

  static const Color darkRed = Color(0xFF741C2B);
  static const Color background = Color(0xFF101114);
  static const Color panel = Color(0xFF1B1D22);

  @override
  void initState() {
    super.initState();
    loadAnimes();
  }

  Future<void> loadAnimes() async {
    final result = await storage.loadAnimes();

    if (!mounted) return;

    setState(() {
      animes = result;
      loading = false;
    });
  }

  List<Anime> get ratedAnimes =>
      animes.where((anime) => anime.rating > 0).toList();

  double get averageRating {
    if (ratedAnimes.isEmpty) return 0;

    final total =
        ratedAnimes.fold<int>(0, (sum, anime) => sum + anime.rating);

    return total / ratedAnimes.length;
  }

  List<Anime> get favorites =>
      animes.where((anime) => anime.favorite).toList();

  List<Anime> get highRated =>
      ratedAnimes.where((anime) => anime.rating >= 4).toList();

  List<Anime> searchResults(String query) {
    final value = query.trim().toLowerCase();

    if (value.isEmpty) return [];

    return animes.where((anime) {
      return anime.title.toLowerCase().contains(value) ||
          anime.genre.toLowerCase().contains(value) ||
          anime.character.toLowerCase().contains(value);
    }).toList();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = searchResults(searchController.text);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: darkRed,
        foregroundColor: Colors.white,
        title: const Text(
          'مرآة الأوتاكو',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadAnimes,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildIntroduction(),
                  const SizedBox(height: 20),
                  _buildSearch(),
                  if (searchController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildSearchResults(results),
                  ],
                  const SizedBox(height: 22),
                  const Text(
                    'ملامح ذوقك في الأنمي',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatistics(),
                  const SizedBox(height: 22),
                  _buildTasteAnalysis(),
                  const SizedBox(height: 22),
                  _buildFavoritesSection(),
                  const SizedBox(height: 22),
                  _buildHighlyRatedSection(),
                  const SizedBox(height: 24),
                  const Text(
                    'كلما أضفت أنميات وقيّمتها، أصبحت قراءتنا لذوقك أدق.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, height: 1.6),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildIntroduction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF741C2B), Color(0xFF38203E)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.psychology_alt, color: Colors.white, size: 42),
          SizedBox(height: 12),
          Text(
            'ماذا تكشف اختياراتك عنك؟',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'حلّل تقييماتك وأنمياتك المفضلة واكتشف الأنواع التي تميل إليها.',
            style: TextStyle(color: Colors.white70, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: searchController,
      style: const TextStyle(color: Colors.white),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'ابحث في أنميات مكتبتك...',
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.search, color: Colors.white70),
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
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
      childAspectRatio: 1.7,
      children: [
        _statCard('إجمالي الأنميات', '${animes.length}', Icons.movie,
            const Color(0xFF247BA0)),
        _statCard('الأنميات المفضلة', '${favorites.length}', Icons.favorite,
            const Color(0xFFB34E68)),
        _statCard('أنميات بتقييم مرتفع', '${highRated.length}',
            Icons.star, const Color(0xFFB87928)),
        _statCard(
          'متوسط تقييمك',
          ratedAnimes.isEmpty ? '—' : averageRating.toStringAsFixed(1),
          Icons.insights,
          const Color(0xFF27866F),
        ),
      ],
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 27),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasteAnalysis() {
    String message;

    if (animes.isEmpty) {
      message =
          'لم تبدأ المرآة بتحليل ذوقك بعد. أضف أول أنمي إلى مكتبتك ثم قيّمه لتبدأ رحلتك.';
    } else if (ratedAnimes.isEmpty) {
      message =
          'لديك ${animes.length} أنمي في مكتبتك، لكنك لم تقيّم أيًّا منها بعد. أضف تقييماتك حتى نتمكن من تحليل اختياراتك.';
    } else {
      message =
          'قيّمت ${ratedAnimes.length} أنمي، ومتوسط تقييمك ${averageRating.toStringAsFixed(1)} من 5. '
          '${highRated.isNotEmpty ? 'منحت ${highRated.length} أنمي تقييمًا مرتفعًا.' : 'جرّب تقييم الأنميات التي أحببتها.'}';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFFB87928)),
              SizedBox(width: 8),
              Text(
                'قراءة المرآة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, height: 1.8),
          ),
          if (ratedAnimes.isNotEmpty) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: averageRating / 5,
                minHeight: 9,
                backgroundColor: Colors.white12,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFB87928)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'مستوى تقييمك العام: ${((averageRating / 5) * 100).round()}%',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFavoritesSection() {
    return _buildAnimeSection(
      title: 'أنمياتك المفضلة',
      icon: Icons.favorite,
      items: favorites,
      emptyMessage: 'لم تضف أنميات إلى المفضلة بعد.',
    );
  }

  Widget _buildHighlyRatedSection() {
    return _buildAnimeSection(
      title: 'الأنميات الأعلى تقييمًا',
      icon: Icons.star,
      items: highRated,
      emptyMessage: 'قيّم أنمياتك لتحصل على قائمة الأعلى تقييمًا.',
    );
  }

  Widget _buildAnimeSection({
    required String title,
    required IconData icon,
    required List<Anime> items,
    required String emptyMessage,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFB87928)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              emptyMessage,
              style: const TextStyle(color: Colors.white54, height: 1.6),
            )
          else
            ...items.take(5).map(
                  (anime) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF741C2B),
                      child: Text(
                        anime.rating > 0 ? '${anime.rating}★' : '★',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      anime.title,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      anime.genre.isEmpty ? 'لم يُحدّد النوع' : anime.genre,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<Anime> results) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: results.isEmpty
          ? const Text(
              'لا توجد نتائج مطابقة في مكتبتك.',
              style: TextStyle(color: Colors.white60),
            )
          : Column(
              children: results.take(10).map((anime) {
                return ListTile(
                  title: Text(
                    anime.title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    anime.genre.isEmpty ? 'لم يُحدّد النوع' : anime.genre,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: const Icon(
                    Icons.movie_outlined,
                    color: Colors.white60,
                  ),
                );
              }).toList(),
            ),
    );
  }
}

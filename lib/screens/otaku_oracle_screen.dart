
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  static const Color darkRed = Color(0xFF741C2B);
  static const Color background = Color(0xFF101114);
  static const Color panel = Color(0xFF1B1D22);

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final results = await Future.wait([
        storage.loadAnimes(),
        rootBundle.loadString('lib/anime_catalog.json'),
      ]);

      final saved = results[0] as List<Anime>;
      final decoded = jsonDecode(results[1] as String);

      if (decoded is! List) {
        throw const FormatException('يجب أن تكون قاعدة البيانات قائمة JSON.');
      }

      final entries = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;

      setState(() {
        animes = saved;
        catalog = entries;
        catalogMessage = '';
        loading = false;
      });
    } catch (e) {
      final saved = await storage.loadAnimes();

      if (!mounted) return;

      setState(() {
        animes = saved;
        catalog = [];
        catalogMessage =
            'تعذرت قراءة قاعدة الأنمي. تحقق من pubspec.yaml '
            'ومحتوى anime_catalog.json، ثم أعد تشغيل التطبيق.';
        loading = false;
      });
    }
  }

  List<Anime> get ratedAnimes =>
      animes.where((anime) => anime.rating > 0).toList();

  double get averageRating {
    if (ratedAnimes.isEmpty) return 0;

    return ratedAnimes.fold<int>(
          0,
          (sum, anime) => sum + anime.rating,
        ) /
        ratedAnimes.length;
  }

  List<Anime> get favorites =>
      animes.where((anime) => anime.favorite).toList();

  List<Anime> get highRated =>
      ratedAnimes.where((anime) => anime.rating >= 4).toList();

  String normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[\s\-_!.,:;؟?]+'), '');
  }

  String catalogTitle(Map<String, dynamic> item) {
    return (item['title'] ?? '').toString();
  }

  List<String> catalogAliases(Map<String, dynamic> item) {
    final value = item['aliases'];
    if (value is! List) return [];

    return value.map((e) => e.toString()).toList();
  }

  List<String> catalogGenres(Map<String, dynamic> item) {
    final value = item['genres'];
    if (value is! List) return [];

    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Map<String, dynamic>? findCatalogAnime(String query) {
    final q = normalize(query);
    if (q.isEmpty) return null;

    for (final item in catalog) {
      final names = [
        catalogTitle(item),
        ...catalogAliases(item),
      ];

      for (final name in names) {
        final normalizedName = normalize(name);
        if (normalizedName.isNotEmpty && normalizedName == q) {
          return item;
        }
      }
    }

    for (final item in catalog) {
      final names = [
        catalogTitle(item),
        ...catalogAliases(item),
      ];

      for (final name in names) {
        final normalizedName = normalize(name);

        if (normalizedName.length >= 4 &&
            q.length >= 4 &&
            (normalizedName.contains(q) || q.contains(normalizedName))) {
          return item;
        }
      }
    }

    return null;
  }

  List<Map<String, dynamic>> searchCatalog(String query) {
    final q = normalize(query);
    if (q.isEmpty) return [];

    return catalog.where((item) {
      final names = [
        catalogTitle(item),
        ...catalogAliases(item),
      ];

      return names.any((name) => normalize(name).contains(q));
    }).take(15).toList();
  }

  List<Anime> searchLibrary(String query) {
    final q = normalize(query);
    if (q.isEmpty) return [];

    return animes.where((anime) {
      return normalize(anime.title).contains(q) ||
          normalize(anime.genre).contains(q) ||
          normalize(anime.character).contains(q);
    }).toList();
  }

  Map<String, int> get genreScores {
    final scores = <String, int>{};

    for (final anime in ratedAnimes) {
      final item = findCatalogAnime(anime.title);
      final genres = anime.genre.trim().isNotEmpty
          ? anime.genre
              .split(RegExp(r'[,،/|]'))
              .map((g) => g.trim())
              .where((g) => g.isNotEmpty)
              .toList()
          : item == null
              ? <String>[]
              : catalogGenres(item);

      for (final genre in genres) {
        scores[genre] = (scores[genre] ?? 0) + anime.rating;
      }
    }

    return scores;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim();
    final libraryResults = searchLibrary(query);
    final databaseResults = searchCatalog(query);

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
              onRefresh: loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildIntroduction(),
                  const SizedBox(height: 16),
                  if (catalogMessage.isNotEmpty)
                    _messageCard(catalogMessage),
                  _buildSearch(),
                  if (query.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildSearchResults(
                      libraryResults,
                      databaseResults,
                    ),
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
                  _buildGenreAnalysis(),
                  const SizedBox(height: 22),
                  _buildAnimeSection(
                    title: 'أنمياتك المفضلة',
                    icon: Icons.favorite,
                    items: favorites,
                    emptyMessage: 'لم تضف أنميات إلى المفضلة بعد.',
                  ),
                  const SizedBox(height: 22),
                  _buildAnimeSection(
                    title: 'الأنميات الأعلى تقييمًا',
                    icon: Icons.star,
                    items: highRated,
                    emptyMessage: 'قيّم أنمياتك لعرض الأعلى تقييمًا.',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'قاعدة الأنمي المحلية: ${catalog.length} عنوانًا',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'تعمل المرآة محليًا، وتزداد دقة تحليلها كلما أضفت '
                    'أنميات وقيّمتها.',
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
            'ابحث في قاعدة الأنمي، واكتشف تصنيفاته، وحلّل ذوقك '
            'من خلال تقييماتك ومفضلاتك.',
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
        hintText: 'ابحث باسم الأنمي بالعربية أو الإنجليزية...',
        hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
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

  Widget _buildSearchResults(
    List<Anime> libraryResults,
    List<Map<String, dynamic>> databaseResults,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نتائج مكتبتك',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (libraryResults.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'لا توجد نتائج في مكتبتك.',
                style: TextStyle(color: Colors.white54),
              ),
            )
          else
            ...libraryResults.take(5).map((anime) {
              final entry = findCatalogAnime(anime.title);
              final genres = anime.genre.trim().isNotEmpty
                  ? anime.genre
                  : entry == null
                      ? 'لم يُعرف التصنيف في القاعدة'
                      : catalogGenres(entry).join('، ');

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  anime.title,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  genres.isEmpty ? 'لم يُحدّد النوع' : genres,
                  style: const TextStyle(color: Colors.white60),
                ),
                trailing: Text(
                  anime.rating > 0 ? '${anime.rating}★' : '—',
                  style: const TextStyle(color: Colors.amber),
                ),
              );
            }),
          const Divider(color: Colors.white12),
          const Text(
            'نتائج قاعدة البيانات',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (databaseResults.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'لا توجد نتائج في قاعدة البيانات الحالية.',
                style: TextStyle(color: Colors.white54),
              ),
            )
          else
            ...databaseResults.map((item) {
              final title = catalogTitle(item);
              final genres = catalogGenres(item);

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  title,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  genres.isEmpty
                      ? 'لا توجد تصنيفات مسجلة'
                      : genres.join('، '),
                  style: const TextStyle(color: Colors.white60),
                ),
                trailing: IconButton(
                  tooltip: 'البحث في المكتبة بهذا الاسم',
                  icon: const Icon(
                    Icons.search,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    searchController.text = title;
                    setState(() {});
                  },
                ),
              );
            }),
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
      childAspectRatio: 1.7,
      children: [
        _statCard(
          'إجمالي الأنميات',
          '${animes.length}',
          Icons.movie,
          const Color(0xFF247BA0),
        ),
        _statCard(
          'الأنميات المفضلة',
          '${favorites.length}',
          Icons.favorite,
          const Color(0xFFB34E68),
        ),
        _statCard(
          'تقييمات مرتفعة',
          '${highRated.length}',
          Icons.star,
          const Color(0xFFB87928),
        ),
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
          'أضف أنميات إلى مكتبتك وقيّمها حتى تبدأ المرآة بتحليل ذوقك.';
    } else if (ratedAnimes.isEmpty) {
      message =
          'لديك ${animes.length} أنمي، لكنك لم تقيّم أيًّا منها بعد.';
    } else {
      message =
          'قيّمت ${ratedAnimes.length} أنمي بمتوسط '
          '${averageRating.toStringAsFixed(1)} من 5. '
          'لديك ${highRated.length} أنمي بتقييم 4 أو 5.';
    }

    return _messageCard(
      message,
      title: 'قراءة المرآة',
      icon: Icons.auto_awesome,
      extra: ratedAnimes.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: averageRating / 5,
                    minHeight: 9,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFB87928),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'مستوى تقييمك: '
                  '${((averageRating / 5) * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGenreAnalysis() {
    final scores = genreScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.category, color: Color(0xFFB87928)),
              SizedBox(width: 8),
              Text(
                'الأنواع الأقرب إلى ذوقك',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (scores.isEmpty)
            const Text(
              'لا توجد بيانات كافية بعد. أضف تقييمات لأنميات موجودة '
              'في القاعدة أو اكتب تصنيفاتها في مكتبتك.',
              style: TextStyle(color: Colors.white60, height: 1.6),
            )
          else
            ...scores.take(5).map((entry) {
              final maximum = scores.first.value;
              final progress = maximum == 0 ? 0.0 : entry.value / maximum;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        Text(
                          '${entry.value}',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF741C2B),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
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
                      backgroundColor: darkRed,
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
                      anime.genre.isNotEmpty
                          ? anime.genre
                          : (catalogGenres(
                              findCatalogAnime(anime.title) ??
                                  <String, dynamic>{},
                            ).join('، ').isEmpty
                              ? 'لم يُحدّد النوع'
                              : catalogGenres(
                                  findCatalogAnime(anime.title) ??
                                      <String, dynamic>{},
                                ).join('، ')),
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _messageCard(
    String message, {
    String? title,
    IconData icon = Icons.info_outline,
    Widget? extra,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Icon(icon, color: const Color(0xFFB87928)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            message,
            style: const TextStyle(color: Colors.white70, height: 1.8),
          ),
          if (extra != null) extra,
        ],
      ),
    );
  }
}

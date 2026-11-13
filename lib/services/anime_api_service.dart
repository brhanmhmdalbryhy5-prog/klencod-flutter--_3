import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime.dart';
import 'storage_service.dart';

class AnimeApiService {
  final StorageService _storage = StorageService();

  // 🔥 جلب البيانات مع العلاقات (المواسم والأفلام)
  Future<Map<String, dynamic>> fetchAnimeData(String animeTitle) async {
    if (animeTitle.trim().isEmpty) {
      return {'genres': <String>[], 'summary': '', 'episodes': 0, 'globalRating': null, 'releaseYear': null, 'subAnimes': []};
    }

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        const String url = 'https://graphql.anilist.co';

        final String query = '''
          query (\$search: String) {
            Page(perPage: 1) {
              media(search: \$search, type: ANIME) {
                id
                genres
                description
                episodes
                averageScore
                startDate { year }
                relations {
                  edges {
                    relationType
                    node {
                      id
                      title { romaji english }
                      episodes
                      format
                    }
                  }
                }
              }
            }
          }
        ''';

        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'query': query,
            'variables': {'search': animeTitle.trim()},
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final mediaList = data['data']?['Page']?['media'] as List?;

          if (mediaList != null && mediaList.isNotEmpty) {
            final media = mediaList[0];

            final List<String> rawGenres = (media['genres'] as List?)?.map((e) => e.toString()).toList() ?? [];
            bool hasAdultContent = rawGenres.any((g) => g == 'Ecchi' || g == 'Hentai');

            List<String> translatedGenres = rawGenres
                .where((g) => g != 'Ecchi' && g != 'Hentai')
                .map((g) => _translateGenre(g))
                .toList();

            final int episodes = (media['episodes'] as int?) ?? 0;
            final int? averageScore = media['averageScore'] as int?;
            final double? globalRating = averageScore != null ? averageScore / 10.0 : null;
            final int? releaseYear = media['startDate']?['year'] as int?;

            String summary = '';
            if (!hasAdultContent) {
              summary = media['description']?.toString() ?? '';
              summary = summary.replaceAll(RegExp(r'<[^>]*>'), '');
              if (summary.isNotEmpty) {
                summary = await _translateToArabic(summary);
              }
            }

            // 🔥 استخراج المواسم والأفلام
            List<Map<String, dynamic>> subAnimes = [];
            final relations = media['relations']?['edges'] as List?;
            if (relations != null) {
              for (var edge in relations) {
                final relationType = edge['relationType'];
                final node = edge['node'];
                final format = node['format'];
                
                // نأخذ المواسم (TV) والأفلام (MOVIE) و OVA و SPECIAL
                if (format == 'TV' || format == 'MOVIE' || format == 'OVA' || format == 'SPECIAL') {
                  final titleRomaji = node['title']['romaji'] ?? '';
                  final titleEnglish = node['title']['english'] ?? '';
                  final displayTitle = titleRomaji.isNotEmpty ? titleRomaji : titleEnglish;
                  
                  if (displayTitle.isNotEmpty) {
                    subAnimes.add({
                      'title': displayTitle,
                      'type': format == 'MOVIE' ? 'فيلم' : (relationType == 'PREQUEL' ? 'موسم سابق' : 'موسم لاحق'),
                      'episodes': node['episodes'] ?? 0,
                    });
                  }
                }
              }
            }

            return {
              'genres': translatedGenres, 
              'summary': summary, 
              'episodes': episodes,
              'globalRating': globalRating,
              'releaseYear': releaseYear,
              'subAnimes': subAnimes,
            };
          }
          return {'genres': <String>[], 'summary': '', 'episodes': 0, 'globalRating': null, 'releaseYear': null, 'subAnimes': []};
        }
      } catch (e) {
        if (attempt < 3) await Future.delayed(const Duration(seconds: 2));
      }
    }
    return {'genres': <String>[], 'summary': '', 'episodes': 0, 'globalRating': null, 'releaseYear': null, 'subAnimes': []};
  }

  Future<String> _translateToArabic(String text) async {
    if (text.trim().isEmpty) return '';
    try {
      final encodedText = Uri.encodeComponent(text);
      final url = Uri.parse('https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=ar&dt=t&q=$encodedText');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty && data[0] is List) {
          String translatedText = '';
          for (var sentence in data[0]) {
             if (sentence is List && sentence.isNotEmpty) translatedText += sentence[0];
          }
          return translatedText.trim();
        }
      }
    } catch (e) {}
    return text; 
  }

  Future<Map<String, int>> autoUpdateLibraryData() async {
    final animes = await _storage.loadAnimes();
    int updatedCount = 0;
    int failedCount = 0;

    for (int i = 0; i < animes.length; i++) {
      final anime = animes[i];
      if (anime.parentId != null) continue; // تخطي المواسم

      if (anime.genre.trim().isNotEmpty && anime.summary.trim().isNotEmpty && anime.episodes > 0 && anime.globalRating != null && anime.releaseYear != null) continue;

      final data = await fetchAnimeData(anime.title);
      bool changed = false;

      if (anime.genre.trim().isEmpty && (data['genres'] as List).isNotEmpty) { anime.genre = (data['genres'] as List).join('، '); changed = true; }
      if (anime.summary.trim().isEmpty && data['summary'].isNotEmpty) { anime.summary = data['summary']; changed = true; }
      if (anime.episodes == 0 && data['episodes'] > 0) { anime.episodes = data['episodes']; changed = true; }
      if (anime.globalRating == null && data['globalRating'] != null) { anime.globalRating = data['globalRating']; changed = true; }
      if (anime.releaseYear == null && data['releaseYear'] != null) { anime.releaseYear = data['releaseYear']; changed = true; }

      if (changed) updatedCount++; else failedCount++;
      await Future.delayed(const Duration(milliseconds: 1200));
    }

    if (updatedCount > 0) await _storage.saveAnimes(animes);
    return {'updated': updatedCount, 'failed': failedCount};
  }

  Future<int> clearAllGenres() async {
    final animes = await _storage.loadAnimes();
    int clearedCount = 0;
    for (var anime in animes) {
      if (anime.genre.trim().isNotEmpty) { anime.genre = ''; clearedCount++; }
    }
    if (clearedCount > 0) await _storage.saveAnimes(animes);
    return clearedCount;
  }

  String _translateGenre(String englishGenre) {
    final map = {
      'Action': 'أكشن', 'Adventure': 'مغامرة', 'Comedy': 'كوميدي', 'Drama': 'دراما',
      'Fantasy': 'فانتازيا', 'Horror': 'رعب', 'Mystery': 'غموض', 'Romance': 'رومانسي',
      'Sci-Fi': 'خيال علمي', 'Slice of Life': 'شريحة من الحياة', 'Sports': 'رياضة',
      'Supernatural': 'قوى خارقة', 'Thriller': 'إثارة', 'Mecha': 'ميكا', 'Music': 'موسيقي',
      'Psychological': 'نفسي', 'School': 'مدرسي', 'Shounen': 'شونين', 'Seinen': 'سينين',
      'Shoujo': 'شوجو', 'Josei': 'جوسي', 'Isekai': 'إيسيكاي', 'Historical': 'تاريخي',
      'Military': 'حربي', 'Space': 'فضاء', 'Police': 'بوليسي', 'Game': 'ألعاب',
      'Martial Arts': 'فنون قتالية', 'Samurai': 'ساموراي', 'Demons': 'شياطين',
      'Vampire': 'فامباير', 'Magic': 'سحر',
    };
    return map[englishGenre] ?? englishGenre;
  }
}
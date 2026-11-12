import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime.dart';
import 'storage_service.dart';

class AnimeApiService {
  final StorageService _storage = StorageService();

  // البحث عن أنمي بالاسم في AniList وجلب التصنيفات والقصة (مع الفلاتر والترجمة)
  Future<Map<String, dynamic>> fetchAnimeData(String animeTitle) async {
    if (animeTitle.trim().isEmpty) return {'genres': <String>[], 'summary': ''};

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        const String url = 'https://graphql.anilist.co';

        final String query = '''
          query (\$search: String) {
            Page(perPage: 1) {
              media(search: \$search, type: ANIME) {
                genres
                description
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
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final mediaList = data['data']?['Page']?['media'] as List?;

          if (mediaList != null && mediaList.isNotEmpty) {
            final media = mediaList[0];

            // 1. استخراج التصنيفات
            final List<String> rawGenres = (media['genres'] as List?)?.map((e) => e.toString()).toList() ?? [];

            // 2. فلتر المحتوى الإباحي
            bool hasAdultContent = rawGenres.any((g) => g == 'Ecchi' || g == 'Hentai');

            List<String> translatedGenres = rawGenres
                .where((g) => g != 'Ecchi' && g != 'Hentai')
                .map((g) => _translateGenre(g))
                .toList();

            // 3. معالجة القصة
            String summary = '';
            if (!hasAdultContent) {
              summary = media['description']?.toString() ?? '';
              // تنظيف النص من أكواد HTML
              summary = summary.replaceAll(RegExp(r'<[^>]*>'), '');
              
              // 🔥 ترجمة القصة إلى العربية
              if (summary.isNotEmpty) {
                summary = await _translateToArabic(summary);
              }
            }

            return {'genres': translatedGenres, 'summary': summary};
          }
          return {'genres': <String>[], 'summary': ''};
        }
      } catch (e) {
        if (attempt < 3) await Future.delayed(const Duration(seconds: 1));
      }
    }
    return {'genres': <String>[], 'summary': ''};
  }

  // 🔥 دالة الترجمة المجانية (Google Translate غير الرسمي)
  Future<String> _translateToArabic(String text) async {
    if (text.trim().isEmpty) return '';
    
    try {
      // تقسيم النص إذا كان طويلاً جداً (لتجنب مشاكل الرابط)
      final encodedText = Uri.encodeComponent(text);
      final url = Uri.parse('https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=ar&dt=t&q=$encodedText');
      
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // استخراج النص المترجم من الرد المعقد
        if (data is List && data.isNotEmpty && data[0] is List) {
          String translatedText = '';
          for (var sentence in data[0]) {
             if (sentence is List && sentence.isNotEmpty) {
               translatedText += sentence[0];
             }
          }
          return translatedText.trim();
        }
      }
    } catch (e) {
      // في حال فشلت الترجمة (مثلاً انقطع الإنترنت)، نرجع النص الإنجليزي
    }
    return text; 
  }

  // دالة لتحديث جميع الأنميات التي لا تحتوي على تصنيف أو قصة
  Future<Map<String, int>> autoUpdateLibraryData() async {
    final animes = await _storage.loadAnimes();
    int updatedCount = 0;
    int failedCount = 0;

    for (int i = 0; i < animes.length; i++) {
      final anime = animes[i];
      
      if (anime.genre.trim().isNotEmpty && anime.summary.trim().isNotEmpty) continue;

      final data = await fetchAnimeData(anime.title);
      final List<String> genres = data['genres'];
      final String summary = data['summary'];

      bool changed = false;
      if (anime.genre.trim().isEmpty && genres.isNotEmpty) {
        anime.genre = genres.join('، ');
        changed = true;
      }
      if (anime.summary.trim().isEmpty && summary.isNotEmpty) {
        anime.summary = summary;
        changed = true;
      }

      if (changed) {
        updatedCount++;
      } else {
        failedCount++;
      }

      // زيادة وقت الانتظار قليلاً لأن الترجمة تأخذ وقتاً إضافياً
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    if (updatedCount > 0) {
      await _storage.saveAnimes(animes);
    }

    return {'updated': updatedCount, 'failed': failedCount};
  }

  // دالة لمسح جميع التصنيفات
  Future<int> clearAllGenres() async {
    final animes = await _storage.loadAnimes();
    int clearedCount = 0;

    for (var anime in animes) {
      if (anime.genre.trim().isNotEmpty) {
        anime.genre = '';
        clearedCount++;
      }
    }

    if (clearedCount > 0) {
      await _storage.saveAnimes(animes);
    }

    return clearedCount;
  }

  String _translateGenre(String englishGenre) {
    final map = {
      'Action': 'أكشن', 'Adventure': 'مغامرة', 'Comedy': 'كوميدي',
      'Drama': 'دراما', 'Fantasy': 'فانتازيا', 'Horror': 'رعب',
      'Mystery': 'غموض', 'Romance': 'رومانسي', 'Sci-Fi': 'خيال علمي',
      'Slice of Life': 'شريحة من الحياة', 'Sports': 'رياضة',
      'Supernatural': 'قوى خارقة', 'Thriller': 'إثارة', 'Mecha': 'ميكا',
      'Music': 'موسيقي', 'Psychological': 'نفسي', 'School': 'مدرسي',
      'Shounen': 'شونين', 'Seinen': 'سينين', 'Shoujo': 'شوجو',
      'Josei': 'جوسي', 'Isekai': 'إيسيكاي', 'Historical': 'تاريخي',
      'Military': 'حربي', 'Space': 'فضاء', 'Police': 'بوليسي',
      'Game': 'ألعاب', 'Martial Arts': 'فنون قتالية', 'Samurai': 'ساموراي',
      'Demons': 'شياطين', 'Vampire': 'فامباير', 'Magic': 'سحر',
    };
    return map[englishGenre] ?? englishGenre;
  }
}
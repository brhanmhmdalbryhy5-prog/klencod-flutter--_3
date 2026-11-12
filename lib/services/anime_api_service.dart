import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime.dart';
import 'storage_service.dart';

class AnimeApiService {
  final StorageService _storage = StorageService();

  // البحث عن أنمي بالاسم في AniList وإرجاع قائمة التصنيفات
  Future<List<String>> fetchGenres(String animeTitle) async {
    if (animeTitle.trim().isEmpty) return [];

    try {
      // AniList يستخدم GraphQL (طلب POST)
      const String url = 'https://graphql.anilist.co';
      
      // استعلام GraphQL للبحث عن الأنمي وجلب التصنيفات
      final String query = '''
        query (\$search: String) {
          Page(perPage: 1) {
            media(search: \$search, type: ANIME) {
              genres
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
      ).timeout(const Duration(seconds: 10)); // وقت انتظار 10 ثوانٍ

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final mediaList = data['data']?['Page']?['media'] as List?;
        
        if (mediaList != null && mediaList.isNotEmpty) {
          final genres = mediaList[0]['genres'] as List?;
          if (genres != null) {
            return genres.map((g) => _translateGenre(g.toString())).toList();
          }
        }
      }
      return [];
    } catch (e) {
      // في حال حدوث خطأ (Timeout، انقطاع إنترنت، إلخ) نرجع قائمة فارغة
      return [];
    }
  }

  // دالة لتحديث جميع الأنميات التي لا تحتوي على تصنيف
  Future<Map<String, int>> autoUpdateLibraryGenres() async {
    final animes = await _storage.loadAnimes();
    int updatedCount = 0;
    int failedCount = 0;

    for (int i = 0; i < animes.length; i++) {
      final anime = animes[i];
      
      if (anime.genre.trim().isNotEmpty) continue;

      final genres = await fetchGenres(anime.title);

      if (genres.isNotEmpty) {
        anime.genre = genres.join('، ');
        updatedCount++;
      } else {
        failedCount++;
      }

      // تأخير بسيط بين الطلبات
      await Future.delayed(const Duration(milliseconds: 500));
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

  // ترجمة التصنيفات إلى العربية
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
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime.dart';
import 'storage_service.dart';

class AnimeApiService {
  final StorageService _storage = StorageService();

  // البحث عن أنمي بالاسم وإرجاع قائمة التصنيفات
  Future<List<String>> fetchGenres(String animeTitle) async {
    if (animeTitle.trim().isEmpty) return [];

    try {
      final query = Uri.encodeComponent(animeTitle.trim());
      final url = Uri.parse('https://api.jikan.moe/v4/anime?q=$query&limit=1');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          final anime = data['data'][0];
          final genres = anime['genres'] as List?;
          
          if (genres != null) {
            return genres.map((g) => _translateGenre(g['name'])).toList();
          }
        }
      }
      return [];
    } catch (e) {
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
      
      // إذا كان الأنمي يحتوي بالفعل على تصنيف، نتخطاه
      if (anime.genre.trim().isNotEmpty) continue;

      // جلب التصنيفات من الإنترنت
      final genres = await fetchGenres(anime.title);

      if (genres.isNotEmpty) {
        anime.genre = genres.join('، ');
        updatedCount++;
      } else {
        failedCount++;
      }

      // تأخير بسيط جداً (500 مللي ثانية) بين كل طلب لتجنب حظر الـ API
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // حفظ التغييرات
    if (updatedCount > 0) {
      await _storage.saveAnimes(animes);
    }

    return {'updated': updatedCount, 'failed': failedCount};
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
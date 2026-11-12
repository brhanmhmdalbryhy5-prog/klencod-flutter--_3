import 'dart:convert';
import 'package:http/http.dart' as http;

class AnimeApiService {
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
            // تحويل التصنيفات الإنجليزية إلى عربية (أو نتركها إنجليزية)
            return genres.map((g) => _translateGenre(g['name'])).toList();
          }
        }
      }
      return [];
    } catch (e) {
      // في حال فشل الاتصال، نرجع قائمة فارغة
      return [];
    }
  }

  // دالة بسيطة لترجمة التصنيفات الشائعة إلى العربية
  String _translateGenre(String englishGenre) {
    final map = {
      'Action': 'أكشن',
      'Adventure': 'مغامرة',
      'Comedy': 'كوميدي',
      'Drama': 'دراما',
      'Fantasy': 'فانتازيا',
      'Horror': 'رعب',
      'Mystery': 'غموض',
      'Romance': 'رومانسي',
      'Sci-Fi': 'خيال علمي',
      'Slice of Life': 'شريحة من الحياة',
      'Sports': 'رياضة',
      'Supernatural': 'قوى خارقة',
      'Thriller': 'إثارة',
      'Mecha': 'ميكا',
      'Music': 'موسيقي',
      'Psychological': 'نفسي',
      'School': 'مدرسي',
      'Shounen': 'شونين',
      'Seinen': 'سينين',
      'Shoujo': 'شوجو',
      'Josei': 'جوسي',
      'Isekai': 'إيسيكاي',
      'Historical': 'تاريخي',
      'Military': 'حربي',
      'Space': 'فضاء',
      'Police': 'بوليسي',
      'Game': 'ألعاب',
      'Martial Arts': 'فنون قتالية',
      'Samurai': 'ساموراي',
      'Demons': 'شياطين',
      'Vampire': 'فامباير',
      'Magic': 'سحر',
    };
    return map[englishGenre] ?? englishGenre; // إذا لم نجد ترجمة، نرجع الاسم الإنجليزي
  }
}
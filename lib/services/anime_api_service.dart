import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/anime.dart';
import 'storage_service.dart';

class AnimeApiService {
  final StorageService _storage = StorageService();

  Future<Map<String, dynamic>> fetchAnimeData(String animeTitle) async {
    if (animeTitle.trim().isEmpty) {
      return {'genres': <String>[], 'summary': '', 'episodes': 0, 'globalRating': null, 'releaseYear': null, 'imageUrl': null, 'subAnimes': [], 'characters': [], 'studios': null};
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
                coverImage { large }
                studios(isMain: true) {
                  nodes { name }
                }
                characters(sort: [ROLE, RELEVANCE, ID], perPage: 8) {
                  nodes {
                    name { full }
                    image { large }
                  }
                }
                relations {
                  edges {
                    relationType
                    node {
                      id
                      title { romaji english }
                      description
                      episodes
                      averageScore
                      startDate { year }
                      genres
                      coverImage { large }
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
          body: jsonEncode({'query': query, 'variables': {'search': animeTitle.trim()}}),
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
            final String? imageUrl = media['coverImage']?['large'] as String?;

            String? studios;
            final studiosList = media['studios']?['nodes'] as List?;
            if (studiosList != null && studiosList.isNotEmpty) {
              studios = studiosList.map((s) => s['name'].toString()).join('، ');
            }

            List<Map<String, dynamic>> characters = [];
            final charList = media['characters']?['nodes'] as List?;
            if (charList != null) {
              for (var c in charList) {
                final name = c['name']?['full'] ?? 'غير معروف';
                final img = c['image']?['large'] ?? '';
                characters.add({'name': name, 'image': img});
              }
            }

            String summary = '';
            if (!hasAdultContent) {
              summary = media['description']?.toString() ?? '';
              summary = summary.replaceAll(RegExp(r'<[^>]*>'), '');
              if (summary.isNotEmpty) summary = await _translateToArabic(summary);
            }

            List<Map<String, dynamic>> subAnimes = [];
            final relations = media['relations']?['edges'] as List?;
            if (relations != null) {
              for (var edge in relations) {
                final relationType = edge['relationType'];
                final node = edge['node'];
                final format = node['format'];
                
                if (format == 'TV' || format == 'MOVIE' || format == 'OVA' || format == 'SPECIAL' || format == 'TV_SHORT') {
                  final titleRomaji = node['title']['romaji'] ?? '';
                  final titleEnglish = node['title']['english'] ?? '';
                  final displayTitle = titleRomaji.isNotEmpty ? titleRomaji : titleEnglish;
                  
                  if (displayTitle.isNotEmpty) {
                    final subGenresRaw = (node['genres'] as List?)?.map((e) => e.toString()).toList() ?? [];
                    final subHasAdult = subGenresRaw.any((g) => g == 'Ecchi' || g == 'Hentai');
                    final subGenres = subGenresRaw.where((g) => g != 'Ecchi' && g != 'Hentai').map((g) => _translateGenre(g)).toList();
                    
                    String subSummary = node['description']?.toString() ?? '';
                    subSummary = subSummary.replaceAll(RegExp(r'<[^>]*>'), '');
                    if (subSummary.isNotEmpty && !subHasAdult) {
                      subSummary = await _translateToArabic(subSummary);
                    } else if (subHasAdult) {
                      subSummary = '';
                    }

                    final subScore = node['averageScore'] as int?;
                    
                    String partName = '';
                    if (format == 'MOVIE') partName = 'فيلم';
                    else if (relationType == 'PREQUEL') partName = 'موسم سابق';
                    else if (relationType == 'SEQUEL') partName = 'موسم لاحق';
                    else if (relationType == 'SIDE_STORY') partName = 'قصة جانبية';
                    else partName = 'جزء إضافي';
                    
                    subAnimes.add({
                      'title': displayTitle,
                      'partName': partName,
                      'episodes': node['episodes'] ?? 0,
                      'summary': subSummary,
                      'genre': subGenres.join('، '),
                      'globalRating': subScore != null ? subScore / 10.0 : null,
                      'releaseYear': node['startDate']?['year'] as int?,
                      'imageUrl': node['coverImage']?['large'] as String?,
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
              'imageUrl': imageUrl,
              'subAnimes': subAnimes,
              'characters': characters,
              'studios': studios,
            };
          }
          return {'genres': <String>[], 'summary': '', 'episodes': 0, 'globalRating': null, 'releaseYear': null, 'imageUrl': null, 'subAnimes': [], 'characters': [], 'studios': null};
        }
      } catch (e) {
        if (attempt < 3) await Future.delayed(const Duration(seconds: 2));
      }
    }
    return {'genres': <String>[], 'summary': '', 'episodes': 0, 'globalRating': null, 'releaseYear': null, 'imageUrl': null, 'subAnimes': [], 'characters': [], 'studios': null};
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
      if (anime.parentId != null) continue;

      if (anime.genre.trim().isNotEmpty && anime.summary.trim().isNotEmpty && anime.episodes > 0 && anime.globalRating != null && anime.releaseYear != null) continue;

      final data = await fetchAnimeData(anime.title);
      bool changed = false;

      if (anime.genre.trim().isEmpty && (data['genres'] as List).isNotEmpty) { anime.genre = (data['genres'] as List).join('، '); changed = true; }
      if (anime.summary.trim().isEmpty && data['summary'].isNotEmpty) { anime.summary = data['summary']; changed = true; }
      if (anime.episodes == 0 && data['episodes'] > 0) { anime.episodes = data['episodes']; changed = true; }
      if (anime.globalRating == null && data['globalRating'] != null) { anime.globalRating = data['globalRating']; changed = true; }
      if (anime.releaseYear == null && data['releaseYear'] != null) { anime.releaseYear = data['releaseYear']; changed = true; }
      if (anime.characters.isEmpty && (data['characters'] as List).isNotEmpty) {
        anime.characters = (data['characters'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        changed = true;
      }
      if (anime.studios == null && data['studios'] != null) { anime.studios = data['studios']; changed = true; }

      // 🔥 تحديث المواسم الموجودة وإنشاء الجديدة
      final List<Map<String, dynamic>> subData = data['subAnimes'];
      if (subData.isNotEmpty) {
        for (var sub in subData) {
          final existingIndex = animes.indexWhere((a) => a.title == sub['title'] && a.parentId == anime.id);
          
          if (existingIndex == -1) {
            // إنشاء موسم جديد
            final newSub = Anime(
              id: DateTime.now().microsecondsSinceEpoch.toString() + Random().nextInt(999).toString(),
              title: sub['title'],
              partName: sub['partName'],
              parentId: anime.id,
              episodes: sub['episodes'] ?? 0,
              summary: sub['summary'] ?? '',
              genre: sub['genre'] ?? '',
              globalRating: sub['globalRating'],
              releaseYear: sub['releaseYear'],
              imageUrl: sub['imageUrl'],
            );
            animes.add(newSub);
            changed = true;
          } else {
            // 🔥 تحديث الموسم الموجود إذا كانت بياناته ناقصة
            final existing = animes[existingIndex];
            if (existing.globalRating == null && sub['globalRating'] != null) { existing.globalRating = sub['globalRating']; changed = true; }
            if (existing.releaseYear == null && sub['releaseYear'] != null) { existing.releaseYear = sub['releaseYear']; changed = true; }
            if ((existing.imageUrl == null || existing.imageUrl!.isEmpty) && sub['imageUrl'] != null) { existing.imageUrl = sub['imageUrl']; changed = true; }
            if (existing.summary.isEmpty && (sub['summary'] ?? '').isNotEmpty) { existing.summary = sub['summary']; changed = true; }
            if (existing.genre.isEmpty && (sub['genre'] ?? '').isNotEmpty) { existing.genre = sub['genre']; changed = true; }
            if (existing.episodes == 0 && (sub['episodes'] ?? 0) > 0) { existing.episodes = sub['episodes']; changed = true; }
          }
        }
      }

      if (changed) updatedCount++; else failedCount++;
      await Future.delayed(const Duration(milliseconds: 1500));
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
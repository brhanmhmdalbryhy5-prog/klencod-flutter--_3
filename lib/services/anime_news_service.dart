import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime_news.dart';

class NewsFetchResult {
  final bool success;
  final int count;
  final int failed;
  final String? error;
  const NewsFetchResult({
    required this.success,
    required this.count,
    this.failed = 0,
    this.error,
  });
}

class AnimeNewsService {
  static const String _prefsKey = 'anime_news_data';
  static const String _lastFetchKey = 'anime_news_last_fetch';
  static const String _baseUrl = 'https://api.jikan.moe/v4';

  Future<List<AnimeNews>> loadNews() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => AnimeNews.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<DateTime?> getLastFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_lastFetchKey);
    return str != null ? DateTime.tryParse(str) : null;
  }

  Future<int> clearNews() async {
    final existing = await loadNews();
    for (final n in existing) {
      if (n.imagePath != null && n.imagePath!.isNotEmpty) {
        try {
          final f = File(n.imagePath!);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove(_lastFetchKey);
    return existing.length;
  }

  // 🆕 حفظ فوري لكل عنصر + الحفاظ على الأخبار القديمة + معالجة فشل منفصل
  Future<NewsFetchResult> fetchUpcoming({
    required void Function(double progress, String stage, String? title)
        onProgress,
    void Function(AnimeNews news)? onItemFetched,
  }) async {
    int newCount = 0;
    int failedCount = 0;

    try {
      // 1. تحميل الأخبار الموجودة (لن تُفقد)
      final savedNews = await loadNews();
      final existingIds = savedNews.map((n) => n.malId).toSet();

      onProgress(0.0, 'جارٍ الاتصال بالخادم...', null);

      // 2. جلب الأنميات القادمة (بدون فشل كلي عند خطأ صفحة واحدة)
      final allResults = <Map<String, dynamic>>[];
      const maxPages = 3;

      for (int page = 1; page <= maxPages; page++) {
        onProgress(
          0.02 + (page - 1) * 0.15,
          'جلب الصفحة $page من $maxPages...',
          null,
        );
        try {
          final response = await http
              .get(
                Uri.parse('$_baseUrl/seasons/upcoming?page=$page&limit=25'),
                headers: {'User-Agent': 'AnimeMemory/1.0'},
              )
              .timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final list = data['data'] as List? ?? [];
            allResults.addAll(list.cast<Map<String, dynamic>>());
          } else if (response.statusCode == 429) {
            // Rate limited - انتظر وأعد
            await Future.delayed(const Duration(seconds: 2));
            try {
              final retry = await http.get(
                Uri.parse('$_baseUrl/seasons/upcoming?page=$page&limit=25'),
                headers: {'User-Agent': 'AnimeMemory/1.0'},
              );
              if (retry.statusCode == 200) {
                final data = jsonDecode(retry.body) as Map<String, dynamic>;
                final list = data['data'] as List? ?? [];
                allResults.addAll(list.cast<Map<String, dynamic>>());
              }
            } catch (_) {}
          }
          if (page < maxPages) {
            await Future.delayed(const Duration(milliseconds: 450));
          }
        } catch (_) {
          // تخطي الصفحة الفاشلة، تابع
        }
      }

      if (allResults.isEmpty) {
        onProgress(1.0, 'لا توجد بيانات', null);
        return const NewsFetchResult(
          success: false,
          count: 0,
          error: 'تعذر جلب البيانات من الخادم. جرّب لاحقاً.',
        );
      }

      onProgress(0.55, 'تصفية الأنميات...', null);

      // 3. تصفية
      final now = DateTime.now();
      final filtered = <Map<String, dynamic>>[];
      final seenIds = <int>{};

      for (final anime in allResults) {
        final aired = anime['aired'] as Map<String, dynamic>?;
        final fromStr = aired?['from'] as String?;
        if (fromStr == null || fromStr.isEmpty) continue;

        DateTime? releaseDate;
        try {
          releaseDate = DateTime.parse(fromStr);
        } catch (_) {
          continue;
        }

        if (!releaseDate.isAfter(now)) continue;

        final malId = (anime['mal_id'] as num?)?.toInt();
        if (malId == null) continue;
        if (seenIds.contains(malId)) continue;
        seenIds.add(malId);

        filtered.add(anime);
      }

      // ترتيب حسب أقرب موعد
      filtered.sort((a, b) {
        try {
          final aDate = DateTime.parse(a['aired']['from'] as String);
          final bDate = DateTime.parse(b['aired']['from'] as String);
          return aDate.compareTo(bDate);
        } catch (_) {
          return 0;
        }
      });

      // 4. تحميل الصور + حفظ فوري لكل عنصر
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/anime_news_images');
      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

      for (int i = 0; i < filtered.length; i++) {
        try {
          final anime = filtered[i];
          final malId = (anime['mal_id'] as num).toInt();
          final title = anime['title'] as String? ??
              anime['title_english'] as String? ??
              'بدون اسم';

          // تخطي المحفوظ مسبقاً
          if (existingIds.contains(malId)) {
            onProgress(
              0.6 + (i / filtered.length) * 0.35,
              'موجود مسبقاً (${i + 1}/${filtered.length})',
              title,
            );
            continue;
          }

          final itemProgress = 0.6 + (i / filtered.length) * 0.35;
          onProgress(
            itemProgress,
            'جديد (${i + 1}/${filtered.length})',
            title,
          );

          // تحميل الصورة
          String? imageUrl;
          String? imagePath;
          final images = anime['images'] as Map<String, dynamic>?;
          final jpg = images?['jpg'] as Map<String, dynamic>?;
          imageUrl = jpg?['large_image_url'] as String? ??
              jpg?['image_url'] as String?;

          if (imageUrl != null && imageUrl.isNotEmpty) {
            try {
              final imgRes = await http
                  .get(Uri.parse(imageUrl),
                      headers: {'User-Agent': 'AnimeMemory/1.0'})
                  .timeout(const Duration(seconds: 15));
              if (imgRes.statusCode == 200) {
                final path =
                    '${imagesDir.path}/news_${malId}_${DateTime.now().microsecondsSinceEpoch}.jpg';
                final file = File(path);
                await file.writeAsBytes(imgRes.bodyBytes);
                imagePath = path;
              }
            } catch (_) {}
          }

          final aired = anime['aired'] as Map<String, dynamic>;
          final releaseDate = DateTime.parse(aired['from'] as String);

          final genresList = (anime['genres'] as List?)
                  ?.map((g) => (g as Map)['name'] as String?)
                  .where((g) => g != null)
                  .cast<String>()
                  .toList() ??
              [];

          final studiosList = (anime['studios'] as List?)
                  ?.map((s) => (s as Map)['name'] as String?)
                  .where((s) => s != null)
                  .cast<String>()
                  .toList() ??
              [];

          final newsItem = AnimeNews(
            id: 'news_$malId',
            malId: malId,
            title: title,
            imageUrl: imageUrl,
            imagePath: imagePath,
            releaseDate: releaseDate,
            format: anime['type'] as String? ?? '',
            episodes: (anime['episodes'] as num?)?.toInt() ?? 0,
            genres: genresList.join('، '),
            studios: studiosList.join('، '),
            synopsis: (anime['synopsis'] as String? ?? '').trim(),
            score: (anime['score'] as num?)?.toDouble(),
            fetchedAt: DateTime.now(),
          );

          // 🆕 الحفظ الفوري لكل عنصر
          savedNews.add(newsItem);
          existingIds.add(malId);
          newCount++;

          final prefs = await SharedPreferences.getInstance();
          final encoded =
              jsonEncode(savedNews.map((n) => n.toJson()).toList());
          await prefs.setString(_prefsKey, encoded);
          await prefs.setString(
              _lastFetchKey, DateTime.now().toIso8601String());

          // 🆕 إعلام الواجهة بالعنصر الجديد
          onItemFetched?.call(newsItem);

          if (i < filtered.length - 1) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        } catch (_) {
          failedCount++;
          // متابعة العنصر التالي
        }
      }

      onProgress(
        1.0,
        newCount > 0
            ? 'اكتمل: $newCount جديد'
            : 'لا توجد أخبار جديدة',
        null,
      );

      return NewsFetchResult(
        success: true,
        count: newCount,
        failed: failedCount,
      );
    } catch (e) {
      onProgress(1.0, 'فشل: $e', null);
      return NewsFetchResult(
        success: false,
        count: newCount,
        failed: failedCount,
        error: 'حدث خطأ: $e',
      );
    }
  }
}
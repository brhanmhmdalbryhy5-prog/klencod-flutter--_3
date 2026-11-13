import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/anime.dart';
import 'anime_api_service.dart';
import 'storage_service.dart';
import 'image_service.dart';

class BulkDownloadProgress {
  final int total;
  final int current;
  final String currentTitle;
  final String status;
  final List<String> failedNames;

  BulkDownloadProgress({
    required this.total, 
    required this.current, 
    required this.currentTitle, 
    required this.status,
    this.failedNames = const [],
  });

  double get percentage => total == 0 ? 0 : current / total;
  bool get isCompleted => total > 0 && current >= total;
}

class BulkDownloadService {
  static final BulkDownloadService _instance = BulkDownloadService._internal();
  factory BulkDownloadService() => _instance;
  BulkDownloadService._internal();

  final StorageService storage = StorageService();
  final AnimeApiService apiService = AnimeApiService();

  final ValueNotifier<BulkDownloadProgress?> progress = ValueNotifier(null);
  bool isRunning = false;
  bool _cancelRequested = false;

  void cancel() => _cancelRequested = true;
  void reset() { progress.value = null; _cancelRequested = false; }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _hasValidData(Map<String, dynamic> data) {
    final genres = data['genres'] as List? ?? [];
    final summary = data['summary'] as String? ?? '';
    final episodes = data['episodes'] as int? ?? 0;
    final imageUrl = data['imageUrl'] as String?;
    final subAnimes = data['subAnimes'] as List? ?? [];
    final characters = data['characters'] as List? ?? [];
    return genres.isNotEmpty || summary.isNotEmpty || episodes > 0 || (imageUrl != null && imageUrl.isNotEmpty) || subAnimes.isNotEmpty || characters.isNotEmpty;
  }

  Future<Map<String, dynamic>> downloadAllData() async {
    if (isRunning) return {'updated': 0, 'failed': 0, 'failedNames': <String>[]};
    final hasNetAtStart = await _hasInternet();
    if (!hasNetAtStart) {
      progress.value = BulkDownloadProgress(total: 0, current: 0, currentTitle: 'لا يوجد إنترنت', status: '❌ تعذر الاتصال');
      return {'updated': 0, 'failed': 0, 'failedNames': <String>[], 'error': 'no_internet'};
    }

    isRunning = true;
    _cancelRequested = false;
    final animes = await storage.loadAnimes();
    final mainAnimes = animes.where((a) => a.parentId == null).toList();
    int updated = 0;
    int failed = 0;
    int processed = 0;
    List<String> failedNames = [];

    for (int i = 0; i < mainAnimes.length; i++) {
      if (_cancelRequested) break;
      final hasNet = await _hasInternet();
      if (!hasNet) {
        progress.value = BulkDownloadProgress(total: mainAnimes.length, current: processed, currentTitle: 'انقطع الاتصال', status: '❌ انقطع الإنترنت', failedNames: failedNames);
        isRunning = false;
        return {'updated': updated, 'failed': failed, 'failedNames': failedNames, 'error': 'connection_lost'};
      }

      final anime = mainAnimes[i];
      progress.value = BulkDownloadProgress(total: mainAnimes.length, current: processed, currentTitle: anime.title, status: 'جاري الجلب (نجح: $updated | فشل: $failed)', failedNames: failedNames);

      try {
        final data = await apiService.fetchAnimeData(anime.title, downloadImages: true);
        if (!_hasValidData(data)) {
          failedNames.add(anime.title);
          failed++;
          processed++;
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        if ((data['genres'] as List).isNotEmpty) anime.genre = (data['genres'] as List).join('، ');
        if ((data['summary'] as String).isNotEmpty) anime.summary = data['summary'];
        if ((data['episodes'] as int) > 0) anime.episodes = data['episodes'];
        if (data['globalRating'] != null) anime.globalRating = data['globalRating'];
        if (data['releaseYear'] != null) anime.releaseYear = data['releaseYear'];
        if (data['studios'] != null) anime.studios = data['studios'];
        // ✅ التعديل الرئيسي: لا نكتب فوق صورة الأنمي الأصلي إن كانت موجودة.
        // لتغيير صورة الأنمي الأصلي استخدم زر "جلب صورة الغلاف" في شاشة التفاصيل.
        if (anime.imagePath == null && data['imagePath'] != null) {
          anime.imagePath = data['imagePath'];
        }
        if ((data['characters'] as List).isNotEmpty) anime.characters = List<Map<String, dynamic>>.from(data['characters']);

        final subData = data['subAnimes'] as List? ?? [];
        for (var sub in subData) {
          final idx = animes.indexWhere((a) => a.title == sub['title'] && a.parentId == anime.id);
          if (idx == -1) {
            animes.add(Anime(
              id: '${DateTime.now().microsecondsSinceEpoch}_${sub['title'].hashCode.abs()}',
              title: sub['title'],
              partName: sub['partName'],
              parentId: anime.id,
              episodes: sub['episodes'] ?? 0,
              summary: sub['summary'] ?? '',
              genre: sub['genre'] ?? '',
              globalRating: sub['globalRating'],
              releaseYear: sub['releaseYear'],
              imageUrl: sub['imageUrl'],
              imagePath: sub['imagePath'],
              characters: (sub['characters'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [], // 🔥
            ));
          } else {
            final existing = animes[idx];
            if (existing.globalRating == null && sub['globalRating'] != null) existing.globalRating = sub['globalRating'];
            if (existing.releaseYear == null && sub['releaseYear'] != null) existing.releaseYear = sub['releaseYear'];
            // ✅ تحسين: أعد جلب صورة الموسم إذا كانت مفقودة أو الملف محذوف من الجهاز
            final needsSubImage = existing.imagePath == null || !File(existing.imagePath!).existsSync();
            if (needsSubImage && sub['imagePath'] != null) existing.imagePath = sub['imagePath'];
            if (existing.summary.isEmpty && (sub['summary'] ?? '').isNotEmpty) existing.summary = sub['summary'];
            if (existing.genre.isEmpty && (sub['genre'] ?? '').isNotEmpty) existing.genre = sub['genre'];
            // ✅ تحسين: تحديث عدد حلقات الموسم إذا كان صفراً (كان ناقصاً)
            if (existing.episodes == 0 && (sub['episodes'] ?? 0) > 0) existing.episodes = sub['episodes'];
            // 🔥 تحديث شخصيات الموسم إذا كانت فارغة
            if (existing.characters.isEmpty && (sub['characters'] as List?)?.isNotEmpty == true) {
              existing.characters = List<Map<String, dynamic>>.from(sub['characters']);
            }
          }
        }

        await storage.saveAnimes(animes);
        updated++;
        processed++;
      } catch (e) {
        failedNames.add(anime.title);
        failed++;
        processed++;
      }
      await Future.delayed(const Duration(milliseconds: 800));
    }

    progress.value = BulkDownloadProgress(total: mainAnimes.length, current: mainAnimes.length, currentTitle: 'اكتمل', status: '✅ تم الانتهاء (نجح: $updated | فشل: $failed)', failedNames: failedNames);
    isRunning = false;
    return {'updated': updated, 'failed': failed, 'failedNames': failedNames};
  }

  Future<Map<String, dynamic>> downloadImagesOnly() async {
    if (isRunning) return {'updated': 0, 'failed': 0, 'failedNames': <String>[]};
    final hasNetAtStart = await _hasInternet();
    if (!hasNetAtStart) {
      progress.value = BulkDownloadProgress(total: 0, current: 0, currentTitle: 'لا يوجد إنترنت', status: '❌ تعذر الاتصال');
      return {'updated': 0, 'failed': 0, 'failedNames': <String>[], 'error': 'no_internet'};
    }

    isRunning = true;
    _cancelRequested = false;
    final animes = await storage.loadAnimes();
    int updated = 0;
    int failed = 0;
    int processed = 0;
    List<String> failedNames = [];

    for (int i = 0; i < animes.length; i++) {
      if (_cancelRequested) break;
      final hasNet = await _hasInternet();
      if (!hasNet) {
        progress.value = BulkDownloadProgress(total: animes.length, current: processed, currentTitle: 'انقطع الاتصال', status: '❌ انقطع الإنترنت', failedNames: failedNames);
        isRunning = false;
        return {'updated': updated, 'failed': failed, 'failedNames': failedNames};
      }

      final anime = animes[i];
      progress.value = BulkDownloadProgress(total: animes.length, current: processed, currentTitle: anime.title, status: 'جاري تحميل الصور (نجح: $updated | فشل: $failed)', failedNames: failedNames);

      bool changed = false;
      if (anime.imagePath == null && anime.imageUrl != null) {
        final path = await ImageService.downloadImage(anime.imageUrl, prefix: 'cover');
        if (path != null) { anime.imagePath = path; changed = true; }
      }
      if (anime.characters.isNotEmpty) {
        for (var char in anime.characters) {
          if (char['imagePath'] == null && char['imageUrl'] != null) {
            final path = await ImageService.downloadImage(char['imageUrl'], prefix: 'char');
            if (path != null) { char['imagePath'] = path; changed = true; }
          }
        }
      }
      if (changed) { updated++; await storage.saveAnimes(animes); } else { failedNames.add(anime.title); failed++; }
      processed++;
      await Future.delayed(const Duration(milliseconds: 300));
    }

    progress.value = BulkDownloadProgress(total: animes.length, current: animes.length, currentTitle: 'اكتمل', status: '✅ تم الانتهاء (نجح: $updated | فشل: $failed)', failedNames: failedNames);
    isRunning = false;
    return {'updated': updated, 'failed': failed, 'failedNames': failedNames};
  }
}
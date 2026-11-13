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
  
  BulkDownloadProgress({required this.total, required this.current, required this.currentTitle, required this.status});
  
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

  Future<Map<String, int>> downloadAllData() async {
    if (isRunning) return {'updated': 0, 'failed': 0};
    isRunning = true;
    _cancelRequested = false;
    
    final animes = await storage.loadAnimes();
    final mainAnimes = animes.where((a) => a.parentId == null).toList();
    int updated = 0;
    int failed = 0;

    for (int i = 0; i < mainAnimes.length; i++) {
      if (_cancelRequested) break;
      
      final anime = mainAnimes[i];
      progress.value = BulkDownloadProgress(
        total: mainAnimes.length, current: i,
        currentTitle: anime.title, status: 'جاري جلب البيانات والصور...',
      );
      
      try {
        final data = await apiService.fetchAnimeData(anime.title, downloadImages: true);
        bool changed = false;
        
        if ((data['genres'] as List).isNotEmpty && anime.genre != (data['genres'] as List).join('، ')) {
          anime.genre = (data['genres'] as List).join('، '); changed = true;
        }
        if (data['summary'].isNotEmpty && anime.summary.isEmpty) { anime.summary = data['summary']; changed = true; }
        if ((data['episodes'] as int) > 0 && anime.episodes == 0) { anime.episodes = data['episodes']; changed = true; }
        if (data['globalRating'] != null && anime.globalRating == null) { anime.globalRating = data['globalRating']; changed = true; }
        if (data['releaseYear'] != null && anime.releaseYear == null) { anime.releaseYear = data['releaseYear']; changed = true; }
        if (data['studios'] != null && anime.studios == null) { anime.studios = data['studios']; changed = true; }
        if (data['imagePath'] != null && anime.imagePath == null) { anime.imagePath = data['imagePath']; changed = true; }
        if ((data['characters'] as List).isNotEmpty) { 
          anime.characters = List<Map<String, dynamic>>.from(data['characters']); 
          changed = true; 
        }
        
        final subData = data['subAnimes'] as List;
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
            ));
            changed = true;
          } else {
            final existing = animes[idx];
            if (existing.globalRating == null && sub['globalRating'] != null) { existing.globalRating = sub['globalRating']; changed = true; }
            if (existing.releaseYear == null && sub['releaseYear'] != null) { existing.releaseYear = sub['releaseYear']; changed = true; }
            if (existing.imagePath == null && sub['imagePath'] != null) { existing.imagePath = sub['imagePath']; changed = true; }
            if (existing.summary.isEmpty && sub['summary'] != null) { existing.summary = sub['summary']; changed = true; }
            if (existing.genre.isEmpty && sub['genre'] != null) { existing.genre = sub['genre']; changed = true; }
          }
        }
        
        await storage.saveAnimes(animes);
        updated++;
      } catch (e) {
        failed++;
      }
      
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    progress.value = BulkDownloadProgress(
      total: mainAnimes.length, current: mainAnimes.length,
      currentTitle: _cancelRequested ? 'تم الإلغاء' : 'اكتمل',
      status: _cancelRequested ? 'أوقفت العملية' : 'تم الانتهاء',
    );
    isRunning = false;
    return {'updated': updated, 'failed': failed};
  }

  Future<Map<String, int>> downloadImagesOnly() async {
    if (isRunning) return {'updated': 0, 'failed': 0};
    isRunning = true;
    _cancelRequested = false;
    
    final animes = await storage.loadAnimes();
    int updated = 0;
    int failed = 0;

    for (int i = 0; i < animes.length; i++) {
      if (_cancelRequested) break;
      
      final anime = animes[i];
      progress.value = BulkDownloadProgress(
        total: animes.length, current: i,
        currentTitle: anime.title, status: 'جاري تحميل الصور...',
      );
      
      bool changed = false;
      
      if (anime.imagePath == null && anime.imageUrl != null) {
        final path = await ImageService.downloadImage(anime.imageUrl, prefix: 'cover');
        if (path != null) { anime.imagePath = path; changed = true; }
      }
      
      if (anime.characters.isNotEmpty) {
        bool charChanged = false;
        for (var char in anime.characters) {
          if (char['imagePath'] == null && char['imageUrl'] != null) {
            final path = await ImageService.downloadImage(char['imageUrl'], prefix: 'char');
            if (path != null) { char['imagePath'] = path; charChanged = true; }
          }
        }
        if (charChanged) changed = true;
      }
      
      if (changed) {
        updated++;
        await storage.saveAnimes(animes);
      } else {
        failed++;
      }
    }

    progress.value = BulkDownloadProgress(
      total: animes.length, current: animes.length,
      currentTitle: _cancelRequested ? 'تم الإلغاء' : 'اكتمل',
      status: _cancelRequested ? 'أوقفت العملية' : 'تم الانتهاء',
    );
    isRunning = false;
    return {'updated': updated, 'failed': failed};
  }
}
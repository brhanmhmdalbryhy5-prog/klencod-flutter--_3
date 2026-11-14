import 'dart:io';
import '../models/anime.dart';
import 'storage_service.dart';

class HealthIssue {
  final String title;
  final String description;
  final bool isFixed;

  HealthIssue({required this.title, required this.description, this.isFixed = false});
}

class DataHealthResult {
  final int totalAnimes;
  final List<HealthIssue> issues;
  final int deletedOrphanFiles;
  final int fixedPaths;

  DataHealthResult({
    required this.totalAnimes,
    required this.issues,
    required this.deletedOrphanFiles,
    required this.fixedPaths,
  });
}

class DataHealthService {
  final StorageService _storage = StorageService();

  Future<DataHealthResult> checkAndFix() async {
    final animes = await _storage.loadAnimes();
    final issues = <HealthIssue>[];
    int deletedOrphanFiles = 0;
    int fixedPaths = 0;

    for (var anime in animes) {
      // 1. فحص الغلاف الأمامي
      if (anime.imagePath != null && anime.imagePath!.isNotEmpty) {
        if (!File(anime.imagePath!).existsSync()) {
          issues.add(HealthIssue(
            title: anime.title,
            description: 'الغلاف الأمامي مفقود من الجهاز.',
          ));
          anime.imagePath = null;
          fixedPaths++;
        }
      }

      // 2. فحص الغلاف الخلفي
      if (anime.backImagePath != null && anime.backImagePath!.isNotEmpty) {
        if (!File(anime.backImagePath!).existsSync()) {
          issues.add(HealthIssue(
            title: anime.title,
            description: 'الغلاف الخلفي مفقود من الجهاز.',
          ));
          anime.backImagePath = null;
          fixedPaths++;
        }
      }

      // 3. فحص الفيديو
      if (anime.videoPath != null && anime.videoPath!.isNotEmpty) {
        if (!File(anime.videoPath!).existsSync()) {
          issues.add(HealthIssue(
            title: anime.title,
            description: 'الفيديو التذكاري مفقود من الجهاز.',
          ));
          anime.videoPath = null;
          fixedPaths++;
        }
      }

      // 4. فحص الشخصيات
      for (var i = 0; i < anime.characters.length; i++) {
        final char = anime.characters[i];
        final path = char['imagePath'] as String?;
        if (path != null && path.isNotEmpty) {
          if (!File(path).existsSync()) {
            anime.characters[i]['imagePath'] = null;
            fixedPaths++;
          }
        }
      }

      // 5. فحص المشاهد
      for (var i = 0; i < anime.scenes.length; i++) {
        final scene = anime.scenes[i];
        final path = scene['imagePath'] as String?;
        if (path != null && path.isNotEmpty) {
          if (!File(path).existsSync()) {
            anime.scenes[i]['imagePath'] = null;
            fixedPaths++;
          }
        }
      }
    }

    // حفظ الإصلاحات
    if (fixedPaths > 0) {
      await _storage.saveAnimes(animes);
    }

    return DataHealthResult(
      totalAnimes: animes.length,
      issues: issues,
      deletedOrphanFiles: deletedOrphanFiles,
      fixedPaths: fixedPaths,
    );
  }
}
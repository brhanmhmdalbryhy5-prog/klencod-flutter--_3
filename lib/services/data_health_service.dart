import 'dart:io';
import '../models/anime.dart';
import 'storage_service.dart';

enum HealthIssueType {
  missingCover,
  missingBackCover,
  missingVideo,
  missingCharacterImage,
  missingSceneImage,
  emptyTitle,
  emptyGenre,
  duplicate,
}

extension HealthIssueTypeExtension on HealthIssueType {
  String get label {
    switch (this) {
      case HealthIssueType.missingCover: return 'غلاف أمامي مفقود';
      case HealthIssueType.missingBackCover: return 'غلاف خلفي مفقود';
      case HealthIssueType.missingVideo: return 'فيديو مفقود';
      case HealthIssueType.missingCharacterImage: return 'صورة شخصية مفقودة';
      case HealthIssueType.missingSceneImage: return 'صورة مشهد مفقودة';
      case HealthIssueType.emptyTitle: return 'بدون اسم';
      case HealthIssueType.emptyGenre: return 'بدون تصنيف';
      case HealthIssueType.duplicate: return 'مكرر';
    }
  }

  int get severity {
    switch (this) {
      case HealthIssueType.emptyTitle: return 3; // خطير
      case HealthIssueType.duplicate: return 2;  // متوسط
      default: return 1;                          // خفيف
    }
  }
}

class HealthIssue {
  final String animeId;
  final String animeTitle;
  final String description;
  final HealthIssueType type;
  final bool wasFixed;

  HealthIssue({
    required this.animeId,
    required this.animeTitle,
    required this.description,
    required this.type,
    this.wasFixed = false,
  });
}

class DataHealthReport {
  // أعداد
  final int totalAnimes;
  final int totalCharacters;
  final int totalScenes;
  final int totalVideos;
  
  // مساحة التخزين
  final int coverBytes;
  final int videoBytes;
  final int characterBytes;
  final int sceneBytes;
  final int memoryBytes;

  // مشاكل
  final List<HealthIssue> issues;
  final int fixedCount;
  final int healthScore;

  DataHealthReport({
    required this.totalAnimes,
    required this.totalCharacters,
    required this.totalScenes,
    required this.totalVideos,
    required this.coverBytes,
    required this.videoBytes,
    required this.characterBytes,
    required this.sceneBytes,
    required this.memoryBytes,
    required this.issues,
    required this.fixedCount,
    required this.healthScore,
  });

  int get totalBytes =>
      coverBytes + videoBytes + characterBytes + sceneBytes + memoryBytes;

  int get missingFilesCount => issues.where((i) =>
      i.type == HealthIssueType.missingCover ||
      i.type == HealthIssueType.missingBackCover ||
      i.type == HealthIssueType.missingVideo ||
      i.type == HealthIssueType.missingCharacterImage ||
      i.type == HealthIssueType.missingSceneImage).length;

  Map<HealthIssueType, int> get issuesByType {
    final map = <HealthIssueType, int>{};
    for (final issue in issues) {
      map[issue.type] = (map[issue.type] ?? 0) + 1;
    }
    return map;
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class DataHealthService {
  final StorageService _storage = StorageService();

  Future<int> _fileSize(String? path) async {
    if (path == null || path.isEmpty) return 0;
    try {
      final file = File(path);
      if (await file.exists()) return await file.length();
    } catch (_) {}
    return 0;
  }

  Future<bool> _fileExists(String? path) async {
    if (path == null || path.isEmpty) return false;
    try {
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }

  /// فحص شامل للمكتبة + إصلاح تلقائي اختياري
  Future<DataHealthReport> scan({
    bool autoFix = false,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    final animes = await _storage.loadAnimes();
    final issues = <HealthIssue>[];
    int fixedCount = 0;

    int coverBytes = 0;
    int videoBytes = 0;
    int characterBytes = 0;
    int sceneBytes = 0;
    int memoryBytes = 0;

    int totalCharacters = 0;
    int totalScenes = 0;
    int totalVideos = 0;

    final titleCount = <String, int>{};

    for (int i = 0; i < animes.length; i++) {
      final anime = animes[i];
      if (onProgress != null) {
        onProgress(i + 1, animes.length, anime.title.isEmpty ? 'بدون اسم' : anime.title);
      }

      // 1. الاسم
      if (anime.title.trim().isEmpty) {
        issues.add(HealthIssue(
          animeId: anime.id,
          animeTitle: 'بدون اسم',
          description: 'الأنمي بدون اسم، لا يمكن البحث عنه',
          type: HealthIssueType.emptyTitle,
        ));
      } else {
        // كشف المكررات
        final key = anime.title.trim().toLowerCase();
        titleCount[key] = (titleCount[key] ?? 0) + 1;
      }

      // 2. التصنيف
      if (anime.genre.trim().isEmpty) {
        issues.add(HealthIssue(
          animeId: anime.id,
          animeTitle: anime.title,
          description: 'لا يوجد تصنيف، لن يظهر في الفلاتر',
          type: HealthIssueType.emptyGenre,
        ));
      }

      // 3. الغلاف الأمامي
      if (anime.imagePath != null && anime.imagePath!.isNotEmpty) {
        if (await _fileExists(anime.imagePath)) {
          coverBytes += await _fileSize(anime.imagePath);
        } else {
          issues.add(HealthIssue(
            animeId: anime.id,
            animeTitle: anime.title,
            description: 'ملف الغلاف محذوف من الجهاز',
            type: HealthIssueType.missingCover,
          ));
          if (autoFix) {
            anime.imagePath = null;
            fixedCount++;
          }
        }
      }

      // 4. الغلاف الخلفي
      if (anime.backImagePath != null && anime.backImagePath!.isNotEmpty) {
        if (await _fileExists(anime.backImagePath)) {
          coverBytes += await _fileSize(anime.backImagePath);
        } else {
          issues.add(HealthIssue(
            animeId: anime.id,
            animeTitle: anime.title,
            description: 'ملف الغلاف الخلفي محذوف',
            type: HealthIssueType.missingBackCover,
          ));
          if (autoFix) {
            anime.backImagePath = null;
            fixedCount++;
          }
        }
      }

      // 5. الفيديو
      if (anime.videoPath != null && anime.videoPath!.isNotEmpty) {
        totalVideos++;
        if (await _fileExists(anime.videoPath)) {
          videoBytes += await _fileSize(anime.videoPath);
        } else {
          issues.add(HealthIssue(
            animeId: anime.id,
            animeTitle: anime.title,
            description: 'ملف الفيديو التذكاري محذوف',
            type: HealthIssueType.missingVideo,
          ));
          if (autoFix) {
            anime.videoPath = null;
            fixedCount++;
          }
        }
      }

      // 6. الشخصيات
      for (int j = 0; j < anime.characters.length; j++) {
        totalCharacters++;
        final char = anime.characters[j];
        final path = char['imagePath'] as String?;
        if (path != null && path.isNotEmpty) {
          if (await _fileExists(path)) {
            characterBytes += await _fileSize(path);
          } else {
            issues.add(HealthIssue(
              animeId: anime.id,
              animeTitle: anime.title,
              description: 'صورة الشخصية "${char['name'] ?? ''}" محذوفة',
              type: HealthIssueType.missingCharacterImage,
            ));
            if (autoFix) {
              anime.characters[j]['imagePath'] = null;
              fixedCount++;
            }
          }
        }
      }

      // 7. المشاهد
      for (int k = 0; k < anime.scenes.length; k++) {
        totalScenes++;
        final scene = anime.scenes[k];
        final path = scene['imagePath'] as String?;
        if (path != null && path.isNotEmpty) {
          if (await _fileExists(path)) {
            sceneBytes += await _fileSize(path);
          } else {
            issues.add(HealthIssue(
              animeId: anime.id,
              animeTitle: anime.title,
              description: 'صورة مشهد محذوفة',
              type: HealthIssueType.missingSceneImage,
            ));
            if (autoFix) {
              anime.scenes[k]['imagePath'] = null;
              fixedCount++;
            }
          }
        }
      }
    }

    // كشف المكررات الفعلية
    titleCount.forEach((title, count) {
      if (count > 1) {
        issues.add(HealthIssue(
          animeId: '',
          animeTitle: title,
          description: 'الاسم مكرر $count مرة في المكتبة',
          type: HealthIssueType.duplicate,
        ));
      }
    });

    // حساب حجم الذكريات
    try {
      final dir = await getApplicationDocumentsDirectory();
      final memDir = Directory('${dir.path}/anime_memory_photos');
      if (await memDir.exists()) {
        await for (final entity in memDir.list()) {
          if (entity is File) {
            memoryBytes += await entity.length();
          }
        }
      }
    } catch (_) {}

    if (autoFix && fixedCount > 0) {
      await _storage.saveAnimes(animes);
    }

    // حساب صحة المكتبة
    int score = 100;
    for (final issue in issues) {
      score -= issue.type.severity * 2;
    }
    if (animes.isEmpty) score = 100;
    score = score.clamp(0, 100);

    return DataHealthReport(
      totalAnimes: animes.length,
      totalCharacters: totalCharacters,
      totalScenes: totalScenes,
      totalVideos: totalVideos,
      coverBytes: coverBytes,
      videoBytes: videoBytes,
      characterBytes: characterBytes,
      sceneBytes: sceneBytes,
      memoryBytes: memoryBytes,
      issues: issues,
      fixedCount: fixedCount,
      healthScore: score,
    );
  }
}
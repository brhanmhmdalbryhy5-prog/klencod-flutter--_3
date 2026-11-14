import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

class BatchCompressResult {
  final int compressed;
  final int skipped;
  final int failed;
  final int savedBytes;

  BatchCompressResult({
    required this.compressed,
    required this.skipped,
    required this.failed,
    required this.savedBytes,
  });

  String get savedFormatted => _formatBytes(savedBytes);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class VideoCompressionService {
  static final VideoCompressionService _instance = VideoCompressionService._internal();
  factory VideoCompressionService() => _instance;
  VideoCompressionService._internal();

  bool _isCompressing = false;
  bool get isCompressing => _isCompressing;

  /// يضغط ملف فيديو ويعيد الملف المضغوط، أو null إذا فشل الضغط
  Future<File?> compressVideo(
    File source, {
    VideoQuality quality = VideoQuality.MediumQuality,
    void Function(double progress)? onProgress,
  }) async {
    if (_isCompressing) return null;
    _isCompressing = true;

    try {
      if (!await source.exists()) return null;

      final originalSize = await source.length();
      // لا نضغط الملفات الصغيرة (< 1MB)
      if (originalSize < 1024 * 1024) return source;

      final subscription = VideoCompress.compressProgress$.subscribe((progress) {
        if (onProgress != null) onProgress(progress / 100.0);
      });

      try {
        final info = await VideoCompress.compressVideo(
          source.path,
          quality: quality,
          deleteOrigin: false,
          includeAudio: true,
        );

        if (info?.file == null) return null;
        final compressed = info!.file!;
        if (!await compressed.exists()) return null;

        final compressedSize = await compressed.length();
        // إذا كان المضغوط أكبر من الأصلي (نادراً)، نحتفظ بالأصلي
        if (compressedSize >= originalSize) {
          try { await compressed.delete(); } catch (_) {}
          return source;
        }

        return compressed;
      } finally {
        await subscription.unsubscribe();
        await VideoCompress.deleteAllCache();
      }
    } catch (e) {
      return null;
    } finally {
      _isCompressing = false;
    }
  }

  /// يحجم كل فيديوهات المكتبة (للاستخدام الجماعي)
  Future<BatchCompressResult> compressAllVideos({
    required List<dynamic> animes, // List<Anime>
    required Future<void> Function() onSave,
    required void Function(int current, int total, String title) onProgress,
  }) async {
    int compressed = 0;
    int skipped = 0;
    int failed = 0;
    int savedBytes = 0;

    final videosToCompress = animes
        .where((a) => a.videoPath != null && a.videoPath.toString().isNotEmpty)
        .toList();

    if (videosToCompress.isEmpty) {
      return BatchCompressResult(compressed: 0, skipped: 0, failed: 0, savedBytes: 0);
    }

    for (int i = 0; i < videosToCompress.length; i++) {
      final anime = videosToCompress[i];
      final videoPath = anime.videoPath as String;
      final file = File(videoPath);
      if (!await file.exists()) continue;

      onProgress(i + 1, videosToCompress.length, anime.title);

      try {
        final originalSize = await file.length();
        final compressed = await compressVideo(file);

        if (compressed == null || compressed.path == file.path) {
          skipped++;
          continue;
        }

        final newSize = await compressed.length();
        if (newSize >= originalSize) {
          skipped++;
          continue;
        }

        // ننسخ المضغوط إلى مجلد التطبيق ثم نحذف الأصلي
        final directory = await getApplicationDocumentsDirectory();
        final folder = Directory('${directory.path}/anime_videos');
        if (!await folder.exists()) await folder.create(recursive: true);
        final newPath = '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.mp4';
        await compressed.copy(newPath);

        try { await file.delete(); } catch (_) {}
        try { await compressed.delete(); } catch (_) {}

        anime.videoPath = newPath;
        await onSave();
        savedBytes += (originalSize - newSize);
        compressed++;
      } catch (e) {
        failed++;
      }
    }

    return BatchCompressResult(
      compressed: compressed,
      skipped: skipped,
      failed: failed,
      savedBytes: savedBytes,
    );
  }

  Future<String> getFileSize(File file) async {
    try {
      if (!await file.exists()) return '0 B';
      return BatchCompressResult._formatBytes(await file.length());
    } catch (_) {
      return '0 B';
    }
  }
}
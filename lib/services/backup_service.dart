import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart' as ziplib;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime.dart';
import 'storage_service.dart';

class BackupService {
  static const String characterPrefix = 'anime_character_image_';

  // ══════════════════════════════════════════════════════════════
  // إنشاء نسخة احتياطية كاملة (مع فيديو، يدعم 2GB+)
  // ══════════════════════════════════════════════════════════════
  Future<String> createBackup() async {
    final tempDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final tempZipPath = '${tempDir.path}/backup_$ts.zip';
    final tempMetaFile = File('${tempDir.path}/metadata_$ts.json');
    final tempAnimeFile = File('${tempDir.path}/animes_$ts.json');

    try {
      final animes = await StorageService().loadAnimes();
      final prefs = await SharedPreferences.getInstance();

      // ✅ ZipFileEncoder يكتب مباشرة على القرص — لا RAM
      final encoder = ziplib.ZipFileEncoder();
      encoder.create(tempZipPath);

      final coverAssets = <String, String>{};
      final characterAssets = <String, String>{};
      final videoAssets = <String, String>{};
      final addedNames = <String>{};

      Future<void> addFile(File f, String archiveName) async {
        if (addedNames.contains(archiveName)) return;
        addedNames.add(archiveName);
        await encoder.addFile(f, archiveName);
      }

      final animeJson = <Map<String, dynamic>>[];

      for (var i = 0; i < animes.length; i++) {
        final anime = animes[i];
        final item = anime.toJson();

        // غلاف
        final path = anime.imagePath;
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            final asset = 'covers/cover_$i.${_extension(path)}';
            await addFile(file, asset);
            coverAssets[anime.id] = asset;
            item['imagePath'] = 'backup://$asset';
          } else {
            item['imagePath'] = null;
          }
        }

        // فيديو
        final videoPath = anime.videoPath;
        if (videoPath != null && videoPath.isNotEmpty) {
          final file = File(videoPath);
          if (await file.exists()) {
            final asset = 'videos/video_$i.${_extension(videoPath)}';
            await addFile(file, asset);
            videoAssets[anime.id] = asset;
            item['videoPath'] = 'backup://$asset';
          } else {
            item['videoPath'] = null;
          }
        }

        animeJson.add(item);
      }

      // صور شخصيات SharedPreferences
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(characterPrefix)) continue;
        final path = prefs.getString(key);
        if (path == null || path.isEmpty) continue;
        final file = File(path);
        if (!await file.exists()) continue;
        final asset = 'characters/${Uri.encodeComponent(key)}.${_extension(path)}';
        await addFile(file, asset);
        characterAssets[key] = asset;
      }

      // صور الذكريات
      final appDir = await getApplicationDocumentsDirectory();
      final memoriesDir = Directory('${appDir.path}/anime_memory_photos');
      if (await memoriesDir.exists()) {
        await for (final entity in memoriesDir.list()) {
          if (entity is! File) continue;
          final name = entity.uri.pathSegments.last;
          await addFile(entity, 'memories/${Uri.encodeComponent(name)}');
        }
      }

      // كتابة metadata + animes كملفات مؤقتة ثم إضافتها
      final metadata = {
        'format': 'anime_memory_backup',
        'version': 4,
        'createdAt': DateTime.now().toIso8601String(),
        'coverAssets': coverAssets,
        'characterAssets': characterAssets,
        'videoAssets': videoAssets,
      };
      await tempMetaFile.writeAsString(jsonEncode(metadata));
      await tempAnimeFile.writeAsString(jsonEncode(animeJson));
      await encoder.addFile(tempMetaFile, 'metadata.json');
      await encoder.addFile(tempAnimeFile, 'animes.json');

      await encoder.close();

      // تنظيف مؤقت
      try { await tempMetaFile.delete(); } catch (_) {}
      try { await tempAnimeFile.delete(); } catch (_) {}

      // حفظ الملف النهائي
      final saveResult = await _saveLargeFileToDisk(
        tempZipPath,
        'anime_memory_backup_$ts.zip',
      );
      try { await File(tempZipPath).delete(); } catch (_) {}
      return saveResult;
    } catch (e) {
      try { await tempMetaFile.delete(); } catch (_) {}
      try { await tempAnimeFile.delete(); } catch (_) {}
      try { await File(tempZipPath).delete(); } catch (_) {}
      return 'فشل إنشاء النسخة الاحتياطية: $e';
    }
  }

  // ══════════════════════════════════════════════════════════════
  // استعادة نسخة (Streaming — يدعم 2GB+)
  // ══════════════════════════════════════════════════════════════
  Future<String> restoreBackup() async {
    final createdFiles = <File>[];

    try {
      final selection = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختر نسخة ذاكرة الأوتاكو',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: false,
        allowMultiple: false,
      );
      if (selection == null || selection.files.isEmpty) {
        return 'تم إلغاء الاستعادة.';
      }

      final sourcePath = selection.files.single.path;
      if (sourcePath == null) return 'تعذر الوصول إلى الملف.';
      if (!await File(sourcePath).exists()) return 'الملف غير موجود.';

      // ✅ Streaming decode — لا يحمّل ZIP كاملاً في RAM
      final inputStream = ziplib.InputFileStream(sourcePath);
      final archive = ziplib.ZipDecoder().decodeStream(inputStream);

      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory('${appDir.path}/anime_images');
      final videosDir = Directory('${appDir.path}/anime_videos');
      final charsDir = Directory('${appDir.path}/anime_characters');
      final memoriesDir = Directory('${appDir.path}/anime_memory_photos');

      await coversDir.create(recursive: true);
      await videosDir.create(recursive: true);
      await charsDir.create(recursive: true);
      await memoriesDir.create(recursive: true);

      final restoredPaths = <String, String>{};
      Map<String, dynamic>? metadataDecoded;
      List<dynamic>? animeDecoded;
      final ts = DateTime.now().millisecondsSinceEpoch;

      // ✅ المرور على كل ملف بشكل stream
      for (final file in archive) {
        if (!file.isFile) continue;
        final name = file.name.replaceAll('\\', '/');

        // ملفات صغيرة — نقرأها بالكامل
        if (name == 'metadata.json' || name == 'animes.json') {
          final bytes = await file.readBytes();
          if (bytes == null) continue;
          if (name == 'metadata.json') {
            metadataDecoded = jsonDecode(utf8.decode(bytes));
          } else {
            animeDecoded = jsonDecode(utf8.decode(bytes));
          }
          continue;
        }

        // ملفات كبيرة (فيديوهات، صور) — stream مباشر على القرص
        String? targetPath;
        if (name.startsWith('covers/')) {
          targetPath = '${coversDir.path}/restored_${ts}_${_sanitize(name.split('/').last)}';
        } else if (name.startsWith('videos/')) {
          targetPath = '${videosDir.path}/restored_${ts}_${_sanitize(name.split('/').last)}';
        } else if (name.startsWith('characters/')) {
          targetPath = '${charsDir.path}/restored_${ts}_${_sanitize(name.split('/').last)}';
        } else if (name.startsWith('memories/')) {
          final decodedName = Uri.decodeComponent(name.split('/').last);
          targetPath = '${memoriesDir.path}/restored_${ts}_$decodedName';
        }

        if (targetPath != null) {
          final outputStream = ziplib.OutputFileStream(targetPath);
          await file.writeContent(outputStream);
          await outputStream.close();
          restoredPaths[name] = targetPath;
          createdFiles.add(File(targetPath));
        }
      }

      inputStream.close();

      if (metadataDecoded == null || animeDecoded == null) {
        await _cleanup(createdFiles);
        return 'النسخة غير مكتملة (metadata أو animes مفقود).';
      }

      final animes = animeDecoded
          .map((e) => Anime.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final coverAssets = Map<String, dynamic>.from(metadataDecoded['coverAssets'] ?? {});
      final characterAssets = Map<String, dynamic>.from(metadataDecoded['characterAssets'] ?? {});
      final videoAssets = Map<String, dynamic>.from(metadataDecoded['videoAssets'] ?? {});

      // ربط الصور والفيديوهات
      for (final anime in animes) {
        final c = coverAssets[anime.id];
        anime.imagePath = c is String ? restoredPaths[c] : null;
        final v = videoAssets[anime.id];
        anime.videoPath = v is String ? restoredPaths[v] : null;
      }

      // حفظ البيانات
      final saved = await StorageService().saveAnimes(animes);
      if (!saved) {
        await _cleanup(createdFiles);
        return 'تعذر حفظ بيانات الأنميات.';
      }

      // استعادة صور شخصيات SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(characterPrefix)) await prefs.remove(key);
      }
      for (final entry in characterAssets.entries) {
        final p = restoredPaths[entry.value as String];
        if (p != null) await prefs.setString(entry.key, p);
      }

      return '✅ تمت استعادة جميع البيانات (بما فيها الفيديوهات) بنجاح.';
    } catch (e) {
      await _cleanup(createdFiles);
      return 'فشلت الاستعادة: $e';
    }
  }

  // ══════════════════════════════════════════════════════════════
  // حفظ ملف كبير على القرص (يتجنب MethodChannel)
  // ══════════════════════════════════════════════════════════════
  Future<String> _saveLargeFileToDisk(String tempPath, String fileName) async {
    // 1. Downloads (iOS/macOS/Windows/Linux)
    try {
      final dir = await getDownloadsDirectory();
      if (dir != null) {
        final target = '${dir.path}/$fileName';
        await File(tempPath).copy(target);
        return '✅ تم حفظ النسخة في:\n$target';
      }
    } catch (_) {}

    // 2. External storage (Android — المجلد الخاص بالتطبيق)
    try {
      final dir = await getExternalStorageDirectory();
      if (dir != null) {
        final folder = Directory('${dir.path}/backups');
        await folder.create(recursive: true);
        final target = '${folder.path}/$fileName';
        await File(tempPath).copy(target);
        return '✅ تم حفظ النسخة في:\n$target';
      }
    } catch (_) {}

    // 3. FilePicker (للملفات الصغيرة فقط)
    try {
      final bytes = await File(tempPath).readAsBytes();
      final output = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ النسخة الاحتياطية',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: bytes,
      );
      if (output == null) return 'تم إلغاء الحفظ.';
      return '✅ تم حفظ النسخة.';
    } catch (e) {
      return '❌ تعذر الحفظ: $e';
    }
  }

  Future<void> _cleanup(List<File> files) async {
    for (final f in files) {
      try { if (await f.exists()) await f.delete(); } catch (_) {}
    }
  }

  String _extension(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return 'bin';
    final ext = name.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,8}$').hasMatch(ext) ? ext : 'bin';
  }

  String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}
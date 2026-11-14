import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart' as ziplib;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime.dart';

class BackupService {
  static const String animeKey = 'anime_memory_list';
  static const String characterPrefix = 'anime_character_image_';

  Future<String> createBackup() async {
    final tempDir = await getTemporaryDirectory();
    final tempZipPath = '${tempDir.path}/backup_${DateTime.now().millisecondsSinceEpoch}.zip';

    try {
      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(prefs.getString(animeKey) ?? '[]');
      if (decoded is! List) return 'تعذر إنشاء النسخة: بيانات الأنميات غير صالحة.';

      final animes = decoded
          .map((item) => Anime.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      // ✅ ZipFileEncoder يكتب مباشرة في ملف (لا RAM)
      final encoder = ziplib.ZipFileEncoder();
      encoder.create(tempZipPath);

      final coverAssets = <String, String>{};
      final characterAssets = <String, String>{};
      final videoAssets = <String, String>{};
      final addedNames = <String>{};

      void addFileIfNeeded(File file, String archiveName) {
        if (addedNames.contains(archiveName)) return;
        addedNames.add(archiveName);
        encoder.addFile(file, archiveName);
      }

      final animeJson = <Map<String, dynamic>>[];

      for (var i = 0; i < animes.length; i++) {
        final anime = animes[i];
        final item = anime.toJson();

        // 1. الغلاف
        final path = anime.imagePath;
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            final ext = _extension(path);
            final asset = 'covers/cover_$i.$ext';
            addFileIfNeeded(file, asset);
            coverAssets[anime.id] = asset;
            item['imagePath'] = 'backup://$asset';
          } else {
            item['imagePath'] = null;
          }
        }

        // 2. الفيديو
        final videoPath = anime.videoPath;
        if (videoPath != null && videoPath.isNotEmpty) {
          final file = File(videoPath);
          if (await file.exists()) {
            final ext = _extension(videoPath);
            final asset = 'videos/video_$i.$ext';
            addFileIfNeeded(file, asset);
            videoAssets[anime.id] = asset;
            item['videoPath'] = 'backup://$asset';
          } else {
            item['videoPath'] = null;
          }
        }

        animeJson.add(item);
      }

      // 3. صور الشخصيات
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(characterPrefix)) continue;
        final path = prefs.getString(key);
        if (path == null || path.isEmpty) continue;
        final file = File(path);
        if (!await file.exists()) continue;
        final ext = _extension(path);
        final asset = 'characters/${Uri.encodeComponent(key)}.$ext';
        addFileIfNeeded(file, asset);
        characterAssets[key] = asset;
      }

      // 4. صور الذكريات
      final appDirectory = await getApplicationDocumentsDirectory();
      final memoriesDirectory = Directory('${appDirectory.path}/anime_memory_photos');
      if (await memoriesDirectory.exists()) {
        await for (final entity in memoriesDirectory.list()) {
          if (entity is! File) continue;
          final name = entity.uri.pathSegments.last;
          final asset = 'memories/${Uri.encodeComponent(name)}';
          addFileIfNeeded(entity, asset);
        }
      }

      final metadata = <String, dynamic>{
        'format': 'anime_memory_backup',
        'version': 2,
        'createdAt': DateTime.now().toIso8601String(),
        'coverAssets': coverAssets,
        'characterAssets': characterAssets,
        'videoAssets': videoAssets,
      };

      final metadataBytes = utf8.encode(jsonEncode(metadata));
      final animeBytes = utf8.encode(jsonEncode(animeJson));

      encoder.addArchiveFile(ziplib.ArchiveFile('metadata.json', metadataBytes.length, metadataBytes));
      encoder.addArchiveFile(ziplib.ArchiveFile('animes.json', animeBytes.length, animeBytes));

      await encoder.close();

      // اطلب من المستخدم مكان الحفظ
      final output = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ نسخة ذاكرة الأوتاكو',
        fileName: 'anime_memory_backup_${DateTime.now().millisecondsSinceEpoch}.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (output == null) {
        try { await File(tempZipPath).delete(); } catch (_) {}
        return 'تم إلغاء حفظ النسخة الاحتياطية.';
      }

      // ✅ انسخ الملف المؤقت إلى وجهة المستخدم (بدون تحميله في RAM)
      String finalPath = output;
      try {
        if (output.startsWith('content://') || output.startsWith('file://')) {
          finalPath = Uri.parse(output).toFilePath();
        }
      } catch (_) {}

      try {
        await File(tempZipPath).copy(finalPath);
      } catch (e) {
        try { await File(tempZipPath).delete(); } catch (_) {}
        return 'تعذر حفظ ملف ZIP: $e';
      }

      try { await File(tempZipPath).delete(); } catch (_) {}

      return 'تمت عملية إنشاء النسخة (مع الفيديوهات). تحقق من مكان الحفظ.';
    } catch (e) {
      try { await File(tempZipPath).delete(); } catch (_) {}
      return 'فشل إنشاء النسخة الاحتياطية: $e';
    }
  }

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

      if (selection == null || selection.files.isEmpty) return 'تم إلغاء الاستعادة.';

      final sourcePath = selection.files.single.path;
      if (sourcePath == null) return 'تعذر الوصول إلى الملف المختار.';

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return 'الملف المختار غير موجود.';

      // ✅ الإصلاح الأساسي: قراءة ZIP بشكل stream (لا RAM)
      final inputStream = ziplib.InputFileStream(sourcePath);
      final archive = ziplib.ZipDecoder().decodeStream(inputStream);

      final appDirectory = await getApplicationDocumentsDirectory();
      // ✅ مجلدات دائمة (وليست مؤقتة)
      final videosDirectory = Directory('${appDirectory.path}/anime_videos');
      final coversDirectory = Directory('${appDirectory.path}/anime_images');
      final charactersDirectory = Directory('${appDirectory.path}/anime_characters');
      final memoriesDirectory = Directory('${appDirectory.path}/anime_memory_photos');

      await videosDirectory.create(recursive: true);
      await coversDirectory.create(recursive: true);
      await charactersDirectory.create(recursive: true);
      await memoriesDirectory.create(recursive: true);

      final restoredPaths = <String, String>{};
      Map<String, dynamic>? metadataDecoded;
      List<dynamic>? animeDecoded;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (final file in archive) {
        if (!file.isFile) continue;
        final name = file.name.replaceAll('\\', '/');

        if (name == 'metadata.json') {
          final outputStream = ziplib.OutputMemoryStream();
          file.writeContent(outputStream);
          metadataDecoded = jsonDecode(utf8.decode(outputStream.getBytes()));
          outputStream.close();
          continue;
        }

        if (name == 'animes.json') {
          final outputStream = ziplib.OutputMemoryStream();
          file.writeContent(outputStream);
          animeDecoded = jsonDecode(utf8.decode(outputStream.getBytes()));
          outputStream.close();
          continue;
        }

        String? targetPath;

        if (name.startsWith('covers/')) {
          targetPath = '${coversDirectory.path}/restored_${timestamp}_${_sanitize(name.split('/').last)}';
        } else if (name.startsWith('videos/')) {
          targetPath = '${videosDirectory.path}/restored_${timestamp}_${_sanitize(name.split('/').last)}';
        } else if (name.startsWith('characters/')) {
          targetPath = '${charactersDirectory.path}/restored_${timestamp}_${_sanitize(name.split('/').last)}';
        } else if (name.startsWith('memories/')) {
          final decodedName = Uri.decodeComponent(name.split('/').last);
          targetPath = '${memoriesDirectory.path}/restored_${timestamp}_$decodedName';
        }

        if (targetPath != null) {
          // ✅ كتابة مباشرة على القرص (لا RAM)
          final outputStream = ziplib.OutputFileStream(targetPath);
          file.writeContent(outputStream);
          outputStream.close();
          restoredPaths[name] = targetPath;
          createdFiles.add(File(targetPath));
        }
      }

      inputStream.close();

      if (metadataDecoded == null || animeDecoded == null) {
        await _cleanupFiles(createdFiles);
        return 'النسخة غير مكتملة (metadata أو animes مفقود).';
      }

      if (animeDecoded is! List) {
        await _cleanupFiles(createdFiles);
        return 'بيانات الأنميات غير صالحة.';
      }

      final animes = animeDecoded
          .map((item) => Anime.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      final coverAssets = Map<String, dynamic>.from(metadataDecoded['coverAssets'] ?? {});
      final characterAssets = Map<String, dynamic>.from(metadataDecoded['characterAssets'] ?? {});
      final videoAssets = Map<String, dynamic>.from(metadataDecoded['videoAssets'] ?? {});

      for (final anime in animes) {
        final coverAsset = coverAssets[anime.id];
        anime.imagePath = coverAsset is String ? restoredPaths[coverAsset] : null;

        final videoAsset = videoAssets[anime.id];
        anime.videoPath = videoAsset is String ? restoredPaths[videoAsset] : null;
      }

      final prefs = await SharedPreferences.getInstance();

      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(characterPrefix)) await prefs.remove(key);
      }
      for (final entry in characterAssets.entries) {
        final path = restoredPaths[entry.value as String];
        if (path != null) await prefs.setString(entry.key, path);
      }

      final encodedAnimes = jsonEncode(animes.map((a) => a.toJson()).toList());
      final saved = await prefs.setString(animeKey, encodedAnimes);
      if (!saved) {
        await _cleanupFiles(createdFiles);
        return 'تعذر حفظ بيانات الأنميات.';
      }

      return 'تمت استعادة جميع البيانات (بما فيها الفيديوهات) بنجاح.';
    } catch (e) {
      await _cleanupFiles(createdFiles);
      return 'فشلت الاستعادة: $e';
    }
  }

  Future<void> _cleanupFiles(List<File> files) async {
    for (final file in files) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  String _extension(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return 'bin';
    final ext = name.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,8}$').hasMatch(ext) ? ext : 'bin';
  }

  String _sanitize(String name) {
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }
}
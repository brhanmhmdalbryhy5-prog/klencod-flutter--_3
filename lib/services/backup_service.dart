import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart' as ziplib;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime.dart';
import 'storage_service.dart';
import 'notification_service.dart';

class BackupProgress {
  final int current;
  final int total;
  final String status;
  final bool isRestore;

  BackupProgress({
    required this.current,
    required this.total,
    required this.status,
    required this.isRestore,
  });

  double get percentage => total == 0 ? 0 : (current / total).clamp(0.0, 1.0);
}

class BackupService {
  static const String characterPrefix = 'anime_character_image_';
  final NotificationService _notif = NotificationService();

  final ValueNotifier<BackupProgress?> progress = ValueNotifier(null);

  int _processedItems = 0;
  int _totalItems = 1;
  DateTime _lastNotifyTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isRestore = false;

  void _resetProgress(int total, {bool isRestore = false}) {
    _processedItems = 0;
    _totalItems = total < 1 ? 1 : total;
    _lastNotifyTime = DateTime.fromMillisecondsSinceEpoch(0);
    _isRestore = isRestore;
    progress.value = BackupProgress(
      current: 0,
      total: _totalItems,
      status: 'تجهيز البيانات...',
      isRestore: isRestore,
    );
  }

  void _clearProgress() {
    progress.value = null;
  }

  Future<void> _maybeNotify(String currentItem) async {
    _processedItems++;
    final now = DateTime.now();
    if (now.difference(_lastNotifyTime).inMilliseconds > 200 ||
        _processedItems == _totalItems) {
      _lastNotifyTime = now;
      progress.value = BackupProgress(
        current: _processedItems,
        total: _totalItems,
        status: currentItem,
        isRestore: _isRestore,
      );
      try {
        await _notif.showProgress(
          title: _isRestore ? 'جاري الاستعادة...' : 'جاري الإنشاء...',
          body: currentItem,
          progress: _processedItems,
          total: _totalItems,
        );
      } catch (_) {}
    }
  }

  Future<String> createBackup() async {
    final tempDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final tempZipPath = '${tempDir.path}/backup_$ts.zip';
    final tempMetaFile = File('${tempDir.path}/metadata_$ts.json');
    final tempAnimeFile = File('${tempDir.path}/animes_$ts.json');

    try {
      _resetProgress(1, isRestore: false);
      try {
        await _notif.showProgress(
          title: 'جارٍ إنشاء النسخة الاحتياطية...',
          body: 'تجهيز البيانات...',
          progress: 0,
          total: 1,
        );
      } catch (_) {}

      final animes = await StorageService().loadAnimes();
      final prefs = await SharedPreferences.getInstance();

      _resetProgress(animes.length * 5 + prefs.getKeys().length + 5, isRestore: false);

      final encoder = ziplib.ZipFileEncoder();
      encoder.create(tempZipPath);

      final coverAssets = <String, String>{};
      final backCoverAssets = <String, String>{};
      final characterAssets = <String, String>{};
      final videoAssets = <String, String>{};
      final addedNames = <String>{};

      Future<void> addFile(File f, String archiveName, String label) async {
        if (addedNames.contains(archiveName)) return;
        addedNames.add(archiveName);
        await encoder.addFile(f, archiveName);
        await _maybeNotify(label);
      }

      final animeJson = <Map<String, dynamic>>[];

      for (var i = 0; i < animes.length; i++) {
        final anime = animes[i];
        final item = anime.toJson();

        final path = anime.imagePath;
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            final asset = 'covers/cover_$i.${_extension(path)}';
            await addFile(file, asset, '${anime.title} — الغلاف الأمامي');
            coverAssets[anime.id] = asset;
            item['imagePath'] = 'backup://$asset';
          } else {
            item['imagePath'] = null;
          }
        }

        final backPath = anime.backImagePath;
        if (backPath != null && backPath.isNotEmpty) {
          final file = File(backPath);
          if (await file.exists()) {
            final asset = 'covers/back_cover_$i.${_extension(backPath)}';
            await addFile(file, asset, '${anime.title} — الغلاف الخلفي');
            backCoverAssets[anime.id] = asset;
            item['backImagePath'] = 'backup://$asset';
          } else {
            item['backImagePath'] = null;
          }
        }

        final videoPath = anime.videoPath;
        if (videoPath != null && videoPath.isNotEmpty) {
          final file = File(videoPath);
          if (await file.exists()) {
            final asset = 'videos/video_$i.${_extension(videoPath)}';
            await addFile(file, asset, '${anime.title} — الفيديو');
            videoAssets[anime.id] = asset;
            item['videoPath'] = 'backup://$asset';
          } else {
            item['videoPath'] = null;
          }
        }

        final updatedCharacters = <Map<String, dynamic>>[];
        for (var j = 0; j < anime.characters.length; j++) {
          final char = Map<String, dynamic>.from(anime.characters[j]);
          final charPath = char['imagePath'] as String?;
          if (charPath != null && charPath.isNotEmpty) {
            final charFile = File(charPath);
            if (await charFile.exists()) {
              final asset = 'char_imgs/anime_${i}_char_$j.${_extension(charPath)}';
              await addFile(charFile, asset, '${anime.title} — شخصية');
              char['imagePath'] = 'backup://$asset';
            } else {
              char['imagePath'] = null;
            }
          }
          updatedCharacters.add(char);
        }
        item['characters'] = updatedCharacters;

        final updatedScenes = <Map<String, dynamic>>[];
        for (var k = 0; k < anime.scenes.length; k++) {
          final scene = Map<String, dynamic>.from(anime.scenes[k]);
          final scenePath = scene['imagePath'] as String?;
          if (scenePath != null && scenePath.isNotEmpty) {
            final sceneFile = File(scenePath);
            if (await sceneFile.exists()) {
              final asset = 'scenes/anime_${i}_scene_$k.${_extension(scenePath)}';
              await addFile(sceneFile, asset, '${anime.title} — مشهد');
              scene['imagePath'] = 'backup://$asset';
            } else {
              scene['imagePath'] = null;
            }
          }
          updatedScenes.add(scene);
        }
        item['scenes'] = updatedScenes;

        animeJson.add(item);
      }

      for (final key in prefs.getKeys()) {
        if (!key.startsWith(characterPrefix)) continue;
        final path = prefs.getString(key);
        if (path == null || path.isEmpty) continue;
        final file = File(path);
        if (!await file.exists()) continue;
        final asset = 'characters/${Uri.encodeComponent(key)}.${_extension(path)}';
        await addFile(file, asset, 'صورة شخصية محفوظة');
      }

      final appDir = await getApplicationDocumentsDirectory();
      final memoriesDir = Directory('${appDir.path}/anime_memory_photos');
      if (await memoriesDir.exists()) {
        await for (final entity in memoriesDir.list()) {
          if (entity is! File) continue;
          final name = entity.uri.pathSegments.last;
          await addFile(entity, 'memories/${Uri.encodeComponent(name)}', 'صورة ذكرى');
        }
      }

      final metadata = {
        'format': 'anime_memory_backup',
        'version': 7,
        'createdAt': DateTime.now().toIso8601String(),
        'coverAssets': coverAssets,
        'backCoverAssets': backCoverAssets,
        'characterAssets': characterAssets,
        'videoAssets': videoAssets,
      };
      await tempMetaFile.writeAsString(jsonEncode(metadata));
      await tempAnimeFile.writeAsString(jsonEncode(animeJson));
      await encoder.addFile(tempMetaFile, 'metadata.json');
      await encoder.addFile(tempAnimeFile, 'animes.json');

      await encoder.close();

      try { await tempMetaFile.delete(); } catch (_) {}
      try { await tempAnimeFile.delete(); } catch (_) {}

      progress.value = BackupProgress(
        current: _totalItems, total: _totalItems,
        status: 'جاري حفظ ملف ZIP...', isRestore: false,
      );

      final saveResult = await _saveLargeFileToDisk(
        tempZipPath, 'anime_memory_backup_$ts.zip',
      );
      try { await File(tempZipPath).delete(); } catch (_) {}

      try { await _notif.showCompleted(body: 'تم إنشاء النسخة وحفظها بنجاح.'); } catch (_) {}
      _clearProgress();
      return saveResult;
    } catch (e) {
      try { await tempMetaFile.delete(); } catch (_) {}
      try { await tempAnimeFile.delete(); } catch (_) {}
      try { await File(tempZipPath).delete(); } catch (_) {}
      try { await _notif.showFailed(body: 'حدث خطأ: $e'); } catch (_) {}
      _clearProgress();
      return 'فشل إنشاء النسخة الاحتياطية: $e';
    }
  }

  Future<String> restoreBackup() async {
    final createdFiles = <File>[];

    try {
      _resetProgress(1, isRestore: true);
      try {
        await _notif.showProgress(
          title: 'جارٍ استعادة النسخة...',
          body: 'اختيار الملف...',
          progress: 0,
          total: 1,
        );
      } catch (_) {}

      final selection = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختر نسخة ذاكرة الأوتاكو',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: false,
        allowMultiple: false,
      );
      if (selection == null || selection.files.isEmpty) {
        try { await _notif.cancelProgress(); } catch (_) {}
        _clearProgress();
        return 'تم إلغاء الاستعادة.';
      }

      final sourcePath = selection.files.single.path;
      if (sourcePath == null) { _clearProgress(); return 'تعذر الوصول إلى الملف.'; }
      if (!await File(sourcePath).exists()) { _clearProgress(); return 'الملف غير موجود.'; }

      final inputStream = ziplib.InputFileStream(sourcePath);
      final archive = ziplib.ZipDecoder().decodeStream(inputStream);

      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory('${appDir.path}/anime_images');
      final videosDir = Directory('${appDir.path}/anime_videos');
      final charsDir = Directory('${appDir.path}/anime_characters');
      final charImgsDir = Directory('${appDir.path}/character_images');
      final scenesDir = Directory('${appDir.path}/anime_scenes');
      final memoriesDir = Directory('${appDir.path}/anime_memory_photos');

      await coversDir.create(recursive: true);
      await videosDir.create(recursive: true);
      await charsDir.create(recursive: true);
      await charImgsDir.create(recursive: true);
      await scenesDir.create(recursive: true);
      await memoriesDir.create(recursive: true);

      final restoredPaths = <String, String>{};
      Map<String, dynamic>? metadataDecoded;
      List<dynamic>? animeDecoded;
      final ts = DateTime.now().millisecondsSinceEpoch;
      _resetProgress(archive.length, isRestore: true);

      for (final file in archive) {
        if (!file.isFile) continue;
        final name = file.name.replaceAll('\\', '/');

        if (name == 'metadata.json' || name == 'animes.json') {
          final content = file.content;
          Uint8List? bytes;
          if (content is Uint8List) {
            bytes = content;
          } else if (content is List<int>) {
            bytes = Uint8List.fromList(content);
          }
          if (bytes == null) continue;
          if (name == 'metadata.json') {
            metadataDecoded = jsonDecode(utf8.decode(bytes));
          } else {
            animeDecoded = jsonDecode(utf8.decode(bytes));
          }
          await _maybeNotify('قراءة البيانات الوصفية');
          continue;
        }

        String? targetPath;
        String label = 'استعادة ملف';

        if (name.startsWith('covers/')) {
          targetPath = '${coversDir.path}/restored_${ts}_${_sanitize(name.split('/').last)}';
          label = 'استعادة غلاف';
        } else if (name.startsWith('videos/')) {
          targetPath = '${videosDir.path}/restored_${ts}_${_sanitize(name.split('/').last)}';
          label = 'استعادة فيديو';
        } else if (name.startsWith('char_imgs/')) {
          targetPath = '${charImgsDir.path}/restored_${ts}_${_sanitize(name.split('/').last)}';
          label = 'استعادة صورة شخصية';
        } else if (name.startsWith('characters/')) {
          targetPath = '${charsDir.path}/restored_${ts}_${_sanitize(name.split('/').last)}';
          label = 'استعادة صورة شخصية';
        } else if (name.startsWith('scenes/')) {
          targetPath = '${scenesDir.path}/restored_${ts}_${_sanitize(name.split('/').last)}';
          label = 'استعادة مشهد';
        } else if (name.startsWith('memories/')) {
          final decodedName = Uri.decodeComponent(name.split('/').last);
          targetPath = '${memoriesDir.path}/restored_${ts}_$decodedName';
          label = 'استعادة صورة ذكرى';
        }

        if (targetPath != null) {
          final outputStream = ziplib.OutputFileStream(targetPath);
          file.writeContent(outputStream);
          await outputStream.close();
          restoredPaths[name] = targetPath;
          createdFiles.add(File(targetPath));
          await _maybeNotify(label);
        }
      }

      inputStream.close();

      if (metadataDecoded == null || animeDecoded == null) {
        await _cleanup(createdFiles);
        _clearProgress();
        try { await _notif.showFailed(body: 'النسخة غير مكتملة.'); } catch (_) {}
        return 'النسخة غير مكتملة.';
      }

      final animes = animeDecoded.map((e) => Anime.fromJson(Map<String, dynamic>.from(e))).toList();

      final coverAssets = Map<String, dynamic>.from(metadataDecoded['coverAssets'] ?? {});
      final backCoverAssets = Map<String, dynamic>.from(metadataDecoded['backCoverAssets'] ?? {});
      final characterAssets = Map<String, dynamic>.from(metadataDecoded['characterAssets'] ?? {});
      final videoAssets = Map<String, dynamic>.from(metadataDecoded['videoAssets'] ?? {});

      for (final anime in animes) {
        final c = coverAssets[anime.id];
        anime.imagePath = c is String ? restoredPaths[c] : null;
        final bc = backCoverAssets[anime.id];
        anime.backImagePath = bc is String ? restoredPaths[bc] : null;
        final v = videoAssets[anime.id];
        anime.videoPath = v is String ? restoredPaths[v] : null;

        for (final ch in anime.characters) {
          final chPath = ch['imagePath'] as String?;
          if (chPath != null && chPath.startsWith('backup://')) {
            final assetName = chPath.replaceFirst('backup://', '');
            ch['imagePath'] = restoredPaths[assetName];
          }
        }
        for (final scene in anime.scenes) {
          final sPath = scene['imagePath'] as String?;
          if (sPath != null && sPath.startsWith('backup://')) {
            final assetName = sPath.replaceFirst('backup://', '');
            scene['imagePath'] = restoredPaths[assetName];
          }
        }
      }

      final saved = await StorageService().saveAnimes(animes);
      if (!saved) {
        await _cleanup(createdFiles);
        _clearProgress();
        try { await _notif.showFailed(body: 'تعذر حفظ البيانات.'); } catch (_) {}
        return 'تعذر حفظ بيانات الأنميات.';
      }

      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(characterPrefix)) await prefs.remove(key);
      }
      for (final entry in characterAssets.entries) {
        final p = restoredPaths[entry.value as String];
        if (p != null) await prefs.setString(entry.key, p);
      }

      try { await _notif.showCompleted(body: 'تم استعادة ${animes.length} أنمي بنجاح.'); } catch (_) {}
      _clearProgress();
      return '✅ تمت استعادة جميع البيانات بنجاح.';
    } catch (e) {
      await _cleanup(createdFiles);
      _clearProgress();
      try { await _notif.showFailed(body: 'خطأ أثناء الاستعادة: $e'); } catch (_) {}
      return 'فشلت الاستعادة: $e';
    }
  }

  Future<String> createLiteBackup() async {
    final tempDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final tempZipPath = '${tempDir.path}/lite_backup_$ts.zip';
    final tempMetaFile = File('${tempDir.path}/lite_meta_$ts.json');
    final tempAnimeFile = File('${tempDir.path}/lite_animes_$ts.json');

    try {
      _resetProgress(1, isRestore: false);
      final animes = await StorageService().loadAnimes();
      _resetProgress(animes.length * 3 + 5, isRestore: false);

      final encoder = ziplib.ZipFileEncoder();
      encoder.create(tempZipPath);

      final coverAssets = <String, String>{};
      final backCoverAssets = <String, String>{};
      final addedNames = <String>{};

      Future<void> addFile(File f, String archiveName, String label) async {
        if (addedNames.contains(archiveName)) return;
        addedNames.add(archiveName);
        await encoder.addFile(f, archiveName);
        await _maybeNotify(label);
      }

      final animeJson = <Map<String, dynamic>>[];

      for (var i = 0; i < animes.length; i++) {
        final anime = animes[i];
        final item = anime.toJson();

        final path = anime.imagePath;
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            final asset = 'covers/cover_$i.${_extension(path)}';
            await addFile(file, asset, '${anime.title} — الغلاف');
            coverAssets[anime.id] = asset;
            item['imagePath'] = 'backup://$asset';
          } else { item['imagePath'] = null; }
        }

        final backPath = anime.backImagePath;
        if (backPath != null && backPath.isNotEmpty) {
          final file = File(backPath);
          if (await file.exists()) {
            final asset = 'covers/back_$i.${_extension(backPath)}';
            await addFile(file, asset, '${anime.title} — الغلاف الخلفي');
            backCoverAssets[anime.id] = asset;
            item['backImagePath'] = 'backup://$asset';
          } else { item['backImagePath'] = null; }
        }

        final updatedCharacters = <Map<String, dynamic>>[];
        for (var j = 0; j < anime.characters.length; j++) {
          final char = Map<String, dynamic>.from(anime.characters[j]);
          final charPath = char['imagePath'] as String?;
          if (charPath != null && charPath.isNotEmpty) {
            final charFile = File(charPath);
            if (await charFile.exists()) {
              final asset = 'char_imgs/anime_${i}_char_$j.${_extension(charPath)}';
              await addFile(charFile, asset, '${anime.title} — شخصية');
              char['imagePath'] = 'backup://$asset';
            } else { char['imagePath'] = null; }
          }
          updatedCharacters.add(char);
        }
        item['characters'] = updatedCharacters;

        item['videoPath'] = null;
        item['scenes'] = <Map<String, dynamic>>[];
        animeJson.add(item);
      }

      final metadata = {
        'format': 'anime_memory_lite_backup',
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'coverAssets': coverAssets,
        'backCoverAssets': backCoverAssets,
      };

      await tempMetaFile.writeAsString(jsonEncode(metadata));
      await tempAnimeFile.writeAsString(jsonEncode(animeJson));
      await encoder.addFile(tempMetaFile, 'metadata.json');
      await encoder.addFile(tempAnimeFile, 'animes.json');

      await encoder.close();

      try { await tempMetaFile.delete(); } catch (_) {}
      try { await tempAnimeFile.delete(); } catch (_) {}

      final saveResult = await _saveLargeFileToDisk(
        tempZipPath, 'anime_memory_lite_backup_$ts.zip',
      );
      try { await File(tempZipPath).delete(); } catch (_) {}

      _clearProgress();
      return saveResult;
    } catch (e) {
      try { await tempMetaFile.delete(); } catch (_) {}
      try { await tempAnimeFile.delete(); } catch (_) {}
      try { await File(tempZipPath).delete(); } catch (_) {}
      _clearProgress();
      return 'فشل إنشاء النسخة الخفيفة: $e';
    }
  }

  Future<String> restoreLiteBackup() async {
    final createdFiles = <File>[];

    try {
      _resetProgress(1, isRestore: true);

      final selection = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختر النسخة الخفيفة',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: false,
        allowMultiple: false,
      );
      if (selection == null || selection.files.isEmpty) {
        _clearProgress();
        return 'تم إلغاء الاستعادة.';
      }

      final sourcePath = selection.files.single.path;
      if (sourcePath == null) { _clearProgress(); return 'تعذر الوصول إلى الملف.'; }
      if (!await File(sourcePath).exists()) { _clearProgress(); return 'الملف غير موجود.'; }

      final inputStream = ziplib.InputFileStream(sourcePath);
      final archive = ziplib.ZipDecoder().decodeStream(inputStream);

      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory('${appDir.path}/anime_images');
      final charImgsDir = Directory('${appDir.path}/character_images');
      await coversDir.create(recursive: true);
      await charImgsDir.create(recursive: true);

      final restoredPaths = <String, String>{};
      Map<String, dynamic>? metadataDecoded;
      List<dynamic>? animeDecoded;
      final ts = DateTime.now().millisecondsSinceEpoch;
      _resetProgress(archive.length, isRestore: true);

      for (final file in archive) {
        if (!file.isFile) continue;
        final name = file.name.replaceAll('\\', '/');

        if (name == 'metadata.json' || name == 'animes.json') {
          final content = file.content;
          Uint8List? bytes;
          if (content is Uint8List) bytes = content;
          else if (content is List<int>) bytes = Uint8List.fromList(content);
          if (bytes == null) continue;
          if (name == 'metadata.json') {
            metadataDecoded = jsonDecode(utf8.decode(bytes));
          } else {
            animeDecoded = jsonDecode(utf8.decode(bytes));
          }
          await _maybeNotify('قراءة البيانات');
          continue;
        }

        String? targetPath;
        if (name.startsWith('covers/')) {
          targetPath = '${coversDir.path}/lite_restored_${ts}_${_sanitize(name.split('/').last)}';
        } else if (name.startsWith('char_imgs/')) {
          targetPath = '${charImgsDir.path}/lite_restored_${ts}_${_sanitize(name.split('/').last)}';
        }

        if (targetPath != null) {
          final outputStream = ziplib.OutputFileStream(targetPath);
          file.writeContent(outputStream);
          await outputStream.close();
          restoredPaths[name] = targetPath;
          createdFiles.add(File(targetPath));
          await _maybeNotify('استعادة صورة');
        }
      }

      inputStream.close();

      if (metadataDecoded == null || animeDecoded == null) {
        await _cleanup(createdFiles);
        _clearProgress();
        return 'النسخة غير مكتملة.';
      }

      final animes = animeDecoded.map((e) => Anime.fromJson(Map<String, dynamic>.from(e))).toList();
      final coverAssets = Map<String, dynamic>.from(metadataDecoded['coverAssets'] ?? {});
      final backCoverAssets = Map<String, dynamic>.from(metadataDecoded['backCoverAssets'] ?? {});

      for (final anime in animes) {
        final c = coverAssets[anime.id];
        if (c is String && restoredPaths[c] != null) anime.imagePath = restoredPaths[c];
        final bc = backCoverAssets[anime.id];
        if (bc is String && restoredPaths[bc] != null) anime.backImagePath = restoredPaths[bc];
        for (final ch in anime.characters) {
          final chPath = ch['imagePath'] as String?;
          if (chPath != null && chPath.startsWith('backup://')) {
            final assetName = chPath.replaceFirst('backup://', '');
            final restored = restoredPaths[assetName];
            if (restored != null) ch['imagePath'] = restored;
          }
        }
      }

      final saved = await StorageService().saveAnimes(animes);
      if (!saved) {
        await _cleanup(createdFiles);
        _clearProgress();
        return 'تعذر حفظ البيانات.';
      }

      _clearProgress();
      return '✅ تمت استعادة النسخة الخفيفة بنجاح.';
    } catch (e) {
      await _cleanup(createdFiles);
      _clearProgress();
      return 'فشلت الاستعادة: $e';
    }
  }

  Future<String> _saveLargeFileToDisk(String tempPath, String fileName) async {
    try {
      final xFile = XFile(tempPath, name: fileName);
      final result = await Share.shareXFiles(
        [xFile],
        subject: 'نسخة احتياطية - ذاكرة الأوتاكو',
        text: 'احفظ هذه النسخة في التنزيلات أو Google Drive.',
      );
      if (result.status == ShareResultStatus.dismissed) return 'تم إلغاء حفظ النسخة.';
      return '✅ تم إنشاء النسخة. تم فتح نافذة المشاركة لحفظها.';
    } catch (e) {
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
      } catch (e2) {
        return '❌ تعذر الحفظ: $e';
      }
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

  String _sanitize(String name) => name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart' as ziplib;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime.dart';
import 'storage_service.dart';

class BackupProgress {
  final int currentFile;
  final int totalFiles;
  final int bytesProcessed;
  final int totalBytes;
  final String currentFileName;
  final String stage;
  final bool isRestore;
  final DateTime startTime;
  final bool isDone;
  final String? resultPath;
  final String? error;
  final bool isCancelled;

  BackupProgress({
    required this.currentFile,
    required this.totalFiles,
    required this.bytesProcessed,
    required this.totalBytes,
    required this.currentFileName,
    required this.stage,
    required this.isRestore,
    required this.startTime,
    this.isDone = false,
    this.resultPath,
    this.error,
    this.isCancelled = false,
  });

  double get percentage => totalFiles == 0 ? 0 : (currentFile / totalFiles).clamp(0.0, 1.0);
  Duration get elapsed => DateTime.now().difference(startTime);
  double get speedMBps {
    final secs = elapsed.inMilliseconds / 1000.0;
    if (secs <= 0) return 0;
    return (bytesProcessed / 1024 / 1024) / secs;
  }
  Duration get eta {
    if (currentFile == 0 || totalFiles == 0) return Duration.zero;
    final perFileMs = elapsed.inMilliseconds / currentFile;
    final remaining = (totalFiles - currentFile) * perFileMs;
    return Duration(milliseconds: remaining.toInt());
  }

  BackupProgress copyWith({
    int? currentFile, int? totalFiles, int? bytesProcessed, int? totalBytes,
    String? currentFileName, String? stage, bool? isDone,
    String? resultPath, String? error, bool? isCancelled,
  }) {
    return BackupProgress(
      currentFile: currentFile ?? this.currentFile,
      totalFiles: totalFiles ?? this.totalFiles,
      bytesProcessed: bytesProcessed ?? this.bytesProcessed,
      totalBytes: totalBytes ?? this.totalBytes,
      currentFileName: currentFileName ?? this.currentFileName,
      stage: stage ?? this.stage,
      isRestore: isRestore,
      startTime: startTime,
      isDone: isDone ?? this.isDone,
      resultPath: resultPath ?? this.resultPath,
      error: error ?? this.error,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }
}

class BackupService {
  static const String characterPrefix = 'anime_character_image_';

  final ValueNotifier<BackupProgress?> progress = ValueNotifier(null);
  bool _cancelRequested = false;
  DateTime _startTime = DateTime.now();
  int _bytesProcessed = 0;
  int _totalBytes = 0;
  int _currentFile = 0;
  int _totalFiles = 0;
  String _stage = '';
  bool _isRestore = false;

  void cancel() => _cancelRequested = true;

  // ══════════════════════════════════════════════════════════════
  // 1️⃣ الإنشاء (يدعم 10GB عبر Streaming كامل)
  // ══════════════════════════════════════════════════════════════
  Future<String> createBackup() async {
    final tempDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final tempZipPath = '${tempDir.path}/backup_$ts.zip';

    try {
      _startTime = DateTime.now();
      _cancelRequested = false;
      _isRestore = false;
      _bytesProcessed = 0;
      _totalBytes = 0;
      _currentFile = 0;
      _totalFiles = 0;
      _stage = 'حساب الحجم...';

      progress.value = BackupProgress(
        currentFile: 0, totalFiles: 0, bytesProcessed: 0, totalBytes: 0,
        currentFileName: '', stage: _stage, isRestore: false,
        startTime: _startTime,
      );

      final animes = await StorageService().loadAnimes();
      final prefs = await SharedPreferences.getInstance();

      // احسب الحجم الإجمالي
      _totalBytes = 0;
      for (final anime in animes) {
        if (anime.imagePath != null && File(anime.imagePath!).existsSync()) {
          _totalBytes += await File(anime.imagePath!).length();
        }
        if (anime.backImagePath != null && File(anime.backImagePath!).existsSync()) {
          _totalBytes += await File(anime.backImagePath!).length();
        }
        if (anime.videoPath != null && File(anime.videoPath!).existsSync()) {
          _totalBytes += await File(anime.videoPath!).length();
        }
        for (final c in anime.characters) {
          final p = c['imagePath'] as String?;
          if (p != null && File(p).existsSync()) {
            _totalBytes += await File(p).length();
          }
        }
        for (final s in anime.scenes) {
          final p = s['imagePath'] as String?;
          if (p != null && File(p).existsSync()) {
            _totalBytes += await File(p).length();
          }
        }
      }

      _stage = 'تجهيز ZIP...';
      progress.value = progress.value!.copyWith(
        stage: _stage, totalBytes: _totalBytes,
      );

      // ZipFileEncoder يكتب مباشرة على القرص (Streaming - لا RAM)
      final encoder = ziplib.ZipFileEncoder();
      encoder.create(tempZipPath);

      final coverAssets = <String, String>{};
      final backCoverAssets = <String, String>{};
      final characterAssets = <String, String>{};
      final videoAssets = <String, String>{};
      final addedNames = <String>{};
      int animeCounter = 0;

      Future<void> addFile(File f, String archiveName, String label) async {
        if (_cancelRequested) return;
        if (addedNames.contains(archiveName)) return;
        addedNames.add(archiveName);
        await encoder.addFile(f, archiveName);
        _currentFile++;
        _bytesProcessed += await f.length();
        progress.value = progress.value!.copyWith(
          currentFile: _currentFile,
          currentFileName: label,
          bytesProcessed: _bytesProcessed,
        );
      }

      final animeJson = <Map<String, dynamic>>[];

      for (var i = 0; i < animes.length; i++) {
        if (_cancelRequested) throw Exception('cancelled');
        final anime = animes[i];
        final item = anime.toJson();

        // الغلاف الأمامي
        if (anime.imagePath != null &&
            anime.imagePath!.isNotEmpty &&
            File(anime.imagePath!).existsSync()) {
          final asset = 'covers/cover_${i}.${_extension(anime.imagePath!)}';
          await addFile(File(anime.imagePath!), asset, '${anime.title} — الغلاف');
          coverAssets[anime.id] = asset;
          item['imagePath'] = 'backup://$asset';
        } else {
          item['imagePath'] = null;
        }

        // الغلاف الخلفي
        if (anime.backImagePath != null &&
            anime.backImagePath!.isNotEmpty &&
            File(anime.backImagePath!).existsSync()) {
          final asset = 'covers/back_${i}.${_extension(anime.backImagePath!)}';
          await addFile(File(anime.backImagePath!), asset, '${anime.title} — الغلاف الخلفي');
          backCoverAssets[anime.id] = asset;
          item['backImagePath'] = 'backup://$asset';
        } else {
          item['backImagePath'] = null;
        }

        // الفيديو
        if (anime.videoPath != null &&
            anime.videoPath!.isNotEmpty &&
            File(anime.videoPath!).existsSync()) {
          final asset = 'videos/video_${i}.${_extension(anime.videoPath!)}';
          await addFile(File(anime.videoPath!), asset, '${anime.title} — فيديو');
          videoAssets[anime.id] = asset;
          item['videoPath'] = 'backup://$asset';
        } else {
          item['videoPath'] = null;
        }

        // الشخصيات
        final updatedChars = <Map<String, dynamic>>[];
        for (var j = 0; j < anime.characters.length; j++) {
          final char = Map<String, dynamic>.from(anime.characters[j]);
          final p = char['imagePath'] as String?;
          if (p != null && p.isNotEmpty && File(p).existsSync()) {
            final asset = 'char_imgs/anime_${i}_char_$j.${_extension(p)}';
            await addFile(File(p), asset, '${anime.title} — شخصية');
            char['imagePath'] = 'backup://$asset';
          } else {
            char['imagePath'] = null;
          }
          updatedChars.add(char);
        }
        item['characters'] = updatedChars;

        // المشاهد
        final updatedScenes = <Map<String, dynamic>>[];
        for (var k = 0; k < anime.scenes.length; k++) {
          final scene = Map<String, dynamic>.from(anime.scenes[k]);
          final p = scene['imagePath'] as String?;
          if (p != null && p.isNotEmpty && File(p).existsSync()) {
            final asset = 'scenes/anime_${i}_scene_$k.${_extension(p)}';
            await addFile(File(p), asset, '${anime.title} — مشهد');
            scene['imagePath'] = 'backup://$asset';
          } else {
            scene['imagePath'] = null;
          }
          updatedScenes.add(scene);
        }
        item['scenes'] = updatedScenes;

        animeJson.add(item);
        animeCounter++;
      }

      // صور SharedPreferences
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(characterPrefix)) continue;
        final path = prefs.getString(key);
        if (path == null || path.isEmpty) continue;
        final file = File(path);
        if (!await file.exists()) continue;
        final asset = 'characters/${Uri.encodeComponent(key)}.${_extension(path)}';
        await addFile(file, asset, 'صورة شخصية محفوظة');
        characterAssets[key] = asset;
      }

      // الذكريات
      final appDir = await getApplicationDocumentsDirectory();
      final memDir = Directory('${appDir.path}/anime_memory_photos');
      if (await memDir.exists()) {
        await for (final entity in memDir.list()) {
          if (entity is! File) continue;
          final name = entity.uri.pathSegments.last;
          final asset = 'memories/${Uri.encodeComponent(name)}';
          await addFile(entity, asset, 'صورة ذكرى');
        }
      }

      // JSON
      final metadata = {
        'format': 'anime_memory_backup',
        'version': 8,
        'createdAt': DateTime.now().toIso8601String(),
        'coverAssets': coverAssets,
        'backCoverAssets': backCoverAssets,
        'characterAssets': characterAssets,
        'videoAssets': videoAssets,
      };
      final metaFile = File('${tempDir.path}/metadata_$ts.json');
      await metaFile.writeAsString(jsonEncode(metadata));
      await encoder.addFile(metaFile, 'metadata.json');
      final animeFile = File('${tempDir.path}/animes_$ts.json');
      await animeFile.writeAsString(jsonEncode(animeJson));
      await encoder.addFile(animeFile, 'animes.json');

      await encoder.close();

      try { await metaFile.delete(); } catch (_) {}
      try { await animeFile.delete(); } catch (_) {}

      _stage = 'نسخ الملف النهائي...';
      progress.value = progress.value!.copyWith(stage: _stage);

      // ✅ الحل السحري: File.copy() - streams, لا RAM
      final finalPath = await _saveToDownloads(tempZipPath, 'anime_memory_backup_$ts.zip');

      try { await File(tempZipPath).delete(); } catch (_) {}

      if (finalPath == null) {
        throw Exception('تعذر حفظ الملف النهائي');
      }

      final finalSize = await File(finalPath).length();

      progress.value = BackupProgress(
        currentFile: _currentFile, totalFiles: _currentFile,
        bytesProcessed: _bytesProcessed, totalBytes: _totalBytes,
        currentFileName: '', stage: 'اكتمل',
        isRestore: false, startTime: _startTime,
        isDone: true, resultPath: finalPath,
      );

      return '✅ تم حفظ النسخة (${_formatBytes(finalSize)})\n\n$finalPath';
    } catch (e) {
      try { await File(tempZipPath).delete(); } catch (_) {}
      final msg = e.toString().contains('cancelled')
          ? 'تم إلغاء العملية.'
          : 'فشل الإنشاء: $e';
      progress.value = progress.value?.copyWith(isDone: true, error: msg);
      return msg;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // 2️⃣ الاستعادة
  // ══════════════════════════════════════════════════════════════
  Future<String> restoreBackup() async {
    final createdFiles = <File>[];

    try {
      final selection = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختر نسخة ذاكرة الأوتاكو',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: false,
      );
      if (selection == null || selection.files.isEmpty) {
        return 'تم إلغاء الاستعادة.';
      }

      final sourcePath = selection.files.single.path;
      if (sourcePath == null) return 'تعذر الوصول للملف.';
      if (!await File(sourcePath).exists()) return 'الملف غير موجود.';

      _startTime = DateTime.now();
      _cancelRequested = false;
      _isRestore = true;
      _bytesProcessed = 0;
      _currentFile = 0;
      _stage = 'فتح الملف...';

      progress.value = BackupProgress(
        currentFile: 0, totalFiles: 0,
        bytesProcessed: 0, totalBytes: 0,
        currentFileName: '', stage: _stage,
        isRestore: true, startTime: _startTime,
      );

      // decodeStream يقرأ من القرص - لا RAM
      final inputStream = ziplib.InputFileStream(sourcePath);
      final archive = ziplib.ZipDecoder().decodeStream(inputStream);

      _totalFiles = archive.length;
      _stage = 'الاستخراج...';

      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory('${appDir.path}/anime_images');
      final videosDir = Directory('${appDir.path}/anime_videos');
      final charsDir = Directory('${appDir.path}/anime_characters');
      final charImgsDir = Directory('${appDir.path}/character_images');
      final scenesDir = Directory('${appDir.path}/anime_scenes');
      final memDir = Directory('${appDir.path}/anime_memory_photos');
      await coversDir.create(recursive: true);
      await videosDir.create(recursive: true);
      await charsDir.create(recursive: true);
      await charImgsDir.create(recursive: true);
      await scenesDir.create(recursive: true);
      await memDir.create(recursive: true);

      final restoredPaths = <String, String>{};
      Map<String, dynamic>? metadata;
      List<dynamic>? animeList;
      final ts = DateTime.now().millisecondsSinceEpoch;

      for (final file in archive) {
        if (_cancelRequested) throw Exception('cancelled');
        if (!file.isFile) continue;
        final name = file.name.replaceAll('\\', '/');

        if (name == 'metadata.json' || name == 'animes.json') {
          final content = file.content;
          Uint8List? bytes;
          if (content is Uint8List) bytes = content;
          else if (content is List<int>) bytes = Uint8List.fromList(content);
          if (bytes != null) {
            if (name == 'metadata.json') {
              metadata = jsonDecode(utf8.decode(bytes));
            } else {
              animeList = jsonDecode(utf8.decode(bytes));
            }
          }
          _currentFile++;
          progress.value = progress.value!.copyWith(
            currentFile: _currentFile, currentFileName: name,
          );
          continue;
        }

        String? targetPath;
        String label = 'استعادة ملف';

        if (name.startsWith('covers/')) {
          targetPath = '${coversDir.path}/r_${ts}_${_sanitize(name.split('/').last)}';
          label = 'غلاف';
        } else if (name.startsWith('videos/')) {
          targetPath = '${videosDir.path}/r_${ts}_${_sanitize(name.split('/').last)}';
          label = 'فيديو';
        } else if (name.startsWith('char_imgs/')) {
          targetPath = '${charImgsDir.path}/r_${ts}_${_sanitize(name.split('/').last)}';
          label = 'شخصية';
        } else if (name.startsWith('characters/')) {
          targetPath = '${charsDir.path}/r_${ts}_${_sanitize(name.split('/').last)}';
          label = 'شخصية';
        } else if (name.startsWith('scenes/')) {
          targetPath = '${scenesDir.path}/r_${ts}_${_sanitize(name.split('/').last)}';
          label = 'مشهد';
        } else if (name.startsWith('memories/')) {
          targetPath = '${memDir.path}/r_${ts}_${_sanitize(name.split('/').last)}';
          label = 'ذكرى';
        }

        if (targetPath != null) {
          // OutputFileStream يكتب على القرص - لا RAM
          final outputStream = ziplib.OutputFileStream(targetPath);
          file.writeContent(outputStream);
          await outputStream.close();
          restoredPaths[name] = targetPath;
          createdFiles.add(File(targetPath));
          _currentFile++;
          _bytesProcessed += file.size;
          progress.value = progress.value!.copyWith(
            currentFile: _currentFile,
            currentFileName: label,
            bytesProcessed: _bytesProcessed,
          );
        }
      }

      inputStream.close();

      if (metadata == null || animeList == null) {
        await _cleanup(createdFiles);
        progress.value = progress.value?.copyWith(
            isDone: true, error: 'النسخة غير مكتملة.');
        return 'النسخة غير مكتملة.';
      }

      _stage = 'ربط البيانات...';
      progress.value = progress.value!.copyWith(stage: _stage);

      final animes = animeList.map((e) => Anime.fromJson(Map<String, dynamic>.from(e))).toList();
      final coverAssets = Map<String, dynamic>.from(metadata['coverAssets'] ?? {});
      final backCoverAssets = Map<String, dynamic>.from(metadata['backCoverAssets'] ?? {});
      final characterAssets = Map<String, dynamic>.from(metadata['characterAssets'] ?? {});
      final videoAssets = Map<String, dynamic>.from(metadata['videoAssets'] ?? {});

      for (final anime in animes) {
        final c = coverAssets[anime.id];
        if (c is String && restoredPaths.containsKey(c)) anime.imagePath = restoredPaths[c];
        final bc = backCoverAssets[anime.id];
        if (bc is String && restoredPaths.containsKey(bc)) anime.backImagePath = restoredPaths[bc];
        final v = videoAssets[anime.id];
        if (v is String && restoredPaths.containsKey(v)) anime.videoPath = restoredPaths[v];

        for (final ch in anime.characters) {
          final p = ch['imagePath'] as String?;
          if (p != null && p.startsWith('backup://')) {
            final k = p.replaceFirst('backup://', '');
            if (restoredPaths.containsKey(k)) ch['imagePath'] = restoredPaths[k];
          }
        }
        for (final sc in anime.scenes) {
          final p = sc['imagePath'] as String?;
          if (p != null && p.startsWith('backup://')) {
            final k = p.replaceFirst('backup://', '');
            if (restoredPaths.containsKey(k)) sc['imagePath'] = restoredPaths[k];
          }
        }
      }

      final saved = await StorageService().saveAnimes(animes);
      if (!saved) {
        await _cleanup(createdFiles);
        progress.value = progress.value?.copyWith(
            isDone: true, error: 'تعذر حفظ البيانات.');
        return 'تعذر حفظ البيانات.';
      }

      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(characterPrefix)) await prefs.remove(key);
      }
      for (final entry in characterAssets.entries) {
        final p = restoredPaths[entry.value as String];
        if (p != null) await prefs.setString(entry.key, p);
      }

      progress.value = BackupProgress(
        currentFile: _totalFiles, totalFiles: _totalFiles,
        bytesProcessed: _bytesProcessed, totalBytes: _bytesProcessed,
        currentFileName: '', stage: 'اكتمل',
        isRestore: true, startTime: _startTime,
        isDone: true, resultPath: null,
      );

      return '✅ تمت استعادة ${animes.length} أنمي بنجاح.';
    } catch (e) {
      await _cleanup(createdFiles);
      final msg = e.toString().contains('cancelled')
          ? 'تم إلغاء الاستعادة.'
          : 'فشلت الاستعادة: $e';
      progress.value = progress.value?.copyWith(isDone: true, error: msg);
      return msg;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // الحفظ الآمن عبر File.copy (يدعم 10GB+)
  // ══════════════════════════════════════════════════════════════
  Future<String?> _saveToDownloads(String tempPath, String fileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupFolder = Directory('${appDir.path}/backups');
      if (!await backupFolder.exists()) await backupFolder.create(recursive: true);
      
      final target = '${backupFolder.path}/$fileName';
      
      // ✅ File.copy() streams (يقرأ ويكتب 4MB في المرة - لا يحمّل 10GB في RAM)
      await File(tempPath).copy(target);
      
      return target;
    } catch (e) {
      // محاولة ثانية: Downloads
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          final folder = Directory('${downloadsDir.path}/AnimeMemoryBackup');
          if (!await folder.exists()) await folder.create(recursive: true);
          final target = '${folder.path}/$fileName';
          await File(tempPath).copy(target);
          return target;
        }
      } catch (_) {}
      return null;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
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
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' as ziplib;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime.dart';

class BackupService {
  static const String animeKey = 'anime_memory_list';
  static const String characterPrefix = 'anime_character_image_';

  Future<String> createBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(prefs.getString(animeKey) ?? '[]');

      if (decoded is! List) return 'تعذر إنشاء النسخة: بيانات الأنميات غير صالحة.';

      final animes = decoded.map((item) => Anime.fromJson(Map<String, dynamic>.from(item))).toList();

      final archive = ziplib.Archive();
      final coverAssets = <String, String>{};
      final characterAssets = <String, String>{};
      final videoAssets = <String, String>{}; // 🔥 للفيديوهات
      final addedAssets = <String>{};

      void addBytes(String name, List<int> bytes) {
        if (addedAssets.contains(name)) return;
        addedAssets.add(name);
        archive.addFile(ziplib.ArchiveFile(name, bytes.length, bytes));
      }

      final animeJson = <Map<String, dynamic>>[];

      for (var i = 0; i < animes.length; i++) {
        final anime = animes[i];
        final item = anime.toJson();
        
        // 1. الأغلفة
        final path = anime.imagePath;
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            final asset = 'covers/cover_$i.${_extension(path)}';
            addBytes(asset, await file.readAsBytes());
            coverAssets[anime.id] = asset;
            item['imagePath'] = 'backup://$asset';
          } else {
            item['imagePath'] = null;
          }
        }

        // 2. الفيديوهات
        final videoPath = anime.videoPath;
        if (videoPath != null && videoPath.isNotEmpty) {
          final file = File(videoPath);
          if (await file.exists()) {
            final asset = 'videos/video_$i.${_extension(videoPath)}';
            addBytes(asset, await file.readAsBytes());
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

        final asset = 'characters/${Uri.encodeComponent(key)}.${_extension(path)}';
        addBytes(asset, await file.readAsBytes());
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
          addBytes(asset, await entity.readAsBytes());
        }
      }

      final metadata = <String, dynamic>{
        'format': 'anime_memory_backup',
        'version': 2, // 🔥 تحديث الإصدار لدعم الفيديو
        'createdAt': DateTime.now().toIso8601String(),
        'coverAssets': coverAssets,
        'characterAssets': characterAssets,
        'videoAssets': videoAssets, // 🔥
      };

      final metadataBytes = utf8.encode(jsonEncode(metadata));
      final animeBytes = utf8.encode(jsonEncode(animeJson));

      archive.addFile(ziplib.ArchiveFile('metadata.json', metadataBytes.length, metadataBytes));
      archive.addFile(ziplib.ArchiveFile('animes.json', animeBytes.length, animeBytes));

      final zipBytes = ziplib.ZipEncoder().encode(archive);
      if (zipBytes == null || zipBytes.isEmpty) return 'تعذر إنشاء ملف النسخة الاحتياطية.';

      final output = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ نسخة ذاكرة الأوتاكو',
        fileName: 'anime_memory_backup_${DateTime.now().millisecondsSinceEpoch}.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: Uint8List.fromList(zipBytes),
      );

      if (output == null) return 'تم إلغاء حفظ النسخة الاحتياطية.';
      return 'تمت عملية إنشاء النسخة (مع الفيديوهات). تحقق من مكان الحفظ.';
    } catch (e) {
      return 'فشل إنشاء النسخة الاحتياطية: $e';
    }
  }

  Future<String> restoreBackup() async {
    Directory? restoreDirectory;
    final createdMemoryFiles = <File>[];
    var success = false;

    try {
      final selection = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختر نسخة ذاكرة الأوتاكو',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: false,
        allowMultiple: false,
      );

      if (selection == null || selection.files.isEmpty) return 'تم إلغاء الاستعادة.';

      final selectedFile = selection.files.single;
      Uint8List? bytes = selectedFile.bytes;

      if (selectedFile.path != null) {
        final source = File(selectedFile.path!);
        if (await source.exists()) bytes = await source.readAsBytes();
      }

      if (bytes == null || bytes.isEmpty) return 'تعذرت قراءة الملف.';

      final ziplib.Archive archive;
      try {
        archive = ziplib.ZipDecoder().decodeBytes(bytes);
      } catch (_) {
        return 'تعذر فتح ملف ZIP.';
      }

      final archiveFiles = <String, ziplib.ArchiveFile>{};
      for (final entry in archive) {
        if (!entry.isFile) continue;
        archiveFiles[entry.name.replaceAll('\\', '/')] = entry;
      }

      final metadataFile = archiveFiles['metadata.json'];
      final animesFile = archiveFiles['animes.json'];

      if (metadataFile == null || animesFile == null) return 'النسخة غير مكتملة.';

      final metadataDecoded = jsonDecode(utf8.decode(_entryBytes(metadataFile)));
      final animeDecoded = jsonDecode(utf8.decode(_entryBytes(animesFile)));

      if (animeDecoded is! List) return 'بيانات الأنميات غير صالحة.';

      final animes = animeDecoded.map((item) => Anime.fromJson(Map<String, dynamic>.from(item))).toList();

      final coverRaw = metadataDecoded['coverAssets'] ?? {};
      final characterRaw = metadataDecoded['characterAssets'] ?? {};
      final videoRaw = metadataDecoded['videoAssets'] ?? {}; // 🔥

      final coverAssets = Map<String, dynamic>.from(coverRaw);
      final characterAssets = Map<String, dynamic>.from(characterRaw);
      final videoAssets = Map<String, dynamic>.from(videoRaw);

      final appDirectory = await getApplicationDocumentsDirectory();
      restoreDirectory = Directory('${appDirectory.path}/anime_memory_restored_${DateTime.now().millisecondsSinceEpoch}');
      await restoreDirectory.create(recursive: true);

      final restoredPaths = <String, String>{};

      // استخراج الملفات
      for (final entry in archiveFiles.entries) {
        if (entry.key.startsWith('covers/') || entry.key.startsWith('characters/') || entry.key.startsWith('videos/')) {
          final parts = entry.key.split('/');
          if (parts.length != 2) continue;

          final targetDirectory = Directory('${restoreDirectory.path}/${parts[0]}');
          await targetDirectory.create(recursive: true);

          final target = File('${targetDirectory.path}/${parts[1]}');
          await target.writeAsBytes(_entryBytes(entry.value), flush: true);

          restoredPaths[entry.key] = target.path;
        }
      }

      // ربط الصور والفيديوهات المستعادة
      for (final anime in animes) {
        final coverAsset = coverAssets[anime.id];
        anime.imagePath = coverAsset is String ? restoredPaths[coverAsset] : null;

        final videoAsset = videoAssets[anime.id];
        anime.videoPath = videoAsset is String ? restoredPaths[videoAsset] : null;
      }

      final newCharacterPaths = <String, String>{};
      for (final entry in characterAssets.entries) {
        final path = restoredPaths[entry.value as String];
        if (path != null) newCharacterPaths[entry.key] = path;
      }

      // استعادة صور الذكريات
      final memoriesDirectory = Directory('${appDirectory.path}/anime_memory_photos');
      await memoriesDirectory.create(recursive: true);

      for (final entry in archiveFiles.entries) {
        if (!entry.key.startsWith('memories/')) continue;
        final name = Uri.decodeComponent(entry.key.split('/').last);
        final target = File('${memoriesDirectory.path}/restored_${DateTime.now().microsecondsSinceEpoch}_$name');
        await target.writeAsBytes(_entryBytes(entry.value), flush: true);
        createdMemoryFiles.add(target);
      }

      // حفظ البيانات
      final prefs = await SharedPreferences.getInstance();
      final encodedAnimes = jsonEncode(animes.map((anime) => anime.toJson()).toList());
      final saved = await prefs.setString(animeKey, encodedAnimes);
      if (!saved) throw Exception('تعذر حفظ بيانات الأنميات.');

      // حفظ صور الشخصيات
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(characterPrefix)) await prefs.remove(key);
      }
      for (final entry in newCharacterPaths.entries) {
        await prefs.setString(entry.key, entry.value);
      }

      success = true;
      return 'تمت استعادة جميع البيانات (بما فيها الفيديوهات) بنجاح.';
    } catch (e) {
      return 'فشلت الاستعادة: $e';
    } finally {
      if (!success && restoreDirectory != null) {
        try {
          if (await restoreDirectory.exists()) await restoreDirectory.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  List<int> _entryBytes(ziplib.ArchiveFile file) {
    final content = file.content;
    if (content is List<int>) return content;
    if (content is Uint8List) return content;
    throw const FormatException('محتوى ملف غير صالح.');
  }

  String _extension(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return 'bin';
    final ext = name.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,8}$').hasMatch(ext) ? ext : 'bin';
  }
}
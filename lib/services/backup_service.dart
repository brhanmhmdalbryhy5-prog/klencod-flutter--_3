
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

      if (decoded is! List) {
        return 'تعذر إنشاء النسخة: بيانات الأنميات غير صالحة.';
      }

      final animes = decoded.map((item) {
        if (item is! Map) {
          throw const FormatException('بيانات أنمي غير صالحة.');
        }
        return Anime.fromJson(Map<String, dynamic>.from(item));
      }).toList();

      final archive = ziplib.Archive();
      final coverAssets = <String, String>{};
      final characterAssets = <String, String>{};
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

        animeJson.add(item);
      }

      // صور الشخصيات المفضلة.
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(characterPrefix)) continue;

        final path = prefs.getString(key);
        if (path == null || path.isEmpty) continue;

        final file = File(path);
        if (!await file.exists()) continue;

        final asset =
            'characters/${Uri.encodeComponent(key)}.${_extension(path)}';

        addBytes(asset, await file.readAsBytes());
        characterAssets[key] = asset;
      }

      // صور معرض الذكريات.
      final appDirectory = await getApplicationDocumentsDirectory();
      final memoriesDirectory = Directory(
        '${appDirectory.path}/anime_memory_photos',
      );

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
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'coverAssets': coverAssets,
        'characterAssets': characterAssets,
      };

      final metadataBytes = utf8.encode(jsonEncode(metadata));
      final animeBytes = utf8.encode(jsonEncode(animeJson));

      archive.addFile(
        ziplib.ArchiveFile(
          'metadata.json',
          metadataBytes.length,
          metadataBytes,
        ),
      );
      archive.addFile(
        ziplib.ArchiveFile(
          'animes.json',
          animeBytes.length,
          animeBytes,
        ),
      );

      final zipBytes = ziplib.ZipEncoder().encode(archive);

      if (zipBytes == null || zipBytes.isEmpty) {
        return 'تعذر إنشاء ملف النسخة الاحتياطية.';
      }

      final output = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ نسخة ذاكرة الأوتاكو',
        fileName:
            'anime_memory_backup_${DateTime.now().millisecondsSinceEpoch}.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: Uint8List.fromList(zipBytes),
      );

      if (output == null) {
        return 'تم إلغاء حفظ النسخة الاحتياطية.';
      }

      return 'تمت عملية إنشاء النسخة. تحقق من المكان الذي اخترته لحفظ الملف.';
    } catch (e) {
      return 'فشل إنشاء النسخة الاحتياطية: $e';
    }
  }

  Future<String> restoreBackup() async {
    try {
      final selection = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختر نسخة ذاكرة الأوتاكو',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
        allowMultiple: false,
      );

      if (selection == null || selection.files.isEmpty) {
        return 'تم إلغاء الاستعادة.';
      }

      final bytes = selection.files.single.bytes;
      if (bytes == null || bytes.isEmpty) {
        return 'تعذر قراءة الملف. حاول اختيار النسخة مرة أخرى.';
      }

      final ziplib.Archive archive;
      try {
        archive = ziplib.ZipDecoder().decodeBytes(bytes);
      } catch (_) {
        return 'الملف ليس أرشيف ZIP صالحًا.';
      }

      final files = <String, List<int>>{};

      for (final entry in archive) {
        if (!entry.isFile) continue;

        final name = entry.name;
        final normalized = name.replaceAll('\\', '/');
        final parts = normalized.split('/');

        // رفض المسارات المطلقة وأي محاولة للخروج من مجلد النسخة.
        if (normalized.startsWith('/') ||
            normalized.startsWith('~') ||
            RegExp(r'^[a-zA-Z]:').hasMatch(normalized) ||
            parts.any((part) => part == '..' || part == '.' || part.isEmpty)) {
          return 'النسخة تحتوي على مسار غير آمن.';
        }

        files[normalized] = List<int>.from(entry.content as List<int>);
      }

      if (!files.containsKey('metadata.json') ||
          !files.containsKey('animes.json')) {
        return 'النسخة غير مكتملة أو لا تخص هذا التطبيق.';
      }

      final dynamic metadataDecoded = jsonDecode(
        utf8.decode(files['metadata.json']!),
      );

      if (metadataDecoded is! Map ||
          metadataDecoded['format'] != 'anime_memory_backup' ||
          metadataDecoded['version'] != 1) {
        return 'صيغة النسخة الاحتياطية غير مدعومة.';
      }

      final dynamic animeDecoded = jsonDecode(
        utf8.decode(files['animes.json']!),
      );

      if (animeDecoded is! List) {
        return 'بيانات الأنميات داخل النسخة غير صالحة.';
      }

      final animes = animeDecoded.map((item) {
        if (item is! Map) {
          throw const FormatException('بيانات أنمي غير صالحة.');
        }
        return Anime.fromJson(Map<String, dynamic>.from(item));
      }).toList();

      final coverRaw = metadataDecoded['coverAssets'];
      final characterRaw = metadataDecoded['characterAssets'];

      if (coverRaw != null && coverRaw is! Map) {
        return 'بيانات صور الأغلفة غير صالحة.';
      }
      if (characterRaw != null && characterRaw is! Map) {
        return 'بيانات صور الشخصيات غير صالحة.';
      }

      final coverAssets = Map<String, dynamic>.from(coverRaw ?? {});
      final characterAssets = Map<String, dynamic>.from(characterRaw ?? {});

      for (final asset in coverAssets.values) {
        if (asset is! String || !files.containsKey(asset)) {
          return 'النسخة تفتقد إحدى صور الأغلفة.';
        }
      }

      for (final entry in characterAssets.entries) {
        if (!entry.key.startsWith(characterPrefix) ||
            entry.value is! String ||
            !files.containsKey(entry.value)) {
          return 'بيانات إحدى صور الشخصيات غير صالحة.';
        }
      }

      // تجهيز الصور في مجلد جديد، دون حذف الصور الحالية.
      final appDirectory = await getApplicationDocumentsDirectory();
      final restoreDirectory = Directory(
        '${appDirectory.path}/anime_memory_restored_'
        '${DateTime.now().millisecondsSinceEpoch}',
      );
      await restoreDirectory.create(recursive: true);

      final restoredPaths = <String, String>{};

      for (final entry in files.entries) {
        if (!entry.key.startsWith('covers/') &&
            !entry.key.startsWith('characters/')) {
          continue;
        }

        final parts = entry.key.split('/');
        if (parts.length != 2) continue;

        final folder = parts[0];
        final filename = parts[1];

        // أسماء الملفات التي أنشأها التطبيق لا تحتوي على فواصل.
        if (filename.isEmpty ||
            filename.contains('/') ||
            filename.contains('\\') ||
            filename == '.' ||
            filename == '..') {
          return 'تحتوي النسخة على اسم صورة غير صالح.';
        }

        final targetDirectory = Directory(
          '${restoreDirectory.path}/$folder',
        );
        await targetDirectory.create(recursive: true);

        final target = File('${targetDirectory.path}/$filename');
        await target.writeAsBytes(entry.value, flush: true);
        restoredPaths[entry.key] = target.path;
      }

      // استعادة مسارات الأغلفة.
      for (final anime in animes) {
        final asset = coverAssets[anime.id];

        if (asset is String) {
          final path = restoredPaths[asset];
          if (path == null) {
            return 'تعذر تجهيز إحدى صور الأغلفة.';
          }
          anime.imagePath = path;
        } else {
          anime.imagePath = null;
        }
      }

      // تجهيز مسارات الشخصيات قبل تحديث الإعدادات.
      final newCharacterPaths = <String, String>{};

      for (final entry in characterAssets.entries) {
        final asset = entry.value as String;
        final path = restoredPaths[asset];

        if (path == null) {
          return 'تعذر تجهيز إحدى صور الشخصيات.';
        }

        newCharacterPaths[entry.key] = path;
      }

      final prefs = await SharedPreferences.getInstance();
      final oldAnimeJson = prefs.getString(animeKey);
      final oldCharacterKeys = <String, String>{};

      for (final key in prefs.getKeys()) {
        if (key.startsWith(characterPrefix)) {
          final value = prefs.getString(key);
          if (value != null) oldCharacterKeys[key] = value;
        }
      }

      // نسجل صور الذكريات الجديدة بأسماء فريدة، ولا نحذف الصور القديمة.
      final memoriesToRestore = <MapEntry<String, List<int>>>[];

      for (final entry in files.entries) {
        if (!entry.key.startsWith('memories/')) continue;

        final parts = entry.key.split('/');
        if (parts.length != 2 || parts[1].isEmpty) {
          return 'اسم إحدى صور الذكريات غير صالح.';
        }

        String originalName;
        try {
          originalName = Uri.decodeComponent(parts[1]);
        } catch (_) {
          return 'اسم إحدى صور الذكريات غير صالح.';
        }

        final safeName = originalName.replaceAll(RegExp(r'[/\\]'), '_');
        if (safeName.isEmpty || safeName == '.' || safeName == '..') {
          return 'اسم إحدى صور الذكريات غير صالح.';
        }

        memoriesToRestore.add(
          MapEntry(safeName, entry.value),
        );
      }

      // حفظ صور الذكريات في مجلد المعرض.
      final memoriesDirectory = Directory(
        '${appDirectory.path}/anime_memory_photos',
      );
      await memoriesDirectory.create(recursive: true);

      final createdMemoryFiles = <File>[];

      try {
        for (final memory in memoriesToRestore) {
          final target = File(
            '${memoriesDirectory.path}/restored_'
            '${DateTime.now().microsecondsSinceEpoch}_'
            '${createdMemoryFiles.length}_${memory.key}',
          );
          await target.writeAsBytes(memory.value, flush: true);
          createdMemoryFiles.add(target);
        }

        final encodedAnimes = jsonEncode(
          animes.map((anime) => anime.toJson()).toList(),
        );

        final saved = await prefs.setString(animeKey, encodedAnimes);
        if (!saved) {
          throw Exception('تعذر حفظ بيانات الأنميات.');
        }

        // استبدال مفاتيح صور الشخصيات بالبيانات الموجودة في النسخة.
        for (final key in prefs.getKeys().toList()) {
          if (key.startsWith(characterPrefix)) {
            await prefs.remove(key);
          }
        }

        for (final entry in newCharacterPaths.entries) {
          final savedCharacter = await prefs.setString(
            entry.key,
            entry.value,
          );
          if (!savedCharacter) {
            throw Exception('تعذر حفظ إحدى صور الشخصيات.');
          }
        }
      } catch (e) {
        // إعادة بيانات الأنميات والشخصيات السابقة عند فشل الحفظ.
        if (oldAnimeJson != null) {
          await prefs.setString(animeKey, oldAnimeJson);
        } else {
          await prefs.remove(animeKey);
        }

        for (final key in prefs.getKeys().toList()) {
          if (key.startsWith(characterPrefix)) {
            await prefs.remove(key);
          }
        }

        for (final entry in oldCharacterKeys.entries) {
          await prefs.setString(entry.key, entry.value);
        }

        for (final file in createdMemoryFiles) {
          if (await file.exists()) {
            await file.delete();
          }
        }

        return 'لم تكتمل الاستعادة، وحاول التطبيق إعادة بياناتك السابقة: $e';
      }

      return 'تمت استعادة الأنميات وصور الشخصيات بنجاح، '
          'وأُضيفت صور الذكريات دون حذف الصور الموجودة مسبقًا.';
    } catch (e) {
      return 'فشلت الاستعادة: $e';
    }
  }

  String _extension(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last;
    final dot = name.lastIndexOf('.');

    if (dot < 0 || dot == name.length - 1) return 'jpg';

    final extension = name.substring(dot + 1).toLowerCase();

    if (!RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension)) {
      return 'jpg';
    }

    return extension;
  }
}

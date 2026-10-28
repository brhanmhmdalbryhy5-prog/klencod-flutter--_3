
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
      final savedJson = prefs.getString(animeKey) ?? '[]';
      final decoded = jsonDecode(savedJson);

      if (decoded is! List) {
        return 'تعذر إنشاء النسخة: بيانات الأنميات غير صالحة.';
      }

      final animes = decoded.map((item) {
        return Anime.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
      }).toList();

      final archive = ziplib.Archive();
      final coverAssets = <String, String>{};
      final characterAssets = <String, String>{};
      final usedAssets = <String, List<int>>{};

      void addBytes(String name, List<int> bytes) {
        if (usedAssets.containsKey(name)) return;

        usedAssets[name] = bytes;
        archive.addFile(
          ziplib.ArchiveFile(name, bytes.length, bytes),
        );
      }

      // حفظ بيانات الأنميات، مع استبدال مسارات الأغلفة
      // بمسارات داخل ملف النسخة الاحتياطية.
      final animeJson = <Map<String, dynamic>>[];

      for (var i = 0; i < animes.length; i++) {
        final anime = animes[i];
        final item = anime.toJson();
        final path = anime.imagePath;

        if (path != null && path.isNotEmpty) {
          final imageFile = File(path);

          if (await imageFile.exists()) {
            final extension = _extension(path);
            final assetName = 'covers/cover_$i.$extension';

            addBytes(assetName, await imageFile.readAsBytes());
            coverAssets[anime.id] = assetName;
            item['imagePath'] = 'backup://$assetName';
          }
        }

        animeJson.add(item);
      }

      // حفظ صور الشخصيات المفضلة.
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(characterPrefix)) continue;

        final path = prefs.getString(key);
        if (path == null || path.isEmpty) continue;

        final imageFile = File(path);
        if (!await imageFile.exists()) continue;

        final assetName =
            'characters/${Uri.encodeComponent(key)}.${_extension(path)}';

        addBytes(assetName, await imageFile.readAsBytes());
        characterAssets[key] = assetName;
      }

      // حفظ صور معرض ذكرياتي.
      final appDirectory = await getApplicationDocumentsDirectory();
      final memoriesDirectory = Directory(
        '${appDirectory.path}/anime_memory_photos',
      );

      if (await memoriesDirectory.exists()) {
        for (final entity in memoriesDirectory.listSync()) {
          if (entity is! File) continue;

          final extension = _extension(entity.path);
          final name =
              'memories/${Uri.encodeComponent(entity.uri.pathSegments.last)}';

          addBytes(name, await entity.readAsBytes());
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

      return 'تم تجهيز النسخة الاحتياطية. تحقق من ظهور الملف في المكان الذي اخترته.';
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

      final Uint8List? bytes = selection.files.single.bytes;

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

        // رفض المسارات غير الآمنة داخل الأرشيف.
        if (entry.name.startsWith('/') ||
            entry.name.contains('../') ||
            entry.name.contains(r'..\')) {
          return 'النسخة تحتوي على مسار غير آمن.';
        }

        files[entry.name] = entry.content as List<int>;
      }

      if (!files.containsKey('metadata.json') ||
          !files.containsKey('animes.json')) {
        return 'النسخة غير مكتملة أو لا تخص هذا التطبيق.';
      }

      final metadata = jsonDecode(
        utf8.decode(files['metadata.json']!),
      );

      if (metadata is! Map ||
          metadata['format'] != 'anime_memory_backup' ||
          metadata['version'] != 1) {
        return 'صيغة النسخة الاحتياطية غير مدعومة.';
      }

      final rawAnimes = jsonDecode(
        utf8.decode(files['animes.json']!),
      );

      if (rawAnimes is! List) {
        return 'بيانات الأنميات داخل النسخة غير صالحة.';
      }

      final animes = rawAnimes.map((item) {
        return Anime.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
      }).toList();

      final coverAssets = Map<String, dynamic>.from(
        metadata['coverAssets'] as Map? ?? {},
      );

      final characterAssets = Map<String, dynamic>.from(
        metadata['characterAssets'] as Map? ?? {},
      );

      // التأكد من وجود كل صورة مرجعية قبل تعديل البيانات الحالية.
      for (final asset in coverAssets.values) {
        if (asset is! String || !files.containsKey(asset)) {
          return 'النسخة تفتقد إحدى صور الأغلفة.';
        }
      }

      for (final asset in characterAssets.values) {
        if (asset is! String || !files.containsKey(asset)) {
          return 'النسخة تفتقد إحدى صور الشخصيات.';
        }
      }

      // تجهيز الصور في مجلد جديد حتى لا نلمس الصور الحالية.
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

        final targetDirectory = Directory(
          '${restoreDirectory.path}/${parts[0]}',
        );

        await targetDirectory.create(recursive: true);

        final target = File(
          '${targetDirectory.path}/${parts[1]}',
        );

        await target.writeAsBytes(entry.value, flush: true);
        restoredPaths[entry.key] = target.path;
      }

      // تحديث مسارات صور الأغلفة في بيانات الأنميات.
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

      // تجهيز صور الذكريات في مجلدها المعروف للتطبيق.
      final memoriesDirectory = Directory(
        '${appDirectory.path}/anime_memory_photos',
      );

      await memoriesDirectory.create(recursive: true);

      for (final entry in files.entries) {
        if (!entry.key.startsWith('memories/')) continue;

        final parts = entry.key.split('/');
        if (parts.length != 2) continue;

        final originalName = Uri.decodeComponent(parts[1]);
        final safeName = originalName.replaceAll(
          RegExp(r'[/\\]'),
          '_',
        );

        final target = File(
          '${memoriesDirectory.path}/restored_'
          '${DateTime.now().microsecondsSinceEpoch}_$safeName',
        );

        await target.writeAsBytes(entry.value, flush: true);
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

      // إعداد بيانات الشخصيات المستعادة.
      final newCharacterPaths = <String, String>{};

      for (final entry in characterAssets.entries) {
        final key = entry.key;
        final asset = entry.value as String;
        final path = restoredPaths[asset];

        if (path == null) {
          return 'تعذر تجهيز إحدى صور الشخصيات.';
        }

        newCharacterPaths[key] = path;
      }

      // حفظ البيانات الجديدة. عند فشل الحفظ نحاول إعادة القديمة.
      try {
        final encodedAnimes = jsonEncode(
          animes.map((anime) => anime.toJson()).toList(),
        );

        final saved = await prefs.setString(animeKey, encodedAnimes);

        if (!saved) {
          return 'تعذر حفظ الأنميات المستعادة.';
        }

        for (final key in prefs.getKeys()) {
          if (key.startsWith(characterPrefix)) {
            await prefs.remove(key);
          }
        }

        for (final entry in newCharacterPaths.entries) {
          await prefs.setString(entry.key, entry.value);
        }
      } catch (e) {
        if (oldAnimeJson != null) {
          await prefs.setString(animeKey, oldAnimeJson);
        }

        for (final key in prefs.getKeys()) {
          if (key.startsWith(characterPrefix)) {
            await prefs.remove(key);
          }
        }

        for (final entry in oldCharacterKeys.entries) {
          await prefs.setString(entry.key, entry.value);
        }

        return 'لم تكتمل الاستعادة، وحاول التطبيق إعادة بياناتك السابقة: $e';
      }

      return 'تمت استعادة بيانات الأنميات وصور الشخصيات. '
          'أُضيفت صور الذكريات إلى المعرض دون حذف الصور الموجودة مسبقًا.';
    } catch (e) {
      return 'فشلت الاستعادة: $e';
    }
  }

  String _extension(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');

    if (dot < 0 || dot == name.length - 1) return 'jpg';

    final extension = name.substring(dot + 1).toLowerCase();

    if (!RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension)) {
      return 'jpg';
    }

    return extension;
  }
}

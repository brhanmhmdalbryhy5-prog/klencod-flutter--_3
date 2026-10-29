
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

  static const String backupFormat = 'anime_memory_backup';
  static const int backupVersion = 1;

  /// إنشاء نسخة احتياطية كاملة.
  static Future<String> createBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final archive = ziplib.Archive();

      final savedAnime = prefs.getString(animeKey);
      final List<dynamic> animeList =
          savedAnime == null || savedAnime.isEmpty
              ? <dynamic>[]
              : jsonDecode(savedAnime) as List<dynamic>;

      final List<Map<String, dynamic>> backupAnime = [];
      final Map<String, String> coverAssets = {};
      final Map<String, String> characterAssets = {};

      final appDir = await getApplicationDocumentsDirectory();

      // حفظ بيانات الأنمي والأغلفة.
      for (int i = 0; i < animeList.length; i++) {
        final animeJson =
            Map<String, dynamic>.from(animeList[i] as Map);

        final anime = Anime.fromJson(animeJson);
        final originalImagePath = anime.imagePath;

        if (originalImagePath != null &&
            originalImagePath.isNotEmpty &&
            !originalImagePath.startsWith('backup://')) {
          final imageFile = File(originalImagePath);

          if (await imageFile.exists()) {
            final extension = _extension(originalImagePath);
            final assetPath = 'covers/cover_$i.$extension';

            archive.addFile(
              ziplib.ArchiveFile(
                assetPath,
                await imageFile.length(),
                await imageFile.readAsBytes(),
              ),
            );

            coverAssets[i.toString()] = assetPath;
            animeJson['imagePath'] = 'backup://$assetPath';
          }
        }

        backupAnime.add(animeJson);
      }

      // حفظ صور الشخصيات المفضلة.
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(characterPrefix)) continue;

        final imagePath = prefs.getString(key);
        if (imagePath == null || imagePath.isEmpty) continue;

        final imageFile = File(imagePath);
        if (!await imageFile.exists()) continue;

        final assetPath =
            'characters/${Uri.encodeComponent(key)}.${_extension(imagePath)}';

        archive.addFile(
          ziplib.ArchiveFile(
            assetPath,
            await imageFile.length(),
            await imageFile.readAsBytes(),
          ),
        );

        characterAssets[key] = assetPath;
      }

      // حفظ صور الذكريات.
      final memoriesDirectory =
          Directory('${appDir.path}/anime_memory_photos');

      if (await memoriesDirectory.exists()) {
        await for (final entity
            in memoriesDirectory.list(recursive: false)) {
          if (entity is! File) continue;

          final name = entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.last
              : 'memory_${DateTime.now().millisecondsSinceEpoch}.jpg';

          final assetPath = 'memories/${Uri.encodeComponent(name)}';

          archive.addFile(
            ziplib.ArchiveFile(
              assetPath,
              await entity.length(),
              await entity.readAsBytes(),
            ),
          );
        }
      }

      final metadata = <String, dynamic>{
        'format': backupFormat,
        'version': backupVersion,
        'createdAt': DateTime.now().toIso8601String(),
        'coverAssets': coverAssets,
        'characterAssets': characterAssets,
      };

      archive.addFile(
        ziplib.ArchiveFile(
          'metadata.json',
          utf8.encode(jsonEncode(metadata)).length,
          utf8.encode(jsonEncode(metadata)),
        ),
      );

      final animeBytes = utf8.encode(jsonEncode(backupAnime));
      archive.addFile(
        ziplib.ArchiveFile(
          'animes.json',
          animeBytes.length,
          animeBytes,
        ),
      );

      final zipBytes = ziplib.ZipEncoder().encode(archive);
      if (zipBytes == null || zipBytes.isEmpty) {
        return 'تعذّر إنشاء ملف النسخة الاحتياطية.';
      }

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ النسخة الاحتياطية',
        fileName:
            'anime_memory_backup_${DateTime.now().millisecondsSinceEpoch}.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: Uint8List.fromList(zipBytes),
      );

      if (result == null) {
        return 'تم إلغاء حفظ النسخة الاحتياطية.';
      }

      return 'تم إنشاء النسخة الاحتياطية بنجاح.';
    } catch (e) {
      return 'حدث خطأ أثناء إنشاء النسخة الاحتياطية: $e';
    }
  }

  /// استعادة نسخة احتياطية بصيغة ZIP.
  static Future<String> restoreBackup() async {
    Directory? restoreDirectory;
    final List<File> createdMemoryFiles = [];

    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        allowMultiple: false,
        withData: false,
      );

      if (selection == null || selection.files.isEmpty) {
        return 'تم إلغاء اختيار النسخة الاحتياطية.';
      }

      final selectedFile = selection.files.single;
      Uint8List? bytes;

      // محاولة قراءة الملف من مساره أولًا.
      final selectedPath = selectedFile.path;

      if (selectedPath != null && selectedPath.isNotEmpty) {
        try {
          final file = File(selectedPath);
          if (await file.exists()) {
            bytes = await file.readAsBytes();
          }
        } catch (_) {
          // ستُجرّب قراءة bytes أدناه إذا كانت متاحة.
        }
      }

      // بعض مزوّدي الملفات قد لا يعيدون مسارًا صالحًا.
      bytes ??= selectedFile.bytes;

      if (bytes == null || bytes.isEmpty) {
        return 'تعذّرت قراءة ملف ZIP. جرّب اختيار الملف من تطبيق الملفات مرة أخرى.';
      }

      // فك الضغط والتحقق من سلامة الأرشيف.
      final ziplib.Archive archive;

      try {
        archive = ziplib.ZipDecoder().decodeBytes(bytes);
      } catch (_) {
        return 'الملف ليس نسخة ZIP صالحة أو أن الملف تالف.';
      }

      final Map<String, ziplib.ArchiveFile> files = {};

      for (final entry in archive.files) {
        if (!entry.isFile) continue;

        final normalizedName =
            entry.name.replaceAll('\\', '/');

        // منع أسماء الملفات التي قد تكتب خارج مجلد الاستعادة.
        if (normalizedName.startsWith('/') ||
            normalizedName.split('/').any(
              (part) => part == '..' || part == '.',
            )) {
          continue;
        }

        files[normalizedName] = entry;
      }

      final metadataFile = files['metadata.json'];
      final animeFile = files['animes.json'];

      if (metadataFile == null || animeFile == null) {
        return 'النسخة الاحتياطية غير مكتملة؛ لم يتم العثور على الملفات الأساسية.';
      }

      Map<String, dynamic> metadata;
      List<dynamic> animeList;

      try {
        metadata = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(
            _archiveBytes(metadataFile),
          )) as Map,
        );

        animeList = jsonDecode(
          utf8.decode(_archiveBytes(animeFile)),
        ) as List<dynamic>;
      } catch (_) {
        return 'تعذّرت قراءة بيانات النسخة الاحتياطية.';
      }

      if (metadata['format'] != backupFormat) {
        return 'صيغة النسخة الاحتياطية غير معروفة.';
      }

      final version = metadata['version'];
      if (version is num && version > backupVersion) {
        return 'هذه النسخة أحدث من إصدار التطبيق الحالي.';
      }

      // التحقق من بيانات الأنمي قبل استبدال البيانات الحالية.
      final List<Map<String, dynamic>> restoredAnime = [];

      try {
        for (final item in animeList) {
          final json = Map<String, dynamic>.from(item as Map);
          final anime = Anime.fromJson(json);

          // التحقق من أن بيانات العنصر قابلة للقراءة.
          anime.toJson();
          restoredAnime.add(json);
        }
      } catch (_) {
        return 'تحتوي النسخة الاحتياطية على بيانات أنمي غير صالحة.';
      }

      final appDir = await getApplicationDocumentsDirectory();

      restoreDirectory = Directory(
        '${appDir.path}/anime_images/restored_${DateTime.now().millisecondsSinceEpoch}',
      );

      await restoreDirectory.create(recursive: true);

      final coverAssets = _stringMap(metadata['coverAssets']);
      final characterAssets =
          _stringMap(metadata['characterAssets']);

      // استعادة الأغلفة وتحديث مساراتها.
      for (int i = 0; i < restoredAnime.length; i++) {
        final animeJson = restoredAnime[i];
        final imagePath = animeJson['imagePath'];

        String? assetPath = coverAssets[i.toString()];

        if (imagePath is String &&
            imagePath.startsWith('backup://')) {
          assetPath = imagePath.substring('backup://'.length);
        }

        if (assetPath == null || assetPath.isEmpty) {
          if (imagePath is String &&
              imagePath.startsWith('backup://')) {
            animeJson['imagePath'] = '';
          }
          continue;
        }

        final safeAssetPath = _safeArchivePath(assetPath);
        final coverEntry =
            safeAssetPath == null ? null : files[safeAssetPath];

        if (coverEntry == null) {
          animeJson['imagePath'] = '';
          continue;
        }

        final extension = _extension(safeAssetPath);
        final destination = File(
          '${restoreDirectory.path}/cover_$i.$extension',
        );

        await destination.writeAsBytes(
          _archiveBytes(coverEntry),
          flush: true,
        );

        animeJson['imagePath'] = destination.path;
      }

      // تجهيز صور الشخصيات للاستعادة.
      final Map<String, String> restoredCharacterPaths = {};

      for (final item in characterAssets.entries) {
        final key = item.key;

        if (!key.startsWith(characterPrefix)) continue;

        final safeAssetPath = _safeArchivePath(item.value);
        if (safeAssetPath == null) continue;

        final characterEntry = files[safeAssetPath];
        if (characterEntry == null) continue;

        final extension = _extension(safeAssetPath);
        final destination = File(
          '${restoreDirectory.path}/character_${restoredCharacterPaths.length}.$extension',
        );

        await destination.writeAsBytes(
          _archiveBytes(characterEntry),
          flush: true,
        );

        restoredCharacterPaths[key] = destination.path;
      }

      // استعادة صور الذكريات إلى مجلدها المخصص.
      final memoriesDirectory =
          Directory('${appDir.path}/anime_memory_photos');

      await memoriesDirectory.create(recursive: true);

      final restoredMemoryPaths = <String>[];

      for (final entry in files.entries) {
        if (!entry.key.startsWith('memories/')) continue;

        final encodedName =
            entry.key.substring('memories/'.length);

        if (encodedName.isEmpty || encodedName.contains('/')) {
          continue;
        }

        String name;
        try {
          name = Uri.decodeComponent(encodedName);
        } catch (_) {
          name = encodedName;
        }

        // منع استخدام أسماء مسارات بدل أسماء ملفات.
        name = name.replaceAll('\\', '/').split('/').last;
        if (name.isEmpty || name == '.' || name == '..') {
          continue;
        }

        final destination = File(
          '${memoriesDirectory.path}/$name',
        );

        await destination.writeAsBytes(
          _archiveBytes(entry.value),
          flush: true,
        );

        createdMemoryFiles.add(destination);
        restoredMemoryPaths.add(destination.path);
      }

      // حفظ البيانات الجديدة مع الاحتفاظ بالقديمة عند فشل الحفظ.
      final prefs = await SharedPreferences.getInstance();
      final oldAnimeData = prefs.getString(animeKey);

      final Map<String, String?> oldCharacterValues = {};
      for (final key in restoredCharacterPaths.keys) {
        oldCharacterValues[key] = prefs.getString(key);
      }

      try {
        final animeSaved = await prefs.setString(
          animeKey,
          jsonEncode(restoredAnime),
        );

        if (!animeSaved) {
          throw Exception('تعذّر حفظ قائمة الأنمي.');
        }

        for (final item in restoredCharacterPaths.entries) {
          final saved = await prefs.setString(
            item.key,
            item.value,
          );

          if (!saved) {
            throw Exception('تعذّر حفظ صور الشخصيات.');
          }
        }
      } catch (_) {
        // التراجع عن تحديث SharedPreferences.
        if (oldAnimeData == null) {
          await prefs.remove(animeKey);
        } else {
          await prefs.setString(animeKey, oldAnimeData);
        }

        for (final item in oldCharacterValues.entries) {
          if (item.value == null) {
            await prefs.remove(item.key);
          } else {
            await prefs.setString(item.key, item.value!);
          }
        }

        for (final file in createdMemoryFiles) {
          try {
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {}
        }

        rethrow;
      }

      return 'تمت استعادة النسخة الاحتياطية بنجاح.';
    } catch (e) {
      return 'حدث خطأ أثناء استعادة النسخة الاحتياطية: $e';
    }
  }

  static List<int> _archiveBytes(ziplib.ArchiveFile file) {
    final content = file.content;

    if (content is List<int>) {
      return content;
    }

    if (content is Uint8List) {
      return content;
    }

    throw const FormatException(
      'محتوى الملف داخل ZIP غير صالح.',
    );
  }

  static Map<String, String> _stringMap(dynamic value) {
    final result = <String, String>{};

    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key is String && entry.value is String) {
          result[entry.key as String] = entry.value as String;
        }
      }
    }

    return result;
  }

  static String? _safeArchivePath(String path) {
    final normalized = path.replaceAll('\\', '/');

    if (normalized.isEmpty ||
        normalized.startsWith('/') ||
        normalized.split('/').any(
          (part) => part == '..' || part == '.',
        )) {
      return null;
    }

    return normalized;
  }

  static String _extension(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last;

    if (!name.contains('.')) return 'jpg';

    final extension = name.split('.').last.toLowerCase();

    const allowedExtensions = {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'bmp',
    };

    if (!allowedExtensions.contains(extension)) {
      return 'jpg';
    }

    return extension;
  }
}

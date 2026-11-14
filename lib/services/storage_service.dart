import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime.dart';

class StorageService {
  // ══════════════════════════════════════════════════════════
  // طبقات الحماية
  // ══════════════════════════════════════════════════════════
  static const String _prefsKey = 'anime_memory_list';       // ترحيل فقط
  static const String _trashPrefsKey = 'anime_trash_list';   // ترحيل فقط
  static const String _ratingSystemKey = 'rating_system_v2';
  static const String _migrationFlagKey = 'storage_v3_migrated';

  static const String _mainFile = 'animes_data.json';         // الملف الأساسي
  static const String _backupFile = 'animes_data.backup.json'; // نسخة احتياطية
  static const String _emergencyFile = 'animes_data.emergency.json'; // طارئة
  static const String _trashFile = 'animes_trash.json';

  // قفل لمنع الكتابة المتزامنة من عمليتين
  static Future<void> _lock = Future.value();

  Future<T> _withLock<T>(Future<T> Function() action) async {
    final previous = _lock;
    final completer = Completer<void>();
    _lock = completer.future;
    try {
      await previous;
      return await action();
    } finally {
      completer.complete();
    }
  }

  Future<Directory> _appDir() => getApplicationDocumentsDirectory();

  Future<File> _fileOf(String name) async {
    final dir = await _appDir();
    return File('${dir.path}/$name');
  }

  // ══════════════════════════════════════════════════════════
  // التحميل — 4 طبقات استعادة
  // ══════════════════════════════════════════════════════════
  Future<List<Anime>> loadAnimes() {
    return _withLock(() async {
      // 1️⃣ الملف الأساسي
      final primary = await _tryLoadFile(await _fileOf(_mainFile));
      if (primary != null) {
        await _ensureRatingUpgraded(primary);
        return primary;
      }

      // 2️⃣ النسخة الاحتياطية
      final backup = await _tryLoadFile(await _fileOf(_backupFile));
      if (backup != null) {
        print('⚠️ Storage: تم الاستعادة من النسخة الاحتياطية');
        await _ensureRatingUpgraded(backup);
        await _writePrimary(backup);
        return backup;
      }

      // 3️⃣ الملف الطارئ
      final emergency = await _tryLoadFile(await _fileOf(_emergencyFile));
      if (emergency != null) {
        print('⚠️ Storage: تم الاستعادة من الملف الطارئ');
        await _ensureRatingUpgraded(emergency);
        await _writePrimary(emergency);
        return emergency;
      }

      // 4️⃣ الترحيل من SharedPreferences (قديم)
      final migrated = await _tryMigrateFromPrefs();
      if (migrated != null) {
        print('✅ Storage: تم الترحيل من الإصدار القديم');
        await _ensureRatingUpgraded(migrated);
        await _writePrimary(migrated);
        return migrated;
      }

      return [];
    });
  }

  Future<List<Anime>?> _tryLoadFile(File file) async {
    try {
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final decoded = jsonDecode(content);
      if (decoded is! List) return null;
      return decoded
          .map((item) => Anime.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      print('⚠️ Storage: فشل قراءة ${file.path}: $e');
      return null;
    }
  }

  Future<List<Anime>?> _tryMigrateFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMigrated = prefs.getBool(_migrationFlagKey) ?? false;
      if (isMigrated) return null;

      final savedData = prefs.getString(_prefsKey);
      if (savedData == null || savedData.isEmpty) {
        await prefs.setBool(_migrationFlagKey, true);
        return null;
      }

      final decoded = jsonDecode(savedData) as List;
      final animes = decoded
          .map((item) => Anime.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      // اترك prefs كما هي احتياطاً حتى نتأكد من نجاح الحفظ الجديد
      return animes;
    } catch (e) {
      print('⚠️ Storage: فشل الترحيل من SharedPreferences: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════
  // الحفظ — كتابة ذرية مع تحقق
  // ══════════════════════════════════════════════════════════
  Future<bool> saveAnimes(List<Anime> animes) {
    return _withLock(() async {
      try {
        final json = jsonEncode(animes.map((a) => a.toJson()).toList());

        // 1. احفظ في الملف الأساسي (ذرّياً)
        final primaryOk = await _atomicWrite(await _fileOf(_mainFile), json);
        if (!primaryOk) {
          print('❌ Storage: فشل الحفظ الأساسي');
          // جرّب الملف الطارئ كحل أخير
          final emergencyOk = await _atomicWrite(await _fileOf(_emergencyFile), json);
          if (!emergencyOk) {
            print('❌❌ Storage: فشل كل شيء!');
            return false;
          }
          print('⚠️ Storage: تم الحفظ في الملف الطارئ فقط');
          return true;
        }

        // 2. اكتب نسخة احتياطية (بشكل غير متزامن - لا يوقف العملية)
        unawaited(_atomicWrite(await _fileOf(_backupFile), json));

        // 3. تحقق من نجاح الحفظ بإعادة القراءة
        final verified = await _verifyFile(await _fileOf(_mainFile), json);
        if (!verified) {
          print('⚠️ Storage: فشل التحقق من صحة الحفظ');
          return false;
        }

        // 4. بعد نجاح مضمون، احذف بيانات الترحيل القديمة
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool(_migrationFlagKey) != true) {
          await prefs.remove(_prefsKey);
          await prefs.setBool(_migrationFlagKey, true);
        }

        return true;
      } catch (e) {
        print('❌ Storage: خطأ في الحفظ: $e');
        return false;
      }
    });
  }

  Future<bool> _atomicWrite(File target, String content) async {
    try {
      // اكتب إلى ملف مؤقت
      final temp = File('${target.path}.tmp');
      await temp.writeAsString(content, flush: true);

      // تحقق من نجاح الكتابة قبل الاستبدال
      final verify = await temp.readAsString();
      if (verify != content) {
        await temp.delete();
        return false;
      }

      // استبدال ذري: إعادة التسمية عملية atomic في نظام الملفات
      await temp.rename(target.path);
      return true;
    } catch (e) {
      print('❌ Storage: _atomicWrite: $e');
      return false;
    }
  }

  Future<bool> _verifyFile(File file, String expected) async {
    try {
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      return content == expected;
    } catch (_) {
      return false;
    }
  }

  Future<void> _writePrimary(List<Anime> animes) async {
    final json = jsonEncode(animes.map((a) => a.toJson()).toList());
    await _atomicWrite(await _fileOf(_mainFile), json);
  }

  // ══════════════════════════════════════════════════════════
  // ترقية نظام التقييم (5 → 10 نجوم)
  // ══════════════════════════════════════════════════════════
  Future<void> _ensureRatingUpgraded(List<Anime> animes) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_ratingSystemKey) == true) return;

    bool changed = false;
    for (final anime in animes) {
      if (anime.rating > 0 && anime.rating <= 5) {
        anime.rating = anime.rating * 2;
        changed = true;
      }
    }
    if (changed) {
      final json = jsonEncode(animes.map((a) => a.toJson()).toList());
      await _atomicWrite(await _fileOf(_mainFile), json);
    }
    await prefs.setBool(_ratingSystemKey, true);
  }

  // ══════════════════════════════════════════════════════════
  // سلة المهملات — أيضاً ملف بدل SharedPreferences
  // ══════════════════════════════════════════════════════════
  Future<bool> moveToTrash(List<Anime> animes, String animeId) async {
    final idx = animes.indexWhere((a) => a.id == animeId);
    if (idx == -1) return false;

    final anime = animes[idx];
    animes.removeAt(idx);

    final saved = await saveAnimes(animes);
    if (!saved) {
      // استرجع العنصر لو فشل الحفظ
      animes.insert(idx, anime);
      return false;
    }

    // أضف إلى سلة المهملات (ملف)
    final trash = await loadTrash();
    trash.add(anime);
    await _saveTrash(trash);
    return true;
  }

  Future<List<Anime>> loadTrash() {
    return _withLock(() async {
      try {
        final file = await _fileOf(_trashFile);
        if (!await file.exists()) return [];
        final content = await file.readAsString();
        if (content.trim().isEmpty) return [];
        final decoded = jsonDecode(content) as List;
        return decoded
            .map((item) => Anime.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (e) {
        print('⚠️ Storage: فشل قراءة سلة المهملات: $e');
        return [];
      }
    });
  }

  Future<bool> _saveTrash(List<Anime> trash) async {
    try {
      final json = jsonEncode(trash.map((a) => a.toJson()).toList());
      return await _atomicWrite(await _fileOf(_trashFile), json);
    } catch (e) {
      print('❌ Storage: فشل حفظ سلة المهملات: $e');
      return false;
    }
  }

  Future<bool> restoreFromTrash(List<Anime> current, Anime anime) async {
    final trash = await loadTrash();
    trash.removeWhere((a) => a.id == anime.id);
    await _saveTrash(trash);

    current.add(anime);
    return await saveAnimes(current);
  }

  Future<bool> permanentDelete(Anime anime, {bool isInTrash = false}) async {
    if (isInTrash) {
      final trash = await loadTrash();
      trash.removeWhere((a) => a.id == anime.id);
      await _saveTrash(trash);
    }

    // احذف صورة الغلاف
    await _deleteFileSafely(anime.imagePath);
    // احذف الفيديو
    await _deleteFileSafely(anime.videoPath);
    // احذف صور الشخصيات
    for (final c in anime.characters) {
      await _deleteFileSafely(c['imagePath'] as String?);
    }

    return true;
  }

  Future<void> _deleteFileSafely(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<bool> imageExists(Anime anime) async {
    final path = anime.imagePath;
    if (path == null || path.isEmpty) return false;
    try {
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // صحة التخزين — لعرضها للمستخدم في الإعدادات (اختياري)
  // ══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> storageHealth() async {
    final main = await _fileOf(_mainFile);
    final backup = await _fileOf(_backupFile);
    final emergency = await _fileOf(_emergencyFile);

    return {
      'mainExists': await main.exists(),
      'mainSize': await main.exists() ? await main.length() : 0,
      'backupExists': await backup.exists(),
      'backupSize': await backup.exists() ? await backup.length() : 0,
      'emergencyExists': await emergency.exists(),
      'emergencySize': await emergency.exists() ? await emergency.length() : 0,
    };
  }
}
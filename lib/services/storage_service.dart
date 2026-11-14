import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime.dart';

class StorageService {
  static const String _storageKey = 'anime_memory_list';       // للترحيل فقط
  static const String _trashKey = 'anime_trash_list';
  static const String _ratingSystemKey = 'rating_system_v2';
  static const String _fileName = 'animes_data.json';          // ✅ ملف دائم

  Future<File> _getStorageFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<Anime>> loadAnimes() async {
    try {
      final file = await _getStorageFile();

      // 1️⃣ قراءة من الملف إن وُجد
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final decoded = jsonDecode(content) as List;
          final animes = decoded
              .map((item) => Anime.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
          await _applyRatingUpgradeIfNeeded(animes);
          return animes;
        }
      }

      // 2️⃣ ترحيل من SharedPreferences (مرة واحدة فقط)
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString(_storageKey);
      if (savedData != null && savedData.isNotEmpty) {
        final decoded = jsonDecode(savedData) as List;
        final animes = decoded
            .map((item) => Anime.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        await _applyRatingUpgradeIfNeeded(animes);
        await saveAnimes(animes);       // نقل إلى الملف
        await prefs.remove(_storageKey); // تنظيف
        return animes;
      }

      return [];
    } catch (e) {
      print('StorageService.loadAnimes error: $e');
      return [];
    }
  }

  Future<bool> saveAnimes(List<Anime> animes) async {
    try {
      final file = await _getStorageFile();
      final json = jsonEncode(animes.map((a) => a.toJson()).toList());

      // ✅ كتابة ذرية (آمنة): ملف مؤقت ثم إعادة تسمية
      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(json, flush: true);
      await tempFile.rename(file.path);

      return true;
    } catch (e) {
      print('StorageService.saveAnimes error: $e');
      return false;
    }
  }

  Future<void> _applyRatingUpgradeIfNeeded(List<Anime> animes) async {
    final prefs = await SharedPreferences.getInstance();
    final isUpgraded = prefs.getBool(_ratingSystemKey) ?? false;
    if (!isUpgraded) {
      bool changed = false;
      for (var anime in animes) {
        if (anime.rating > 0 && anime.rating <= 5) {
          anime.rating = anime.rating * 2;
          changed = true;
        }
      }
      if (changed) await saveAnimes(animes);
      await prefs.setBool(_ratingSystemKey, true);
    }
  }

  Future<bool> moveToTrash(List<Anime> animes, String animeId) async {
    final animeIndex = animes.indexWhere((anime) => anime.id == animeId);
    if (animeIndex == -1) return false;

    final Anime anime = animes[animeIndex];
    animes.removeAt(animeIndex);
    final bool saved = await saveAnimes(animes);

    if (saved) {
      final prefs = await SharedPreferences.getInstance();
      final String? trashData = prefs.getString(_trashKey);
      List<dynamic> trashList = trashData != null ? jsonDecode(trashData) : [];
      trashList.add(anime.toJson());
      await prefs.setString(_trashKey, jsonEncode(trashList));
    }

    return saved;
  }

  Future<List<Anime>> loadTrash() async {
    final prefs = await SharedPreferences.getInstance();
    final String? trashData = prefs.getString(_trashKey);
    if (trashData == null || trashData.isEmpty) return [];
    try {
      final List<dynamic> decodedData = jsonDecode(trashData);
      return decodedData
          .map((item) => Anime.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> restoreFromTrash(List<Anime> currentAnimes, Anime animeToRestore) async {
    final prefs = await SharedPreferences.getInstance();
    final String? trashData = prefs.getString(_trashKey);
    if (trashData != null) {
      List<dynamic> trashList = jsonDecode(trashData);
      trashList.removeWhere((item) => item['id'] == animeToRestore.id);
      await prefs.setString(_trashKey, jsonEncode(trashList));
    }
    currentAnimes.add(animeToRestore);
    return await saveAnimes(currentAnimes);
  }

  Future<bool> permanentDelete(Anime anime, {bool isInTrash = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (isInTrash) {
      final String? trashData = prefs.getString(_trashKey);
      if (trashData != null) {
        List<dynamic> trashList = jsonDecode(trashData);
        trashList.removeWhere((item) => item['id'] == anime.id);
        await prefs.setString(_trashKey, jsonEncode(trashList));
      }
    }
    final String? imagePath = anime.imagePath;
    if (imagePath != null && imagePath.isNotEmpty) {
      try {
        final file = File(imagePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    return true;
  }

  Future<bool> imageExists(Anime anime) async {
    final String? imagePath = anime.imagePath;
    if (imagePath == null || imagePath.isEmpty) return false;
    try {
      return await File(imagePath).exists();
    } catch (_) {
      return false;
    }
  }
}
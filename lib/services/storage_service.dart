import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime.dart';

class StorageService {
  static const String _storageKey = 'anime_memory_list';
  static const String _trashKey = 'anime_trash_list'; // 🔥 مفتاح جديد لسلة المهملات
  static const String _ratingSystemKey = 'rating_system_v2';

  // 🔥 دالة لتحميل الأنميات العادية
  Future<List<Anime>> loadAnimes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString(_storageKey);

    if (savedData == null || savedData.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decodedData = jsonDecode(savedData);

      List<Anime> animes = decodedData
          .map((item) => Anime.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      // الترقية التلقائية من 5 نجوم إلى 10 نجوم
      final bool isUpgraded = prefs.getBool(_ratingSystemKey) ?? false;
      if (!isUpgraded) {
        for (var anime in animes) {
          if (anime.rating > 0 && anime.rating <= 5) {
            anime.rating = anime.rating * 2;
          }
        }
        await saveAnimes(animes);
        await prefs.setBool(_ratingSystemKey, true);
      }

      return animes;
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveAnimes(List<Anime> animes) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(animes.map((anime) => anime.toJson()).toList());
    return prefs.setString(_storageKey, encodedData);
  }

  // 🔥 دالة لنقل الأنمي إلى سلة المهملات (بدلاً من الحذف النهائي)
  Future<bool> moveToTrash(List<Anime> animes, String animeId) async {
    final animeIndex = animes.indexWhere((anime) => anime.id == animeId);
    if (animeIndex == -1) return false;

    final Anime anime = animes[animeIndex];
    animes.removeAt(animeIndex);

    // حفظ القائمة الأصلية بدون الأنمي
    final bool saved = await saveAnimes(animes);

    if (saved) {
      // إضافة الأنمي إلى سلة المهملات
      final prefs = await SharedPreferences.getInstance();
      final String? trashData = prefs.getString(_trashKey);
      List<dynamic> trashList = trashData != null ? jsonDecode(trashData) : [];
      
      trashList.add(anime.toJson());
      await prefs.setString(_trashKey, jsonEncode(trashList));
    }

    return saved;
  }

  // 🔥 دالة لتحميل سلة المهملات
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

  // 🔥 دالة لاستعادة أنمي من السلة
  Future<bool> restoreFromTrash(List<Anime> currentAnimes, Anime animeToRestore) async {
    final prefs = await SharedPreferences.getInstance();
    
    // إزالته من سلة المهملات
    final String? trashData = prefs.getString(_trashKey);
    if (trashData != null) {
      List<dynamic> trashList = jsonDecode(trashData);
      trashList.removeWhere((item) => item['id'] == animeToRestore.id);
      await prefs.setString(_trashKey, jsonEncode(trashList));
    }

    // إضافته للقائمة الأصلية
    currentAnimes.add(animeToRestore);
    return await saveAnimes(currentAnimes);
  }

  // 🔥 دالة لحذف أنمي نهائياً (من السلة أو من المكتبة)
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

    // حذف الصورة من الجهاز
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
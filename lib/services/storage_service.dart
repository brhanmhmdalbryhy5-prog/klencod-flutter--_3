import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime.dart';

class StorageService {
  static const String _storageKey = 'anime_memory_list';
  static const String _ratingSystemKey = 'rating_system_v2'; // مفتاح لمعرفة أن الترقية تمت

  Future<List<Anime>> loadAnimes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString(_storageKey);

    if (savedData == null || savedData.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decodedData = jsonDecode(savedData);

      List<Anime> animes = decodedData
          .map(
            (item) => Anime.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();

      // 🔥 الترقية التلقائية من 5 نجوم إلى 10 نجوم
      final bool isUpgraded = prefs.getBool(_ratingSystemKey) ?? false;
      if (!isUpgraded) {
        for (var anime in animes) {
          if (anime.rating > 0 && anime.rating <= 5) {
            // ضرب التقييم في 2 (5 تصبح 10، 4 تصبح 8، إلخ)
            anime.rating = anime.rating * 2;
          }
        }
        // حفظ التعديلات الجديدة في الخلفية
        await saveAnimes(animes);
        // تسجيل أن الترقية تمت بنجاح حتى لا تتكرر
        await prefs.setBool(_ratingSystemKey, true);
      }

      return animes;
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveAnimes(List<Anime> animes) async {
    final prefs = await SharedPreferences.getInstance();

    final String encodedData = jsonEncode(
      animes.map((anime) => anime.toJson()).toList(),
    );

    return prefs.setString(_storageKey, encodedData);
  }

  Future<bool> deleteAnime(
    List<Anime> animes,
    String animeId,
  ) async {
    final animeIndex = animes.indexWhere(
      (anime) => anime.id == animeId,
    );

    if (animeIndex == -1) {
      return false;
    }

    final Anime anime = animes[animeIndex];
    final String? imagePath = anime.imagePath;

    animes.removeAt(animeIndex);

    final bool saved = await saveAnimes(animes);

    if (saved && imagePath != null && imagePath.isNotEmpty) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    return saved;
  }

  Future<bool> imageExists(Anime anime) async {
    final String? imagePath = anime.imagePath;

    if (imagePath == null || imagePath.isEmpty) {
      return false;
    }

    try {
      return await File(imagePath).exists();
    } catch (_) {
      return false;
    }
  }
}

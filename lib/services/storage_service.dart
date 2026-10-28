
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime.dart';

class StorageService {
  static const String _storageKey = 'anime_memory_list';

  Future<List<Anime>> loadAnimes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString(_storageKey);

    if (savedData == null || savedData.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decodedData = jsonDecode(savedData);

      return decodedData
          .map(
            (item) => Anime.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
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

  /// حذف أنمي واحد مع محاولة حذف صورته المحلية.
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
      } catch (_) {
        // يظل حذف الأنمي محفوظًا حتى لو تعذر حذف الصورة.
      }
    }

    return saved;
  }

  /// التحقق من وجود صورة محفوظة للأنمي.
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

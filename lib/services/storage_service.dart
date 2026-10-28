
import 'dart:convert';

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
    } catch (e) {
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

  Future<bool> clearAnimes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(_storageKey);
  }
}

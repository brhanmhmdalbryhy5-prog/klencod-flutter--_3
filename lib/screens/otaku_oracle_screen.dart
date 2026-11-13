import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/anime.dart';
import '../services/storage_service.dart';

class OtakuOracleScreen extends StatefulWidget {
  const OtakuOracleScreen({super.key});

  @override
  State<OtakuOracleScreen> createState() => _OtakuOracleScreenState();
}

class _OtakuOracleScreenState extends State<OtakuOracleScreen> {
  final StorageService storage = StorageService();
  final TextEditingController searchController = TextEditingController();

  List<Anime> animes = [];
  List<Map<String, dynamic>> catalog = [];

  bool loading = true;
  String catalogMessage = '';

  static const Color background = Color(0xFF111318);
  static const Color panel = Color(0xFF1B1F28);

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final results = await Future.wait([storage.loadAnimes(), rootBundle.loadString('lib/anime_catalog.json')]);
      final saved = results[0] as List<Anime>;
      final decoded = jsonDecode(results[1] as String);
      if (decoded is! List) throw const FormatException('يجب أن تكون قاعدة البيانات قائمة JSON.');
      final entries = decoded.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      if (!mounted) return;
      setState(() { animes = saved; catalog = entries; catalogMessage = ''; loading = false; });
    } catch (e) {
      final saved = await storage.loadAnimes();
      if (!mounted) return;
      setState(() { animes = saved; catalog = []; catalogMessage = 'تعذرت قراءة قاعدة الأنمي.'; loading = false; });
    }
  }

  List<Anime> get ratedAnimes => animes.where((anime) => anime.rating > 0).toList();

  double get averageRating {
    if (ratedAnimes.isEmpty) return 0;
    return ratedAnimes.fold<double>(0, (sum, anime) => sum + anime.rating) / ratedAnimes.length; // 🔥 sum double
  }

  List<Anime> get favorites => animes.where((anime) => anime.favorite).toList();
  List<Anime> get highRated => ratedAnimes.where((anime) => anime.rating >= 8.0).toList(); // 🔥 8.0

  int get totalEpisodesWatched => animes.where((a) => a.status == 'مكتمل').fold<int>(0, (sum, a) => sum + a.episodes);

  double get completionRate {
    if (animes.isEmpty) return 0;
    final completed = animes.where((a) => a.status == 'مكتمل').length;
    return (completed / animes.length) * 100;
  }

  String normalize(String value) {
    return value.toLowerCase().replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا').replaceAll('ى', 'ي').replaceAll('ة', 'ه').replaceAll(RegExp(r'[\s\-_!.,:;؟?]+'), '');
  }

  String catalogTitle(Map<String, dynamic> item) => (item['title'] ?? '').toString();
  List<String> catalogAliases(Map<String, dynamic> item) { final value = item['aliases']; if (value is! List) return []; return value.map((e) => e.toString()).toList(); }
  List<String> catalogGenres(Map<String, dynamic> item) { final value = item['genres']; if (value is! List) return []; return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(); }

  Map<String, dynamic>? findCatalogAnime(String query) {
    final q = normalize(query);
    if (q.isEmpty) return null;
    for (final item in catalog) { final names = [catalogTitle(item), ...catalogAliases(item)]; for (final name in names) { if (normalize(name) == q) return item; } }
    return null;
  }

  Map<String, double> get genreScores { // 🔥 double scores
    final scores = <String, double>{};
    for (final anime in ratedAnimes) {
      final item = findCatalogAnime(anime.title);
      final genres = anime.genre.trim().isNotEmpty ? anime.genre.split(RegExp(r'[,،/|]')).map((g) => g.trim()).where((g) => g.isNotEmpty).toList() : item == null ? <String>[] : catalogGenres(item);
      for (final genre in genres) { scores[genre] = (scores[genre] ?? 0.0) + anime.rating; }
    }
    return scores;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = primaryColorNotifier.value;
    final query = searchController.text.trim();
    final libraryResults = animes.where((a) => normalize(a.title).contains(normalize(query))).toList();
    final databaseResults = catalog.where((i) => normalize(catalogTitle(i)).contains(normalize(query))).take(15).toList();

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(backgroundColor: primaryColor, foregroundColor: Colors.white, title: const Text('مرآة الأوتاكو', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildIntroduction(),
          const SizedBox(height: 16),
          if (catalogMessage.isNotEmpty) _messageCard(catalogMessage),
          _buildSearch(),
          if (query.isNotEmpty) ...[
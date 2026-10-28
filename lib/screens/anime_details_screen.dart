
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime.dart';

class AnimeDetailsScreen extends StatefulWidget {
  final Anime anime;

  const AnimeDetailsScreen({
    super.key,
    required this.anime,
  });

  @override
  State<AnimeDetailsScreen> createState() =>
      _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends State<AnimeDetailsScreen> {
  static const Color background = Color(0xFF111318);
  static const Color panel = Color(0xFF1B1F28);
  static const Color accent = Color(0xFF741C2B);

  final ImagePicker _picker = ImagePicker();

  String? _characterImagePath;
  bool _loading = true;
  bool _busy = false;

  String get _preferenceKey =>
      'anime_character_image_${widget.anime.id}';

  @override
  void initState() {
    super.initState();
    _loadCharacterImage();
  }

  Future<void> _loadCharacterImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_preferenceKey);

    if (!mounted) return;

    setState(() {
      _characterImagePath = path;
      _loading = false;
    });
  }

  Future<String> _copyImage(String sourcePath) async {
    final directory = await getApplicationDocumentsDirectory();

    final folder = Directory(
      '${directory.path}/anime_character_images',
    );

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final extension = sourcePath.contains('.')
        ? sourcePath.substring(sourcePath.lastIndexOf('.'))
        : '.jpg';

    final destination =
        '${folder.path}/${DateTime.now().microsecondsSinceEpoch}$extension';

    return (await File(sourcePath).copy(destination)).path;
  }

  Future<void> _chooseCharacterImage() async {
    if (_busy) return;

    setState(() => _busy = true);

    String? newPath;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) return;

      newPath = await _copyImage(picked.path);

      final prefs = await SharedPreferences.getInstance();
      final oldPath = _characterImagePath;

      final saved = await prefs.setString(
        _preferenceKey,
        newPath,
      );

      if (!saved) {
        try {
          await File(newPath).delete();
        } catch (_) {}
        newPath = null;
        throw Exception('تعذر حفظ مسار الصورة');
      }

      if (!mounted) return;

      setState(() => _characterImagePath = newPath);

      if (oldPath != null &&
          oldPath.isNotEmpty &&
          oldPath != newPath) {
        try {
          final oldFile = File(oldPath);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        } catch (_) {}
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ صورة الشخصية')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر اختيار الصورة أو حفظها'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeCharacterImage() async {
    final path = _characterImagePath;

    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.remove(_preferenceKey);

    if (!mounted) return;

    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذرت إزالة الصورة')),
      );
      return;
    }

    setState(() => _characterImagePath = null);

    if (path != null && path.isNotEmpty) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت إزالة صورة الشخصية')),
    );
  }

  Widget _section(String title, String value, IconData icon) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFFC857), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              height: 1.7,
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cover() {
    final path = widget.anime.imagePath;

    if (path != null &&
        path.isNotEmpty &&
        File(path).existsSync()) {
      return Image.file(
        File(path),
        width: double.infinity,
        height: 230,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _coverPlaceholder(),
      );
    }

    return _coverPlaceholder();
  }

  Widget _coverPlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      color: panel,
      child: const Icon(
        Icons.movie_creation_outlined,
        size: 65,
        color: Colors.white30,
      ),
    );
  }

  Widget _characterImage() {
    final path = _characterImagePath;

    if (path != null &&
        path.isNotEmpty &&
        File(path).existsSync()) {
      return Image.file(
        File(path),
        width: 110,
        height: 140,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _characterPlaceholder(),
      );
    }

    return _characterPlaceholder();
  }

  Widget _characterPlaceholder() {
    return Container(
      width: 110,
      height: 140,
      color: accent.withValues(alpha: 0.25),
      child: const Icon(
        Icons.person_outline,
        size: 48,
        color: Colors.white54,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anime = widget.anime;
    final title = anime.title.trim().isEmpty
        ? 'أنمي بدون اسم'
        : anime.title;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        title: const Text('تفاصيل الأنمي'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: _cover(),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (anime.status.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.bookmark_outline, size: 18),
                  label: Text(anime.status),
                ),
              if (anime.genre.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.category_outlined, size: 18),
                  label: Text(anime.genre),
                ),
              if (anime.episodes > 0)
                Chip(
                  avatar: const Icon(Icons.live_tv_outlined, size: 18),
                  label: Text('${anime.episodes} حلقة'),
                ),
              if (anime.rating > 0)
                const SizedBox.shrink(),
            ],
          ),
          if (anime.rating > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Color(0xFFFFC857)),
                const SizedBox(width: 5),
                Text(
                  '${anime.rating} / 5',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          _section(
            'ملخص القصة',
            anime.summary,
            Icons.menu_book_outlined,
          ),
          _section(
            'ذكرياتك مع الأنمي',
            anime.memory,
            Icons.auto_awesome_outlined,
          ),
          Container(
            padding: const EdgeInsets.all(15),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الشخصية المفضلة',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _loading
                          ? Container(
                              width: 110,
                              height: 140,
                              color: Colors.white10,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _characterImage(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            anime.character.trim().isEmpty
                                ? 'لم تحدد شخصية مفضلة'
                                : anime.character,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : _chooseCharacterImage,
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                            ),
                            icon: const Icon(Icons.add_photo_alternate),
                            label: Text(
                              _characterImagePath == null
                                  ? 'إضافة صورة'
                                  : 'تغيير الصورة',
                            ),
                          ),
                          if (_characterImagePath != null)
                            TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : _removeCharacterImage,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('إزالة الصورة'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

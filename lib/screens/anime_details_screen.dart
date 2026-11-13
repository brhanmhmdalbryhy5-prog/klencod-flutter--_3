import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../models/anime.dart';
import '../services/anime_api_service.dart';
import '../services/storage_service.dart';

class AnimeDetailsScreen extends StatefulWidget {
  final Anime anime;
  const AnimeDetailsScreen({super.key, required this.anime});

  @override
  State<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends State<AnimeDetailsScreen> {
  static const Color background = Color(0xFF111318);
  static const Color panel = Color(0xFF1B1F28);

  final ImagePicker _picker = ImagePicker();
  final AnimeApiService apiService = AnimeApiService();
  final StorageService storage = StorageService();
  final GlobalKey _cardKey = GlobalKey();

  late Anime currentAnime;

  String? _characterImagePath;
  bool _loading = true;
  bool _busy = false;
  
  List<Anime> subAnimes = [];
  bool _isSeasonGridView = false;
  static const String _seasonViewKey = 'season_view_grid';
  
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  String get _preferenceKey => 'anime_character_image_${currentAnime.id}';

  @override
  void initState() {
    super.initState();
    currentAnime = widget.anime;
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_preferenceKey);
    final savedView = prefs.getBool(_seasonViewKey);
    
    final allAnimes = await storage.loadAnimes();
    
    final index = allAnimes.indexWhere((a) => a.id == currentAnime.id);
    if (index != -1) {
      currentAnime = allAnimes[index];
    }

    List<Anime> relatedAnimes;
    if (currentAnime.parentId == null) {
      relatedAnimes = allAnimes.where((a) => a.parentId == currentAnime.id).toList();
    } else {
      final parent = allAnimes.where((a) => a.id == currentAnime.parentId).toList();
      final siblings = allAnimes.where((a) => a.parentId == currentAnime.parentId && a.id != currentAnime.id).toList();
      relatedAnimes = [...parent, ...siblings];
    }

    if (!mounted) return;
    setState(() {
      _characterImagePath = path;
      if (savedView != null) _isSeasonGridView = savedView;
      subAnimes = relatedAnimes;
      _loading = false;
    });
    
    if (currentAnime.videoPath != null && File(currentAnime.videoPath!).existsSync()) {
      _initializeVideo(currentAnime.videoPath!);
    }
  }

  Future<void> _toggleSeasonView() async {
    HapticFeedback.selectionClick();
    setState(() => _isSeasonGridView = !_isSeasonGridView);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seasonViewKey, _isSeasonGridView);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _initializeVideo(String path) {
    _videoController = VideoPlayerController.file(File(path))
      ..initialize().then((_) {
        _chewieController = ChewieController(videoPlayerController: _videoController!, autoPlay: false, looping: false, aspectRatio: _videoController!.value.aspectRatio);
        if (mounted) setState(() {});
      });
  }

  Future<void> _pickVideo() async {
    HapticFeedback.lightImpact();
    try {
      final picked = await _picker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return;
      final directory = await getApplicationDocumentsDirectory();
      final folder = Directory('${directory.path}/anime_videos');
      if (!await folder.exists()) await folder.create(recursive: true);
      final destination = '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.mp4';
      final savedFile = await File(picked.path).copy(destination);
      final allAnimes = await storage.loadAnimes();
      final index = allAnimes.indexWhere((a) => a.id == currentAnime.id);
      if (index != -1) {
        allAnimes[index].videoPath = savedFile.path;
        await storage.saveAnimes(allAnimes);
        setState(() { currentAnime.videoPath = savedFile.path; });
        _initializeVideo(savedFile.path);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر اختيار الفيديو.')));
    }
  }

  void _showImageZoom() {
    HapticFeedback.lightImpact();
    if (currentAnime.imagePath != null && File(currentAnime.imagePath!).existsSync()) {
      showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, insetPadding: EdgeInsets.zero, child: InteractiveViewer(panEnabled: true, minScale: 1.0, maxScale: 5.0, child: Image.file(File(currentAnime.imagePath!), fit: BoxFit.contain))));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد صورة محلية لتكبيرها.')));
    }
  }

  void _showCharacterImageZoom(String? imagePath, String? imageUrl) {
    HapticFeedback.lightImpact();
    Widget? imageWidget;
    if (imagePath != null && File(imagePath).existsSync()) {
      imageWidget = Image.file(File(imagePath), fit: BoxFit.contain);
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      imageWidget = Image.network(imageUrl, fit: BoxFit.contain);
    }
    if (imageWidget == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد صورة لعرضها.')));
      return;
    }
    showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(10), child: InteractiveViewer(panEnabled: true, minScale: 1.0, maxScale: 5.0, child: imageWidget!)));
  }

  Future<void> _editAnimeDetails() async {
    // ... (بقي كما هو)
    HapticFeedback.lightImpact();
    final titleController = TextEditingController(text: currentAnime.title);
    final partNameController = TextEditingController(text: currentAnime.partName ?? '');
    final episodesController = TextEditingController(text: currentAnime.episodes == 0 ? '' : '${currentAnime.episodes}');
    final watchedController = TextEditingController(text: currentAnime.watchedEpisodes == 0 ? '' : '${currentAnime.watchedEpisodes}');
    final studiosController = TextEditingController(text: currentAnime.studios ?? '');
    double rating = currentAnime.rating;
    String? newImagePath = currentAnime.imagePath;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: panel,
              title: Text(currentAnime.parentId != null ? 'تعديل الموسم/الفيلم' : 'تعديل الأنمي'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                        if (picked != null) {
                          final directory = await getApplicationDocumentsDirectory();
                          final folder = Directory('${directory.path}/anime_images');
                          if (!await folder.exists()) await folder.create(recursive: true);
                          final dest = '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
                          final saved = await File(picked.path).copy(dest);
                          setDialogState(() => newImagePath = saved.path);
                        }
                      },
                      child: Container(
                        height: 120, width: double.infinity,
                        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: primaryColorNotifier.value)),
                        child: newImagePath != null && File(newImagePath!).existsSync()
                            ? ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.file(File(newImagePath!), fit: BoxFit.cover))
                            : const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, size: 30), Text('إضافة صورة محلية')])),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: 'الاسم')),
                    const SizedBox(height: 10),
                    TextField(controller: studiosController, decoration: const InputDecoration(labelText: 'الاستوديو')),
                    if (currentAnime.parentId != null) ...[
                      const SizedBox(height: 10),
                      TextField(controller: partNameController, decoration: const InputDecoration(labelText: 'اسم الموسم')),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: episodesController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'إجمالي الحلقات'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: watchedController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'شاهدت'))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('تقييمك: ${rating.toStringAsFixed(1)}'),
                    Slider(value: rating, min: 0, max: 10, divisions: 20, onChanged: (v) => setDialogState(() => rating = v)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final allAnimes = await storage.loadAnimes();
      final index = allAnimes.indexWhere((a) => a.id == currentAnime.id);
      if (index != -1) {
        allAnimes[index]
          ..title = titleController.text.trim()
          ..partName = partNameController.text.trim()
          ..studios = studiosController.text.trim().isEmpty ? null : studiosController.text.trim()
          ..episodes = int.tryParse(episodesController.text) ?? 0
          ..watchedEpisodes = int.tryParse(watchedController.text) ?? 0
          ..rating = rating
          ..imagePath = newImagePath;
        await storage.saveAnimes(allAnimes);
        await _loadData();
      }
    }
  }

  Future<void> _deleteSubAnime(Anime sub) async {
    // ... (بقي كما هو)
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title: const Text('حذف الموسم/الفيلم؟'),
        content: Text('هل أنت متأكد من حذف "${sub.partName}" نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirm != true) return;
    final allAnimes = await storage.loadAnimes();
    await storage.permanentDelete(sub); 
    allAnimes.removeWhere((a) => a.id == sub.id);
    await storage.saveAnimes(allAnimes);
    await _loadData();
  }

  Future<void> _fetchMainImageOnly() async {
    // ... (بقي كما هو)
    if (currentAnime.title.trim().isEmpty) return;
    final hasNet = await _hasInternet();
    if (!hasNet) { /* show error */ return; }
    // ... (نفس المنطق السابق)
  }

  Future<void> _shareCardImage() async {
    // ... (بقي كما هو)
    HapticFeedback.mediumImpact();
    try {
      RenderRepaintBoundary boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/anime_card_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'أنمي: ${currentAnime.title}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر مشاركة البطاقة.')));
    }
  }

  Widget _buildShareCard() {
    // ... (بقي كما هو مع إضافة التوقيع BURHAN)
    final imagePath = currentAnime.imagePath;
    final fontName = fontNotifier.value;
    final titleColor = titleColorNotifier.value;
    TextStyle titleStyle;
    if (fontName == 'Cairo') titleStyle = GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor);
    else if (fontName == 'Tajawal') titleStyle = GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor);
    else if (fontName == 'Almarai') titleStyle = GoogleFonts.almarai(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor);
    else if (fontName == 'Changa') titleStyle = GoogleFonts.changa(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor);
    else titleStyle = TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor);
    final genres = currentAnime.genre.split('،').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final primaryColor = primaryColorNotifier.value;
    return RepaintBoundary(
      key: _cardKey,
      child: Container(
        width: 340,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: const Color(0xFF1B1F28)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              if (imagePath != null && File(imagePath).existsSync()) Positioned.fill(child: Image.file(File(imagePath), fit: BoxFit.cover)),
              Positioned.fill(child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: Container(color: Colors.black.withOpacity(0.7)))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)]),
                      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: imagePath != null && File(imagePath).existsSync() ? Image.file(File(imagePath), height: 220, fit: BoxFit.cover) : Container(height: 220, width: 150, color: Colors.black26, child: const Icon(Icons.movie, size: 60, color: Colors.white24))),
                    ),
                    const SizedBox(height: 20),
                    Text(currentAnime.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle.copyWith(shadows: [Shadow(color: Colors.black87, blurRadius: 10)])),
                    const SizedBox(height: 12),
                    if (genres.isNotEmpty) Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: genres.take(3).map((g) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: primaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryColor.withOpacity(0.5))), child: Text(g, style: const TextStyle(color: Colors.white, fontSize: 10)))).toList()),
                    const SizedBox(height: 20),
                    Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [if (currentAnime.rating > 0) _cardStat(Icons.star, '${currentAnime.rating.toStringAsFixed(1)}', 'تقييمك', const Color(0xFFFFC857)), if (currentAnime.globalRating != null) _cardStat(Icons.public, '${currentAnime.globalRating!.toStringAsFixed(1)}', 'عالمي', Colors.cyan), if (currentAnime.releaseYear != null) _cardStat(Icons.calendar_today, '${currentAnime.releaseYear}', 'السنة', Colors.white70), if (currentAnime.episodes > 0) _cardStat(Icons.play_circle_outline, '${currentAnime.episodes}', 'حلقة', primaryColor)])),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shield, size: 16, color: primaryColor), const SizedBox(width: 6), Text('ذاكرة الأوتاكو', style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2))]),
                    const SizedBox(height: 8),
                    Text('BURHAN', style: GoogleFonts.greatVibes(fontSize: 32, color: titleColor, shadows: [Shadow(color: titleColor.withOpacity(0.5), blurRadius: 8)])),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardStat(IconData icon, String value, String label, Color color) {
    return Column(children: [Icon(icon, color: color, size: 22), const SizedBox(height: 4), Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10))]);
  }

  void _showShareDialog() {
    // ... (بقي كما هو)
    HapticFeedback.lightImpact();
    showDialog(context: context, builder: (dialogContext) => Dialog(backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [_buildShareCard(), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.center, children: [ElevatedButton.icon(onPressed: () { Navigator.pop(dialogContext); _shareCardImage(); }, style: ElevatedButton.styleFrom(backgroundColor: primaryColorNotifier.value, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.share), label: const Text('مشاركة البطاقة', style: TextStyle(fontWeight: FontWeight.bold))), const SizedBox(width: 12), IconButton(onPressed: () => Navigator.pop(dialogContext), style: IconButton.styleFrom(backgroundColor: Colors.white12), icon: const Icon(Icons.close, color: Colors.white))])])));
  }

  Future<void> _incrementWatchedEpisode() async {
    // ... (بقي كما هو)
    HapticFeedback.lightImpact();
    if (currentAnime.episodes > 0 && currentAnime.watchedEpisodes >= currentAnime.episodes) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لقد أكملت جميع الحلقات!'))); return; }
    setState(() { currentAnime.watchedEpisodes++; });
    final allAnimes = await storage.loadAnimes();
    final index = allAnimes.indexWhere((a) => a.id == currentAnime.id);
    if (index != -1) { allAnimes[index] = currentAnime; await storage.saveAnimes(allAnimes); }
  }

  Future<void> _fetchDataManually() async {
    // ... (نفس المنطق السابق مع شريط التقدم)
    // ... ولكن مع إضافة حفظ شخصيات المواسم
    if (currentAnime.title.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الأنمي لا يملك اسماً'))); return; }
    final hasNet = await _hasInternet();
    if (!hasNet) { /* show error */ return; }
    
    // ... شريط التقدم كما في الرسالة السابقة ...
    
    // داخل الحلقة:
    final subData = data['subAnimes'] as List? ?? [];
    for (var sub in subData) {
      final existingIndex = allAnimes.indexWhere((a) => a.title == sub['title'] && a.parentId == currentAnime.id);
      if (existingIndex == -1) {
        final newSub = Anime(
          id: DateTime.now().microsecondsSinceEpoch.toString() + Random().nextInt(999).toString(),
          title: sub['title'], partName: sub['partName'], parentId: currentAnime.id,
          episodes: sub['episodes'] ?? 0, summary: sub['summary'] ?? '', genre: sub['genre'] ?? '',
          globalRating: sub['globalRating'], releaseYear: sub['releaseYear'],
          imageUrl: sub['imageUrl'], imagePath: sub['imagePath'],
          characters: (sub['characters'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [], // 🔥
        );
        allAnimes.add(newSub);
      } else {
        final existing = allAnimes[existingIndex];
        if (existing.globalRating == null && sub['globalRating'] != null) existing.globalRating = sub['globalRating'];
        if (existing.releaseYear == null && sub['releaseYear'] != null) existing.releaseYear = sub['releaseYear'];
        if (existing.imagePath == null && sub['imagePath'] != null) existing.imagePath = sub['imagePath'];
        if (existing.summary.isEmpty && (sub['summary'] ?? '').isNotEmpty) existing.summary = sub['summary'];
        if (existing.genre.isEmpty && (sub['genre'] ?? '').isNotEmpty) existing.genre = sub['genre'];
        if (existing.episodes == 0 && (sub['episodes'] ?? 0) > 0) existing.episodes = sub['episodes'];
        // 🔥 تحديث شخصيات الموسم إذا كانت فارغة
        if (existing.characters.isEmpty && (sub['characters'] as List?)?.isNotEmpty == true) {
          existing.characters = List<Map<String, dynamic>>.from(sub['characters']);
        }
      }
    }
    // ... حفظ
  }

  void _addSubAnime() {
    // ... (بقي كما هو)
  }

  Widget _section(String title, String value, IconData icon) {
    // ... (بقي كما هو)
    return const SizedBox();
  }

  Widget _buildCharacters() {
    // ... (بقي كما هو)
    return const SizedBox();
  }

  Widget _cover() {
    // ... (بقي كما هو)
    return const SizedBox();
  }

  Widget _buildSeasonGridCard(Anime sub) {
    // ... (بقي كما هو)
    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    // ... (بقي كما هو)
    return const SizedBox();
  }
}
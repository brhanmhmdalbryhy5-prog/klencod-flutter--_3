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

  String? _characterImagePath;
  bool _loading = true;
  bool _busy = false;
  
  List<Anime> subAnimes = [];
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  String get _preferenceKey => 'anime_character_image_${widget.anime.id}';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_preferenceKey);
    
    final allAnimes = await storage.loadAnimes();
    // جلب المواسم المرتبطة بهذا الأنمي
    final children = allAnimes.where((a) => a.parentId == widget.anime.id).toList();

    if (!mounted) return;
    setState(() {
      _characterImagePath = path;
      subAnimes = children;
      _loading = false;
    });
    
    if (widget.anime.videoPath != null && File(widget.anime.videoPath!).existsSync()) {
      _initializeVideo(widget.anime.videoPath!);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _initializeVideo(String path) {
    _videoController = VideoPlayerController.file(File(path))
      ..initialize().then((_) {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: false,
          looping: false,
          aspectRatio: _videoController!.value.aspectRatio,
        );
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
      final index = allAnimes.indexWhere((a) => a.id == widget.anime.id);
      if (index != -1) {
        allAnimes[index].videoPath = savedFile.path;
        await storage.saveAnimes(allAnimes);
        setState(() { widget.anime.videoPath = savedFile.path; });
        _initializeVideo(savedFile.path);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر اختيار الفيديو.')));
    }
  }

  void _showImageZoom() {
    HapticFeedback.lightImpact();
    if (widget.anime.imagePath == null || !File(widget.anime.imagePath!).existsSync()) return;
    
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 1.0,
          maxScale: 5.0,
          child: Image.file(File(widget.anime.imagePath!), fit: BoxFit.contain),
        ),
      ),
    );
  }

  Future<void> _shareCardImage() async {
    HapticFeedback.mediumImpact();
    try {
      RenderRepaintBoundary boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/anime_card_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'أنمي: ${widget.anime.title}');
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر مشاركة البطاقة.'))); }
    }
  }

  Widget _buildShareCard() {
    final anime = widget.anime;
    final primaryColor = primaryColorNotifier.value;
    final imagePath = anime.imagePath;
    final fontName = fontNotifier.value;
    final titleColor = titleColorNotifier.value;

    TextStyle titleStyle;
    if (fontName == 'Cairo') titleStyle = GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor);
    else if (fontName == 'Tajawal') titleStyle = GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor);
    else if (fontName == 'Almarai') titleStyle = GoogleFonts.almarai(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor);
    else if (fontName == 'Changa') titleStyle = GoogleFonts.changa(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor);
    else titleStyle = TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor);

    final genres = anime.genre.split('،').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    return RepaintBoundary(
      key: _cardKey,
      child: Container(
        width: 340,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: const Color(0xFF1B1F28)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              if (imagePath != null && File(imagePath).existsSync())
                Positioned.fill(child: Image.file(File(imagePath), fit: BoxFit.cover)),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(color: Colors.black.withOpacity(0.7)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: imagePath != null && File(imagePath).existsSync()
                            ? Image.file(File(imagePath), height: 220, fit: BoxFit.cover)
                            : Container(height: 220, width: 150, color: Colors.black26, child: const Icon(Icons.movie, size: 60, color: Colors.white24)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(anime.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle.copyWith(shadows: [Shadow(color: Colors.black87, blurRadius: 10)])),
                    const SizedBox(height: 12),
                    if (genres.isNotEmpty)
                      Wrap(
                        alignment: WrapAlignment.center, spacing: 6, runSpacing: 6,
                        children: genres.take(3).map((g) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: primaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryColor.withOpacity(0.5))),
                          child: Text(g, style: const TextStyle(color: Colors.white, fontSize: 10)),
                        )).toList(),
                      ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (anime.rating > 0) _cardStat(Icons.star, '${anime.rating.toStringAsFixed(1)}', 'تقييمك', const Color(0xFFFFC857)),
                          if (anime.globalRating != null) _cardStat(Icons.public, '${anime.globalRating!.toStringAsFixed(1)}', 'عالمي', Colors.cyan),
                          if (anime.releaseYear != null) _cardStat(Icons.calendar_today, '${anime.releaseYear}', 'السنة', Colors.white70),
                          if (anime.episodes > 0) _cardStat(Icons.play_circle_outline, '${anime.episodes}', 'حلقة', primaryColor),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shield, size: 16, color: primaryColor), const SizedBox(width: 6), Text('ذاكرة الأوتاكو', style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2))]),
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
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  void _showShareDialog() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildShareCard(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () { Navigator.pop(dialogContext); _shareCardImage(); },
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColorNotifier.value, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.share), label: const Text('مشاركة البطاقة', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  IconButton(onPressed: () => Navigator.pop(dialogContext), style: IconButton.styleFrom(backgroundColor: Colors.white12), icon: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _incrementWatchedEpisode() async {
    HapticFeedback.lightImpact();
    if (widget.anime.episodes > 0 && widget.anime.watchedEpisodes >= widget.anime.episodes) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لقد أكملت جميع الحلقات!')));
      return;
    }
    setState(() { widget.anime.watchedEpisodes++; });
    final allAnimes = await storage.loadAnimes();
    final index = allAnimes.indexWhere((a) => a.id == widget.anime.id);
    if (index != -1) { allAnimes[index] = widget.anime; await storage.saveAnimes(allAnimes); }
  }

  // 🔥 دالة الجلب الرئيسية (تقوم بإنشاء المواسم تلقائياً)
  Future<void> _fetchDataManually() async {
    if (widget.anime.title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الأنمي لا يملك اسماً، لا يمكن البحث عنه.')));
      return;
    }
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    final data = await apiService.fetchAnimeData(widget.anime.title);
    
    if (!mounted) return;
    Navigator.pop(context);
    
    final List<String> genres = data['genres'];
    final String summary = data['summary'];
    final int episodes = data['episodes'];
    final double? globalRating = data['globalRating'];
    final int? releaseYear = data['releaseYear'];
    final List<Map<String, dynamic>> subData = data['subAnimes'];

    // تحديث بيانات الأنمي الأصلي
    setState(() {
      if (genres.isNotEmpty) widget.anime.genre = genres.join('، ');
      if (summary.isNotEmpty) widget.anime.summary = summary;
      if (episodes > 0) widget.anime.episodes = episodes;
      if (globalRating != null) widget.anime.globalRating = globalRating;
      if (releaseYear != null) widget.anime.releaseYear = releaseYear;
    });

    final allAnimes = await storage.loadAnimes();
    final index = allAnimes.indexWhere((a) => a.id == widget.anime.id);
    if (index != -1) { allAnimes[index] = widget.anime; }

    // 🔥 إنشاء قوالب المواسم والأفلام
    if (subData.isNotEmpty) {
      for (var sub in subData) {
        // التأكد من عدم وجود الموسم مسبقاً
        final exists = allAnimes.any((a) => a.title == sub['title'] && a.parentId == widget.anime.id);
        if (!exists) {
          final newSub = Anime(
            id: DateTime.now().microsecondsSinceEpoch.toString() + Random().nextInt(999).toString(),
            title: sub['title'],
            partName: sub['type'],
            parentId: widget.anime.id, // يربطه بالأنمي الأصلي
            episodes: sub['episodes'] ?? 0,
          );
          allAnimes.add(newSub);
        }
      }
    }
    
    await storage.saveAnimes(allAnimes);
    await _loadData(); // تحديث الواجهة لإظهار المواسم

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم جلب البيانات وإنشاء قوالب المواسم بنجاح!')));
  }

  void _addSubAnime() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title: const Text('إضافة موسم أو فيلم يدوياً'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'اسم الموسم (مثلاً: الموسم الثاني)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final newSub = Anime(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                title: widget.anime.title,
                partName: controller.text.trim(),
                parentId: widget.anime.id,
              );
              final allAnimes = await storage.loadAnimes();
              allAnimes.add(newSub);
              await storage.saveAnimes(allAnimes);
              if (mounted) Navigator.pop(dialogContext);
              await _loadData();
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String value, IconData icon) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    final primaryColor = primaryColorNotifier.value;
    return Container(
      width: double.infinity, margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(15), border: Border.all(color: primaryColor.withOpacity(0.3), width: 1), boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: primaryColor, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(height: 1.7, color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anime = widget.anime;
    final title = anime.title.trim().isEmpty ? 'أنمي بدون اسم' : anime.title;
    final genres = anime.genre.split('،').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final primaryColor = primaryColorNotifier.value;
    
    double progress = anime.episodes > 0 ? (anime.watchedEpisodes / anime.episodes) : 0.0;
    if (progress > 1.0) progress = 1.0;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background, 
        title: const Text('تفاصيل الأنمي'), 
        centerTitle: true,
        actions: [
          IconButton(tooltip: 'صنع بطاقة للمشاركة', icon: const Icon(Icons.dashboard_customize_outlined, color: Colors.cyan), onPressed: _showShareDialog),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _showImageZoom,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    color: Colors.black26, constraints: const BoxConstraints(maxHeight: 350),
                    child: anime.imagePath != null && File(anime.imagePath!).existsSync()
                        ? Hero(tag: 'anime_image_${anime.id}', child: Image.file(File(anime.imagePath!), width: double.infinity, fit: BoxFit.contain))
                        : Container(height: 180, color: panel, child: const Icon(Icons.movie_creation_outlined, size: 65, color: Colors.white30)),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.zoom_in, color: Colors.white, size: 24),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: titleColorNotifier.value)),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (anime.status.isNotEmpty) Chip(avatar: const Icon(Icons.bookmark_outline, size: 18), label: Text(anime.status)),
              if (anime.releaseYear != null) Chip(avatar: const Icon(Icons.calendar_today, size: 16), label: Text('${anime.releaseYear}'), backgroundColor: primaryColor.withOpacity(0.2), side: BorderSide(color: primaryColor.withOpacity(0.5))),
              ...genres.map((genre) => Chip(avatar: const Icon(Icons.category_outlined, size: 18), label: Text(genre), backgroundColor: primaryColor.withOpacity(0.2), side: BorderSide(color: primaryColor.withOpacity(0.5)))),
              IconButton(tooltip: 'جلب البيانات والمواسم', onPressed: _fetchDataManually, icon: const Icon(Icons.cloud_download_outlined, color: Colors.cyan)),
            ],
          ),
          
          // 🔥 قسم المواسم يظهر فقط للأنمي الأصلي
          if (anime.parentId == null) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المواسم والأفلام المرتبطة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                TextButton.icon(onPressed: _addSubAnime, icon: const Icon(Icons.add, size: 16), label: const Text('إضافة يدوي')),
              ],
            ),
            const SizedBox(height: 10),
            if (subAnimes.isEmpty)
              const Text('لا توجد مواسم مضافة. اضغط على "جلب البيانات" للبحث عنها.', style: TextStyle(color: Colors.white54, fontSize: 12))
            else
              ...subAnimes.map((sub) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: primaryColor.withOpacity(0.2), child: const Icon(Icons.playlist_play, color: Colors.white)),
                  title: Text(sub.partName ?? 'موسم', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text(sub.episodes > 0 ? '${sub.episodes} حلقة' : 'غير محدد', style: const TextStyle(color: Colors.white54)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white38),
                  onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeDetailsScreen(anime: sub))); },
                ),
              )),
          ],

          const SizedBox(height: 22),
          
          // 🔥 شريط تقدم المشاهدة يظهر للأنمي الأصلي وللموسم أيضاً
          if (anime.episodes > 0) ...[
            Container(
              padding: const EdgeInsets.all(15), margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: primaryColor.withOpacity(0.4))),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('تقدم المشاهدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('${anime.watchedEpisodes} / ${anime.episodes}', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 12),
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(primaryColor))),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _incrementWatchedEpisode,
                      style: OutlinedButton.styleFrom(foregroundColor: primaryColor, side: BorderSide(color: primaryColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.add), label: const Text('شاهدت حلقة جديدة (+1)'),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Container(
            padding: const EdgeInsets.all(15), margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('تذكار فيديو', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.video_call, color: Colors.cyan), onPressed: _pickVideo),
                  ],
                ),
                if (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized)
                  AspectRatio(
                    aspectRatio: _chewieController!.videoPlayerController.value.aspectRatio,
                    child: Chewie(controller: _chewieController!),
                  )
                else
                  const Center(child: Text('لا يوجد فيديو مضاف. اضغط على الأيقونة لإضافة فيديو من المعرض.', style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center)),
              ],
            ),
          ),

          _section('ملخص القصة', anime.summary, Icons.menu_book_outlined),
          _section('ذكرياتك مع الأنمي', anime.memory, Icons.auto_awesome_outlined),
        ],
      ),
    );
  }
}
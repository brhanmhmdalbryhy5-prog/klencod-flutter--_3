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

  // 🔥 دالة فحص الاتصال بالإنترنت
  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
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
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent, insetPadding: EdgeInsets.zero,
          child: InteractiveViewer(
            panEnabled: true, minScale: 1.0, maxScale: 5.0,
            child: Image.file(File(currentAnime.imagePath!), fit: BoxFit.contain),
          ),
        ),
      );
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

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent, 
        insetPadding: const EdgeInsets.all(10),
        child: InteractiveViewer(
          panEnabled: true, minScale: 1.0, maxScale: 5.0,
          child: imageWidget!,
        ),
      ),
    );
  }

  Future<void> _editAnimeDetails() async {
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
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title: const Text('حذف الموسم/الفيلم؟'),
        content: Text('هل أنت متأكد من حذف "${sub.partName}" نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
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

  // 🔥 جلب صورة الغلاف مع شريط تقدم ورسالة خطأ
  Future<void> _fetchMainImageOnly() async {
    if (currentAnime.title.trim().isEmpty) return;

    final hasNet = await _hasInternet();
    if (!hasNet) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: panel,
          title: const Row(children: [
            Icon(Icons.wifi_off, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('لا يوجد إنترنت'),
          ]),
          content: const Text('يرجى تشغيل الاتصال بالإنترنت لجلب الصورة ثم المحاولة مرة أخرى.', style: TextStyle(height: 1.6)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
        ),
      );
      return;
    }

    final progressNotifier = ValueNotifier<double>(0.0);
    Timer? timer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: panel,
        content: ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image, size: 50, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              const Text('جاري جلب الصورة...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColorNotifier.value),
                ),
              ),
              const SizedBox(height: 8),
              Text('${(value * 100).toInt()}%', style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ),
        ),
      ),
    );

    timer = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (progressNotifier.value < 0.9) progressNotifier.value += 0.03;
    });

    Map<String, dynamic>? data;
    String? error;
    try {
      data = await apiService.fetchAnimeData(currentAnime.title, downloadImages: true)
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      error = 'انتهت مهلة الاتصال. يرجى المحاولة مجدداً.';
    } catch (e) {
      error = 'تعذر الاتصال بالخادم. تحقق من الإنترنت.';
    }

    timer.cancel();
    progressNotifier.value = 1.0;
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) Navigator.pop(context);

    if (error != null) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: panel,
          title: const Row(children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('تعذر الجلب'),
          ]),
          content: Text(error, style: const TextStyle(height: 1.6)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
        ),
      );
      return;
    }

    final imageUrl = data?['imageUrl'] as String?;
    final imagePath = data?['imagePath'] as String?;
    
    if (imageUrl != null) {
      setState(() { 
        currentAnime.imageUrl = imageUrl; 
        if (imagePath != null) currentAnime.imagePath = imagePath;
      });
      final allAnimes = await storage.loadAnimes();
      final index = allAnimes.indexWhere((a) => a.id == currentAnime.id);
      if (index != -1) {
        allAnimes[index].imageUrl = imageUrl;
        if (imagePath != null) allAnimes[index].imagePath = imagePath;
        await storage.saveAnimes(allAnimes);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم جلب وحفظ صورة الغلاف محلياً.')));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على صورة.')));
    }
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
      await Share.shareXFiles([XFile(file.path)], text: 'أنمي: ${currentAnime.title}');
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر مشاركة البطاقة.'))); }
    }
  }

  // 🔥 بناء البطاقة مع التوقيع
  Widget _buildShareCard() {
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
                    Text(currentAnime.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle.copyWith(shadows: [Shadow(color: Colors.black87, blurRadius: 10)])),
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
                          if (currentAnime.rating > 0) _cardStat(Icons.star, '${currentAnime.rating.toStringAsFixed(1)}', 'تقييمك', const Color(0xFFFFC857)),
                          if (currentAnime.globalRating != null) _cardStat(Icons.public, '${currentAnime.globalRating!.toStringAsFixed(1)}', 'عالمي', Colors.cyan),
                          if (currentAnime.releaseYear != null) _cardStat(Icons.calendar_today, '${currentAnime.releaseYear}', 'السنة', Colors.white70),
                          if (currentAnime.episodes > 0) _cardStat(Icons.play_circle_outline, '${currentAnime.episodes}', 'حلقة', primaryColor),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // توقيع التطبيق
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shield, size: 16, color: primaryColor), const SizedBox(width: 6), Text('ذاكرة الأوتاكو', style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2))]),
                    const SizedBox(height: 8),
                    // 🔥 التوقيع الخاص BURHAN
                    Text(
                      'BURHAN',
                      style: GoogleFonts.greatVibes(
                        fontSize: 32,
                        color: titleColor,
                        shadows: [Shadow(color: titleColor.withOpacity(0.5), blurRadius: 8)],
                      ),
                    ),
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
    if (currentAnime.episodes > 0 && currentAnime.watchedEpisodes >= currentAnime.episodes) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لقد أكملت جميع الحلقات!')));
      return;
    }
    setState(() { currentAnime.watchedEpisodes++; });
    final allAnimes = await storage.loadAnimes();
    final index = allAnimes.indexWhere((a) => a.id == currentAnime.id);
    if (index != -1) { allAnimes[index] = currentAnime; await storage.saveAnimes(allAnimes); }
  }

  // 🔥 دالة الجلب الرئيسية مع شريط تقدم ورسالة خطأ
  Future<void> _fetchDataManually() async {
    if (currentAnime.title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الأنمي لا يملك اسماً، لا يمكن البحث عنه.')));
      return;
    }

    // 1. فحص الاتصال بالإنترنت
    final hasNet = await _hasInternet();
    if (!hasNet) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: panel,
          title: const Row(children: [
            Icon(Icons.wifi_off, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('لا يوجد إنترنت'),
          ]),
          content: const Text('يرجى تشغيل الاتصال بالإنترنت لجلب البيانات ثم المحاولة مرة أخرى.', style: TextStyle(height: 1.6)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
        ),
      );
      return;
    }

    // 2. إظهار شريط التقدم
    final progressNotifier = ValueNotifier<double>(0.0);
    Timer? progressTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: panel,
        content: ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_download, size: 50, color: Colors.cyan),
              const SizedBox(height: 16),
              const Text('جاري جلب البيانات والصور...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColorNotifier.value),
                ),
              ),
              const SizedBox(height: 8),
              Text('${(value * 100).toInt()}%', style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ),
        ),
      ),
    );

    progressTimer = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (progressNotifier.value < 0.9) progressNotifier.value += 0.02;
    });

    // 3. تنفيذ الجلب مع معالجة الأخطاء
    Map<String, dynamic>? data;
    String? errorMessage;
    try {
      data = await apiService.fetchAnimeData(currentAnime.title, downloadImages: true)
          .timeout(const Duration(seconds: 120));
    } on TimeoutException {
      errorMessage = 'انتهت مهلة الاتصال بالخادم. يرجى التحقق من الإنترنت والمحاولة مجدداً.';
    } catch (e) {
      errorMessage = 'تعذر الاتصال بالخادم. يرجى التحقق من اتصالك بالإنترنت.';
    }

    progressTimer.cancel();
    progressNotifier.value = 1.0;
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) Navigator.pop(context);

    // 4. إظهار رسالة خطأ إن وجدت
    if (errorMessage != null) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: panel,
          title: const Row(children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('تعذر الجلب'),
          ]),
          content: Text(errorMessage!, style: const TextStyle(height: 1.6)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
        ),
      );
      return;
    }

    if (data == null) return;

    final genres = data['genres'] as List;
    final summary = data['summary'] as String;
    final episodes = data['episodes'] as int;
    final subAnimesData = data['subAnimes'] as List;
    final charactersData = data['characters'] as List;

    // 5. التحقق من وجود بيانات فعلية
    if (genres.isEmpty && summary.isEmpty && episodes == 0 && subAnimesData.isEmpty && charactersData.isEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: panel,
          title: const Row(children: [
            Icon(Icons.search_off, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('لا توجد نتائج'),
          ]),
          content: const Text('لم يتم العثور على بيانات لهذا الأنمي. تأكد من كتابة الاسم بالإنجليزية بشكل صحيح.', style: TextStyle(height: 1.6)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
        ),
      );
      return;
    }

    // 6. تحديث بيانات الأنمي
    final double? globalRating = data['globalRating'];
    final int? releaseYear = data['releaseYear'];
    final String? studios = data['studios'];
    final String? mainImagePath = data['imagePath'];

    setState(() {
      if (genres.isNotEmpty) currentAnime.genre = genres.join('، ');
      if (summary.isNotEmpty) currentAnime.summary = summary;
      if (episodes > 0) currentAnime.episodes = episodes;
      if (globalRating != null) currentAnime.globalRating = globalRating;
      if (releaseYear != null) currentAnime.releaseYear = releaseYear;
      if (studios != null) currentAnime.studios = studios;
      if (mainImagePath != null && currentAnime.imagePath == null) currentAnime.imagePath = mainImagePath;
      if (charactersData.isNotEmpty) currentAnime.characters = List<Map<String, dynamic>>.from(charactersData);
    });

    final allAnimes = await storage.loadAnimes();
    final index = allAnimes.indexWhere((a) => a.id == currentAnime.id);
    if (index != -1) { allAnimes[index] = currentAnime; }

    // 7. معالجة المواسم
    if (subAnimesData.isNotEmpty) {
      for (var sub in subAnimesData) {
        final existingIndex = allAnimes.indexWhere((a) => a.title == sub['title'] && a.parentId == currentAnime.id);
        
        if (existingIndex == -1) {
          final newSub = Anime(
            id: DateTime.now().microsecondsSinceEpoch.toString() + Random().nextInt(999).toString(),
            title: sub['title'],
            partName: sub['partName'],
            parentId: currentAnime.id,
            episodes: sub['episodes'] ?? 0,
            summary: sub['summary'] ?? '',
            genre: sub['genre'] ?? '',
            globalRating: sub['globalRating'],
            releaseYear: sub['releaseYear'],
            imageUrl: sub['imageUrl'],
            imagePath: sub['imagePath'],
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
        }
      }
    }
    
    await storage.saveAnimes(allAnimes);
    await _loadData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم جلب البيانات وحفظ الصور محلياً!')));
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
                title: currentAnime.title,
                partName: controller.text.trim(),
                parentId: currentAnime.id,
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

  Widget _buildCharacters() {
    if (currentAnime.characters.isEmpty) return const SizedBox.shrink();
    final primaryColor = primaryColorNotifier.value;

    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: primaryColor.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.people, color: primaryColor, size: 20), const SizedBox(width: 8), const Text('الشخصيات الرئيسية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: currentAnime.characters.length,
              itemBuilder: (context, index) {
                final char = currentAnime.characters[index];
                final imgPath = char['imagePath'] as String?;
                final imgUrl = char['imageUrl'] as String?;
                
                ImageProvider? imageProvider;
                if (imgPath != null && File(imgPath).existsSync()) {
                  imageProvider = FileImage(File(imgPath));
                } else if (imgUrl != null && imgUrl.isNotEmpty) {
                  imageProvider = NetworkImage(imgUrl);
                }

                return Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _showCharacterImageZoom(imgPath, imgUrl),
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: Colors.white10,
                          backgroundImage: imageProvider,
                          child: imageProvider == null ? const Icon(Icons.person, color: Colors.white54, size: 30) : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 85,
                        child: Text(
                          char['name'] ?? '',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _cover() {
    final path = currentAnime.imagePath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return Container(
        color: Colors.black26, constraints: const BoxConstraints(maxHeight: 350),
        child: Hero(tag: 'anime_image_${currentAnime.id}', child: Image.file(File(path), width: double.infinity, fit: BoxFit.contain)),
      );
    }
    return Container(height: 180, width: double.infinity, color: panel, child: const Icon(Icons.movie_creation_outlined, size: 65, color: Colors.white30));
  }

  Widget _buildSeasonGridCard(Anime sub) {
    final hasLocalImage = sub.imagePath != null && sub.imagePath!.isNotEmpty && File(sub.imagePath!).existsSync();
    final primaryColor = primaryColorNotifier.value;
    final isOriginal = sub.parentId == null;

    return Container(
      decoration: BoxDecoration(
        color: panel, borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: isOriginal ? primaryColor.withOpacity(0.5) : Colors.white12, width: isOriginal ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeDetailsScreen(anime: sub)));
          await _loadData();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: hasLocalImage
                        ? Image.file(File(sub.imagePath!), fit: BoxFit.cover)
                        : Container(color: primaryColor.withOpacity(0.2), child: const Icon(Icons.playlist_play, color: Colors.white)),
                  ),
                  Positioned(
                    top: 2, right: 2,
                    child: Material(
                      color: Colors.black54, borderRadius: BorderRadius.circular(30),
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        onPressed: () => _deleteSubAnime(sub),
                      ),
                    ),
                  ),
                  if (isOriginal)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(6)),
                        child: const Text('الأصلي', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sub.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    '${sub.partName ?? 'الأنمي الأصلي'}${sub.releaseYear != null ? ' • ${sub.releaseYear}' : ''}${sub.episodes > 0 ? ' • ${sub.episodes} حلقة' : ''}',
                    maxLines: 2, overflow: TextOverflow.ellipsis, 
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                  if (sub.globalRating != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.public, size: 12, color: Colors.cyan),
                      const SizedBox(width: 3),
                      Text(sub.globalRating!.toStringAsFixed(1), style: const TextStyle(color: Colors.cyan, fontSize: 10, fontWeight: FontWeight.bold)),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = currentAnime.title.trim().isEmpty ? 'أنمي بدون اسم' : currentAnime.title;
    final genres = currentAnime.genre.split('،').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final primaryColor = primaryColorNotifier.value;
    
    double progress = currentAnime.episodes > 0 ? (currentAnime.watchedEpisodes / currentAnime.episodes) : 0.0;
    if (progress > 1.0) progress = 1.0;

    final isOriginalAnime = currentAnime.parentId == null;
    final sectionTitle = isOriginalAnime ? 'المواسم والأفلام المرتبطة' : 'الأجزاء الأخرى من السلسلة';

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background, 
        title: Text(isOriginalAnime ? 'تفاصيل الأنمي' : 'تفاصيل الموسم/الفيلم'), 
        centerTitle: true,
        actions: [
          IconButton(tooltip: 'تعديل البيانات', icon: const Icon(Icons.edit, color: Colors.white70), onPressed: _editAnimeDetails),
          if (isOriginalAnime)
            IconButton(tooltip: 'جلب صورة الغلاف من الإنترنت', icon: const Icon(Icons.image, color: Colors.orangeAccent), onPressed: _fetchMainImageOnly),
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
                ClipRRect(borderRadius: BorderRadius.circular(18), child: _cover()),
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
          if (currentAnime.partName != null && currentAnime.partName!.isNotEmpty)
            Text(currentAnime.partName!, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: primaryColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (currentAnime.status.isNotEmpty) Chip(avatar: const Icon(Icons.bookmark_outline, size: 18), label: Text(currentAnime.status)),
              if (currentAnime.releaseYear != null) Chip(avatar: const Icon(Icons.calendar_today, size: 16), label: Text('${currentAnime.releaseYear}'), backgroundColor: primaryColor.withOpacity(0.2), side: BorderSide(color: primaryColor.withOpacity(0.5))),
              if (currentAnime.studios != null && currentAnime.studios!.isNotEmpty) 
                Chip(avatar: const Icon(Icons.business, size: 16), label: Text(currentAnime.studios!), backgroundColor: primaryColor.withOpacity(0.2), side: BorderSide(color: primaryColor.withOpacity(0.5))),
              ...genres.map((genre) => Chip(avatar: const Icon(Icons.category_outlined, size: 18), label: Text(genre), backgroundColor: primaryColor.withOpacity(0.2), side: BorderSide(color: primaryColor.withOpacity(0.5)))),
              IconButton(tooltip: 'جلب البيانات والمواسم', onPressed: _fetchDataManually, icon: const Icon(Icons.cloud_download_outlined, color: Colors.cyan)),
            ],
          ),
          
          if (subAnimes.isNotEmpty || isOriginalAnime) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(sectionTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                Row(
                  children: [
                    IconButton(
                      tooltip: _isSeasonGridView ? 'عرض قائمة' : 'عرض شبكة',
                      icon: Icon(_isSeasonGridView ? Icons.view_list : Icons.grid_view, color: Colors.white70, size: 20),
                      onPressed: _toggleSeasonView,
                    ),
                    if (isOriginalAnime)
                      TextButton.icon(onPressed: _addSubAnime, icon: const Icon(Icons.add, size: 16), label: const Text('إضافة')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (subAnimes.isEmpty)
              const Text('لا توجد مواسم مضافة. اضغط على "جلب البيانات" للبحث عنها.', style: TextStyle(color: Colors.white54, fontSize: 12))
            else if (_isSeasonGridView)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subAnimes.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.75,
                ),
                itemBuilder: (context, index) => _buildSeasonGridCard(subAnimes[index]),
              )
            else
              ...subAnimes.map((sub) {
                final hasLocalImage = sub.imagePath != null && sub.imagePath!.isNotEmpty && File(sub.imagePath!).existsSync();
                final isOriginal = sub.parentId == null;
                
                List<String> subtitleParts = [];
                if (isOriginal) {
                  subtitleParts.add('الأنمي الأصلي');
                } else if (sub.partName != null) {
                  subtitleParts.add(sub.partName!);
                }
                if (sub.releaseYear != null) subtitleParts.add('${sub.releaseYear}');
                if (sub.episodes > 0) subtitleParts.add('${sub.episodes} حلقة');
                if (subtitleParts.isEmpty) subtitleParts.add('غير محدد');
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: panel, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isOriginal ? primaryColor.withOpacity(0.5) : Colors.white12, width: isOriginal ? 2 : 1),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: hasLocalImage
                          ? Image.file(File(sub.imagePath!), width: 50, height: 50, fit: BoxFit.cover)
                          : Container(width: 50, height: 50, color: primaryColor.withOpacity(0.2), child: const Icon(Icons.playlist_play, color: Colors.white)),
                    ),
                    title: Text(
                      sub.title, 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: isOriginal ? primaryColor : Colors.white,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(subtitleParts.join(' • '), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ),
                        if (sub.globalRating != null) ...[
                          const Icon(Icons.public, size: 12, color: Colors.cyan),
                          const SizedBox(width: 3),
                          Text(sub.globalRating!.toStringAsFixed(1), style: const TextStyle(color: Colors.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _deleteSubAnime(sub),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white38),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeDetailsScreen(anime: sub)));
                      await _loadData();
                    },
                  ),
                );
              }),
          ],

          const SizedBox(height: 22),
          
          if (currentAnime.episodes > 0) ...[
            Container(
              padding: const EdgeInsets.all(15), margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: primaryColor.withOpacity(0.4))),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('تقدم المشاهدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('${currentAnime.watchedEpisodes} / ${currentAnime.episodes}', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))]),
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

          _buildCharacters(),

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

          _section('ملخص القصة', currentAnime.summary, Icons.menu_book_outlined),
          _section('ذكرياتك مع الأنمي', currentAnime.memory, Icons.auto_awesome_outlined),
        ],
      ),
    );
  }
}
import 'dart:io';
import 'dart:math'; // 🔥 تمت إضافة هذا السطر لعملية الخلط العشوائي

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../models/anime.dart';
import '../services/storage_service.dart';
import '../services/anime_api_service.dart';
import 'anime_details_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final StorageService storage = StorageService();
  final AnimeApiService apiService = AnimeApiService();
  final TextEditingController searchController = TextEditingController();
  final ImagePicker imagePicker = ImagePicker();
  
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  static const String _sortKey = 'anime_library_sort';
  static const String _viewKey = 'anime_library_view';

  final List<String> allGenres = const [
    'أكشن', 'مغامرة', 'كوميدي', 'دراما', 'فانتازيا', 'رعب',
    'إيتشي', 'ميكا', 'غموض', 'رومانسي', 'خيال علمي', 'شريحة من الحياة',
    'رياضة', 'إثارة', 'حريم', 'مدرسي', 'شونين', 'سينين',
    'جوسي', 'شوجو', 'قوى خارقة', 'تاريخي', 'موسيقي', 'نفسي',
    'فامباير', 'سحر', 'حربي', 'فضاء', 'بوليسي', 'عائلي',
    'ألعاب', 'فنون قتالية', 'ساموراي', 'شياطين', 'إيسيكاي',
  ];

  List<Anime> animes = [];
  String selectedStatus = 'الكل';
  double selectedRatingFilter = 0;
  String searchText = '';
  String sortMode = 'newest';
  int viewMode = 0;
  bool loading = true;

  final List<Color> colors = const [
    Color(0xFF741C2B), Color(0xFF247BA0), Color(0xFF8B65C6),
    Color(0xFFB87928), Color(0xFF27866F), Color(0xFFB34E68),
  ];

  @override
  void initState() {
    super.initState();
    loadAnimes();
    _loadLibraryPreferences();
    _scrollController.addListener(() {
      if (_scrollController.offset > 300 && !_showBackToTop) {
        setState(() => _showBackToTop = true);
      } else if (_scrollController.offset <= 300 && _showBackToTop) {
        setState(() => _showBackToTop = false);
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => searchText = value);
  }

  Future<void> _loadLibraryPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        sortMode = prefs.getString(_sortKey) ?? 'newest';
        viewMode = prefs.getInt(_viewKey) ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _saveLibraryPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sortKey, sortMode);
      await prefs.setInt(_viewKey, viewMode);
    } catch (_) {}
  }

  Future<void> loadAnimes() async {
    try {
      final data = await storage.loadAnimes();
      if (!mounted) return;
      setState(() { 
        animes = data.where((a) => a.parentId == null).toList(); 
        loading = false; 
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحميل مكتبة الأنمي')));
    }
  }

  List<Anime> get filteredAnimes {
    final query = searchText.trim().toLowerCase();
    final result = animes.where((anime) {
      final matchesSearch = anime.title.toLowerCase().contains(query) || 
                            anime.genre.toLowerCase().contains(query) || 
                            anime.character.toLowerCase().contains(query);
      
      bool matchesStatus = false;
      if (selectedStatus == 'الكل') {
        matchesStatus = true;
      } else if (selectedStatus == 'المفضلة') {
        matchesStatus = anime.favorite;
      } else if (selectedStatus == 'جُلب تلقائياً') {
        matchesStatus = anime.genre.isNotEmpty && !anime.genre.contains('، ');
      } else if (selectedStatus == 'بدون تصنيف') {
        matchesStatus = anime.genre.trim().isEmpty;
      } else if (selectedStatus == 'قيد المشاهدة (تقدم)') {
        matchesStatus = anime.watchedEpisodes > 0 && (anime.episodes == 0 || anime.watchedEpisodes < anime.episodes);
      } else {
        matchesStatus = anime.status == selectedStatus;
      }

      bool matchesRating = true;
      if (selectedRatingFilter > 0) {
        matchesRating = anime.rating == selectedRatingFilter;
      }

      return matchesSearch && matchesStatus && matchesRating;
    }).toList();

    switch (sortMode) {
      case 'oldest': result.sort((a, b) => _dateOf(a).compareTo(_dateOf(b))); break;
      case 'titleAsc': result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())); break;
      case 'titleDesc': result.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase())); break;
      case 'rating': result.sort((a, b) => b.rating.compareTo(a.rating)); break;
      case 'favorites': result.sort((a, b) { final favoriteOrder = (b.favorite ? 1 : 0).compareTo(a.favorite ? 1 : 0); if (favoriteOrder != 0) return favoriteOrder; return _dateOf(b).compareTo(_dateOf(a)); }); break;
      case 'random': result.shuffle(Random()); break; // 🔥 الترتيب العشوائي هنا
      case 'newest': default: result.sort((a, b) => _dateOf(b).compareTo(_dateOf(a))); break;
    }
    return result;
  }

  DateTime _dateOf(Anime anime) {
    final index = animes.indexWhere((item) => item.id == anime.id);
    return DateTime.fromMillisecondsSinceEpoch(index < 0 ? 0 : index);
  }

  String get sortLabel {
    switch (sortMode) {
      case 'oldest': return 'الأقدم إضافة';
      case 'titleAsc': return 'الاسم: أ ← ي';
      case 'titleDesc': return 'الاسم: ي ← أ';
      case 'rating': return 'الأعلى تقييمًا';
      case 'favorites': return 'المفضلة أولًا';
      case 'random': return 'عشوائي'; // 🔥 اسم الترتيب العشوائي
      default: return 'الأحدث إضافة';
    }
  }

  Future<String> _saveImageLocally(String sourcePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagesDirectory = Directory('${directory.path}/anime_images');
    if (!await imagesDirectory.exists()) await imagesDirectory.create(recursive: true);
    final extension = sourcePath.contains('.') ? sourcePath.substring(sourcePath.lastIndexOf('.')) : '.jpg';
    final destinationPath = '${imagesDirectory.path}/${DateTime.now().microsecondsSinceEpoch}$extension';
    return (await File(sourcePath).copy(destinationPath)).path;
  }

  Future<String?> _pickAndSaveImage() async {
    try {
      final picked = await imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return null;
      return await _saveImageLocally(picked.path);
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر اختيار الصورة أو حفظها.')));
      return null;
    }
  }

  Widget _animeImage(Anime anime, Color color, {bool compact = false}) {
    final path = anime.imagePath;
    Widget imageWidget;

    if (path != null && path.isNotEmpty) {
      imageWidget = Image.file(File(path), width: compact ? double.infinity : 76, height: compact ? 160 : 96, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imagePlaceholder(color, compact: compact));
    } else {
      imageWidget = _imagePlaceholder(color, compact: compact);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Hero(
        tag: 'anime_image_${anime.id}',
        child: imageWidget,
      ),
    );
  }

  Widget _imagePlaceholder(Color color, {bool compact = false}) {
    return Container(
      width: compact ? double.infinity : 76,
      height: compact ? 160 : 96,
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(13)),
      child: Icon(Icons.movie_creation_outlined, color: color, size: 32),
    );
  }

  Future<void> openAnimeDetails(Anime anime) async {
    HapticFeedback.lightImpact();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeDetailsScreen(anime: anime)));
    if (mounted) await loadAnimes();
  }

  Future<void> moveToTrash(Anime anime) async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('نقل إلى سلة المهملات؟'),
        content: Text('هل تريد نقل "${anime.title.isEmpty ? 'أنمي بدون اسم' : anime.title}" إلى سلة المهملات؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: primaryColorNotifier.value), onPressed: () => Navigator.pop(dialogContext, true), child: const Text('نقل')),
        ],
      ),
    );

    if (confirm != true) return;

    final saved = await storage.moveToTrash(animes, anime.id);
    if (!mounted) return;
    if (saved) await loadAnimes();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved ? 'تم نقل الأنمي إلى السلة' : 'تعذر حفظ العملية')));
  }

  Future<void> toggleFavorite(Anime anime) async {
    HapticFeedback.selectionClick();
    final oldValue = anime.favorite;
    setState(() => anime.favorite = !oldValue);
    final saved = await storage.saveAnimes(animes);
    if (!mounted) return;
    if (!saved) {
      setState(() => anime.favorite = oldValue);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ التغيير')));
    } else {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(anime.favorite ? 'أضيف إلى المفضلة' : 'أزيل من المفضلة')));
    }
  }

  Future<void> _fetchDataManually(Anime anime) async {
    if (anime.title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الأنمي لا يملك اسماً، لا يمكن البحث عنه.')));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    final data = await apiService.fetchAnimeData(anime.title);

    if (!mounted) return;
    Navigator.pop(context);

    final List<String> genres = data['genres'];
    final String summary = data['summary'];
    final int episodes = data['episodes'];
    final double? globalRating = data['globalRating'];
    final int? releaseYear = data['releaseYear'];

    if (genres.isNotEmpty || summary.isNotEmpty || episodes > 0 || globalRating != null || releaseYear != null) {
      setState(() {
        if (genres.isNotEmpty) anime.genre = genres.join('، ');
        if (summary.isNotEmpty) anime.summary = summary;
        if (episodes > 0) anime.episodes = episodes;
        if (globalRating != null) anime.globalRating = globalRating;
        if (releaseYear != null) anime.releaseYear = releaseYear;
      });
      await storage.saveAnimes(animes);
      if (!mounted) return;
      
      String msg = 'تم جلب ';
      if (genres.isNotEmpty) msg += 'التصنيفات ';
      if (summary.isNotEmpty) msg += 'والقصة ';
      if (episodes > 0) msg += 'والحلقات ';
      if (globalRating != null) msg += 'والتقييم ';
      if (releaseYear != null) msg += 'والسنة ';
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على بيانات. تأكد من كتابة الاسم بالإنجليزية.')));
    }
  }

  Future<List<String>?> _showGenrePicker(List<String> currentGenres) async {
    final selected = Set<String>.from(currentGenres);
    return showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B1F28),
              title: const Text('اختر التصنيفات'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allGenres.length,
                  itemBuilder: (context, index) {
                    final genre = allGenres[index];
                    return CheckboxListTile(
                      title: Text(genre),
                      value: selected.contains(genre),
                      activeColor: primaryColorNotifier.value,
                      checkColor: Colors.white,
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) selected.add(genre);
                          else selected.remove(genre);
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
                FilledButton(style: FilledButton.styleFrom(backgroundColor: primaryColorNotifier.value), onPressed: () => Navigator.pop(dialogContext, selected.toList()), child: const Text('تأكيد')),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> editAnime(Anime anime) async {
    HapticFeedback.lightImpact();
    final titleController = TextEditingController(text: anime.title);
    final characterController = TextEditingController(text: anime.character);
    final episodesController = TextEditingController(text: anime.episodes == 0 ? '' : '${anime.episodes}');
    final watchedController = TextEditingController(text: anime.watchedEpisodes == 0 ? '' : '${anime.watchedEpisodes}');
    final summaryController = TextEditingController(text: anime.summary);
    final memoryController = TextEditingController(text: anime.memory);
    final yearController = TextEditingController(text: anime.releaseYear?.toString() ?? '');

    String status = anime.status;
    double rating = anime.rating;
    String? imagePath = anime.imagePath;
    bool imageChanged = false;
    List<String> selectedGenres = anime.genre.split('،').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF1B1F28),
                title: const Text('تعديل الأنمي'),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final pickedPath = await _pickAndSaveImage();
                            if (pickedPath != null) setDialogState(() { imagePath = pickedPath; imageChanged = true; });
                          },
                          child: Container(
                            height: 145, width: double.infinity,
                            decoration: BoxDecoration(color: const Color(0xFF111318), borderRadius: BorderRadius.circular(14), border: Border.all(color: primaryColorNotifier.value)),
                            clipBehavior: Clip.antiAlias,
                            child: imagePath != null && File(imagePath!).existsSync()
                                ? Image.file(File(imagePath!), fit: BoxFit.cover)
                                : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_outlined, size: 36), SizedBox(height: 8), Text('اختيار صورة (اختياري)')]),
                          ),
                        ),
                        if (imagePath != null)
                          TextButton.icon(onPressed: () => setDialogState(() { imagePath = null; imageChanged = true; }), icon: const Icon(Icons.delete_outline), label: const Text('إزالة الصورة')),
                        const SizedBox(height: 12),
                        TextField(controller: titleController, decoration: const InputDecoration(labelText: 'اسم الأنمي (اختياري)')),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () async {
                            final newGenres = await _showGenrePicker(selectedGenres);
                            if (newGenres != null) setDialogState(() => selectedGenres = newGenres);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'التصنيفات (اختياري)', suffixIcon: Icon(Icons.arrow_drop_down)),
                            child: Text(selectedGenres.isEmpty ? 'لم يتم اختيار تصنيف' : selectedGenres.join('، '), style: TextStyle(color: selectedGenres.isEmpty ? Colors.white38 : Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(controller: characterController, decoration: const InputDecoration(labelText: 'الشخصية المفضلة (اختياري)')),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: episodesController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'إجمالي الحلقات'))),
                            const SizedBox(width: 10),
                            Expanded(child: TextField(controller: watchedController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'شاهدت منها', prefixIcon: Icon(Icons.play_arrow, size: 16)))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(controller: yearController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سنة النزول')),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: ['', 'مكتمل', 'أتابعه', 'مخطط له', 'متوقف'].contains(status) ? status : '',
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'حالة المشاهدة (اختياري)'),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('لم أحدد')),
                            DropdownMenuItem(value: 'مكتمل', child: Text('مكتمل')),
                            DropdownMenuItem(value: 'أتابعه', child: Text('أتابعه')),
                            DropdownMenuItem(value: 'مخطط له', child: Text('مخطط له')),
                            DropdownMenuItem(value: 'متوقف', child: Text('متوقف')),
                          ],
                          onChanged: (value) { if (value != null) setDialogState(() => status = value); },
                        ),
                        const SizedBox(height: 14),
                        Column(
                          children: [
                            Text('تقييمك: ${rating.toStringAsFixed(1)} / 10', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColorNotifier.value, fontSize: 16)),
                            Slider(
                              value: rating, min: 0, max: 10, divisions: 20, label: rating.toStringAsFixed(1), activeColor: const Color(0xFFFFC857),
                              onChanged: (value) { setDialogState(() => rating = value); },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(controller: summaryController, maxLines: 3, decoration: const InputDecoration(labelText: 'ملخص القصة (اختياري)')),
                        const SizedBox(height: 10),
                        TextField(controller: memoryController, maxLines: 3, decoration: const InputDecoration(labelText: 'ذكرياتك (اختياري)')),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: primaryColorNotifier.value),
                    onPressed: () { HapticFeedback.lightImpact(); Navigator.pop(dialogContext, true); },
                    child: const Text('حفظ التعديلات')
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != true) {
        if (imageChanged && imagePath != null && imagePath != anime.imagePath) {
          try { final file = File(imagePath!); if (await file.exists()) await file.delete(); } catch (_) {}
        }
        return;
      }

      final oldImagePath = anime.imagePath;
      anime
        ..title = titleController.text.trim()
        ..genre = selectedGenres.join('، ')
        ..character = characterController.text.trim()
        ..episodes = int.tryParse(episodesController.text) ?? 0
        ..watchedEpisodes = int.tryParse(watchedController.text) ?? 0
        ..releaseYear = int.tryParse(yearController.text)
        ..status = status
        ..rating = rating
        ..summary = summaryController.text.trim()
        ..memory = memoryController.text.trim()
        ..imagePath = imagePath;

      final saved = await storage.saveAnimes(animes);
      if (!mounted) return;

      if (saved) {
        if (imageChanged && oldImagePath != null && oldImagePath.isNotEmpty && oldImagePath != imagePath) {
          try { final oldFile = File(oldImagePath); if (await oldFile.exists()) await oldFile.delete(); } catch (_) {}
        }
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ تعديلات الأنمي')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ التعديلات')));
      }
    } finally {
      titleController.dispose();
      characterController.dispose();
      episodesController.dispose();
      watchedController.dispose();
      summaryController.dispose();
      memoryController.dispose();
      yearController.dispose();
    }
  }

  Widget _buildAnimeTitle(String title, {double fontSize = 16, bool lightText = false}) {
    final fontName = fontNotifier.value;
    final titleColor = titleColorNotifier.value;
    
    TextStyle textStyle;
    if (fontName == 'Cairo') textStyle = GoogleFonts.cairo(fontSize: fontSize, fontWeight: FontWeight.w900, color: lightText ? Colors.white : titleColor);
    else if (fontName == 'Tajawal') textStyle = GoogleFonts.tajawal(fontSize: fontSize, fontWeight: FontWeight.w900, color: lightText ? Colors.white : titleColor);
    else if (fontName == 'Almarai') textStyle = GoogleFonts.almarai(fontSize: fontSize, fontWeight: FontWeight.w900, color: lightText ? Colors.white : titleColor);
    else if (fontName == 'Changa') textStyle = GoogleFonts.changa(fontSize: fontSize, fontWeight: FontWeight.w900, color: lightText ? Colors.white : titleColor);
    else textStyle = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: lightText ? Colors.white : titleColor);

    return Text(
      title.trim().isEmpty ? 'أنمي بدون اسم' : title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: textStyle.copyWith(shadows: [Shadow(color: Colors.black87, blurRadius: 10)]),
    );
  }

  Widget _buildProgressBar(Anime anime, {bool onImage = false}) {
    if (anime.episodes <= 0 || anime.watchedEpisodes <= 0) return const SizedBox.shrink();

    if (anime.watchedEpisodes >= anime.episodes) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
            const SizedBox(width: 4),
            Text('مكتمل (${anime.episodes})', style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    double progress = anime.watchedEpisodes / anime.episodes;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(onImage ? Colors.cyan : primaryColorNotifier.value), borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 4),
        Text('شاهدت ${anime.watchedEpisodes} من ${anime.episodes}', style: TextStyle(color: onImage ? Colors.white70 : Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildRowCard(Anime anime) {
    final color = colors[anime.colorIndex.abs() % colors.length];
    final details = [
      if (anime.releaseYear != null) '${anime.releaseYear}', 
      if (anime.status.isNotEmpty) anime.status, 
      if (anime.episodes > 0) '${anime.episodes} حلقة'
    ].join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: const Color(0xFF1B1F28), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(0.4), width: 1), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)]),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openAnimeDetails(anime),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _animeImage(anime, color),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAnimeTitle(anime.title),
                      const SizedBox(height: 6),
                      Text(anime.genre.isEmpty ? 'بدون تصنيف' : anime.genre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(details, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                      Row(
                        children: [
                          if (anime.rating > 0) ...[
                            const SizedBox(height: 5),
                            const Icon(Icons.star, size: 16, color: Color(0xFFFFC857)),
                            const SizedBox(width: 4),
                            Text('${anime.rating.toStringAsFixed(1)}/10', style: const TextStyle(fontSize: 12)),
                          ],
                          if (anime.globalRating != null) ...[
                            const SizedBox(width: 10),
                            const SizedBox(height: 5),
                            const Icon(Icons.public, size: 14, color: Colors.cyan),
                            const SizedBox(width: 4),
                            Text('${anime.globalRating!.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, color: Colors.cyan)),
                          ],
                        ],
                      ),
                      _buildProgressBar(anime),
                      if (anime.favorite) ...[
                        const SizedBox(height: 5),
                        const Row(children: [Icon(Icons.favorite, size: 14, color: Color(0xFFFF5364)), SizedBox(width: 4), Text('في المفضلة', style: TextStyle(color: Color(0xFFFF5364), fontSize: 11))]),
                      ],
                    ],
                  ),
                ),
              ),
              _animeMenu(anime),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(Anime anime) {
    final color = colors[anime.colorIndex.abs() % colors.length];
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1B1F28), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.4), width: 1), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)]),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => openAnimeDetails(anime),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _animeImage(anime, color, compact: true),
                  Positioned(top: 2, right: 2, child: Material(color: Colors.black54, borderRadius: BorderRadius.circular(30), child: SizedBox(width: 38, height: 38, child: _animeMenu(anime, light: true)))),
                  if (anime.favorite) const Positioned(left: 8, top: 8, child: Icon(Icons.favorite, color: Color(0xFFFF5364), size: 19)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAnimeTitle(anime.title, fontSize: 13),
                  const SizedBox(height: 4),
                  Text(anime.genre.isEmpty ? 'بدون تصنيف' : anime.genre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  Row(
                    children: [
                      if (anime.releaseYear != null) ...[const SizedBox(height: 4), Text('${anime.releaseYear}', style: const TextStyle(fontSize: 11, color: Colors.white54))],
                      if (anime.rating > 0) ...[const SizedBox(width: 8), const SizedBox(height: 4), const Icon(Icons.star, size: 14, color: Color(0xFFFFC857)), const SizedBox(width: 3), Text('${anime.rating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11))],
                      if (anime.globalRating != null) ...[const SizedBox(width: 8), const SizedBox(height: 4), const Icon(Icons.public, size: 12, color: Colors.cyan), const SizedBox(width: 3), Text('${anime.globalRating!.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, color: Colors.cyan))],
                    ],
                  ),
                  _buildProgressBar(anime),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactGridCard(Anime anime) {
    final color = colors[anime.colorIndex.abs() % colors.length];
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1B1F28), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.4), width: 1), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)]),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => openAnimeDetails(anime),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _animeImage(anime, color, compact: true)),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAnimeTitle(anime.title, fontSize: 11),
                  if (anime.rating > 0) ...[const SizedBox(height: 2), Row(children: [const Icon(Icons.star, size: 12, color: Color(0xFFFFC857)), const SizedBox(width: 3), Text('${anime.rating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 10))])],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCinematicCard(Anime anime) {
    final imagePath = anime.imagePath;
    return Container(
      height: 220, margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imagePath != null && File(imagePath).existsSync())
                Hero(tag: 'anime_image_${anime.id}', child: Image.file(File(imagePath), fit: BoxFit.cover))
            else
                Container(color: Colors.black26, child: const Icon(Icons.movie, size: 50, color: Colors.white24)),
            Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black87, Colors.black], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0.4, 0.8, 1.0]))),
            Positioned(
              bottom: 15, left: 15, right: 15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAnimeTitle(anime.title, fontSize: 18, lightText: true),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(anime.genre.isEmpty ? 'بدون تصنيف' : anime.genre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                      if (anime.rating > 0) Row(children: [const Icon(Icons.star, size: 16, color: Color(0xFFFFC857)), const SizedBox(width: 4), Text('${anime.rating.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))]),
                    ],
                  ),
                  _buildProgressBar(anime, onImage: true),
                ],
              ),
            ),
            Positioned(top: 10, right: 10, child: Material(color: Colors.black54, borderRadius: BorderRadius.circular(30), child: SizedBox(width: 38, height: 38, child: _animeMenu(anime, light: true)))),
            if (anime.favorite) const Positioned(left: 10, top: 10, child: Icon(Icons.favorite, color: Color(0xFFFF5364), size: 22)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactListCard(Anime anime) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: const Color(0xFF1B1F28), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openAnimeDetails(anime),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Hero(
                  tag: 'anime_image_${anime.id}',
                  child: anime.imagePath != null && File(anime.imagePath!).existsSync()
                      ? Image.file(File(anime.imagePath!), width: 45, height: 45, fit: BoxFit.cover)
                      : Container(width: 45, height: 45, color: Colors.black26, child: const Icon(Icons.movie, size: 20, color: Colors.white24)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAnimeTitle(anime.title, fontSize: 14),
                    const SizedBox(height: 4),
                    Text(anime.genre.isEmpty ? 'بدون تصنيف' : anime.genre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
              if (anime.rating > 0) ...[
                const Icon(Icons.star, size: 14, color: Color(0xFFFFC857)),
                const SizedBox(width: 4),
                Text(anime.rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 12)),
                const SizedBox(width: 10),
              ],
              _animeMenu(anime),
            ],
          ),
        ),
      ),
    );
  }

  Widget _animeMenu(Anime anime, {bool light = false}) {
    return PopupMenuButton<String>(
      tooltip: 'خيارات الأنمي',
      padding: EdgeInsets.zero, iconSize: 22,
      icon: Icon(Icons.more_vert, color: light ? Colors.white : Colors.white70),
      onSelected: (value) async {
        switch (value) {
          case 'edit': await editAnime(anime); break;
          case 'favorite': await toggleFavorite(anime); break;
          case 'trash': await moveToTrash(anime); break;
          case 'fetch_data': await _fetchDataManually(anime); break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined), SizedBox(width: 10), Text('تعديل بيانات الأنمي')])),
        const PopupMenuItem(value: 'fetch_data', child: Row(children: [Icon(Icons.cloud_download_outlined, color: Colors.cyan), SizedBox(width: 10), Text('جلب البيانات من الإنترنت')])),
        PopupMenuItem(value: 'favorite', child: Row(children: [const Icon(Icons.favorite_border, color: Color(0xFFFF5364)), const SizedBox(width: 10), Text(anime.favorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة')])),
        const PopupMenuItem(value: 'trash', child: Row(children: [Icon(Icons.delete_outline, color: Color(0xFFFF6B72)), SizedBox(width: 10), Text('نقل إلى سلة المهملات')])),
      ],
    );
  }

  Widget _buildToolbar() {
    IconData getViewIcon() {
      switch (viewMode) {
        case 0: return Icons.view_agenda_outlined;
        case 1: return Icons.grid_view_rounded;
        case 2: return Icons.apps;
        case 3: return Icons.view_carousel_outlined;
        case 4: return Icons.view_headline;
        default: return Icons.view_agenda_outlined;
      }
    }

    return Row(
      children: [
        Expanded(
          child: PopupMenuButton<String>(
            onSelected: (value) { HapticFeedback.selectionClick(); setState(() => sortMode = value); _saveLibraryPreferences(); },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'newest', child: Text('الأحدث إضافة')),
              PopupMenuItem(value: 'oldest', child: Text('الأقدم إضافة')),
              PopupMenuItem(value: 'titleAsc', child: Text('الاسم: أ ← ي')),
              PopupMenuItem(value: 'titleDesc', child: Text('الاسم: ي ← أ')),
              PopupMenuItem(value: 'rating', child: Text('الأعلى تقييمًا')),
              PopupMenuItem(value: 'favorites', child: Text('المفضلة أولًا')),
              PopupMenuItem(value: 'random', child: Text('عشوائي 🎲')), // 🔥 خيار الترتيب العشوائي
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(color: const Color(0xFF1B1F28), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
              child: Row(children: [const Icon(Icons.sort, size: 19), const SizedBox(width: 8), Expanded(child: Text(sortLabel, overflow: TextOverflow.ellipsis)), const Icon(Icons.keyboard_arrow_down)]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          decoration: BoxDecoration(color: const Color(0xFF1B1F28), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
          child: IconButton(
            tooltip: 'تغيير العرض',
            onPressed: () { HapticFeedback.lightImpact(); setState(() { viewMode = (viewMode + 1) % 5; }); _saveLibraryPreferences(); },
            icon: Icon(getViewIcon(), color: const Color(0xFFFFC857)),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonLoader() {
    return Column(
      children: List.generate(5, (index) => 
        Container(
          margin: const EdgeInsets.only(bottom: 12), height: 120,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              Container(width: 76, height: 96, margin: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(13))),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 150, height: 16, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 10),
                  Container(width: 100, height: 12, color: Colors.white.withOpacity(0.05)),
                ],
              )),
            ],
          ),
        )
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = filteredAnimes;
    final primaryColor = primaryColorNotifier.value;

    Widget buildContent() {
      if (loading) return _buildSkeletonLoader();
      
      if (items.isEmpty) {
        return Container(
          margin: const EdgeInsets.only(top: 20), padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(color: const Color(0xFF1B1F28), borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              const Icon(Icons.video_library_outlined, size: 50, color: Colors.white38),
              const SizedBox(height: 12),
              Text(animes.isEmpty ? 'مكتبتك فارغة' : 'لا توجد نتائج مطابقة', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('أضف أنمياتك من الصفحة الرئيسية.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
            ],
          ),
        );
      }
      
      switch (viewMode) {
        case 1: return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 12, childAspectRatio: 0.58), itemBuilder: (context, index) => _buildGridCard(items[index]));
        case 2: return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.6), itemBuilder: (context, index) => _buildCompactGridCard(items[index]));
        case 3: return Column(children: items.map(_buildCinematicCard).toList());
        case 4: return Column(children: items.map(_buildCompactListCard).toList());
        case 0: default: return Column(children: items.map(_buildRowCard).toList());
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _showBackToTop
          ? FloatingActionButton(
              mini: true, backgroundColor: primaryColor,
              onPressed: () { HapticFeedback.lightImpact(); _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut); },
              child: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: loadAnimes,
        child: Scrollbar(
          controller: _scrollController, thumbVisibility: false, trackVisibility: false, thickness: 8, radius: const Radius.circular(10), interactive: true,
          child: ListView(
            controller: _scrollController, keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, padding: const EdgeInsets.all(18),
            children: [
              const Text('مكتبة الأنمي', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('كل أعمالك في مكان واحد • ${animes.length} أنمي', style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 22),
              TextField(
                controller: searchController, onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'ابحث عن أنمي أو تصنيف...', prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchText.isNotEmpty ? IconButton(onPressed: () { searchController.clear(); setState(() => searchText = ''); }, icon: const Icon(Icons.close)) : null,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ['الكل', 'مكتمل', 'أتابعه', 'مخطط له', 'متوقف', 'المفضلة', 'جُلب تلقائياً', 'بدون تصنيف', 'قيد المشاهدة (تقدم)'].map((status) {
                    final selected = selectedStatus == status;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(label: Text(status), selected: selected, selectedColor: primaryColor, backgroundColor: const Color(0xFF1B1F28), side: BorderSide(color: selected ? primaryColor : Colors.white12), onSelected: (_) { HapticFeedback.selectionClick(); setState(() => selectedStatus = status); }),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ['كل التقييمات', '10', '9.5', '9', '8.5', '8', '7.5', '7', '6.5', '6', '5.5', '5', '4.5', '4', '3.5', '3', '2.5', '2', '1.5', '1', '0.5'].map((rate) {
                    final val = rate == 'كل التقييمات' ? 0.0 : double.parse(rate);
                    final selected = selectedRatingFilter == val;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(label: Text(rate), selected: selected, selectedColor: const Color(0xFFFFC857), backgroundColor: const Color(0xFF1B1F28), side: BorderSide(color: selected ? const Color(0xFFFFC857) : Colors.white12), labelStyle: TextStyle(color: selected ? Colors.black : Colors.white), onSelected: (_) { HapticFeedback.selectionClick(); setState(() => selectedRatingFilter = val); }),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),
              _buildToolbar(),
              const SizedBox(height: 18),
              buildContent(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
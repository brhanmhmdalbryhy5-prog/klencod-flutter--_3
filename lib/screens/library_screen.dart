
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime.dart';
import '../services/storage_service.dart';
import 'anime_details_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final StorageService storage = StorageService();
  final TextEditingController searchController = TextEditingController();
  final ImagePicker imagePicker = ImagePicker();

  static const String _sortKey = 'anime_library_sort';
  static const String _viewKey = 'anime_library_view';

  List<Anime> animes = [];
  String selectedStatus = 'الكل';
  String searchText = '';
  String sortMode = 'newest';
  bool gridView = false;
  bool loading = true;

  final List<Color> colors = const [
    Color(0xFF741C2B),
    Color(0xFF247BA0),
    Color(0xFF8B65C6),
    Color(0xFFB87928),
    Color(0xFF27866F),
    Color(0xFFB34E68),
  ];

  @override
  void initState() {
    super.initState();
    loadAnimes();
    _loadLibraryPreferences();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLibraryPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      setState(() {
        sortMode = prefs.getString(_sortKey) ?? 'newest';
        gridView = prefs.getBool(_viewKey) ?? false;
      });
    } catch (_) {}
  }

  Future<void> _saveLibraryPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sortKey, sortMode);
      await prefs.setBool(_viewKey, gridView);
    } catch (_) {}
  }

  Future<void> loadAnimes() async {
    try {
      final data = await storage.loadAnimes();

      if (!mounted) return;

      setState(() {
        animes = data;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل مكتبة الأنمي')),
      );
    }
  }

  List<Anime> get filteredAnimes {
    final query = searchText.trim().toLowerCase();

    final result = animes.where((anime) {
      final matchesSearch =
          anime.title.toLowerCase().contains(query) ||
          anime.genre.toLowerCase().contains(query) ||
          anime.character.toLowerCase().contains(query);

      final matchesStatus = selectedStatus == 'الكل' ||
          (selectedStatus == 'المفضلة'
              ? anime.favorite
              : anime.status == selectedStatus);

      return matchesSearch && matchesStatus;
    }).toList();

    switch (sortMode) {
      case 'oldest':
        result.sort((a, b) => _dateOf(a).compareTo(_dateOf(b)));
        break;
      case 'titleAsc':
        result.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'titleDesc':
        result.sort((a, b) =>
            b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case 'rating':
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'favorites':
        result.sort((a, b) {
          final favoriteOrder =
              (b.favorite ? 1 : 0).compareTo(a.favorite ? 1 : 0);
          if (favoriteOrder != 0) return favoriteOrder;
          return _dateOf(b).compareTo(_dateOf(a));
        });
        break;
      case 'newest':
      default:
        result.sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
        break;
    }

    return result;
  }

  // تاريخ الإضافة غير موجود في نموذج Anime الحالي؛
  // لذلك يستخدم ترتيب القائمة الأصلي عند تساوي التاريخ الافتراضي.
  // سنعتمد ترتيب القائمة المحفوظة كبديل آمن دون تغيير نموذج البيانات.
  DateTime _dateOf(Anime anime) {
    final index = animes.indexWhere((item) => item.id == anime.id);
    return DateTime.fromMillisecondsSinceEpoch(index < 0 ? 0 : index);
  }

  String get sortLabel {
    switch (sortMode) {
      case 'oldest':
        return 'الأقدم إضافة';
      case 'titleAsc':
        return 'الاسم: أ ← ي';
      case 'titleDesc':
        return 'الاسم: ي ← أ';
      case 'rating':
        return 'الأعلى تقييمًا';
      case 'favorites':
        return 'المفضلة أولًا';
      default:
        return 'الأحدث إضافة';
    }
  }

  Future<String> _saveImageLocally(String sourcePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagesDirectory = Directory('${directory.path}/anime_images');

    if (!await imagesDirectory.exists()) {
      await imagesDirectory.create(recursive: true);
    }

    final extension = sourcePath.contains('.')
        ? sourcePath.substring(sourcePath.lastIndexOf('.'))
        : '.jpg';

    final destinationPath =
        '${imagesDirectory.path}/${DateTime.now().microsecondsSinceEpoch}$extension';

    return (await File(sourcePath).copy(destinationPath)).path;
  }

  Future<String?> _pickAndSaveImage() async {
    try {
      final picked = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) return null;
      return await _saveImageLocally(picked.path);
    } catch (_) {
      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر اختيار الصورة أو حفظها.')),
      );
      return null;
    }
  }

  Widget _imagePlaceholder(Color color, {bool compact = false}) {
    return Container(
      width: compact ? double.infinity : 76,
      height: compact ? 160 : 96,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        Icons.movie_creation_outlined,
        color: color,
        size: 32,
      ),
    );
  }

  Widget _animeImage(
    Anime anime,
    Color color, {
    bool compact = false,
  }) {
    final path = anime.imagePath;

    if (path != null && path.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Image.file(
          File(path),
          width: compact ? double.infinity : 76,
          height: compact ? 160 : 96,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _imagePlaceholder(color, compact: compact),
        ),
      );
    }

    return _imagePlaceholder(color, compact: compact);
  }

  Future<void> openAnimeDetails(Anime anime) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimeDetailsScreen(anime: anime),
      ),
    );

    if (mounted) await loadAnimes();
  }

  Future<void> deleteAnime(Anime anime) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('حذف الأنمي؟'),
        content: Text(
          'هل تريد حذف "${anime.title.isEmpty ? 'أنمي بدون اسم' : anime.title}" من مكتبتك؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF741C2B),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final saved = await storage.deleteAnime(animes, anime.id);
    if (!mounted) return;

    if (saved) {
      await loadAnimes();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved ? 'تم حذف الأنمي' : 'تعذر حفظ عملية الحذف'),
      ),
    );
  }

  Future<void> toggleFavorite(Anime anime) async {
    final oldValue = anime.favorite;

    setState(() => anime.favorite = !oldValue);

    final saved = await storage.saveAnimes(animes);
    if (!mounted) return;

    if (!saved) {
      setState(() => anime.favorite = oldValue);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ التغيير')),
      );
    } else {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            anime.favorite ? 'أضيف إلى المفضلة' : 'أزيل من المفضلة',
          ),
        ),
      );
    }
  }

  Future<void> editAnime(Anime anime) async {
    final titleController = TextEditingController(text: anime.title);
    final genreController = TextEditingController(text: anime.genre);
    final characterController = TextEditingController(text: anime.character);
    final episodesController = TextEditingController(
      text: anime.episodes == 0 ? '' : '${anime.episodes}',
    );
    final summaryController = TextEditingController(text: anime.summary);
    final memoryController = TextEditingController(text: anime.memory);

    String status = anime.status;
    int rating = anime.rating;
    String? imagePath = anime.imagePath;
    bool imageChanged = false;

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
                            if (pickedPath != null) {
                              setDialogState(() {
                                imagePath = pickedPath;
                                imageChanged = true;
                              });
                            }
                          },
                          child: Container(
                            height: 145,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF111318),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF741C2B),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: imagePath != null &&
                                    File(imagePath!).existsSync()
                                ? Image.file(
                                    File(imagePath!),
                                    fit: BoxFit.cover,
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 36,
                                      ),
                                      SizedBox(height: 8),
                                      Text('اختيار صورة (اختياري)'),
                                    ],
                                  ),
                          ),
                        ),
                        if (imagePath != null)
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                imagePath = null;
                                imageChanged = true;
                              });
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('إزالة الصورة'),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'اسم الأنمي (اختياري)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: genreController,
                          decoration: const InputDecoration(
                            labelText: 'التصنيف (اختياري)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: characterController,
                          decoration: const InputDecoration(
                            labelText: 'الشخصية المفضلة (اختياري)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: episodesController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'عدد الحلقات (اختياري)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: [
                            '',
                            'مكتمل',
                            'أتابعه',
                            'مخطط له',
                            'متوقف',
                          ].contains(status)
                              ? status
                              : '',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'حالة المشاهدة (اختياري)',
                          ),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('لم أحدد')),
                            DropdownMenuItem(value: 'مكتمل', child: Text('مكتمل')),
                            DropdownMenuItem(value: 'أتابعه', child: Text('أتابعه')),
                            DropdownMenuItem(value: 'مخطط له', child: Text('مخطط له')),
                            DropdownMenuItem(value: 'متوقف', child: Text('متوقف')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => status = value);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text('التقييم (اختياري)'),
                        ),
                        Wrap(
                          spacing: 2,
                          children: List.generate(5, (index) {
                            final value = index + 1;
                            return IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  rating = rating == value ? 0 : value;
                                });
                              },
                              icon: Icon(
                                Icons.star,
                                color: value <= rating
                                    ? const Color(0xFFFFC857)
                                    : Colors.white24,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: summaryController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'ملخص القصة (اختياري)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: memoryController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'ذكرياتك (اختياري)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF741C2B),
                    ),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('حفظ التعديلات'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != true) {
        if (imageChanged && imagePath != null && imagePath != anime.imagePath) {
          try {
            final file = File(imagePath!);
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }
        return;
      }

      final oldImagePath = anime.imagePath;

      anime
        ..title = titleController.text.trim()
        ..genre = genreController.text.trim()
        ..character = characterController.text.trim()
        ..episodes = int.tryParse(episodesController.text) ?? 0
        ..status = status
        ..rating = rating
        ..summary = summaryController.text.trim()
        ..memory = memoryController.text.trim()
        ..imagePath = imagePath;

      final saved = await storage.saveAnimes(animes);
      if (!mounted) return;

      if (saved) {
        if (imageChanged &&
            oldImagePath != null &&
            oldImagePath.isNotEmpty &&
            oldImagePath != imagePath) {
          try {
            final oldFile = File(oldImagePath);
            if (await oldFile.exists()) await oldFile.delete();
          } catch (_) {}
        }

        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ تعديلات الأنمي')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ التعديلات')),
        );
      }
    } finally {
      titleController.dispose();
      genreController.dispose();
      characterController.dispose();
      episodesController.dispose();
      summaryController.dispose();
      memoryController.dispose();
    }
  }

  Widget _buildRowCard(Anime anime) {
    final color = colors[anime.colorIndex.abs() % colors.length];
    final details = [
      if (anime.status.isNotEmpty) anime.status,
      if (anime.episodes > 0) '${anime.episodes} حلقة',
    ].join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
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
                      Text(
                        anime.title.trim().isEmpty ? 'أنمي بدون اسم' : anime.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        anime.genre.isEmpty ? 'بدون تصنيف' : anime.genre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          details,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      if (anime.rating > 0) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 16, color: Color(0xFFFFC857)),
                            const SizedBox(width: 4),
                            Text('${anime.rating}/5'),
                          ],
                        ),
                      ],
                      if (anime.favorite) ...[
                        const SizedBox(height: 5),
                        const Row(
                          children: [
                            Icon(Icons.favorite, size: 14, color: Color(0xFFFF5364)),
                            SizedBox(width: 4),
                            Text(
                              'في المفضلة',
                              style: TextStyle(color: Color(0xFFFF5364), fontSize: 11),
                            ),
                          ],
                        ),
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
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F28),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
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
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: _animeMenu(anime, light: true),
                      ),
                    ),
                  ),
                  if (anime.favorite)
                    const Positioned(
                      left: 8,
                      top: 8,
                      child: Icon(
                        Icons.favorite,
                        color: Color(0xFFFF5364),
                        size: 19,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime.title.trim().isEmpty ? 'أنمي بدون اسم' : anime.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    anime.genre.isEmpty ? 'بدون تصنيف' : anime.genre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  if (anime.rating > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Color(0xFFFFC857)),
                        const SizedBox(width: 3),
                        Text('${anime.rating}/5', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _animeMenu(Anime anime, {bool light = false}) {
    return PopupMenuButton<String>(
      tooltip: 'خيارات الأنمي',
      padding: EdgeInsets.zero,
      iconSize: 22,
      icon: Icon(
        Icons.more_vert,
        color: light ? Colors.white : Colors.white70,
      ),
      onSelected: (value) async {
        switch (value) {
          case 'edit':
            await editAnime(anime);
            break;
          case 'favorite':
            await toggleFavorite(anime);
            break;
          case 'delete':
            await deleteAnime(anime);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined),
              SizedBox(width: 10),
              Text('تعديل بيانات الأنمي'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'favorite',
          child: Row(
            children: [
              const Icon(Icons.favorite_border, color: Color(0xFFFF5364)),
              const SizedBox(width: 10),
              Text(anime.favorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Color(0xFFFF6B72)),
              SizedBox(width: 10),
              Text('حذف الأنمي'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        Expanded(
          child: PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => sortMode = value);
              _saveLibraryPreferences();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'newest', child: Text('الأحدث إضافة')),
              PopupMenuItem(value: 'oldest', child: Text('الأقدم إضافة')),
              PopupMenuItem(value: 'titleAsc', child: Text('الاسم: أ ← ي')),
              PopupMenuItem(value: 'titleDesc', child: Text('الاسم: ي ← أ')),
              PopupMenuItem(value: 'rating', child: Text('الأعلى تقييمًا')),
              PopupMenuItem(value: 'favorites', child: Text('المفضلة أولًا')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1F28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sort, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sortLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1B1F28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: IconButton(
            tooltip: gridView ? 'عرض الصفوف' : 'عرض الأعمدة',
            onPressed: () {
              setState(() => gridView = !gridView);
              _saveLibraryPreferences();
            },
            icon: Icon(
              gridView ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
              color: const Color(0xFFFFC857),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = filteredAnimes;

    return RefreshIndicator(
      onRefresh: loadAnimes,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'مكتبة الأنمي',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'كل أعمالك في مكان واحد • ${animes.length} أنمي',
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: searchController,
            onChanged: (value) => setState(() => searchText = value),
            decoration: InputDecoration(
              hintText: 'ابحث عن أنمي أو تصنيف...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchText.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() => searchText = '');
                      },
                      icon: const Icon(Icons.close),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                'الكل',
                'مكتمل',
                'أتابعه',
                'مخطط له',
                'متوقف',
                'المفضلة',
              ].map((status) {
                final selected = selectedStatus == status;

                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(status),
                    selected: selected,
                    selectedColor: const Color(0xFF741C2B),
                    backgroundColor: const Color(0xFF1B1F28),
                    side: BorderSide(
                      color: selected ? const Color(0xFF741C2B) : Colors.white12,
                    ),
                    onSelected: (_) => setState(() => selectedStatus = status),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          _buildToolbar(),
          const SizedBox(height: 18),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),
            )
          else if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1F28),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  const Icon(Icons.video_library_outlined, size: 50, color: Colors.white38),
                  const SizedBox(height: 12),
                  Text(
                    animes.isEmpty ? 'مكتبتك فارغة' : 'لا توجد نتائج مطابقة',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'أضف أنمياتك من الصفحة الرئيسية.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            )
          else if (gridView)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
                childAspectRatio: 0.58,
              ),
              itemBuilder: (context, index) => _buildGridCard(items[index]),
            )
          else
            ...items.map(_buildRowCard),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

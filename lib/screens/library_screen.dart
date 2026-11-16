import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_events.dart';
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
  static const String _swipeKey = 'anime_swipe_enabled';

  // 🆕 تحديد متعدد
  bool _selectionMode = false;
  final Set<String> _selectedAnimeIds = {};

  // 🆕 تفعيل السحب
  bool _swipeEnabled = true;

  final List<String> allGenres = const [
    'أكشن', 'مغامرة', 'كوميدي', 'دراما', 'فانتازيا', 'رعب',
    'إيتشي', 'ميكا', 'غموض', 'رومانسي', 'خيال علمي', 'شريحة من الحياة',
    'رياضة', 'إثارة', 'حريم', 'مدرسي', 'شونين', 'سينين',
    'جوسي', 'شوجو', 'قوى خارقة', 'تاريخي', 'موسيقي', 'نفسي',
    'فامباير', 'سحر', 'حربي', 'فضاء', 'بوليسي', 'عائلي',
    'ألعاب', 'فنون قتالية', 'ساموراي', 'شياطين', 'إيسيكاي',
  ];

  List<Anime> animes = [];
  List<Anime> _allAnimes = [];
  String selectedStatus = 'الكل';
  String selectedType = 'الكل';
  double selectedRatingFilter = 0;
  String searchText = '';
  String sortMode = 'newest';
  int viewMode = 0;
  bool loading = true;

  int? _advFromYear;
  int? _advToYear;
  List<String> _advGenres = [];

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
        _swipeEnabled = prefs.getBool(_swipeKey) ?? true;
      });
    } catch (_) {}
  }

  Future<void> _saveLibraryPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sortKey, sortMode);
      await prefs.setInt(_viewKey, viewMode);
      await prefs.setBool(_swipeKey, _swipeEnabled);
    } catch (_) {}
  }

  Future<void> loadAnimes() async {
    try {
      final data = await storage.loadAnimes();
      if (!mounted) return;
      setState(() {
        _allAnimes = data;
        animes = data.where((a) => a.parentId == null).toList();
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل مكتبة الأنمي')));
    }
  }

  Route _createAnimatedRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // 🆕 Swipe Actions
  // ══════════════════════════════════════════════════════════════
  Future<void> _incrementWatched(Anime anime) async {
    if (anime.episodes > 0 && anime.watchedEpisodes >= anime.episodes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ هذا الأنمي مكتمل بالفعل'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    HapticFeedback.lightImpact();
    final allAnimes = await storage.loadAnimes();
    final idx = allAnimes.indexWhere((a) => a.id == anime.id);
    if (idx == -1) return;

    allAnimes[idx].watchedEpisodes++;
    final isNowComplete = anime.episodes > 0 &&
        allAnimes[idx].watchedEpisodes >= anime.episodes;
    final isOneLeft = anime.episodes > 0 &&
        allAnimes[idx].watchedEpisodes == anime.episodes - 1;

    if (isNowComplete) allAnimes[idx].status = 'مكتمل';
    await storage.saveAnimes(allAnimes);
    await loadAnimes();

    // 🆕 إطلاق الحدث للشخصية
    if (isNowComplete) {
      AppEvents.fire('anime_completed');
    } else if (isOneLeft) {
      AppEvents.fire('one_episode_left');
    } else {
      AppEvents.fire('episode_done');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNowComplete
              ? '🎉 اكتمل ${anime.title}!'
              : '➕ ${anime.title}: ${allAnimes[idx].watchedEpisodes}/${anime.episodes}'),
          duration: const Duration(milliseconds: 1200),
          backgroundColor: isNowComplete ? Colors.green : Colors.blue,
        ),
      );
    }
  }

  // 🆕 تقييم سريع بالنجوم (10 نجوم مع رسالة تأكيد)
  Future<void> _quickSetRating(Anime anime, double newRating) async {
    HapticFeedback.selectionClick();

    final isSameRating = (anime.rating - newRating).abs() < 0.1;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: Row(
          children: [
            Icon(
              isSameRating ? Icons.star_border : Icons.star,
              color: const Color(0xFFFFC857),
            ),
            const SizedBox(width: 8),
            Text(isSameRating ? 'إلغاء التقييم' : 'تأكيد التقييم'),
          ],
        ),
        content: Text(
          isSameRating
              ? 'سيتم إزالة التقييم الحالي (${anime.rating.toStringAsFixed(1)}) '
                  'من "${anime.title}".\n\nهل تريد المتابعة؟'
              : 'سيتم تغيير تقييم "${anime.title}"\n'
                  'من ${anime.rating.toStringAsFixed(1)} '
                  'إلى ${newRating.toStringAsFixed(1)} من 10.\n\n'
                  'هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: primaryColorNotifier.value,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final allAnimes = await storage.loadAnimes();
    final idx = allAnimes.indexWhere((a) => a.id == anime.id);
    if (idx == -1) return;

    if (isSameRating) {
      allAnimes[idx].rating = 0;
    } else {
      allAnimes[idx].rating = newRating;
    }
    await storage.saveAnimes(allAnimes);
    await loadAnimes();

    // 🆕 إطلاق الحدث للشخصية
    if (newRating >= 8) {
      AppEvents.fire('high_rate');
    } else if (newRating > 0 && newRating < 5) {
      AppEvents.fire('low_rate');
    } else if (newRating > 0) {
      AppEvents.fire('rated');
    }
  }

  Widget _wrapWithSwipe(Anime anime, Widget child) {
    if (_selectionMode || !_swipeEnabled) return child;

    return Dismissible(
      key: ValueKey('swipe_${anime.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5364).withOpacity(0.9),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, color: Colors.white, size: 32),
            SizedBox(height: 4),
            Text('المفضلة',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.9),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle, color: Colors.white, size: 32),
            SizedBox(height: 4),
            Text('+1 حلقة',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _incrementWatched(anime);
        } else if (direction == DismissDirection.endToStart) {
          await toggleFavorite(anime);
        }
        return false;
      },
      child: child,
    );
  }

  Widget _buildQuickRating(Anime anime, {bool lightText = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(10, (index) {
        final starValue = (index + 1) * 1.0;
        final isFilled = anime.rating >= starValue - 0.5;
        return GestureDetector(
          onTap: () => _quickSetRating(anime, starValue),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
            child: Icon(
              isFilled ? Icons.star : Icons.star_border,
              color: const Color(0xFFFFC857),
              size: 14,
            ),
          ),
        );
      }),
    );
  }

  void _toggleSelectionMode() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedAnimeIds.clear();
    });
  }

  void _toggleAnimeSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedAnimeIds.contains(id)) {
        _selectedAnimeIds.remove(id);
      } else {
        _selectedAnimeIds.add(id);
      }
    });
  }

  void _selectAllVisible() {
    HapticFeedback.lightImpact();
    setState(() {
      for (final anime in filteredAnimes) {
        _selectedAnimeIds.add(anime.id);
      }
    });
  }

  void _clearSelection() {
    HapticFeedback.lightImpact();
    setState(() => _selectedAnimeIds.clear());
  }

  Future<void> _markSelectedAsCompleted() async {
    if (_selectedAnimeIds.isEmpty) return;

    final count = _selectedAnimeIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('تحديد كمكتمل'),
        content: Text(
          'سيتم تحديد $count أنمي كمكتمل.\n\n'
          '• سيتم ضبط "شاهدت" = إجمالي الحلقات (إن وُجدت)\n'
          '• سيتم تغيير الحالة إلى "مكتمل"\n\n'
          'هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: primaryColorNotifier.value),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final allAnimes = await storage.loadAnimes();
      int updated = 0;
      for (final anime in allAnimes) {
        if (_selectedAnimeIds.contains(anime.id)) {
          if (anime.episodes > 0) {
            anime.watchedEpisodes = anime.episodes;
          }
          anime.status = 'مكتمل';
          updated++;
        }
      }
      final saved = await storage.saveAnimes(allAnimes);
      if (!mounted) return;

      setState(() {
        _selectionMode = false;
        _selectedAnimeIds.clear();
      });

      if (saved) {
        await loadAnimes();
        if (!mounted) return;
        AppEvents.fire('anime_completed'); // 🆕
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم تحديد $updated أنمي كمكتمل.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ التغييرات.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    }
  }

  List<Anime> get filteredAnimes {
    final query = searchText.trim().toLowerCase();

    final List<Anime> sourceList;
    if (selectedStatus == 'قيد المشاهدة (تقدم)') {
      sourceList = _allAnimes.where((a) {
        final hasProgress = a.watchedEpisodes > 0 &&
            (a.episodes == 0 || a.watchedEpisodes < a.episodes);
        if (a.parentId == null) {
          if (hasProgress) return true;
          return _allAnimes.any((s) =>
              s.parentId == a.id &&
              s.watchedEpisodes > 0 &&
              (s.episodes == 0 || s.watchedEpisodes < s.episodes));
        } else {
          return hasProgress;
        }
      }).toList();
    } else {
      sourceList = animes;
    }

    final result = sourceList.where((anime) {
      final matchesSearch = anime.title.toLowerCase().contains(query) ||
          anime.genre.toLowerCase().contains(query) ||
          anime.character.toLowerCase().contains(query);

      bool matchesType = true;
      if (selectedType == 'أفلام') {
        matchesType = anime.format == 'MOVIE';
      } else if (selectedType == 'مسلسلات') {
        matchesType = anime.format != 'MOVIE';
      }

      bool matchesStatus = true;
      if (selectedStatus != 'قيد المشاهدة (تقدم)') {
        if (selectedStatus == 'الكل') {
          matchesStatus = true;
        } else if (selectedStatus == 'المفضلة') {
          matchesStatus = anime.favorite;
        } else if (selectedStatus == 'جُلب تلقائياً') {
          matchesStatus = anime.genre.isNotEmpty && !anime.genre.contains('، ');
        } else if (selectedStatus == 'بدون تصنيف') {
          matchesStatus = anime.genre.trim().isEmpty;
        } else {
          matchesStatus = anime.status == selectedStatus;
        }
      }

      bool matchesRating = true;
      if (selectedRatingFilter > 0) {
        matchesRating = anime.rating == selectedRatingFilter;
      }

      bool matchesAdvanced = true;
      if (_advFromYear != null && (anime.releaseYear ?? 0) < _advFromYear!) {
        matchesAdvanced = false;
      }
      if (_advToYear != null && (anime.releaseYear ?? 9999) > _advToYear!) {
        matchesAdvanced = false;
      }
      if (_advGenres.isNotEmpty) {
        final animeGenres = anime.genre.split('،').map((e) => e.trim()).toList();
        if (!_advGenres.any((g) => animeGenres.contains(g))) {
          matchesAdvanced = false;
        }
      }

      return matchesSearch && matchesType && matchesStatus && matchesRating && matchesAdvanced;
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
      case 'random':
        result.shuffle(Random());
        break;
      case 'newest':
      default:
        result.sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
        break;
    }
    return result;
  }

  DateTime _dateOf(Anime anime) {
    final index = _allAnimes.indexWhere((item) => item.id == anime.id);
    return DateTime.fromMillisecondsSinceEpoch(index < 0 ? 0 : index);
  }

  String get sortLabel {
    switch (sortMode) {
      case 'oldest': return 'الأقدم إضافة';
      case 'titleAsc': return 'الاسم: أ ← ي';
      case 'titleDesc': return 'الاسم: ي ← أ';
      case 'rating': return 'الأعلى تقييمًا';
      case 'favorites': return 'المفضلة أولًا';
      case 'random': return 'عشوائي';
      default: return 'الأحدث إضافة';
    }
  }

  Future<void> _showAdvancedSearch() async {
    final fromYearController =
        TextEditingController(text: _advFromYear?.toString() ?? '');
    final toYearController =
        TextEditingController(text: _advToYear?.toString() ?? '');
    List<String> tempGenres = List.from(_advGenres);

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          title: const Row(children: [
            Icon(Icons.tune, color: Colors.cyan),
            SizedBox(width: 8),
            Text('البحث المتقدم'),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('نطاق السنة',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fromYearController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'من',
                            prefixIcon:
                                Icon(Icons.calendar_today, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: toYearController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'إلى',
                            prefixIcon:
                                Icon(Icons.calendar_today, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('التصنيفات',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allGenres.take(20).map((genre) {
                      final selected = tempGenres.contains(genre);
                      return FilterChip(
                        label: Text(
                          genre,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                selected ? Colors.white : Colors.white70,
                          ),
                        ),
                        selected: selected,
                        selectedColor: primaryColorNotifier.value,
                        backgroundColor: const Color(0xFF111318),
                        side: BorderSide(
                          color: selected
                              ? primaryColorNotifier.value
                              : Colors.white24,
                        ),
                        onSelected: (v) {
                          setDialogState(() {
                            if (v) {
                              tempGenres.add(genre);
                            } else {
                              tempGenres.remove(genre);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _advFromYear = null;
                  _advToYear = null;
                  _advGenres = [];
                });
                Navigator.pop(dialogContext, false);
              },
              child: const Text('مسح الكل'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: primaryColorNotifier.value),
              onPressed: () {
                setState(() {
                  _advFromYear = int.tryParse(fromYearController.text);
                  _advToYear = int.tryParse(toYearController.text);
                  _advGenres = tempGenres;
                });
                Navigator.pop(dialogContext, true);
              },
              child: const Text('تطبيق'),
            ),
          ],
        ),
      ),
    );
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
          source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return null;
      return await _saveImageLocally(picked.path);
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر اختيار الصورة أو حفظها.')));
      return null;
    }
  }

  Widget _animeImage(Anime anime, Color color, {bool compact = false}) {
    final path = anime.imagePath;
    Widget imageWidget;

    if (path != null && path.isNotEmpty) {
      imageWidget = Image.file(
        File(path),
        width: compact ? double.infinity : 76,
        height: compact ? 160 : 96,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _imagePlaceholder(color, compact: compact),
      );
    } else {
      imageWidget = _imagePlaceholder(color, compact: compact);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Hero(tag: 'anime_image_${anime.id}', child: imageWidget),
    );
  }

  Widget _imagePlaceholder(Color color, {bool compact = false}) {
    return Container(
      width: compact ? double.infinity : 76,
      height: compact ? 160 : 96,
      decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(13)),
      child: Icon(Icons.movie_creation_outlined, color: color, size: 32),
    );
  }

  void _onCardTap(Anime anime) {
    if (_selectionMode) {
      _toggleAnimeSelection(anime.id);
    } else {
      openAnimeDetails(anime);
    }
  }

  Future<void> openAnimeDetails(Anime anime) async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      _createAnimatedRoute(AnimeDetailsScreen(anime: anime)),
    );
    if (mounted) await loadAnimes();
  }

  Widget _selectionCheckbox(Anime anime) {
    final isSelected = _selectedAnimeIds.contains(anime.id);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: isSelected
            ? primaryColorNotifier.value
            : Colors.black.withOpacity(0.7),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 20)
          : null,
    );
  }

  Future<void> moveToTrash(Anime anime) async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('نقل إلى سلة المهملات؟'),
        content: Text(
            'هل تريد نقل "${anime.title.isEmpty ? 'أنمي بدون اسم' : anime.title}" إلى سلة المهملات؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: primaryColorNotifier.value),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('نقل'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final allAnimes = await storage.loadAnimes();
    final saved = await storage.moveToTrash(allAnimes, anime.id);
    if (!mounted) return;
    if (saved) {
      AppEvents.fire('anime_deleted'); // 🆕
      await loadAnimes();
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(saved ? 'تم نقل الأنمي إلى السلة' : 'تعذر حفظ العملية')));
  }

  Future<void> toggleFavorite(Anime anime) async {
    HapticFeedback.selectionClick();
    final allAnimes = await storage.loadAnimes();
    final idx = allAnimes.indexWhere((a) => a.id == anime.id);
    if (idx == -1) return;

    allAnimes[idx].favorite = !allAnimes[idx].favorite;
    final isFav = allAnimes[idx].favorite;
    final saved = await storage.saveAnimes(allAnimes);
    await loadAnimes();

    if (saved) {
      AppEvents.fire(isFav ? 'favorite_added' : 'favorite_removed'); // 🆕
    }

    if (!mounted) return;
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isFav ? '❤️ أضيف إلى المفضلة' : 'أزيل من المفضلة'),
          duration: const Duration(milliseconds: 1000)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ التغيير')));
    }
  }

  Future<void> toggleMovieFormat(Anime anime) async {
    HapticFeedback.selectionClick();
    final allAnimes = await storage.loadAnimes();
    final idx = allAnimes.indexWhere((a) => a.id == anime.id);
    if (idx == -1) return;

    final wasMovie = allAnimes[idx].format == 'MOVIE';
    allAnimes[idx].format = wasMovie ? 'TV' : 'MOVIE';
    final saved = await storage.saveAnimes(allAnimes);

    if (!mounted) return;
    if (saved) {
      AppEvents.fire('anime_edited'); // 🆕
      await loadAnimes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(wasMovie
            ? '📺 تم نقل "${anime.title}" إلى تبويب المسلسلات'
            : '🎬 تم نقل "${anime.title}" إلى تبويب الأفلام'),
        backgroundColor: wasMovie ? Colors.blue : Colors.orange,
        duration: const Duration(seconds: 2),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ التغيير')));
    }
  }

  Future<void> _fetchDataManually(Anime anime) async {
    if (anime.title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('الأنمي لا يملك اسماً، لا يمكن البحث عنه.')));
      return;
    }

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    final data =
        await apiService.fetchAnimeData(anime.title, downloadImages: true);

    if (!mounted) return;
    Navigator.pop(context);

    final List<String> genres = data['genres'];
    final String summary = data['summary'];
    final int episodes = data['episodes'];
    final double? globalRating = data['globalRating'];
    final int? releaseYear = data['releaseYear'];
    final String? imagePath = data['imagePath'];
    final String? fetchedFormat = data['format'];

    if (genres.isNotEmpty ||
        summary.isNotEmpty ||
        episodes > 0 ||
        globalRating != null ||
        releaseYear != null ||
        imagePath != null) {
      final allAnimes = await storage.loadAnimes();
      final idx = allAnimes.indexWhere((a) => a.id == anime.id);
      if (idx != -1) {
        final target = allAnimes[idx];
        if (genres.isNotEmpty) target.genre = genres.join('، ');
        if (summary.isNotEmpty) target.summary = summary;
        if (episodes > 0) target.episodes = episodes;
        if (globalRating != null) target.globalRating = globalRating;
        if (releaseYear != null) target.releaseYear = releaseYear;
        if (imagePath != null) target.imagePath = imagePath;
        if (fetchedFormat != null) target.format = fetchedFormat;
        if ((data['characters'] as List).isNotEmpty) {
          target.characters =
              List<Map<String, dynamic>>.from(data['characters']);
        }
      }
      final saved = await storage.saveAnimes(allAnimes);

      if (!mounted) return;
      if (saved) {
        await loadAnimes();
        AppEvents.fire('anime_edited'); // 🆕
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم جلب البيانات والصور وحفظها محلياً!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر حفظ البيانات.')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'لم يتم العثور على بيانات. تأكد من كتابة الاسم بالإنجليزية.')));
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
                          if (value == true) {
                            selected.add(genre);
                          } else {
                            selected.remove(genre);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('إلغاء')),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: primaryColorNotifier.value),
                  onPressed: () =>
                      Navigator.pop(dialogContext, selected.toList()),
                  child: const Text('تأكيد'),
                ),
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
    final episodesController = TextEditingController(
        text: anime.episodes == 0 ? '' : '${anime.episodes}');
    final watchedController = TextEditingController(
        text: anime.watchedEpisodes == 0 ? '' : '${anime.watchedEpisodes}');
    final summaryController = TextEditingController(text: anime.summary);
    final memoryController = TextEditingController(text: anime.memory);
    final yearController =
        TextEditingController(text: anime.releaseYear?.toString() ?? '');

    String status = anime.status;
    double rating = anime.rating;
    String? imagePath = anime.imagePath;
    bool imageChanged = false;
    String? selectedFormat = anime.format;
    List<String> selectedGenres = anime.genre
        .split('،')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

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
                                  color: primaryColorNotifier.value),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: imagePath != null &&
                                    File(imagePath!).existsSync()
                                ? Image.file(File(imagePath!),
                                    fit: BoxFit.cover)
                                : const Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                        Icon(
                                            Icons
                                                .add_photo_alternate_outlined,
                                            size: 36),
                                        SizedBox(height: 8),
                                        Text('اختيار صورة (اختياري)')
                                      ]),
                          ),
                        ),
                        if (imagePath != null)
                          TextButton.icon(
                            onPressed: () => setDialogState(() {
                              imagePath = null;
                              imageChanged = true;
                            }),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('إزالة الصورة'),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                            controller: titleController,
                            decoration: const InputDecoration(
                                labelText: 'اسم الأنمي (اختياري)')),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () async {
                            final newGenres =
                                await _showGenrePicker(selectedGenres);
                            if (newGenres != null) {
                              setDialogState(() =>
                                  selectedGenres = newGenres);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                                labelText: 'التصنيفات (اختياري)',
                                suffixIcon:
                                    Icon(Icons.arrow_drop_down)),
                            child: Text(
                              selectedGenres.isEmpty
                                  ? 'لم يتم اختيار تصنيف'
                                  : selectedGenres.join('، '),
                              style: TextStyle(
                                  color: selectedGenres.isEmpty
                                      ? Colors.white38
                                      : Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                            controller: characterController,
                            decoration: const InputDecoration(
                                labelText:
                                    'الشخصية المفضلة (اختياري)')),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String?>(
                          value: selectedFormat,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'نوع العمل (اختياري)',
                              helperText:
                                  'الأفلام تظهر في تبويب "أفلام"'),
                          items: const [
                            DropdownMenuItem<String?>(
                                value: null, child: Text('غير محدد')),
                            DropdownMenuItem<String?>(
                                value: 'TV',
                                child: Text('مسلسل تلفزيوني (TV)')),
                            DropdownMenuItem<String?>(
                                value: 'TV_SHORT',
                                child: Text('مسلسل قصير (TV Short)')),
                            DropdownMenuItem<String?>(
                                value: 'MOVIE',
                                child: Text('فيلم (Movie)')),
                            DropdownMenuItem<String?>(
                                value: 'OVA', child: Text('OVA')),
                            DropdownMenuItem<String?>(
                                value: 'ONA', child: Text('ONA')),
                            DropdownMenuItem<String?>(
                                value: 'SPECIAL',
                                child: Text('حلقة خاصة (Special)')),
                          ],
                          onChanged: (value) {
                            setDialogState(() => selectedFormat = value);
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                                child: TextField(
                                    controller: episodesController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText:
                                            'إجمالي الحلقات'))),
                            const SizedBox(width: 10),
                            Expanded(
                                child: TextField(
                                    controller: watchedController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'شاهدت منها',
                                        prefixIcon: Icon(
                                            Icons.play_arrow,
                                            size: 16)))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                            controller: yearController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'سنة النزول')),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: [
                            '',
                            'مكتمل',
                            'أتابعه',
                            'مخطط له',
                            'متوقف'
                          ].contains(status)
                              ? status
                              : '',
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'حالة المشاهدة (اختياري)'),
                          items: const [
                            DropdownMenuItem(
                                value: '', child: Text('لم أحدد')),
                            DropdownMenuItem(
                                value: 'مكتمل', child: Text('مكتمل')),
                            DropdownMenuItem(
                                value: 'أتابعه', child: Text('أتابعه')),
                            DropdownMenuItem(
                                value: 'مخطط له', child: Text('مخطط له')),
                            DropdownMenuItem(
                                value: 'متوقف', child: Text('متوقف')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => status = value);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        Column(
                          children: [
                            Text(
                                'تقييمك: ${rating.toStringAsFixed(1)} / 10',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColorNotifier.value,
                                    fontSize: 16)),
                            Slider(
                              value: rating,
                              min: 0,
                              max: 10,
                              divisions: 20,
                              label: rating.toStringAsFixed(1),
                              activeColor: const Color(0xFFFFC857),
                              onChanged: (value) {
                                setDialogState(() => rating = value);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                            controller: summaryController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                                labelText: 'ملخص القصة (اختياري)')),
                        const SizedBox(height: 10),
                        TextField(
                            controller: memoryController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                                labelText: 'ذكرياتك (اختياري)')),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: primaryColorNotifier.value),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(dialogContext, true);
                    },
                    child: const Text('حفظ التعديلات'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != true) {
        if (imageChanged &&
            imagePath != null &&
            imagePath != anime.imagePath) {
          try {
            final file = File(imagePath!);
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }
        return;
      }

      final allAnimes = await storage.loadAnimes();
      final idx = allAnimes.indexWhere((a) => a.id == anime.id);
      if (idx == -1) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('لم يتم العثور على الأنمي في التخزين.')));
        return;
      }

      final oldImagePath = allAnimes[idx].imagePath;
      allAnimes[idx]
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
        ..imagePath = imagePath
        ..format = selectedFormat;

      final saved = await storage.saveAnimes(allAnimes);
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
        await loadAnimes();
        if (!mounted) return;
        AppEvents.fire('anime_edited'); // 🆕
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ تعديلات الأنمي')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر حفظ التعديلات، حاول مرة أخرى')));
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

  Widget _buildAnimeTitle(String title,
      {double fontSize = 16, bool lightText = false}) {
    final fontName = fontNotifier.value;
    final titleColor = titleColorNotifier.value;

    TextStyle textStyle;
    if (fontName == 'Cairo') {
      textStyle = GoogleFonts.cairo(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: lightText ? Colors.white : titleColor);
    } else if (fontName == 'Tajawal') {
      textStyle = GoogleFonts.tajawal(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: lightText ? Colors.white : titleColor);
    } else if (fontName == 'Almarai') {
      textStyle = GoogleFonts.almarai(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: lightText ? Colors.white : titleColor);
    } else if (fontName == 'Changa') {
      textStyle = GoogleFonts.changa(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: lightText ? Colors.white : titleColor);
    } else {
      textStyle = TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: lightText ? Colors.white : titleColor);
    }

    return Text(
      title.trim().isEmpty ? 'أنمي بدون اسم' : title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: textStyle.copyWith(
          shadows: [Shadow(color: Colors.black87, blurRadius: 10)]),
    );
  }

  Widget _buildProgressBar(Anime anime, {bool onImage = false}) {
    if (anime.episodes <= 0 || anime.watchedEpisodes <= 0) {
      return const SizedBox.shrink();
    }

    if (anime.watchedEpisodes >= anime.episodes) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            const Icon(Icons.check_circle,
                color: Colors.greenAccent, size: 16),
            const SizedBox(width: 4),
            Text('مكتمل (${anime.episodes})',
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    double progress = anime.watchedEpisodes / anime.episodes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(
                onImage ? Colors.cyan : primaryColorNotifier.value),
            borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 4),
        Text('شاهدت ${anime.watchedEpisodes} من ${anime.episodes}',
            style: TextStyle(
                color: onImage ? Colors.white70 : Colors.white54,
                fontSize: 10)),
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
      decoration: BoxDecoration(
          color: const Color(0xFF1B1F28),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.4), width: 1),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2)
          ]),
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _onCardTap(anime),
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
                          const SizedBox(height: 4),
                          _buildQuickRating(anime),
                          const SizedBox(height: 6),
                          Text(
                              anime.genre.isEmpty
                                  ? 'بدون تصنيف'
                                  : anime.genre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                          if (details.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(details,
                                style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                          Row(
                            children: [
                              if (anime.globalRating != null) ...[
                                const SizedBox(height: 5),
                                const Icon(Icons.public,
                                    size: 14, color: Colors.cyan),
                                const SizedBox(width: 4),
                                Text(
                                    '${anime.globalRating!.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.cyan)),
                              ],
                            ],
                          ),
                          _buildProgressBar(anime),
                          if (anime.favorite) ...[
                            const SizedBox(height: 5),
                            const Row(children: [
                              Icon(Icons.favorite,
                                  size: 14, color: Color(0xFFFF5364)),
                              SizedBox(width: 4),
                              Text('في المفضلة',
                                  style: TextStyle(
                                      color: Color(0xFFFF5364),
                                      fontSize: 11))
                            ]),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (!_selectionMode) _animeMenu(anime),
                ],
              ),
            ),
          ),
          if (_selectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: _selectionCheckbox(anime),
            ),
        ],
      ),
    );
  }

  Widget _buildGridCard(Anime anime) {
    final color = colors[anime.colorIndex.abs() % colors.length];
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFF1B1F28),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.4), width: 1),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2)
          ]),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _onCardTap(anime),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _animeImage(anime, color, compact: true),
                  if (!_selectionMode)
                    Positioned(
                        top: 2,
                        right: 2,
                        child: Material(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(30),
                            child: SizedBox(
                                width: 38,
                                height: 38,
                                child: _animeMenu(anime, light: true)))),
                  if (anime.favorite && !_selectionMode)
                    const Positioned(
                        left: 8,
                        top: 8,
                        child: Icon(Icons.favorite,
                            color: Color(0xFFFF5364), size: 19)),
                  if (_selectionMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _selectionCheckbox(anime),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAnimeTitle(anime.title, fontSize: 13),
                  const SizedBox(height: 2),
                  _buildQuickRating(anime),
                  const SizedBox(height: 2),
                  Text(
                      anime.genre.isEmpty ? 'بدون تصنيف' : anime.genre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
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
      decoration: BoxDecoration(
          color: const Color(0xFF1B1F28),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.4), width: 1),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2)
          ]),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _onCardTap(anime),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _animeImage(anime, color, compact: true),
                  if (_selectionMode)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Transform.scale(
                          scale: 0.8,
                          child: _selectionCheckbox(anime)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAnimeTitle(anime.title, fontSize: 11),
                  if (anime.rating > 0) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.star,
                          size: 12, color: Color(0xFFFFC857)),
                      const SizedBox(width: 3),
                      Text('${anime.rating.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 10))
                    ])
                  ],
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

    return GestureDetector(
      onTap: () => _onCardTap(anime),
      child: Container(
        height: 220,
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 2)
            ]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imagePath != null && File(imagePath).existsSync())
                Hero(
                    tag: 'anime_image_${anime.id}',
                    child: Image.file(File(imagePath), fit: BoxFit.cover))
              else
                Container(
                    color: Colors.black26,
                    child: const Icon(Icons.movie,
                        size: 50, color: Colors.white24)),
              Container(
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [
                    Colors.transparent,
                    Colors.black87,
                    Colors.black
                  ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.4, 0.8, 1.0]))),
              Positioned(
                bottom: 15,
                left: 15,
                right: 15,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAnimeTitle(anime.title,
                        fontSize: 18, lightText: true),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(
                                anime.genre.isEmpty
                                    ? 'بدون تصنيف'
                                    : anime.genre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12))),
                        _buildQuickRating(anime, lightText: true),
                      ],
                    ),
                    _buildProgressBar(anime, onImage: true),
                  ],
                ),
              ),
              if (!_selectionMode)
                Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(30),
                        child: SizedBox(
                            width: 38,
                            height: 38,
                            child: _animeMenu(anime, light: true)))),
              if (anime.favorite && !_selectionMode)
                const Positioned(
                    left: 10,
                    top: 10,
                    child: Icon(Icons.favorite,
                        color: Color(0xFFFF5364), size: 22)),
              if (_selectionMode)
                Positioned(
                  top: 10,
                  left: 10,
                  child: _selectionCheckbox(anime),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactListCard(Anime anime) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: const Color(0xFF1B1F28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10)),
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onCardTap(anime),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Hero(
                      tag: 'anime_image_${anime.id}',
                      child: anime.imagePath != null &&
                              File(anime.imagePath!).existsSync()
                          ? Image.file(File(anime.imagePath!),
                              width: 45, height: 45, fit: BoxFit.cover)
                          : Container(
                              width: 45,
                              height: 45,
                              color: Colors.black26,
                              child: const Icon(Icons.movie,
                                  size: 20, color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAnimeTitle(anime.title, fontSize: 14),
                        const SizedBox(height: 4),
                        _buildQuickRating(anime),
                        const SizedBox(height: 4),
                        Text(
                            anime.genre.isEmpty
                                ? 'بدون تصنيف'
                                : anime.genre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ),
                  if (!_selectionMode) _animeMenu(anime),
                ],
              ),
            ),
          ),
          if (_selectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: _selectionCheckbox(anime),
            ),
        ],
      ),
    );
  }

  Widget _animeMenu(Anime anime, {bool light = false}) {
    final isMovie = anime.format == 'MOVIE';
    return PopupMenuButton<String>(
      tooltip: 'خيارات الأنمي',
      padding: EdgeInsets.zero,
      iconSize: 22,
      icon: Icon(Icons.more_vert,
          color: light ? Colors.white : Colors.white70),
      onSelected: (value) async {
        switch (value) {
          case 'edit':
            await editAnime(anime);
            break;
          case 'favorite':
            await toggleFavorite(anime);
            break;
          case 'trash':
            await moveToTrash(anime);
            break;
          case 'fetch_data':
            await _fetchDataManually(anime);
            break;
          case 'toggle_movie':
            await toggleMovieFormat(anime);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined),
              SizedBox(width: 10),
              Text('تعديل بيانات الأنمي')
            ])),
        const PopupMenuItem(
            value: 'fetch_data',
            child: Row(children: [
              Icon(Icons.cloud_download_outlined, color: Colors.cyan),
              SizedBox(width: 10),
              Text('جلب البيانات والصور')
            ])),
        PopupMenuItem(
            value: 'toggle_movie',
            child: Row(children: [
              Icon(isMovie ? Icons.tv : Icons.movie,
                  color: Colors.orangeAccent),
              const SizedBox(width: 10),
              Text(isMovie
                  ? 'نقل إلى المسلسلات'
                  : 'إضافة إلى قائمة الأفلام'),
            ])),
        PopupMenuItem(
            value: 'favorite',
            child: Row(children: [
              const Icon(Icons.favorite_border,
                  color: Color(0xFFFF5364)),
              const SizedBox(width: 10),
              Text(anime.favorite
                  ? 'إزالة من المفضلة'
                  : 'إضافة إلى المفضلة')
            ])),
        const PopupMenuItem(
            value: 'trash',
            child: Row(children: [
              Icon(Icons.delete_outline, color: Color(0xFFFF6B72)),
              SizedBox(width: 10),
              Text('نقل إلى سلة المهملات')
            ])),
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
            onSelected: (value) {
              HapticFeedback.selectionClick();
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
              PopupMenuItem(value: 'random', child: Text('عشوائي 🎲')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                  color: const Color(0xFF1B1F28),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12)),
              child: Row(children: [
                const Icon(Icons.sort, size: 19),
                const SizedBox(width: 8),
                Expanded(child: Text(sortLabel, overflow: TextOverflow.ellipsis)),
                const Icon(Icons.keyboard_arrow_down)
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          decoration: BoxDecoration(
              color: const Color(0xFF1B1F28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12)),
          child: IconButton(
            tooltip: 'تغيير العرض',
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => viewMode = (viewMode + 1) % 5);
              _saveLibraryPreferences();
            },
            icon: Icon(getViewIcon(), color: const Color(0xFFFFC857)),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          decoration: BoxDecoration(
              color: _selectionMode
                  ? primaryColorNotifier.value
                  : const Color(0xFF1B1F28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _selectionMode
                      ? primaryColorNotifier.value
                      : Colors.white12,
                  width: _selectionMode ? 2 : 1)),
          child: IconButton(
            tooltip: _selectionMode ? 'إلغاء التحديد' : 'تحديد متعدد',
            onPressed: _toggleSelectionMode,
            icon: Icon(
              _selectionMode ? Icons.close : Icons.checklist,
              color: _selectionMode ? Colors.white : const Color(0xFFFFC857),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonLoader() {
    return Column(
      children: List.generate(
          5,
          (index) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 120,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(18)),
                child: Row(
                  children: [
                    Container(
                        width: 76,
                        height: 96,
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(13))),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                            width: 150,
                            height: 16,
                            color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 10),
                        Container(
                            width: 100,
                            height: 12,
                            color: Colors.white.withOpacity(0.05)),
                      ],
                    )),
                  ],
                ),
              )),
    );
  }

  Widget _buildSelectionActionBar(Color primaryColor) {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1F28),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withOpacity(0.6), width: 2),
          boxShadow: [
            BoxShadow(
                color: primaryColor.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 3)
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: primaryColor, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${_selectedAnimeIds.length} محدد',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            if (_selectedAnimeIds.isNotEmpty)
              IconButton(
                tooltip: 'إلغاء التحديد',
                onPressed: _clearSelection,
                icon: const Icon(Icons.clear_all,
                    color: Colors.white70, size: 20),
              ),
            IconButton(
              tooltip: 'تحديد الكل',
              onPressed: _selectAllVisible,
              icon: const Icon(Icons.select_all, color: Colors.cyan, size: 20),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: _selectedAnimeIds.isEmpty ? null : _markSelectedAsCompleted,
              icon: const Icon(Icons.done_all, size: 18),
              label: Text('إكمال (${_selectedAnimeIds.length})',
                  style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = filteredAnimes;
    final primaryColor = primaryColorNotifier.value;
    final hasAdvancedFilter = _advFromYear != null ||
        _advToYear != null ||
        _advGenres.isNotEmpty;

    Widget buildContent() {
      if (loading) return _buildSkeletonLoader();

      if (items.isEmpty) {
        return Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
              color: const Color(0xFF1B1F28),
              borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              const Icon(Icons.video_library_outlined,
                  size: 50, color: Colors.white38),
              const SizedBox(height: 12),
              Text(animes.isEmpty ? 'مكتبتك فارغة' : 'لا توجد نتائج مطابقة',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('أضف أنمياتك من الصفحة الرئيسية.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54)),
            ],
          ),
        );
      }

      switch (viewMode) {
        case 1:
          return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.55),
              itemBuilder: (context, index) =>
                  _wrapWithSwipe(items[index], _buildGridCard(items[index])));
        case 2:
          return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.6),
              itemBuilder: (context, index) => _wrapWithSwipe(
                  items[index], _buildCompactGridCard(items[index])));
        case 3:
          return Column(
              children: items
                  .map((a) => _wrapWithSwipe(a, _buildCinematicCard(a)))
                  .toList());
        case 4:
          return Column(
              children: items
                  .map((a) => _wrapWithSwipe(a, _buildCompactListCard(a)))
                  .toList());
        case 0:
        default:
          return Column(
              children:
                  items.map((a) => _wrapWithSwipe(a, _buildRowCard(a))).toList());
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _showBackToTop && !_selectionMode
          ? FloatingActionButton(
              mini: true,
              backgroundColor: primaryColor,
              onPressed: () {
                HapticFeedback.lightImpact();
                _scrollController.animateTo(0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut);
              },
              child: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
            )
          : null,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: loadAnimes,
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: false,
              trackVisibility: false,
              thickness: 8,
              radius: const Radius.circular(10),
              interactive: true,
              child: ListView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(18),
                children: [
                  const Text('مكتبة الأنمي',
                      style: TextStyle(
                          fontSize: 27, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('كل أعمالك في مكان واحد • ${animes.length} أنمي',
                      style: const TextStyle(color: Colors.white60)),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'ابحث عن أنمي أو تصنيف...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: searchText.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      searchController.clear();
                                      setState(() => searchText = '');
                                    },
                                    icon: const Icon(Icons.close))
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: hasAdvancedFilter
                              ? primaryColor
                              : const Color(0xFF1B1F28),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: primaryColor.withOpacity(0.5)),
                        ),
                        child: IconButton(
                          tooltip: 'البحث المتقدم',
                          icon: Icon(Icons.tune,
                              color: hasAdvancedFilter
                                  ? Colors.white
                                  : primaryColor),
                          onPressed: _showAdvancedSearch,
                        ),
                      ),
                    ],
                  ),
                  if (hasAdvancedFilter) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: primaryColor.withOpacity(0.4))),
                      child: Row(
                        children: [
                          Icon(Icons.filter_alt, color: primaryColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('فلتر متقدم نشط',
                                style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _advFromYear = null;
                                _advToYear = null;
                                _advGenres = [];
                              });
                            },
                            child: const Icon(Icons.clear,
                                color: Colors.white70, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['الكل', 'مسلسلات', 'أفلام'].map((type) {
                        final selected = selectedType == type;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(type),
                            selected: selected,
                            selectedColor: Colors.orangeAccent,
                            backgroundColor: const Color(0xFF1B1F28),
                            side: BorderSide(
                                color: selected
                                    ? Colors.orangeAccent
                                    : Colors.white12),
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              setState(() => selectedType = type);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        'الكل', 'مكتمل', 'أتابعه', 'مخطط له', 'متوقف',
                        'المفضلة', 'جُلب تلقائياً', 'بدون تصنيف',
                        'قيد المشاهدة (تقدم)'
                      ].map((status) {
                        final selected = selectedStatus == status;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(status),
                            selected: selected,
                            selectedColor: primaryColor,
                            backgroundColor: const Color(0xFF1B1F28),
                            side: BorderSide(
                                color: selected ? primaryColor : Colors.white12),
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              setState(() => selectedStatus = status);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        'كل التقييمات', '10', '9.5', '9', '8.5', '8', '7.5',
                        '7', '6.5', '6', '5.5', '5', '4.5', '4', '3.5', '3',
                        '2.5', '2', '1.5', '1', '0.5'
                      ].map((rate) {
                        final val =
                            rate == 'كل التقييمات' ? 0.0 : double.parse(rate);
                        final selected = selectedRatingFilter == val;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(rate),
                            selected: selected,
                            selectedColor: const Color(0xFFFFC857),
                            backgroundColor: const Color(0xFF1B1F28),
                            side: BorderSide(
                                color: selected
                                    ? const Color(0xFFFFC857)
                                    : Colors.white12),
                            labelStyle: TextStyle(
                                color:
                                    selected ? Colors.black : Colors.white),
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              setState(() => selectedRatingFilter = val);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildToolbar(),
                  const SizedBox(height: 18),
                  buildContent(),
                  SizedBox(height: _selectionMode ? 120 : 80),
                ],
              ),
            ),
          ),
          if (_selectionMode) _buildSelectionActionBar(primaryColor),
        ],
      ),
    );
  }
}
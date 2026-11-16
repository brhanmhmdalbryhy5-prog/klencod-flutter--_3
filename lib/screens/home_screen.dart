import 'dart:io';
import 'dart:math';

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
import '../widgets/manga_character.dart'; // ضروري لاستخدام FloatingMangaCharacter
import 'anime_details_screen.dart';
import 'otaku_oracle_screen.dart';
import 'random_picker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService storage = StorageService();
  final AnimeApiService apiService = AnimeApiService();
  final ImagePicker imagePicker = ImagePicker();

  List<Anime> animes = [];
  List<Anime> _allAnimes = [];
  bool loading = true;
  bool isAutoFetching = false;

  final List<Color> colors = const [
    Color(0xFF741C2B), Color(0xFF247BA0), Color(0xFF7651A8),
    Color(0xFFB87928), Color(0xFF27866F), Color(0xFFB34E68)
  ];

  final List<String> allGenres = const [
    'أكشن', 'مغامرة', 'كوميدي', 'دراما', 'فانتازيا', 'رعب',
    'إيتشي', 'ميكا', 'غموض', 'رومانسي', 'خيال علمي', 'شريحة من الحياة',
    'رياضة', 'إثارة', 'حريم', 'مدرسي', 'شونين', 'سينين',
    'جوسي', 'شوجو', 'قوى خارقة', 'تاريخي', 'موسيقي', 'نفسي',
    'فامباير', 'سحر', 'حربي', 'فضاء', 'بوليسي', 'عائلي',
    'ألعاب', 'فنون قتالية', 'ساموراي', 'شياطين', 'إيسيكاي'
  ];

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    await loadData();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('auto_fetch_enabled') ?? false) {
      _autoFetchMissingData();
    }
  }

  Future<void> loadData() async {
    final result = await storage.loadAnimes();
    if (!mounted) return;
    setState(() {
      _allAnimes = result;
      animes = result.where((a) => a.parentId == null).toList();
      loading = false;
    });
    // إخبار الشخصية العائمة إذا كانت المكتبة فارغة
    if (result.isEmpty) {
      FloatingMangaCharacter.say('empty_library');
    }
  }

  Future<void> _autoFetchMissingData() async {
    if (isAutoFetching) return;
    final missingData = animes.where((a) =>
        a.genre.trim().isEmpty ||
        a.summary.trim().isEmpty ||
        a.episodes == 0 ||
        a.globalRating == null ||
        a.releaseYear == null).toList();
    if (missingData.isEmpty) return;

    setState(() => isAutoFetching = true);
    bool hasChanges = false;

    for (var anime in missingData) {
      final data = await apiService.fetchAnimeData(anime.title);
      if (data['genres'].isNotEmpty && anime.genre.trim().isEmpty) {
        anime.genre = data['genres'].join('، ');
        hasChanges = true;
      }
      if (data['summary'].isNotEmpty && anime.summary.trim().isEmpty) {
        anime.summary = data['summary'];
        hasChanges = true;
      }
      if (data['episodes'] > 0 && anime.episodes == 0) {
        anime.episodes = data['episodes'];
        hasChanges = true;
      }
      if (data['globalRating'] != null && anime.globalRating == null) {
        anime.globalRating = data['globalRating'];
        hasChanges = true;
      }
      if (data['releaseYear'] != null && anime.releaseYear == null) {
        anime.releaseYear = data['releaseYear'];
        hasChanges = true;
      }
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (hasChanges) {
      await storage.saveAnimes(_allAnimes);
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => isAutoFetching = false);
  }

  int get completed => animes.where((a) => a.status == 'مكتمل').length;
  int get watching => animes.where((a) => a.status == 'أتابعه').length;
  int get planned => animes.where((a) => a.status == 'مخطط له').length;

  double get averageRating {
    final rated = animes.where((a) => a.rating > 0).toList();
    if (rated.isEmpty) return 0;
    return rated.fold<double>(0, (sum, a) => sum + a.rating) / rated.length;
  }

  List<Anime> get _continueWatchingList {
    final inProgress = _allAnimes.where((a) {
      return a.watchedEpisodes > 0 &&
          (a.episodes == 0 || a.watchedEpisodes < a.episodes);
    }).toList();

    inProgress.sort((a, b) {
      final dateA = DateTime.tryParse(a.date) ?? DateTime(2000);
      final dateB = DateTime.tryParse(b.date) ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    return inProgress.take(5).toList();
  }

  Future<void> _incrementWatched(Anime anime) async {
    if (anime.episodes > 0 && anime.watchedEpisodes >= anime.episodes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ هذا الأنمي مكتمل بالفعل'),
              duration: Duration(seconds: 1)),
        );
      }
      return;
    }

    HapticFeedback.lightImpact();
    final all = await storage.loadAnimes();
    final idx = all.indexWhere((a) => a.id == anime.id);
    if (idx == -1) return;

    all[idx].watchedEpisodes++;
    final isNowComplete = all[idx].episodes > 0 &&
        all[idx].watchedEpisodes >= all[idx].episodes;
    if (isNowComplete) all[idx].status = 'مكتمل';
    await storage.saveAnimes(all);
    await loadData();

    FloatingMangaCharacter.say(isNowComplete ? 'complete' : 'progress_congrats');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNowComplete
              ? '🎉 اكتمل ${anime.title}!'
              : '➕ ${anime.title}: ${all[idx].watchedEpisodes}/${all[idx].episodes}'),
          duration: const Duration(milliseconds: 1500),
          backgroundColor: isNowComplete ? Colors.green : Colors.blue,
        ),
      );
    }
  }

  Widget _buildContinueWatching(Color primaryColor) {
    final list = _continueWatchingList;
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.play_circle, color: primaryColor, size: 22),
            const SizedBox(width: 8),
            const Text('استمر في المشاهدة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('${list.length}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        ...list.map((anime) => _buildContinueCard(anime, primaryColor)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildContinueCard(Anime anime, Color primaryColor) {
    final progress = anime.episodes > 0
        ? (anime.watchedEpisodes / anime.episodes).clamp(0.0, 1.0)
        : 0.0;

    final hasImage = anime.imagePath != null &&
        File(anime.imagePath!).existsSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: primaryColor.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 2)
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AnimeDetailsScreen(anime: anime)),
          );
          await loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: hasImage
                    ? Image.file(File(anime.imagePath!),
                        width: 60, height: 80, fit: BoxFit.cover)
                    : Container(
                        width: 60,
                        height: 80,
                        color: primaryColor.withOpacity(0.2),
                        child:
                            Icon(Icons.movie, color: primaryColor, size: 28),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(anime.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      'شاهدت ${anime.watchedEpisodes}/${anime.episodes == 0 ? "?" : anime.episodes}',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: primaryColor,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _incrementWatched(anime),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 22),
                        Text('+1',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
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

  Future<void> addAnime() async {
    HapticFeedback.lightImpact();
    final titleController = TextEditingController();
    final episodesController = TextEditingController();
    final yearController = TextEditingController();
    final characterController = TextEditingController();
    final summaryController = TextEditingController();
    final memoryController = TextEditingController();

    String status = '';
    double rating = 0.0;
    XFile? selectedImage;
    List<String> selectedGenres = [];

    final result = await showDialog<Anime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B1F28),
              title: const Text('إضافة أنمي جديد',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          try {
                            final image = await imagePicker.pickImage(
                                source: ImageSource.gallery, imageQuality: 85);
                            if (image != null) {
                              setDialogState(() => selectedImage = image);
                            }
                          } catch (_) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                    content: Text('تعذر اختيار الصورة.')));
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 155,
                          decoration: BoxDecoration(
                              color: const Color(0xFF111318),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: primaryColorNotifier.value)),
                          clipBehavior: Clip.antiAlias,
                          child: selectedImage == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                      Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 42,
                                          color:
                                              primaryColorNotifier.value),
                                      const SizedBox(height: 9),
                                      const Text(
                                          'اختر صورة للأنمي (اختياري)'),
                                      const SizedBox(height: 4),
                                      const Text(
                                          'اضغط هنا لفتح المعرض',
                                          style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12))
                                    ])
                              : Stack(fit: StackFit.expand, children: [
                                  Image.file(File(selectedImage!.path),
                                      fit: BoxFit.cover),
                                  Positioned(
                                      left: 8,
                                      top: 8,
                                      child: IconButton(
                                          onPressed: () => setDialogState(
                                              () => selectedImage = null),
                                          style: IconButton.styleFrom(
                                              backgroundColor:
                                                  Colors.black87,
                                              foregroundColor:
                                                  Colors.white),
                                          icon: const Icon(Icons.close)))
                                ]),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Align(
                          alignment: Alignment.centerRight,
                          child: Text('المعلومات (كلها اختيارية)',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 12))),
                      const SizedBox(height: 10),
                      TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                              labelText: 'اسم الأنمي (اختياري)',
                              prefixIcon: Icon(Icons.movie_outlined))),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final newGenres =
                              await _showGenrePicker(selectedGenres);
                          if (newGenres != null) {
                            setDialogState(
                                () => selectedGenres = newGenres);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                              labelText: 'التصنيفات (اختياري)',
                              prefixIcon: Icon(Icons.category_outlined),
                              suffixIcon: Icon(Icons.arrow_drop_down)),
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
                      const SizedBox(height: 12),
                      TextField(
                          controller: characterController,
                          decoration: const InputDecoration(
                              labelText: 'الشخصية المفضلة (اختياري)',
                              prefixIcon: Icon(Icons.person_outline))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child: TextField(
                                  controller: episodesController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'عدد الحلقات',
                                      prefixIcon: Icon(
                                          Icons.play_circle_outline)))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: TextField(
                                  controller: yearController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'سنة النزول',
                                      prefixIcon: Icon(
                                          Icons.calendar_today)))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: status,
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
                      const SizedBox(height: 16),
                      Column(
                        children: [
                          Text('تقييمك: ${rating.toStringAsFixed(1)} / 10',
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
                      const SizedBox(height: 12),
                      TextField(
                          controller: summaryController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'ملخص القصة (اختياري)',
                              alignLabelWithHint: true,
                              prefixIcon:
                                  Icon(Icons.menu_book_outlined))),
                      const SizedBox(height: 12),
                      TextField(
                          controller: memoryController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'ذكرياتك مع الأنمي (اختياري)',
                              alignLabelWithHint: true,
                              prefixIcon:
                                  Icon(Icons.auto_awesome_outlined))),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('إلغاء')),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: primaryColorNotifier.value),
                  onPressed: () {
                    final anime = Anime(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      title: titleController.text.trim(),
                      genre: selectedGenres.join('، '),
                      character: characterController.text.trim(),
                      summary: summaryController.text.trim(),
                      memory: memoryController.text.trim(),
                      episodes: int.tryParse(episodesController.text) ?? 0,
                      releaseYear: int.tryParse(yearController.text),
                      status: status,
                      rating: rating,
                      colorIndex: animes.length % colors.length,
                      date: DateTime.now().toIso8601String(),
                    );
                    Navigator.pop(dialogContext, anime);
                  },
                  child: const Text('حفظ الأنمي'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    episodesController.dispose();
    yearController.dispose();
    characterController.dispose();
    summaryController.dispose();
    memoryController.dispose();

    if (result == null) return;

    try {
      if (selectedImage != null) {
        result.imagePath = await _saveImageLocally(selectedImage!.path);
      }
      _allAnimes.add(result);
      animes.add(result);
      final saved = await storage.saveAnimes(_allAnimes);
      if (!mounted) return;

      if (saved) {
        if (result.rating >= 8) {
          FloatingMangaCharacter.say('high_rate');
        } else if (result.rating > 0 && result.rating < 5) {
          FloatingMangaCharacter.say('low_rate');
        } else {
          FloatingMangaCharacter.say('add_anime');
        }
      }

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(saved ? 'تم حفظ الأنمي في مكتبتك' : 'تعذر حفظ البيانات.')));

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('auto_fetch_enabled') ?? false) {
        if (result.genre.isEmpty ||
            result.summary.isEmpty ||
            result.globalRating == null ||
            result.releaseYear == null) {
          _autoFetchMissingData();
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ الصورة أو البيانات.')));
    }
  }

  Widget _animeImage(Anime anime, Color color) {
    final path = anime.imagePath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Image.file(File(path),
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _imagePlaceholder(color)));
    }
    return _imagePlaceholder(color);
  }

  Widget _imagePlaceholder(Color color) {
    return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(13)),
        child: Icon(Icons.movie_outlined, color: color));
  }

  Widget _oracleButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
            colors: [
              primaryColorNotifier.value,
              primaryColorNotifier.value.withOpacity(0.5),
              const Color(0xFF202431)
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        border: Border.all(
            color: primaryColorNotifier.value.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: primaryColorNotifier.value.withOpacity(0.5),
              blurRadius: 25,
              spreadRadius: 5)
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            FloatingMangaCharacter.say('thinking');
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const OtakuOracleScreen()));
          },
          child: const Padding(
            padding: EdgeInsets.all(17),
            child: Row(
              children: [
                CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.psychology_alt,
                        color: Colors.white, size: 29)),
                SizedBox(width: 13),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('مرآة الأوتاكو',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      SizedBox(height: 5),
                      Text('اكتشف ملامح ذوقك في عالم الأنمي',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12))
                    ])),
                Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _randomPickerButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
            colors: [Color(0xFF247BA0), Color(0xFF27866F), Color(0xFF202431)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        border:
            Border.all(color: Colors.cyan.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.cyan.withOpacity(0.5),
              blurRadius: 25,
              spreadRadius: 5)
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            FloatingMangaCharacter.say('random_pick');
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RandomPickerScreen()));
          },
          child: const Padding(
            padding: EdgeInsets.all(17),
            child: Row(
              children: [
                CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.casino, color: Colors.white, size: 29)),
                SizedBox(width: 13),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('قرعة الأنمي 🎲',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      SizedBox(height: 5),
                      Text('ماذا أشاهد الآن؟',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12))
                    ])),
                Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Column(
      children: List.generate(
          5,
          (index) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                height: 70,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(17)),
                child: Row(
                  children: [
                    Container(
                        width: 50,
                        height: 50,
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(13))),
                    Expanded(
                        child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            width: 150,
                            height: 14,
                            color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 8),
                        Container(
                            width: 80,
                            height: 10,
                            color: Colors.white.withOpacity(0.05)),
                      ],
                    )),
                  ],
                ),
              )),
    );
  }

  Widget _buildLatestAchievementCard() {
    int totalCount = animes.length;
    if (totalCount < 10) return const SizedBox.shrink();

    final List<Color> achColors = [
      const Color(0xFFCD7F32), const Color(0xFFC0C0C0), const Color(0xFFFFD700),
      const Color(0xFF00E5FF), const Color(0xFFE040FB), const Color(0xFFFF5252),
      const Color(0xFF69F0AE), const Color(0xFFFFAB40), const Color(0xFF448AFF),
      const Color(0xFFFF4081)
    ];

    final List<IconData> achIcons = [
      Icons.star_border, Icons.explore, Icons.local_cafe, Icons.psychology,
      Icons.auto_awesome, Icons.verified, Icons.workspace_premium,
      Icons.military_tech, Icons.diamond, Icons.emoji_events
    ];

    final List<String> achTitles = [
      'البداية', 'المستكشف', 'الباحث', 'المتذوق', 'الهاوي', 'المشجع',
      'المحلل', 'الناقد', 'الأسطورة الصاعدة', 'الخبير',
      'المبتدئ المعتمد', 'المغامر', 'جامع القصص', 'عاشق الأنمي', 'صائد الجواهر',
      'المتابع', 'المراجع', 'المستشار',
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../main.dart';
import '../models/anime.dart';
import '../services/storage_service.dart';
import '../services/anime_api_service.dart';
import 'otaku_oracle_screen.dart';

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
  bool loading = true;
  bool isAutoFetching = false;

  final List<Color> colors = const [
    Color(0xFF741C2B), Color(0xFF247BA0), Color(0xFF7651A8),
    Color(0xFFB87928), Color(0xFF27866F), Color(0xFFB34E68),
  ];

  final List<String> allGenres = const [
    'أكشن', 'مغامرة', 'كوميدي', 'دراما', 'فانتازيا', 'رعب',
    'إيتشي', 'ميكا', 'غموض', 'رومانسي', 'خيال علمي', 'شريحة من الحياة',
    'رياضة', 'إثارة', 'حريم', 'مدرسي', 'شونين', 'سينين',
    'جوسي', 'شوجو', 'قوى خارقة', 'تاريخي', 'موسيقي', 'نفسي',
    'فامباير', 'سحر', 'حربي', 'فضاء', 'بوليسي', 'عائلي',
    'ألعاب', 'فنون قتالية', 'ساموراي', 'شياطين', 'إيسيكاي',
  ];

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    await loadData();
    _autoFetchMissingData();
  }

  Future<void> loadData() async {
    final result = await storage.loadAnimes();
    if (!mounted) return;
    setState(() {
      animes = result;
      loading = false;
    });
  }

  Future<void> _autoFetchMissingData() async {
    if (isAutoFetching) return;
    
    // نبحث عن أنميات لا تحتوي على تصنيف أو قصة
    final missingData = animes.where((a) => a.genre.trim().isEmpty || a.summary.trim().isEmpty).toList();
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
      
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (hasChanges) {
      await storage.saveAnimes(animes);
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
    return rated.fold<int>(0, (sum, a) => sum + a.rating) / rated.length;
  }

  Future<String> _saveImageLocally(String sourcePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagesDirectory = Directory('${directory.path}/anime_images');
    if (!await imagesDirectory.exists()) await imagesDirectory.create(recursive: true);
    final extension = sourcePath.contains('.') ? sourcePath.substring(sourcePath.lastIndexOf('.')) : '.jpg';
    final destinationPath = '${imagesDirectory.path}/${DateTime.now().microsecondsSinceEpoch}$extension';
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
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: primaryColorNotifier.value),
                  onPressed: () => Navigator.pop(dialogContext, selected.toList()),
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
    final titleController = TextEditingController();
    final episodesController = TextEditingController();
    final characterController = TextEditingController();
    final summaryController = TextEditingController();
    final memoryController = TextEditingController();

    String status = '';
    int rating = 0;
    XFile? selectedImage;
    List<String> selectedGenres = [];

    final result = await showDialog<Anime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B1F28),
              title: const Text('إضافة أنمي جديد', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          try {
                            final image = await imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                            if (image != null) setDialogState(() => selectedImage = image);
                          } catch (_) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('تعذر اختيار الصورة.')));
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 155,
                          decoration: BoxDecoration(
                            color: const Color(0xFF111318),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: primaryColorNotifier.value),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: selectedImage == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined, size: 42, color: primaryColorNotifier.value),
                                    const SizedBox(height: 9),
                                    const Text('اختر صورة للأنمي (اختياري)'),
                                    const SizedBox(height: 4),
                                    const Text('اضغط هنا لفتح المعرض', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                )
                              : Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(File(selectedImage!.path), fit: BoxFit.cover),
                                    Positioned(
                                      left: 8, top: 8,
                                      child: IconButton(
                                        onPressed: () => setDialogState(() => selectedImage = null),
                                        style: IconButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
                                        icon: const Icon(Icons.close),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Align(alignment: Alignment.centerRight, child: Text('المعلومات (كلها اختيارية)', style: TextStyle(color: Colors.white60, fontSize: 12))),
                      const SizedBox(height: 10),
                      TextField(controller: titleController, decoration: const InputDecoration(labelText: 'اسم الأنمي (اختياري)', prefixIcon: Icon(Icons.movie_outlined))),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final newGenres = await _showGenrePicker(selectedGenres);
                          if (newGenres != null) setDialogState(() => selectedGenres = newGenres);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'التصنيفات (اختياري)', prefixIcon: Icon(Icons.category_outlined), suffixIcon: Icon(Icons.arrow_drop_down)),
                          child: Text(
                            selectedGenres.isEmpty ? 'لم يتم اختيار تصنيف' : selectedGenres.join('، '),
                            style: TextStyle(color: selectedGenres.isEmpty ? Colors.white38 : Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: characterController, decoration: const InputDecoration(labelText: 'الشخصية المفضلة (اختياري)', prefixIcon: Icon(Icons.person_outline))),
                      const SizedBox(height: 12),
                      TextField(controller: episodesController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد الحلقات (اختياري)', prefixIcon: Icon(Icons.play_circle_outline))),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: status,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'حالة المشاهدة (اختياري)'),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('لم أحدد')),
                          DropdownMenuItem(value: 'مكتمل', child: Text('مكتمل')),
                          DropdownMenuItem(value: 'أتابعه', child: Text('أتابعه')),
                          DropdownMenuItem(value: 'مخطط له', child: Text('مخطط له')),
                          DropdownMenuItem(value: 'متوقف', child: Text('متوقف')),
                        ],
                        onChanged: (value) {
                          if (value != null) setDialogState(() => status = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      const Align(alignment: Alignment.centerRight, child: Text('تقييمك (اختياري - من 10)')),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 0,
                        children: List.generate(10, (index) {
                          final value = index + 1;
                          final isSelected = value <= rating;
                          return GestureDetector(
                            onTap: () => setDialogState(() => rating = rating == value ? 0 : value),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? const Color(0xFFFFC857).withOpacity(0.2) : Colors.transparent,
                                boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFFFC857).withOpacity(0.5), blurRadius: 8, spreadRadius: 1)] : [],
                              ),
                              child: Icon(Icons.star, color: isSelected ? const Color(0xFFFFC857) : Colors.white24, size: 24),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: summaryController, maxLines: 3, decoration: const InputDecoration(labelText: 'ملخص القصة (اختياري)', alignLabelWithHint: true, prefixIcon: Icon(Icons.menu_book_outlined))),
                      const SizedBox(height: 12),
                      TextField(controller: memoryController, maxLines: 3, decoration: const InputDecoration(labelText: 'ذكرياتك مع الأنمي (اختياري)', alignLabelWithHint: true, prefixIcon: Icon(Icons.auto_awesome_outlined))),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: primaryColorNotifier.value),
                  onPressed: () {
                    final anime = Anime(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      title: titleController.text.trim(),
                      genre: selectedGenres.join('، '),
                      character: characterController.text.trim(),
                      summary: summaryController.text.trim(),
                      memory: memoryController.text.trim(),
                      episodes: int.tryParse(episodesController.text) ?? 0,
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
    characterController.dispose();
    summaryController.dispose();
    memoryController.dispose();

    if (result == null) return;

    try {
      if (selectedImage != null) result.imagePath = await _saveImageLocally(selectedImage!.path);
      animes.add(result);
      final saved = await storage.saveAnimes(animes);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved ? 'تم حفظ الأنمي في مكتبتك' : 'تعذر حفظ البيانات.')));
      
      if (result.genre.isEmpty || result.summary.isEmpty) {
        _autoFetchMissingData();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ الصورة أو البيانات.')));
    }
  }

  Widget _animeImage(Anime anime, Color color) {
    final path = anime.imagePath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Image.file(File(path), width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imagePlaceholder(color)),
      );
    }
    return _imagePlaceholder(color);
  }

  Widget _imagePlaceholder(Color color) {
    return Container(
      width: 50, height: 50,
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(13)),
      child: Icon(Icons.movie_outlined, color: color),
    );
  }

  Widget _oracleButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [primaryColorNotifier.value, primaryColorNotifier.value.withOpacity(0.5), const Color(0xFF202431)],
          begin: Alignment.topRight, end: Alignment.bottomLeft,
        ),
        border: Border.all(color: primaryColorNotifier.value.withOpacity(0.6), width: 1.5),
        boxShadow: [BoxShadow(color: primaryColorNotifier.value.withOpacity(0.5), blurRadius: 25, spreadRadius: 5)],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OtakuOracleScreen())),
          child: const Padding(
            padding: EdgeInsets.all(17),
            child: Row(
              children: [
                CircleAvatar(radius: 25, backgroundColor: Colors.white24, child: Icon(Icons.psychology_alt, color: Colors.white, size: 29)),
                SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مرآة الأوتاكو', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      SizedBox(height: 5),
                      Text('اكتشف ملامح ذوقك في عالم الأنمي', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = primaryColorNotifier.value;

    return RefreshIndicator(
      onRefresh: () async {
        await loadData();
        await _autoFetchMissingData();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.5), blurRadius: 12, spreadRadius: 2)],
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 29),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ذاكرة الأوتاكو', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text('سجّل رحلتك. احفظ ذكرياتك.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                onPressed: addAnime,
                tooltip: 'إضافة أنمي',
                style: IconButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, elevation: 8, shadowColor: primaryColor.withOpacity(0.7)),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _oracleButton(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.3), const Color(0xFF202431)],
                begin: Alignment.topRight, end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: primaryColor.withOpacity(0.4), width: 1.5),
              boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 3)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('سجلّك الخاص', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                const Text('كل أنمي يترك أثرًا.', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('لديك ${animes.length} أنمي في مجموعتك.', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: addAnime,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 10,
                      shadowColor: primaryColor.withOpacity(0.8),
                      side: BorderSide(color: primaryColor.withOpacity(0.8), width: 1.5),
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('أضف أنمي إلى مكتبتك', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text('إحصائياتك', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 13),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 11, crossAxisSpacing: 11, childAspectRatio: 1.65,
            children: [
              _statCard('إجمالي الأنميات', '${animes.length}', Icons.movie_creation_outlined, primaryColor),
              _statCard('أنميات مكتملة', '$completed', Icons.verified_outlined, const Color(0xFF27866F)),
              _statCard('أتابعها الآن', '$watching', Icons.play_circle_outline, const Color(0xFF247BA0)),
              _statCard('مخطط لها', '$planned', Icons.bookmark_outline, const Color(0xFF8B65C6)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1F28),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFFFC857).withOpacity(0.3), width: 1),
              boxShadow: [BoxShadow(color: const Color(0xFFFFC857).withOpacity(0.2), blurRadius: 15, spreadRadius: 2)],
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFFC857), size: 32),
                const SizedBox(width: 12),
                const Expanded(child: Text('متوسط تقييماتك', style: TextStyle(fontWeight: FontWeight.bold))),
                Text('${averageRating.toStringAsFixed(1)} / 10', style: const TextStyle(color: Color(0xFFFFC857), fontSize: 19, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 27),
          Row(
            children: [
              const Expanded(child: Text('أضيفت مؤخرًا', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              Text('${animes.length} أنمي', style: const TextStyle(color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 13),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(25), child: CircularProgressIndicator()))
          else if (animes.isEmpty)
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(color: const Color(0xFF1B1F28), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
              child: const Column(
                children: [
                  Icon(Icons.video_library_outlined, size: 43, color: Colors.white38),
                  SizedBox(height: 12),
                  Text('مكتبتك تبدأ من هنا', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('أضف أول أنمي وابدأ بتسجيل رحلتك.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          else
            ...animes.reversed.take(5).map((anime) {
              final color = colors[anime.colorIndex.abs() % colors.length];
              final details = [if (anime.status.isNotEmpty) anime.status, if (anime.episodes > 0) '${anime.episodes} حلقة'].join(' • ');
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1F28),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: color.withOpacity(0.4), width: 1),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 15, spreadRadius: 2)],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  leading: _animeImage(anime, color),
                  title: Text(anime.title.trim().isEmpty ? 'أنمي بدون اسم' : anime.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(details.isEmpty ? 'لم تُضف معلومات بعد' : details, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: anime.rating > 0
                      ? Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFC857)), Text('${anime.rating}/10')])
                      : const Icon(Icons.chevron_left, color: Colors.white38),
                ),
              );
            }),
          if (isAutoFetching) ...[
            const SizedBox(height: 10),
            const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('جارٍ جلب البيانات الناقصة في الخلفية...', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F28),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 15, spreadRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Row(
            children: [
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11))),
              Text(value, style: TextStyle(color: color, fontSize: 23, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}
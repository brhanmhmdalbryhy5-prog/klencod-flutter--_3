
import 'package:flutter/material.dart';

import '../models/anime.dart';
import '../services/storage_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final StorageService storage = StorageService();
  final TextEditingController searchController = TextEditingController();

  List<Anime> animes = [];
  String selectedStatus = 'الكل';
  String searchText = '';
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
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadAnimes() async {
    final data = await storage.loadAnimes();

    if (!mounted) return;

    setState(() {
      animes = data;
      loading = false;
    });
  }

  List<Anime> get filteredAnimes {
    return animes.where((anime) {
      final matchesSearch =
          anime.title.toLowerCase().contains(searchText.toLowerCase()) ||
          anime.genre.toLowerCase().contains(searchText.toLowerCase());

      final matchesStatus = selectedStatus == 'الكل' ||
          (selectedStatus == 'المفضلة'
              ? anime.favorite
              : anime.status == selectedStatus);

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Future<void> deleteAnime(Anime anime) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('حذف الأنمي؟'),
        content: Text('هل تريد حذف "${anime.title}" من مكتبتك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF741C2B),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    animes.removeWhere((item) => item.id == anime.id);
    await storage.saveAnimes(animes);

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف الأنمي')),
    );
  }

  Future<void> toggleFavorite(Anime anime) async {
    setState(() {
      anime.favorite = !anime.favorite;
    });

    await storage.saveAnimes(animes);
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
                      color: selected
                          ? const Color(0xFF741C2B)
                          : Colors.white12,
                    ),
                    onSelected: (_) {
                      setState(() => selectedStatus = status);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 22),
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
                  const Icon(
                    Icons.video_library_outlined,
                    size: 50,
                    color: Colors.white38,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    animes.isEmpty
                        ? 'مكتبتك فارغة'
                        : 'لا توجد نتائج مطابقة',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
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
          else
            ...items.map((anime) {
              final color =
                  colors[anime.colorIndex.abs() % colors.length];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1F28),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    children: [
                      Container(
                        width: 62,
                        height: 82,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.movie_creation_outlined,
                          color: color,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anime.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              anime.genre.isEmpty
                                  ? 'بدون تصنيف'
                                  : anime.genre,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${anime.status} • ${anime.episodes} حلقة',
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (anime.rating > 0) ...[
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Color(0xFFFFC857),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('${anime.rating}/5'),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            tooltip: 'المفضلة',
                            onPressed: () => toggleFavorite(anime),
                            icon: Icon(
                              anime.favorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: anime.favorite
                                  ? const Color(0xFFFF5364)
                                  : Colors.white54,
                            ),
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            onPressed: () => deleteAnime(anime),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xFFFF6B72),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

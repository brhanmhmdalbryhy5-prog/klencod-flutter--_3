
import 'package:flutter/material.dart';

import '../models/anime.dart';
import '../services/storage_service.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  final StorageService storage = StorageService();

  List<Anime> animes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadMemories();
  }

  Future<void> loadMemories() async {
    final data = await storage.loadAnimes();

    if (!mounted) return;

    setState(() {
      animes = data;
      loading = false;
    });
  }

  List<Anime> get memoryAnimes {
    return animes.where((anime) {
      return anime.memory.trim().isNotEmpty ||
          anime.character.trim().isNotEmpty ||
          anime.summary.trim().isNotEmpty;
    }).toList();
  }

  Future<void> editMemory(Anime anime) async {
    final characterController =
        TextEditingController(text: anime.character);
    final summaryController =
        TextEditingController(text: anime.summary);
    final memoryController =
        TextEditingController(text: anime.memory);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: Text(
          anime.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: characterController,
                decoration: const InputDecoration(
                  labelText: 'أفضل شخصية',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: summaryController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ملخص القصة',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: memoryController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'ذكرى أو مشهد لا يُنسى',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.auto_awesome),
                ),
              ),
            ],
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
            child: const Text('حفظ الذكريات'),
          ),
        ],
      ),
    );

    if (saved == true) {
      anime.character = characterController.text.trim();
      anime.summary = summaryController.text.trim();
      anime.memory = memoryController.text.trim();

      await storage.saveAnimes(animes);

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ ذكرياتك بنجاح')),
        );
      }
    }

    characterController.dispose();
    summaryController.dispose();
    memoryController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = memoryAnimes;

    return RefreshIndicator(
      onRefresh: loadMemories,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'ذكرياتي',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'الشخصيات والمشاهد التي بقيت في ذاكرتك.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF3D285E),
                  Color(0xFF202431),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 38,
                  color: Color(0xFFC7A6FF),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'أرشيف الذكريات',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${items.length} أنمي يحتوي على ذكريات مسجلة',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(25),
                child: CircularProgressIndicator(),
              ),
            )
          else if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1F28),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white10),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 50,
                    color: Colors.white38,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'لا توجد ذكريات مسجلة بعد',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'افتح مكتبة الأنمي وأضف أفضل شخصية '
                    'وملخص القصة والمشهد الذي لن تنساه.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            )
          else
            ...items.map((anime) {
              return Container(
                margin: const EdgeInsets.only(bottom: 13),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1F28),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF741C2B)
                                .withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.movie_outlined,
                            color: Color(0xFFE8899A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            anime.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => editMemory(anime),
                          tooltip: 'تعديل الذكريات',
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Color(0xFF65BCE0),
                          ),
                        ),
                      ],
                    ),
                    if (anime.character.isNotEmpty) ...[
                      const SizedBox(height: 13),
                      _memorySection(
                        Icons.person_outline,
                        'أفضل شخصية',
                        anime.character,
                        const Color(0xFFFFC857),
                      ),
                    ],
                    if (anime.summary.isNotEmpty) ...[
                      const SizedBox(height: 13),
                      _memorySection(
                        Icons.menu_book_outlined,
                        'ملخص القصة',
                        anime.summary,
                        const Color(0xFF65BCE0),
                      ),
                    ],
                    if (anime.memory.isNotEmpty) ...[
                      const SizedBox(height: 13),
                      _memorySection(
                        Icons.auto_awesome,
                        'مشهد لا يُنسى',
                        anime.memory,
                        const Color(0xFFC7A6FF),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _memorySection(
    IconData icon,
    String title,
    String content,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(height: 1.6),
          ),
        ],
      ),
    );
  }
}

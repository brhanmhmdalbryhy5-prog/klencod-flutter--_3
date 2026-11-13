import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/anime.dart';
import '../services/storage_service.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final StorageService storage = StorageService();
  List<Anime> trashAnimes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    final data = await storage.loadTrash();
    if (!mounted) return;
    setState(() {
      trashAnimes = data;
      loading = false;
    });
  }

  Future<void> _restore(Anime anime) async {
    final currentAnimes = await storage.loadAnimes();
    final success = await storage.restoreFromTrash(currentAnimes, anime);
    if (success) {
      await _loadTrash();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استعادة الأنمي بنجاح')));
    }
  }

  Future<void> _permanentDelete(Anime anime) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('حذف نهائي؟'),
        content: Text('هل أنت متأكد من حذف "${anime.title}" نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await storage.permanentDelete(anime, isInTrash: true);
      await _loadTrash();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = primaryColorNotifier.value;

    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111318),
        title: const Text('سلة المهملات'),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : trashAnimes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, size: 80, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text('سلة المهملات فارغة', style: TextStyle(fontSize: 18, color: Colors.white54)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: trashAnimes.length,
                  itemBuilder: (context, index) {
                    final anime = trashAnimes[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1F28),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ListTile(
                        leading: anime.imagePath != null && File(anime.imagePath!).existsSync()
                            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(anime.imagePath!), width: 45, height: 45, fit: BoxFit.cover))
                            : Container(width: 45, height: 45, color: Colors.black26, child: const Icon(Icons.movie, color: Colors.white54)),
                        title: Text(
                          anime.title,
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'استعادة',
                              icon: const Icon(Icons.restore, color: Colors.greenAccent),
                              onPressed: () => _restore(anime),
                            ),
                            IconButton(
                              tooltip: 'حذف نهائي',
                              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                              onPressed: () => _permanentDelete(anime),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
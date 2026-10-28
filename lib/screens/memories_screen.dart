
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  static const Color background = Color(0xFF101114);
  static const Color panel = Color(0xFF1B1D22);
  static const Color darkRed = Color(0xFF741C2B);

  final ImagePicker picker = ImagePicker();

  List<File> memories = [];
  bool loading = true;
  bool adding = false;

  @override
  void initState() {
    super.initState();
    loadMemories();
  }

  Future<Directory> getMemoriesDirectory() async {
    final appDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${appDirectory.path}/anime_memory_photos',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<void> loadMemories() async {
    try {
      final directory = await getMemoriesDirectory();
      final files = directory
          .listSync()
          .whereType<File>()
          .where((file) {
        final path = file.path.toLowerCase();
        return path.endsWith('.jpg') ||
            path.endsWith('.jpeg') ||
            path.endsWith('.png') ||
            path.endsWith('.webp') ||
            path.endsWith('.heic');
      }).toList();

      files.sort((a, b) {
        return b.lastModifiedSync().compareTo(
          a.lastModifiedSync(),
        );
      });

      if (!mounted) return;

      setState(() {
        memories = files;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      showMessage('تعذر تحميل الصور: $e');
    }
  }

  Future<void> addMemory() async {
    if (adding) return;

    setState(() => adding = true);

    try {
      final selectedImages = await picker.pickMultiImage(
        imageQuality: 95,
      );

      if (selectedImages.isEmpty) return;

      final directory = await getMemoriesDirectory();

      for (final image in selectedImages) {
        final extension = image.path.contains('.')
            ? image.path.split('.').last.toLowerCase()
            : 'jpg';

        final safeExtension = <String>[
          'jpg',
          'jpeg',
          'png',
          'webp',
          'heic',
        ].contains(extension)
            ? extension
            : 'jpg';

        final filename =
            'memory_${DateTime.now().microsecondsSinceEpoch}_'
            '${memories.length}_${selectedImages.indexOf(image)}.'
            '$safeExtension';

        await File(image.path).copy(
          '${directory.path}/$filename',
        );
      }

      await loadMemories();

      if (mounted) {
        showMessage('تمت إضافة الصور إلى ذكرياتي');
      }
    } catch (e) {
      if (mounted) {
        showMessage('تعذرت إضافة الصور: $e');
      }
    } finally {
      if (mounted) {
        setState(() => adding = false);
      }
    }
  }

  Future<void> deleteMemory(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title: const Text('حذف الصورة؟'),
        content: const Text(
          'سيتم حذف هذه الصورة من معرض ذكرياتي.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: darkRed,
            ),
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (await file.exists()) {
        await file.delete();
      }

      await loadMemories();

      if (mounted) {
        showMessage('تم حذف الصورة');
      }
    } catch (e) {
      if (mounted) {
        showMessage('تعذر حذف الصورة: $e');
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void openMemory(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemoryPhotoViewer(
          file: file,
          onDelete: () => deleteMemory(file),
        ),
      ),
    ).then((_) => loadMemories());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadMemories,
          color: const Color(0xFFE8899A),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20, 22, 20, 18,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ذكرياتي',
                        style: TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'احتفظ بالمشاهد التي لن تنساها.',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF51202D),
                              Color(0xFF24212A),
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.photo_library_rounded,
                              size: 40,
                              color: Color(0xFFFFC1CB),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'أرشيف لحظاتك',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight:
                                          FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${memories.length} صورة محفوظة',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: adding ? null : addMemory,
                          style: FilledButton.styleFrom(
                            backgroundColor: darkRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(15),
                            ),
                          ),
                          icon: adding
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.add_photo_alternate,
                                ),
                          label: Text(
                            adding
                                ? 'جارٍ إضافة الصور...'
                                : 'إضافة صور من المعرض',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (memories.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.collections_outlined,
                            size: 76,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'معرضك ما زال فارغًا',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'أضف صور مشاهد الأنمي المفضلة '
                            'لديك لتجدها هنا دائمًا.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white54,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    16, 0, 16, 24,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final file = memories[index];

                        return Material(
                          color: panel,
                          borderRadius:
                              BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => openMemory(file),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  file,
                                  fit: BoxFit.cover,
                                  errorBuilder: (
                                    context,
                                    error,
                                    stackTrace,
                                  ) {
                                    return const Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 42,
                                        color: Colors.white38,
                                      ),
                                    );
                                  },
                                ),
                                Positioned(
                                  top: 7,
                                  right: 7,
                                  child: Material(
                                    color: Colors.black54,
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      tooltip: 'حذف الصورة',
                                      visualDensity:
                                          VisualDensity.compact,
                                      onPressed: () =>
                                          deleteMemory(file),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 35,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black87,
                                        ],
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.zoom_in,
                                      color: Colors.white,
                                      size: 21,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: memories.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MemoryPhotoViewer extends StatelessWidget {
  final File file;
  final Future<void> Function() onDelete;

  const MemoryPhotoViewer({
    super.key,
    required this.file,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('مشهد من ذكرياتي'),
        actions: [
          IconButton(
            tooltip: 'حذف الصورة',
            onPressed: () async {
              await onDelete();

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.7,
          maxScale: 5,
          child: Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Text(
                'تعذر عرض الصورة',
                style: TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}

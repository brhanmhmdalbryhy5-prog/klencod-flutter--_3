
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_events.dart';
import '../main.dart';
import 'anime_news_screen.dart';

// ══════════════════════════════════════════════════════════════
// Memory Metadata
// ══════════════════════════════════════════════════════════════
class MemoryMeta {
  final String caption;
  final bool favorite;
  final String category;

  const MemoryMeta({
    this.caption = '',
    this.favorite = false,
    this.category = 'عام',
  });

  Map<String, dynamic> toJson() => {
        'caption': caption,
        'favorite': favorite,
        'category': category,
      };

  factory MemoryMeta.fromJson(Map<String, dynamic> json) => MemoryMeta(
        caption: json['caption'] as String? ?? '',
        favorite: json['favorite'] as bool? ?? false,
        category: json['category'] as String? ?? 'عام',
      );

  MemoryMeta copyWith({String? caption, bool? favorite, String? category}) =>
      MemoryMeta(
        caption: caption ?? this.caption,
        favorite: favorite ?? this.favorite,
        category: category ?? this.category,
      );
}

// ══════════════════════════════════════════════════════════════
// Main Screen
// ══════════════════════════════════════════════════════════════
class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  static const Color background = Color(0xFF111318);
  static const Color panel = Color(0xFF1B1F28);
  static const String _metaKey = 'memory_metadata';

  static const List<String> _categories = [
    'عام',
    'أنمي',
    'شخصيات',
    'مشاهد',
    'لحظات شخصية',
  ];

  final ImagePicker picker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();

  List<File> allMemories = [];
  Map<String, MemoryMeta> metadata = {};

  String _searchQuery = '';
  String _selectedCategory = 'الكل';
  String _sortMode = 'newest';
  int _gridColumns = 2;
  bool _showOnlyFavorites = false;
  bool loading = true;
  bool adding = false;

  bool _selectionMode = false;
  final Set<String> _selectedFiles = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadMetadata(), _loadMemories()]);
  }

  Future<void> _loadMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_metaKey);
      if (raw == null || raw.isEmpty) {
        metadata = {};
        return;
      }
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      metadata = decoded.map((k, v) => MapEntry(
            k,
            MemoryMeta.fromJson(Map<String, dynamic>.from(v as Map)),
          ));
    } catch (_) {
      metadata = {};
    }
  }

  Future<void> _saveMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(
          metadata.map((k, v) => MapEntry(k, v.toJson())));
      await prefs.setString(_metaKey, json);
    } catch (_) {}
  }

  Future<Directory> _getMemoriesDirectory() async {
    final appDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory('${appDirectory.path}/anime_memory_photos');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<void> _loadMemories() async {
    try {
      final directory = await _getMemoriesDirectory();
      final files = directory.listSync().whereType<File>().where((file) {
        final path = file.path.toLowerCase();
        return path.endsWith('.jpg') ||
            path.endsWith('.jpeg') ||
            path.endsWith('.png') ||
            path.endsWith('.webp') ||
            path.endsWith('.heic');
      }).toList();

      files.sort((a, b) =>
          b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (!mounted) return;
      setState(() {
        allMemories = files;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _showMessage('تعذر تحميل الصور: $e');
    }
  }

  String _fileName(File f) => f.path.split('/').last;

  MemoryMeta _metaFor(File f) =>
      metadata[_fileName(f)] ?? const MemoryMeta();

  List<File> get _filteredMemories {
    var list = allMemories.where((f) {
      final meta = _metaFor(f);

      if (_showOnlyFavorites && !meta.favorite) return false;
      if (_selectedCategory != 'الكل' &&
          meta.category != _selectedCategory) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = _fileName(f).toLowerCase();
        if (!name.contains(q) &&
            !meta.caption.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (_sortMode) {
      case 'oldest':
        list.sort((a, b) =>
            a.lastModifiedSync().compareTo(b.lastModifiedSync()));
        break;
      case 'name':
        list.sort((a, b) => _fileName(a).compareTo(_fileName(b)));
        break;
      case 'size':
        list.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
        break;
      case 'newest':
      default:
        list.sort((a, b) =>
            b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    }
    return list;
  }

  int get _favoritesCount =>
      allMemories.where((f) => _metaFor(f).favorite).length;

  int get _totalSize {
    int total = 0;
    for (final f in allMemories) {
      try {
        total += f.lengthSync();
      } catch (_) {}
    }
    return total;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  Future<void> _addMemories() async {
    if (adding) return;

    String? chosenCategory = await _pickCategoryForUpload();
    if (chosenCategory == null) return;

    setState(() => adding = true);

    try {
      final selectedImages = await picker.pickMultiImage(imageQuality: 95);
      if (selectedImages.isEmpty) return;

      final directory = await _getMemoriesDirectory();

      for (final image in selectedImages) {
        final extension = image.path.contains('.')
            ? image.path.split('.').last.toLowerCase()
            : 'jpg';
        final safeExt =
            <String>['jpg', 'jpeg', 'png', 'webp', 'heic']
                    .contains(extension)
                ? extension
                : 'jpg';
        final filename =
            'memory_${DateTime.now().microsecondsSinceEpoch}_'
            '${allMemories.length}_${selectedImages.indexOf(image)}.'
            '$safeExt';

        await File(image.path).copy('${directory.path}/$filename');

        metadata[filename] = MemoryMeta(category: chosenCategory);
      }

      await _saveMetadata();
      await _loadMemories();

      AppEvents.fire('anime_edited');
      if (mounted) {
        _showMessage(
            'تمت إضافة ${selectedImages.length} صورة إلى ذكرياتك');
      }
    } catch (e) {
      if (mounted) _showMessage('تعذرت إضافة الصور: $e');
    } finally {
      if (mounted) setState(() => adding = false);
    }
  }

  Future<String?> _pickCategoryForUpload() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: panel,
        title: const Text('اختر تصنيف الصور'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories
              .map((c) => ChoiceChip(
                    label: Text(c),
                    selected: false,
                    selectedColor: primaryColorNotifier.value,
                    backgroundColor: const Color(0xFF111318),
                    side: const BorderSide(color: Colors.white24),
                    labelStyle: const TextStyle(fontSize: 12),
                    onSelected: (_) => Navigator.pop(ctx, c),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: primaryColorNotifier.value),
            onPressed: () => Navigator.pop(ctx, 'عام'),
            child: const Text('بدون تصنيف'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMemory(File file) async {
    if (_selectionMode) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: panel,
        title: const Text('حذف الصورة؟'),
        content: const Text('سيتم حذف هذه الصورة من معرض ذكرياتي.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: primaryColorNotifier.value),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      if (await file.exists()) await file.delete();
      metadata.remove(_fileName(file));
      await _saveMetadata();
      await _loadMemories();
      if (mounted) _showMessage('تم حذف الصورة');
    } catch (e) {
      if (mounted) _showMessage('تعذر حذف الصورة: $e');
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedFiles.isEmpty) return;
    final count = _selectedFiles.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: panel,
        title: Text('حذف $count صورة؟'),
        content: const Text('سيتم حذف جميع الصور المحددة نهائياً.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: primaryColorNotifier.value),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      for (final file in allMemories) {
        if (_selectedFiles.contains(_fileName(file))) {
          try {
            if (await file.exists()) await file.delete();
            metadata.remove(_fileName(file));
          } catch (_) {}
        }
      }
      await _saveMetadata();
      if (mounted) {
        setState(() {
          _selectionMode = false;
          _selectedFiles.clear();
        });
        _showMessage('تم حذف $count صورة');
      }
      await _loadMemories();
    } catch (e) {
      if (mounted) _showMessage('خطأ: $e');
    }
  }

  // إصلاح: إرجاع Future<void> بدلاً من void
  Future<void> _toggleFavorite(File file) async {
    final name = _fileName(file);
    final meta = metadata[name] ?? const MemoryMeta();
    metadata[name] = meta.copyWith(favorite: !meta.favorite);
    await _saveMetadata();
    if (mounted) setState(() {});
  }

  // إصلاح: إرجاع Future<void> بدلاً من void
  Future<void> _editCaption(File file) async {
    final name = _fileName(file);
    final meta = metadata[name] ?? const MemoryMeta();
    final controller = TextEditingController(text: meta.caption);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: panel,
        title: const Text('تعديل الوصف'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: 'اكتب وصفاً أو ذكرى لهذه الصورة...',
            labelText: 'الوصف',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          if (meta.caption.isNotEmpty)
            TextButton(
                onPressed: () => Navigator.pop(ctx, ''),
                child: const Text('مسح',
                    style: TextStyle(color: Colors.redAccent))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: primaryColorNotifier.value),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null) return;

    metadata[name] = meta.copyWith(caption: result);
    await _saveMetadata();
    if (mounted) setState(() {});
  }

  // إصلاح: إرجاع Future<void> بدلاً من void
  Future<void> _changeCategory(File file) async {
    final name = _fileName(file);
    final meta = metadata[name] ?? const MemoryMeta();

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: panel,
        title: const Text('تغيير التصنيف'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories
              .map((c) => ChoiceChip(
                    label: Text(c),
                    selected: c == meta.category,
                    selectedColor: primaryColorNotifier.value,
                    backgroundColor: const Color(0xFF111318),
                    side: BorderSide(
                        color: c == meta.category
                            ? primaryColorNotifier.value
                            : Colors.white24),
                    labelStyle: const TextStyle(fontSize: 12),
                    onSelected: (_) => Navigator.pop(ctx, c),
                  ))
              .toList(),
        ),
      ),
    );

    if (picked == null) return;
    metadata[name] = meta.copyWith(category: picked);
    await _saveMetadata();
    if (mounted) setState(() {});
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _openViewer(int index, List<File> filtered) {
    if (_selectionMode) {
      _toggleSelection(filtered[index]);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MemoryViewerPage(
          files: filtered,
          initialIndex: index,
          metadata: metadata,
          onFavoriteToggle: _toggleFavorite,
          onDelete: (f) async {
            await _deleteMemory(f);
            return true;
          },
          onEditCaption: _editCaption,
          onChangeCategory: _changeCategory,
        ),
      ),
    ).then((_) => _loadMemories());
  }

  void _toggleSelection(File f) {
    final name = _fileName(f);
    setState(() {
      if (_selectedFiles.contains(name)) {
        _selectedFiles.remove(name);
        if (_selectedFiles.isEmpty) _selectionMode = false;
      } else {
        _selectedFiles.add(name);
      }
    });
  }

  void _enterSelectionMode(File f) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      _selectedFiles.add(_fileName(f));
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedFiles.clear();
    });
  }

  void _selectAll() {
    setState(() {
      _selectionMode = true;
      for (final f in _filteredMemories) {
        _selectedFiles.add(_fileName(f));
      }
    });
  }

  Future<void> _showSortMenu() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('ترتيب حسب',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            _sortItem('newest', 'الأحدث أولاً', Icons.schedule),
            _sortItem('oldest', 'الأقدم أولاً', Icons.history),
            _sortItem('name', 'الاسم', Icons.sort_by_alpha),
            _sortItem('size', 'الحجم', Icons.storage),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _sortMode = picked);
  }

  Widget _sortItem(String value, String label, IconData icon) {
    final selected = _sortMode == value;
    return ListTile(
      leading: Icon(icon,
          color: selected
              ? primaryColorNotifier.value
              : Colors.white70),
      title: Text(label,
          style: TextStyle(
              color: selected
                  ? primaryColorNotifier.value
                  : Colors.white,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal)),
      trailing: selected
          ? Icon(Icons.check,
              color: primaryColorNotifier.value, size: 20)
          : null,
      onTap: () => Navigator.pop(context, value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = primaryColorNotifier.value;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        title: Text(
          _selectionMode
              ? '${_selectedFiles.length} محدد'
              : 'ذكرياتي',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: _selectionMode
            ? [
                IconButton(
                  tooltip: 'تحديد الكل',
                  icon: const Icon(Icons.select_all),
                  onPressed: _selectAll,
                ),
                IconButton(
                  tooltip: 'حذف المحدد',
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: _deleteSelected,
                ),
              ]
            : [
                IconButton(
                  tooltip: 'أخبار الأنمي',
                  icon: const Icon(Icons.newspaper, color: Colors.cyan),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AnimeNewsScreen()),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'ترتيب',
                  icon: const Icon(Icons.sort),
                  onPressed: _showSortMenu,
                ),
              ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: adding ? null : _addMemories,
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              icon: adding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_photo_alternate),
              label: Text(adding ? 'جارٍ الإضافة...' : 'إضافة صور'),
            ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          color: primaryColor,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(primaryColor)),
              SliverToBoxAdapter(child: _buildFilters(primaryColor)),
              if (loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_filteredMemories.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(primaryColor),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  sliver: SliverGrid(
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridColumns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: _gridColumns == 2 ? 0.82 : 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final f = _filteredMemories[index];
                        return _buildMemoryCard(
                            f, index, _filteredMemories, primaryColor);
                      },
                      childCount: _filteredMemories.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ذكرياتي',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('احتفظ بالمشاهد التي لن تنساها.',
              style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.7),
                  primaryColor.withOpacity(0.2),
                  const Color(0xFF24212A),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2)
              ],
            ),
            child: Row(children: [
              Icon(Icons.photo_library_rounded,
                  size: 40, color: Colors.white.withOpacity(0.9)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('أرشيف لحظاتك',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Wrap(spacing: 12, children: [
                      _statBadge(
                          Icons.image, '${allMemories.length} صورة'),
                      _statBadge(
                          Icons.star, '$_favoritesCount مفضلة'),
                      _statBadge(Icons.storage, _formatSize(_totalSize)),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _statBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white70),
        const SizedBox(width: 3),
        Text(text,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildFilters(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            decoration: InputDecoration(
              hintText: 'ابحث في الذكريات...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      })
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              filled: true,
              fillColor: panel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _filterChip(
                          'الكل',
                          _selectedCategory == 'الكل' && !_showOnlyFavorites,
                          primaryColor, () {
                        setState(() {
                          _selectedCategory = 'الكل';
                          _showOnlyFavorites = false;
                        });
                      }),
                      _filterChip('⭐ المفضلة', _showOnlyFavorites,
                          primaryColor, () {
                        setState(() => _showOnlyFavorites =
                            !_showOnlyFavorites);
                      }),
                      ..._categories.map((c) => _filterChip(
                          c, _selectedCategory == c, primaryColor, () {
                        setState(() {
                          _selectedCategory =
                              _selectedCategory == c ? 'الكل' : c;
                          _showOnlyFavorites = false;
                        });
                      })),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip:
                    'شبكة ${_gridColumns == 2 ? "3" : "2"} أعمدة',
                icon: Icon(
                  _gridColumns == 2 ? Icons.apps : Icons.grid_view,
                  color: Colors.white70,
                ),
                onPressed: () => setState(() =>
                    _gridColumns = _gridColumns == 2 ? 3 : 2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
      String label, bool selected, Color primaryColor, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        selectedColor: primaryColor,
        backgroundColor: panel,
        side: BorderSide(
            color: selected ? primaryColor : Colors.white12),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildMemoryCard(
      File file, int index, List<File> filtered, Color primaryColor) {
    final meta = _metaFor(file);
    final name = _fileName(file);
    final isSelected = _selectedFiles.contains(name);

    return Material(
      color: panel,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openViewer(index, filtered),
        onLongPress: () => _enterSelectionMode(file),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined,
                    size: 40, color: Colors.white38),
              ),
            ),
            if (isSelected)
              Container(
                color: primaryColor.withOpacity(0.4),
                child: Center(
                  child: Icon(Icons.check_circle,
                      color: primaryColor, size: 42),
                ),
              ),
            if (!_selectionMode)
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _deleteMemory(file),
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              top: 6,
              left: 6,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _toggleFavorite(file),
                  icon: Icon(
                    meta.favorite ? Icons.star : Icons.star_border,
                    color: meta.favorite
                        ? const Color(0xFFFFC857)
                        : Colors.white70,
                  ),
                ),
              ),
            ),
            if (meta.caption.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: Text(
                    meta.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            if (meta.category != 'عام')
              Positioned(
                left: 8,
                bottom: meta.caption.isNotEmpty ? 34 : 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    meta.category,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 9),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor) {
    final isFiltering = _searchQuery.isNotEmpty ||
        _selectedCategory != 'الكل' ||
        _showOnlyFavorites;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryColor.withOpacity(0.3),
                    primaryColor.withOpacity(0.05),
                  ],
                ),
              ),
              child: Icon(Icons.collections_outlined,
                  size: 60, color: primaryColor),
            ),
            const SizedBox(height: 20),
            Text(
              isFiltering ? 'لا توجد صور مطابقة' : 'معرضك ما زال فارغاً',
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltering
                  ? 'جرّب تغيير البحث أو التصنيف'
                  : 'أضف صور مشاهد الأنمي المفضلة لديك\nلتجدها هنا دائمًا.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white54, height: 1.6, fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (!isFiltering)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                onPressed: adding ? null : _addMemories,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('أضف أول صورة'),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Enhanced Viewer Page
// ══════════════════════════════════════════════════════════════
class _MemoryViewerPage extends StatefulWidget {
  final List<File> files;
  final int initialIndex;
  final Map<String, MemoryMeta> metadata;
  final Future<void> Function(File) onFavoriteToggle;
  final Future<bool> Function(File) onDelete;
  final Future<void> Function(File) onEditCaption;
  final Future<void> Function(File) onChangeCategory;

  const _MemoryViewerPage({
    required this.files,
    required this.initialIndex,
    required this.metadata,
    required this.onFavoriteToggle,
    required this.onDelete,
    required this.onEditCaption,
    required this.onChangeCategory,
  });

  @override
  State<_MemoryViewerPage> createState() => _MemoryViewerPageState();
}

class _MemoryViewerPageState extends State<_MemoryViewerPage> {
  // إصلاح: تعريف لون لوحة عارض الصور
  static const Color panel = Color(0xFF1B1F28);

  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  MemoryMeta _metaFor(File f) {
    final name = f.path.split('/').last;
    return widget.metadata[name] ?? const MemoryMeta();
  }

  Future<void> _shareCurrent() async {
    if (widget.files.isEmpty) return;
    try {
      final f = widget.files[_currentIndex];
      await Share.shareXFiles([XFile(f.path)],
          text: 'ذكرى من ذاكرة الأوتاكو 🎌');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = primaryColorNotifier.value;

    if (widget.files.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child:
                Text('لا توجد صور', style: TextStyle(color: Colors.white))),
      );
    }

    final currentFile = widget.files[_currentIndex];
    final meta = _metaFor(currentFile);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.files.length}'),
        actions: [
          IconButton(
            tooltip: meta.favorite
                ? 'إزالة من المفضلة'
                : 'إضافة إلى المفضلة',
            icon: Icon(
              meta.favorite ? Icons.star : Icons.star_border,
              color: meta.favorite
                  ? const Color(0xFFFFC857)
                  : Colors.white,
            ),
            onPressed: () async {
              await widget.onFavoriteToggle(currentFile);
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            tooltip: 'مشاركة',
            icon: const Icon(Icons.share),
            onPressed: _shareCurrent,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'caption':
                  await widget.onEditCaption(currentFile);
                  if (mounted) setState(() {});
                  break;
                case 'category':
                  await widget.onChangeCategory(currentFile);
                  if (mounted) setState(() {});
                  break;
                case 'delete':
                  final ok = await widget.onDelete(currentFile);
                  if (ok && mounted) Navigator.pop(context);
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'caption',
                  child: Row(children: [
                    Icon(Icons.edit_note, color: Colors.cyan),
                    SizedBox(width: 8),
                    Text('تعديل الوصف'),
                  ])),
              const PopupMenuItem(
                  value: 'category',
                  child: Row(children: [
                    Icon(Icons.category, color: Colors.purpleAccent),
                    SizedBox(width: 8),
                    Text('تغيير التصنيف'),
                  ])),
              const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text('حذف الصورة'),
                  ])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemCount: widget.files.length,
              itemBuilder: (context, index) {
                final f = widget.files[index];
                return InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 5,
                  child: Center(
                    child: Image.file(
                      f,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                          size: 60),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            color: panel,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(meta.category,
                          style: TextStyle(
                              color: primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(currentFile.lastModifiedSync()),
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 10),
                    ),
                  ]),
                  if (meta.caption.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(meta.caption,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

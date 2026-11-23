import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_events.dart';
import '../main.dart';
import '../models/anime_news.dart';
import '../services/anime_news_service.dart';

class AnimeNewsScreen extends StatefulWidget {
  const AnimeNewsScreen({super.key});

  @override
  State<AnimeNewsScreen> createState() => _AnimeNewsScreenState();
}

class _AnimeNewsScreenState extends State<AnimeNewsScreen> {
  final AnimeNewsService _service = AnimeNewsService();

  List<AnimeNews> _news = [];
  DateTime? _lastFetch;
  bool _loading = true;
  bool _fetching = false;

  // شريط التقدم
  final ValueNotifier<double> _progress = ValueNotifier(0.0);
  final ValueNotifier<String> _stage = ValueNotifier('جارٍ التحضير...');
  final ValueNotifier<String?> _currentTitle = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _progress.dispose();
    _stage.dispose();
    _currentTitle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await _service.loadNews();
    final lf = await _service.getLastFetch();
    if (!mounted) return;
    setState(() {
      _news = data;
      _lastFetch = lf;
      _loading = false;
    });
  }

  Future<void> _fetchNews() async {
    if (_fetching) return;
    setState(() => _fetching = true);
    _progress.value = 0;
    _stage.value = 'جارٍ التحضير...';
    _currentTitle.value = null;

    final dialogShown = _showProgressDialog();

    final result = await _service.fetchUpcoming(
      onProgress: (p, stage, title) {
        _progress.value = p;
        _stage.value = stage;
        _currentTitle.value = title;
      },
    );

    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted && dialogShown) Navigator.pop(context);
    if (mounted) setState(() => _fetching = false);

    if (result.success && result.count > 0) {
      AppEvents.fire('news_fetched');
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم جلب ${result.count} أنمي قادم'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (result.error != null) AppEvents.fire('news_fetch_failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'فشل الجلب'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  bool _showProgressDialog() {
    if (!mounted) return false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1B1F28),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.newspaper, size: 50, color: Colors.cyan),
              const SizedBox(height: 16),
              const Text('جلب الأنميات القادمة',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              ValueListenableBuilder<double>(
                valueListenable: _progress,
                builder: (_, value, __) => Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 10,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            primaryColorNotifier.value),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${(value * 100).toInt()}%',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white54)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: _stage,
                builder: (_, stage, __) => Text(
                  stage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<String?>(
                valueListenable: _currentTitle,
                builder: (_, title, __) {
                  if (title == null || title.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white60),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    return true;
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('مسح الأخبار المحفوظة؟'),
        content: const Text(
            'سيتم حذف كل الأنميات القادمة المحفوظة والصور المحلية.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final count = await _service.clearNews();
    if (!mounted) return;
    await _load();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم مسح $count أنمي من الأخبار')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = primaryColorNotifier.value;

    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text('أخبار الأنمي القادمة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_news.isNotEmpty)
            IconButton(
              tooltip: 'مسح الأخبار',
              icon: const Icon(Icons.delete_sweep),
              onPressed: _confirmClear,
            ),
          IconButton(
            tooltip: 'جلب الأخبار',
            icon: _fetching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh),
            onPressed: _fetching ? null : _fetchNews,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _news.isEmpty
              ? _buildEmptyState(primaryColor)
              : RefreshIndicator(
                  onRefresh: _fetchNews,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _news.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildHeader(primaryColor);
                      }
                      return _buildNewsCard(_news[index - 1], primaryColor);
                    },
                  ),
                ),
    );
  }

  Widget _buildHeader(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.3),
            primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.newspaper, color: primaryColor, size: 22),
            const SizedBox(width: 8),
            const Text('الأنميات القادمة بمواعيد مؤكدة',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text(
            '${_news.length} أنمي قادم',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          if (_lastFetch != null) ...[
            const SizedBox(height: 4),
            Text(
              'آخر تحديث: ${_formatDate(_lastFetch!)}',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.newspaper, size: 80, color: primaryColor),
            const SizedBox(height: 16),
            const Text('لا توجد أخبار محفوظة',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'اضغط لبدء جلب الأنميات القادمة\n(فقط التي لها موعد رسمي مؤكد)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.6),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _fetching ? null : _fetchNews,
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
              ),
              icon: const Icon(Icons.download),
              label: const Text('جلب الأخبار الآن'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsCard(AnimeNews news, Color primaryColor) {
    final hasImage = news.imagePath != null &&
        File(news.imagePath!).existsSync();
    final isSoon = news.isSoon;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSoon
              ? Colors.orangeAccent.withOpacity(0.6)
              : primaryColor.withOpacity(0.3),
          width: isSoon ? 2 : 1,
        ),
        boxShadow: [
          if (isSoon)
            BoxShadow(
              color: Colors.orangeAccent.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 2,
            )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: hasImage
                  ? Image.file(
                      File(news.imagePath!),
                      width: 80,
                      height: 110,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 80,
                      height: 110,
                      color: primaryColor.withOpacity(0.2),
                      child: Icon(Icons.movie, color: primaryColor),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    news.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.calendar_today,
                        size: 13,
                        color: isSoon ? Colors.orangeAccent : Colors.cyan),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(news.releaseDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: isSoon
                            ? Colors.orangeAccent
                            : Colors.cyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSoon
                            ? Colors.orangeAccent.withOpacity(0.2)
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        news.timeRemainingText,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSoon
                              ? Colors.orangeAccent
                              : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  if (news.format.isNotEmpty || news.episodes > 0)
                    Text(
                      '${news.format}${news.episodes > 0 ? " • ${news.episodes} حلقة" : ""}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white54),
                    ),
                  if (news.studios.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '🎬 ${news.studios}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white60),
                    ),
                  ],
                  if (news.genres.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: news.genres
                          .split('،')
                          .take(3)
                          .map((g) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: primaryColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  g.trim(),
                                  style: const TextStyle(
                                      fontSize: 9, color: Colors.white70),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                  if (news.synopsis.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      news.synopsis,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white38,
                          height: 1.4),
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

  String _formatDate(DateTime d) {
    final months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
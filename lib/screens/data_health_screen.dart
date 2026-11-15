import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/data_health_service.dart';

class DataHealthScreen extends StatefulWidget {
  const DataHealthScreen({super.key});

  @override
  State<DataHealthScreen> createState() => _DataHealthScreenState();
}

class _DataHealthScreenState extends State<DataHealthScreen>
    with SingleTickerProviderStateMixin {
  bool _scanning = true;
  bool _fixing = false;
  String _status = 'جاري الفحص...';
  double _progress = 0.0;
  DataHealthReport? _report;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _runScan(autoFix: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runScan({required bool autoFix}) async {
    setState(() {
      _scanning = true;
      _fixing = autoFix;
      _progress = 0.0;
      _status = autoFix ? 'جاري الفحص والإصلاح...' : 'جاري فحص المكتبة...';
    });

    final report = await DataHealthService().scan(
      autoFix: autoFix,
      onProgress: (current, total, title) {
        if (mounted) {
          setState(() {
            _progress = total == 0 ? 0 : current / total;
            _status = '($current/$total) $title';
          });
        }
      },
    );

    if (!mounted) return;
    setState(() {
      _report = report;
      _scanning = false;
      _fixing = false;
    });
    _controller.forward(from: 0);

    if (autoFix && report.fixedCount > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم إصلاح ${report.fixedCount} مشكلة تلقائياً.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF00E676);
    if (score >= 60) return const Color(0xFFFFC857);
    if (score >= 40) return const Color(0xFFFF9800);
    return const Color(0xFFFF5252);
  }

  String _scoreLabel(int score) {
    if (score >= 80) return 'ممتاز';
    if (score >= 60) return 'جيد';
    if (score >= 40) return 'متوسط';
    return 'يحتاج صيانة';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = primaryColorNotifier.value;

    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111318),
        title: const Text('فحص صحة المكتبة'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'إعادة الفحص',
            icon: const Icon(Icons.refresh),
            onPressed: _scanning ? null : () => _runScan(autoFix: false),
          ),
        ],
      ),
      body: _scanning
          ? _buildScanningView(primaryColor)
          : _report == null
              ? const Center(child: Text('لا توجد بيانات'))
              : _buildReportView(primaryColor),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // واجهة الفحص
  // ══════════════════════════════════════════════════════════════
  Widget _buildScanningView(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 12,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                ),
                Column(
                  children: [
                    Icon(_fixing ? Icons.healing : Icons.health_and_safety,
                        size: 60, color: primaryColor),
                    const SizedBox(height: 8),
                    Text('${(_progress * 100).toInt()}%',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryColor)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 30),
            Text(
              _fixing
                  ? 'يقوم التطبيق بحذف المراجع للملفات المفقودة...'
                  : 'يمر التطبيق على كل أنمي للتحقق من الصور والفيديوهات...',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // واجهة التقرير
  // ══════════════════════════════════════════════════════════════
  Widget _buildReportView(Color primaryColor) {
    final report = _report!;
    final scoreColor = _scoreColor(report.healthScore);

    return RefreshIndicator(
      onRefresh: () => _runScan(autoFix: false),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // بطاقة الصحة العامة
          _buildHealthScoreCard(report, scoreColor, primaryColor),
          const SizedBox(height: 16),

          // إحصائيات سريعة
          _buildQuickStats(report, primaryColor),
          const SizedBox(height: 16),

          // رسم بياني: توزيع المساحة
          if (report.totalBytes > 0) ...[
            _buildStorageChart(report, primaryColor),
            const SizedBox(height: 16),
          ],

          // رسم بياني: المشاكل حسب النوع
          if (report.issues.isNotEmpty) ...[
            _buildIssuesChart(report, primaryColor),
            const SizedBox(height: 16),
          ],

          // قائمة المشاكل
          if (report.issues.isNotEmpty)
            _buildIssuesList(report, primaryColor)
          else
            _buildAllGoodCard(),

          const SizedBox(height: 20),

          // أزرار الإجراءات
          _buildActionButtons(report, primaryColor),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // بطاقة الصحة (مع رسم دائري)
  // ══════════════════════════════════════════════════════════════
  Widget _buildHealthScoreCard(
      DataHealthReport report, Color scoreColor, Color primaryColor) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final animatedScore = report.healthScore * _controller.value;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scoreColor.withOpacity(0.3), const Color(0xFF1B1F28)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scoreColor.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(
                  color: scoreColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2)
            ],
          ),
          child: Row(
            children: [
              // دائرة التقييم
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CircularProgressIndicator(
                        value: animatedScore / 100,
                        strokeWidth: 10,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${animatedScore.toInt()}',
                            style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: scoreColor)),
                        Text('/ 100',
                            style: TextStyle(
                                fontSize: 11, color: scoreColor.withOpacity(0.7))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_scoreLabel(report.healthScore),
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: scoreColor)),
                    const SizedBox(height: 6),
                    const Text('صحة مكتبتك',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _miniStat('${report.totalAnimes}', 'أنمي'),
                        const SizedBox(width: 16),
                        _miniStat('${report.issues.length}', 'مشكلة'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // إحصائيات سريعة
  // ══════════════════════════════════════════════════════════════
  Widget _buildQuickStats(DataHealthReport report, Color primaryColor) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: [
        _statBox('الأنميات', '${report.totalAnimes}',
            Icons.movie_creation, Colors.cyan),
        _statBox('الشخصيات', '${report.totalCharacters}',
            Icons.people, Colors.purpleAccent),
        _statBox('المشاهد', '${report.totalScenes}',
            Icons.collections, Colors.teal),
        _statBox('الفيديوهات', '${report.totalVideos}',
            Icons.video_library, Colors.orangeAccent),
        _statBox('المساحة الكلية', report.formatBytes(report.totalBytes),
            Icons.storage, Colors.amber),
        _statBox('ملفات مفقودة', '${report.missingFilesCount}',
            Icons.error_outline,
            report.missingFilesCount > 0 ? Colors.redAccent : Colors.greenAccent),
      ],
    );
  }

  Widget _statBox(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(title,
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // رسم بياني: توزيع المساحة (Pie Chart)
  // ══════════════════════════════════════════════════════════════
  Widget _buildStorageChart(DataHealthReport report, Color primaryColor) {
    final entries = <MapEntry<String, int>>[
      if (report.videoBytes > 0) MapEntry('فيديوهات', report.videoBytes),
      if (report.coverBytes > 0) MapEntry('أغلفة', report.coverBytes),
      if (report.characterBytes > 0)
        MapEntry('شخصيات', report.characterBytes),
      if (report.sceneBytes > 0) MapEntry('مشاهد', report.sceneBytes),
      if (report.memoryBytes > 0) MapEntry('ذكريات', report.memoryBytes),
    ];

    final colors = [
      Colors.orangeAccent,
      primaryColor,
      Colors.purpleAccent,
      Colors.teal,
      Colors.pinkAccent,
    ];

    return _cardWrapper(
      icon: Icons.pie_chart,
      iconColor: primaryColor,
      title: 'توزيع مساحة التخزين',
      child: SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 35,
                  sections: List.generate(entries.length, (i) {
                    final percent =
                        entries[i].value / report.totalBytes * 100;
                    return PieChartSectionData(
                      color: colors[i % colors.length],
                      value: entries[i].value.toDouble(),
                      title: '${percent.toStringAsFixed(0)}%',
                      radius: 55,
                      titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(entries.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: colors[i % colors.length],
                                shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${entries[i].key}: ${report.formatBytes(entries[i].value)}',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white70),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // رسم بياني: المشاكل حسب النوع (Bar Chart)
  // ══════════════════════════════════════════════════════════════
  Widget _buildIssuesChart(DataHealthReport report, Color primaryColor) {
    final byType = report.issuesByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxY = byType.isEmpty ? 5.0 : (byType.first.value + 1).toDouble();

    return _cardWrapper(
      icon: Icons.bar_chart,
      iconColor: Colors.amber,
      title: 'المشاكل حسب النوع',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (value) =>
                  FlLine(color: Colors.white12, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= byType.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        byType[i].value.toString(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(byType.length, (i) {
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: byType[i].value.toDouble(),
                    color: primaryColor,
                    width: 22,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // قائمة المشاكل
  // ══════════════════════════════════════════════════════════════
  Widget _buildIssuesList(DataHealthReport report, Color primaryColor) {
    // تجميع المشاكل حسب النوع
    final grouped = <HealthIssueType, List<HealthIssue>>{};
    for (final issue in report.issues) {
      grouped.putIfAbsent(issue.type, () => []).add(issue);
    }

    return _cardWrapper(
      icon: Icons.list_alt,
      iconColor: Colors.redAccent,
      title: 'تفاصيل المشاكل (${report.issues.length})',
      child: Column(
        children: grouped.entries.map((entry) {
          final type = entry.key;
          final issues = entry.value;
          final color = type.severity == 3
              ? Colors.redAccent
              : type.severity == 2
                  ? Colors.orangeAccent
                  : Colors.amber;

          return Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              iconColor: color,
              collapsedIconColor: color,
              leading: Icon(
                _iconForType(type),
                color: color,
                size: 22,
              ),
              title: Text(type.label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 13)),
              subtitle: Text('${issues.length} حالة',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11)),
              children: issues.map((issue) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber,
                          color: color.withOpacity(0.7), size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (issue.animeTitle.isNotEmpty)
                              Text(issue.animeTitle,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            Text(issue.description,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _iconForType(HealthIssueType type) {
    switch (type) {
      case HealthIssueType.missingCover: return Icons.image_not_supported;
      case HealthIssueType.missingBackCover: return Icons.flip;
      case HealthIssueType.missingVideo: return Icons.videocam_off;
      case HealthIssueType.missingCharacterImage: return Icons.person_off;
      case HealthIssueType.missingSceneImage: return Icons.broken_image;
      case HealthIssueType.emptyTitle: return Icons.title;
      case HealthIssueType.emptyGenre: return Icons.category;
      case HealthIssueType.duplicate: return Icons.content_copy;
    }
  }

  Widget _buildAllGoodCard() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF00E676).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E676), width: 2),
      ),
      child: const Column(
        children: [
          Icon(Icons.check_circle, color: Color(0xFF00E676), size: 60),
          SizedBox(height: 12),
          Text('مكتبتك بصحة ممتازة!',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00E676))),
          SizedBox(height: 6),
          Text('لا توجد مشاكل في البيانات',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // أزرار الإجراءات
  // ══════════════════════════════════════════════════════════════
  Widget _buildActionButtons(DataHealthReport report, Color primaryColor) {
    final hasIssues = report.issues.isNotEmpty;
    final fixableIssues = report.missingFilesCount;

    return Column(
      children: [
        if (hasIssues && fixableIssues > 0) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _scanning
                  ? null
                  : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF1B1F28),
                          title: const Text('إصلاح تلقائي'),
                          content: Text(
                            'سيقوم التطبيق بحذف المراجع لـ $fixableIssues ملف مفقود من البيانات.\n\n'
                            'لن تُحذف أي بيانات سليمة، فقط المراجع التالفة.',
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('إلغاء')),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: primaryColor),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('ابدأ الإصلاح'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await _runScan(autoFix: true);
                    },
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.healing),
              label: Text('إصلاح تلقائي ($fixableIssues مشكلة)'),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _scanning ? null : () => _runScan(autoFix: false),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: BorderSide(color: primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة الفحص'),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // قالب البطاقة
  // ══════════════════════════════════════════════════════════════
  Widget _cardWrapper({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
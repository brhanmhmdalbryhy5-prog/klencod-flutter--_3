import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../main.dart';
import '../services/statistics_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _loading = true;
  StatisticsData? _data;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final data = await StatisticsService().generateStatistics();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = primaryColorNotifier.value;

    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111318),
        title: const Text('إحصائياتك'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _buildMainStatsCard(primaryColor),
                const SizedBox(height: 20),
                _buildRatingCard(primaryColor),
                const SizedBox(height: 20),
                if (_data!.genreDistribution.isNotEmpty) _buildGenreChart(primaryColor),
                const SizedBox(height: 20),
                _buildStatusCard(primaryColor),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildMainStatsCard(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.6)], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 15, spreadRadius: 2)],
      ),
      child: Column(
        children: [
          const Icon(Icons.insights, size: 50, color: Colors.white),
          const SizedBox(height: 10),
          const Text('رحلة الأوتاكو', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('أنمي', '${_data!.totalAnimes}'),
              _statItem('حلقة', '${_data!.totalEpisodesWatched}'),
              _statItem('ساعة', _data!.totalHoursWatched.toStringAsFixed(0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.white70)),
      ],
    );
  }

  Widget _buildRatingCard(Color primaryColor) {
    return _cardWrapper(
      icon: Icons.star,
      iconColor: Colors.amber,
      title: 'تقييماتك',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('متوسط التقييم', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text('${_data!.averageRating.toStringAsFixed(1)} / 10', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('أعلى تقييم', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(_data!.topRatedAnime, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenreChart(Color primaryColor) {
    final genres = _data!.genreDistribution.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topGenres = genres.take(5).toList();
    final colors = [primaryColor, Colors.purpleAccent, Colors.cyan, Colors.orange, Colors.pinkAccent];

    return _cardWrapper(
      icon: Icons.pie_chart,
      iconColor: Colors.cyan,
      title: 'التصنيفات المفضلة',
      child: SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  sections: List.generate(topGenres.length, (index) {
                    return PieChartSectionData(
                      color: colors[index % colors.length],
                      value: topGenres[index].value.toDouble(),
                      title: '',
                      radius: 40,
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
                children: List.generate(topGenres.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[index % colors.length], shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${topGenres[index].key} (${topGenres[index].value})', style: const TextStyle(fontSize: 12, color: Colors.white70), overflow: TextOverflow.ellipsis)),
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

  Widget _buildStatusCard(Color primaryColor) {
    return _cardWrapper(
      icon: Icons.checklist,
      iconColor: Colors.greenAccent,
      title: 'حالة المشاهدة',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _data!.statusDistribution.entries.map((e) {
          return Chip(
            label: Text('${e.key}: ${e.value}'),
            backgroundColor: primaryColor.withOpacity(0.2),
            side: BorderSide(color: primaryColor.withOpacity(0.5)),
            labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
          );
        }).toList(),
      ),
    );
  }

  Widget _cardWrapper({required IconData icon, required Color iconColor, required String title, required Widget child}) {
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
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
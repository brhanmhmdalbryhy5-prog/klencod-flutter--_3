import '../models/anime.dart';
import 'storage_service.dart';

class StatisticsData {
  final int totalAnimes;
  final int totalEpisodesWatched;
  final int totalEpisodesAvailable;
  final double totalHoursWatched;
  final double averageRating;
  final String topGenre;
  final String topRatedAnime;
  final Map<String, int> genreDistribution;
  final Map<String, int> statusDistribution;

  StatisticsData({
    required this.totalAnimes,
    required this.totalEpisodesWatched,
    required this.totalEpisodesAvailable,
    required this.totalHoursWatched,
    required this.averageRating,
    required this.topGenre,
    required this.topRatedAnime,
    required this.genreDistribution,
    required this.statusDistribution,
  });
}

class StatisticsService {
  final StorageService _storage = StorageService();

  Future<StatisticsData> generateStatistics() async {
    final animes = await _storage.loadAnimes();
    
    int totalAnimes = animes.length;
    int totalEpisodesWatched = 0;
    int totalEpisodesAvailable = 0;
    double totalRating = 0;
    int ratedAnimesCount = 0;
    
    String topRatedAnimeTitle = 'لا يوجد';
    double highestRating = -1;

    Map<String, int> genreDistribution = {};
    Map<String, int> statusDistribution = {};

    for (var anime in animes) {
      totalEpisodesWatched += anime.watchedEpisodes;
      totalEpisodesAvailable += anime.episodes;

      // حساب التقييمات
      if (anime.rating > 0) {
        totalRating += anime.rating;
        ratedAnimesCount++;
        if (anime.rating > highestRating) {
          highestRating = anime.rating;
          topRatedAnimeTitle = anime.title;
        }
      }

      // توزيع الحالات
      final status = anime.status.isEmpty ? 'غير محدد' : anime.status;
      statusDistribution[status] = (statusDistribution[status] ?? 0) + 1;

      // توزيع التصنيفات
      final genres = anime.genre.split('،').map((e) => e.trim()).where((e) => e.isNotEmpty);
      for (var genre in genres) {
        genreDistribution[genre] = (genreDistribution[genre] ?? 0) + 1;
      }
    }

    // التصنيف الأكثر شيوعاً
    String topGenreName = 'غير محدد';
    int maxGenreCount = 0;
    genreDistribution.forEach((key, value) {
      if (value > maxGenreCount) {
        maxGenreCount = value;
        topGenreName = key;
      }
    });

    // حساب الساعات (نفترض أن الحلقة = 24 دقيقة = 0.4 ساعة)
    double totalHours = (totalEpisodesWatched * 24) / 60.0;

    double averageRating = ratedAnimesCount > 0 ? totalRating / ratedAnimesCount : 0.0;

    return StatisticsData(
      totalAnimes: totalAnimes,
      totalEpisodesWatched: totalEpisodesWatched,
      totalEpisodesAvailable: totalEpisodesAvailable,
      totalHoursWatched: totalHours,
      averageRating: averageRating,
      topGenre: topGenreName,
      topRatedAnime: topRatedAnimeTitle,
      genreDistribution: genreDistribution,
      statusDistribution: statusDistribution,
    );
  }
}
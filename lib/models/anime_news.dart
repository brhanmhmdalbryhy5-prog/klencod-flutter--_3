class AnimeNews {
  final String id;
  final int malId;
  final String title;
  final String? imageUrl;
  final String? imagePath;
  final DateTime releaseDate;
  final String format;
  final int episodes;
  final String genres;
  final String studios;
  final String synopsis;
  final double? score;
  final DateTime fetchedAt;

  AnimeNews({
    required this.id,
    required this.malId,
    required this.title,
    this.imageUrl,
    this.imagePath,
    required this.releaseDate,
    required this.format,
    required this.episodes,
    required this.genres,
    required this.studios,
    required this.synopsis,
    this.score,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'malId': malId,
        'title': title,
        'imageUrl': imageUrl,
        'imagePath': imagePath,
        'releaseDate': releaseDate.toIso8601String(),
        'format': format,
        'episodes': episodes,
        'genres': genres,
        'studios': studios,
        'synopsis': synopsis,
        'score': score,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory AnimeNews.fromJson(Map<String, dynamic> json) => AnimeNews(
        id: json['id'] as String,
        malId: json['malId'] as int,
        title: json['title'] as String? ?? 'بدون اسم',
        imageUrl: json['imageUrl'] as String?,
        imagePath: json['imagePath'] as String?,
        releaseDate: DateTime.parse(json['releaseDate'] as String),
        format: json['format'] as String? ?? '',
        episodes: json['episodes'] as int? ?? 0,
        genres: json['genres'] as String? ?? '',
        studios: json['studios'] as String? ?? '',
        synopsis: json['synopsis'] as String? ?? '',
        score: (json['score'] as num?)?.toDouble(),
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      );

  /// كم باقي على العرض
  Duration get timeRemaining => releaseDate.difference(DateTime.now());

  /// هل سيعرض قريباً (خلال 30 يوم)?
  bool get isSoon => timeRemaining.inDays >= 0 && timeRemaining.inDays <= 30;

  /// نص "بعد X يوم"
  String get timeRemainingText {
    final d = timeRemaining;
    if (d.isNegative) return 'معروض';
    if (d.inDays > 0) return 'بعد ${d.inDays} يوم';
    if (d.inHours > 0) return 'بعد ${d.inHours} ساعة';
    return 'بعد ${d.inMinutes} دقيقة';
  }
}
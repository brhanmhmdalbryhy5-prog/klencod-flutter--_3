class Anime {
  String id;
  String title;
  String status;
  String genre;
  String character;
  String summary;
  String memory;
  int episodes;
  int watchedEpisodes;
  double rating; // 🔥 أصبح double
  bool favorite;
  int colorIndex;
  String date;
  String? imagePath;
  double? globalRating;
  int? releaseYear;

  Anime({
    required this.id,
    this.title = '',
    this.status = '',
    this.genre = '',
    this.character = '',
    this.summary = '',
    this.memory = '',
    this.episodes = 0,
    this.watchedEpisodes = 0,
    this.rating = 0.0,
    this.favorite = false,
    this.colorIndex = 0,
    this.date = '',
    this.imagePath,
    this.globalRating,
    this.releaseYear,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id, 'title': title, 'status': status, 'genre': genre,
      'character': character, 'summary': summary, 'memory': memory,
      'episodes': episodes, 'watchedEpisodes': watchedEpisodes,
      'rating': rating, 'favorite': favorite, 'colorIndex': colorIndex,
      'date': date, 'imagePath': imagePath, 'globalRating': globalRating,
      'releaseYear': releaseYear,
    };
  }

  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      genre: json['genre'] as String? ?? '',
      character: json['character'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      memory: json['memory'] as String? ?? '',
      episodes: (json['episodes'] as num?)?.toInt() ?? 0,
      watchedEpisodes: (json['watchedEpisodes'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0, // 🔥 دعم الأرقام العشرية
      favorite: json['favorite'] as bool? ?? false,
      colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
      date: json['date'] as String? ?? '',
      imagePath: json['imagePath'] as String?,
      globalRating: (json['globalRating'] as num?)?.toDouble(),
      releaseYear: (json['releaseYear'] as num?)?.toInt(),
    );
  }
}
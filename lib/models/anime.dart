class Anime {
  String id;
  String title;
  String status;
  String genre;
  String character;
  String summary;
  String memory;
  int episodes;
  int rating;
  bool favorite;
  int colorIndex;
  String date;
  String? imagePath;
  double? globalRating;
  int? releaseYear;
  
  // 🔥 الحقل الجديد: عدد الحلقات التي شاهدتها
  int watchedEpisodes; 

  Anime({
    required this.id,
    this.title = '',
    this.status = '',
    this.genre = '',
    this.character = '',
    this.summary = '',
    this.memory = '',
    this.episodes = 0,
    this.rating = 0,
    this.favorite = false,
    this.colorIndex = 0,
    this.date = '',
    this.imagePath,
    this.globalRating,
    this.releaseYear,
    this.watchedEpisodes = 0, // القيمة الافتراضية
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'status': status,
      'genre': genre,
      'character': character,
      'summary': summary,
      'memory': memory,
      'episodes': episodes,
      'rating': rating,
      'favorite': favorite,
      'colorIndex': colorIndex,
      'date': date,
      'imagePath': imagePath,
      'globalRating': globalRating,
      'releaseYear': releaseYear,
      'watchedEpisodes': watchedEpisodes,
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
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      favorite: json['favorite'] as bool? ?? false,
      colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
      date: json['date'] as String? ?? '',
      imagePath: json['imagePath'] as String?,
      globalRating: (json['globalRating'] as num?)?.toDouble(),
      releaseYear: (json['releaseYear'] as num?)?.toInt(),
      watchedEpisodes: (json['watchedEpisodes'] as num?)?.toInt() ?? 0,
    );
  }
}
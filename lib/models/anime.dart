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
  double rating;
  bool favorite;
  int colorIndex;
  String date;
  String? imagePath; // مسار الصورة المحلية
  String? imageUrl;  // 🔥 رابط الصورة من الإنترنت
  double? globalRating;
  int? releaseYear;
  String? parentId;
  String? partName;
  String? videoPath;

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
    this.imageUrl,
    this.globalRating,
    this.releaseYear,
    this.parentId,
    this.partName,
    this.videoPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id, 'title': title, 'status': status, 'genre': genre,
      'character': character, 'summary': summary, 'memory': memory,
      'episodes': episodes, 'watchedEpisodes': watchedEpisodes,
      'rating': rating, 'favorite': favorite, 'colorIndex': colorIndex,
      'date': date, 'imagePath': imagePath, 'imageUrl': imageUrl,
      'globalRating': globalRating, 'releaseYear': releaseYear, 
      'parentId': parentId, 'partName': partName, 'videoPath': videoPath,
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
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      favorite: json['favorite'] as bool? ?? false,
      colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
      date: json['date'] as String? ?? '',
      imagePath: json['imagePath'] as String?,
      imageUrl: json['imageUrl'] as String?,
      globalRating: (json['globalRating'] as num?)?.toDouble(),
      releaseYear: (json['releaseYear'] as num?)?.toInt(),
      parentId: json['parentId'] as String?,
      partName: json['partName'] as String?,
      videoPath: json['videoPath'] as String?,
    );
  }
}
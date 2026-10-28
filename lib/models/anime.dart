
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

  Anime({
    required this.id,
    required this.title,
    this.status = 'مكتمل',
    this.genre = '',
    this.character = '',
    this.summary = '',
    this.memory = '',
    this.episodes = 0,
    this.rating = 0,
    this.favorite = false,
    this.colorIndex = 0,
    this.date = '',
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
    };
  }

  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'مكتمل',
      genre: json['genre'] as String? ?? '',
      character: json['character'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      memory: json['memory'] as String? ?? '',
      episodes: (json['episodes'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      favorite: json['favorite'] as bool? ?? false,
      colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
      date: json['date'] as String? ?? '',
    );
  }
}
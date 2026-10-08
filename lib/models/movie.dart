class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.releaseDate,
    required this.voteAverage,
  });

  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final DateTime? releaseDate;
  final double voteAverage;

  factory Movie.fromJson(Map<String, dynamic> json) {
    final poster = json['poster_path'] as String?;
    final date = json['release_date'] as String?;
    final title = json['title'] as String?;

    return Movie(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: title == null || title.trim().isEmpty
          ? 'Titre indisponible'
          : title,
      overview: json['overview'] as String? ?? '',
      posterPath: poster == null || poster.trim().isEmpty ? null : poster,
      releaseDate: date == null ? null : DateTime.tryParse(date),
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
    );
  }
}

class Recipe {
  final int? id;
  final String title;
  final String? description;
  final String instructions;
  final String? imageUrl;
  final int? cookTimeMinutes;
  final int? servings;
  final String? tags;
  final double? rating;
  final int authorId;
  final String? authorName;

  Recipe({
    this.id,
    required this.title,
    this.description,
    required this.instructions,
    this.imageUrl,
    this.cookTimeMinutes,
    this.servings,
    this.tags,
    this.rating,
    required this.authorId,
    this.authorName,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as int?,
      title: json['title'] as String,
      description: json['description'] as String?,
      instructions: json['instructions'] as String,
      imageUrl: json['image_url'] as String?,
      cookTimeMinutes: json['cook_time_minutes'] as int?,
      servings: json['servings'] as int?,
      tags: json['tags'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      authorId: json['author_id'] as int,
      authorName: json['author_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'instructions': instructions,
      'image_url': imageUrl,
      'cook_time_minutes': cookTimeMinutes,
      'servings': servings,
      'tags': tags,
      'author_id': authorId,
    };
  }
}



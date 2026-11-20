class User {
  final int id;
  final String username;
  final String? avatarUrl;
  final String? bio;

  User({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.bio,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
    );
  }
}









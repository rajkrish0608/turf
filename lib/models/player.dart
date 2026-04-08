enum PlayerRole { user, admin }

class Player {
  final String username;
  final String avatar;
  final String color;
  final PlayerRole role;
  final bool isBanned;

  const Player({
    required this.username,
    this.avatar = '😎',
    this.color = '#58a6ff',
    this.role = PlayerRole.user,
    this.isBanned = false,
  });

  bool get isAdmin => role == PlayerRole.admin;

  Player copyWith({
    String? username,
    String? avatar,
    String? color,
    PlayerRole? role,
    bool? isBanned,
  }) {
    return Player(
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      color: color ?? this.color,
      role: role ?? this.role,
      isBanned: isBanned ?? this.isBanned,
    );
  }
}

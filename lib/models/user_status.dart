enum UserStatus {
  online,
  away,
  dnd,
  invisible;

  String get label => switch (this) {
    UserStatus.online    => 'Online',
    UserStatus.away      => 'Away',
    UserStatus.dnd       => 'Do not disturb',
    UserStatus.invisible => 'Invisible',
  };

  static UserStatus fromString(String? v) => switch (v) {
    'away'      => UserStatus.away,
    'dnd'       => UserStatus.dnd,
    'invisible' => UserStatus.invisible,
    _           => UserStatus.online,
  };
}

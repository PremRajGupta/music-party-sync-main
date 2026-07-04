class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://music-party-sync-main.onrender.com/api',
  );

  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'https://music-party-socket.onrender.com',
  );

  static String get mediaUrl => socketUrl;
  static String get songUrl => '$socketUrl/static/song.mp3';
}

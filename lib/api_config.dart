class ApiConfig {
  static const String baseUrl = 'http://10.0.2.2:5000';
  static const String socketUrl = 'http://10.0.2.2:5000';
  
  // Auth endpoints
  static const String signup = '/signup';
  static const String login = '/login';
  static const String firebaseGoogleLogin = '/firebase-google-login';
  static const String checkUserExists = '/check-user-exists';
  
  // User endpoints
  static const String userByEmail = '/user-by-email';
  static const String profile = '/profile';
  
  // Lost items
  static const String lostItems = '/lost-items';
  static const String lostItemsAdmin = '/lost-items-admin';
  
  // Found items
  static const String foundItems = '/found-items';
  
  // Chat
  static const String sendMessage = '/send_message';
  static const String getMessages = '/get_messages';
  static const String getChats = '/get_chats';
  static const String markRead = '/mark_read';
  
  // Search
  static const String searchLostItems = '/search-lost-items';
  
  // Activity
  static const String activityFeed = '/activity-feed';
  
  // Health
  static const String health = '/health';
  
  static String getUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
  
  static String getSocketUrl() {
    return socketUrl;
  }
}

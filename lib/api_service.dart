import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_config.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();
  IO.Socket? _socket;
  
  // ========== Socket.IO Methods ==========
  
  void connectSocket() {
    if (_socket != null && _socket!.connected) return;
    
    _socket = IO.io(
      ApiConfig.getSocketUrl(),
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .build(),
    );
    
    _socket!.onConnect((_) {
      print('Socket connected');
    });
    
    _socket!.onDisconnect((_) {
      print('Socket disconnected');
    });
    
    _socket!.on('new_message', (data) {
      print('New message: $data');
    });
  }
  
  void disconnectSocket() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
  
  void joinChatRoom(String user1, String user2) {
    _socket?.emit('join_chat', {'user1': user1, 'user2': user2});
  }
  
  void sendMessageViaSocket({
    required String authorId,
    required String receiverId,
    required String text,
  }) {
    _socket?.emit('send_message', {
      'author_id': authorId,
      'receiver_id': receiverId,
      'text': text,
    });
  }
  
  void onNewMessage(Function(dynamic) callback) {
    _socket?.on('new_message', callback);
  }
  
  void offNewMessage() {
    _socket?.off('new_message');
  }
  
  // ========== HTTP Methods ==========
  
  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  
  Future<http.Response> _get(String endpoint) async {
    final headers = await _getHeaders();
    return http.get(
      Uri.parse(ApiConfig.getUrl(endpoint)),
      headers: headers,
    );
  }
  
  Future<http.Response> _post(String endpoint, {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    return http.post(
      Uri.parse(ApiConfig.getUrl(endpoint)),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }
  
  // ========== Auth Methods ==========
  
  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String name,
  }) async {
    final response = await _post(ApiConfig.signup, body: {
      'email': email,
      'password': password,
      'name': name,
    });
    return jsonDecode(response.body);
  }
  
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _post(ApiConfig.login, body: {
      'email': email,
      'password': password,
    });
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _storage.write(key: 'access_token', value: data['session']['access_token']);
      await _storage.write(key: 'refresh_token', value: data['session']['refresh_token']);
      await _storage.write(key: 'email', value: data['user']['email']);
      return data;
    }
    
    return jsonDecode(response.body);
  }
  
  Future<Map<String, dynamic>> firebaseGoogleLogin(String accessToken) async {
    final response = await _post(ApiConfig.firebaseGoogleLogin, body: {
      'access_token': accessToken,
    });
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _storage.write(key: 'access_token', value: data['session']['access_token']);
      await _storage.write(key: 'refresh_token', value: data['session']['refresh_token']);
      await _storage.write(key: 'email', value: data['user']['email']);
      return data;
    }
    
    return jsonDecode(response.body);
  }
  
  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'email');
    disconnectSocket();
  }
  
  // ========== User Methods ==========
  
  Future<Map<String, dynamic>> getUserByEmail(String email) async {
    final response = await _get('${ApiConfig.userByEmail}/$email');
    return jsonDecode(response.body);
  }
  
  Future<bool> checkUserExists(String email) async {
    final response = await _post(ApiConfig.checkUserExists, body: {'email': email});
    final data = jsonDecode(response.body);
    return data['exists'] ?? false;
  }
  
  Future<Map<String, dynamic>?> getProfile(String email) async {
    final response = await _get('${ApiConfig.profile}/$email');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }
  
  Future<bool> completeProfile({
    required String name,
    required int nsuId,
    required String phone,
  }) async {
    final response = await _post(ApiConfig.profile, body: {
      'name': name,
      'nsu_id': nsuId,
      'phone_number': phone,
    });
    return response.statusCode == 200;
  }
  
  // ========== Chat Methods ==========
  
  Future<List<dynamic>> getMessages({
    required String authorId,
    required String receiverId,
  }) async {
    final response = await _post(ApiConfig.getMessages, body: {
      'author_id': authorId,
      'receiver_id': receiverId,
    });
    return jsonDecode(response.body);
  }
  
  Future<List<dynamic>> getChats(String userId) async {
    final response = await _post(ApiConfig.getChats, body: {'user_id': userId});
    return jsonDecode(response.body);
  }
  
  Future<void> markMessagesRead({
    required String authorId,
    required String receiverId,
  }) async {
    await _post(ApiConfig.markRead, body: {
      'author_id': authorId,
      'receiver_id': receiverId,
    });
  }
  
  // ========== Item Methods ==========
  
  Future<List<dynamic>> getLostItems() async {
    final response = await _get(ApiConfig.lostItems);
    return jsonDecode(response.body);
  }
  
  Future<List<dynamic>> searchLostItems({required String query}) async {
    final response = await _get('${ApiConfig.searchLostItems}?q=$query');
    return jsonDecode(response.body);
  }
  
  Future<List<dynamic>> getActivityFeed() async {
    final response = await _get(ApiConfig.activityFeed);
    return jsonDecode(response.body);
  }
  
  Future<bool> markItemAsFound(String itemId) async {
    final response = await _post(ApiConfig.getMarkFoundUrl(itemId));
    return response.statusCode == 200;
  }
  
  Future<bool> reportLostItem({
    required String description,
    required String location,
    required String imagePath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.getUrl(ApiConfig.lostItems)),
    );
    request.fields['description'] = description;
    request.fields['location'] = location;
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    
    final streamedResponse = await request.send();
    return streamedResponse.statusCode == 201;
  }
}

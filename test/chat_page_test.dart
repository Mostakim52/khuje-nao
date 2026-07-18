import 'package:flutter_test/flutter_test.dart';
import 'package:khuje_nao/chat_page.dart';

void main() {
  group('ChatPage Tests', () {
    test('ChatPage can be instantiated', () {
      const chatPage = ChatPage();
      expect(chatPage, isA<ChatPage>());
    });
  });
}

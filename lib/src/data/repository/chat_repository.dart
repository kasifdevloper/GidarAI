import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/models/app_models.dart';
import '../local/app_database.dart';

class ChatRepository {
  ChatRepository(this._database);

  final AppDatabase _database;

  Stream<List<ChatSession>> watchAllChats() {
    return _database.watchAllChats().map((rows) => rows.map(_mapChatRow).toList());
  }

  Future<List<ChatSession>> loadAllChats() async {
    final rows = await _database.getAllChatsOnce();
    return rows.map(_mapChatRow).toList();
  }

  Future<void> saveChat(ChatSession session) async {
    await _database.upsertChat(
      ChatsCompanion.insert(
        id: session.id,
        title: session.title,
        createdTimestamp: Value(session.createdAt.millisecondsSinceEpoch),
        timestamp: session.updatedAt.millisecondsSinceEpoch,
        messages: jsonEncode(session.messages.map((message) => message.toMap()).toList()),
      ),
    );
    await _database.enforceChatLimit();
  }

  Future<void> deleteChat(String chatId) async {
    await _database.deleteChatById(chatId);
  }

  Future<void> clearAll() async {
    await _database.clearChats();
  }

  ChatSession _mapChatRow(Chat row) {
    List<dynamic> decodedMessages = const [];
    try {
      decodedMessages = jsonDecode(row.messages) as List<dynamic>;
    } catch (_) {
      decodedMessages = const [];
    }
    return ChatSession(
      id: row.id,
      title: row.title,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdTimestamp),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.timestamp),
      messages: decodedMessages
          .map((message) => ChatMessage.fromMap(Map<String, dynamic>.from(message as Map)))
          .toList(),
    );
  }
}

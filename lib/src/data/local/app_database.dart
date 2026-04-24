import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Chats extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get createdTimestamp => integer().withDefault(const Constant(0))();
  IntColumn get timestamp => integer()();
  TextColumn get messages => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Messages extends Table {
  IntColumn get id => integer()();
  TextColumn get chatId => text().references(Chats, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()();
  TextColumn get content => text()();
  IntColumn get timestamp => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Chats, Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(chats, chats.createdTimestamp);
            await customStatement(
              'UPDATE chats SET created_timestamp = timestamp WHERE created_timestamp IS NULL',
            );
          }
        },
      );

  Stream<List<Chat>> watchAllChats() {
    return (select(chats)..orderBy([(table) => OrderingTerm.desc(table.timestamp)])).watch();
  }

  Future<List<Chat>> getAllChatsOnce() {
    return (select(chats)..orderBy([(table) => OrderingTerm.desc(table.timestamp)])).get();
  }

  Future<Chat?> getChatById(String chatId) {
    return (select(chats)..where((table) => table.id.equals(chatId))).getSingleOrNull();
  }

  Future<void> upsertChat(ChatsCompanion chat) async {
    await into(chats).insertOnConflictUpdate(chat);
  }

  Future<void> deleteChatById(String chatId) async {
    await (delete(chats)..where((table) => table.id.equals(chatId))).go();
  }

  Future<void> clearChats() => delete(chats).go();

  Future<int> chatCount() async {
    final countExpression = chats.id.count();
    final query = selectOnly(chats)..addColumns([countExpression]);
    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }

  Future<void> enforceChatLimit({int maxChats = 100}) async {
    final currentChats = await getAllChatsOnce();
    if (currentChats.length <= maxChats) return;
    final overflow = currentChats.skip(maxChats).toList();
    for (final chat in overflow) {
      await deleteChatById(chat.id);
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final file = File(p.join(documentsDirectory.path, 'gidar_ai.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

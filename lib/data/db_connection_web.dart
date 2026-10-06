import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

/// Web 预览使用的内存 SQLite。数据不跨刷新持久化，只用于查看界面效果。
QueryExecutor openDriftConnection() {
  return LazyDatabase(() async {
    final sqlite3 = await WasmSqlite3.loadFromUrl(
      Uri.parse('sqlite3.wasm'),
    );
    sqlite3.registerVirtualFileSystem(
      InMemoryFileSystem(name: 'beecount_preview'),
      makeDefault: true,
    );
    return WasmDatabase.inMemory(sqlite3);
  });
}

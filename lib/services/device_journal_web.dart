import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

/// Synchronous localStorage plus IndexedDB.
///
/// Safari can drop an in-flight async write when the tab closes. localStorage
/// is written first, and IndexedDB is the copy that survives longer on iPhone.
class DeviceJournal {
  static const _dbName = 'united_kites_books';
  static const _store = 'kv';
  static IDBDatabase? _db;
  static Future<IDBDatabase?>? _opening;

  static void writeSync(String key, String value) {
    try {
      window.localStorage.setItem(key, value);
    } catch (_) {}
  }

  static String? readSync(String key) {
    try {
      return window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeDurable(String key, String value) async {
    final db = await _database();
    if (db == null) return;
    final txn = db.transaction(_store.toJS, 'readwrite');
    final done = Completer<void>();
    txn.oncomplete = ((Event _) {
      if (!done.isCompleted) done.complete();
    }).toJS;
    txn.onerror = ((Event _) {
      if (!done.isCompleted) done.completeError(StateError('IndexedDB write failed'));
    }).toJS;
    await _request<void>(
      txn.objectStore(_store).put(value.toJS, key.toJS),
      (_) {},
    );
    await done.future;
  }

  static Future<String?> readDurable(String key) async {
    final db = await _database();
    if (db == null) return null;
    final txn = db.transaction(_store.toJS, 'readonly');
    return _request<String?>(
      txn.objectStore(_store).get(key.toJS),
      (result) {
        final dart = result?.dartify();
        return dart is String ? dart : null;
      },
    );
  }

  static Future<IDBDatabase?> _database() {
    return _opening ??= _open();
  }

  static Future<IDBDatabase?> _open() async {
    if (_db != null) return _db;
    try {
      final request = window.indexedDB.open(_dbName, 1);
      request.onupgradeneeded = ((Event _) {
        final db = request.result as IDBDatabase;
        if (!_hasStore(db.objectStoreNames, _store)) {
          db.createObjectStore(_store);
        }
      }).toJS;
      _db = await _request<IDBDatabase>(request, (result) => result as IDBDatabase);
      return _db;
    } catch (_) {
      _opening = null;
      return null;
    }
  }

  static bool _hasStore(DOMStringList names, String store) {
    for (var i = 0; i < names.length; i++) {
      if (names.item(i) == store) return true;
    }
    return false;
  }

  static Future<T> _request<T>(IDBRequest request, T Function(JSAny?) decode) {
    final completer = Completer<T>();
    request.onsuccess = ((Event _) {
      if (!completer.isCompleted) completer.complete(decode(request.result));
    }).toJS;
    request.onerror = ((Event _) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('IndexedDB request failed'));
      }
    }).toJS;
    return completer.future;
  }
}

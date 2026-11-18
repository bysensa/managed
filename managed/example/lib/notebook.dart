class User {
  const User(this.id, this.name);

  final String id;
  final String name;
}

abstract interface class NoteStorage {
  Future<String?> read(String owner, String key);
  Future<void> write(String owner, String key, String text);
}

/// В памяти сервера у каждого аккаунта свой набор ключей.
class MemoryStorage implements NoteStorage {
  final _notes = <(String, String), String>{};

  @override
  Future<String?> read(String owner, String key) async => _notes[(owner, key)];

  @override
  Future<void> write(String owner, String key, String text) async {
    _notes[(owner, key)] = text;
  }
}

class TextCache {
  final _entries = <String, String>{};
  bool _closed = false;

  String? read(String key) {
    if (_closed) throw StateError('Кэш уже закрыт');
    return _entries[key];
  }

  void put(String key, String text) {
    if (_closed) throw StateError('Кэш уже закрыт');
    _entries[key] = text;
  }

  void close() {
    _closed = true;
    _entries.clear();
  }
}

abstract interface class Notebook {
  Future<String?> read(String key);
  Future<void> save(String key, String text);
}

class CachedNotebook implements Notebook {
  CachedNotebook(this.owner, this._storage, this._cache);

  final User owner;
  final NoteStorage _storage;
  final TextCache _cache;
  bool _closed = false;

  @override
  Future<String?> read(String key) async {
    if (_closed) throw StateError('Блокнот уже закрыт');
    final cached = _cache.read(key);
    if (cached != null) return cached;
    final text = await _storage.read(owner.id, key);
    if (!_closed && text != null) _cache.put(key, text);
    return text;
  }

  @override
  Future<void> save(String key, String text) async {
    if (_closed) throw StateError('Блокнот уже закрыт');
    await _storage.write(owner.id, key, text);
    if (!_closed) _cache.put(key, text);
  }

  void close() => _closed = true;
}

class DraftBuffer {
  final edits = <String, String>{};

  void close() => edits.clear();
}

class NoteEditor {
  NoteEditor(this.notebook, this.buffer);

  final Notebook notebook;
  final DraftBuffer buffer;
  bool _closed = false;
  Future<void>? _saving;

  void edit(String key, String text) {
    if (_closed) throw StateError('Редактор уже закрыт');
    buffer.edits[key] = text;
  }

  Future<void> save() {
    if (_closed) throw StateError('Редактор уже закрыт');
    return _savePending();
  }

  // Выход во время ручного сохранения дожидается той же записи.
  Future<void> _savePending() => _saving ??= Future.microtask(_flush);

  Future<void> _flush() async {
    try {
      while (buffer.edits.isNotEmpty) {
        final entry = buffer.edits.entries.first;
        await notebook.save(entry.key, entry.value);
        if (buffer.edits[entry.key] == entry.value) {
          buffer.edits.remove(entry.key);
        }
      }
    } finally {
      _saving = null;
    }
  }

  Future<void> close() {
    _closed = true;
    return _savePending();
  }
}

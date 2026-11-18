part of '../managed.dart';

/// A source replacement or a scope reset ends one generation. Entries subscribe
/// when constructed, so reverse subscription order releases consumers first.
class _Lifetime {
  _Lifetime({this.ownsTransients = true});

  final bool ownsTransients;
  static final _releasing = Object();
  int generation = 0;
  final _entries = <_Entry>{};

  Future<void> invalidate({void Function()? publish}) {
    generation++;
    // A disposer may itself clear a source or scope. Its own batch already
    // owns those entries and must never wait on itself.
    final enclosing = Zone.current[_releasing] as Set<_Entry>?;
    final entries = _entries
        .toList()
        .reversed
        .where((entry) => enclosing?.contains(entry) != true)
        .toList();
    final releases = [for (final entry in entries) entry.detach()];
    // Publish the new source after detaching the old generation and before a
    // disposal callback can read or replace it.
    publish?.call();
    if (releases.isEmpty) return Future.value();
    final batch = {...?enclosing, ...entries};
    return runZoned(() => _releaseAll(releases),
        zoneValues: {_releasing: batch}).whenComplete(batch.clear);
  }
}

/// Cache entries and disposable transient instances can share several lifetimes.
class _Entry<T> {
  _Entry(this.lifetimes, this.onDispose, this.evict) {
    for (final lifetime in lifetimes) {
      lifetime._entries.add(this);
    }
  }

  factory _Entry.ready(
          T value, Set<_Lifetime> lifetimes, OnDispose<T>? onDispose) =>
      _Entry<T>(lifetimes, onDispose, null)..build(() => value);

  late T value;
  final Set<_Lifetime> lifetimes;
  final OnDispose<T>? onDispose;
  final void Function()? evict;
  Completer<void>? _disposing;
  Completer<void>? _built;
  bool _building = true;
  bool _hasValue = false;

  T build(Factory<T> factory) {
    try {
      value = factory();
      _hasValue = true;
    } catch (_) {
      _unregister();
      rethrow;
    } finally {
      _building = false;
      _built?.complete();
    }
    checkActive();
    return value;
  }

  void checkActive() {
    if (_disposing != null) {
      throw StateError('The instance was invalidated during construction.');
    }
  }

  void _unregister() {
    for (final lifetime in lifetimes) {
      lifetime._entries.remove(this);
    }
  }

  FutureOr<void> _dispose() {
    if (_building) {
      // The factory triggered this invalidation before returning its value.
      return (_built ??= Completer<void>()).future.then((_) => _dispose());
    }
    if (_hasValue) return onDispose?.call(value);
  }

  /// Evict synchronously, before any user callback can re-enter the graph.
  /// Overlapping invalidations wait for the same disposal.
  FutureOr<void> Function() detach() {
    final pending = _disposing;
    if (pending != null) return () => pending.future;
    final done = _disposing = Completer<void>();
    evict?.call();

    return () {
      try {
        final result = _dispose();
        if (result is Future<void>) {
          done.complete(result.whenComplete(_unregister));
          return done.future;
        }
      } catch (error, stack) {
        _unregister();
        done.completeError(error, stack);
        return done.future;
      }
      _unregister();
      done.complete();
    };
  }
}

Future<void> _releaseAll(List<FutureOr<void> Function()> releases) async {
  Object? firstError;
  StackTrace? firstStack;
  for (final release in releases) {
    try {
      final result = release();
      if (result is Future<void>) await result;
    } catch (error, stack) {
      firstError ??= error;
      firstStack ??= stack;
    }
  }
  if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
}

/// Dart keeps a factory's zone in its asynchronous callbacks. Reject lookups
/// from that zone once any of the inputs to the factory has been invalidated.
class _Resolution {
  _Resolution(this.provider, Set<_Lifetime> lifetimes, this.ownsTransients)
      : generations = {for (final life in lifetimes) life: life.generation};

  static final key = Object();
  static _Resolution? get current => Zone.current[key] as _Resolution?;

  final Manage provider;
  final Map<_Lifetime, int> generations;
  final bool ownsTransients;
  bool building = false;

  R run<R>(R Function() action) {
    if (identical(current, this)) return action();
    building = true;
    try {
      return runZoned(action, zoneValues: {key: this});
    } finally {
      building = false;
    }
  }

  void check() {
    for (final entry in generations.entries) {
      if (entry.key.generation != entry.value) {
        throw StateError('The dependencies of this instance were invalidated.');
      }
    }
  }
}

part of 'manage.dart';

/// Implement on a dependency that owns resources or signals a change of state.
/// A shared instance stays available while its consumers are recreated.
mixin DependencyLifecycle {
  WeakReference<Manage>? _owner;

  _InstanceChanges? _attach(Manage registration) {
    final reference = _owner;
    if (reference != null) return reference.target?._changesFor(this);
    final changes = registration._changesFor(this);
    _owner = WeakReference(changes.owner);
    return changes;
  }

  /// Called synchronously after construction and before onNewInstance.
  void init() {}

  /// Called when a managed instance is released. Consumers are disposed first.
  FutureOr<void> dispose() {}

  /// Evict consumers of this instance immediately and await their cleanup.
  /// The object decides which changes matter, e.g. a different account ID.
  Future<void> dependencyChanged() =>
      _owner?.target?._dependencyChanged(this) ?? Future<void>.value();
}

class _InstanceChanges extends _Lifetime {
  _InstanceChanges(this.owner);
  // A live cache entry or subscriber keeps the first registration available
  // even when the instance is accessed through a different cache alias.
  final Manage owner;
}

class _Lifetime {
  _Lifetime({this.ownsTransients = true});

  final bool ownsTransients;
  static final _releasing = Object();
  int generation = 0;
  final _entries = <_Entry>{};

  Future<void> invalidate() {
    generation++;
    return release(_entries);
  }

  static Future<void> release(Iterable<_Entry> affected) {
    // A disposer may itself invalidate another lifetime. Its own batch already
    // owns those entries and must never wait on itself.
    final enclosing = Zone.current[_releasing] as Set<_Entry>?;
    final entries = affected
        .where((entry) => enclosing?.contains(entry) != true)
        .toList()
      ..sort((a, b) => b.order.compareTo(a.order));
    final releases = [for (final entry in entries) entry.detach()];
    if (releases.isEmpty) return Future.value();
    final batch = {...?enclosing, ...entries};
    // Disposers must not inherit the resolution of the code that triggered
    // the invalidation, e.g. a stream callback registered inside a factory.
    return runZoned(() => _releaseAll(releases),
            zoneValues: {_releasing: batch, _Resolution.key: null})
        .whenComplete(batch.clear);
  }
}

/// Cache entries and disposable transient instances can share several lifetimes.
class _Entry<T> {
  _Entry(this.lifetimes, this.onDispose, this.evict) {
    for (final lifetime in lifetimes) {
      lifetime._entries.add(this);
    }
  }

  static int _nextOrder = 0;
  int order = _nextOrder++;

  void subscribe(_Lifetime lifetime) {
    if (lifetimes.add(lifetime)) lifetime._entries.add(this);
  }

  late T _value;
  _InstanceChanges? _changes;
  bool _initialized = false;
  T get value {
    if (!_initialized) throw StateError('The instance is still initializing.');
    return _value;
  }

  final Set<_Lifetime> lifetimes;
  final OnDispose<T>? onDispose;
  final void Function()? evict;
  Completer<void>? _disposing;
  Completer<void>? _built;
  bool _building = true;
  bool _hasValue = false;

  // Where the entry was cached, so a disposer can still reach it while the
  // cleanup walks from consumers to inputs.
  Map<Object, _Entry>? cache;
  Object? cacheKey;
  bool _released = false;

  T build(Factory<T> factory, void Function(T) initialize) {
    try {
      _value = factory();
      _hasValue = true;
      checkActive();
      initialize(_value);
    } catch (_) {
      if (!_hasValue) _unregister();
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
      // The factory or init() triggered invalidation before setup finished.
      return (_built ??= Completer<void>()).future.then((_) => _dispose());
    }
    if (!_hasValue) return null;
    final instance = _value;
    if (instance is DependencyLifecycle) {
      if (onDispose == null) return instance.dispose();
      return _releaseAll([instance.dispose, () => onDispose!(instance)]);
    }
    return onDispose?.call(instance);
  }

  /// Evict synchronously, before any user callback can re-enter the graph.
  /// Overlapping invalidations wait for the same disposal.
  FutureOr<void> Function() detach() {
    final pending = _disposing;
    if (pending != null) return () => pending.future;
    final done = _disposing = Completer<void>();
    evict?.call();

    return () {
      _released = true;
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
  _Resolution(this.provider, Set<_Lifetime> lifetimes, this._hasOwner)
      : generations = {for (final life in lifetimes) life: life.generation};

  static final key = Object();
  static _Resolution? get current => Zone.current[key] as _Resolution?;

  final Manage provider;
  final Map<_Lifetime, int> generations;
  final bool _hasOwner;
  bool get ownsTransients =>
      _hasOwner || generations.keys.any((life) => life.ownsTransients);
  final _transients = <_Entry>{};
  _Entry? _entry;
  bool building = false;

  // A unique sibling may already have been created when a subsequent input
  // reveals its instance-specific notification. Enrol both in that lifetime.
  void track(_Entry entry) {
    if (!_transients.add(entry)) return;
    if (ownsTransients) {
      for (final life in generations.keys) {
        entry.subscribe(life);
      }
    }
  }

  void observe(
      Manage input, Iterable<_Lifetime> lifetimes, _InstanceChanges? changes,
      [Iterable<_Entry> transients = const []]) {
    if (!building ||
        !provider._dependencies.any((d) => identical(d._canonical, input))) {
      return;
    }
    final previouslyOwned = ownsTransients;
    final added = {
      ...lifetimes,
      if (changes != null) changes,
    }..removeWhere(generations.containsKey);
    for (final life in added) {
      generations[life] = life.generation;
    }
    if (added.isNotEmpty && ownsTransients) {
      final subscriptions = previouslyOwned ? added : generations.keys;
      for (final entry in [..._transients, if (_entry != null) _entry!]) {
        for (final life in subscriptions) {
          entry.subscribe(life);
        }
      }
    }
    if (input.scope == ScopeType.unique) {
      for (final entry in transients) {
        track(entry);
      }
    }
    // A factory or init() can resolve another declared input while building.
    _entry?.order = _Entry._nextOrder++;
  }

  R run<R>(R Function() action) {
    final parent = current;
    if (identical(parent, this)) return action();
    building = true;
    try {
      final value = runZoned(action, zoneValues: {key: this});
      parent?.observe(
          provider,
          generations.keys,
          value is DependencyLifecycle ? value._attach(provider) : null,
          _transients);
      return value;
    } catch (_) {
      final abandoned = {
        ..._transients,
        if (_entry?._hasValue == true) _entry!,
      }.where((e) => e._disposing == null);
      if (abandoned.isNotEmpty) unawaited(_Lifetime.release(abandoned));
      rethrow;
    } finally {
      building = false;
      _transients.clear();
      _entry = null;
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

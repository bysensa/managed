part of '../managed.dart';

/// Controls how instances are reused. Cached and singleton registrations with
/// the same factory and declared dependencies share an instance in that scope.
abstract class Scope {
  static final _unique = _InstanceScope();
  static final _singleton = _InstanceScope(cache: true);
  static final _cached = _InstanceScope(cache: true, reset: _Lifetime());

  static Scope get unique => _unique;
  static Scope get singleton => _singleton;
  static Scope get cached => _cached;

  T provideUsing<T>(
    Factory<T> factory, {
    OnNewInstance<T>? onNewInstance,
    OnDispose<T>? onDispose,
  });

  /// Evicts cached instances and their live dependents immediately. Completes
  /// once their disposal callbacks have finished, in consumer-first order.
  /// Direct resets of [unique] and [singleton] have no effect.
  Future<void> reset();
}

class _InstanceScope implements Scope {
  _InstanceScope({bool cache = false, _Lifetime? reset})
      : _instances = cache ? {} : null,
        _reset = reset;

  final Map<Object, _Entry>? _instances;
  final _Lifetime? _reset;

  @override
  T provideUsing<T>(
    Factory<T> factory, {
    OnNewInstance<T>? onNewInstance,
    OnDispose<T>? onDispose,
  }) {
    final entry = _instances?[factory];
    if (entry != null) return entry.value as T;
    final reset = _reset;
    return _create(
        factory, factory, {if (reset != null) reset}, onNewInstance, onDispose);
  }

  T _create<T>(
    Object key,
    Factory<T> factory,
    Set<_Lifetime> lifetimes,
    OnNewInstance<T>? onNewInstance,
    OnDispose<T>? onDispose, {
    _Resolution? resolution,
  }) {
    final cache = _instances;
    final context = resolution ?? _Resolution.current;
    late final _Entry<T> entry;
    entry = _Entry<T>(lifetimes, onDispose, () {
      if (identical(cache?[key], entry)) cache?.remove(key);
    });
    resolution?._entry = entry;
    try {
      final value = entry.build(factory, (instance) {
        context?.check();
        cache?[key] = entry;
        if (instance is DependencyLifecycle) {
          if (resolution != null) {
            entry._changes = instance._attach(resolution.provider);
          }
          instance.init();
          entry.checkActive();
          context?.check();
        }
        entry._initialized = true;
        onNewInstance?.call(instance);
        context?.check();
      });
      if (cache == null) {
        if (value is DependencyLifecycle || onDispose != null) {
          resolution?.track(entry);
        } else {
          entry._unregister();
        }
      }
      return value;
    } catch (_) {
      if (resolution == null && entry._hasValue && entry._disposing == null) {
        unawaited(_Lifetime.release([entry]));
      }
      rethrow;
    }
  }

  @override
  Future<void> reset() => _reset?.invalidate() ?? Future.value();
}

/// A factory may be registered in both a global module and a user module.
/// Only registrations that bind the same inputs can share its cached result.
class _FactoryBinding {
  _FactoryBinding(this.factory, List<Manage> dependencies)
      : inputs = [
          for (final dep in dependencies) (dep.managedType, dep._canonical),
        ];

  final Factory factory;
  final List<(Type, Manage)> inputs;

  @override
  late final int hashCode = Object.hash(factory, Object.hashAll(inputs));

  @override
  bool operator ==(Object other) {
    if (other is! _FactoryBinding ||
        factory != other.factory ||
        inputs.length != other.inputs.length) return false;
    for (var i = 0; i < inputs.length; i++) {
      if (inputs[i] != other.inputs[i]) return false;
    }
    return true;
  }
}

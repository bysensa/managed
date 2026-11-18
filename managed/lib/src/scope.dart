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
    OnDispose<T>? onDispose,
  ) {
    final cache = _instances;
    if (cache == null && (onDispose == null || lifetimes.isEmpty)) {
      final value = factory();
      _Resolution.current?.check();
      onNewInstance?.call(value);
      _Resolution.current?.check();
      return value;
    }
    late final _Entry<T> entry;
    entry = _Entry<T>(lifetimes, onDispose, () {
      if (identical(cache?[key], entry)) cache?.remove(key);
    });
    final value = entry.build(factory);
    cache?[key] = entry;
    onNewInstance?.call(value);
    entry.checkActive();
    return value;
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

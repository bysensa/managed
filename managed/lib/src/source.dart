part of '../managed.dart';

/// A [Manage] whose value is supplied by the application, e.g. a login session.
class ManageSource<T extends Object> extends Manage<T> {
  ManageSource._(this._state) : super(_state.read);

  final _SourceState<T> _state;

  /// Publishes [next] immediately. A change of identity also evicts all live
  /// dependents. Await the result to wait for their disposal.
  Future<void> set(T next) {
    final previous = _state.current;
    if (previous != null && _state.sameIdentity(previous.value, next)) {
      previous.value = next;
      return Future.value();
    }
    return _state.changes.invalidate(publish: () {
      final dispose = _state.onDispose;
      _state.current =
          _Entry.ready(next, {if (dispose != null) _state.changes}, dispose);
    });
  }

  /// Makes this source unavailable and releases its dependents.
  Future<void> clear() {
    _state.current = null;
    return _state.changes.invalidate();
  }

  @override
  void _collectLifetimes(Set<_Lifetime> result, Set<Manage> visited) {
    // Verify availability before a consumer allocates any of its other inputs.
    _state.read();
    result.add(_state.changes);
  }
}

class _SourceState<T extends Object> {
  _SourceState(this.sameIdentity, this.onDispose);

  final bool Function(T previous, T next) sameIdentity;
  final OnDispose<T>? onDispose;
  final changes = _Lifetime();
  _Entry<T>? current;

  T read() =>
      current?.value ?? (throw StateError('No active value for source $T.'));
}

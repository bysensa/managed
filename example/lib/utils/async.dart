import 'package:async/async.dart' hide Result;
import 'package:oxidized/oxidized.dart';

typedef AsyncFactory<T> = Future<T> Function();
typedef AsyncResult<T extends Object> = Result<T, AsyncFactoryException>;

class Async<T extends Object> {
  final AsyncFactory<T> _factory;
  var _memoizer = AsyncMemoizer<T>();

  Async(this._factory);

  Future<T> _call() async {
    try {
      return await _memoizer.runOnce(_factory);
    } catch (err, trace) {
      throw AsyncFactoryException(err, trace);
    }
  }

  Future<AsyncResult<T>> get instance => Result.asyncOf(_call);

  void reset() {
    _memoizer = AsyncMemoizer();
  }
}

class AsyncFactoryException implements Exception {
  final Object internalError;
  final StackTrace trace;

  AsyncFactoryException(this.internalError, this.trace);

  @override
  String toString() {
    return 'AsyncFactoryException: caught $internalError';
  }
}

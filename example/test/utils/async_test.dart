import 'package:example/utils/async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oxidized/oxidized.dart';

class TestValue {}

void main() {
  test('should call factory only once', () async {
    var callCount = 0;
    final asyncClass = Async(() async {
      callCount += 1;
      return TestValue();
    });
    asyncClass.instance;
    expect(callCount, 1);
    asyncClass.instance;
    expect(callCount, 1);
  });
  test('should call factory twice if reset', () async {
    var callCount = 0;
    final asyncClass = Async(() async {
      callCount += 1;
      return TestValue();
    });
    asyncClass.instance;
    expect(callCount, 1);
    asyncClass.instance;
    expect(callCount, 1);
    asyncClass.reset();
    asyncClass.instance;
    expect(callCount, 2);
  });

  test('should return Ok', () async {
    final asyncClass = Async(() async {
      return TestValue();
    });
    expect(await asyncClass.instance, isA<Ok>());
  });

  test('should return Err', () async {
    final asyncClass = Async(() async {
      throw StateError('test error');
    });
    expect(await asyncClass.instance, isA<Err>());
  });

  test('should wrap Error in AsyncFactoryException', () async {
    final asyncClass = Async(() async {
      throw StateError('test error');
    });
    expect(await asyncClass.instance, isA<Err>());
    expect(await asyncClass.instance.unwrapErr(), isA<AsyncFactoryException>());
    expect(
      await asyncClass.instance.mapErr((err) => err.internalError).unwrapErr(),
      isA<StateError>(),
    );
  });

  test('should wrap Exception in AsyncFactoryException', () async {
    final asyncClass = Async(() async {
      throw Exception('test error');
    });
    expect(await asyncClass.instance, isA<Err>());
    expect(await asyncClass.instance.unwrapErr(), isA<AsyncFactoryException>());
    expect(
      await asyncClass.instance.mapErr((err) => err.internalError).unwrapErr(),
      isA<Exception>(),
    );
  });
}

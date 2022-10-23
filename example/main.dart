import 'dart:convert';
import 'dart:io';

import 'package:managed/managed.dart';

Future<void> main() async {
  /// Create instance of module to initialize all dependencies
  ExampleModule();
  final controller = Controller();
  print(await controller.fact());
  controller.increment();
  print(await controller.fact());
  controller.decrement();
  print(await controller.fact());
}

class Controller with Managed {
  var _count = 0;

  /// provider function for NumberServiceInstance
  T _service<T extends NumberFactService>();

  void increment() {
    _count += 1;
  }

  void decrement() {
    _count -= 1;
  }

  Future<String> fact() async {
    /// use NumberFactService to get fact
    return await _service().numberFact(_count);
  }
}

class NumberFactService with Managed {
  /// provider function for HttpClient
  T _client<T extends HttpClient>();

  Future<String> numberFact(int number) async {
    try {
      /// use HttpClient to request Numbers API
      HttpClientRequest request =
          await _client().getUrl(Uri.parse('http://numbersapi.com/$number'));

      HttpClientResponse response = await request.close();

      final stringData = await response.transform(utf8.decoder).join();
      return stringData;
    } catch (err, _) {
      print(err);
      rethrow;
    }
  }
}

class ExampleModule extends Module {
  ExampleModule() : super({exampleService});

  /// register HttpClient for singleton scope
  static final client = Manage(
    HttpClient.new,
    scope: Scope.singleton,
  );

  /// register NumberFactService for singleton scope and mark it depends on client
  static final exampleService = Manage(
    NumberFactService.new,
    scope: Scope.singleton,
    dependsOn: [client],
  );
}

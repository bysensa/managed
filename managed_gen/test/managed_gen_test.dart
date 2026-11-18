import 'package:build_test/build_test.dart';
import 'package:managed_gen/managed_gen.dart';
import 'package:managed_gen/src/extensions/spec.extension.dart';
import 'package:managed_gen/src/producers/extended.manage.producer.dart';
import 'package:managed_gen/src/producers/params.producer.dart';
import 'package:managed_gen/src/producers/provider.producer.dart';
import 'package:managed_gen/src/visitor.dart';
import 'package:test/test.dart';

extension NullableExt<T> on T? {
  Type get nonNullableType => T;
}

class Some {}

void main() {
  test('should visit', () async {
    final visitor = ManagedTypeCollector();
    final mock = 'managed_gen|test/_files/simple.dart';
    final lib = await resolveSources(
      {
        mock: useAssetReader,
      },
      (resolver) => resolver.findLibraryByName('example'),
      resolverFor: mock,
    );
    final cls = lib!.getClass('Boo')!;
    cls.visitChildren(visitor);
    print(visitor.managedTypes);
  });

  test('should provide', () async {
    final _ = ManagedTypeCollector();
    final mock = 'managed_gen|test/_files/simple.dart';
    final lib = await resolveSources(
      {
        mock: useAssetReader,
      },
      (resolver) => resolver.findLibraryByName('example'),
      resolverFor: mock,
    );
    final cls = lib!.getClass('Boo')!;
    final extendedManageProd = ExtendedManageProducer(managedType: cls);
    final paramsProd = ParamsProducer(managedType: cls);
    final prod = ProviderProducer(managedType: cls);

    print(extendedManageProd.produce().formattedString());
    print(paramsProd.produce().formattedString());
    expect(prod.produce().formattedString(), contains('super.call(params)'));
    final cached = ProviderProducer(managedType: lib.getClass('Cached')!);
    expect(cached.produce().formattedString(),
        contains('super.call(CachedProvider.params!)'));
  });
}

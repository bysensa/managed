import 'dart:async';
import 'package:managed/managed.dart';
import 'dart:core';
import 'markdown.dart';
// **************************************************************************
// ManagedGenerator
// **************************************************************************





class ManageMarkdownStyle = Manage<MarkdownStyle> with MarkdownStyleProvider;


class MarkdownStyleParams extends Params {
  MarkdownStyleParams({required this.headingPrefix});

  final String headingPrefix;

  @override
  Type get targetType => MarkdownStyle;

  @override
  void inject(
    ZoneValues values,
    Map<Type, Manage> dependencies,
  ) {
    values[#headingPrefix] = headingPrefix;
  }
}


mixin MarkdownStyleProvider on Manage<MarkdownStyle> {
  static final _provider = ManageMarkdownStyle(
    _managed,
    scope: ScopeType.cached,
    dependsOn: [],
  );

  static MarkdownStyleParams? params;

  static Manage<MarkdownStyle> get provider {
    return _provider;
  }

  static MarkdownStyle _managed() {
    final zone = Zone.current;
    return MarkdownStyle(headingPrefix: zone[#headingPrefix]);
  }

  @override
  MarkdownStyle call([covariant MarkdownStyleParams? params]) =>
      super.call(MarkdownStyleProvider.params!);
}





class ManageMarkdownHeading = Manage<MarkdownHeading>
    with MarkdownHeadingProvider;


class MarkdownHeadingParams extends Params {
  MarkdownHeadingParams({required this.title});

  final String title;

  @override
  Type get targetType => MarkdownHeading;

  @override
  void inject(
    ZoneValues values,
    Map<Type, Manage> dependencies,
  ) {
    values[#title] = title;
  }
}


mixin MarkdownHeadingProvider on Manage<MarkdownHeading> {
  static final _provider = ManageMarkdownHeading(
    _managed,
    scope: ScopeType.unique,
    dependsOn: [],
  );

  static Manage<MarkdownHeading> get provider {
    return _provider;
  }

  static MarkdownHeading _managed() {
    final zone = Zone.current;
    return MarkdownHeading(zone[#title]);
  }

  @override
  MarkdownHeading call([covariant MarkdownHeadingParams? params]) =>
      super.call(params);
}





class ManageMarkdownTemplate = Manage<MarkdownTemplate>
    with MarkdownTemplateProvider;


class MarkdownTemplateParams extends Params {
  MarkdownTemplateParams({
    required this.heading,
    required this.includeAuthor,
  });

  final MarkdownHeadingParams heading;

  final bool includeAuthor;

  @override
  Type get targetType => MarkdownTemplate;

  @override
  void inject(
    ZoneValues values,
    Map<Type, Manage> dependencies,
  ) {
    values[heading.targetType] =
        dependencies.remove(heading.targetType)?.call(heading);
    values[#includeAuthor] = includeAuthor;
  }
}


mixin MarkdownTemplateProvider on Manage<MarkdownTemplate> {
  static final _provider = ManageMarkdownTemplate(
    _managed,
    scope: ScopeType.unique,
    dependsOn: [
      MarkdownStyleProvider.provider,
      MarkdownHeadingProvider.provider,
    ],
  );

  static Manage<MarkdownTemplate> get provider {
    assert(MarkdownStyleProvider.params != null, "");
    return _provider;
  }

  static MarkdownTemplate _managed() {
    final zone = Zone.current;
    return MarkdownTemplate(
      Manage.resolve(),
      Manage.resolve(),
      includeAuthor: zone[#includeAuthor],
    );
  }

  @override
  MarkdownTemplate call([covariant MarkdownTemplateParams? params]) =>
      super.call(params);
}

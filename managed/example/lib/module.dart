// GENERATED CODE - DO NOT MODIFY BY HAND
import "dart:core" as _core;
import "dart:async" as _async;
import "package:managed/codegen.dart" as _m;
import "package:managed_notebook_example/markdown.dart" as _i1;

class _RequiredParams extends _m.Params {
  _RequiredParams(this.targetType, this.name);
  @_core.override
  final _core.Type targetType;
  final _core.String name;
  @_core.override
  void inject(
      _m.ZoneValues values, _core.Map<_core.Type, _m.Manage> dependencies) {
    throw _core.StateError('Provide $name when constructing $targetType.');
  }
}

class ManageMarkdownHeading = _m.Manage<_i1.MarkdownHeading>
    with MarkdownHeadingProvider;

class MarkdownHeadingParams extends _m.Params {
  MarkdownHeadingParams({required this.title});
  final _core.String title;
  @_core.override
  _core.Type get targetType => _i1.MarkdownHeading;
  @_core.override
  void inject(
      _m.ZoneValues values, _core.Map<_core.Type, _m.Manage> dependencies) {
    values[#title] = this.title;
    values[MarkdownHeadingParams] = () => _i1.MarkdownHeading(this.title);
  }
}

mixin MarkdownHeadingProvider on _m.Manage<_i1.MarkdownHeading> {
  static final ManageMarkdownHeading provider = register();
  MarkdownHeadingParams? _defaults;
  static ManageMarkdownHeading register(
          {MarkdownHeadingParams? params,
          _core.List<_m.Manage> dependsOn = const [],
          _m.OnNewInstance<_i1.MarkdownHeading>? onNewInstance,
          _m.OnDispose<_i1.MarkdownHeading>? onDispose,
          _core.Object? resolutionKey}) =>
      ManageMarkdownHeading(_managed,
          scope: _m.ScopeType.unique,
          dependsOn: dependsOn,
          onNewInstance: onNewInstance,
          onDispose: onDispose,
          resolutionKey: resolutionKey)
        .._defaults = params;
  static _i1.MarkdownHeading _managed() =>
      (_async.Zone.current[MarkdownHeadingParams] as _i1.MarkdownHeading
          Function())();
  @_core.override
  _i1.MarkdownHeading call([MarkdownHeadingParams? params]) =>
      this.callWithParams(params ??
          this._defaults ??
          _RequiredParams(_i1.MarkdownHeading, "MarkdownHeadingParams"));
}

class ManageMarkdownStyle = _m.Manage<_i1.MarkdownStyle>
    with MarkdownStyleProvider;

class MarkdownStyleParams extends _m.Params {
  MarkdownStyleParams({required this.headingPrefix});
  final _core.String headingPrefix;
  @_core.override
  _core.Type get targetType => _i1.MarkdownStyle;
  @_core.override
  void inject(
      _m.ZoneValues values, _core.Map<_core.Type, _m.Manage> dependencies) {
    values[#headingPrefix] = this.headingPrefix;
    values[MarkdownStyleParams] =
        () => _i1.MarkdownStyle(headingPrefix: this.headingPrefix);
  }
}

mixin MarkdownStyleProvider on _m.Manage<_i1.MarkdownStyle> {
  static final ManageMarkdownStyle provider = register();
  static MarkdownStyleParams? params;
  MarkdownStyleParams? _defaults;
  static ManageMarkdownStyle register(
          {MarkdownStyleParams? params,
          _core.List<_m.Manage> dependsOn = const [],
          _m.OnNewInstance<_i1.MarkdownStyle>? onNewInstance,
          _m.OnDispose<_i1.MarkdownStyle>? onDispose,
          _core.Object? resolutionKey}) =>
      ManageMarkdownStyle(_managed,
          scope: _m.ScopeType.cached,
          dependsOn: dependsOn,
          onNewInstance: onNewInstance,
          onDispose: onDispose,
          resolutionKey: resolutionKey)
        .._defaults = params;
  static _i1.MarkdownStyle _managed() =>
      (_async.Zone.current[MarkdownStyleParams] as _i1.MarkdownStyle
          Function())();
  @_core.override
  _i1.MarkdownStyle call([MarkdownStyleParams? params]) =>
      this.callWithParams(params ??
          _defaults ??
          MarkdownStyleProvider.params ??
          _RequiredParams(_i1.MarkdownStyle, "MarkdownStyleParams"));
}

class ManageMarkdownTemplate = _m.Manage<_i1.MarkdownTemplate>
    with MarkdownTemplateProvider;

class MarkdownTemplateParams extends _m.Params {
  MarkdownTemplateParams({this.heading, required this.includeAuthor});
  final MarkdownHeadingParams? heading;
  final _core.bool includeAuthor;
  @_core.override
  _core.Type get targetType => _i1.MarkdownTemplate;
  @_core.override
  void inject(
      _m.ZoneValues values, _core.Map<_core.Type, _m.Manage> dependencies) {
    final _input0 = dependencies[_i1.MarkdownStyle]!.callWithParams(null)
        as _i1.MarkdownStyle;
    values[_i1.MarkdownStyle] = _input0;
    final _input1 = dependencies[_i1.MarkdownHeading]!
        .callWithParams(this.heading) as _i1.MarkdownHeading;
    values[_i1.MarkdownHeading] = _input1;
    values[#includeAuthor] = this.includeAuthor;
    dependencies.remove(_i1.MarkdownStyle);
    dependencies.remove(_i1.MarkdownHeading);
    values[MarkdownTemplateParams] = () => _i1.MarkdownTemplate(
        _input0, _input1,
        includeAuthor: this.includeAuthor);
  }
}

mixin MarkdownTemplateProvider on _m.Manage<_i1.MarkdownTemplate> {
  static final ManageMarkdownTemplate provider = register();
  MarkdownTemplateParams? _defaults;
  static ManageMarkdownTemplate register(
          {MarkdownTemplateParams? params,
          _core.List<_m.Manage> dependsOn = const [],
          _m.OnNewInstance<_i1.MarkdownTemplate>? onNewInstance,
          _m.OnDispose<_i1.MarkdownTemplate>? onDispose,
          _core.Object? resolutionKey}) =>
      ManageMarkdownTemplate(_managed,
          scope: _m.ScopeType.unique,
          dependsOn: [
            for (final dep in <_m.Manage>[
              MarkdownStyleProvider.provider,
              MarkdownHeadingProvider.provider
            ])
              if (!dependsOn.any((d) => d.managedType == dep.managedType)) dep,
            ...dependsOn
          ],
          onNewInstance: onNewInstance,
          onDispose: onDispose,
          resolutionKey: resolutionKey)
        .._defaults = params;
  static _i1.MarkdownTemplate _managed() =>
      (_async.Zone.current[MarkdownTemplateParams] as _i1.MarkdownTemplate
          Function())();
  @_core.override
  _i1.MarkdownTemplate call([MarkdownTemplateParams? params]) =>
      this.callWithParams(params ??
          this._defaults ??
          _RequiredParams(_i1.MarkdownTemplate, "MarkdownTemplateParams"));
}

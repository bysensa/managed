import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'reduce_rebuild.dart';

typedef ComponentActionInvokeHandler<T extends Intent> = Object? Function(T,
    [BuildContext?]);
typedef ComponentActionPredicate<T extends Intent> = bool Function(T);

abstract class Component<S extends StatefulWidget> = State<S>
    with ComponentMixin;

mixin ComponentMixin<T extends StatefulWidget> on State<T> {
  final _actions = _ComponentActions();

  ValueListenable<Map<Type, Action<Intent>>> get actions => _actions;

  ComponentAction<I> action<I extends Intent>(
    ComponentActionInvokeHandler<I> handler, {
    ComponentActionPredicate<I>? consumesKeyPredicate,
    ComponentActionPredicate<I>? isEnabledPredicate,
  }) {
    final newAction = ComponentAction<I>(
      handler: handler,
      consumesKeyPredicate: consumesKeyPredicate,
      isEnabledPredicate: isEnabledPredicate,
    );
    _actions[newAction.intentType] = newAction;
    return newAction;
  }

  void addAction(ComponentAction action) {
    _actions[action.intentType] = action;
  }

  bool removeAction(ComponentAction action) {
    final removedAction = _actions.remove(action.intentType);
    return removedAction != null;
  }
}

class ComponentAction<T extends Intent> extends ContextAction<T> {
  final ComponentActionInvokeHandler<T> _handler;
  final ComponentActionPredicate<T>? _consumesKeyPredicate;
  final ComponentActionPredicate<T>? _isEnabledPredicate;
  bool _isEnabled = true;
  bool _consumesKey = true;

  ComponentAction({
    required Object? Function(T, [BuildContext?]) handler,
    bool Function(T)? consumesKeyPredicate,
    bool Function(T)? isEnabledPredicate,
  })  : _handler = handler,
        _consumesKeyPredicate = consumesKeyPredicate,
        _isEnabledPredicate = isEnabledPredicate;

  @override
  bool get isActionEnabled => _isEnabled;

  void enable() {
    _isEnabled = true;
    notifyActionListeners();
  }

  void disable() {
    _isEnabled = false;
    notifyActionListeners();
  }

  void toggle() {
    _isEnabled = !_isEnabled;
    notifyActionListeners();
  }

  void enableKeyConsume() {
    _consumesKey = true;
    notifyActionListeners();
  }

  void disableKeyConsume() {
    _consumesKey = false;
    notifyActionListeners();
  }

  void toggleKeyConsume() {
    _consumesKey = !_consumesKey;
    notifyActionListeners();
  }

  @override
  bool isEnabled(T intent) {
    if (_isEnabledPredicate == null) {
      return _isEnabled;
    }
    return _isEnabled && _isEnabledPredicate!(intent);
  }

  @override
  bool consumesKey(T intent) {
    if (_consumesKeyPredicate == null) {
      return _consumesKey;
    }
    return _consumesKey && _consumesKeyPredicate!(intent);
  }

  @override
  Object? invoke(T intent, [BuildContext? context]) =>
      _handler(intent, context);
}

class _ComponentActions extends MapBase<Type, Action>
    with ChangeNotifier
    implements ValueListenable<Map<Type, Action>> {
  final _internal = <Type, Action>{};

  @override
  Map<Type, Action<Intent>> get value => UnmodifiableMapView(_internal);

  @override
  Action<Intent>? operator [](Object? key) {
    return _internal[key];
  }

  @override
  void operator []=(Type key, Action<Intent> value) {
    assert(
      !_internal.containsKey(key),
      'Action for intent $key already present',
    );
    _internal[key] = value;
    notifyListeners();
  }

  @override
  void clear() {
    _internal.clear();
    notifyListeners();
  }

  @override
  Iterable<Type> get keys => _internal.keys;

  @override
  Action<Intent>? remove(Object? key) {
    final removedValue = _internal.remove(key);
    if (removedValue != null) {
      notifyListeners();
    }
    return removedValue;
  }
}

/// Widget delegate intent invocation to component.
///
/// Example:
///
/// ```dart
/// class IntentWithCommonHandler extends Intent {}
/// class ExampleIntent extends Intent {}
///
/// class ExampleComponent extends StatefulWidget {
///   const ExampleComponent({Key? key}) : super(key: key);
///
///   @override
///   State<ExampleComponent> createState() => _ExampleComponentState();
/// }
///
/// class _ExampleComponentState extends State<ExampleComponent>
///     with FlateComponentMixin {
///
///   @override
///   void registerIntents(IntentRegistration registration) {
///     registration.registerWithCallback(onExampleIntent);
///   }
///
///   void onExampleIntent(ExampleIntent intent, [BuildContext? context]) {}
///
///
///   @override
///   void invoke(Intent intent, [BuildContext? context]) {
///     if (intent is IntentWithCommonHandler) {
///       // do something here
///     }
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return FlateComponentActions(
///       component: this,
///       child: Container(),
///     );
///   }
/// }
/// ```
class ComponentActions extends StatelessReduceRebuildWidget {
  final ComponentMixin component;
  final ActionDispatcher? actionDispatcher;
  final Widget child;
  final bool reduceRebuilds;

  const ComponentActions({
    required this.component,
    required this.child,
    this.actionDispatcher,
    this.reduceRebuilds = false,
    Key? key,
  }) : super(key: key);

  @override
  bool shouldNotRebuild(covariant ComponentActions newWidget) {
    return newWidget.reduceRebuilds &&
        component == newWidget.component &&
        actionDispatcher == newWidget.actionDispatcher &&
        key == newWidget.key;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<Type, Action<Intent>>>(
      valueListenable: component.actions,
      builder: (context, value, child) => Actions(
        actions: value,
        dispatcher: actionDispatcher,
        child: child!,
      ),
      child: child,
    );
  }
}

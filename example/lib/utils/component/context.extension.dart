import 'package:flutter/widgets.dart';

/// Extension for [BuildContext] used to simplify some operations with [Intent] or [Notification].
extension BuildContextExtension on BuildContext {
  /// Returns a [VoidCallback] handler that invokes the bound action for the given [Intent]
  /// If the action is enabled, and returns null if the action is not enabled, or no matching action is found.
  ///
  /// This is intended to be used in widgets which have something similar to an onTap handler,
  /// which takes a VoidCallback, and can be set to the result of calling this function.
  ///
  /// Example:
  /// ```dart
  /// VoidCallback? handler = context.handler(SomeIntent());
  /// ```
  VoidCallback? handler<T extends Intent>(T intent) =>
      Actions.handler(this, intent);

  /// Finds the Action bound to the given intent type T in the given context.
  ///
  /// Creates a dependency on the Actions widget that maps the bound action so that
  /// if the actions change, the context will be rebuilt and find the updated action.
  /// The [intent] argument supplies the type of the intent to look for action.
  /// If no Actions widget surrounds the given context, this function will assert in debug mode,
  /// and throw an exception in release mode.
  ///
  /// Example:
  /// ```dart
  /// Action<SomeIntent> action = context.findAction(SomeIntent());
  /// ```
  Action<T> findAction<T extends Intent>(T intent) =>
      Actions.find(this, intent: intent);

  /// Finds the Action bound to the given intent type T in the given context.
  ///
  /// Creates a dependency on the Actions widget that maps the bound action
  /// so that if the actions change, the context will be rebuilt and find the updated action.
  /// The [intent] argument supplies the type of the intent to look for.
  /// If no Actions widget surrounds the given context, this function will return null.
  ///
  /// Example:
  /// ```dart
  /// Action<SomeIntent>? maybeAction = context.maybeFindAction(SomeIntent());
  /// ```
  Action<T>? maybeFindAction<T extends Intent>(T intent) =>
      Actions.maybeFind(this, intent: intent);

  /// Invokes the action associated with the given [Intent] using the [Actions]
  /// widget that most tightly encloses the given [BuildContext].
  ///
  /// This method returns the result of invoking the action's [Action.invoke] method.
  /// If the given [intent] doesn't map to an action, then it will look to the next ancestor Actions widget
  /// in the hierarchy until it reaches the root. This method will throw an exception
  /// if no ambient Actions widget is found, or when a suitable Action is found
  /// but it returns false for Action.isEnabled.
  ///
  /// Example:
  /// ```dart
  /// Object? maybeResult = context.invoke(SomeIntent());
  /// ```
  Object? invoke<T extends Intent>(T intent) => Actions.invoke(this, intent);

  /// Invokes the action associated with the given [Intent] using the [Actions] widget
  /// that most tightly encloses the given [BuildContext].
  ///
  /// This method returns the result of invoking the action's [Action.invoke] method.
  /// If no action mapping was found for the specified intent, or if the first action found was disabled,
  /// or the action itself returns null from [Action.invoke], then this method returns null.
  /// If the given [intent] doesn't map to an action, then it will look to the next ancestor
  /// Actions widget in the hierarchy until it reaches the root. If a suitable Action is found
  /// but its Action.isEnabled returns false, the search will stop and this method will return null.
  ///
  /// Example:
  /// ```dart
  /// Object? maybeResult = context.maybeInvoke(SomeIntent());
  /// ```
  Object? maybeInvoke<T extends Intent>(T intent) =>
      Actions.maybeInvoke(this, intent);

  /// Start bubbling this [notification] at the given build context.
  ///
  /// The notification will be delivered to any [NotificationListener] widgets with
  /// the appropriate type parameters that are ancestors of the given [BuildContext].
  void dispatch(Notification notification) => notification.dispatch(this);
}

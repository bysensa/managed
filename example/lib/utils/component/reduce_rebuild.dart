import 'package:flutter/widgets.dart';

mixin ReduceRebuildMixin on StatelessWidget {
  @protected
  bool shouldNotRebuild(covariant Widget newWidget) => false;
}

mixin ReduceRebuildElementMixin on StatelessElement {
  bool _shouldNotRebuild = false;
  Widget? _oldChildWidget;

  @override
  void update(covariant StatelessWidget newWidget) {
    if (widget is ReduceRebuildMixin) {
      _shouldNotRebuild =
          (widget as ReduceRebuildMixin).shouldNotRebuild(newWidget);
    }
    super.update(newWidget);
  }

  @override
  void deactivate() {
    _dropCachedWidget();
    super.deactivate();
  }

  @override
  void didChangeDependencies() {
    _dropCachedWidget();
    super.didChangeDependencies();
  }

  @override
  void reassemble() {
    _dropCachedWidget();
    super.reassemble();
  }

  void _dropCachedWidget() {
    _oldChildWidget = null;
    _shouldNotRebuild = false;
  }

  @override
  void unmount() {
    _dropCachedWidget();
    super.unmount();
  }

  Widget _maybeBuild(ValueGetter<Widget> builder) {
    if (_oldChildWidget == null || !_shouldNotRebuild) {
      _oldChildWidget = builder();
      _shouldNotRebuild = false;
    }

    return _oldChildWidget!;
  }
}

abstract class StatelessReduceRebuildWidget extends StatelessWidget
    with ReduceRebuildMixin {
  const StatelessReduceRebuildWidget({Key? key}) : super(key: key);

  @override
  StatelessElement createElement() => StatelessReduceRebuildElement(this);
}

class StatelessReduceRebuildElement extends StatelessElement
    with ReduceRebuildElementMixin {
  StatelessReduceRebuildElement(StatelessReduceRebuildWidget widget)
      : super(widget);

  @override
  Widget build() {
    return _maybeBuild(super.build);
  }
}

class ReduceRebuild extends StatelessReduceRebuildWidget {
  final ValueGetter<bool> predicate;
  final Widget child;

  const ReduceRebuild({
    required this.predicate,
    required this.child,
    Key? key,
  }) : super(key: key);

  @override
  bool shouldNotRebuild(covariant Widget newWidget) => predicate();

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

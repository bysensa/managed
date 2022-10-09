import 'package:example/module.dart';
import 'package:example/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:managed/managed.dart';
import 'package:mobx/mobx.dart' hide action;

import '../infrastructure/calendar.dart';

class RequestPermissionsIntent extends Intent {}

class PermissionCheck extends StatefulWidget {
  final Widget? child;

  const PermissionCheck({
    Key? key,
    this.child,
  }) : super(key: key);

  @override
  State<PermissionCheck> createState() => _PermissionCheckState();
}

class _PermissionCheckState extends Component<PermissionCheck> with Managed {
  @override
  final dependsOn = {AppModule.calendarApi};

  late final ObservableFuture<bool> _hasPermissions;

  T calendarApi<T extends CalendarApi>();

  @override
  void initState() {
    super.initState();
    action(_onRequestPermissions);
    _hasPermissions = ObservableFuture(calendarApi().hasAccess());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _onRequestPermissions(
    RequestPermissionsIntent intent, [
    BuildContext? context,
  ]) async {
    await calendarApi().requestPermissions();
    _hasPermissions.replace(calendarApi().hasAccess());
  }

  @override
  Widget build(BuildContext context) {
    return ComponentActions(
      component: this,
      child: _Layout(
        hasPermissions: _hasPermissions,
        child: widget.child,
      ),
    );
  }
}

class _Layout extends StatelessObserverWidget {
  final Widget? child;
  final ObservableValue<bool?> hasPermissions;

  const _Layout({
    required this.hasPermissions,
    this.child,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasPermissionsValue = hasPermissions.value;
    if (hasPermissionsValue == null) {
      return const _Loader();
    }
    if (hasPermissionsValue) {
      return child ?? const _Loader();
    }
    return const _NoPermissionsView(
      requestPermissionsButton: _RequestPermissionsButton(),
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CupertinoActivityIndicator(),
    );
  }
}

class _NoPermissionsView extends StatelessWidget {
  final Widget requestPermissionsButton;

  const _NoPermissionsView({
    Key? key,
    required this.requestPermissionsButton,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Column(
        children: [
          const Expanded(
            child: SizedBox.expand(),
          ),
          requestPermissionsButton,
        ],
      ),
    );
  }
}

class _RequestPermissionsButton extends StatelessWidget {
  const _RequestPermissionsButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoButton.filled(
      onPressed: context.handler(RequestPermissionsIntent()),
      child: const Text('Request Permissions'),
    );
  }
}

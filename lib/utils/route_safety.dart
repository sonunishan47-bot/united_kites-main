import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Wait until modal routes have finished the current (and next) frame.
Future<void> waitForOverlaySettle() async {
  final binding = SchedulerBinding.instance;
  await binding.endOfFrame;
  await binding.endOfFrame;
}

/// Run [fn] on the next frame if [context] is still mounted.
void afterRouteFrame(BuildContext context, VoidCallback fn) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    fn();
  });
}

/// Pop only after the current frame so InheritedNotifier dependents can detach.
void popAfterFrame<T>(BuildContext context, [T? result]) {
  if (!context.mounted) return;
  final navigator = Navigator.of(context);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    navigator.pop(result);
  });
}

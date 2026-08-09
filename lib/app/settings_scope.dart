import 'package:flutter/widgets.dart';

import '../services/settings_service.dart';

/// Provides the app-wide [SettingsService] to the widget tree.
///
/// Using an [InheritedNotifier] means any widget that calls [of] rebuilds
/// whenever a setting changes, and the single service instance is shared across
/// screens (no duplicate state).
class SettingsScope extends InheritedNotifier<SettingsService> {
  const SettingsScope({
    super.key,
    required SettingsService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [SettingsService], registering a rebuild dependency.
  static SettingsService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope found in context');
    return scope!.notifier!;
  }
}

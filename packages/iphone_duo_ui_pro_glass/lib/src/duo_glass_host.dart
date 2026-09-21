// Wires iphone_duo_ui_pro and adaptive_platform_ui around the navigator.

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:iphone_duo_ui_pro/iphone_duo_ui_pro.dart';

import 'duo_glass_scaffold.dart';

/// Installs everything both packages need above the navigator, in the order
/// that makes them work together:
///
/// 1. [DuoScope] streams the native bridge into the tree,
/// 2. [DuoDisplayFeatures] republishes the fold, so routes, [FoldAwareTwoPane]
///    and [FoldAlignedGrid] see it,
/// 3. [AdaptiveToolbarHost] draws the one fixed Liquid Glass toolbar, and on
///    iPhone Duo the vertical bar with the tab bar at the bottom of it.
///
/// It also decides the [DuoGlassPose] once, from the padding of the window,
/// for every [DuoGlassScaffold] below; see [poseOf].
///
/// Put it in the app `builder`:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => DuoGlassHost(child: child!),
///   home: const HomeScreen(),
/// );
/// ```
///
/// `AdaptiveApp` installs its own toolbar host, so switch ours off there:
///
/// ```dart
/// AdaptiveApp(
///   builder: (context, child) =>
///       DuoGlassHost(installToolbarHost: false, child: child!),
///   home: const HomeScreen(),
/// );
/// ```
class DuoGlassHost extends StatelessWidget {
  /// Creates the host.
  const DuoGlassHost({
    super.key,
    required this.child,
    this.installToolbarHost = true,
    this.environment,
    this.includeOcclusions = true,
  });

  /// The navigator, as the app `builder` receives it.
  final Widget child;

  /// Whether to wrap [child] in an [AdaptiveToolbarHost]. Pass false under
  /// `AdaptiveApp`, which installs one itself.
  final bool installToolbarHost;

  /// A fixed environment for tests and previews; see [DuoScope.environment].
  final DuoEnvironment? environment;

  /// Whether the under-display camera is published as a `cutout`; see
  /// [DuoDisplayFeatures.includeOcclusions].
  final bool includeOcclusions;

  /// The pose of the bars, as the nearest [DuoGlassHost] decided it.
  ///
  /// The host reads the padding where adaptive_platform_ui's own host reads
  /// it, above the navigator, so both always agree. A page cannot work it out
  /// for itself: inside a scaffold the top of `viewPadding` already includes
  /// the title band. Without a host the padding in [context] is used.
  static DuoGlassPose poseOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DuoGlassPoseScope>()?.pose ??
      DuoGlassPose.forViewPadding(MediaQuery.viewPaddingOf(context));

  @override
  Widget build(BuildContext context) {
    return DuoScope(
      environment: environment,
      child: DuoDisplayFeatures(
        includeOcclusions: includeOcclusions,
        child: _DuoGlassPoseScope(
          pose: DuoGlassPose.forViewPadding(MediaQuery.viewPaddingOf(context)),
          child: installToolbarHost ? _hosted(context) : child,
        ),
      ),
    );
  }

  /// The toolbar host draws the iPhone Duo title itself, above the navigator.
  /// Under `MaterialApp` nothing up there sets a text style, so the title
  /// would pick up Flutter's fallback (red, underlined in yellow). Give it
  /// the style `CupertinoApp` puts above its own navigator.
  Widget _hosted(BuildContext context) {
    return DefaultTextStyle(
      style: CupertinoTheme.of(context).textTheme.textStyle,
      child: AdaptiveToolbarHost(child: child),
    );
  }
}

class _DuoGlassPoseScope extends InheritedWidget {
  const _DuoGlassPoseScope({required this.pose, required super.child});

  final DuoGlassPose pose;

  @override
  bool updateShouldNotify(_DuoGlassPoseScope oldWidget) =>
      oldWidget.pose != pose;
}

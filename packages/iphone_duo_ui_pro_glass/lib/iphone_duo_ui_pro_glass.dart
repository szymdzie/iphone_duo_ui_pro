/// Official Liquid Glass chrome for `iphone_duo_ui_pro`: the second of its two
/// modes for the bars. `DuoAdaptiveScaffold` (custom navigation, drawn by
/// Flutter) and [DuoGlassScaffold] (drawn by UIKit) take the same actions and
/// tabs, so a screen moves between the modes by changing one widget.
///
/// `iphone_duo_ui_pro` keeps the content off the fold; this companion hands the
/// bars to UIKit through `adaptive_platform_ui`. On iOS 26 and later the
/// toolbar, the tab bar and the capsules of the iPhone Duo vertical bar are
/// native views, so the glass is the system's own.
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => DuoGlassHost(child: child!),
///   home: DuoGlassScaffold(
///     title: 'Library',
///     tabs: tabs,
///     selectedTabIndex: index,
///     onTabSelected: select,
///     body: FoldAwareTwoPane(startPane: list, endPane: detail),
///   ),
/// );
/// ```
///
/// The core package is re-exported, so this import is the only one you need.
library;

export 'package:iphone_duo_ui_pro/iphone_duo_ui_pro.dart';

export 'src/duo_glass_host.dart';
export 'src/duo_glass_scaffold.dart';

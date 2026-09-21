/// Fold-aware Flutter widgets for iPhone Duo.
///
/// The package has two halves. A native iOS bridge reports what Flutter cannot
/// see on its own — reserved regions (the fold, the under-display camera),
/// UIKit size classes, the hinge and the vertical bar edge — and a set of
/// widgets turn that state into layout: [DuoDisplayFeatures] republishes the
/// fold as a `DisplayFeature`, [DuoAdaptiveScaffold] moves navigation into the
/// vertical bar, [FoldAwareTwoPane] and [FoldAlignedGrid] keep content off the
/// fold.
///
/// The bars come in two modes that take the same [DuoBarAction] and [DuoTab]
/// values. [DuoAdaptiveScaffold], in this package, is custom navigation: drawn
/// by Flutter, with no dependencies. `DuoGlassScaffold`, in the optional
/// companion `iphone_duo_ui_pro_glass`, hands them to UIKit as official Liquid
/// Glass.
///
/// Wrap the app once, then use the widgets anywhere below it:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => DuoScope(
///     child: DuoDisplayFeatures(child: child ?? const SizedBox.shrink()),
///   ),
///   home: const HomeScreen(),
/// );
/// ```
library;

export 'src/duo_adaptive_scaffold.dart';
export 'src/duo_display_features.dart';
export 'src/duo_environment.dart';
export 'src/fold_aligned_grid.dart';
export 'src/fold_aware_two_pane.dart';

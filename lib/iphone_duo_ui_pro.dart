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

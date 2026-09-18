// A tile grid aligned to the iPhone Duo fold (it works with folding Android devices too).
// Sources: Apple iPhone Duo Tech Talks and HIG - see README.md.
//
// Apple guidance (HIG "Designing for iPhone Duo", Tech Talk "Strike a pose with adaptive layouts"):
// * grids keep an even column count whenever a fold is in view, including when the device lies flat,
//   so folding does not rebuild the layout;
// * once folded, nothing interactive sits in the fold: outer margins stay put, the gap around the hinge
//   grows, and every tile stays inside its own region (the pattern from the Fitness app);
// * scrolling content is never displaced between regions; with a horizontal fold (tabletop pose)
//   the grid simply scrolls through it.
//
// An even column count (duoEvenColumns) is not enough when the content area is not centred on the fold,
// for example with a DuoAdaptiveScaffold vertical bar on one side: the middle gap then misses the fold.
// This grid lays columns out symmetrically around the centre of the fold.
//
// The fold comes from MediaQuery.displayFeatures: on iOS it is injected by DuoDisplayFeatures from the
// bridge's reserved regions, on Android Flutter fills it in itself.

import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A vertical fold in the grid's local horizontal coordinates, measured from its left edge.
/// An inactive fold (the device lies flat) has zero width.
@immutable
class GridFold {
  /// Creates a fold spanning [start] to [end].
  const GridFold({required this.start, required this.end})
    : assert(end >= start);

  /// Left edge of the fold, in the grid's local coordinates.
  final double start;

  /// Right edge of the fold, in the grid's local coordinates.
  final double end;

  /// Horizontal centre of the fold.
  double get center => (start + end) / 2;

  /// Width of the fold; zero for an inactive fold.
  double get width => end - start;

  @override
  bool operator ==(Object other) =>
      other is GridFold && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'GridFold($start–$end)';
}

/// A column plan: the left edge of every column (physically, from the left) and the shared tile width.
@immutable
class FoldAlignedColumns {
  /// Creates a column plan.
  const FoldAlignedColumns({required this.offsets, required this.tileWidth});

  /// Left edge of every column, from the left, in the grid's local coordinates.
  final List<double> offsets;

  /// Width shared by every tile.
  final double tileWidth;

  /// Number of columns.
  int get count => offsets.length;
}

/// Plans the columns of a grid [width] wide.
///
/// * Without a fold: as many columns as fit at [minTileWidth]; an even count when [evenColumns].
/// * With a vertical [fold] crossing the grid: `n` columns per side, symmetric around the centre of the
///   fold. The middle gap is [spacing] plus the fold width, so the grid looks uniform when flat and only
///   the gap at the hinge grows once folded. Neither `n` nor the outer edges of the grid depend on the
///   fold width, so folding changes neither the column count nor the margins.
///   The narrower side (the one with the vertical bar, say) sets `n` and the tile width; the wider side
///   gets a larger outer margin, so the grid is centred on the fold rather than on the content.
FoldAlignedColumns planFoldAlignedColumns({
  required double width,
  required double minTileWidth,
  double spacing = 12,
  double horizontalPadding = 16,
  GridFold? fold,
  bool evenColumns = false,
}) {
  assert(minTileWidth > 0);
  if (fold != null && fold.start > 0 && fold.end < width) {
    final center = fold.center;
    // A symmetric reach on both sides of the fold centre (from the centre to the outer margin).
    final sideExtent = math.min(
      center - horizontalPadding,
      width - horizontalPadding - center,
    );
    // Columns per side are computed for a zero-width fold, which keeps them stable while folding.
    final perSide =
        ((sideExtent - spacing / 2 + spacing) / (minTileWidth + spacing))
            .floor();
    if (perSide >= 1) {
      final gap = spacing + fold.width;
      final half = sideExtent - gap / 2;
      final tileWidth = math.max(
        0.0,
        (half - (perSide - 1) * spacing) / perSide,
      );
      final stride = tileWidth + spacing;
      final leftStart = center - sideExtent;
      final rightStart = center + gap / 2;
      return FoldAlignedColumns(
        offsets: List<double>.unmodifiable(<double>[
          for (var i = 0; i < perSide; i++) leftStart + i * stride,
          for (var i = 0; i < perSide; i++) rightStart + i * stride,
        ]),
        tileWidth: tileWidth,
      );
    }
  }

  // No fold in the grid, or a fold at its edge (Split View): a plain grid.
  final contentWidth = math.max(0.0, width - 2 * horizontalPadding);
  var count = math.max(
    1,
    ((contentWidth + spacing) / (minTileWidth + spacing)).floor(),
  );
  if (evenColumns && count > 1) {
    count -= count % 2;
  }
  final tileWidth = math.max(
    0.0,
    (contentWidth - (count - 1) * spacing) / count,
  );
  return FoldAlignedColumns(
    offsets: List<double>.unmodifiable(<double>[
      for (var i = 0; i < count; i++)
        horizontalPadding + i * (tileWidth + spacing),
    ]),
    tileWidth: tileWidth,
  );
}

/// A [SliverGridDelegate] built on [planFoldAlignedColumns]. Rows have a fixed [tileHeight].
class FoldAlignedGridDelegate extends SliverGridDelegate {
  /// Creates a delegate; [planFoldAlignedColumns] describes the rules.
  const FoldAlignedGridDelegate({
    required this.minTileWidth,
    required this.tileHeight,
    this.spacing = 12,
    this.horizontalPadding = 16,
    this.fold,
    this.evenColumns = false,
  });

  /// Smallest tile width, used to pick the column count.
  final double minTileWidth;

  /// Fixed height of every row.
  final double tileHeight;

  /// Gap between columns and between rows.
  final double spacing;

  /// Outer horizontal padding of the grid.
  final double horizontalPadding;

  /// A vertical fold crossing the grid, in the grid's local coordinates.
  final GridFold? fold;

  /// Whether to keep the column count even when no fold is in view.
  final bool evenColumns;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final columns = planFoldAlignedColumns(
      width: constraints.crossAxisExtent,
      minTileWidth: minTileWidth,
      spacing: spacing,
      horizontalPadding: horizontalPadding,
      fold: fold,
      evenColumns: evenColumns,
    );
    // In RTL the first column is on the right; column positions, and so the fold alignment, do not change.
    final reversed = axisDirectionIsReversed(constraints.crossAxisDirection);
    return _FoldAlignedGridLayout(
      offsets: reversed
          ? columns.offsets.reversed.toList(growable: false)
          : columns.offsets,
      tileWidth: columns.tileWidth,
      tileHeight: tileHeight,
      mainAxisStride: tileHeight + spacing,
    );
  }

  @override
  bool shouldRelayout(FoldAlignedGridDelegate oldDelegate) =>
      oldDelegate.minTileWidth != minTileWidth ||
      oldDelegate.tileHeight != tileHeight ||
      oldDelegate.spacing != spacing ||
      oldDelegate.horizontalPadding != horizontalPadding ||
      oldDelegate.fold != fold ||
      oldDelegate.evenColumns != evenColumns;
}

class _FoldAlignedGridLayout extends SliverGridLayout {
  const _FoldAlignedGridLayout({
    required this.offsets,
    required this.tileWidth,
    required this.tileHeight,
    required this.mainAxisStride,
  });

  final List<double> offsets;
  final double tileWidth;
  final double tileHeight;
  final double mainAxisStride;

  int get _columns => offsets.length;

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) =>
      mainAxisStride > precisionErrorTolerance
      ? _columns * (scrollOffset ~/ mainAxisStride)
      : 0;

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    if (mainAxisStride <= 0) return 0;
    final rows = (scrollOffset / mainAxisStride).ceil();
    return math.max(0, _columns * rows - 1);
  }

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) => SliverGridGeometry(
    scrollOffset: (index ~/ _columns) * mainAxisStride,
    crossAxisOffset: offsets[index % _columns],
    mainAxisExtent: tileHeight,
    crossAxisExtent: tileWidth,
  );

  @override
  double computeMaxScrollOffset(int childCount) {
    if (childCount == 0) return 0;
    final rows = ((childCount - 1) ~/ _columns) + 1;
    return mainAxisStride * rows - (mainAxisStride - tileHeight);
  }
}

/// A scrolling tile grid aligned to the fold (the rules live in [planFoldAlignedColumns]).
///
/// The fold from `MediaQuery.displayFeatures` is in window coordinates, so the widget measures its own
/// position on screen after each frame (like `FoldAwareTwoPane`) and converts the fold to local coordinates.
class FoldAlignedGrid extends StatefulWidget {
  /// Creates a fold-aligned grid.
  const FoldAlignedGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.tileHeight,
    this.minTileWidth = 104,
    this.spacing = 12,
    this.outerPadding = 16,
    this.controller,
  });

  /// Number of tiles.
  final int itemCount;

  /// Builds the tile at the given index.
  final IndexedWidgetBuilder itemBuilder;

  /// A fixed row height, so folding the device does not shift rows.
  final double tileHeight;

  /// Smallest tile width, used to pick the column count.
  final double minTileWidth;

  /// Gap between columns and between rows.
  final double spacing;

  /// Padding around the grid.
  final double outerPadding;

  /// Scroll controller of the grid.
  final ScrollController? controller;

  @override
  State<FoldAlignedGrid> createState() => _FoldAlignedGridState();
}

class _FoldAlignedGridState extends State<FoldAlignedGrid> {
  double _originX = 0;

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        final originX = renderObject.localToGlobal(Offset.zero).dx;
        if ((originX - _originX).abs() > 0.5) {
          setState(() => _originX = originX);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    GridFold? fold;
    var hasFold = false;
    for (final feature in MediaQuery.displayFeaturesOf(context)) {
      if (feature.type != DisplayFeatureType.fold &&
          feature.type != DisplayFeatureType.hinge) {
        continue; // a camera (cutout) does not split the grid
      }
      // A fold is in view, even an inactive one: keep the column count even, as in Apple's recipe B.
      hasFold = true;
      final bounds = feature.bounds;
      if (fold == null && bounds.height > bounds.width) {
        fold = GridFold(
          start: bounds.left - _originX,
          end: bounds.right - _originX,
        );
      }
    }

    return GridView.builder(
      controller: widget.controller,
      padding: EdgeInsets.symmetric(vertical: widget.outerPadding),
      gridDelegate: FoldAlignedGridDelegate(
        minTileWidth: widget.minTileWidth,
        tileHeight: widget.tileHeight,
        spacing: widget.spacing,
        horizontalPadding: widget.outerPadding,
        fold: fold,
        evenColumns: hasFold,
      ),
      itemCount: widget.itemCount,
      itemBuilder: widget.itemBuilder,
    );
  }
}

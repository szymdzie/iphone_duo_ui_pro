// A fold-aware two-pane layout for iPhone Duo.
// Sources: Apple iPhone Duo Tech Talks and HIG - see README.md.

import 'dart:ui' show DisplayFeature, DisplayFeatureState;

import 'package:flutter/material.dart';

import 'duo_environment.dart';

/// Two panes that behave like a HIG split view:
/// * active vertical fold: the panes sit on either side of it (an even split, like Notes and Reminders),
/// * flat at regular width: the start pane takes [startFraction] of the width,
/// * compact width: only [compactPane] (defaults to [endPane]).
///
/// The fold position is resolved against the widget's own position on screen, measured after each frame.
class FoldAwareTwoPane extends StatefulWidget {
  /// Creates a two-pane layout.
  const FoldAwareTwoPane({
    super.key,
    required this.startPane,
    required this.endPane,
    this.compactPane,
    this.startFraction = 0.38,
    this.divider,
  }) : assert(startFraction > 0 && startFraction < 1);

  /// The leading pane, usually a list.
  final Widget startPane;

  /// The trailing pane, usually the detail.
  final Widget endPane;

  /// The pane shown alone at compact width; defaults to [endPane].
  final Widget? compactPane;

  /// Share of the width given to [startPane] when the device is flat.
  final double startFraction;

  /// An optional divider between the panes in the flat layout.
  final Widget? divider;

  @override
  State<FoldAwareTwoPane> createState() => _FoldAwareTwoPaneState();
}

class _FoldAwareTwoPaneState extends State<FoldAwareTwoPane> {
  Offset _origin = Offset.zero;

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        final origin = renderObject.localToGlobal(Offset.zero);
        if ((origin - _origin).distance > 0.5) {
          setState(() => _origin = origin);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    final sizeClasses = DuoSizeClasses.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;

    DisplayFeature? fold;
    for (final feature in MediaQuery.displayFeaturesOf(context)) {
      if (feature.state == DisplayFeatureState.postureHalfOpened &&
          feature.bounds.height > feature.bounds.width &&
          feature.bounds.width > 0) {
        fold = feature;
        break;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (fold != null && width.isFinite) {
          final foldLeft = fold.bounds.left - _origin.dx;
          final foldRight = fold.bounds.right - _origin.dx;
          if (foldLeft > 0 && foldRight < width) {
            final leftRegion = foldLeft;
            final rightRegion = width - foldRight;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Row lays children out in text direction: in RTL the first pane is on the right.
                SizedBox(
                  width: rtl ? rightRegion : leftRegion,
                  child: widget.startPane,
                ),
                SizedBox(width: foldRight - foldLeft),
                Expanded(child: widget.endPane),
              ],
            );
          }
        }
        if (sizeClasses.isRegularWidth && width.isFinite) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: width * widget.startFraction,
                child: widget.startPane,
              ),
              if (widget.divider != null) widget.divider!,
              Expanded(child: widget.endPane),
            ],
          );
        }
        return widget.compactPane ?? widget.endPane;
      },
    );
  }
}

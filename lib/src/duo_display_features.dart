// The iPhone Duo fold and camera as MediaQuery.displayFeatures (without the usual traps),
// plus dialog anchor points that follow Apple's guidance.
// Sources: Apple iPhone Duo Tech Talks and HIG - see README.md.

import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';

import 'duo_environment.dart';

/// Injects iPhone Duo regions into [MediaQueryData.displayFeatures].
///
/// Place it in `MaterialApp.builder` (inside [DuoScope]) so the overridden MediaQuery covers the
/// Navigator and every route. DialogRoute, ModalBottomSheetRoute, PopupMenu and
/// CupertinoModalPopupRoute then avoid an active fold on their own (DisplayFeatureSubScreen).
class DuoDisplayFeatures extends StatelessWidget {
  /// Creates the display-feature injector.
  const DuoDisplayFeatures({
    super.key,
    required this.child,
    this.includeOcclusions = true,
  });

  /// The subtree that sees the injected display features.
  final Widget child;

  /// Whether to publish the active under-display camera as a `cutout`.
  final bool includeOcclusions;

  @override
  Widget build(BuildContext context) {
    final environment = DuoScope.of(context);
    final mediaQuery = MediaQuery.of(context);
    final injected = duoDisplayFeaturesFor(
      environment,
      mediaQuery.size,
      includeOcclusions: includeOcclusions,
    );
    if (injected.isEmpty) return child;
    return MediaQuery(
      data: mediaQuery.copyWith(
        displayFeatures: <DisplayFeature>[
          ...mediaQuery.displayFeatures,
          ...injected,
        ],
      ),
      child: child,
    );
  }
}

/// Maps reserved regions to [DisplayFeature]s:
/// * an active fold with a non-zero area -> `fold` + `postureHalfOpened` (splits dialogs in half),
/// * an inactive or degenerate fold -> a zero-width line + `postureFlat` (no effect on dialogs),
/// * an active camera -> `cutout` + `unknown` (any other state trips an assert in DisplayFeature).
List<DisplayFeature> duoDisplayFeaturesFor(
  DuoEnvironment environment,
  Size viewSize, {
  bool includeOcclusions = true,
}) {
  if (viewSize.isEmpty) return const <DisplayFeature>[];
  final bounds = Offset.zero & viewSize;
  final features = <DisplayFeature>[];

  for (final region in environment.divisions) {
    final clipped = region.rect.intersect(bounds);
    final hasArea = clipped.width > 0 && clipped.height > 0;
    if (region.active && hasArea) {
      features.add(
        DisplayFeature(
          bounds: clipped,
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      );
    } else {
      final center = region.rect.center;
      final x = center.dx.clamp(0.0, viewSize.width).toDouble();
      final y = center.dy.clamp(0.0, viewSize.height).toDouble();
      final line = region.isVertical
          ? Rect.fromLTRB(x, 0, x, viewSize.height)
          : Rect.fromLTRB(0, y, viewSize.width, y);
      features.add(
        DisplayFeature(
          bounds: line,
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureFlat,
        ),
      );
    }
  }

  if (includeOcclusions) {
    for (final region in environment.occlusions) {
      if (!region.active) continue;
      final clipped = region.rect.intersect(bounds);
      if (clipped.width <= 0 || clipped.height <= 0) continue;
      features.add(
        DisplayFeature(
          bounds: clipped,
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
      );
    }
  }
  return features;
}

/// What a presentation is for: it picks the region to use when the fold is horizontal (tabletop pose).
enum DuoAnchorPurpose {
  /// An alert, a confirmation, something to read: the upper region.
  alert,

  /// Content watched from a distance: the upper region.
  content,

  /// Interactive controls, media transport for example: the lower region.
  controls,
}

/// Anchor point for `showDialog` / `showModalBottomSheet` / `showCupertinoModalPopup`,
/// following "Strike a pose with adaptive layouts on iPhone Duo":
/// * book pose (vertical fold): the trailing side,
/// * tabletop pose (horizontal fold): the top for alerts and content, the bottom for controls.
///
/// Returns a **constant** point (a window corner), independent of the fold state when the route opens.
/// The dialog route recomputes `DisplayFeatureSubScreen` on every `MediaQuery` change and clamps the
/// point to the window, so a dialog opened flat moves to the correct half once the device is folded.
/// (A point computed from the current fold - or `null` when flat - would be captured by the route,
/// and after folding the dialog would land in the leading half.)
///
/// Without an active fold the point changes nothing: an inactive fold has zero width and
/// `postureFlat`, so it does not split the screen and the dialog stays centred.
///
/// RTL: trailing follows the text direction, so in RTL it is the left half.
/// VERIFY(27.1 SDK): whether system alerts in RTL also land in the left half (the HIG argues the side physically).
Offset duoAnchorPoint(
  BuildContext context, {
  DuoAnchorPurpose purpose = DuoAnchorPurpose.alert,
}) {
  final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
  final x = rtl ? 0.0 : double.maxFinite;
  final y = purpose == DuoAnchorPurpose.controls ? double.maxFinite : 0.0;
  return Offset(x, y);
}

/// `showDialog` with an anchor point matched to the iPhone Duo pose.
Future<T?> showDuoDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  DuoAnchorPurpose purpose = DuoAnchorPurpose.alert,
}) {
  return showDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    anchorPoint: duoAnchorPoint(context, purpose: purpose),
  );
}

/// `showModalBottomSheet` with an anchor point matched to the pose (controls by default).
Future<T?> showDuoModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = true,
  DuoAnchorPurpose purpose = DuoAnchorPurpose.controls,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    anchorPoint: duoAnchorPoint(context, purpose: purpose),
  );
}

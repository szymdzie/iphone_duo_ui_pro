// iPhone Duo environment state, delivered by the native bridge (ios/Classes/DuoBridge.swift).
// Sources: Apple iPhone Duo Tech Talks and HIG - see README.md.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Size class as UIKit and SwiftUI report it.
enum DuoSizeClass {
  /// Compact size class.
  compact,

  /// Regular size class.
  regular,

  /// The bridge did not report a size class.
  unspecified,
}

/// Physical edge the vertical bar sits on. The bar is aligned to the hardware,
/// so in RTL languages it stays on the same side of the device.
enum DuoBarEdge {
  /// No vertical bar.
  none,

  /// The bar sits on the left edge of the device.
  left,

  /// The bar sits on the right edge of the device.
  right,
}

/// Hinge status (iOS 27.1: `onHingeChange` / `UIHingeInteraction`).
enum DuoHingeStatus {
  /// The device is closed.
  closed,

  /// The device is half open: the book or tabletop pose.
  partiallyOpen,

  /// The device lies flat.
  fullyOpen,

  /// The hinge reported a status this package does not know.
  unknown,
}

enum _EdgeInfo { left, right, leading, trailing }

DuoSizeClass _parseSizeClass(Object? value) => switch (value) {
  'compact' => DuoSizeClass.compact,
  'regular' => DuoSizeClass.regular,
  _ => DuoSizeClass.unspecified,
};

_EdgeInfo? _parseEdge(String? raw) {
  if (raw == null) return null;
  final value = raw.toLowerCase();
  if (value.isEmpty ||
      value.contains('unavailable') ||
      value == 'nil' ||
      value.contains('none') ||
      value.contains('unspecified')) {
    return null;
  }
  if (value.contains('trailing')) return _EdgeInfo.trailing;
  if (value.contains('leading')) return _EdgeInfo.leading;
  if (value.contains('right')) return _EdgeInfo.right;
  if (value.contains('left')) return _EdgeInfo.left;
  return null;
}

/// A reserved region: the fold (division) or the camera (occlusion), in Flutter logical pixels.
@immutable
class DuoRegion {
  /// Creates a region.
  const DuoRegion({required this.rect, required this.active});

  /// Frame of the region in the Flutter view's logical pixels.
  final Rect rect;

  /// Whether the region currently affects layout: an active fold or a live camera.
  final bool active;

  /// A vertical fold (book pose): the region is taller than it is wide.
  bool get isVertical => rect.height >= rect.width;

  /// Whether the region has a non-zero area.
  bool get hasArea => rect.width > 0 && rect.height > 0;

  /// Parses a region map sent by the bridge; null when [value] is not a map.
  static DuoRegion? fromMap(Object? value) {
    if (value is! Map) return null;
    final map = value;
    double read(String key) => (map[key] as num?)?.toDouble() ?? 0;
    return DuoRegion(
      rect: Rect.fromLTWH(read('x'), read('y'), read('width'), read('height')),
      active: map['active'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DuoRegion && other.rect == rect && other.active == active;

  @override
  int get hashCode => Object.hash(rect, active);

  @override
  String toString() => 'DuoRegion($rect, active: $active)';
}

/// Hinge status and angle. `null` in [DuoEnvironment.hinge] means a device without a hinge
/// or no data at all (a bridge built without `DUO_SDK_27_1`).
@immutable
class DuoHinge {
  /// Creates a hinge state.
  const DuoHinge({required this.status, this.angleDegrees});

  /// Current hinge status.
  final DuoHingeStatus status;

  /// Hinge angle in degrees, when reported.
  final double? angleDegrees;

  /// Parses a hinge map sent by the bridge; null when [value] is not a map.
  static DuoHinge? fromMap(Object? value) {
    if (value is! Map) return null;
    final map = value;
    final raw = (map['status'] as String? ?? '').toLowerCase();
    final status = raw.contains('partially')
        ? DuoHingeStatus.partiallyOpen
        : raw.contains('fully')
        ? DuoHingeStatus.fullyOpen
        : raw.contains('closed')
        ? DuoHingeStatus.closed
        : DuoHingeStatus.unknown;
    return DuoHinge(
      status: status,
      angleDegrees: (map['angleDegrees'] as num?)?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DuoHinge &&
      other.status == status &&
      other.angleDegrees == angleDegrees;

  @override
  int get hashCode => Object.hash(status, angleDegrees);
}

/// iPhone Duo environment: size classes, vertical bar, fold, camera and hinge.
@immutable
class DuoEnvironment {
  /// Creates an environment; every field defaults to "unknown".
  const DuoEnvironment({
    this.isAvailable = false,
    this.sdk271 = false,
    this.size,
    this.horizontalSizeClass = DuoSizeClass.unspecified,
    this.verticalSizeClass = DuoSizeClass.unspecified,
    this.toolbarVerticalEdgeRaw,
    this.uikitVerticalBarEdgeRaw,
    this.divisions = const <DuoRegion>[],
    this.occlusions = const <DuoRegion>[],
    this.hinge,
  });

  /// No data from the bridge (another platform, bridge not installed, tests without an override).
  static const DuoEnvironment unavailable = DuoEnvironment();

  /// Parses the map the bridge sends on the `iphone_duo/environment` channel.
  factory DuoEnvironment.fromMap(Map<Object?, Object?> map) {
    List<DuoRegion> regions(Object? value) => value is List
        ? value
              .map(DuoRegion.fromMap)
              .whereType<DuoRegion>()
              .toList(growable: false)
        : const <DuoRegion>[];
    final width = (map['width'] as num?)?.toDouble();
    final height = (map['height'] as num?)?.toDouble();
    return DuoEnvironment(
      isAvailable: true,
      sdk271: map['sdk271'] == true,
      size: width != null && height != null ? Size(width, height) : null,
      horizontalSizeClass: _parseSizeClass(map['horizontalSizeClass']),
      verticalSizeClass: _parseSizeClass(map['verticalSizeClass']),
      toolbarVerticalEdgeRaw: map['toolbarVerticalEdge'] as String?,
      uikitVerticalBarEdgeRaw: map['uikitVerticalBarEdge'] as String?,
      divisions: regions(map['divisions']),
      occlusions: regions(map['occlusions']),
      hinge: DuoHinge.fromMap(map['hinge']),
    );
  }

  /// Returns a copy with the given fields replaced.
  DuoEnvironment copyWith({
    bool? isAvailable,
    bool? sdk271,
    Size? size,
    DuoSizeClass? horizontalSizeClass,
    DuoSizeClass? verticalSizeClass,
    String? toolbarVerticalEdgeRaw,
    String? uikitVerticalBarEdgeRaw,
    List<DuoRegion>? divisions,
    List<DuoRegion>? occlusions,
    DuoHinge? hinge,
  }) {
    return DuoEnvironment(
      isAvailable: isAvailable ?? this.isAvailable,
      sdk271: sdk271 ?? this.sdk271,
      size: size ?? this.size,
      horizontalSizeClass: horizontalSizeClass ?? this.horizontalSizeClass,
      verticalSizeClass: verticalSizeClass ?? this.verticalSizeClass,
      toolbarVerticalEdgeRaw:
          toolbarVerticalEdgeRaw ?? this.toolbarVerticalEdgeRaw,
      uikitVerticalBarEdgeRaw:
          uikitVerticalBarEdgeRaw ?? this.uikitVerticalBarEdgeRaw,
      divisions: divisions ?? this.divisions,
      occlusions: occlusions ?? this.occlusions,
      hinge: hinge ?? this.hinge,
    );
  }

  /// The bridge delivered data.
  final bool isAvailable;

  /// The bridge was compiled with `DUO_SDK_27_1` and runs on iOS 27.1 or later.
  final bool sdk271;

  /// Size of the Flutter view in logical pixels, when reported.
  final Size? size;

  /// Horizontal size class reported by UIKit.
  final DuoSizeClass horizontalSizeClass;

  /// Vertical size class reported by UIKit.
  final DuoSizeClass verticalSizeClass;

  /// Raw description of `@Environment(\.toolbarVerticalEdge)` (SwiftUI), or `unavailable`.
  final String? toolbarVerticalEdgeRaw;

  /// Raw description of `traitCollection.verticalBarEdge` (UIKit), or `unavailable`.
  final String? uikitVerticalBarEdgeRaw;

  /// Folds (divisions): both active and inactive (`includeInactive`).
  final List<DuoRegion> divisions;

  /// Active occlusion regions (the FaceTime camera under the display).
  final List<DuoRegion> occlusions;

  /// Hinge state, or null on a device without a hinge.
  final DuoHinge? hinge;

  /// The device has a fold, even lying flat - use it to keep a column count even.
  bool get hasFoldHardware => divisions.isNotEmpty || hinge != null;

  /// Whether a fold region is in this view, including an inactive one. Matches the condition from
  /// Apple's recipe B (`reservedRegions(kind: .division, options: .includeInactive)` is not empty).
  /// False on the outer display and in a Split View half without a fold, even though the device hinges.
  bool get hasDivisionInView => divisions.isNotEmpty;

  /// An active fold with a non-zero area.
  DuoRegion? get activeFold {
    for (final region in divisions) {
      if (region.active && region.hasArea) return region;
    }
    return null;
  }

  /// Partially folded like a book (a vertical fold).
  bool get isBookPose => activeFold?.isVertical ?? false;

  /// Partially folded on a table (a horizontal fold).
  bool get isTabletopPose {
    final fold = activeFold;
    return fold != null && !fold.isVertical;
  }

  /// Whether the system reported the vertical bar edge (iOS 27.1).
  bool get verticalBarEdgeKnown =>
      _parseEdge(toolbarVerticalEdgeRaw) != null ||
      _parseEdge(uikitVerticalBarEdgeRaw) != null;

  /// Physical edge of the vertical bar for the app's text direction.
  DuoBarEdge barEdgeFor(TextDirection direction) {
    final info =
        _parseEdge(toolbarVerticalEdgeRaw) ??
        _parseEdge(uikitVerticalBarEdgeRaw);
    if (info == null) return DuoBarEdge.none;
    final rtl = direction == TextDirection.rtl;
    return switch (info) {
      _EdgeInfo.left => DuoBarEdge.left,
      _EdgeInfo.right => DuoBarEdge.right,
      _EdgeInfo.leading => rtl ? DuoBarEdge.right : DuoBarEdge.left,
      _EdgeInfo.trailing => rtl ? DuoBarEdge.left : DuoBarEdge.right,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is DuoEnvironment &&
      other.isAvailable == isAvailable &&
      other.sdk271 == sdk271 &&
      other.size == size &&
      other.horizontalSizeClass == horizontalSizeClass &&
      other.verticalSizeClass == verticalSizeClass &&
      other.toolbarVerticalEdgeRaw == toolbarVerticalEdgeRaw &&
      other.uikitVerticalBarEdgeRaw == uikitVerticalBarEdgeRaw &&
      listEquals(other.divisions, divisions) &&
      listEquals(other.occlusions, occlusions) &&
      other.hinge == hinge;

  @override
  int get hashCode => Object.hash(
    isAvailable,
    sdk271,
    size,
    horizontalSizeClass,
    verticalSizeClass,
    toolbarVerticalEdgeRaw,
    uikitVerticalBarEdgeRaw,
    Object.hashAll(divisions),
    Object.hashAll(occlusions),
    hinge,
  );

  @override
  String toString() =>
      'DuoEnvironment(available: $isAvailable, sdk271: $sdk271, size: $size, '
      'sizeClasses: $horizontalSizeClass/$verticalSizeClass, divisions: $divisions, '
      'occlusions: $occlusions, hinge: ${hinge?.status})';
}

/// Size classes: from the bridge, or approximated from the window size.
@immutable
class DuoSizeClasses {
  /// Creates a pair of size classes.
  const DuoSizeClasses(this.horizontal, this.vertical);

  /// Horizontal size class.
  final DuoSizeClass horizontal;

  /// Vertical size class.
  final DuoSizeClass vertical;

  /// Whether the horizontal size class is regular.
  bool get isRegularWidth => horizontal == DuoSizeClass.regular;

  /// Whether the vertical size class is regular.
  bool get isRegularHeight => vertical == DuoSizeClass.regular;

  /// The approximation used when the bridge reports no size classes. On iPhone Duo width alone is not
  /// enough (outer display in landscape is compact, inner in portrait is regular), hence `shortestSide`.
  static DuoSizeClasses estimate(Size size) {
    if (size.shortestSide >= 600) {
      return const DuoSizeClasses(DuoSizeClass.regular, DuoSizeClass.regular);
    }
    return DuoSizeClasses(
      DuoSizeClass.compact,
      size.height >= 500 ? DuoSizeClass.regular : DuoSizeClass.compact,
    );
  }

  /// Size classes for [context]: from the bridge when available, otherwise estimated from the window size.
  static DuoSizeClasses of(BuildContext context) {
    final environment = DuoScope.of(context);
    if (environment.horizontalSizeClass != DuoSizeClass.unspecified &&
        environment.verticalSizeClass != DuoSizeClass.unspecified) {
      return DuoSizeClasses(
        environment.horizontalSizeClass,
        environment.verticalSizeClass,
      );
    }
    return estimate(MediaQuery.sizeOf(context));
  }

  @override
  bool operator ==(Object other) =>
      other is DuoSizeClasses &&
      other.horizontal == horizontal &&
      other.vertical == vertical;

  @override
  int get hashCode => Object.hash(horizontal, vertical);

  @override
  String toString() => 'DuoSizeClasses($horizontal, $vertical)';
}

/// An even column count on a folding device (HIG: content should split cleanly at the fold).
int duoEvenColumns(int columns, DuoEnvironment environment) {
  if (!environment.hasDivisionInView || columns <= 1) return columns;
  return columns.isEven ? columns : columns - 1;
}

/// Publishes [DuoEnvironment] to the widget tree.
///
/// On iOS it listens on the `iphone_duo/environment` channel (DuoBridge.swift). On other platforms,
/// or when you pass [environment] (tests, previews), the channel is not used.
class DuoScope extends StatefulWidget {
  /// Creates a scope; pass [environment] to bypass the channel.
  const DuoScope({
    super.key,
    required this.child,
    this.environment,
    this.channel,
  });

  /// The subtree that can read the environment with [DuoScope.of].
  final Widget child;

  /// A fixed environment for tests and previews. When set, the channel is not used.
  final DuoEnvironment? environment;

  /// A custom channel (defaults to [defaultChannel]).
  final EventChannel? channel;

  /// The channel the native bridge publishes on.
  static const EventChannel defaultChannel = EventChannel(
    'iphone_duo/environment',
  );

  /// The nearest environment, or [DuoEnvironment.unavailable] outside a [DuoScope].
  static DuoEnvironment of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_DuoInherited>()
          ?.environment ??
      DuoEnvironment.unavailable;

  /// The nearest environment, or null outside a [DuoScope].
  static DuoEnvironment? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DuoInherited>()?.environment;

  @override
  State<DuoScope> createState() => _DuoScopeState();
}

class _DuoScopeState extends State<DuoScope> {
  StreamSubscription<dynamic>? _subscription;
  DuoEnvironment _environment = DuoEnvironment.unavailable;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant DuoScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.environment != widget.environment ||
        oldWidget.channel != widget.channel) {
      _subscription?.cancel();
      _subscription = null;
      _subscribe();
    }
  }

  void _subscribe() {
    if (widget.environment != null) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    final channel = widget.channel ?? DuoScope.defaultChannel;
    _subscription = channel.receiveBroadcastStream().listen(
      (Object? event) {
        if (event is Map && mounted) {
          final next = DuoEnvironment.fromMap(
            Map<Object?, Object?>.from(event),
          );
          if (next != _environment) {
            setState(() => _environment = next);
          }
        }
      },
      onError: (Object error) {
        // No bridge, or a native error: stay on DuoEnvironment.unavailable.
        debugPrint('DuoScope: brak danych iPhone Duo ($error)');
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DuoInherited(
      environment: widget.environment ?? _environment,
      child: widget.child,
    );
  }
}

class _DuoInherited extends InheritedWidget {
  const _DuoInherited({required this.environment, required super.child});

  final DuoEnvironment environment;

  @override
  bool updateShouldNotify(_DuoInherited oldWidget) =>
      oldWidget.environment != environment;
}

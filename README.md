<img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/e5007d96df5c918aa3ec3f77c11f1af4f4ecb1f8/doc/img/hero.png" alt="iphone_duo_ui_pro - fold-aware Flutter widgets for iPhone Duo" width="100%">

[![pub package](https://img.shields.io/pub/v/iphone_duo_ui_pro.svg)](https://pub.dev/packages/iphone_duo_ui_pro)
[![license: MIT](https://img.shields.io/badge/license-MIT-0F6079.svg)](https://github.com/szymdzie/iphone_duo_ui_pro/blob/main/LICENSE)
[![platform: iOS](https://img.shields.io/badge/platform-iOS-555.svg)](https://pub.dev/packages/iphone_duo_ui_pro)

On iPhone Duo a Flutter app resizes itself correctly, and `MediaQuery.paddingOf` even reports the
asymmetric safe area. The rest is missing: `MediaQuery.displayFeatures` stays empty on iOS, so
nothing in Dart knows where the fold is, and your navigation stays pinned to the bottom while the
system moves its own bars to the side of the screen.

This package fills that gap. A native bridge reports what UIKit and SwiftUI already know — reserved
regions, size classes, the hinge, the vertical bar edge — and a small set of widgets turn that state
into layout.

```sh
flutter pub add iphone_duo_ui_pro
```

<img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/e5007d96df5c918aa3ec3f77c11f1af4f4ecb1f8/screenshots/fold.gif" alt="The example on the iPhone Duo simulator: the panes split on the fold, a dialog steps aside, the grid mirrors around the hinge, the bridge reports the angle" width="100%">

The example on the iPhone Duo simulator (iOS 27.1). The angle in the caption is the one the bridge
reported at that frame.

## Two modes for the bars

<img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/e5007d96df5c918aa3ec3f77c11f1af4f4ecb1f8/doc/img/two-modes.png" alt="Two modes for the bars: custom navigation drawn by Flutter (DuoAdaptiveScaffold) or official Liquid Glass drawn by UIKit (DuoGlassScaffold), fed by the same actions and tabs" width="100%">

The content widgets are the same either way. For the bars you pick a mode, per app or per screen:

| | **Mode 1 · custom navigation** | **Mode 2 · official Liquid Glass** |
| --- | --- | --- |
| Widget | `DuoAdaptiveScaffold` | `DuoGlassScaffold` |
| Package | this one | [`iphone_duo_ui_pro_glass`](https://pub.dev/packages/iphone_duo_ui_pro_glass), the optional companion |
| Drawn by | Flutter | UIKit: `UIGlassEffect`, `UITabBar`, `UINavigationBar` |
| Dependencies | none | `adaptive_platform_ui` |
| Looks | the same on iOS, Android and in tests; yours to restyle | the system's own material, light and dark, whatever Apple ships next |
| Extras | overflow priorities, tab bar compression, FAB mapping | system back button, system overflow menu, a backdrop under the bar |

Both take the same `DuoBarAction` and `DuoTab` values, so moving a screen from one mode to the
other is a rename. Details: [mode 1](#mode-1-custom-navigation), [mode 2](#mode-2-official-liquid-glass).

## What you get

| API | What it does |
| --- | --- |
| `DuoScope` | Streams the native bridge into the widget tree as a `DuoEnvironment`. |
| `DuoDisplayFeatures` | Republishes the fold and the under-display camera as `DisplayFeature`s, so every system route avoids them on its own. |
| `FoldAwareTwoPane` | List and detail split exactly on the fold, one pane at compact width. |
| `DuoAdaptiveScaffold` | Custom navigation, the first of the [two modes](#two-modes-for-the-bars): moves navigation and actions into the vertical bar when the display calls for it, and keeps content state across the switch. |
| `FoldAlignedGrid`, `duoEvenColumns` | Tile grids whose columns stay symmetric around the hinge. |
| `showDuoDialog`, `showDuoModalBottomSheet`, `duoAnchorPoint` | Presentations anchored to the region Apple's guidance asks for. |
| [`iphone_duo_ui_pro_glass`](#mode-2-official-liquid-glass) | Optional companion, the second mode: the same actions and tabs drawn by UIKit, as official Liquid Glass. |

## Setup

Requires **Flutter 3.38+** and an app on the **UIScene life cycle** — apps built against the iOS 27
SDK without it do not launch at all. Minimum deployment target is iOS 15; every iPhone Duo API is
guarded by availability checks.

```dart
MaterialApp(
  builder: (context, child) => DuoScope(
    child: DuoDisplayFeatures(child: child ?? const SizedBox.shrink()),
  ),
  home: const HomeScreen(),
);
```

That is the whole installation. The plugin registers itself through Flutter's
`GeneratedPluginRegistrant`, so there is no app-side Swift to write. On platforms without the bridge
`DuoScope` reports `DuoEnvironment.unavailable` and every widget falls back to its plain layout, so
the same code keeps working on a regular iPhone, on Android and in tests.

## Two panes, and dialogs that step aside

<img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/e5007d96df5c918aa3ec3f77c11f1af4f4ecb1f8/doc/img/two-pane.png" alt="FoldAwareTwoPane in compact, flat and book poses, with a dialog anchored to the trailing half" width="100%">

```dart
FoldAwareTwoPane(
  startPane: SessionList(onSelected: _select),
  endPane: SessionDetail(id: _selected),
);

showDuoDialog<void>(
  context: context,
  builder: (context) => const AlertDialog(title: Text('Delete this session?')),
);

showDuoModalBottomSheet<void>(
  context: context,
  purpose: DuoAnchorPurpose.controls, // the lower region in the tabletop pose
  builder: (context) => const PlaybackControls(),
);
```

The anchor point is deliberately constant — a window corner rather than a measured fold. Dialog
routes recompute `DisplayFeatureSubScreen` on every `MediaQuery` change, so a dialog opened while
the device is flat moves to the correct half the moment it is folded. A point computed from the
current fold would be captured by the route and end up in the wrong half.

## Mode 1: custom navigation

<img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/e5007d96df5c918aa3ec3f77c11f1af4f4ecb1f8/doc/img/vertical-bar.png" alt="DuoAdaptiveScaffold: horizontal bars on the inner display in portrait, a vertical bar on the outer display" width="100%">

On the outer display, and on the inner display in landscape, the system moves toolbars, navigation
and tab bars to the side. `DuoAdaptiveScaffold` follows: the same actions, in the order Apple
specifies, with an icon and a label on each so they read identically in the overflow menu.

```dart
DuoAdaptiveScaffold(
  title: 'Library',
  prominentAction: DuoBarAction(icon: Icons.add, label: 'Add', onPressed: _add),
  topActions: <DuoBarAction>[
    DuoBarAction(
      icon: Icons.edit_outlined,
      label: 'Compose',
      priority: DuoVisibilityPriority.high,
      onPressed: _compose,
    ),
    DuoBarAction(icon: Icons.inbox_outlined, label: 'Inbox', badgeCount: 7, onPressed: _inbox),
  ],
  tabs: const <DuoTab>[
    DuoTab(icon: Icons.photo_library_outlined, label: 'Library'),
    DuoTab(icon: Icons.grid_view_outlined, label: 'Grid'),
  ],
  selectedTabIndex: _tab,
  onTabSelected: (index) => setState(() => _tab = index),
  body: content,
);
```

On iPhone Duo the status bar and the camera live in an 84 pt safe-area inset along the bar edge,
and the system draws its own bars inside that column. The scaffold does the same: the bar takes the
column, starts below the status and camera region (the bridge reports it as an occlusion), stops
above the home indicator, and centres its items on the status bar axis, 48 pt from the edge. Content
is not inset twice. Without a system column — a regular iPhone, a test — the bar keeps its own 64 pt
inside the safe area.

On a regular iPhone the scaffold falls back to an app bar and a tab bar — one bar at the bottom,
never two: with tabs, the bottom actions move into the app bar's overflow menu. In both layouts the
body runs to the bottom edge and leaves the inset in `MediaQuery`, so scroll views pad their own
content the way they do on iOS.

Two more details worth knowing. A floating action button is only shown in the horizontal layout — in the
vertical bar its role is taken by `prominentAction`, which is why the scaffold asserts you passed
one. And the body travels between layouts under a `GlobalKey`, so scroll offsets and text fields
survive opening, closing and rotating the device.

## Mode 2: official Liquid Glass

<img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/e5007d96df5c918aa3ec3f77c11f1af4f4ecb1f8/doc/img/liquid-glass.png" alt="iphone_duo_ui_pro_glass: real UIKit Liquid Glass capsules in the iPhone Duo vertical bar, a fold-aligned Flutter grid underneath" width="100%">

Mode 1 draws its bars in Flutter, which keeps this package free of dependencies and identical on
every platform. If you want the system's own material instead, add the companion:

```sh
flutter pub add iphone_duo_ui_pro_glass
```

[`iphone_duo_ui_pro_glass`](https://pub.dev/packages/iphone_duo_ui_pro_glass) hands the bars to
UIKit through [`adaptive_platform_ui`](https://pub.dev/packages/adaptive_platform_ui) — a real
`UINavigationBar`, a real `UITabBar`, and `UIGlassEffect` capsules in the iPhone Duo vertical bar —
while everything in this package keeps laying out the content around the fold. It is a separate
package on purpose: Dart has no optional dependencies, and nobody who only needs the layout should
ship two more native plugins.

```dart
import 'package:iphone_duo_ui_pro_glass/iphone_duo_ui_pro_glass.dart';

MaterialApp(
  builder: (context, child) => DuoGlassHost(child: child!), // bridge + fold + toolbar host
  home: DuoGlassScaffold(
    title: 'Library',
    topActions: <DuoBarAction>[
      DuoBarAction(
        icon: Icons.edit_outlined,
        sfSymbol: 'square.and.pencil', // UIKit draws SF Symbols
        label: 'Compose',
        onPressed: _compose,
      ),
    ],
    tabs: tabs,
    selectedTabIndex: _tab,
    onTabSelected: (index) => setState(() => _tab = index),
    body: FoldAwareTwoPane(startPane: list, endPane: detail),
  ),
);
```

<p>
  <img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/e5007d96df5c918aa3ec3f77c11f1af4f4ecb1f8/packages/iphone_duo_ui_pro_glass/screenshots/glass-inner.gif" alt="Inner display folding and unfolding with native glass capsules in the vertical bar" width="62%">
  <img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/e5007d96df5c918aa3ec3f77c11f1af4f4ecb1f8/packages/iphone_duo_ui_pro_glass/screenshots/glass-cover.gif" alt="Cover display: a pushed page gets the system back button in the glass bar" width="36%">
</p>

<img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/e5007d96df5c918aa3ec3f77c11f1af4f4ecb1f8/packages/iphone_duo_ui_pro_glass/screenshots/two-modes.gif" alt="The same screen switching between custom navigation and Liquid Glass" width="100%">

The companion's example switches between the two modes at run time, above. `DuoBarAction` and
`DuoTab` carry an optional `sfSymbol` for exactly this: the same values feed
both scaffolds, so moving a screen to Liquid Glass is a rename. This package's own widgets ignore
the field.

## Grids aligned to the hinge

<img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/e5007d96df5c918aa3ec3f77c11f1af4f4ecb1f8/doc/img/fold-aligned-grid.png" alt="A plain grid leaves a tile in the fold; FoldAlignedGrid mirrors columns around it" width="100%">

An even column count is the usual advice, and it is enough when the content area is centred on the
fold. Add a vertical bar on one side and the middle gap misses the hinge. `FoldAlignedGrid` plans
columns outwards from the centre of the fold instead, so folding the device grows the middle gap and
changes nothing else — not the column count, not the outer margins.

```dart
FoldAlignedGrid(
  itemCount: photos.length,
  tileHeight: 104,
  minTileWidth: 120,
  itemBuilder: (context, index) => PhotoTile(photos[index]),
);
```

## What the bridge reports

`DuoScope.of(context)` returns a `DuoEnvironment`:

| Member | Meaning |
| --- | --- |
| `isAvailable`, `sdk271` | Whether the bridge answered, and whether it was built with the iOS 27.1 APIs. |
| `size`, `horizontalSizeClass`, `verticalSizeClass` | The UIKit view size and size classes — on iPhone Duo width alone cannot tell you the class. |
| `divisions`, `occlusions` | Reserved regions: folds (active and inactive) and the camera under the display. |
| `hasDivisionInView`, `activeFold` | Whether a fold is in this view at all, and the one currently splitting it. |
| `isBookPose`, `isTabletopPose` | Which way the device is folded. |
| `hinge` | Hinge status and angle, or `null` on a device without one. |
| `verticalBarEdgeKnown`, `barEdgeFor(direction)` | Which physical edge the system put its bars on. |

## iOS 27.1 and the `DUO_SDK_27_1` flag

Reserved regions, the vertical bar edge and the hinge ship with the **iOS 27.1 SDK**. Until every
build machine has Xcode 27.1, those call sites stay behind a compilation condition — `#available`
alone is not enough, because the symbols do not exist in the 27.0 SDK and the compiler stops at
"cannot find … in scope". Turn them on in your `ios/Podfile`:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    next unless target.name == 'iphone_duo_ui_pro'
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = '$(inherited) DUO_SDK_27_1'
    end
  end
end
```

Without the flag the bridge still reports size classes and the view size, so `DuoAdaptiveScaffold`
and `FoldAwareTwoPane` keep working; folds simply never appear. On Android, `displayFeatures` comes
from Flutter itself, so `FoldAlignedGrid` works there with no bridge at all.

**Status:** the bridge compiles against the iOS 27.1 SDK (Xcode 27.1) with the flag on and no
warnings, and every value below was observed on the iPhone Duo simulator through Device Hub. A
physical device has not been tested yet.

## Testing without the device

Pass an environment and the channel is never touched:

```dart
const fold = DuoRegion(rect: Rect.fromLTWH(467.5, 0, 16, 669), active: true);

await tester.pumpWidget(
  DuoScope(
    environment: const DuoEnvironment(
      isAvailable: true,
      sdk271: true,
      size: Size(951, 669),
      horizontalSizeClass: DuoSizeClass.regular,
      verticalSizeClass: DuoSizeClass.regular,
      divisions: <DuoRegion>[fold],
      hinge: DuoHinge(status: DuoHingeStatus.partiallyOpen, angleDegrees: 120),
    ),
    child: const DuoDisplayFeatures(child: MyApp()),
  ),
);
```

The package ships 34 tests built this way, covering both poses, RTL, Split View halves, overflow
priorities and state preservation across layout switches.

## Configurations at a glance

| Configuration | Size classes | Bars | Panes |
| --- | --- | --- | --- |
| Outer display, portrait | compact × regular | vertical | one |
| Outer display, landscape | compact × compact | vertical | one |
| Inner display, portrait | regular × regular | horizontal | two, 38 / 62 |
| Inner display, landscape | regular × regular | vertical | two |
| Half open (book pose) | regular × regular | as above | split on the fold |

Measured on the simulator, for previews and tests — never for hard-coding layout:

| | Outer display | Inner display (landscape) |
| --- | --- | --- |
| Size | 466 × 678 pt | 951 × 669 pt |
| Safe area | right 84, bottom 34 | right 84, bottom 34 |
| Status region in the column | 84 × 170 pt | 84 × 120 pt |
| Fold | — | 40 pt wide, centred (455.5 – 495.5) |
| Status bar axis | 48 pt from the edge | 48 pt from the edge |

## Building with Xcode 27.1

Two things bite today. Xcode 27.1 rejects deployment targets below iOS 15, so raise
`IPHONEOS_DEPLOYMENT_TARGET` in the Runner project and force it for pods in `post_install`. And
Flutter 3.38's `flutter build ios --simulator` stops at "does not contain architectures" because the
new `lipo` prints them in a different order; building one architecture avoids it:

```sh
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone Duo' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build
```

`example/ios/Podfile` shows both settings.

## Sources

Built from Apple's iPhone Duo material: the six Tech Talks (*Prepare your app for iPhone Duo*, *Design
for iPhone Duo*, *Raise the bar with iPhone Duo*, *Strike a pose with adaptive layouts on iPhone Duo*,
*Leverage multiple displays and scenes on iPhone Duo*, *Build a great camera experience for iPhone
Duo*), the articles *Preparing your app for iPhone Duo* and *Choosing a camera by the direction it faces*, and the *Designing for iPhone Duo* Human Interface Guidelines.

## Author

Szymon Dziedzic — mobile developer, Flutter and native iOS.
[LinkedIn](https://www.linkedin.com/in/dziedzic-szymon/) · [szymondziedzic.com](https://szymondziedzic.com)

## License

MIT — see [LICENSE](https://github.com/szymdzie/iphone_duo_ui_pro/blob/main/LICENSE).

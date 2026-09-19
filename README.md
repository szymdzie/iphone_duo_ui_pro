<img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/edd5f0cb79eea70c4f20a4bb15eaeda20c7df78e/doc/img/hero.png" alt="iphone_duo_ui_pro - fold-aware Flutter widgets for iPhone Duo" width="100%">

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

## What you get

| API | What it does |
| --- | --- |
| `DuoScope` | Streams the native bridge into the widget tree as a `DuoEnvironment`. |
| `DuoDisplayFeatures` | Republishes the fold and the under-display camera as `DisplayFeature`s, so every system route avoids them on its own. |
| `FoldAwareTwoPane` | List and detail split exactly on the fold, one pane at compact width. |
| `DuoAdaptiveScaffold` | Moves navigation and actions into the vertical bar when the display calls for it, and keeps content state across the switch. |
| `FoldAlignedGrid`, `duoEvenColumns` | Tile grids whose columns stay symmetric around the hinge. |
| `showDuoDialog`, `showDuoModalBottomSheet`, `duoAnchorPoint` | Presentations anchored to the region Apple's guidance asks for. |

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

<img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/edd5f0cb79eea70c4f20a4bb15eaeda20c7df78e/doc/img/two-pane.png" alt="FoldAwareTwoPane in compact, flat and book poses, with a dialog anchored to the trailing half" width="100%">

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

## The vertical bar

<img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/edd5f0cb79eea70c4f20a4bb15eaeda20c7df78e/doc/img/vertical-bar.png" alt="DuoAdaptiveScaffold: horizontal bars on the inner display in portrait, a vertical bar on the outer display" width="100%">

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

Two more details worth knowing. A floating action button is only shown in the horizontal layout — in the
vertical bar its role is taken by `prominentAction`, which is why the scaffold asserts you passed
one. And the body travels between layouts under a `GlobalKey`, so scroll offsets and text fields
survive opening, closing and rotating the device.

## Grids aligned to the hinge

<img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/edd5f0cb79eea70c4f20a4bb15eaeda20c7df78e/doc/img/fold-aligned-grid.png" alt="A plain grid leaves a tile in the fold; FoldAlignedGrid mirrors columns around it" width="100%">

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

The package ships 30 tests built this way, covering both poses, RTL, Split View halves, overflow
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

Built from Apple's iPhone Duo material: the six Tech Talks (*Get ready for iPhone Duo*, *Strike a
pose with adaptive layouts*, *Raise the bar*, *Leverage multiple displays and scenes*, *Update your
camera app*, *Design for iPhone Duo*) and the *Designing for iPhone Duo* Human Interface Guidelines.

## Author

Szymon Dziedzic — mobile developer, Flutter and native iOS.
[LinkedIn](https://www.linkedin.com/in/dziedzic-szymon/) · [szymondziedzic.com](https://szymondziedzic.com)

## License

MIT — see [LICENSE](https://github.com/szymdzie/iphone_duo_ui_pro/blob/main/LICENSE).

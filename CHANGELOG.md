## 0.3.0

Two modes for the bars: custom navigation, as before, or official Liquid Glass.

* `DuoAdaptiveScaffold` is now one of two modes. It stays what it was: custom navigation drawn by
  Flutter, with no dependencies.
* The second mode is a new companion package,
  [`iphone_duo_ui_pro_glass`](https://pub.dev/packages/iphone_duo_ui_pro_glass): the actions and
  tabs of `DuoAdaptiveScaffold` drawn by UIKit through `adaptive_platform_ui` — native glass
  capsules in the iPhone Duo vertical bar — with this package's widgets laying out the content
  underneath. It is a separate package, so this one stays free of dependencies.
* `DuoBarAction.sfSymbol`, `DuoTab.sfSymbol` and `DuoTab.selectedSfSymbol`: SF Symbol names for
  renderers that draw with UIKit. This package's own widgets ignore them, so the same values can
  feed both scaffolds.
* README: the two modes side by side, screenshots and recordings from the iPhone Duo simulator;
  the same media is on pub.dev.
* Example: `remote=1` in the launch options turns on a remote control (`tmp/duo_cmd.txt` in the
  app container) for driving the app while the simulator is in the background; the debug banner
  is off.

## 0.2.1

Fixes found on the iPhone Duo and iPhone 18 Pro simulators.

* `DuoAdaptiveScaffold`, horizontal layout: **one bar at the bottom, never two.** With a tab bar the
  bottom actions move to the overflow menu of the app bar; without tabs they keep a single toolbar
  row. The app bar keeps up to `maxInlineActions` (3) top actions, by priority, and overflows the rest.
* `DuoAdaptiveScaffold`: the body is no longer clipped at the bottom safe-area inset. It runs to the
  edge and leaves the inset in `MediaQuery`, so scroll views pad their own content, as on iOS. The
  horizontal layout also keeps the body clear of the side insets (the Dynamic Island in landscape).
* `FoldAlignedGrid` adds the safe area to its scroll padding — an explicit `padding` had switched off
  the one `GridView` adds by itself, so the last row could end up under the home indicator.
* The status bar axis is exact: 143.5 px at 3x (47.83 pt), identical on both displays.
* Example: launch options (`tab`, `scroll_end`) read from `tmp/duo_launch.txt` in the app container,
  for screenshots without touching the simulator.

## 0.2.0

Verified on the iPhone Duo simulator (iOS 27.1, Xcode 27.1).

* The native bridge compiles against the iOS 27.1 SDK with `DUO_SDK_27_1` and no warnings; reserved
  regions, the hinge, size classes and the vertical bar edge were all observed at run time.
* `DuoAdaptiveScaffold`: the vertical bar now lives in the system column, the 84 pt safe-area inset
  the status bar occupies. It starts below the status/camera region (reported as an occlusion),
  ends above the home indicator, and its items share the status bar axis, 48 pt from the edge.
  Content is no longer inset twice and gains the width of the column.
* `DuoEnvironment.copyWith`.
* **Breaking:** the iOS deployment target is 15.0. Xcode 27.1 rejects anything lower.
* Example: UIScene life cycle, `DUO_SDK_27_1` enabled in the Podfile, and a Bridge tab that shows
  and logs the live environment.
* Tests use the measured geometry: a 40 pt fold, the 84 pt system column, 34 pt home indicator.

## 0.1.1

* README: fixed a clipped caption in the two-pane diagram and pinned the diagrams to an immutable commit.

## 0.1.0

First release.

* `DuoScope` + native iOS bridge (`DuoBridge`): reserved regions, hinge, UIKit
  size classes and the vertical bar edge streamed into Dart.
* `DuoDisplayFeatures`: republishes the fold and the under-display camera as
  `DisplayFeature`s, which iOS does not provide to Flutter.
* `DuoAdaptiveScaffold`: navigation in the vertical bar, with the primary
  action promoted instead of a floating action button.
* `FoldAwareTwoPane`, `FoldAlignedGrid`, `duoEvenColumns`: layouts that keep
  content and controls off the fold.
* `showDuoDialog`, `showDuoModalBottomSheet`, `duoAnchorPoint`: presentations
  anchored beside the fold.

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

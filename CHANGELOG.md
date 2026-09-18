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

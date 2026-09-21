## 0.1.0

First release: the Liquid Glass mode of `iphone_duo_ui_pro`, next to its custom navigation mode.
Verified on the iPhone Duo simulator (iOS 27.1, Xcode 27.1) and on an iPhone 18 Pro
simulator (iOS 27.0) with `adaptive_platform_ui` 1.0.1.

* `DuoGlassHost`: wires `DuoScope`, `DuoDisplayFeatures` and `adaptive_platform_ui`'s toolbar host
  around the navigator, and decides the bar pose once for every page below it.
* `DuoGlassScaffold`: the actions and tabs of `DuoAdaptiveScaffold`, drawn by UIKit. On iPhone Duo
  they sit in the vertical bar as native Liquid Glass capsules, in the order Apple gives them; on
  other devices in the native toolbar and tab bar, with an overflow sheet for what does not fit.
* Text-only actions stay next to the title on iPhone Duo: the system never puts a title-only item
  into a vertical bar.
* `backdrop`: a background that runs under the vertical bar, as Apple advises for heroes and
  background images, and that the glass refracts.
* Only the visible copy of the body is built when `adaptive_platform_ui` keeps one per tab.
* Example: both modes behind one switch (the Controls tab, `mode=custom` in the launch options, or
  the `mode=` remote command), fed by the same actions and tabs.

<img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/main/doc/img/liquid-glass.png" alt="iphone_duo_ui_pro_glass - official Liquid Glass bars on iPhone Duo, fold-aware Flutter content underneath" width="100%">

[![pub package](https://img.shields.io/pub/v/iphone_duo_ui_pro_glass.svg)](https://pub.dev/packages/iphone_duo_ui_pro_glass)
[![license: MIT](https://img.shields.io/badge/license-MIT-0F6079.svg)](https://github.com/szymdzie/iphone_duo_ui_pro/blob/main/LICENSE)
[![platform: iOS](https://img.shields.io/badge/platform-iOS-555.svg)](https://pub.dev/packages/iphone_duo_ui_pro_glass)

Flutter paints its own pixels, and Liquid Glass is a system material: it refracts what is behind
it, reacts to light and dark, and changes whenever Apple changes it. A shader can come close. It
cannot be the real thing.

This package does not imitate it. It is the optional companion of
[`iphone_duo_ui_pro`](https://pub.dev/packages/iphone_duo_ui_pro) that hands the bars to UIKit
through [`adaptive_platform_ui`](https://pub.dev/packages/adaptive_platform_ui): `UIGlassEffect`,
`UITabBar` and `UINavigationBar`, hosted as platform views. On iPhone Duo they move into the
vertical bar as native glass capsules, and everything beneath them is still laid out around the
fold by `iphone_duo_ui_pro`.

```sh
flutter pub add iphone_duo_ui_pro_glass
```

## Two modes for the bars

<img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/main/doc/img/two-modes.png" alt="Two modes for the bars: custom navigation drawn by Flutter (DuoAdaptiveScaffold) or official Liquid Glass drawn by UIKit (DuoGlassScaffold), fed by the same actions and tabs" width="100%">

`iphone_duo_ui_pro` has two modes for the bars, and this package is the second one:

| | **Mode 1 · custom navigation** | **Mode 2 · official Liquid Glass** |
| --- | --- | --- |
| Widget | `DuoAdaptiveScaffold` | `DuoGlassScaffold` |
| Package | [`iphone_duo_ui_pro`](https://pub.dev/packages/iphone_duo_ui_pro) | this one |
| Drawn by | Flutter | UIKit |
| Dependencies | none | `adaptive_platform_ui` |

The same `DuoBarAction` and `DuoTab` values feed both, per app or per screen. The core package
stays free of this dependency; add the companion only if you want UIKit's bars. The example
switches between the modes at run time:

<img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/main/packages/iphone_duo_ui_pro_glass/screenshots/two-modes.gif" alt="The same screen switching between custom navigation and Liquid Glass" width="100%">

## On iPhone Duo

<p>
  <img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/main/packages/iphone_duo_ui_pro_glass/screenshots/glass-inner.gif" alt="Inner display of the iPhone Duo simulator folding and unfolding: glass capsules in the vertical bar, panes and grid realigning around the fold" width="62%">
  <img src="https://raw.githubusercontent.com/szymdzie/iphone_duo_ui_pro/main/packages/iphone_duo_ui_pro_glass/screenshots/glass-cover.gif" alt="Cover display: a pushed page gets the system back button in the glass bar" width="36%">
</p>

The inner display folding and unfolding, and the cover display with a pushed page. All recordings
come from the iPhone Duo simulator (iOS 27.1); the angle in the caption is the one the native
bridge reported at that frame.

## Setup

One widget wires both packages around the navigator, in the order that makes them work together:
the bridge, the fold as a `DisplayFeature`, then the fixed toolbar host.

```dart
import 'package:iphone_duo_ui_pro_glass/iphone_duo_ui_pro_glass.dart';

MaterialApp(
  builder: (context, child) => DuoGlassHost(child: child!),
  home: const HomeScreen(),
);
```

`AdaptiveApp` installs a toolbar host of its own, so switch ours off there:

```dart
AdaptiveApp(
  builder: (context, child) => DuoGlassHost(installToolbarHost: false, child: child!),
  home: const HomeScreen(),
);
```

The import re-exports `iphone_duo_ui_pro`, so it is the only one you need. The iOS side is the
core package's: a deployment target of iOS 15, the UIScene life cycle, and the `DUO_SDK_27_1`
flag for the iPhone Duo APIs. Its
[README](https://pub.dev/packages/iphone_duo_ui_pro#ios-271-and-the-duo_sdk_27_1-flag) has the
Podfile snippet.

## The scaffold

`DuoGlassScaffold` takes the same `DuoBarAction` and `DuoTab` values as `DuoAdaptiveScaffold`.
Switching an existing screen is a matter of renaming the widget and adding SF Symbols.

```dart
DuoGlassScaffold(
  title: 'Library',
  prominentAction: DuoBarAction(
    icon: Icons.add, sfSymbol: 'plus', label: 'Add', onPressed: _add,
  ),
  topActions: <DuoBarAction>[
    DuoBarAction(
      icon: Icons.edit_outlined,
      sfSymbol: 'square.and.pencil',
      label: 'Compose',
      priority: DuoVisibilityPriority.high,
      onPressed: _compose,
    ),
    DuoBarAction(icon: Icons.inbox_outlined, sfSymbol: 'tray', label: 'Inbox', onPressed: _inbox),
  ],
  textActions: <DuoTextAction>[DuoTextAction(label: 'Select', onPressed: _select)],
  tabs: const <DuoTab>[
    DuoTab(icon: Icons.photo_library_outlined, sfSymbol: 'photo.on.rectangle', label: 'Library'),
    DuoTab(icon: Icons.grid_view_outlined, sfSymbol: 'square.grid.2x2', label: 'Grid'),
  ],
  selectedTabIndex: _tab,
  onTabSelected: (index) => setState(() => _tab = index),
  backdrop: const HeroGradient(),
  body: FoldAwareTwoPane(startPane: list, endPane: detail),
);
```

The order follows Apple's, and it differs between the two bars, so the scaffold maps the actions
for the bar they end up in:

| | Vertical bar (iPhone Duo) | Horizontal bars |
| --- | --- | --- |
| Back | the system back button, a round glass control on top | the system back button |
| `leading` (Close, Cancel) | a capsule of its own, first | the leading side of the toolbar |
| `prominentAction` | a tinted capsule right below | last on the trailing side |
| `topActions`, `bottomActions` | one capsule each; what does not fit moves into the system overflow menu, from the bottom up | three by `priority`, the rest behind **…** |
| `textActions` | next to the title: the system never puts a title-only item into a vertical bar | ordinary bar buttons |
| `tabs` | a capsule of icons at the bottom of the bar | the floating tab bar |

Give every action an `sfSymbol`. UIKit draws SF Symbols, not Flutter icons: without one the
vertical bar shows your `icon` laid over the native glass, and the horizontal toolbar falls back
to the `label` as text.

### A backdrop under the bar

The body stays out of the strip the system reserves, as UIKit content does. Apple's advice for
what is *behind* it is to extend a hero or a background image under the bar
(`backgroundExtensionEffect`, `UIBackgroundExtensionView`). `backdrop` does that: it fills the
whole window and the scaffold turns transparent above it. It is also what gives the glass
something to refract.

## Where it renders what

| Platform | Bars |
| --- | --- |
| iOS 26 and later | UIKit: `UINavigationBar`, `UITabBar`, `UIGlassEffect` capsules on iPhone Duo |
| iOS 15 to 18 | Cupertino bars |
| Android | Material bars |

The fallbacks are `adaptive_platform_ui`'s. The content widgets behave the same everywhere.

## Good to know

- **The pose is decided once, above the pages.** `DuoGlassHost.poseOf(context)` returns it.
  A page cannot work it out from its own `MediaQuery`: inside a scaffold the top of `viewPadding`
  already includes the title band.
- **The body is built once.** With a tab bar, `adaptive_platform_ui` keeps one copy of the body per
  tab in an `IndexedStack`. The scaffold builds only the visible one, so a heavy screen or a
  `GlobalKey` in the body is safe. The scaffold is re-created on every tab change; keep the state
  you care about above it.
- **Not everything maps.** Bar buttons have no badge and no disabled style, so
  `DuoBarAction.badgeCount` is ignored and an action without `onPressed` stays tappable and does
  nothing. Tab badges work.
- **Platform views sit above Flutter.** A Flutter overlay you draw over the bars ends up under the
  glass. Route-level UI (dialogs, sheets) is fine: the bars dim and stop taking touches.

## Tested on

The iPhone Duo simulator (iOS 27.1, Xcode 27.1): the cover display in portrait, the inner display
in landscape, flat and half open (book pose), and in portrait, each in light and dark. An iPhone 18
Pro simulator (iOS 27.0) for the horizontal bars. Not tested yet: the cover display in landscape,
the tabletop pose, Split View, right-to-left, and a physical iPhone Duo.

```sh
cd example && flutter run
```

## Credits

The native views, the fixed toolbar and the vertical bar itself are the work of
[`adaptive_platform_ui`](https://pub.dev/packages/adaptive_platform_ui) (MIT, Berkay Çatak). This
package adds the fold-aware half and the glue. Liquid Glass, UIKit and iPhone are Apple's.

## License

MIT — see [LICENSE](https://github.com/szymdzie/iphone_duo_ui_pro/blob/main/LICENSE).

# iphone_duo_ui_pro_glass example

The gallery of `iphone_duo_ui_pro`, with the bars handed to UIKit: a native Liquid Glass toolbar
and tab bar, which on iPhone Duo move into the vertical bar as glass capsules. The content below
them is Flutter, laid out around the fold.

```sh
cd example
flutter run
```

The gallery runs in both modes of `iphone_duo_ui_pro`: the Controls tab switches the bars between
UIKit glass (`DuoGlassScaffold`) and Flutter (`DuoAdaptiveScaffold`). The actions and tabs are built
once and handed to whichever scaffold is on.

Four tabs: a two-pane library split on the fold (a single list with pushed pages on the cover
display), a fold-aligned grid, native glass controls, and the live values of the bridge.

Building with Xcode 27.1 has two quirks; the core package's README lists them under "Building with
Xcode 27.1", and `ios/Podfile` here carries both settings.

## Driving it without touching the screen

Taps sent to a simulator in the background never arrive, so the app reads two files from the `tmp`
folder of its data container:

```sh
C=$(xcrun simctl get_app_container booted com.szymondziedzic.iphoneDuoGlassExample data)
echo "tab=1;remote=1;mode=glass" > "$C/tmp/duo_launch.txt"   # read once, at launch (mode=custom for Flutter bars)
echo "$(date +%s):tab=2" > "$C/tmp/duo_cmd.txt"     # polled while remote=1
```

Commands: `tab=0…3`, `select=4`, `open=2` (push a session page), `back`, `alert`, `scroll=640`,
`mode=custom`, `mode=glass`.
The part before the colon only has to change, so the same command can be sent twice.

Every environment change is logged as `DUO-ENV …` and every command as `DUO-CMD …`:

```sh
xcrun simctl spawn booted log show --last 30s --predicate 'eventMessage CONTAINS "DUO-"'
```

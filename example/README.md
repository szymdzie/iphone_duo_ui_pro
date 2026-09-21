# iphone_duo_ui_pro example

A gallery of every widget in the package: the vertical bar (`DuoAdaptiveScaffold`),
a two-pane layout split on the fold (`FoldAwareTwoPane`), a fold-aligned grid
(`FoldAlignedGrid`), anchored dialogs and sheets, and a live readout of the
values the native bridge reports.

```sh
cd example
flutter run
```

Drag the simulator edges, or open and close an iPhone Duo in Device Hub, and
watch the navigation move into the vertical bar while the panes and the grid
realign around the hinge.

## Launch options

For screenshots and Device Hub checks the app reads `tmp/duo_launch.txt` from its data container:

```sh
C=$(xcrun simctl get_app_container booted com.szymondziedzic.iphoneDuoUiProExample data)
echo "tab=1;scroll_end=1;remote=1" > "$C/tmp/duo_launch.txt"   # 0 Library, 1 Grid, 2 Bridge
```

Taps sent to a simulator in the background never arrive. With `remote=1` in the launch options
the app also polls `tmp/duo_cmd.txt`, so the host can drive it while Device Hub changes the pose:

```sh
echo "$(date +%s):tab=1" > "$C/tmp/duo_cmd.txt"   # tab=0…2, select=4, dialog, sheet, back
```

The part before the colon only has to change, so the same command can be sent twice.

Every environment change is also logged as `DUO-ENV …`, readable with
`xcrun simctl spawn booted log show --last 30s --predicate 'eventMessage CONTAINS "DUO-ENV"'`.

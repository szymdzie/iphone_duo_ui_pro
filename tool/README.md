# Tools for the README media

Nothing here ships with the package (`tool/` is in `.pubignore`).

* `readme_gif.py <config.json>` frames a `simctl io recordVideo` capture in a drawn device, marks
  the fold, and captions every frame with the pose. The caption is driven by the app's own log
  (`DUO-ENV`, `DUO-CMD`), so the angle shown is the angle the bridge reported at that moment.
* `readme_still.py <config.json>` does the same for one `simctl io screenshot`, at 2x.

* `publish_glass.sh [--dry-run] [--local]` publishes `packages/iphone_duo_ui_pro_glass` from a copy
  outside the repository. The core package keeps `packages/` out of its own archive with
  `.pubignore`, and pub applies a parent's ignore file to a nested package too, so published in
  place the companion comes out empty. Publish the core first: the companion needs its version.

Recording recipe (Xcode 27.1, iPhone Duo simulator):

1. Launch an example with `remote=1` in `tmp/duo_launch.txt`.
2. `xcrun simctl io <udid> recordVideo --codec=h264 out.mov` for the inner display; add
   `--display=<UUID>` for the cover display (the second `Display class: 0` port of
   `simctl io <udid> enumerate`).
3. Change tabs through `tmp/duo_cmd.txt`, poses with the Closed / Book / Open buttons of Device Hub.
4. Stop with `kill -INT`, then sync: the first `hinge=` line of the log is the first scene change
   of the video (`ffmpeg -vf "select='gt(scene,0.02)',showinfo"`). That offset is `t0` in the config.

Needs Python 3.9+, Pillow and ffmpeg. `doc/img/src/liquid-glass.html` is the source of the Liquid
Glass graphic: render it with headless Chrome at `--window-size=1200,630
--force-device-scale-factor=2`.

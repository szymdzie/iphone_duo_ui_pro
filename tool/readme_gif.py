#!/usr/bin/env python3
"""Compose a README GIF from a simulator recording.

Frames come from `simctl io recordVideo`; the pose caption and the hinge glyph
are driven by the app's own log (DUO-ENV / DUO-CMD lines with timestamps), so
the angle shown is the angle the bridge reported at that moment.

usage: make_gif.py <config.json>
Python 3.9 compatible.
"""
import json
import math
import os
import subprocess
import sys
from typing import List, Optional, Tuple

from PIL import Image, ImageDraw, ImageFont

BG = (241, 244, 248)
INK = (18, 26, 34)
MUTED = (85, 97, 110)
TEAL = (15, 96, 121)
BEZEL = (22, 27, 34)
LINE = (182, 194, 207)

MENLO = "/System/Library/Fonts/Menlo.ttc"
HELV = "/System/Library/Fonts/HelveticaNeue.ttc"


def font(path: str, size: int, index: int = 0) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size, index=index)


def seconds(clock: str) -> float:
    h, m, s = clock.split(":")
    return int(h) * 3600 + int(m) * 60 + float(s)


def load_events(path: str, t0: float):
    hinge: List[Tuple[float, float, str]] = []
    tabs: List[Tuple[float, str]] = []
    if not path or not os.path.exists(path):
        return hinge, tabs
    for line in open(path):
        parts = line.split()
        if len(parts) < 3:
            continue
        t = seconds(parts[0]) - t0
        if parts[1] == "HINGE":
            hinge.append((t, float(parts[3]), parts[2]))
        elif parts[1] == "CMD":
            tabs.append((t, parts[2]))
    return hinge, tabs


def angle_at(hinge, t: float, default: float) -> float:
    if not hinge:
        return default
    if t <= hinge[0][0]:
        # Before the first reading the device is in the pose it started in.
        return default
    for (t1, a1, _), (t2, a2, _) in zip(hinge, hinge[1:]):
        if t1 <= t <= t2:
            if t2 - t1 > 1.5:  # a hold, not a movement
                return a1
            return a1 + (a2 - a1) * (t - t1) / max(t2 - t1, 1e-6)
    return hinge[-1][1]


def draw_hinge(draw: ImageDraw.ImageDraw, cx: float, cy: float, angle: float, scale: float = 1.0):
    """A device seen from above: two leaves meeting at the hinge."""
    arm = 26 * scale
    half = math.radians((180 - angle) / 2)
    # Leaves rise symmetrically from the hinge as the device folds.
    lx, ly = cx - arm * math.cos(half), cy - arm * math.sin(half)
    rx, ry = cx + arm * math.cos(half), cy - arm * math.sin(half)
    w = max(2, int(4 * scale))
    draw.line([(lx, ly), (cx, cy)], fill=INK, width=w)
    draw.line([(cx, cy), (rx, ry)], fill=INK, width=w)
    r = 4 * scale
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=TEAL)


def rounded_mask(size: Tuple[int, int], radius: int, ss: int = 4) -> Image.Image:
    big = Image.new("L", (size[0] * ss, size[1] * ss), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        [0, 0, big.size[0] - 1, big.size[1] - 1], radius=radius * ss, fill=255
    )
    return big.resize(size, Image.LANCZOS)


def main() -> None:
    cfg = json.load(open(sys.argv[1]))
    out_dir = cfg["work"]
    os.makedirs(out_dir, exist_ok=True)
    fps = cfg.get("fps", 12)
    sw, sh = cfg["screen"]  # size of the screen inside the frame
    pad = cfg.get("bezel", 12)
    cw, ch = cfg["canvas"]
    dx = (cw - (sw + 2 * pad)) // 2
    dy = cfg.get("top", 24)
    t0 = seconds(cfg["t0"]) if cfg.get("t0") else 0.0
    hinge, tabs = load_events(cfg.get("events", ""), t0)
    tab_names = cfg.get("tabs", [])
    fold_x = cfg.get("fold")  # 0..1 across the screen, or None

    # 1. frames of every segment, already scaled
    frames: List[Tuple[float, str]] = []
    for i, (a, b) in enumerate(cfg["segments"]):
        pattern = os.path.join(out_dir, "seg%02d_%%04d.png" % i)
        subprocess.run(
            [
                "ffmpeg", "-v", "error", "-y", "-ss", str(a), "-to", str(b),
                "-i", cfg["video"], "-vf",
                "fps=%d,scale=%d:%d:flags=lanczos" % (fps, sw, sh), pattern,
            ],
            check=True,
        )
        n = 1
        while os.path.exists(pattern % n):
            frames.append((a + (n - 1) / fps, pattern % n))
            n += 1

    mask = rounded_mask((sw, sh), cfg.get("radius", 26))
    f_pose = font(MENLO, 19, 1)
    f_note = font(HELV, 15)
    f_tab = font(MENLO, 14)

    composed = []
    for k, (t, path) in enumerate(frames):
        canvas = Image.new("RGB", (cw, ch), BG)
        d = ImageDraw.Draw(canvas)
        # device
        d.rounded_rectangle(
            [dx, dy, dx + sw + 2 * pad, dy + sh + 2 * pad],
            radius=cfg.get("radius", 26) + pad - 2, fill=BEZEL,
        )
        screen = Image.open(path).convert("RGB")
        canvas.paste(screen, (dx + pad, dy + pad), mask)
        # where the hinge is
        if fold_x is not None:
            fx = dx + pad + sw * fold_x
            for y0, y1 in ((dy - 12, dy - 4), (dy + sh + 2 * pad + 4, dy + sh + 2 * pad + 12)):
                d.line([(fx, y0), (fx, y1)], fill=TEAL, width=3)

        # caption
        base = dy + sh + 2 * pad + cfg.get("caption_gap", 30)
        angle = angle_at(hinge, t, cfg.get("angle", 180.0))
        if cfg.get("pose_label"):
            pose = cfg["pose_label"]
        elif angle >= 176:
            pose = "Open"
        elif angle <= 1:
            pose = "Closed"
        else:
            pose = "Book"
        glyph_x = dx + 34
        draw_hinge(d, glyph_x, base + 22, angle if not cfg.get("pose_label") else cfg.get("angle", 0.0))
        d.text((glyph_x + 44, base + 2), "%s · %d°" % (pose, round(angle)), font=f_pose, fill=INK)
        tab = cfg.get("tab0", "")
        page = tab
        mode = cfg.get("mode0", "")
        modes = cfg.get("modes", {})
        for (tt, cmd) in tabs:
            # The first frame after a seek is a little late, so lead the label.
            if tt > t + cfg.get("label_lead", 0.3):
                continue
            if cmd.startswith("tab=") and tab_names:
                tab = tab_names[int(cmd.split("=")[1])]
                page = tab
            elif cmd.startswith("open="):
                tab = "Session %d · pushed page" % (int(cmd.split("=")[1]) + 1)
            elif cmd == "back":
                tab = page
            elif cmd.startswith("mode="):
                mode = cmd.split("=")[1]
        if mode and modes:
            tab = "%s · %s" % (tab, modes.get(mode, mode)) if tab else modes.get(mode, mode)
        if tab:
            d.text((glyph_x + 44, base + 28), tab, font=f_tab, fill=MUTED)
        note = cfg.get("note", "")
        if note:
            lines = note.split("\n")
            for li, text in enumerate(lines):
                w = d.textlength(text, font=f_note)
                d.text((dx + sw + 2 * pad - w - 4, base + 4 + li * 21), text, font=f_note, fill=MUTED)
        out = os.path.join(out_dir, "c_%04d.png" % k)
        canvas.save(out)
        composed.append(out)

    # 2. GIF with a palette of its own
    palette = os.path.join(out_dir, "palette.png")
    inp = os.path.join(out_dir, "c_%04d.png")
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-framerate", str(fps), "-i", inp, "-vf",
         "palettegen=max_colors=%d:stats_mode=diff" % cfg.get("colors", 200), palette],
        check=True,
    )
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-framerate", str(fps), "-i", inp, "-i", palette,
         "-lavfi", "paletteuse=dither=bayer:bayer_scale=%d:diff_mode=rectangle" % cfg.get("bayer", 4),
         "-loop", "0", cfg["out"]],
        check=True,
    )
    print("%s: %d frames, %.1f s, %.2f MB" % (
        cfg["out"], len(composed), len(composed) / fps, os.path.getsize(cfg["out"]) / 1e6))
    # a poster frame for quick review
    Image.open(composed[min(len(composed) - 1, cfg.get("poster", 30))]).save(cfg["out"].replace(".gif", "-poster.png"))


if __name__ == "__main__":
    main()

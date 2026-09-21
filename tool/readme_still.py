#!/usr/bin/env python3
"""One framed still, drawn like the GIF frames but at 2x. usage: make_still.py <json>"""
import json, sys
from PIL import Image, ImageDraw
import readme_gif as g

def main():
    c = json.load(open(sys.argv[1]))
    k = c.get("scale", 2)
    cw, ch = [v * k for v in c["canvas"]]
    sw, sh = [v * k for v in c["screen"]]
    pad, dy, radius = c.get("bezel", 12) * k, c.get("top", 26) * k, c.get("radius", 26) * k
    dx = (cw - (sw + 2 * pad)) // 2
    canvas = Image.new("RGB", (cw, ch), g.BG)
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle([dx, dy, dx + sw + 2 * pad, dy + sh + 2 * pad], radius=radius + pad - 2 * k, fill=g.BEZEL)
    screen = Image.open(c["image"]).convert("RGB").resize((sw, sh), Image.LANCZOS)
    canvas.paste(screen, (dx + pad, dy + pad), g.rounded_mask((sw, sh), radius, ss=2))
    if c.get("fold") is not None:
        fx = dx + pad + sw * c["fold"]
        for y0, y1 in ((dy - 12 * k, dy - 4 * k), (dy + sh + 2 * pad + 4 * k, dy + sh + 2 * pad + 12 * k)):
            d.line([(fx, y0), (fx, y1)], fill=g.TEAL, width=3 * k)
    base = dy + sh + 2 * pad + 30 * k
    gx = dx + 34 * k
    g.draw_hinge(d, gx, base + 22 * k, c["angle"], scale=k)
    d.text((gx + 44 * k, base + 2 * k), "%s · %d°" % (c["pose"], c["angle"]), font=g.font(g.MENLO, 19 * k, 1), fill=g.INK)
    d.text((gx + 44 * k, base + 28 * k), c.get("tab", ""), font=g.font(g.MENLO, 14 * k), fill=g.MUTED)
    author = c.get("author")
    if author:
        # photo, name and LinkedIn at the trailing end of the caption row
        size = 48 * k
        photo = Image.open(author["photo"]).convert("RGB").resize((size, size), Image.LANCZOS)
        f_name = g.font(g.HELV, 15 * k)
        f_link = g.font(g.MENLO, int(12.5 * k))
        text_w = max(d.textlength(author["name"], font=f_name), d.textlength(author["link"], font=f_link))
        right = dx + sw + 2 * pad - 4 * k
        ax = int(right - text_w - 14 * k - size)
        ay = int(base - 10 * k)
        canvas.paste(photo, (ax, ay), g.rounded_mask((size, size), size // 2, ss=2))
        d.ellipse([ax, ay, ax + size, ay + size], outline=g.LINE, width=max(2, int(1.5 * k)))
        d.text((ax + size + 14 * k, ay + 5 * k), author["name"], font=f_name, fill=g.INK)
        d.text((ax + size + 14 * k, ay + 26 * k), author["link"], font=f_link, fill=g.TEAL)
        c["note"] = ""
    f_note = g.font(g.HELV, 15 * k)
    for li, text in enumerate(c.get("note", "").split("\n")):
        if not text:
            continue
        w = d.textlength(text, font=f_note)
        d.text((dx + sw + 2 * pad - w - 4 * k, base + 4 * k + li * 21 * k), text, font=f_note, fill=g.MUTED)
    canvas.save(c["out"], optimize=True)
    print(c["out"], canvas.size)

main()

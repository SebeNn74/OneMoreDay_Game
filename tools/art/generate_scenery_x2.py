"""Scenarios of One More Day in "pixel x2": drawn natively at half resolution and scaled x2, so the scenery
has the same pixel density as the characters (16x24 sprites shown at scale 2) and signs stay readable.

Run from the repository root:
    python tools/art/generate_scenery_x2.py
    ART_PREVIEW=<folder> python tools/art/generate_scenery_x2.py     (also writes composite previews)

Every scenario has 3 layers, like the home:
  1. floor   environment/<street|office>/bg_<level>_floor.png  (level size)  -> World/Background/Floor
  2. walls   environment/<street|office>/bg_<level>_walls.png  (level size)  -> World/Background/Walls
  3. objects environment/<street|office>/decoration/obj_*.png  (one per object) -> props in World/Entities
Street objects also come as *_dusk / *_night for the Vuelta levels (their light is baked in).
"""
from __future__ import annotations

import importlib.util
import math
import os
import random
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("art", HERE / "generate_missing_art.py")
art = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(art)
hexc, shade, new, rect, px, text, text_width = art.hexc, art.shade, art.new, art.rect, art.px, art.text, art.text_width
PAL, BAYER, outline, grade, line = art.PAL, art.BAYER, art.outline, art.grade, art.line
DUSK, EVENING, NIGHT = art.DUSK, art.EVENING, art.NIGHT
STREET, OFFICE = art.STREET, art.OFFICE
OUT = (26, 26, 26, 255)
PREVIEW = Path(os.environ["ART_PREVIEW"]) if os.environ.get("ART_PREVIEW") else None

# Half-resolution street layout (x2 on screen: facades 0-95, sidewalk 96-145, road 152-273, sidewalk 280+).
FACADE_H = 48
SIDE_TOP, CURB_TOP, ROAD, CURB_BOT, SIDE_BOT = (48, 72), 73, (76, 136), 137, 140


def x2(im: Image.Image) -> Image.Image:
    return im.resize((im.width * 2, im.height * 2), Image.NEAREST)


def shadowed(sprite: Image.Image, w: int) -> Image.Image:
    out = new(sprite.width, sprite.height + 2)
    cx = sprite.width // 2
    ImageDraw.Draw(out).ellipse([cx - w // 2, sprite.height - 3, cx + w // 2, sprite.height + 1], fill=(0, 0, 0, 60))
    out.alpha_composite(sprite)
    return out


def board(im, x, y, label, color, ink, pad=3):
    """Sign board with the 3x5 font: 7 px tall, outlined. Returns its width."""
    w = text_width(label) + pad * 2
    rect(im, x - 1, y - 1, x + w, y + 7, OUT)
    rect(im, x, y, x + w - 1, y + 6, color)
    rect(im, x, y, x + w - 1, y, shade(color, 1.25))
    text(im, x + pad, y + 1, label, ink)
    return w


# ---------------------------------------------------------------- street floor

def sidewalk(im, x0, y0, x1, y1, rng, pavers=False):
    w, h = (6, 4) if pavers else (12, 8)
    for sy in range(y0, y1 + 1, h):
        off = w // 2 if ((sy - y0) // h) % 2 else 0
        for sx in range(x0 - off, x1 + 1, w):
            if pavers:
                base = hexc("a8a296") if ((sy - y0) // h) % 5 == 2 else hexc("b36c54")
            else:
                base = PAL["slab"]
            base = shade(base, rng.uniform(0.96, 1.04))
            a0, b0, a1, b1 = max(sx, x0), sy, min(sx + w - 1, x1), min(sy + h - 1, y1)
            rect(im, a0, b0, a1, b1, base)
            rect(im, a0, b0, a1, b0, shade(base, 1.09))
            rect(im, a1, b0, a1, b1, PAL["grout"])
            rect(im, a0, b1, a1, b1, PAL["grout"])
            if not pavers and a1 - a0 > 4 and b1 - b0 > 3:
                if rng.random() < 0.1:
                    cx, cy = rng.randint(a0 + 1, a1 - 2), rng.randint(b0 + 1, b1 - 2)
                    px(im, cx, cy, shade(base, 0.78))
                    px(im, cx + 1, cy + rng.choice((0, 1)), shade(base, 0.78))
                if rng.random() < 0.08:
                    px(im, rng.randint(a0 + 1, a1 - 1), b1 - 1, PAL["leaf"])


def tactile(im, x0, y, x1):
    rect(im, x0, y, x1, y + 3, hexc("d8b23a"))
    rect(im, x0, y, x1, y, hexc("ecc85a"))
    for x in range(x0 + 1, x1, 2):
        px(im, x, y + 2, hexc("b8962c"))


def tree_pit(im, x, y):
    rect(im, x, y, x + 11, y + 5, PAL["curb_face"])
    rect(im, x + 1, y + 1, x + 10, y + 4, PAL["soil"])
    for k in range(2, 10, 3):
        px(im, x + k, y + 3, PAL["grass_hi"])


def curb(im, x0, y0, x1, painted=()):
    rect(im, x0, y0, x1, y0, PAL["curb_top"])
    rect(im, x0, y0 + 1, x1, y0 + 1, PAL["curb_face"])
    rect(im, x0, y0 + 2, x1, y0 + 2, PAL["curb_dark"])
    for a, b in painted:
        for x in range(a, b + 1):
            rect(im, x, y0, x, y0 + 1, hexc("e2bf48") if (x // 4) % 2 == 0 else hexc("2a2a2e"))


def asphalt(im, x0, y0, x1, y1, rng, crossings=(), bus_at=None, bike=False):
    art.mottle(im, x0, y0, x1, y1, PAL["asphalt"], PAL["asphalt_hi"], PAL["asphalt_lo"], rng.randint(0, 999), cell=22, spread=0.11)
    art.speckle(im, x0, y0, x1, y1, [hexc("5c5f68"), hexc("44474e")], 0.03, rng)
    mid = (y0 + y1) // 2
    for x in range(x0, x1, 20):
        rect(im, x + 4, mid, x + 13, mid, PAL["paint_y"])
    rect(im, x0, y0 + 2, x1, y0 + 2, PAL["paint_w"])
    rect(im, x0, y1 - 2, x1, y1 - 2, PAL["paint_w"])
    if bike:
        rect(im, x0, y0 + 3, x1, y0 + 9, hexc("4e8a58"))
        rect(im, x0, y0 + 10, x1, y0 + 10, PAL["paint_w"])
        for bx in range(x0 + 30, x1, 100):
            ImageDraw.Draw(im).ellipse([bx, y0 + 5, bx + 3, y0 + 8], outline=PAL["paint_w"])
            ImageDraw.Draw(im).ellipse([bx + 6, y0 + 5, bx + 9, y0 + 8], outline=PAL["paint_w"])
            line(im, bx + 2, y0 + 6, bx + 5, y0 + 5, PAL["paint_w"])
            line(im, bx + 5, y0 + 5, bx + 7, y0 + 6, PAL["paint_w"])
    for _ in range((x1 - x0) // 100 + 1):
        rx, ry = rng.randint(x0 + 10, x1 - 30), rng.randint(y0 + 12, y1 - 14)
        rect(im, rx, ry, rx + rng.randint(10, 20), ry + rng.randint(4, 7), hexc("474a51"))
    for _ in range((x1 - x0) // 80 + 1):
        x, y = rng.randint(x0, x1 - 8), rng.randint(y0 + 12, y1 - 4)
        for k in range(rng.randint(3, 7)):
            px(im, x + k, y + (k // 3) % 2, hexc("3a3b40"))
    for cx in crossings:
        rect(im, cx - 3, y0 + 4, cx - 2, y1 - 4, PAL["paint_w"])
        for y in range(y0 + 5, y1 - 4, 5):
            rect(im, cx, y, cx + 15, y + 2, PAL["paint_w"])
    if bus_at is not None:
        text(im, bus_at, y0 + 6, "BUS", PAL["paint_y"], size=2)
    for x in range(x0 + 40, x1 - 8, 120):
        for yy in (y0 + 1, y1 - 3):
            rect(im, x, yy, x + 7, yy + 2, hexc("2a2b30"))
            for gx in range(x + 1, x + 7, 2):
                px(im, gx, yy + 1, hexc("15161a"))
    for x in range(x0 + 90, x1 - 10, 200):
        ImageDraw.Draw(im).ellipse([x, mid + 12, x + 8, mid + 18], fill=hexc("3a3b40"), outline=hexc("2a2b30"))


def grass(im, x0, y0, x1, y1, rng):
    art.mottle(im, x0, y0, x1, y1, PAL["grass"], PAL["grass_hi"], PAL["grass_lo"], rng.randint(0, 999), cell=10, spread=0.12)
    for _ in range((x1 - x0) * (y1 - y0) // 40):
        px(im, rng.randint(x0, x1), rng.randint(y0, y1), PAL["grass_hi"])
    for _ in range((x1 - x0) * (y1 - y0) // 300):
        x, y = rng.randint(x0 + 1, x1 - 1), rng.randint(y0 + 1, y1 - 1)
        px(im, x, y, rng.choice((hexc("f4f0e0"), hexc("f0d060"), hexc("e88aa8"))))


def puddle(im, cx, cy, rx, seed):
    art.blob(im, cx, cy, rx, 2, hexc("6a7c90"), seed, rough=0.3)
    rect(im, cx - rx // 2, cy - 1, cx, cy - 1, hexc("9ab0c4"))


# ---------------------------------------------------------------- street walls (facades)

def roof(im, x0, x1, top, bottom):
    for y in range(top, bottom + 1):
        row = (y - top) // 3
        for x in range(x0, x1 + 1):
            phase, tx = (y - top) % 3, (x - x0 + (row % 2) * 2) % 4
            px(im, x, y, PAL["roof_hi"] if phase == 0 else (PAL["roof_lo"] if phase == 2 else (hexc("a24c33") if tx == 0 else PAL["roof"])))
    rect(im, x0, bottom + 1, x1, bottom + 1, PAL["roof_edge"])


def plaster(im, x0, x1, top, bottom, color, rng):
    wall = hexc(color)
    art.mottle(im, x0, top, x1, bottom, wall, shade(wall, 1.04), shade(wall, 0.94), rng.randint(0, 999), cell=8, spread=0.17)
    for _ in range(max(1, (x1 - x0) // 25)):
        art.blob(im, rng.randint(x0, x1), rng.randint(bottom - 8, bottom), rng.randint(3, 6), rng.randint(2, 3),
                 shade(wall, 0.86), rng.randint(0, 999))
    rect(im, x0, top, x1, top, shade(wall, 0.72))


def window(im, x, y, w, h, lit, curtain, reja=True):
    rect(im, x - 1, y - 1, x + w, y + h, PAL["frame"])
    rect(im, x + w, y - 1, x + w, y + h, shade(PAL["frame"], 0.8))
    for yy in range(y, y + h):
        t = (yy - y) / max(1, h - 1)
        rect(im, x, yy, x + w - 1, yy, tuple(int(PAL["glass_top"][i] + (PAL["glass_bot"][i] - PAL["glass_top"][i]) * t) for i in range(3)) + (255,))
    px(im, x + w - 2, y + 1, hexc("c8dce6"))
    px(im, x + w - 3, y + 2, hexc("c8dce6"))
    if curtain:
        rect(im, x, y, x, y + h - 1, curtain)
        rect(im, x + w - 1, y, x + w - 1, y + h - 1, curtain)
    lit.append((x, y, x + w - 1, y + h - 1))
    if reja:
        for gx in range(x + 2, x + w - 1, 3):
            rect(im, gx, y, gx, y + h - 1, PAL["reja"])
    rect(im, x - 1, y + h + 1, x + w, y + h + 1, hexc("9a8e78"))


def door(im, x, y, w, bottom, color):
    rect(im, x - 1, y - 1, x + w, bottom, OUT)
    rect(im, x, y, x + w - 1, bottom, color)
    rect(im, x, y, x + w - 1, y, shade(color, 1.2))
    rect(im, x + 2, y + 3, x + w - 3, y + 8, shade(color, 0.8))
    rect(im, x + 2, y + 11, x + w - 3, bottom - 3, shade(color, 0.8))
    px(im, x + w - 2, (y + bottom) // 2, hexc("e3c060"))


def house(im, x0, x1, color, rng, lit, home=False):
    roof(im, x0, x1, 0, 6)
    plaster(im, x0, x1, 8, FACADE_H - 5, color, rng)
    wall = hexc(color)
    rect(im, x0, FACADE_H - 4, x1, FACADE_H - 1, shade(wall, 0.72))
    rect(im, x0, FACADE_H - 4, x1, FACADE_H - 4, shade(wall, 0.86))
    curtain = hexc(rng.choice(["e8d8a0", "d88a8a", "a8c8e0", "f0f0e8"]))
    dx = x0 + (x1 - x0) // 2 - 5 if home else x0 + rng.randint(5, max(5, x1 - x0 - 16))
    door(im, dx, 24, 10, FACADE_H - 2, hexc("8a5a34") if home else hexc(rng.choice(["8a5a34", "3c6aa0", "4a7a5a", "8a3a34"])))
    if home:
        board(im, dx - 3, 15, "CASA", hexc("f4f0e8"), hexc("3c6aa0"))
        rect(im, dx + 12, 22, dx + 13, 23, hexc("f8e8a8"))
        lit.append((dx + 11, 21, dx + 14, 24))
        rect(im, dx - 2, FACADE_H - 1, dx + 11, FACADE_H - 1, hexc("8a3a34"))
    for wx in range(x0 + 4, x1 - 12, 17):
        if wx + 12 < dx - 1 or wx > dx + 12:
            window(im, wx, 25, 11, 9, lit, curtain)
            if rng.random() < 0.4:
                rect(im, wx, 34, wx + 10, 35, hexc("b0543a"))
                for k in range(wx, wx + 11, 2):
                    px(im, k, 33, rng.choice((PAL["leaf_hi"], hexc("e04860"))))
    if (x1 - x0) >= 60 and rng.random() < 0.5:
        for wx in range(x0 + 6, x1 - 10, 16):
            window(im, wx, 11, 8, 6, lit, curtain, reja=False)
    if rng.random() < 0.5:
        rect(im, x1 - 6, 28, x1 - 3, 32, hexc("9aa2a8"))
        px(im, x1 - 5, 29, hexc("d8e0e4"))


SHOPS = [("TIENDA", "b03a3a", "f4f0e0", ("c83c3c", "f4f0e8")), ("PANADERIA", "6f4932", "f4e0a0", ("e3b55a", "f4f0e8")),
         ("DROGUERIA", "2e8a4a", "f4fff4", ("3c8a4c", "f4f0e8")), ("VARIEDADES", "3c6aa0", "f4f0e0", ("3c6aa0", "f0d060")),
         ("CAFE", "4a321c", "f0d8a0", ("8a3a34", "e9dcbc"))]


def shop(im, x0, x1, kind, color, rng, lit):
    name, board_c, ink, stripes = kind
    roof(im, x0, x1, 0, 4)
    plaster(im, x0, x1, 6, FACADE_H - 1, color, rng)
    bw = text_width(name) + 6
    bx = x0 + ((x1 - x0 + 1) - bw) // 2
    board(im, bx, 9, name, hexc(board_c), hexc(ink))
    if name == "DROGUERIA":
        cx = bx - 7 if bx - 7 > x0 + 1 else bx + bw + 2
        rect(im, cx + 2, 9, cx + 3, 15, hexc("3cc060"))
        rect(im, cx, 11, cx + 5, 13, hexc("3cc060"))
    for x in range(x0 + 2, x1 - 1):
        c = hexc(stripes[((x - x0) // 3) % 2])
        rect(im, x, 18, x, 22, c)
        px(im, x, 18, shade(c, 0.8))
        if (x - x0) % 3 != 0:
            px(im, x, 23, c)
    rect(im, x0 + 2, 17, x1 - 2, 17, OUT)
    rect(im, x0 + 3, 24, x1 - 3, FACADE_H - 2, hexc("2c2420"))
    goods = [hexc(c) for c in ("d03a3a", "f0d060", "4ab050", "f4f0e8", "3c6aa0", "e88a40")]
    if name == "PANADERIA":
        goods = [hexc("d89048"), hexc("c87838"), hexc("e8b060")]
    for sy in (30, 36):
        rect(im, x0 + 4, sy, x1 - 4, sy, hexc("6b4a2b"))
        for x in range(x0 + 5, x1 - 4, 2):
            rect(im, x, sy - rng.randint(2, 3), x, sy - 1, rng.choice(goods))
    lit.append((x0 + 3, 24, x1 - 3, 38))
    rect(im, x0 + 5, 40, x1 - 5, FACADE_H - 2, hexc(board_c))
    rect(im, x0 + 5, 40, x1 - 5, 40, hexc("cde4ee"))
    rect(im, x0, FACADE_H - 1, x1, FACADE_H - 1, shade(hexc(color), 0.65))


def tower(im, x0, x1, rng, lit, entrance=False):
    """Office tower: glass curtain wall with sky reflection over a granite podium."""
    top_c, bot_c = hexc("9ec0da"), hexc("4a6a88")
    podium = FACADE_H - 16
    for y in range(0, podium):
        t = y / podium
        rect(im, x0, y, x1, y, tuple(int(top_c[i] + (bot_c[i] - top_c[i]) * t) for i in range(3)) + (255,))
    for k in range(x0 - 30, x1, 36):
        for i in range(podium):
            for wdt in range(3):
                art.lighten(im, k + i + wdt, podium - 1 - i, 0.16)
    for x in range(x0, x1 + 1, 8):
        rect(im, x, 0, x, podium - 1, hexc("36404c"))
    for y in range(0, podium, 6):
        rect(im, x0, y, x1, y, hexc("36404c"))
    for wy in range(1, podium - 5, 6):
        for wx in range(x0 + 1, x1 - 6, 8):
            if rng.random() < 0.35:
                lit.append((wx, wy, wx + 6, wy + 4))
    rect(im, x0, podium, x1, FACADE_H - 1, hexc("8c8a86"))
    for gy in range(podium, FACADE_H, 5):
        rect(im, x0, gy, x1, gy, hexc("74726e"))
    rect(im, x0, podium, x1, podium, hexc("b4b2ae"))
    if entrance:
        ex = x1 - 44
        rect(im, ex - 3, podium - 6, ex + 40, podium - 1, hexc("2a3440"))
        rect(im, ex - 3, podium - 1, ex + 40, podium - 1, hexc("c8a84a"))
        text(im, ex + (38 - text_width("OFICINAS")) // 2, podium - 6, "OFICINAS", hexc("f0e0a0"))
        rect(im, ex + 2, podium + 1, ex + 35, FACADE_H - 2, hexc("2a3440"))
        for dx in (ex + 3, ex + 19):
            rect(im, dx, podium + 2, dx + 14, FACADE_H - 2, hexc("a8c8dc"))
            px(im, dx + 10, podium + 3, hexc("dcecf4"))
            px(im, dx + 9, podium + 4, hexc("dcecf4"))
        lit.append((ex + 3, podium + 2, ex + 34, FACADE_H - 2))


def cables(im, width):
    poles = list(range(0, width + 1, 160))
    for a, b in zip(poles, poles[1:]):
        for base, sag in ((1, 3), (2, 4)):
            prev = None
            for x in range(a, b + 1):
                t = (x - a) / max(1, b - a)
                y = int(base + sag * 4 * t * (1 - t))
                if prev is not None:
                    line(im, x - 1, prev, x, y, hexc("1e1e1e"))
                prev = y


def rail(im, y0, y1):
    w = im.width
    rect(im, 0, y1 - 3, w - 1, y1, hexc("a8a498"))
    rect(im, 0, y1 - 3, w - 1, y1 - 3, hexc("cecabe"))
    rect(im, 0, y1, w - 1, y1, OUT)
    rect(im, 0, y0, w - 1, y0, PAL["metal_hi"])
    rect(im, 0, y0 + 1, w - 1, y0 + 1, PAL["metal_lo"])
    for x in range(1, w, 3):
        rect(im, x, y0 + 2, x, y1 - 4, PAL["metal"])
    for x in range(0, w, 24):
        rect(im, x, y0 - 1, x + 1, y1 - 4, PAL["metal_lo"])


def hedge(im, y0, y1, rng):
    w = im.width
    for x in range(w):
        top = y0 + int(1 + math.sin(x * 0.6) + rng.random())
        rect(im, x, top, x, y1, PAL["leaf"])
        px(im, x, top, PAL["leaf_hi"])
    art.speckle(im, 0, y0 + 2, w - 1, y1 - 1, [PAL["leaf_lo"], PAL["leaf_hi"]], 0.25, rng)
    rect(im, 0, y1, w - 1, y1, OUT)


def facades(walls, width, seed, style, home_end=False):
    rng = random.Random(seed)
    lit = []
    plan, x = [], 0
    while x < width:
        w = rng.choice((48, 56, 64, 72)) if style == "barrio" else rng.choice((80, 96, 104))
        if width - (x + w) < 32:
            w = width - x
        plan.append((x, x + w - 1))
        x += w
    kinds = rng.sample(SHOPS, len(SHOPS))
    shops = 0
    last_shop = False
    for i, (a, b) in enumerate(plan):
        if style == "towers":
            tower(walls, a, b, rng, lit, entrance=i == len(plan) - 1)
        elif home_end and i == len(plan) - 1:
            house(walls, a, b, "e9dcbc", rng, lit, home=True)
        elif not last_shop and b - a >= 47 and rng.random() < 0.45:
            shop(walls, a, b, kinds[shops % len(kinds)], rng.choice(art.FACADE_COLORS), rng, lit)
            shops += 1
            last_shop = True
            rect(walls, a, 0, a, FACADE_H - 1, PAL["brown_line"])
            continue
        else:
            house(walls, a, b, rng.choice(art.FACADE_COLORS), rng, lit)
        last_shop = False
        rect(walls, a, 0, a, FACADE_H - 1, PAL["brown_line"])
    rect(walls, 0, FACADE_H - 1, width - 1, FACADE_H - 1, PAL["brown_line"])
    if style == "barrio":
        cables(walls, width)
    return lit


def street_level(width, seed, style="barrio", crossings=(), bus_at=None, painted=(), pits=(), bottom="rail",
                 puddles=0, home_end=False, bike=False, tactile_strip=False):
    rng = random.Random(seed)
    H = 180
    floor = new(width, H)
    sidewalk(floor, 0, SIDE_TOP[0], width - 1, SIDE_TOP[1], rng, pavers=style == "towers")
    if tactile_strip:
        tactile(floor, 0, 66, width - 1)
    for p in pits:
        tree_pit(floor, p, 62)
    art.shadow_band(floor, 0, SIDE_TOP[0], width - 1, SIDE_TOP[0] + 4, "top", 0.42)
    curb(floor, 0, CURB_TOP, width - 1, painted)
    asphalt(floor, 0, ROAD[0], width - 1, ROAD[1], rng, crossings, bus_at, bike)
    art.shadow_band(floor, 0, ROAD[0], width - 1, ROAD[0] + 2, "top", 0.35)
    curb(floor, 0, CURB_BOT, width - 1)
    if bottom == "park":
        sidewalk(floor, 0, SIDE_BOT, width - 1, 153, rng)
        grass(floor, 0, 154, width - 1, H - 1, rng)
        for x in range(15, width, 75):
            rect(floor, x, 154, x + 11, H - 1, hexc("c8b890"))
    else:
        sidewalk(floor, 0, SIDE_BOT, width - 1, H - 1, rng)
    for _ in range(puddles):
        puddle(floor, rng.randint(20, width - 20), rng.choice((rng.randint(56, 70), rng.randint(144, 152))),
               rng.randint(4, 8), rng.randint(0, 999))
    walls = new(width, H)
    lit = facades(walls, width, seed + 1, style, home_end)
    if bottom == "park":
        hedge(walls, H - 9, H - 1, rng)
    else:
        rail(walls, H - 11, H - 1)
    return floor, walls, lit


# ---------------------------------------------------------------- street objects (drawn at half size)

def obj_bus_stop():
    im = new(56, 44)
    rect(im, 2, 0, 53, 8, hexc("3c6aa0"))
    rect(im, 2, 0, 53, 0, hexc("7aa8d8"))
    rect(im, 2, 8, 53, 8, hexc("2a4a70"))
    w = text_width("PARADERO") + 4
    rect(im, 28 - w // 2, 1, 28 - w // 2 + w - 1, 7, hexc("f4f0e8"))
    text(im, 28 - w // 2 + 2, 2, "PARADERO", hexc("2a4a70"))
    for x in (4, 50):
        rect(im, x, 9, x + 1, 40, PAL["metal"])
        rect(im, x + 1, 9, x + 1, 40, PAL["metal_lo"])
    rect(im, 6, 10, 49, 27, hexc("a8c8dc", 140))
    for i in range(12):
        px(im, 36 + i, 11 + i, hexc("eaf6fc", 220))
    rect(im, 8, 11, 21, 26, hexc("f4f0e8"))
    for y in range(12, 19):
        rect(im, 9, y, 20, y, (240 - 4 * (y - 12), 140 + 5 * (y - 12), 90, 255))
    text(im, 9, 20, "BUS", hexc("3c6aa0"))
    rect(im, 10, 30, 45, 31, PAL["wood_hi"])
    rect(im, 10, 32, 45, 33, PAL["wood"])
    for x in (12, 43):
        rect(im, x, 34, x, 38, PAL["metal_lo"])
    return shadowed(outline(im), 50)


def obj_lamppost():
    im = new(16, 46)
    rect(im, 6, 8, 7, 41, PAL["metal"])
    rect(im, 6, 8, 6, 41, PAL["metal_hi"])
    rect(im, 4, 40, 9, 43, PAL["metal_lo"])
    rect(im, 7, 5, 13, 6, PAL["metal"])
    rect(im, 10, 4, 15, 5, PAL["metal_lo"])
    rect(im, 11, 6, 14, 6, hexc("f8e8a8"))
    return shadowed(outline(im), 8)


def obj_tree():
    im = new(36, 48)
    rect(im, 16, 26, 19, 44, hexc("6b4a2b"))
    rect(im, 16, 26, 16, 44, hexc("8a6440"))
    rect(im, 19, 26, 19, 44, hexc("4a321c"))
    art.foliage(im, 18, 15, 15, 13, 11)
    return shadowed(outline(im), 18)


def obj_bench():
    im = new(28, 16)
    for y in (1, 6):
        rect(im, 1, y, 26, y + 2, PAL["wood"])
        rect(im, 1, y, 26, y, PAL["wood_hi"])
    for x in (3, 23):
        rect(im, x, 4, x + 1, 13, PAL["metal_lo"])
    return shadowed(outline(im), 24)


def obj_trash_can():
    im = new(10, 16)
    rect(im, 2, 4, 7, 14, hexc("3c8a4c"))
    rect(im, 2, 4, 2, 14, hexc("50a860"))
    rect(im, 1, 2, 8, 4, hexc("e88a30"))
    rect(im, 3, 3, 6, 3, hexc("1e1e1e"))
    for y in (7, 10):
        rect(im, 3, y, 6, y, hexc("2c6a38"))
    return shadowed(outline(im), 8)


def obj_hydrant():
    im = new(8, 12)
    rect(im, 2, 3, 5, 10, hexc("e0c040"))
    rect(im, 2, 3, 2, 10, hexc("f0d860"))
    rect(im, 1, 2, 6, 3, hexc("d03a3a"))
    rect(im, 0, 5, 7, 6, hexc("d03a3a"))
    return shadowed(outline(im), 6)


def obj_planter():
    im = new(24, 18)
    art.foliage(im, 12, 6, 10, 5, 21)
    for x in range(5, 20, 4):
        px(im, x, 4 + x % 3, hexc("e04860"))
    rect(im, 2, 9, 21, 15, hexc("a8a498"))
    rect(im, 2, 9, 21, 10, hexc("c8c4b8"))
    rect(im, 3, 10, 20, 10, PAL["soil"])
    return shadowed(outline(im), 22)


def obj_bollard():
    im = new(6, 11)
    rect(im, 1, 1, 4, 9, hexc("4a525c"))
    rect(im, 1, 1, 1, 9, hexc("6a727e"))
    rect(im, 1, 3, 4, 3, hexc("e2bf48"))
    return shadowed(outline(im), 5)


def obj_stop_sign():
    im = new(22, 34)
    rect(im, 10, 18, 11, 31, PAL["metal"])
    pts = [(6, 1), (15, 1), (20, 6), (20, 13), (15, 18), (6, 18), (1, 13), (1, 6)]
    ImageDraw.Draw(im).polygon(pts, fill=hexc("d03a3a"), outline=hexc("f4f0e8"))
    text(im, 11 - text_width("PARE") // 2, 7, "PARE", hexc("f4f0e8"))
    return shadowed(outline(im), 8)


def obj_kiosk():
    im = new(32, 34)
    for i, x in enumerate(range(1, 31, 4)):
        c = hexc(("3c8a4c", "f0d060")[i % 2])
        rect(im, x, 1, x + 3, 5, c)
        rect(im, x + 1, 6, x + 2, 6, c)
    rect(im, 1, 0, 30, 0, OUT)
    for x in (2, 29):
        rect(im, x, 7, x, 16, PAL["metal"])
    rect(im, 5, 9, 26, 14, hexc("f4f0e8"))
    for y in (10, 12):
        rect(im, 6, y, 25, y, hexc("9a9a96"))
    rect(im, 1, 16, 30, 30, hexc("3c6aa0"))
    rect(im, 1, 16, 30, 18, hexc("e8e4d8"))
    rng = random.Random(5)
    for x in range(2, 30, 2):
        rect(im, x, 16, x, 17, rng.choice([hexc("d03a3a"), hexc("f0d060"), hexc("4ab050"), hexc("f08aa8")]))
    text(im, 16 - text_width("DULCES") // 2, 22, "DULCES", hexc("f4f0e0"))
    return shadowed(outline(im), 30)


def obj_cart(kind):
    """Street stands of the tinto vendor (NPC-01) and the empanada vendor (NPC-05)."""
    label = "TINTO" if kind == "coffee" else "EMPANADA"
    im = new(40, 32)
    stripes = ("b03a3a", "f4f0e8") if kind == "coffee" else ("e3b55a", "c83c3c")
    for i, x in enumerate(range(1, 39, 4)):
        c = hexc(stripes[i % 2])
        rect(im, x, 1, x + 3, 6, c)
        rect(im, x + 1, 7, x + 2, 7, c)
    rect(im, 1, 0, 38, 0, OUT)
    for x in (3, 36):
        rect(im, x, 8, x, 17, PAL["metal"])
    rect(im, 2, 17, 37, 26, PAL["wood"])
    rect(im, 2, 17, 37, 18, hexc("e8e4d8"))
    if kind == "coffee":
        rect(im, 6, 10, 11, 16, hexc("c8c8c4"))
        rect(im, 7, 9, 10, 9, hexc("5a5a62"))
        rect(im, 14, 11, 18, 16, hexc("b03a3a"))
        for x in (22, 26, 30):
            rect(im, x, 13, x + 2, 16, hexc("f4f0e8"))
        px(im, 8, 7, hexc("f4f0e8", 170))
        px(im, 9, 6, hexc("f4f0e8", 170))
    else:
        rect(im, 5, 10, 34, 16, hexc("bcd8e4", 150))
        for x in range(7, 33, 5):
            rect(im, x, 13, x + 3, 15, hexc("e3a040"))
            rect(im, x + 1, 13, x + 2, 13, hexc("f0c870"))
    text(im, 20 - text_width(label) // 2, 20, label, hexc("f4f0e0"))
    for cx in (6, 30):
        ImageDraw.Draw(im).ellipse([cx, 25, cx + 5, 30], fill=hexc("2a2a30"))
    return shadowed(outline(im), 36)


# ---------------------------------------------------------------- office

OW = {"cap": hexc("d8d6ce"), "cap_hi": hexc("ecebe4"), "paint": hexc("cdd3d8"), "low": hexc("8e9ca8"),
      "rail": hexc("e8ecee"), "base": hexc("4c525c")}
CAP, FACE_END = 4, 31


def city(im, x0, y0, x1, y1, rng):
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0)
        rect(im, x0, y, x1, y, (int(150 + 60 * t), int(196 + 34 * t), int(232 + 10 * t), 255))
    hills = art.value_noise(rng.randint(0, 999), 12)
    for x in range(x0, x1 + 1):
        top = y0 + int((y1 - y0) * (0.25 + 0.3 * hills(x, 0)))
        rect(im, x, top, x, y1, hexc("5c8a5a"))
        px(im, x, top, hexc("7aa870"))
    bx = x0
    while bx < x1:
        bw, bh = rng.randint(3, 6), rng.randint((y1 - y0) // 4, (y1 - y0) * 2 // 3)
        c = hexc(rng.choice(["8c96a4", "a4acb8", "7a8494", "b4a898"]))
        rect(im, bx, y1 - bh, min(x1, bx + bw), y1, c)
        for wy in range(y1 - bh + 1, y1, 2):
            if rng.random() < 0.6:
                px(im, bx + 1, wy, shade(c, 0.8))
        bx += bw + rng.randint(0, 2)


def office_feature(w, kind, x, rng, lit):
    if kind == "window":
        rect(w, x - 2, 6, x + 33, 26, hexc("e4e8ea"))
        city(w, x, 8, x + 31, 24, rng)
        for y in range(8, 14, 2):
            rect(w, x, y, x + 31, y, hexc("eef0f0"))
        rect(w, x + 15, 8, x + 16, 24, hexc("e4e8ea"))
        rect(w, x - 3, 26, x + 34, 27, hexc("b8c0c6"))
        lit.append((x, 14, x + 31, 24))
    elif kind == "whiteboard":
        rect(w, x - 1, 7, x + 37, 25, hexc("8a9098"))
        rect(w, x, 8, x + 36, 24, hexc("f6f8f8"))
        for i, h in enumerate((5, 9, 7, 12, 10)):
            rect(w, x + 4 + i * 5, 22 - h, x + 6 + i * 5, 22, hexc(("3a6ac8", "d04040", "3a9a50", "e3a040", "8a4ac8")[i]))
        rect(w, x + 3, 22, x + 30, 22, hexc("2a2a30"))
    elif kind == "clock":
        draw = ImageDraw.Draw(w)
        draw.ellipse([x, 7, x + 11, 18], fill=hexc("2a2a30"))
        draw.ellipse([x + 1, 8, x + 10, 17], fill=hexc("f4f2ec"))
        rect(w, x + 5, 9, x + 5, 12, hexc("2a2a30"))
        rect(w, x + 6, 12, x + 8, 12, hexc("2a2a30"))
    elif kind == "board":
        rect(w, x - 1, 7, x + 27, 25, hexc("6f4932"))
        rect(w, x, 8, x + 26, 24, hexc("b48a52"))
        for k in range(6):
            nx, ny = x + 2 + (k % 3) * 8, 9 + (k // 3) * 8
            c = hexc(rng.choice(["f4f0a0", "f0f0f0", "a8d8f0", "f8c0c8", "c8f0b0"]))
            rect(w, nx, ny, nx + 5, ny + 5, c)
            rect(w, nx + 1, ny + 2, nx + 4, ny + 2, shade(c, 0.7))
            px(w, nx + 2, ny, hexc("d03a3a"))
    elif kind == "poster":
        rect(w, x - 1, 6, x + 28, 26, hexc("2a2a30"))
        for y in range(7, 18):
            rect(w, x, y, x + 27, y, (240 - 3 * (y - 7), 160 + 2 * (y - 7), 80 + 5 * (y - 7), 255))
        ImageDraw.Draw(w).ellipse([x + 9, 8, x + 18, 16], fill=hexc("f8e8a0"))
        rect(w, x, 18, x + 27, 25, hexc("3c6aa0"))
        text(w, x + 14 - text_width("EQUIPO") // 2, 19, "EQUIPO", hexc("f4f0e0"))
    elif kind == "ac":
        rect(w, x, 5, x + 21, 10, hexc("f4f4f0"))
        rect(w, x, 10, x + 21, 10, hexc("b8bcc0"))
        px(w, x + 19, 6, hexc("50d060"))
    elif kind == "elevator":
        rect(w, x - 2, 5, x + 23, FACE_END, hexc("9aa2ac"))
        rect(w, x, 9, x + 21, FACE_END, hexc("b8c0c8"))
        rect(w, x + 10, 9, x + 11, FACE_END, hexc("6a727c"))
        rect(w, x + 7, 5, x + 14, 8, hexc("1a1a1a"))
        px(w, x + 10, 6, hexc("e04040"))
        rect(w, x + 24, 16, x + 25, 19, hexc("d8d8d0"))
    elif kind == "sign":
        board(w, x, 9, "ENTREGAS", hexc("2a3440"), hexc("f0e0a0"))
    elif kind == "turno":
        rect(w, x - 1, 6, x + 39, 20, OUT)
        rect(w, x, 7, x + 38, 19, hexc("1a1a1a"))
        text(w, x + 2, 8, "TURNO", hexc("e04040"))
        text(w, x + 2, 14, "A", hexc("f0d060"))
        text(w, x + 10, 14, "B", hexc("60c0f0"))


def office_level(width, height, seed, features=(), lobby=None, queue_lines=(), doors=(75, 107)):
    rng = random.Random(seed)
    floor = new(width, height)
    for ty in range(0, height, 16):
        for tx in range(0, width, 16):
            horiz = ((tx // 16) + (ty // 16)) % 2 == 0
            base = hexc("6c7a8e") if horiz else hexc("65738a")
            rect(floor, tx, ty, tx + 15, ty + 15, base)
            for k in range(0, 16, 3):
                if horiz:
                    rect(floor, tx, ty + k, tx + 15, ty + k, shade(base, 1.06))
                else:
                    rect(floor, tx + k, ty, tx + k, ty + 15, shade(base, 1.06))
            rect(floor, tx, ty, tx + 15, ty, shade(base, 0.9))
            rect(floor, tx, ty, tx, ty + 15, shade(base, 0.92))
    if lobby:
        lx0, lx1 = lobby
        for ty in range(0, height, 24):
            for tx in range(lx0, lx1, 24):
                c = hexc("d8d0c0") if ((tx - lx0) // 24 + ty // 24) % 2 == 0 else hexc("c8bfae")
                rect(floor, tx, ty, min(lx1, tx + 23), ty + 23, c)
                rect(floor, tx, ty, min(lx1, tx + 23), ty, shade(c, 1.06))
                rect(floor, tx, ty + 23, min(lx1, tx + 23), ty + 23, shade(c, 0.84))
                for k in range(5):
                    px(floor, tx + 3 + k, ty + 2 + k // 2, shade(c, 1.1))
                for k in range(8):
                    px(floor, tx + 12 + k, ty + 14 + (k * 3) % 5, shade(c, 0.88))
        rect(floor, lx1, 0, lx1 + 1, height - 1, hexc("9a9890"))
        my = (doors[0] + doors[1]) // 2
        rect(floor, 4, my - 12, 20, my + 12, hexc("5a3a34"))
        rect(floor, 5, my - 11, 19, my + 11, hexc("7a4a3e"))
    for x0, x1, y in queue_lines:
        for x in range(x0, x1):
            rect(floor, x, y, x, y + 1, hexc("e2bf48") if (x // 3) % 2 == 0 else hexc("2a2a2e"))
        for ax in range(x0 + 6, x1 - 4, 20):
            for k in range(3):
                rect(floor, ax + k, y - 5 + k, ax + k, y - 1 - k, hexc("e4e2d8"))
    art.shadow_band(floor, 0, FACE_END + 1, width - 1, FACE_END + 6, "top", 0.42)
    art.shadow_band(floor, 4, 0, 9, height - 1, "left", 0.35)
    art.shadow_band(floor, width - 10, 0, width - 5, height - 1, "right", 0.3)

    walls = new(width, height)
    rect(walls, 0, CAP, width - 1, FACE_END, OW["paint"])
    art.mottle(walls, 0, CAP, width - 1, 19, OW["paint"], shade(OW["paint"], 1.03), shade(OW["paint"], 0.97), seed, cell=16)
    rect(walls, 0, 20, width - 1, 20, OW["rail"])
    rect(walls, 0, 21, width - 1, FACE_END - 2, OW["low"])
    for x in range(0, width, 4):
        rect(walls, x, 21, x, FACE_END - 2, shade(OW["low"], 0.9))
    rect(walls, 0, FACE_END - 1, width - 1, FACE_END, OW["base"])
    lit = []
    for kind, x in features:
        office_feature(walls, kind, x, rng, lit)
    art.shadow_band(walls, 0, CAP, width - 1, CAP + 2, "top", 0.4)

    def cap(x0, y0, x1, y1):
        if y1 < y0:
            return
        rect(walls, x0, y0, x1, y1, OW["cap"])
        rect(walls, x0 + 1, y0 + 1, x1 - 1, y0 + 1, OW["cap_hi"])
        ImageDraw.Draw(walls).rectangle([x0, y0, x1, y1], outline=PAL["brown_line"])

    cap(0, 0, width - 1, CAP - 1)
    for side in (0, width - 4):
        cap(side, 0, side + 3, doors[0] - 1)
        cap(side, doors[1] + 1, side + 3, height - 1)
    cap(0, height - 4, width - 1, height - 1)
    rect(walls, 1, CAP, 2, FACE_END, OW["cap"])
    rect(walls, width - 3, CAP, width - 2, FACE_END, OW["cap"])
    return floor, walls, lit


def obox(im, x0, y0, x1, y1, top_h, color, top=None):
    top = top or shade(color, 1.18)
    rect(im, x0, y0, x1, y0 + top_h - 1, top)
    rect(im, x0, y0 + top_h, x1, y1, color)
    rect(im, x0, y0 + top_h, x1, y0 + top_h, shade(color, 0.82))
    rect(im, x1, y0 + top_h, x1, y1, shade(color, 0.86))
    rect(im, x0, y1, x1, y1, shade(color, 0.7))


def obj_office_desk():
    im = new(34, 24)
    obox(im, 1, 8, 32, 19, 6, hexc("8a6440"), hexc("c49a68"))
    rect(im, 22, 15, 31, 18, hexc("9a7048"))
    rect(im, 23, 16, 30, 16, hexc("6b4a2b"))
    for x in (2, 30):
        rect(im, x, 20, x + 1, 22, hexc("4a321c"))
    rect(im, 10, 0, 23, 8, hexc("2a2a30"))
    rect(im, 11, 1, 22, 7, hexc("3c78b0"))
    for y in (2, 4, 6):
        rect(im, 12, y, 12 + (y * 3) % 8 + 3, y, hexc("a8d8f0"))
    rect(im, 9, 10, 22, 11, hexc("e8e8e4"))
    rect(im, 3, 9, 7, 12, hexc("f4f0e0"))
    rect(im, 27, 9, 29, 11, hexc("d04040"))
    return shadowed(outline(im), 32)


def obj_office_chair():
    im = new(12, 17)
    rect(im, 2, 1, 9, 7, hexc("2f3340"))
    rect(im, 3, 1, 8, 1, hexc("4a5262"))
    rect(im, 1, 8, 10, 10, hexc("3a4050"))
    rect(im, 1, 8, 10, 8, hexc("4a5262"))
    rect(im, 5, 11, 6, 13, PAL["metal"])
    rect(im, 2, 13, 9, 13, PAL["metal"])
    for x in (2, 5, 9):
        px(im, x, 14, hexc("1a1a1a"))
    return shadowed(outline(im), 10)


def obj_cubicle():
    im = new(36, 18)
    obox(im, 0, 1, 35, 15, 2, hexc("7c8ca0"), hexc("c8ccd0"))
    for x in (0, 12, 24):
        rect(im, x, 1, x, 15, hexc("a8b0b8"))
    rect(im, 4, 5, 7, 8, hexc("f4f0a0"))
    rect(im, 10, 6, 13, 9, hexc("a8d8f0"))
    return outline(im)


def obj_printer():
    im = new(20, 22)
    obox(im, 1, 2, 18, 19, 4, hexc("c8c8c4"), hexc("e0e0dc"))
    rect(im, 2, 2, 17, 4, hexc("5a5a62"))
    rect(im, 3, 3, 7, 3, hexc("6ab0e0"))
    px(im, 15, 3, hexc("50d060"))
    rect(im, 4, 9, 15, 9, hexc("3a3a40"))
    rect(im, 5, 10, 14, 12, hexc("f6f4ec"))
    rect(im, 3, 15, 16, 16, hexc("b4b4b0"))
    return shadowed(outline(im), 18)


def obj_coffee_station():
    im = new(26, 24)
    obox(im, 1, 9, 24, 21, 3, hexc("8a6440"), hexc("d8d4c8"))
    rect(im, 4, 1, 11, 10, hexc("3a3a40"))
    rect(im, 5, 2, 8, 4, hexc("6ab0e0"))
    px(im, 10, 2, hexc("d04040"))
    rect(im, 6, 6, 9, 9, hexc("1a1a1a"))
    rect(im, 7, 8, 8, 9, hexc("f4f0e8"))
    for x in (14, 17, 20):
        rect(im, x, 7, x + 1, 9, hexc("f4f0e8"))
    rect(im, 12, 15, 12, 18, hexc("5a3a24"))
    return shadowed(outline(im), 24)


def obj_water_cooler():
    im = new(10, 23)
    rect(im, 2, 1, 7, 7, hexc("8cc8f0", 220))
    rect(im, 3, 2, 3, 6, hexc("c8e8fc", 235))
    obox(im, 2, 8, 7, 20, 1, hexc("e8e8e4"))
    px(im, 3, 11, hexc("3a6ac8"))
    px(im, 6, 11, hexc("d04040"))
    return shadowed(outline(im), 8)


def obj_plant():
    im = new(12, 20)
    art.foliage(im, 6, 6, 5, 6, 41)
    obox(im, 3, 12, 8, 18, 2, hexc("b0543a"), hexc("c8664a"))
    return shadowed(outline(im), 8)


def obj_plant_big():
    im = new(18, 32)
    art.foliage(im, 9, 11, 8, 10, 31)
    obox(im, 4, 22, 13, 30, 2, hexc("e8e4d8"), hexc("f4f0e8"))
    return shadowed(outline(im), 12)


def obj_filing_cabinet():
    im = new(13, 24)
    obox(im, 1, 1, 11, 22, 2, hexc("8a929c"), hexc("aab2bc"))
    for y in (4, 10, 16):
        rect(im, 2, y, 10, y + 4, hexc("9aa2ac"))
        rect(im, 2, y, 10, y, hexc("b4bcc4"))
        rect(im, 5, y + 2, 7, y + 2, hexc("4a505a"))
    return shadowed(outline(im), 11)


def obj_bookshelf():
    im = new(26, 30)
    obox(im, 1, 1, 24, 28, 2, PAL["wood"], PAL["wood_hi"])
    rng = random.Random(9)
    for shelf in (4, 12, 20):
        rect(im, 2, shelf, 23, shelf + 6, hexc("4a321c"))
        for x in range(3, 23, 2):
            c = hexc(rng.choice(["d04040", "3c6aa0", "3a9a50", "e3b55a", "8a4ac8", "f4f0e8"]))
            rect(im, x, shelf + 6 - rng.randint(4, 6), x, shelf + 6, c)
        rect(im, 2, shelf + 7, 23, shelf + 7, PAL["wood_hi"])
    return shadowed(outline(im), 24)


def obj_reception_desk():
    im = new(56, 26)
    obox(im, 1, 5, 54, 23, 4, hexc("5a7088"), hexc("e4e0d4"))
    rect(im, 1, 11, 54, 11, hexc("c8a84a"))
    board(im, 28 - (text_width("RECEPCION") + 6) // 2, 14, "RECEPCION", hexc("2a3440"), hexc("f0e0a0"))
    rect(im, 36, 0, 45, 5, hexc("2a2a30"))
    rect(im, 37, 1, 44, 4, hexc("3c78b0"))
    rect(im, 16, 2, 18, 5, hexc("4c8a3c"))
    return shadowed(outline(im), 54)


def obj_sofa():
    im = new(34, 18)
    obox(im, 2, 1, 31, 8, 2, hexc("8a3a34"), hexc("a84a42"))
    obox(im, 1, 7, 32, 14, 3, hexc("7a322e"), hexc("a84a42"))
    rect(im, 11, 8, 11, 13, hexc("5a2420"))
    rect(im, 22, 8, 22, 13, hexc("5a2420"))
    obox(im, 0, 5, 2, 15, 1, hexc("6a2a26"))
    obox(im, 31, 5, 33, 15, 1, hexc("6a2a26"))
    return shadowed(outline(im), 32)


def obj_counter(letter):
    """Ventanilla A / B of the M/M/1 windows (Trabajo 3)."""
    im = new(36, 32)
    rect(im, 12, 0, 23, 12, OUT)
    rect(im, 13, 1, 22, 11, hexc("1a1a1a"))
    text(im, 15, 2, letter, hexc("f0d060") if letter == "A" else hexc("60c0f0"), size=2)
    rect(im, 1, 13, 34, 13, PAL["metal_lo"])
    rect(im, 2, 14, 33, 21, hexc("bcd8e4", 150))
    for i in range(7):
        px(im, 24 + i, 14 + i, hexc("f0f8fc", 220))
    rect(im, 12, 19, 23, 21, hexc("3a4050"))
    obox(im, 1, 21, 34, 29, 2, hexc("5a7088"), hexc("e4e0d4"))
    rect(im, 4, 25, 9, 27, hexc("f4f0e0"))
    return shadowed(outline(im), 34)


def obj_stanchion():
    im = new(26, 15)
    for x in (2, 22):
        rect(im, x, 2, x, 12, hexc("c8a84a"))
        rect(im, x - 1, 1, x + 1, 1, hexc("e8c86a"))
        rect(im, x - 1, 12, x + 1, 13, hexc("8a7030"))
    for x in range(3, 22):
        rect(im, x, 3 + int(2 * math.sin((x - 3) / 19 * math.pi)), x, 3 + int(2 * math.sin((x - 3) / 19 * math.pi)), hexc("b03a3a"))
    return shadowed(outline(im), 24)


def obj_delivery_tray():
    """Punto de entrega de las carpetas (Trabajo 3)."""
    im = new(40, 26)
    obox(im, 1, 9, 38, 23, 3, hexc("5a7088"), hexc("d8d4c8"))
    for i, y in enumerate((3, 5, 7)):
        rect(im, 9, y, 30, y + 1, hexc("8a929c"))
        rect(im, 10, y - 1, 29, y - 1, hexc("f0d090") if i % 2 else hexc("f4f0e8"))
    board(im, 20 - (text_width("ENTREGAS") + 6) // 2, 14, "ENTREGAS", hexc("2a3440"), hexc("f0e0a0"))
    return shadowed(outline(im), 36)


def obj_boxes():
    im = new(18, 18)
    obox(im, 1, 7, 16, 16, 3, hexc("b4864e"), hexc("caa068"))
    obox(im, 3, 1, 13, 8, 2, hexc("a87a44"), hexc("c49a62"))
    rect(im, 8, 1, 8, 3, hexc("e8d8b0"))
    rect(im, 5, 11, 11, 13, hexc("f4f0e8"))
    return shadowed(outline(im), 16)


def obj_office_trash():
    im = new(7, 9)
    rect(im, 1, 2, 5, 7, hexc("5a626c"))
    rect(im, 1, 2, 1, 7, hexc("7a828c"))
    rect(im, 0, 1, 6, 2, hexc("4a525c"))
    px(im, 3, 0, hexc("f4f0e8"))
    return shadowed(outline(im), 5)


def obj_extinguisher():
    im = new(6, 12)
    rect(im, 1, 3, 4, 10, hexc("d03a3a"))
    rect(im, 1, 3, 1, 10, hexc("e86a5a"))
    rect(im, 2, 1, 3, 2, hexc("2a2a30"))
    rect(im, 2, 6, 3, 7, hexc("f4f0e8"))
    return shadowed(outline(im), 4)


STREET_OBJECTS = {
    "obj_tree": obj_tree, "obj_lamppost": obj_lamppost, "obj_bus_stop": obj_bus_stop, "obj_bench": obj_bench,
    "obj_trash_can": obj_trash_can, "obj_hydrant": obj_hydrant, "obj_planter": obj_planter, "obj_bollard": obj_bollard,
    "obj_stop_sign": obj_stop_sign, "obj_kiosk": obj_kiosk, "obj_coffee_cart": lambda: obj_cart("coffee"),
    "obj_empanada_stand": lambda: obj_cart("empanada"),
}
OFFICE_OBJECTS = {
    "obj_office_desk": obj_office_desk, "obj_office_chair": obj_office_chair, "obj_cubicle": obj_cubicle,
    "obj_printer": obj_printer, "obj_coffee_station": obj_coffee_station, "obj_water_cooler": obj_water_cooler,
    "obj_plant": obj_plant, "obj_plant_big": obj_plant_big, "obj_filing_cabinet": obj_filing_cabinet,
    "obj_bookshelf": obj_bookshelf, "obj_reception_desk": obj_reception_desk, "obj_sofa": obj_sofa,
    "obj_counter_a": lambda: obj_counter("A"), "obj_counter_b": lambda: obj_counter("B"),
    "obj_stanchion": obj_stanchion, "obj_delivery_tray": obj_delivery_tray, "obj_boxes": obj_boxes,
    "obj_office_trash": obj_office_trash, "obj_extinguisher": obj_extinguisher,
}

# Recipes in half-resolution units. Objects: suggested placement (x, y top-left, half units) for the preview.
STREET_LEVELS = {
    "commute_01": dict(width=960, seed=11, light=None, street=dict(crossings=(320, 650), pits=(45, 205, 430, 590, 780)),
                       objects=[("obj_tree", 33, 22), ("obj_tree", 193, 22), ("obj_tree", 418, 22), ("obj_tree", 578, 22),
                                ("obj_tree", 768, 22), ("obj_lamppost", 125, 28), ("obj_lamppost", 500, 28),
                                ("obj_lamppost", 850, 28), ("obj_coffee_cart", 236, 44), ("obj_trash_can", 280, 58),
                                ("obj_hydrant", 360, 62), ("obj_bench", 700, 58), ("obj_stop_sign", 300, 40),
                                ("obj_kiosk", 880, 42), ("obj_planter", 100, 150), ("obj_planter", 550, 150),
                                ("obj_bollard", 318, 145), ("obj_bollard", 333, 145), ("obj_trash_can", 750, 150)]),
    "commute_03": dict(width=320, seed=13, light=None,
                       street=dict(style="towers", crossings=(150,), bike=True, tactile_strip=True),
                       objects=[("obj_planter", 20, 52), ("obj_planter", 100, 52), ("obj_lamppost", 65, 28),
                                ("obj_lamppost", 210, 28), ("obj_bollard", 250, 62), ("obj_bollard", 262, 62),
                                ("obj_bench", 130, 150), ("obj_tree", 280, 120), ("obj_trash_can", 180, 58)]),
    "return_01": dict(width=320, seed=21, light="dusk", street=dict(crossings=(210,), bus_at=24, painted=((60, 115),)),
                      objects=[("obj_bus_stop", 62, 30), ("obj_empanada_stand", 222, 44), ("obj_lamppost", 158, 30),
                               ("obj_lamppost", 296, 30), ("obj_trash_can", 130, 58), ("obj_tree", 8, 116),
                               ("obj_bench", 258, 150)]),
    "return_02": dict(width=320, seed=22, light="evening", street=dict(crossings=(100,), bottom="park", puddles=5),
                      objects=[("obj_lamppost", 50, 28), ("obj_lamppost", 160, 28), ("obj_lamppost", 270, 28),
                               ("obj_tree", 30, 128), ("obj_tree", 150, 128), ("obj_tree", 260, 128),
                               ("obj_bench", 200, 150), ("obj_trash_can", 120, 58)]),
    "return_03": dict(width=320, seed=23, light="night", street=dict(pits=(75, 225), home_end=True),
                      objects=[("obj_lamppost", 50, 28), ("obj_lamppost", 160, 28), ("obj_lamppost", 270, 28),
                               ("obj_tree", 63, 22), ("obj_tree", 213, 22), ("obj_trash_can", 140, 58),
                               ("obj_planter", 280, 150)]),
}
LAMPS = ((56, 64, 45), (166, 64, 45), (276, 64, 45))
LIGHTS = {"dusk": DUSK, "evening": EVENING, "night": NIGHT}

OFFICE_LEVELS = {
    "work_01": dict(size=(400, 300), seed=31,
                    office=dict(lobby=(4, 124), features=(("elevator", 20), ("elevator", 70), ("poster", 100),
                                                          ("window", 145), ("board", 195), ("clock", 235), ("ac", 260),
                                                          ("whiteboard", 290), ("window", 340))),
                    objects=[("obj_reception_desk", 35, 125), ("obj_sofa", 20, 210), ("obj_sofa", 70, 210),
                             ("obj_plant_big", 10, 30), ("obj_plant_big", 105, 30), ("obj_office_desk", 150, 60),
                             ("obj_office_desk", 200, 60), ("obj_office_desk", 300, 60), ("obj_office_chair", 160, 85),
                             ("obj_office_chair", 210, 85), ("obj_office_chair", 310, 85), ("obj_cubicle", 150, 170),
                             ("obj_cubicle", 190, 170), ("obj_office_desk", 150, 190), ("obj_office_desk", 300, 190),
                             ("obj_water_cooler", 370, 35), ("obj_filing_cabinet", 380, 130), ("obj_bookshelf", 260, 30),
                             ("obj_plant", 380, 260), ("obj_extinguisher", 135, 35)]),
    "work_02": dict(size=(320, 180), seed=32,
                    office=dict(features=(("window", 20), ("whiteboard", 70), ("clock", 120), ("ac", 140),
                                          ("window", 170), ("board", 225), ("window", 265))),
                    objects=[("obj_cubicle", 20, 55), ("obj_cubicle", 56, 55), ("obj_cubicle", 165, 55),
                             ("obj_office_desk", 20, 70), ("obj_office_desk", 56, 70), ("obj_office_desk", 165, 70),
                             ("obj_cubicle", 20, 120), ("obj_cubicle", 56, 120), ("obj_office_desk", 20, 135),
                             ("obj_office_desk", 56, 135), ("obj_printer", 125, 125), ("obj_coffee_station", 280, 35),
                             ("obj_plant_big", 295, 135), ("obj_boxes", 210, 145), ("obj_office_trash", 100, 90),
                             ("obj_filing_cabinet", 240, 35)]),
    "work_03": dict(size=(320, 180), seed=33,
                    office=dict(features=(("window", 20), ("clock", 70), ("poster", 90), ("turno", 150),
                                          ("sign", 195), ("window", 260)),
                                queue_lines=((150, 215, 70), (150, 215, 135))),
                    objects=[("obj_counter_a", 215, 35), ("obj_counter_b", 215, 100), ("obj_stanchion", 160, 60),
                             ("obj_stanchion", 160, 125), ("obj_delivery_tray", 260, 60), ("obj_filing_cabinet", 290, 130),
                             ("obj_plant_big", 10, 135), ("obj_water_cooler", 120, 35), ("obj_sofa", 30, 150),
                             ("obj_printer", 75, 40), ("obj_office_trash", 130, 150)]),
}


def save(im, path):
    art.save(im, path)


def preview(name, floor, walls, objects, placements):
    if PREVIEW is None:
        return
    scene = floor.copy()
    scene.alpha_composite(walls)
    for obj, x, y in sorted(placements, key=lambda p: p[2] + objects[p[0]].height):
        scene.alpha_composite(objects[obj], (x, y))
    PREVIEW.mkdir(parents=True, exist_ok=True)
    x2(scene).save(PREVIEW / f"preview_{name}.png")


def main():
    print("Street objects (pixel x2)")
    street = {name: fn() for name, fn in STREET_OBJECTS.items()}
    for name, im in street.items():
        save(x2(im), STREET / "decoration" / f"{name}.png")
        save(x2(grade(im, DUSK)), STREET / "decoration" / f"{name}_dusk.png")
        save(x2(grade(im, NIGHT)), STREET / "decoration" / f"{name}_night.png")
    print("Office objects (pixel x2)")
    office = {name: fn() for name, fn in OFFICE_OBJECTS.items()}
    for name, im in office.items():
        save(x2(im), OFFICE / "decoration" / f"{name}.png")

    print("Street levels (pixel x2)")
    for name, spec in STREET_LEVELS.items():
        floor, walls, lit = street_level(spec["width"], spec["seed"], **spec["street"])
        objects = street
        if spec["light"]:
            tint = LIGHTS[spec["light"]]
            lamps = LAMPS if spec["light"] != "dusk" else ()
            floor = grade(floor, tint, lamps=lamps)
            walls = grade(walls, tint, lit_rects=lit if spec["light"] != "dusk" else ())
            objects = {k: grade(v, NIGHT if spec["light"] == "night" else DUSK) for k, v in street.items()}
        save(x2(floor), STREET / f"bg_{name}_floor.png")
        save(x2(walls), STREET / f"bg_{name}_walls.png")
        preview(name, floor, walls, objects, spec["objects"])

    print("Office levels (pixel x2)")
    for name, spec in OFFICE_LEVELS.items():
        floor, walls, _ = office_level(*spec["size"], spec["seed"], **spec["office"])
        save(x2(floor), OFFICE / f"bg_{name}_floor.png")
        save(x2(walls), OFFICE / f"bg_{name}_walls.png")
        preview(name, floor, walls, office, spec["objects"])


if __name__ == "__main__":
    main()

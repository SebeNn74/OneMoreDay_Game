"""Home redrawn in "pixel x2" (half resolution scaled x2), like the other scenarios.

Floor and walls keep the exact layout of the hand-drawn home: a zone map (wood, rug, tiles, mat, plaster,
brick, trim, outline) is read from the original art in git (HEAD of master when the script was written,
kept in tools/art/home_layout/) and repainted with new textures. Furniture is redrawn inside the same canvas
size and bounding box, so prop footprints and the home collisions stay valid.
    python tools/art/generate_home_x2.py
"""
from __future__ import annotations

import importlib.util
import math
import random
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("art", HERE / "generate_missing_art.py")
art = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(art)
hexc, shade, new, rect, px, outline = art.hexc, art.shade, art.new, art.rect, art.px, art.outline
HOME = art.SPRITES / "environment" / "home"
LAYOUT = HERE / "home_layout"   # copies of the original floor/walls, used only to read the zone map
OUT = hexc("2f1b1a")

FLOOR_CLASSES = {
    "wood": ["b76f3d", "6f4932", "1e1e1e"], "rug": ["a59875", "786c52", "746850", "908363"],
    "tile": ["71858c", "50626e", "82959b", "414954"], "mat": ["524735", "1b0e06"],
}
WALL_CLASSES = {
    "plaster": ["e7daba", "e6d9b9", "cab296", "b6a58f", "c9b698"], "outline": ["2f1b1a", "392424", "2f1f1f", "471f27"],
    "brick": ["b96c49", "af6549", "82412f", "884939", "cb8365", "ab654b", "894834"],
    "trim": ["7f5443", "725547", "946c59", "7d736a"], "side": ["5b3d45", "5b4045"],
}


def classify(im: Image.Image, classes: dict) -> list[list]:
    """Half-resolution zone map: majority class of each 2x2 block; outline wins so walls keep their contour."""
    lut = {hexc(c)[:3]: name for name, cs in classes.items() for c in cs}
    w, h = im.size
    src = im.load()
    grid = []
    for y in range(0, h, 2):
        row = []
        for x in range(0, w, 2):
            names = []
            for dy in (0, 1):
                for dx in (0, 1):
                    p = src[min(x + dx, w - 1), min(y + dy, h - 1)]
                    if p[3] > 127:
                        names.append(lut.get(p[:3]) or min(lut.items(), key=lambda kv: sum((a - b) ** 2 for a, b in zip(kv[0], p[:3])))[1])
            if len(names) < 2:
                row.append(None)
            elif "outline" in names and names.count("outline") >= 1:
                row.append("outline")
            else:
                row.append(Counter(names).most_common(1)[0][0])
        grid.append(row)
    return grid


def components(grid, name):
    """Bounding boxes of the connected regions of one class."""
    h, w = len(grid), len(grid[0])
    seen = set()
    boxes = []
    for y in range(h):
        for x in range(w):
            if grid[y][x] != name or (x, y) in seen:
                continue
            stack, xs, ys = [(x, y)], [], []
            seen.add((x, y))
            while stack:
                cx, cy = stack.pop()
                xs.append(cx)
                ys.append(cy)
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and grid[ny][nx] == name:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            boxes.append((min(xs), min(ys), max(xs), max(ys)))
    return boxes


def paint_floor(grid, wall_grid, seed):
    rng = random.Random(seed)
    h, w = len(grid), len(grid[0])
    im = new(w, h)
    plank_h = 5
    tints = {}
    for y in range(h):
        for x in range(w):
            zone = grid[y][x]
            if zone == "wood":
                row = y // plank_h
                offset = (row * 17) % 23
                plank = (x + offset) // 26
                key = (row, plank)
                if key not in tints:
                    tints[key] = rng.uniform(0.93, 1.06)
                base = shade(hexc("b76f3d"), tints[key])
                if y % plank_h == plank_h - 1:
                    c = hexc("4a2c1c")
                elif (x + offset) % 26 == 0:
                    c = hexc("5a3622")
                elif y % plank_h == 0:
                    c = shade(base, 1.07)
                else:
                    c = base
                im.putpixel((x, y), c)
            elif zone == "tile":
                gx, gy = x % 5, y % 5
                c = hexc("50626e") if gx == 4 or gy == 4 else (hexc("82959b") if gx == 0 and gy == 0 else hexc("71858c"))
                im.putpixel((x, y), c)
            elif zone in ("rug", "mat"):
                im.putpixel((x, y), hexc("a59875") if zone == "rug" else hexc("524735"))
    for _ in range(w * h // 90):
        x, y = rng.randrange(w), rng.randrange(h)
        if grid[y][x] == "wood" and y % plank_h not in (0, plank_h - 1):
            for k in range(rng.randint(2, 5)):
                if x + k < w and grid[y][x + k] == "wood":
                    px(im, x + k, y, hexc("9a5a32"))
    for x0, y0, x1, y1 in components(grid, "rug"):
        rect(im, x0, y0, x1, y1, hexc("a59875"))
        art.mottle(im, x0, y0, x1, y1, hexc("a59875"), hexc("b2a682"), hexc("9a8c6a"), seed + 3, cell=6, spread=0.14)
        ImageDraw.Draw(im).rectangle([x0 + 2, y0 + 2, x1 - 2, y1 - 2], outline=hexc("786c52"))
        ImageDraw.Draw(im).rectangle([x0 + 4, y0 + 4, x1 - 4, y1 - 4], outline=hexc("8a7e5e"))
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        for dx, dy in ((0, -3), (-3, 0), (3, 0), (0, 3), (0, 0)):
            px(im, cx + dx, cy + dy, hexc("786c52"))
        for y in range(y0 + 1, y1, 2):
            px(im, x0, y, hexc("e0d4b0"))
            px(im, x1, y, hexc("e0d4b0"))
    for x0, y0, x1, y1 in components(grid, "mat"):
        rect(im, x0, y0, x1, y1, hexc("524735"))
        ImageDraw.Draw(im).rectangle([x0, y0, x1, y1], outline=hexc("2f2618"))
        for y in range(y0 + 2, y1 - 1, 2):
            rect(im, x0 + 2, y, x1 - 2, y, hexc("62563f"))
    # soft shadow under every wall, like the original's dark streaks
    for y in range(h):
        for x in range(w):
            if grid[y][x] in ("wood", "tile", "rug"):
                for d in (1, 2, 3):
                    above = y - d >= 0 and wall_grid[y - d][x] is not None
                    left = x - d >= 0 and wall_grid[y][x - d] is not None
                    if above or left:
                        art.darken(im, x, y, (0.32, 0.2, 0.1)[d - 1])
                        break
    return im


def paint_walls(grid, seed):
    rng = random.Random(seed)
    h, w = len(grid), len(grid[0])
    im = new(w, h)
    noise = art.fbm(seed, 10)
    for y in range(h):
        for x in range(w):
            zone = grid[y][x]
            if zone == "plaster":
                v = noise(x, y)
                c = hexc("efe4c6") if v > 0.62 else (hexc("dccca8") if v < 0.36 else hexc("e7daba"))
                im.putpixel((x, y), c)
            elif zone == "outline":
                im.putpixel((x, y), OUT)
            elif zone == "brick":
                row = y // 3
                mortar = y % 3 == 2 or (x + (row % 2) * 3) % 6 == 0
                c = hexc("82412f") if mortar else (hexc("c97c58") if y % 3 == 0 else hexc("b96c49"))
                im.putpixel((x, y), c)
            elif zone == "trim":
                im.putpixel((x, y), hexc("7f5443"))
            elif zone == "side":
                im.putpixel((x, y), hexc("5b3d45"))
    # stains on the plaster: soft humidity blotches, like the original walls
    shape = art.value_noise(seed + 1, 3)
    for x0, y0, x1, y1 in components(grid, "plaster"):
        if (x1 - x0) < 8 or (y1 - y0) < 8:
            continue
        spots = [(x0 + 2, y0 + 2), (x1 - 2, y0 + 2)] + \
                [(rng.randint(x0, x1), y1 - rng.randint(0, 3)) for _ in range(max(1, (x1 - x0) // 40))]
        for sx, sy in spots:
            rx, ry = rng.randint(4, 9), rng.randint(3, 6)
            for ty in range(sy - ry * 2, sy + ry * 2 + 1):
                for tx in range(sx - rx * 2, sx + rx * 2 + 1):
                    if not (0 <= tx < w and 0 <= ty < h) or grid[ty][tx] != "plaster":
                        continue
                    d = ((tx - sx) / rx) ** 2 + ((ty - sy) / ry) ** 2 + (shape(tx, ty) - 0.5) * 1.4
                    if d < 0.55:
                        im.putpixel((tx, ty), hexc("cab296"))
                    elif d < 1.0:
                        im.putpixel((tx, ty), hexc("d8c8a6"))
    for y in range(h):
        for x in range(w):
            if grid[y][x] == "trim" and (y == 0 or grid[y - 1][x] != "trim"):
                im.putpixel((x, y), hexc("946c59"))
            if grid[y][x] == "plaster" and y + 1 < h and grid[y + 1][x] in ("trim", "brick"):
                im.putpixel((x, y), hexc("cab296"))
    return im


def x2(im, size):
    return im.resize((im.width * 2, im.height * 2), Image.NEAREST).crop((0, 0, *size))


# ---------------------------------------------------------------- furniture (half size, same bounding box)

def obox(im, x0, y0, x1, y1, top_h, color, top=None):
    top = top or shade(color, 1.18)
    rect(im, x0, y0, x1, y0 + top_h - 1, top)
    rect(im, x0, y0, x1, y0, shade(top, 1.06))
    rect(im, x0, y0 + top_h, x1, y1, color)
    rect(im, x0, y0 + top_h, x1, y0 + top_h, shade(color, 0.82))
    rect(im, x1, y0 + top_h, x1, y1, shade(color, 0.86))
    rect(im, x0, y1, x1, y1, shade(color, 0.7))


WOOD, WOOD_HI, WOOD_LO = hexc("8a5a34"), hexc("a87048"), hexc("6b4a2b")


def wardrobe():
    im = new(32, 48)
    obox(im, 5, 2, 25, 45, 3, WOOD, WOOD_HI)
    rect(im, 15, 6, 15, 44, WOOD_LO)
    for x0, x1 in ((7, 13), (17, 23)):
        rect(im, x0, 8, x1, 22, shade(WOOD, 0.9))
        rect(im, x0, 26, x1, 41, shade(WOOD, 0.9))
        rect(im, x0, 8, x1, 8, WOOD_HI)
        rect(im, x0, 26, x1, 26, WOOD_HI)
    px(im, 14, 24, hexc("e3c060"))
    px(im, 16, 24, hexc("e3c060"))
    rect(im, 6, 45, 7, 46, WOOD_LO)
    rect(im, 23, 45, 24, 46, WOOD_LO)
    return outline(im, OUT)


def bed():
    im = new(32, 48)
    rect(im, 4, 2, 27, 8, WOOD)
    rect(im, 4, 2, 27, 2, WOOD_HI)
    rect(im, 4, 2, 5, 10, WOOD_LO)
    rect(im, 26, 2, 27, 10, WOOD_LO)
    rect(im, 6, 8, 25, 42, hexc("e8e8e4"))
    rect(im, 8, 9, 23, 13, hexc("f4f4f0"))
    rect(im, 8, 13, 23, 13, hexc("c8c8c4"))
    blanket = hexc("3c8a8a")
    rect(im, 6, 15, 25, 42, blanket)
    rect(im, 6, 15, 25, 16, hexc("e8e8e4"))
    rng = random.Random(4)
    for _ in range(14):
        x, y = rng.randint(8, 22), rng.randint(19, 40)
        rect(im, x, y, x + rng.randint(2, 4), y, hexc("54a4a0"))
        px(im, x + 1, y + 1, hexc("2c6a6a"))
    rect(im, 25, 17, 25, 42, hexc("2c6a6a"))
    rect(im, 4, 42, 27, 45, WOOD)
    rect(im, 4, 42, 27, 42, WOOD_HI)
    return outline(im, OUT)


def kitchen():
    im = new(80, 32)
    steel, steel_hi, steel_lo = hexc("6a7078"), hexc("8a9098"), hexc("4a5058")
    obox(im, 17, 1, 37, 30, 10, steel, steel_hi)
    for bx, by in ((20, 2), (29, 2), (20, 6), (29, 6)):
        ImageDraw.Draw(im).ellipse([bx, by, bx + 5, by + 2], fill=hexc("2a2a30"))
        px(im, bx + 2, by + 1, hexc("5a5a62"))
    rect(im, 19, 12, 35, 13, steel_lo)
    for kx in range(21, 35, 4):
        px(im, kx, 12, hexc("d8d8d0"))
    rect(im, 20, 16, 34, 27, hexc("2a2e34"))
    rect(im, 21, 17, 33, 18, hexc("5a6068"))
    rect(im, 22, 15, 32, 15, hexc("c8c8c0"))
    obox(im, 38, 1, 60, 30, 10, WOOD, hexc("d8d4c8"))
    rect(im, 42, 3, 56, 8, hexc("9aa2a8"))
    rect(im, 43, 4, 55, 7, hexc("6a7278"))
    rect(im, 49, 1, 50, 3, hexc("b4bcc2"))
    for x0, x1 in ((40, 48), (50, 58)):
        rect(im, x0, 14, x1, 28, shade(WOOD, 0.92))
        rect(im, x0, 14, x1, 14, WOOD_HI)
    px(im, 47, 20, hexc("e3c060"))
    px(im, 51, 20, hexc("e3c060"))
    return outline(im, OUT)


def shower():
    # Fits between the sink and the bathroom wall (screen x 140-172 at its home_01 position).
    im = new(40, 40)
    rect(im, 16, 0, 17, 4, hexc("9aa2a8"))
    rect(im, 14, 3, 19, 4, hexc("b4bcc2"))
    rect(im, 11, 5, 23, 5, hexc("8a9098"))
    for x in range(11, 24):
        c = hexc("e8e4d8") if (x // 2) % 2 == 0 else hexc("c8c0b0")
        rect(im, x, 6, x, 33, c)
    for y in range(8, 32, 6):
        rect(im, 11, y, 23, y, hexc("d8d0c0"))
    rect(im, 10, 33, 24, 38, hexc("f0f0ec"))
    rect(im, 10, 33, 24, 33, hexc("ffffff"))
    rect(im, 12, 35, 22, 37, hexc("9ab0bc"))
    return outline(im, OUT)


def desk():
    im = new(32, 32)
    obox(im, 1, 4, 30, 16, 6, WOOD, hexc("c49a68"))
    rect(im, 20, 11, 29, 15, shade(WOOD, 0.9))
    rect(im, 21, 13, 28, 13, WOOD_LO)
    rect(im, 2, 17, 3, 26, WOOD_LO)
    rect(im, 28, 17, 29, 26, WOOD_LO)
    rect(im, 8, 1, 17, 6, hexc("3a3a40"))
    rect(im, 9, 2, 16, 5, hexc("5aa0d0"))
    rect(im, 7, 6, 18, 7, hexc("8a8e96"))
    rect(im, 21, 4, 26, 7, hexc("f4f0e0"))
    rect(im, 22, 5, 25, 5, hexc("a4a4a0"))
    rect(im, 10, 18, 21, 24, WOOD)
    rect(im, 10, 18, 21, 18, WOOD_HI)
    rect(im, 11, 25, 12, 30, WOOD_LO)
    rect(im, 19, 25, 20, 30, WOOD_LO)
    rect(im, 10, 24, 21, 25, shade(WOOD, 0.85))
    return outline(im, OUT)


def toilet():
    im = new(16, 24)
    obox(im, 3, 0, 12, 7, 2, hexc("e8e8e4"), hexc("f8f8f4"))
    px(im, 10, 3, hexc("9aa2a8"))
    ImageDraw.Draw(im).ellipse([2, 7, 13, 18], fill=hexc("f0f0ec"))
    ImageDraw.Draw(im).ellipse([4, 9, 11, 16], fill=hexc("c8d4dc"))
    ImageDraw.Draw(im).ellipse([5, 10, 10, 15], fill=hexc("9ab0bc"))
    rect(im, 5, 18, 10, 22, hexc("e0e0dc"))
    rect(im, 10, 18, 10, 22, hexc("c4c4c0"))
    return outline(im, OUT)


def sink():
    im = new(16, 32)
    ImageDraw.Draw(im).ellipse([1, 4, 14, 12], fill=hexc("f0f0ec"))
    ImageDraw.Draw(im).ellipse([3, 6, 12, 10], fill=hexc("c8d4dc"))
    px(im, 7, 8, hexc("4a5058"))
    rect(im, 7, 4, 8, 5, hexc("b4bcc2"))
    rect(im, 5, 12, 10, 26, hexc("e8e8e4"))
    rect(im, 9, 12, 10, 26, hexc("c8c8c4"))
    rect(im, 4, 26, 11, 28, hexc("d8d8d4"))
    return outline(im, OUT)


def dining_table():
    im = new(32, 32)
    obox(im, 3, 2, 28, 18, 13, WOOD, hexc("b48050"))
    for x in (9, 15, 21):
        rect(im, x, 3, x, 14, shade(hexc("b48050"), 0.86))
    for x in (4, 26):
        rect(im, x, 19, x + 1, 30, WOOD_LO)
    return outline(im, OUT)


def fridge():
    im = new(20, 40)
    body, hi, lo = hexc("d4d6c0"), hexc("e8eadc"), hexc("a8aa94")
    obox(im, 0, 0, 18, 38, 2, body, hi)
    rect(im, 1, 12, 17, 12, lo)
    rect(im, 15, 4, 15, 9, hexc("8a8c78"))
    rect(im, 15, 15, 15, 26, hexc("8a8c78"))
    px(im, 5, 18, hexc("d03a3a"))
    px(im, 9, 22, hexc("3c6aa0"))
    rect(im, 4, 26, 7, 28, hexc("f4f0e0"))
    rect(im, 1, 37, 17, 38, lo)
    return outline(im, OUT)


def chair():
    im = new(32, 32)
    frame, cushion = WOOD_LO, hexc("b8b040")
    rect(im, 8, 0, 23, 2, frame)
    rect(im, 8, 0, 9, 15, frame)
    rect(im, 22, 0, 23, 15, frame)
    rect(im, 10, 3, 21, 12, cushion)
    rect(im, 10, 3, 21, 3, hexc("d0c858"))
    rect(im, 7, 15, 24, 20, cushion)
    rect(im, 7, 15, 24, 15, hexc("d0c858"))
    rect(im, 7, 20, 24, 21, frame)
    for x in (8, 22):
        rect(im, x, 22, x + 1, 29, frame)
    return outline(im, OUT)


def sofa():
    im = new(60, 40)
    fab, hi, lo = hexc("5a6a7a"), hexc("7a8a9a"), hexc("42505e")
    obox(im, 1, 0, 8, 30, 2, lo, fab)
    rect(im, 8, 0, 14, 26, fab)
    rect(im, 8, 0, 14, 1, hi)
    for y in (8, 17):
        rect(im, 8, y, 14, y, lo)
    obox(im, 1, 24, 45, 31, 2, lo, fab)
    rect(im, 1, 31, 45, 37, fab)
    rect(im, 1, 31, 45, 32, hi)
    for x in (16, 30):
        rect(im, x, 31, x, 37, lo)
    obox(im, 42, 26, 45, 37, 1, lo)
    rect(im, 2, 38, 3, 39, hexc("2a2a30"))
    rect(im, 42, 38, 43, 39, hexc("2a2a30"))
    return outline(im, OUT)


def tv():
    im = new(32, 32)
    obox(im, 6, 0, 25, 14, 2, hexc("5a5a78"), hexc("7a7a98"))
    rect(im, 8, 3, 22, 12, hexc("2a3040"))
    rect(im, 9, 4, 13, 5, hexc("5a6a8a"))
    px(im, 24, 6, hexc("50d060"))
    ImageDraw.Draw(im).ellipse([3, 13, 28, 20], fill=hexc("a87048"))
    ImageDraw.Draw(im).ellipse([3, 14, 28, 22], outline=WOOD_LO)
    rect(im, 5, 18, 26, 27, WOOD)
    rect(im, 5, 27, 26, 28, WOOD_LO)
    rect(im, 14, 21, 17, 25, shade(WOOD, 0.88))
    px(im, 27, 27, hexc("2a2a30"))
    px(im, 28, 28, hexc("2a2a30"))
    return outline(im, OUT)


FURNITURE = {
    "obj_armario.png": wardrobe, "obj_cama.png": bed, "obj_cocina.png": kitchen, "obj_ducha.png": shower,
    "obj_escritorio.png": desk, "obj_inodoro.png": toilet, "obj_lavamanos.png": sink,
    "obj_mesa_comedor.png": dining_table, "obj_nevera.png": fridge, "obj_silla.png": chair, "obj_sofa.png": sofa,
    "obj_tv.png": tv,
}


def main():
    LAYOUT.mkdir(exist_ok=True)
    for name in ("bg_home_floor.png", "bg_home_walls.png", "bg_home_wall.png"):
        if not (LAYOUT / name).exists():
            (LAYOUT / name).write_bytes((HOME / name).read_bytes())
    floor_src = Image.open(LAYOUT / "bg_home_floor.png").convert("RGBA")
    walls_src = Image.open(LAYOUT / "bg_home_walls.png").convert("RGBA")
    part_src = Image.open(LAYOUT / "bg_home_wall.png").convert("RGBA")
    wall_grid = classify(walls_src, WALL_CLASSES)
    floor_grid = classify(floor_src, FLOOR_CLASSES)
    art.save(x2(paint_floor(floor_grid, wall_grid, 7), floor_src.size), HOME / "bg_home_floor.png")
    art.save(x2(paint_walls(wall_grid, 8), walls_src.size), HOME / "bg_home_walls.png")
    art.save(x2(paint_walls(classify(part_src, WALL_CLASSES), 9), part_src.size), HOME / "bg_home_wall.png")
    for name, fn in FURNITURE.items():
        size = Image.open(HOME / "decoration" / name).size
        art.save(x2(fn(), size), HOME / "decoration" / name)


if __name__ == "__main__":
    main()

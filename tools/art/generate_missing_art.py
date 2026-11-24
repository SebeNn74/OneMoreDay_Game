"""Generates the missing One More Day pixel art with Pillow.

Run from the repository root:
    python tools/art/generate_missing_art.py

Outputs (same conventions as the existing art):
- Hostiles: 64x96 sheets, 16x24 cells, 4 frames x 4 directions (down, up, left, right),
  like hostile_crowd_*.png. Zones (H-T4) are 4 frames of 32x48, like hostile_rain.png.
- Scenarios in 3 layers, like the home (environment/street and environment/office):
  1. floor:   bg_<level>_floor.png (level size, origin top-left) -> World/Background/Floor
  2. walls:   bg_<level>_walls.png (level size, transparent where walkable) -> World/Background/Walls
  3. objects: decoration/obj_*.png, one sprite per object, placed as props in World/Entities (Y-sort).
  Vuelta levels have the dusk/night light baked in; street objects also come as *_dusk / *_night.
  STREET_LEVELS / OFFICE_LEVELS hold a suggested object placement; ART_PREVIEW=<folder> renders it.
- Endings: 640x360 illustrations (drawn at 320x180 and scaled x2) for V-01..V-05 and D-01..D-05.
Every random choice uses a fixed seed, so running it again gives the same files.
"""
from __future__ import annotations

import math
import os
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "assets" / "sprites"
ENEMIES = SPRITES / "enemies"
ENDINGS = SPRITES / "endings"
STREET = SPRITES / "environment" / "street"
OFFICE = SPRITES / "environment" / "office"

OUTLINE = (26, 26, 26, 255)
CLEAR = (0, 0, 0, 0)


# ---------------------------------------------------------------- helpers

def hexc(value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = value.lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha


def shade(color, factor: float):
    r, g, b, a = color
    return (min(255, int(r * factor)), min(255, int(g * factor)), min(255, int(b * factor)), a)


def new(w: int, h: int, color=CLEAR) -> Image.Image:
    return Image.new("RGBA", (w, h), color)


def rect(im: Image.Image, x0: int, y0: int, x1: int, y1: int, color) -> None:
    """Filled rectangle, both corners inclusive."""
    if x1 < x0 or y1 < y0:
        return
    ImageDraw.Draw(im).rectangle([x0, y0, x1, y1], fill=color)


def px(im: Image.Image, x: int, y: int, color) -> None:
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), color)


def blend(im: Image.Image, x: int, y: int, color, alpha: float) -> None:
    if 0 <= x < im.width and 0 <= y < im.height:
        r, g, b, a = im.getpixel((x, y))
        cr, cg, cb = color[:3]
        im.putpixel((x, y), (int(r + (cr - r) * alpha), int(g + (cg - g) * alpha), int(b + (cb - b) * alpha), max(a, 255 if a else int(255 * alpha))))


def outline(im: Image.Image, color=OUTLINE) -> Image.Image:
    """Adds a 1 px outline around every opaque pixel (4-neighbourhood), like the existing sprites."""
    src = im.load()
    out = im.copy()
    dst = out.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 200:
                    dst[x, y] = color
                    break
    return out


def speckle(im: Image.Image, x0: int, y0: int, x1: int, y1: int, colors, density: float, rng: random.Random) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if rng.random() < density:
                px(im, x, y, rng.choice(colors))


def scale(im: Image.Image, factor: int) -> Image.Image:
    return im.resize((im.width * factor, im.height * factor), Image.NEAREST)


def save(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    print(f"  {path.relative_to(ROOT).as_posix()}  {im.width}x{im.height}")


FONT = {
    "A": [".#.", "#.#", "###", "#.#", "#.#"], "B": ["##.", "#.#", "##.", "#.#", "##."],
    "C": [".##", "#..", "#..", "#..", ".##"], "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "##.", "#..", "###"], "F": ["###", "#..", "##.", "#..", "#.."],
    "G": [".##", "#..", "#.#", "#.#", ".##"], "H": ["#.#", "#.#", "###", "#.#", "#.#"], "I": ["###", ".#.", ".#.", ".#.", "###"],
    "L": ["#..", "#..", "#..", "#..", "###"], "M": ["#...#", "##.##", "#.#.#", "#...#", "#...#"],
    "N": ["#..#", "##.#", "#.##", "#..#", "#..#"], "O": [".#.", "#.#", "#.#", "#.#", ".#."],
    "P": ["##.", "#.#", "##.", "#..", "#.."], "Q": [".#.", "#.#", "#.#", "##.", ".##"], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "S": [".##", "#..", ".#.", "..#", "##."], "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"], "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
    " ": ["...", "...", "...", "...", "..."],
    "0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["##.", "..#", ".#.", "#..", "###"], "3": ["##.", "..#", ".#.", "..#", "##."],
    "4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "##.", "..#", "##."],
    "6": [".##", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "##."],
}


def text(im: Image.Image, x: int, y: int, word: str, color, size: int = 1) -> int:
    """Draws [word] with the 3x5 pixel font ([size] = pixel scale). Returns the width used."""
    cx = x
    for ch in word:
        for row, line in enumerate(FONT[ch]):
            for col, cell in enumerate(line):
                if cell == "#":
                    rect(im, cx + col * size, y + row * size, cx + col * size + size - 1, y + row * size + size - 1, color)
        cx += (len(FONT[ch][0]) + 1) * size
    return cx - x - size


def text_width(word: str) -> int:
    return sum(len(FONT[ch][0]) + 1 for ch in word) - 1


# ---------------------------------------------------------------- characters (16x24)

def person_frame(spec: dict, direction: int, frame: int) -> Image.Image:
    """One 16x24 walk frame. direction: 0 down, 1 up, 2 left (3 right is the mirror of 2)."""
    if direction == 3:
        return ImageOps.mirror(person_frame(spec, 2, frame))
    im = new(16, 24)
    phase = (0, 1, 0, -1)[frame % 4]
    b = 1 if phase != 0 else 0
    skin, skin_sh = spec["skin"], shade(spec["skin"], 0.82)
    top, top_sh = spec["top"], shade(spec["top"], 0.72)
    pants, shoes = spec["pants"], spec["shoes"]
    hair = spec.get("hair", hexc("2b2118"))
    hood, hat = spec.get("hood"), spec.get("hat")
    eye = spec.get("eye", hexc("1a1a1a"))

    if direction in (0, 1):
        for index, leg_x in enumerate((5, 8)):
            lift = 1 if (phase == 1 and index == 0) or (phase == -1 and index == 1) else 0
            rect(im, leg_x, 18, leg_x + 2, 21 - lift, pants)
            rect(im, leg_x, 22 - lift, leg_x + 2, 22 - lift, shoes)
        rect(im, 4, 11 + b, 11, 17 + b, top)
        rect(im, 11, 11 + b, 11, 17 + b, top_sh)
        for arm_x, lifted in ((3, phase == 1), (12, phase == -1)):
            hand_y = 17 + b - (1 if lifted else 0)
            rect(im, arm_x, 12 + b, arm_x, hand_y - 1, top_sh)
            px(im, arm_x, hand_y, skin)
        if hood:
            rect(im, 4, 2 + b, 11, 11 + b, hood)
            rect(im, 4, 2 + b, 4, 11 + b, shade(hood, 0.8))
            if direction == 0:
                rect(im, 6, 6 + b, 9, 10 + b, skin_sh)
                px(im, 6, 8 + b, spec.get("hood_eye", hexc("8a7a6a")))
                px(im, 9, 8 + b, spec.get("hood_eye", hexc("8a7a6a")))
        else:
            rect(im, 6, 10 + b, 9, 10 + b, skin_sh)
            rect(im, 5, 4 + b, 10, 9 + b, skin)
            rect(im, 4, 2 + b, 11, 4 + b, hair)
            rect(im, 4, 5 + b, 4, 7 + b, hair)
            rect(im, 11, 5 + b, 11, 7 + b, hair)
            if direction == 0:
                px(im, 6, 7 + b, eye)
                px(im, 9, 7 + b, eye)
                rect(im, 7, 9 + b, 8, 9 + b, skin_sh)
            else:
                rect(im, 4, 2 + b, 11, 9 + b, hair)
            if hat:
                rect(im, 4, 1 + b, 11, 3 + b, hat)
                if direction == 0:
                    rect(im, 4, 4 + b, 11, 4 + b, shade(hat, 0.7))
    else:
        if phase == 0:
            rect(im, 7, 18, 9, 21, pants)
            rect(im, 6, 22, 9, 22, shoes)
        else:
            rect(im, 9, 18, 11, 21, shade(pants, 0.8))
            rect(im, 9, 22, 11, 22, shoes)
            rect(im, 5, 18, 7, 21, pants)
            rect(im, 4, 22, 7, 22, shoes)
        rect(im, 6, 11 + b, 10, 17 + b, top)
        rect(im, 10, 11 + b, 10, 17 + b, top_sh)
        if phase == 0:
            rect(im, 8, 12 + b, 8, 16 + b, top_sh)
            px(im, 8, 17 + b, skin)
        elif phase == 1:
            rect(im, 7, 12 + b, 7, 15 + b, top_sh)
            px(im, 6, 16 + b, skin)
        else:
            rect(im, 9, 12 + b, 9, 15 + b, top_sh)
            px(im, 10, 16 + b, skin)
        if hood:
            rect(im, 5, 2 + b, 10, 11 + b, hood)
            rect(im, 5, 6 + b, 7, 10 + b, skin_sh)
            px(im, 6, 8 + b, spec.get("hood_eye", hexc("8a7a6a")))
        else:
            rect(im, 7, 10 + b, 8, 10 + b, skin_sh)
            rect(im, 5, 4 + b, 9, 9 + b, skin)
            px(im, 4, 7 + b, skin)
            rect(im, 5, 2 + b, 10, 4 + b, hair)
            rect(im, 9, 5 + b, 10, 8 + b, hair)
            px(im, 6, 7 + b, eye)
            if hat:
                rect(im, 5, 1 + b, 10, 3 + b, hat)
                rect(im, 3, 4 + b, 7, 4 + b, shade(hat, 0.7))
    extra = spec.get("extra")
    if extra:
        extra(im, direction, frame, b)
    return outline(im)


def sheet(frame_fn, cell=(16, 24), frames: int = 4, directions: int = 4) -> Image.Image:
    out = new(cell[0] * frames, cell[1] * directions)
    for d in range(directions):
        for f in range(frames):
            out.alpha_composite(frame_fn(d, f), (f * cell[0], d * cell[1]))
    return out


def tray_extra(colors):
    def draw(im, direction, frame, b):
        wood, wood_sh = hexc("8a5a34"), hexc("6b4a2b")
        if direction == 0:
            rect(im, 2, 13 + b, 13, 14 + b, wood)
            rect(im, 2, 14 + b, 13, 14 + b, wood_sh)
            for i, x in enumerate(range(3, 13, 2)):
                px(im, x, 12 + b, colors[i % len(colors)])
        elif direction == 1:
            px(im, 2, 13 + b, wood)
            px(im, 13, 13 + b, wood)
        else:
            rect(im, 1, 13 + b, 6, 14 + b, wood)
            rect(im, 1, 14 + b, 6, 14 + b, wood_sh)
            for i, x in enumerate(range(2, 6, 2)):
                px(im, x, 12 + b, colors[i % len(colors)])
    return draw


def scarf_extra(color):
    def draw(im, direction, frame, b):
        if direction in (0, 1):
            rect(im, 5, 11 + b, 10, 12 + b, color)
            if direction == 0:
                rect(im, 9, 13 + b, 10, 15 + b, color)
        else:
            rect(im, 6, 11 + b, 10, 12 + b, color)
            rect(im, 10, 13 + b, 11, 15 + b, color)
    return draw


SKIN = hexc("edc39a")
SKIN_DARK = hexc("c08a5c")

HOSTILE_PEOPLE = {
    # H-I3 Figura sospechosa: hood up, hands in the pockets, lurks near the bus stop.
    "hostile_suspicious_gray": {"skin": SKIN, "hood": hexc("3f4b5e"), "top": hexc("3f4b5e"),
                                "pants": hexc("22252f"), "shoes": hexc("1a1a1a")},
    "hostile_suspicious_brown": {"skin": SKIN_DARK, "hood": hexc("5a4632"), "top": hexc("5a4632"),
                                 "pants": hexc("2f3340"), "shoes": hexc("1a1a1a")},
    # H-I4 Vendedor insistente: cap and a tray of candy that blocks the way.
    "hostile_vendor_red": {"skin": SKIN, "hair": hexc("2b2118"), "hat": hexc("b03a3a"), "top": hexc("e7daba"),
                           "pants": hexc("3f4b5e"), "shoes": hexc("4a321c"),
                           "extra": tray_extra([hexc("e04848"), hexc("f0c040"), hexc("50b050")])},
    "hostile_vendor_green": {"skin": SKIN_DARK, "hair": hexc("1a1a1a"), "hat": hexc("3c8a4c"), "top": hexc("e3b55a"),
                             "pants": hexc("4a3a2c"), "shoes": hexc("2b2118"),
                             "extra": tray_extra([hexc("f08cc0"), hexc("ffffff"), hexc("f0c040")])},
    # H-V3 Calle oscura: a shadow with glowing eyes (not a "type of person", see tone rule 5).
    "hostile_dark_street_a": {"skin": hexc("2a2636"), "hood": hexc("1c1a24"), "top": hexc("1c1a24"),
                              "pants": hexc("15141b"), "shoes": hexc("0e0e12"), "hood_eye": hexc("f0d060")},
    "hostile_dark_street_b": {"skin": hexc("2a2636"), "hood": hexc("241c2c"), "top": hexc("241c2c"),
                              "pants": hexc("15141b"), "shoes": hexc("0e0e12"), "hood_eye": hexc("f07050"),
                              "extra": scarf_extra(hexc("6a2430"))},
}


def email_frame(body, direction: int, frame: int) -> Image.Image:
    """H-T3 Correo de última hora: a flying envelope with a red badge."""
    im = new(16, 24)
    y = (0, -1, -2, -1)[frame]
    body_sh = shade(body, 0.78)
    x0, x1 = (2, 13) if direction in (0, 1) else (4, 11)
    rect(im, x0, 9 + y, x1, 17 + y, body)
    rect(im, x0, 17 + y, x1, 17 + y, body_sh)
    if direction != 1:
        for i in range((x1 - x0 + 1) // 2):
            px(im, x0 + i, 9 + y + i, body_sh)
            px(im, x1 - i, 9 + y + i, body_sh)
    wing = hexc("f4f4f4")
    up = frame % 2 == 0
    for wx in (x0 - 2, x1 + 1):
        if up:
            rect(im, wx, 8 + y, wx + 1, 10 + y, wing)
        else:
            rect(im, wx, 12 + y, wx + 1, 14 + y, wing)
    if direction != 1:
        bx = x1 - 3
        rect(im, bx, 5 + y, bx + 3, 9 + y, hexc("d03a3a"))
        rect(im, bx + 1, 6 + y, bx + 2, 7 + y, hexc("ffffff"))
        rect(im, bx + 1, 9 + y, bx + 2, 9 + y, hexc("ffffff"))
    im = outline(im)
    rect(im, 5, 22, 10, 22, (0, 0, 0, 70))
    return im


def fatigue_frame(direction: int, frame: int) -> Image.Image:
    """H-V4 Cansancio: a sleepy cloud that yawns and drifts, with Zz above."""
    im = new(16, 24)
    y = (0, -1, -1, 0)[frame]
    body, light, dark = hexc("6a6a9a"), hexc("9090c4"), hexc("3c3c64")
    draw = ImageDraw.Draw(im)
    draw.ellipse([2, 8 + y, 13, 18 + y], fill=body)
    draw.ellipse([4, 9 + y, 9, 12 + y], fill=light)
    for i, wx in enumerate(range(3, 13, 3)):
        px(im, wx + (frame + i) % 2, 19 + y, body)
    if direction != 1:
        offset = -1 if direction == 2 else (1 if direction == 3 else 0)
        rect(im, 5 + offset, 13 + y, 6 + offset, 13 + y, dark)
        rect(im, 9 + offset, 13 + y, 10 + offset, 13 + y, dark)
        mouth = 1 if frame in (1, 2) else 0
        rect(im, 7 + offset, 15 + y, 8 + offset, 15 + y + mouth, dark)
    im = outline(im, hexc("24243c"))
    z = hexc("d8d8f8")
    zx, zy = 10 + frame % 2, 5 - frame
    for (dx, dy) in ((0, 0), (1, 0), (2, 0), (1, 1), (0, 2), (1, 2), (2, 2)):
        px(im, zx + dx, zy + dy, z)
    rect(im, 4, 22, 11, 22, (0, 0, 0, 60))
    return im


def printer_zone_frame(frame: int) -> Image.Image:
    """H-T4 Fila de la impresora: a jammed printer over a slow floor zone (32x48, like rain)."""
    im = new(32, 48)
    rect(im, 2, 22, 29, 46, (230, 200, 60, 70))
    for i in range(2, 30):
        stripe = hexc("e6c83c") if (i // 3) % 2 == 0 else hexc("2a2a2a")
        px(im, i, 22, stripe)
        px(im, i, 46, stripe)
    for j in range(22, 47):
        stripe = hexc("e6c83c") if (j // 3) % 2 == 0 else hexc("2a2a2a")
        px(im, 2, j, stripe)
        px(im, 29, j, stripe)
    rng = random.Random(41 + frame // 2)
    for _ in range(4):
        x, y = rng.randint(5, 23), rng.randint(26, 41)
        rect(im, x, y, x + 3, y + 2, hexc("f2f0e8"))
        px(im, x + 1, y + 1, hexc("9a9a9a"))
    printer = new(32, 48)
    rect(printer, 5, 4, 26, 19, hexc("c8c8c4"))
    rect(printer, 5, 4, 26, 7, hexc("5a5a62"))
    rect(printer, 5, 18, 26, 19, hexc("a4a4a0"))
    rect(printer, 9, 12, 22, 12, hexc("3a3a40"))
    length = (2, 5, 7, 3)[frame]
    rect(printer, 10, 13, 21, 12 + length, hexc("f6f4ec"))
    rect(printer, 11, 14, 20, 14, hexc("b0b0b0"))
    px(printer, 23, 5, hexc("50d060") if frame % 2 == 0 else hexc("e04040"))
    im.alpha_composite(outline(printer), (0, 0))
    return im


# ---------------------------------------------------------------- shading tools

BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))


def value_noise(seed: int, cell: float):
    """Smooth 2D value noise in [0, 1] with grid spacing [cell] px."""
    rng = random.Random(seed)
    table = [rng.random() for _ in range(4096)]

    def lattice(ix: int, iy: int) -> float:
        return table[(ix * 73856093 ^ iy * 19349663) & 4095]

    def at(x: float, y: float) -> float:
        gx, gy = x / cell, y / cell
        x0, y0 = math.floor(gx), math.floor(gy)
        fx, fy = gx - x0, gy - y0
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a, b = lattice(x0, y0), lattice(x0 + 1, y0)
        c, d = lattice(x0, y0 + 1), lattice(x0 + 1, y0 + 1)
        return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy
    return at


def fbm(seed: int, cell: float):
    n1, n2, n3 = value_noise(seed, cell), value_noise(seed + 1, cell / 2), value_noise(seed + 2, cell / 4)
    return lambda x, y: 0.55 * n1(x, y) + 0.3 * n2(x, y) + 0.15 * n3(x, y)


def mottle(im, x0, y0, x1, y1, base, light, dark, seed, cell=24.0, spread=0.12) -> None:
    """Fills a region with [base] and dithered [light]/[dark] patches, like hand-painted plaster or asphalt."""
    noise = fbm(seed, cell)
    data = im.load()
    for y in range(max(0, y0), min(im.height, y1 + 1)):
        for x in range(max(0, x0), min(im.width, x1 + 1)):
            v = noise(x, y)
            t = BAYER[y % 4][x % 4] / 16
            if v > 0.5 + spread + 0.04 * t * 2:
                data[x, y] = light
            elif v < 0.5 - spread - 0.04 * t * 2:
                data[x, y] = dark
            else:
                data[x, y] = base


def darken(im, x, y, k: float) -> None:
    if 0 <= x < im.width and 0 <= y < im.height:
        r, g, b, a = im.getpixel((x, y))
        if a:
            im.putpixel((x, y), (int(r * (1 - k)), int(g * (1 - k)), int(b * (1 - k)), a))


def lighten(im, x, y, k: float, color=(255, 255, 255)) -> None:
    if 0 <= x < im.width and 0 <= y < im.height:
        r, g, b, a = im.getpixel((x, y))
        if a:
            im.putpixel((x, y), (int(r + (color[0] - r) * k), int(g + (color[1] - g) * k), int(b + (color[2] - b) * k), a))


def shadow_band(im, x0, y0, x1, y1, side: str, strength: float = 0.45) -> None:
    """Banded, dithered ambient-occlusion shadow that fades away from [side] (top/bottom/left/right)."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if side == "top":
                t = (y - y0) / max(1, y1 - y0)
            elif side == "bottom":
                t = (y1 - y) / max(1, y1 - y0)
            elif side == "left":
                t = (x - x0) / max(1, x1 - x0)
            else:
                t = (x1 - x) / max(1, x1 - x0)
            k = strength * (1 - t) ** 1.4 + (BAYER[y % 4][x % 4] / 16 - 0.5) * 0.12
            k = round(max(0.0, k) / 0.1) * 0.1
            if k > 0:
                darken(im, x, y, min(k, 0.8))


def blob(im, cx, cy, rx, ry, color, seed, rough=0.45) -> None:
    """Irregular soft-edged stain (the plaster stains of the home walls)."""
    noise = value_noise(seed, max(3.0, min(rx, ry) / 1.5))
    for y in range(int(cy - ry * 1.6), int(cy + ry * 1.6) + 1):
        for x in range(int(cx - rx * 1.6), int(cx + rx * 1.6) + 1):
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d < 1 + (noise(x, y) - 0.5) * 2 * rough and 0 <= x < im.width and 0 <= y < im.height and im.getpixel((x, y))[3]:
                px(im, x, y, color)


def line(im, x0, y0, x1, y1, color) -> None:
    ImageDraw.Draw(im).line([x0, y0, x1, y1], fill=color, width=1)


def crack(im, x, y, length, color, rng) -> None:
    for _ in range(length):
        px(im, x, y, color)
        x += rng.choice((1, 1, 1, 0))
        y += rng.choice((-1, 0, 0, 1))


# ---------------------------------------------------------------- street pieces

PAL = {
    "outline": hexc("1e1e1e"), "brown_line": hexc("2f1b1a"),
    "slab": hexc("b3aea2"), "slab_hi": hexc("c9c4b8"), "slab_lo": hexc("9a9588"), "grout": hexc("7d786d"),
    "curb_top": hexc("d2cec2"), "curb_face": hexc("8f8b80"), "curb_dark": hexc("6d695f"),
    "asphalt": hexc("50535b"), "asphalt_hi": hexc("5b5e67"), "asphalt_lo": hexc("464950"),
    "paint_w": hexc("e4e2d8"), "paint_y": hexc("e2bf48"),
    "roof": hexc("b4583c"), "roof_hi": hexc("cf7552"), "roof_lo": hexc("8a3c28"), "roof_edge": hexc("5a2618"),
    "frame": hexc("efe6d2"), "reja": hexc("2b2f3a"), "glass_top": hexc("86a8b6"), "glass_bot": hexc("3c5a6a"),
    "wood": hexc("8a5a34"), "wood_hi": hexc("a87048"), "wood_lo": hexc("6b4a2b"),
    "metal": hexc("5c6670"), "metal_hi": hexc("7c8792"), "metal_lo": hexc("3e464f"),
    "leaf": hexc("4c8a3c"), "leaf_hi": hexc("6aac50"), "leaf_lo": hexc("2f6230"),
    "soil": hexc("5a4030"), "grass": hexc("5e9a44"), "grass_hi": hexc("7cb85a"), "grass_lo": hexc("44783a"),
}
FACADE_COLORS = ["e9dcbc", "e2a072", "8fb8ac", "e8c066", "b4c87e", "d48c7a", "c2b2d8", "f2e4c4", "9cb4d0"]


def sidewalk(im, x0, y0, x1, y1, rng, style: str = "slab") -> None:
    """Concrete sidewalk: bevelled slabs with tint variation, cracks, gum spots and weeds in the joints."""
    w, h = (24, 16) if style == "slab" else (12, 6)
    for sy in range(y0, y1 + 1, h):
        row_off = (w // 2) if ((sy - y0) // h) % 2 and style == "slab" else 0
        for sx in range(x0 - row_off, x1 + 1, w):
            tint = rng.uniform(0.95, 1.04)
            if style == "pavers":
                base = hexc("a8a296") if ((sy - y0) // h) % 5 == 2 else hexc("b36c54")
            else:
                base = PAL["slab"]
            base = shade(base, tint)
            ax0, ay0, ax1, ay1 = max(sx, x0), sy, min(sx + w - 1, x1), min(sy + h - 1, y1)
            rect(im, ax0, ay0, ax1, ay1, base)
            rect(im, ax0, ay0, ax1, ay0, shade(base, 1.1))
            rect(im, ax0, ay0, ax0, ay1, shade(base, 1.06))
            rect(im, ax0, ay1, ax1, ay1, PAL["grout"])
            rect(im, ax1, ay0, ax1, ay1, PAL["grout"])
            if ax1 - ax0 < 5 or ay1 - ay0 < 4:
                continue
            speckle(im, ax0 + 1, ay0 + 1, ax1 - 1, ay1 - 1, [shade(base, 0.94), shade(base, 1.04)], 0.06, rng)
            if rng.random() < 0.08:
                crack(im, rng.randint(ax0, ax1), rng.randint(ay0, ay1), rng.randint(5, 12), shade(base, 0.7), rng)
            if rng.random() < 0.05:
                px(im, rng.randint(ax0 + 2, ax1 - 2), rng.randint(ay0 + 2, ay1 - 2), shade(base, 0.6))
            if rng.random() < 0.06:
                gx = rng.randint(ax0, ax1)
                for k in range(rng.randint(2, 4)):
                    px(im, gx + k, ay1 - (k % 2), PAL["leaf"] if k % 2 else PAL["leaf_hi"])


def tactile_strip(im, x0, y, x1) -> None:
    rect(im, x0, y, x1, y + 7, hexc("d8b23a"))
    rect(im, x0, y, x1, y, hexc("ecc85a"))
    rect(im, x0, y + 7, x1, y + 7, hexc("a88a28"))
    for x in range(x0 + 1, x1, 3):
        for yy in (y + 2, y + 5):
            px(im, x, yy, hexc("f0d070"))
            px(im, x, yy + 1, hexc("b8962c"))


def curb(im, x0, y0, x1, y1, painted=()) -> None:
    """Kerb seen from above: light top face, darker front face, shadow line below."""
    rect(im, x0, y0, x1, y0 + 1, PAL["curb_top"])
    rect(im, x0, y0 + 2, x1, y1 - 1, PAL["curb_face"])
    rect(im, x0, y1, x1, y1, PAL["curb_dark"])
    for x in range(x0, x1 + 1, 12):
        px(im, x, y0 + 2, PAL["curb_dark"])
        px(im, x, y0 + 3, PAL["curb_dark"])
    for px0, px1 in painted:
        for x in range(max(x0, px0), min(x1, px1) + 1):
            color = hexc("e2bf48") if (x // 8) % 2 == 0 else hexc("2a2a2e")
            rect(im, x, y0, x, y1 - 1, color)
            px(im, x, y0, shade(color, 1.15))


def asphalt(im, x0, y0, x1, y1, rng, crossings=(), bike_lane=False, bus_lane=False) -> None:
    """Asphalt with mottled wear, tyre tracks, repairs, worn paint, drains and manholes."""
    mottle(im, x0, y0, x1, y1, PAL["asphalt"], PAL["asphalt_hi"], PAL["asphalt_lo"], rng.randint(0, 9999), cell=40, spread=0.1)
    speckle(im, x0, y0, x1, y1, [hexc("5f626b"), hexc("3f4248"), hexc("575a62")], 0.1, rng)
    mid = (y0 + y1) // 2
    lane = (y1 - y0) // 2
    for track in (y0 + lane // 3, y0 + 2 * lane // 3, mid + lane // 3, mid + 2 * lane // 3):
        for y in range(track - 2, track + 3):
            for x in range(x0, x1 + 1):
                if rng.random() < 0.35:
                    darken(im, x, y, 0.08)
    for _ in range((x1 - x0) // 260 + 1):
        rx, ry = rng.randint(x0 + 10, x1 - 60), rng.randint(y0 + 8, max(y0 + 8, y1 - 30))
        rw, rh = rng.randint(24, 50), rng.randint(10, 22)
        rect(im, rx, ry, rx + rw, ry + rh, hexc("44474e"))
        speckle(im, rx, ry, rx + rw, ry + rh, [hexc("3c3f45"), hexc("4c4f56")], 0.2, rng)
        rect(im, rx, ry, rx + rw, ry, hexc("3a3d43"))
        rect(im, rx, ry + rh, rx + rw, ry + rh, hexc("5c5f68"))
    for _ in range((x1 - x0) // 150 + 1):
        crack(im, rng.randint(x0, x1 - 20), rng.randint(y0 + 4, y1 - 4), rng.randint(8, 20), hexc("38393f"), rng)
    for _ in range((x1 - x0) // 300 + 1):
        blob(im, rng.randint(x0 + 20, x1 - 20), rng.randint(y0 + 10, y1 - 10), rng.randint(5, 9), rng.randint(3, 5),
             hexc("3e3f46"), rng.randint(0, 999))

    def worn(xa, ya, xb, yb, color):
        for y in range(ya, yb + 1):
            for x in range(xa, xb + 1):
                if rng.random() > 0.04:
                    px(im, x, y, color if rng.random() > 0.08 else shade(color, 0.9))

    for x in range(x0, x1, 40):
        worn(x + 8, mid - 1, x + 28, mid, PAL["paint_y"])
    worn(x0, y0 + 4, x1, y0 + 4, PAL["paint_w"])
    worn(x0, y1 - 4, x1, y1 - 4, PAL["paint_w"])
    if bike_lane:
        rect(im, x0, y0 + 6, x1, y0 + 19, hexc("4e8a58"))
        speckle(im, x0, y0 + 6, x1, y0 + 19, [hexc("44784c"), hexc("5a9a62")], 0.15, rng)
        worn(x0, y0 + 20, x1, y0 + 20, PAL["paint_w"])
        for x in range(x0 + 60, x1, 200):
            for cx in (x, x + 10):
                ImageDraw.Draw(im).ellipse([cx, y0 + 10, cx + 5, y0 + 15], outline=PAL["paint_w"])
            line(im, x + 3, y0 + 12, x + 8, y0 + 10, PAL["paint_w"])
            line(im, x + 8, y0 + 10, x + 13, y0 + 12, PAL["paint_w"])
    if bus_lane:
        for bx in bus_lane:
            text(im, bx, y0 + 10, "BUS", PAL["paint_y"], size=3)
    for cx in crossings:
        rect(im, cx - 6, y0 + 6, cx - 4, y1 - 6, PAL["paint_w"])
        for y in range(y0 + 8, y1 - 8, 10):
            rect(im, cx, y, cx + 30, y + 5, PAL["paint_w"])
            rect(im, cx, y + 5, cx + 30, y + 5, shade(PAL["paint_w"], 0.86))
            for _ in range(3):
                px(im, rng.randint(cx, cx + 30), rng.choice((y, y + 5)), PAL["asphalt"])
    for x in range(x0 + 70, x1 - 20, 230):
        for yy in (y0 + 1, y1 - 7):
            rect(im, x, yy, x + 15, yy + 6, hexc("2a2b30"))
            for gx in range(x + 1, x + 15, 2):
                rect(im, gx, yy + 1, gx, yy + 5, hexc("15161a"))
    for x in range(x0 + 150, x1 - 20, 410):
        cy = mid + rng.choice((-lane // 2, lane // 2))
        ImageDraw.Draw(im).ellipse([x, cy - 7, x + 15, cy + 7], fill=hexc("3a3b40"), outline=hexc("2a2b30"))
        for gy in range(cy - 4, cy + 5, 3):
            line(im, x + 3, gy, x + 12, gy, hexc("55575e"))


def tree_pit(im, x, y, w=22, h=12) -> None:
    rect(im, x, y, x + w - 1, y + h - 1, PAL["curb_face"])
    rect(im, x + 2, y + 2, x + w - 3, y + h - 3, PAL["soil"])
    speckle(im, x + 2, y + 2, x + w - 3, y + h - 3, [hexc("6a4c38"), hexc("4a3428")], 0.3, random.Random(x))
    for k in range(4):
        px(im, x + 4 + k * 4, y + h - 4, PAL["grass_hi"])
        px(im, x + 4 + k * 4, y + h - 5, PAL["grass"])


def grass(im, x0, y0, x1, y1, rng) -> None:
    mottle(im, x0, y0, x1, y1, PAL["grass"], PAL["grass_hi"], PAL["grass_lo"], rng.randint(0, 999), cell=18, spread=0.12)
    for _ in range((x1 - x0) * (y1 - y0) // 60):
        x, y = rng.randint(x0, x1), rng.randint(y0 + 1, y1)
        px(im, x, y, PAL["grass_hi"])
        px(im, x, y - 1, hexc("8ccc6a"))
    for _ in range((x1 - x0) * (y1 - y0) // 900):
        x, y = rng.randint(x0 + 2, x1 - 2), rng.randint(y0 + 2, y1 - 2)
        color = rng.choice((hexc("f4f0e0"), hexc("f0d060"), hexc("e88aa8")))
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            px(im, x + dx, y + dy, color)
        px(im, x, y, hexc("e0a030"))


def puddle(im, cx, cy, rx, ry, seed) -> None:
    blob(im, cx, cy, rx, ry, hexc("6a7c90"), seed, rough=0.3)
    blob(im, cx - rx // 4, cy - 1, rx // 2, max(1, ry // 3), hexc("9ab0c4"), seed + 1, rough=0.2)


# ---------------------------------------------------------------- facades (walls layer)

def roof(im, x0, x1, top, bottom, rng) -> None:
    """3/4 clay-tile roof edge: rows of tiles with per-tile light, then the dark eave."""
    for y in range(top, bottom):
        row = (y - top) // 4
        for x in range(x0, x1 + 1):
            tile_x = (x - x0 + (row % 2) * 3) % 6
            phase = (y - top) % 4
            c = PAL["roof"]
            if phase == 0:
                c = PAL["roof_hi"]
            elif phase == 3:
                c = PAL["roof_lo"]
            elif tile_x == 0:
                c = hexc("a24c33")
            elif tile_x == 5:
                c = hexc("c0664a")
            px(im, x, y, c)
    for _ in range((x1 - x0) // 10):
        tx, ty = rng.randint(x0, x1 - 5), top + 4 * rng.randint(0, (bottom - top) // 4 - 1)
        rect(im, tx, ty + 1, tx + 4, ty + 2, rng.choice((hexc("9a4a32"), hexc("c87050"), hexc("7a6a3a"))))
    rect(im, x0, bottom, x1, bottom + 1, PAL["roof_edge"])


def window(im, x, y, w, h, lit: list, rng, reja=True, curtain=None, pot=False) -> None:
    rect(im, x - 2, y - 2, x + w + 1, y + h + 1, PAL["frame"])
    rect(im, x - 2, y - 2, x + w + 1, y - 2, shade(PAL["frame"], 1.05))
    rect(im, x + w + 1, y - 2, x + w + 1, y + h + 1, shade(PAL["frame"], 0.82))
    for yy in range(y, y + h):
        t = (yy - y) / max(1, h - 1)
        c = tuple(int(PAL["glass_top"][i] + (PAL["glass_bot"][i] - PAL["glass_top"][i]) * t) for i in range(3)) + (255,)
        rect(im, x, yy, x + w - 1, yy, c)
    for k in range(0, min(w, h), 1):
        px(im, x + w - 4 - k, y + 1 + k, hexc("b8d0dc"))
        px(im, x + w - 7 - k, y + 1 + k, hexc("a4c0ce"))
    lit.append((x, y, x + w - 1, y + h - 1))
    if curtain:
        rect(im, x, y, x + 3, y + h - 1, curtain)
        rect(im, x + w - 4, y, x + w - 1, y + h - 1, curtain)
        for yy in range(y, y + h, 3):
            px(im, x + 1, yy, shade(curtain, 0.8))
            px(im, x + w - 3, yy, shade(curtain, 0.8))
    if reja:
        for gx in range(x + 2, x + w - 1, 3):
            rect(im, gx, y, gx, y + h - 1, PAL["reja"])
        rect(im, x, y + h // 2, x + w - 1, y + h // 2, PAL["reja"])
        for gx in range(x + 1, x + w - 1, 3):
            px(im, gx, y + 2, PAL["reja"])
            px(im, gx + 1, y + 1, PAL["reja"])
    rect(im, x - 3, y + h + 2, x + w + 2, y + h + 3, hexc("d8ccb4"))
    rect(im, x - 3, y + h + 4, x + w + 2, y + h + 4, hexc("9a8e78"))
    if pot:
        rect(im, x, y + h - 2, x + w - 1, y + h + 1, hexc("b0543a"))
        rect(im, x, y + h - 2, x + w - 1, y + h - 2, hexc("c8664a"))
        for k in range(x, x + w, 2):
            px(im, k, y + h - 3, PAL["leaf"])
            px(im, k + 1, y + h - 4, PAL["leaf_hi"])
            if rng.random() < 0.4:
                px(im, k, y + h - 5, rng.choice((hexc("e04860"), hexc("f0a0c0"), hexc("f0d060"))))


def door(im, x, y, w, bottom, rng, kind="wood") -> None:
    rect(im, x - 3, y - 3, x + w + 2, bottom, hexc("d8ccb4"))
    rect(im, x - 3, y - 3, x + w + 2, y - 3, hexc("efe6d2"))
    rect(im, x - 1, y - 1, x + w, bottom, PAL["outline"])
    if kind == "wood":
        rect(im, x, y, x + w - 1, bottom, PAL["wood"])
        for gx in range(x + 3, x + w - 1, 4):
            rect(im, gx, y, gx, bottom, PAL["wood_lo"])
        for py0, py1 in ((y + 3, y + 16), (y + 20, bottom - 4)):
            rect(im, x + 3, py0, x + w - 4, py0, PAL["wood_lo"])
            rect(im, x + 3, py1, x + w - 4, py1, PAL["wood_hi"])
        px(im, x + w - 4, (y + bottom) // 2, hexc("e3c060"))
    else:
        color = hexc(rng.choice(["3c6aa0", "4a7a5a", "8a3a34", "5a5a6a"]))
        rect(im, x, y, x + w - 1, bottom, color)
        for k in range(0, w, 6):
            for yy in range(y + 3, bottom - 2, 6):
                px(im, x + k + 3, yy, shade(color, 1.25))
                px(im, x + k + 2, yy + 1, shade(color, 0.7))
                px(im, x + k + 4, yy + 1, shade(color, 0.7))
                px(im, x + k + 3, yy + 2, shade(color, 1.25))
        rect(im, x + w // 2 - 3, y + 10, x + w // 2 + 2, y + 10, shade(color, 0.6))
        px(im, x + w - 3, (y + bottom) // 2, hexc("e3c060"))
    rect(im, x - 5, bottom + 1, x + w + 4, bottom + 2, hexc("c8c2b4"))


def plaster(im, x0, x1, top, bottom, color, rng) -> None:
    wall = hexc(color)
    mottle(im, x0, top, x1, bottom, wall, shade(wall, 1.04), shade(wall, 0.94), rng.randint(0, 9999), cell=14, spread=0.16)
    for _ in range((x1 - x0) // 30 + 1):
        blob(im, rng.randint(x0, x1), rng.randint(bottom - 18, bottom), rng.randint(6, 14), rng.randint(4, 8),
             shade(wall, 0.86), rng.randint(0, 999))
    for _ in range((x1 - x0) // 50):
        blob(im, rng.randint(x0, x1), rng.randint(top + 4, bottom - 10), rng.randint(3, 8), rng.randint(3, 6),
             shade(wall, 1.05), rng.randint(0, 999))
    if rng.random() < 0.35:
        bx, by = rng.randint(x0 + 4, max(x0 + 4, x1 - 30)), rng.randint(top + 8, bottom - 26)
        noise = value_noise(rng.randint(0, 999), 5)
        for y in range(by, by + 20):
            for x in range(bx, bx + 26):
                d = ((x - bx - 13) / 13) ** 2 + ((y - by - 10) / 10) ** 2
                if d < 1 + (noise(x, y) - 0.5) * 1.2 and x0 <= x <= x1:
                    row = (y - by) // 3
                    mortar = (y - by) % 3 == 2 or (x - bx + row * 3) % 7 == 0
                    px(im, x, y, hexc("82412f") if mortar else (hexc("b96c49") if (x + y) % 5 else hexc("c97c58")))


def house(im, x0, x1, H, color, rng, lit, home=False) -> None:
    roof(im, x0, x1, 0, 12, rng)
    plaster(im, x0, x1, 14, H - 10, color, rng)
    shadow_band(im, x0, 14, x1, 19, "top", 0.5)
    wall = hexc(color)
    rect(im, x0, H - 10, x1, H - 1, shade(wall, 0.72))
    rect(im, x0, H - 10, x1, H - 10, shade(wall, 0.88))
    speckle(im, x0, H - 9, x1, H - 1, [shade(wall, 0.66), shade(wall, 0.78)], 0.15, rng)
    width = x1 - x0 + 1
    curtain = hexc(rng.choice(["e8d8a0", "d88a8a", "a8c8e0", "f0f0e8", "c8a8d8"]))
    door_w = 20
    door_x = x0 + rng.randint(8, max(8, width - door_w - 10))
    door(im, door_x, H - 46, door_w, H - 3, rng, "wood" if home or rng.random() < 0.5 else "metal")
    if home:
        rect(im, door_x - 2, H - 60, door_x + door_w + 1, H - 52, PAL["outline"])
        rect(im, door_x - 1, H - 59, door_x + door_w, H - 53, hexc("f4f0e8"))
        text(im, door_x + (door_w - text_width("CASA")) // 2, H - 58, "CASA", hexc("3c6aa0"))
        rect(im, door_x + door_w + 4, H - 50, door_x + door_w + 7, H - 47, hexc("f8e8a8"))
        lit.append((door_x + door_w + 3, H - 51, door_x + door_w + 8, H - 46))
        lit.append((door_x + 3, H - 43, door_x + door_w - 4, H - 36))
        rect(im, door_x - 4, H - 2, door_x + door_w + 3, H - 1, hexc("8a3a34"))
    rect(im, door_x + door_w + 5, H - 40, door_x + door_w + 9, H - 37, hexc("f4f0e8"))
    rect(im, door_x + door_w + 6, H - 39, door_x + door_w + 8, H - 38, hexc("3c6aa0"))
    two_storey = width >= 110 and rng.random() < 0.6
    slots = [wx for wx in range(x0 + 8, x1 - 24, 32) if wx + 24 < door_x - 4 or wx > door_x + door_w + 12]
    for wx in slots:
        window(im, wx, H - 50, 22, 20, lit, rng, curtain=curtain, pot=rng.random() < 0.35)
    if two_storey:
        for wx in range(x0 + 10, x1 - 22, 30):
            window(im, wx, 20, 18, 12, lit, rng, reja=False, curtain=curtain)
        rect(im, x0 + 4, 34, x1 - 4, 35, hexc("2b2f3a"))
        for bx in range(x0 + 4, x1 - 3, 4):
            rect(im, bx, 36, bx, 39, hexc("2b2f3a"))
        rect(im, x0 + 2, 40, x1 - 2, 41, shade(wall, 0.8))
        rect(im, x0 + 2, 42, x1 - 2, 42, shade(wall, 0.65))
    if rng.random() < 0.6:
        mx = x1 - 12
        rect(im, mx, H - 34, mx + 6, H - 26, hexc("9aa2a8"))
        rect(im, mx + 1, H - 33, mx + 5, H - 30, hexc("d8e0e4"))
        px(im, mx + 3, H - 28, hexc("2a2a2a"))
    if rng.random() < 0.5:
        dx = x0 + 2
        rect(im, dx, 12, dx + 1, H - 2, hexc("8a929a"))
        for by in range(20, H - 4, 14):
            rect(im, dx - 1, by, dx + 2, by, hexc("5a6268"))


SHOPS = [("TIENDA", "b03a3a", "f4f0e0", ("c83c3c", "f4f0e8")), ("PANADERIA", "6f4932", "f4e0a0", ("e3b55a", "f4f0e8")),
         ("DROGUERIA", "2e8a4a", "f4fff4", ("3c8a4c", "f4f0e8")), ("VARIEDADES", "3c6aa0", "f4f0e0", ("3c6aa0", "f0d060")),
         ("CAFE", "4a321c", "f0d8a0", ("8a3a34", "e9dcbc"))]


def shop(im, x0, x1, H, color, rng, lit, kind=None) -> None:
    roof(im, x0, x1, 0, 10, rng)
    plaster(im, x0, x1, 12, H - 1, color, rng)
    shadow_band(im, x0, 12, x1, 16, "top", 0.5)
    name, board, ink, stripes = kind or rng.choice(SHOPS)
    width = x1 - x0 + 1
    bw = min(width - 10, text_width(name) + 12)
    bx = x0 + (width - bw) // 2
    rect(im, bx - 1, 17, bx + bw, 30, PAL["outline"])
    rect(im, bx, 18, bx + bw - 1, 29, hexc(board))
    rect(im, bx, 18, bx + bw - 1, 18, shade(hexc(board), 1.25))
    rect(im, bx, 29, bx + bw - 1, 29, shade(hexc(board), 0.7))
    text(im, bx + (bw - text_width(name)) // 2, 21, name, hexc(ink))
    if name == "DROGUERIA":
        cx = bx - 9 if bx - 9 > x0 else bx + bw + 2
        rect(im, cx + 2, 18, cx + 4, 28, hexc("3cc060"))
        rect(im, cx, 21, cx + 6, 25, hexc("3cc060"))
    ax0, ax1 = x0 + 3, x1 - 3
    for x in range(ax0, ax1 + 1):
        c = hexc(stripes[((x - ax0) // 6) % 2])
        rect(im, x, 33, x, 41, c)
        px(im, x, 33, shade(c, 0.8))
        px(im, x, 34, shade(c, 0.9))
        if ((x - ax0) % 6) in (1, 2, 3, 4):
            px(im, x, 42, c)
            if ((x - ax0) % 6) in (2, 3):
                px(im, x, 43, c)
    rect(im, ax0, 32, ax1, 32, PAL["outline"])
    oy0, oy1 = 44, H - 4
    rect(im, ax0 + 2, oy0, ax1 - 2, oy1, hexc("2c2420"))
    shadow_band(im, ax0 + 2, oy0, ax1 - 2, oy0 + 6, "top", 0.4)
    for sy in range(oy0, oy0 + 6):
        rect(im, ax0 + 2, sy, ax1 - 2, sy, hexc("8e949c") if sy % 2 == 0 else hexc("6e747c"))
    goods = [hexc(c) for c in ("d03a3a", "f0d060", "4ab050", "f4f0e8", "3c6aa0", "e88a40")]
    if name == "PANADERIA":
        goods = [hexc("d89048"), hexc("c87838"), hexc("e8b060")]
    for shelf_y in range(oy0 + 12, oy1 - 14, 9):
        rect(im, ax0 + 3, shelf_y, ax1 - 3, shelf_y, hexc("6b4a2b"))
        x = ax0 + 4
        while x < ax1 - 5:
            c = rng.choice(goods)
            hgt = rng.randint(2, 5)
            rect(im, x, shelf_y - hgt, x + 1, shelf_y - 1, c)
            px(im, x, shelf_y - hgt, shade(c, 1.2))
            x += 3
    lit.append((ax0 + 2, oy0 + 6, ax1 - 2, oy1 - 12))
    rect(im, ax0 + 6, oy1 - 11, ax1 - 6, oy1, hexc(board))
    rect(im, ax0 + 6, oy1 - 11, ax1 - 6, oy1 - 10, hexc("cde4ee"))
    rect(im, ax0 + 6, oy1, ax1 - 6, oy1, shade(hexc(board), 0.6))
    rect(im, x0, H - 3, x1, H - 1, shade(hexc(color), 0.7))


def tower(im, x0, x1, H, rng, lit, entrance=False) -> None:
    """Office tower: glass curtain wall with sky reflections over a granite podium."""
    sky_top, sky_bot = hexc("9ec0da"), hexc("4a6a88")
    clouds = fbm(rng.randint(0, 999), 18)
    for y in range(0, H - 34):
        t = y / (H - 34)
        base = tuple(int(sky_top[i] + (sky_bot[i] - sky_top[i]) * t) for i in range(3)) + (255,)
        for x in range(x0, x1 + 1):
            c = base
            if clouds(x * 0.7, y * 1.6) > 0.62:
                c = shade(base, 1.18)
            px(im, x, y, c)
    for k in range(x0 - 60, x1, 70):
        for i in range(0, 60):
            for wdt in range(6):
                lighten(im, k + i + wdt, H - 36 - i, 0.18)
    for x in range(x0, x1 + 1):
        if (x - x0) % 16 in (0, 1):
            rect(im, x, 0, x, H - 35, hexc("36404c") if (x - x0) % 16 == 0 else hexc("56606c"))
    for y in range(0, H - 34, 12):
        rect(im, x0, y, x1, y, hexc("36404c"))
        rect(im, x0, y + 1, x1, y + 1, hexc("6a7684"))
    for wy in range(2, H - 36, 12):
        for wx in range(x0 + 2, x1 - 12, 16):
            if rng.random() < 0.4:
                lit.append((wx, wy, wx + 13, wy + 9))
                if rng.random() < 0.5:
                    for by in range(wy, wy + 5, 2):
                        rect(im, wx, by, wx + 13, by, hexc("d8e0e6"))
    rect(im, x0, H - 34, x1, H - 1, hexc("8c8a86"))
    for gy in range(H - 34, H, 9):
        rect(im, x0, gy, x1, gy, hexc("74726e"))
        for gx in range(x0 + ((gy // 9) % 2) * 12, x1, 24):
            rect(im, gx, gy, gx, gy + 8, hexc("74726e"))
    speckle(im, x0, H - 34, x1, H - 1, [hexc("9c9a96"), hexc("7e7c78"), hexc("a8a6a2")], 0.12, rng)
    rect(im, x0, H - 34, x1, H - 33, hexc("b4b2ae"))
    if entrance:
        ex = x1 - 84
        rect(im, ex - 6, H - 46, ex + 61, H - 40, hexc("2a3440"))
        rect(im, ex - 6, H - 40, ex + 61, H - 39, hexc("c8a84a"))
        text(im, ex + (56 - text_width("OFICINAS")) // 2, H - 45, "OFICINAS", hexc("f0e0a0"))
        rect(im, ex, H - 38, ex + 55, H - 3, hexc("2a3440"))
        rect(im, ex + 2, H - 36, ex + 53, H - 3, hexc("e8d8a8"))
        for dx in (ex + 2, ex + 28):
            rect(im, dx, H - 36, dx + 25, H - 3, hexc("a8c8dc"))
            rect(im, dx, H - 36, dx, H - 3, hexc("c8a84a"))
            for i in range(12):
                px(im, dx + 18 - i, H - 34 + i, hexc("dcecf4"))
        rect(im, ex + 27, H - 36, ex + 28, H - 3, hexc("c8a84a"))
        lit.append((ex + 2, H - 36, ex + 53, H - 3))
        shadow_band(im, ex, H - 38, ex + 55, H - 32, "top", 0.4)


def cables(im, width, rng, poles) -> None:
    for (a, b) in zip(poles, poles[1:]):
        for base, sag in ((6, 10), (10, 13)):
            prev = None
            for x in range(a, b + 1):
                t = (x - a) / max(1, b - a)
                y = int(base + sag * 4 * t * (1 - t))
                if prev is not None:
                    line(im, x - 1, prev, x, y, hexc("1e1e1e"))
                prev = y


def facade_band(width: int, height: int, seed: int, style: str = "barrio", home_at=None, cable=True):
    """The walls layer of a street: a row of buildings. Returns (image, lit rects for the night)."""
    rng = random.Random(seed)
    im = new(width, height)
    lit: list = []
    x = 0
    plan = []
    while x < width:
        remaining = width - x
        w = rng.choice((96, 112, 128, 144)) if style == "barrio" else rng.choice((160, 192, 208))
        if remaining - w < 64:
            w = remaining
        plan.append((x, min(width - 1, x + w - 1)))
        x += w
    last_shop = False
    shop_kinds = rng.sample(SHOPS, len(SHOPS))
    shops_done = 0
    for index, (a, b) in enumerate(plan):
        if style == "towers":
            tower(im, a, b, height, rng, lit, entrance=index == len(plan) - 1)
        elif home_at is not None and index == len(plan) - 1:
            house(im, a, b, height, "e9dcbc", rng, lit, home=True)
        elif not last_shop and rng.random() < 0.4:
            shop(im, a, b, height, rng.choice(FACADE_COLORS), rng, lit, shop_kinds[shops_done % len(shop_kinds)])
            shops_done += 1
            last_shop = True
            continue
        else:
            house(im, a, b, height, rng.choice(FACADE_COLORS), rng, lit)
        last_shop = False
    for a, b in plan:
        rect(im, a, 0, a, height - 1, PAL["brown_line"])
        if a:
            shadow_band(im, a + 1, 12, a + 4, height - 1, "left", 0.3)
    rect(im, 0, height - 1, width - 1, height - 1, PAL["brown_line"])
    if cable and style == "barrio":
        cables(im, width, rng, list(range(0, width + 1, 320)))
    return im, lit


def low_wall(im, y0, y1, kind: str, rng) -> None:
    """Bottom border of a street level seen from above: a railing on a kerb, or a hedge."""
    w = im.width
    if kind == "hedge":
        for x in range(0, w):
            top = y0 + int(2 + 2 * math.sin(x * 0.35) + rng.random())
            rect(im, x, top, x, y1, PAL["leaf"])
        mottle(im, 0, y0, w - 1, y1, PAL["leaf"], PAL["leaf_hi"], PAL["leaf_lo"], rng.randint(0, 999), cell=6, spread=0.1)
        for x in range(0, w):
            top = y0 + int(2 + 2 * math.sin(x * 0.35))
            for y in range(y0, top):
                px(im, x, y, CLEAR)
            px(im, x, top, PAL["leaf_hi"])
        rect(im, 0, y1, w - 1, y1, PAL["outline"])
        return
    rect(im, 0, y1 - 7, w - 1, y1, hexc("a8a498"))
    rect(im, 0, y1 - 7, w - 1, y1 - 6, hexc("cecabe"))
    rect(im, 0, y1, w - 1, y1, PAL["outline"])
    speckle(im, 0, y1 - 5, w - 1, y1 - 1, [hexc("989488"), hexc("b4b0a4")], 0.15, rng)
    rect(im, 0, y0, w - 1, y0 + 1, PAL["metal_hi"])
    rect(im, 0, y0 + 2, w - 1, y0 + 2, PAL["metal_lo"])
    for x in range(2, w, 6):
        rect(im, x, y0 + 3, x, y1 - 8, PAL["metal"])
        px(im, x + 1, y0 + 3, PAL["metal_lo"])
    for x in range(0, w, 48):
        rect(im, x, y0 - 1, x + 2, y1 - 8, PAL["metal_lo"])
        rect(im, x, y0 - 1, x + 2, y0 - 1, PAL["metal_hi"])


# ---------------------------------------------------------------- night / dusk

def grade(im: Image.Image, tint, lamps=(), lit_rects=(), lit_color=hexc("f0c86e")) -> Image.Image:
    """Bakes dusk or night light: multiply by [tint], paint lit windows, add warm lamp pools."""
    out = im.copy()
    data = out.load()
    w, h = out.size
    tr, tg, tb = tint
    for y in range(h):
        for x in range(w):
            r, g, b, a = data[x, y]
            if a:
                data[x, y] = (int(r * tr), int(g * tg), int(b * tb), a)
    for x0, y0, x1, y1 in lit_rects:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if 0 <= x < w and 0 <= y < h and data[x, y][3]:
                    r, g, b, a = data[x, y]
                    data[x, y] = (min(255, (r + lit_color[0] * 2) // 3), min(255, (g + lit_color[1] * 2) // 3),
                                  min(255, (b + lit_color[2] * 2) // 3), a)
    for lx, ly, radius in lamps:
        for y in range(max(0, ly - radius), min(h, ly + radius)):
            for x in range(max(0, lx - radius), min(w, lx + radius)):
                d = math.hypot(x - lx, (y - ly) * 1.7)
                if d < radius and data[x, y][3]:
                    k = (1 - d / radius) ** 1.3 * 0.6 + (BAYER[y % 4][x % 4] / 16 - 0.5) * 0.06
                    k = max(0.0, round(k / 0.08) * 0.08)
                    r, g, b, a = data[x, y]
                    data[x, y] = (min(255, int(r + (255 - r) * k)), min(255, int(g + (214 - g) * k)),
                                  min(255, int(b + (150 - b) * k * 0.6)), a)
    return out


DUSK = (1.0, 0.8, 0.7)
EVENING = (0.74, 0.64, 0.74)
NIGHT = (0.48, 0.52, 0.78)


# ---------------------------------------------------------------- street levels

def street_level(width, height, seed, style="barrio", crossings=(), bottom="rail", pits=(), tactile=False,
                 bike_lane=False, bus_lane=(), painted=(), puddles=0, home_at=None):
    """Horizontal street. Floor: sidewalk, kerb, road, kerb, sidewalk (or park). Walls: facades + bottom border."""
    rng = random.Random(seed)
    floor = new(width, height)
    sidewalk(floor, 0, 96, width - 1, 145, rng, "pavers" if style == "towers" else "slab")
    if tactile:
        tactile_strip(floor, 0, 134, width - 1)
    for px0 in pits:
        tree_pit(floor, px0, 122)
    shadow_band(floor, 0, 96, width - 1, 104, "top", 0.42)
    curb(floor, 0, 146, width - 1, 151, painted)
    asphalt(floor, 0, 152, width - 1, 273, rng, crossings, bike_lane, bus_lane)
    shadow_band(floor, 0, 152, width - 1, 155, "top", 0.35)
    curb(floor, 0, 274, width - 1, 279)
    if bottom == "park":
        sidewalk(floor, 0, 280, width - 1, 307, rng)
        grass(floor, 0, 308, width - 1, height - 1, rng)
        for x in range(30, width, 150):
            rect(floor, x, 308, x + 23, height - 1, hexc("c8b890"))
            speckle(floor, x, 308, x + 23, height - 1, [hexc("b0a078"), hexc("d8c8a0")], 0.25, rng)
    else:
        sidewalk(floor, 0, 280, width - 1, height - 1, rng)
    for _ in range(puddles):
        puddle(floor, rng.randint(40, width - 40), rng.choice((rng.randint(110, 140), rng.randint(290, 320))),
               rng.randint(8, 16), rng.randint(3, 5), rng.randint(0, 999))
    walls = new(width, height)
    band, lit = facade_band(width, 96, seed + 1, style, home_at)
    walls.alpha_composite(band, (0, 0))
    low_wall(walls, height - 22, height - 1, "hedge" if bottom == "park" else "rail", rng)
    return floor, walls, lit


# ---------------------------------------------------------------- office (walls layer like the home: cap + face)

def city_view(im, x0, y0, x1, y1, rng) -> None:
    """What the office windows show: Bogotá-like hills behind a skyline."""
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0)
        rect(im, x0, y, x1, y, (int(150 + 60 * t), int(196 + 34 * t), int(232 + 10 * t), 255))
    hills = value_noise(rng.randint(0, 999), 22)
    for x in range(x0, x1 + 1):
        top = y0 + int((y1 - y0) * (0.28 + 0.25 * hills(x, 0)))
        rect(im, x, top, x, y1, hexc("5c8a5a"))
        px(im, x, top, hexc("7aa870"))
    bx = x0
    while bx < x1:
        bw, bh = rng.randint(6, 14), rng.randint((y1 - y0) // 4, (y1 - y0) * 2 // 3)
        c = hexc(rng.choice(["8c96a4", "a4acb8", "7a8494", "b4a898"]))
        rect(im, bx, y1 - bh, min(x1, bx + bw), y1, c)
        rect(im, bx, y1 - bh, min(x1, bx + bw), y1 - bh, shade(c, 1.15))
        for wy in range(y1 - bh + 2, y1, 3):
            for wx in range(bx + 1, min(x1, bx + bw) - 1, 2):
                if rng.random() < 0.5:
                    px(im, wx, wy, shade(c, 0.8))
        bx += bw + rng.randint(0, 3)


OFFICE_WALL = {"cap": hexc("d8d6ce"), "cap_hi": hexc("ecebe4"), "paint": hexc("cdd3d8"), "low": hexc("8e9ca8"),
               "rail": hexc("e8ecee"), "base": hexc("4c525c")}
WALL_TOP, WALL_FACE_END = 8, 63


def wall_feature(walls, kind, x, rng, lit) -> None:
    top = WALL_TOP
    if kind == "window":
        rect(walls, x - 3, top + 6, x + 66, top + 46, hexc("e4e8ea"))
        rect(walls, x - 3, top + 6, x + 66, top + 6, hexc("f6f8f8"))
        city_view(walls, x, top + 9, x + 63, top + 43, rng)
        for y in range(top + 9, top + 22, 2):
            rect(walls, x, y, x + 63, y, hexc("eef0f0"))
            rect(walls, x, y + 1, x + 63, y + 1, hexc("c4cacc"))
        rect(walls, x + 31, top + 9, x + 32, top + 43, hexc("e4e8ea"))
        rect(walls, x - 5, top + 46, x + 68, top + 48, hexc("b8c0c6"))
        rect(walls, x - 5, top + 49, x + 68, top + 49, hexc("7c868e"))
        lit.append((x, top + 22, x + 63, top + 43))
    elif kind == "whiteboard":
        rect(walls, x - 2, top + 8, x + 73, top + 44, hexc("8a9098"))
        rect(walls, x, top + 10, x + 71, top + 42, hexc("f6f8f8"))
        for i, h in enumerate((10, 18, 14, 24, 20)):
            c = hexc(("3a6ac8", "d04040", "3a9a50", "e3a040", "8a4ac8")[i])
            rect(walls, x + 8 + i * 9, top + 38 - h, x + 13 + i * 9, top + 38, c)
        rect(walls, x + 6, top + 38, x + 56, top + 38, hexc("2a2a30"))
        rect(walls, x + 6, top + 14, x + 6, top + 38, hexc("2a2a30"))
        for k in range(14):
            px(walls, x + 54 + k // 2, top + 14 + k, hexc("d04040"))
        rect(walls, x + 8, top + 43, x + 63, top + 44, hexc("6a7078"))
        for i, c in enumerate(("3a6ac8", "d04040", "2a2a30")):
            rect(walls, x + 40 + i * 5, top + 43, x + 43 + i * 5, top + 43, hexc(c))
    elif kind == "clock":
        draw = ImageDraw.Draw(walls)
        draw.ellipse([x, top + 8, x + 21, top + 29], fill=hexc("2a2a30"))
        draw.ellipse([x + 2, top + 10, x + 19, top + 27], fill=hexc("f4f2ec"))
        for k in range(12):
            a = k * math.pi / 6
            px(walls, int(x + 10.5 + math.sin(a) * 7), int(top + 18.5 - math.cos(a) * 7), hexc("6a6a70"))
        line(walls, x + 10, top + 18, x + 10, top + 12, hexc("2a2a30"))
        line(walls, x + 10, top + 18, x + 15, top + 20, hexc("2a2a30"))
        px(walls, x + 10, top + 18, hexc("d03a3a"))
    elif kind == "board":
        rect(walls, x - 2, top + 10, x + 51, top + 44, hexc("6f4932"))
        rect(walls, x, top + 12, x + 49, top + 42, hexc("b48a52"))
        speckle(walls, x, top + 12, x + 49, top + 42, [hexc("a47a46"), hexc("c49a62")], 0.2, rng)
        for k in range(6):
            nx, ny = x + 3 + (k % 3) * 16, top + 14 + (k // 3) * 14
            c = hexc(rng.choice(["f4f0a0", "f0f0f0", "a8d8f0", "f8c0c8", "c8f0b0"]))
            rect(walls, nx, ny, nx + 11, ny + 11, c)
            rect(walls, nx + 2, ny + 4, nx + 9, ny + 4, shade(c, 0.7))
            rect(walls, nx + 2, ny + 7, nx + 7, ny + 7, shade(c, 0.7))
            px(walls, nx + 5, ny + 1, hexc("d03a3a"))
    elif kind == "poster":
        rect(walls, x - 2, top + 8, x + 33, top + 44, hexc("2a2a30"))
        for y in range(top + 10, top + 43):
            t = (y - top - 10) / 32
            rect(walls, x, y, x + 31, y, (int(240 - 40 * t), int(160 + 20 * t), int(80 + 60 * t), 255))
        ImageDraw.Draw(walls).ellipse([x + 8, top + 14, x + 23, top + 29], fill=hexc("f8e8a0"))
        rect(walls, x, top + 31, x + 31, top + 42, hexc("3c6aa0"))
        text(walls, x + (32 - text_width("EQUIPO")) // 2, top + 34, "EQUIPO", hexc("f4f0e0"))
    elif kind == "ac":
        rect(walls, x, top + 4, x + 39, top + 15, hexc("f4f4f0"))
        rect(walls, x, top + 15, x + 39, top + 16, hexc("b8bcc0"))
        for k in range(x + 4, x + 36, 2):
            px(walls, k, top + 13, hexc("9aa0a6"))
        px(walls, x + 35, top + 7, hexc("50d060"))
    elif kind == "elevator":
        rect(walls, x - 4, top + 4, x + 43, WALL_FACE_END, hexc("9aa2ac"))
        rect(walls, x, top + 12, x + 39, WALL_FACE_END, hexc("b8c0c8"))
        rect(walls, x + 19, top + 12, x + 20, WALL_FACE_END, hexc("6a727c"))
        for k in range(top + 14, WALL_FACE_END, 4):
            px(walls, x + 6, k, hexc("d8dee4"))
            px(walls, x + 30, k, hexc("d8dee4"))
        rect(walls, x + 14, top + 5, x + 25, top + 10, hexc("1a1a1a"))
        text(walls, x + 16, top + 5, "P", hexc("e04040"))
        rect(walls, x + 44, top + 30, x + 46, top + 34, hexc("d8d8d0"))
        px(walls, x + 45, top + 31, hexc("e0c040"))
    elif kind == "sign":
        label = "ENTREGAS"
        w = text_width(label) + 12
        rect(walls, x - 1, top + 5, x + w, top + 19, PAL["outline"])
        rect(walls, x, top + 6, x + w - 1, top + 18, hexc("2a3440"))
        text(walls, x + 6, top + 10, label, hexc("f0e0a0"))
    elif kind == "turno":
        rect(walls, x - 1, top + 5, x + 49, top + 25, PAL["outline"])
        rect(walls, x, top + 6, x + 48, top + 24, hexc("1a1a1a"))
        text(walls, x + 3, top + 8, "TURNO", hexc("e04040"))
        text(walls, x + 26, top + 8, "A", hexc("f0d060"), size=2)
        text(walls, x + 36, top + 8, "B", hexc("60c0f0"), size=2)


def office_level(width: int, height: int, seed: int, features=(), lobby=None, queue_lines=(), doors=(150, 214)):
    """Office: carpet floor with soft wall shadows; walls layer with a top cap + painted face, side caps with doors."""
    rng = random.Random(seed)
    floor = new(width, height)
    carpet, carpet_b = hexc("6c7a8e"), hexc("66748a")
    for ty in range(0, height, 32):
        for tx in range(0, width, 32):
            horizontal = ((tx // 32) + (ty // 32)) % 2 == 0
            base = carpet if horizontal else carpet_b
            rect(floor, tx, ty, tx + 31, ty + 31, base)
            for y in range(ty, ty + 32):
                for x in range(tx, tx + 32):
                    if ((y if horizontal else x) % 3) == 0:
                        px(floor, x, y, shade(base, 1.06))
                    elif ((y if horizontal else x) % 3) == 2 and rng.random() < 0.3:
                        px(floor, x, y, shade(base, 0.96))
            rect(floor, tx, ty, tx + 31, ty, shade(base, 0.9))
            rect(floor, tx, ty, tx, ty + 31, shade(base, 0.92))
    wear = fbm(seed, 60)
    for y in range(height):
        for x in range(width):
            if wear(x, y) > 0.64 and BAYER[y % 4][x % 4] < 6:
                darken(floor, x, y, 0.06)
    if lobby:
        lx0, lx1 = lobby
        veins = fbm(seed + 5, 10)
        for ty in range(0, height, 48):
            for tx in range(lx0, lx1, 48):
                c = hexc("d8d0c0") if ((tx - lx0) // 48 + ty // 48) % 2 == 0 else hexc("c8bfae")
                rect(floor, tx, ty, min(lx1, tx + 47), ty + 47, c)
                for y in range(ty, ty + 48):
                    for x in range(tx, min(lx1, tx + 48)):
                        if abs(veins(x, y) - 0.5) < 0.012:
                            px(floor, x, y, shade(c, 0.86))
                rect(floor, tx, ty, min(lx1, tx + 47), ty, shade(c, 1.06))
                rect(floor, tx, ty, tx, ty + 47, shade(c, 1.04))
                rect(floor, tx, ty + 47, min(lx1, tx + 47), ty + 47, shade(c, 0.84))
                for k in range(10):
                    px(floor, tx + 6 + k, ty + 4 + k // 2, shade(c, 1.1))
        rect(floor, lx1, 0, lx1 + 2, height - 1, hexc("9a9890"))
        rect(floor, lx1 + 1, 0, lx1 + 1, height - 1, hexc("c4c2b8"))
        my = (doors[0] + doors[1]) // 2
        rect(floor, 8, my - 24, 40, my + 24, hexc("5a3a34"))
        rect(floor, 10, my - 22, 38, my + 22, hexc("7a4a3e"))
        for y in range(my - 20, my + 21, 3):
            rect(floor, 12, y, 36, y, hexc("6a4036"))
    for (x0, x1, y) in queue_lines:
        for x in range(x0, x1):
            c = hexc("e2bf48") if (x // 6) % 2 == 0 else hexc("2a2a2e")
            rect(floor, x, y, x, y + 2, c)
        for ax in range(x0 + 12, x1 - 8, 40):
            for k in range(5):
                rect(floor, ax + k, y - 8 + k, ax + k, y - 8 + 9 - k, hexc("e4e2d8"))
    shadow_band(floor, 0, WALL_FACE_END + 1, width - 1, WALL_FACE_END + 12, "top", 0.42)
    shadow_band(floor, 8, 0, 18, height - 1, "left", 0.35)
    shadow_band(floor, width - 19, 0, width - 9, height - 1, "right", 0.3)

    walls = new(width, height)
    W = OFFICE_WALL
    rect(walls, 0, WALL_TOP, width - 1, WALL_FACE_END, W["paint"])
    mottle(walls, 0, WALL_TOP, width - 1, 40, W["paint"], shade(W["paint"], 1.03), shade(W["paint"], 0.97), seed, cell=30)
    rect(walls, 0, 41, width - 1, WALL_FACE_END - 4, W["low"])
    for x in range(0, width, 8):
        rect(walls, x, 42, x, WALL_FACE_END - 4, shade(W["low"], 0.9))
    rect(walls, 0, 40, width - 1, 41, W["rail"])
    rect(walls, 0, 42, width - 1, 42, shade(W["low"], 0.75))
    rect(walls, 0, WALL_FACE_END - 3, width - 1, WALL_FACE_END, W["base"])
    rect(walls, 0, WALL_FACE_END - 3, width - 1, WALL_FACE_END - 3, shade(W["base"], 1.3))
    lit: list = []
    for kind, x in features:
        wall_feature(walls, kind, x, rng, lit)
    shadow_band(walls, 0, WALL_TOP, width - 1, WALL_TOP + 5, "top", 0.4)

    def cap(x0, y0, x1, y1):
        if y1 < y0:
            return
        rect(walls, x0, y0, x1, y1, W["cap"])
        rect(walls, x0 + 1, y0 + 1, x1 - 1, y0 + 1, W["cap_hi"])
        ImageDraw.Draw(walls).rectangle([x0, y0, x1, y1], outline=PAL["brown_line"])

    cap(0, 0, width - 1, WALL_TOP - 1)
    for side in (0, width - 8):
        cap(side, 0, side + 7, doors[0] - 1)
        cap(side, doors[1] + 1, side + 7, height - 1)
        rect(walls, side, doors[0] - 2, side + 7, doors[0] - 1, hexc("6a727e"))
        rect(walls, side, doors[1] + 1, side + 7, doors[1] + 2, hexc("6a727e"))
    cap(0, height - 8, width - 1, height - 1)
    rect(walls, 1, WALL_TOP, 6, WALL_FACE_END, W["cap"])
    rect(walls, width - 7, WALL_TOP, width - 2, WALL_FACE_END, W["cap"])
    return floor, walls, lit


# ---------------------------------------------------------------- objects of the world (single sprites)

def box(im, x0, y0, x1, y1, top_h, color, top=None) -> None:
    """3/4 box: lighter top face [top_h] px tall, front face with a dark base line and a lit left edge."""
    top = top or shade(color, 1.18)
    rect(im, x0, y0, x1, y0 + top_h - 1, top)
    rect(im, x0, y0, x1, y0, shade(top, 1.08))
    rect(im, x0, y0 + top_h, x1, y1, color)
    rect(im, x0, y0 + top_h, x1, y0 + top_h, shade(color, 0.82))
    rect(im, x0, y0 + top_h, x0, y1, shade(color, 1.08))
    rect(im, x1, y0 + top_h, x1, y1, shade(color, 0.86))
    rect(im, x0, y1, x1, y1, shade(color, 0.7))


def foliage(im, cx, cy, rx, ry, seed, base=None) -> None:
    base = base or PAL["leaf"]
    rng = random.Random(seed)
    clusters = [(cx + rng.randint(-rx // 2, rx // 2), cy + rng.randint(-ry // 2, ry // 2), rng.randint(rx // 3, rx // 2 + 2))
                for _ in range(9)]
    mask = new(im.width, im.height)
    for (x, y, r) in clusters:
        ImageDraw.Draw(mask).ellipse([x - r, y - r * 0.85, x + r, y + r * 0.85], fill=(255, 255, 255, 255))
    data, m = im.load(), mask.load()
    noise = value_noise(seed, 3)
    for y in range(im.height):
        for x in range(im.width):
            if m[x, y][3]:
                light = (cx - x) * 0.6 + (cy - y) + (noise(x, y) - 0.5) * 10
                if light > ry * 0.35:
                    c = shade(base, 1.3)
                elif light > -ry * 0.1:
                    c = base
                else:
                    c = shade(base, 0.72)
                data[x, y] = c
    for _ in range(rx * 2):
        x, y = rng.randint(cx - rx, cx + rx), rng.randint(cy - ry, cy + ry)
        if 0 <= x < im.width and 0 <= y < im.height and m[x, y][3]:
            px(im, x, y, shade(base, 1.45))


def with_shadow(sprite: Image.Image, w: int, pad: int = 3) -> Image.Image:
    out = new(sprite.width, sprite.height + pad)
    cx = sprite.width // 2
    ImageDraw.Draw(out).ellipse([cx - w // 2, sprite.height - 4, cx + w // 2, sprite.height + pad - 1], fill=(0, 0, 0, 60))
    out.alpha_composite(sprite)
    return out


def obj_tree() -> Image.Image:
    im = new(64, 84)
    rect(im, 28, 46, 34, 80, hexc("6b4a2b"))
    rect(im, 28, 46, 29, 80, hexc("8a6440"))
    rect(im, 33, 46, 34, 80, hexc("4a321c"))
    for y in range(50, 80, 5):
        px(im, 31, y, hexc("4a321c"))
    line(im, 31, 56, 22, 44, hexc("6b4a2b"))
    line(im, 32, 52, 42, 42, hexc("6b4a2b"))
    foliage(im, 32, 28, 28, 24, 11)
    return with_shadow(outline(im), 34)


def obj_lamppost() -> Image.Image:
    im = new(28, 84)
    rect(im, 11, 14, 14, 76, PAL["metal"])
    rect(im, 11, 14, 11, 76, PAL["metal_hi"])
    rect(im, 14, 14, 14, 76, PAL["metal_lo"])
    rect(im, 8, 74, 17, 80, PAL["metal_lo"])
    rect(im, 8, 74, 17, 74, PAL["metal_hi"])
    for k in range(10):
        px(im, 13 + k, 14 - int(5 * math.sin(k / 9 * math.pi / 2)), PAL["metal"])
        px(im, 13 + k, 15 - int(5 * math.sin(k / 9 * math.pi / 2)), PAL["metal_lo"])
    rect(im, 18, 8, 27, 11, PAL["metal_lo"])
    rect(im, 19, 12, 26, 13, hexc("f8e8a8"))
    rect(im, 20, 12, 25, 12, hexc("ffffff"))
    rect(im, 11, 40, 14, 46, hexc("3c6aa0"))
    return with_shadow(outline(im), 14)


def obj_bus_stop() -> Image.Image:
    im = new(104, 80)
    rect(im, 4, 2, 99, 13, hexc("3c6aa0"))
    rect(im, 4, 2, 99, 8, hexc("5a8ac0"))
    rect(im, 4, 2, 99, 2, hexc("7aa8d8"))
    rect(im, 6, 14, 97, 15, hexc("2a4a70"))
    w = text_width("PARADERO") + 8
    rect(im, 52 - w // 2, 4, 52 + w // 2, 11, hexc("f4f0e8"))
    text(im, 52 - w // 2 + 4, 5, "PARADERO", hexc("2a4a70"))
    for x in (8, 95):
        rect(im, x, 16, x + 2, 74, PAL["metal"])
        px(im, x, 16, PAL["metal_hi"])
        rect(im, x + 2, 16, x + 2, 74, PAL["metal_lo"])
    glass = hexc("a8c8dc", 140)
    rect(im, 11, 18, 94, 50, glass)
    for i in range(26):
        px(im, 64 + i, 20 + i, hexc("eaf6fc", 210))
        px(im, 60 + i, 20 + i, hexc("dceef8", 170))
    rect(im, 14, 20, 37, 48, hexc("f4f0e8"))
    for y in range(22, 36):
        t = (y - 22) / 14
        rect(im, 15, y, 36, y, (int(240 - 30 * t), int(140 + 40 * t), int(80 + 40 * t), 255))
    text(im, 17, 38, "BUS", hexc("3c6aa0"))
    for i, c in enumerate(("d04040", "3a9a50", "e3b55a")):
        rect(im, 30, 38 + i * 3, 35, 39 + i * 3, hexc(c))
    box(im, 18, 54, 85, 60, 2, PAL["wood"], PAL["wood_hi"])
    for x in range(18, 86, 6):
        px(im, x, 55, PAL["wood_lo"])
    for x in (22, 80):
        rect(im, x, 61, x + 1, 70, PAL["metal_lo"])
    return with_shadow(outline(im), 96)


def obj_bench() -> Image.Image:
    im = new(52, 32)
    box(im, 2, 2, 49, 8, 2, PAL["wood"], PAL["wood_hi"])
    box(im, 2, 12, 49, 18, 3, PAL["wood"], PAL["wood_hi"])
    for x in range(2, 50, 8):
        px(im, x, 13, PAL["wood_lo"])
    for x in (6, 43):
        rect(im, x, 9, x + 2, 27, PAL["metal_lo"])
        rect(im, x, 9, x, 27, PAL["metal"])
    return with_shadow(outline(im), 46)


def obj_trash_can() -> Image.Image:
    im = new(18, 30)
    rect(im, 3, 7, 14, 26, hexc("3c8a4c"))
    rect(im, 3, 7, 4, 26, hexc("50a860"))
    rect(im, 13, 7, 14, 26, hexc("2c6a38"))
    box(im, 2, 3, 15, 7, 2, hexc("e88a30"))
    for y in range(10, 24, 4):
        rect(im, 5, y, 12, y, hexc("2c6a38"))
    rect(im, 6, 4, 11, 4, hexc("1e1e1e"))
    return with_shadow(outline(im), 14)


def obj_hydrant() -> Image.Image:
    im = new(14, 22)
    rect(im, 4, 6, 9, 18, hexc("e0c040"))
    rect(im, 4, 6, 4, 18, hexc("f0d860"))
    rect(im, 9, 6, 9, 18, hexc("b09020"))
    rect(im, 3, 4, 10, 6, hexc("d03a3a"))
    rect(im, 5, 2, 8, 3, hexc("d03a3a"))
    rect(im, 1, 10, 12, 12, hexc("d03a3a"))
    rect(im, 3, 18, 10, 19, hexc("b09020"))
    return with_shadow(outline(im), 12)


def obj_planter() -> Image.Image:
    im = new(44, 34)
    foliage(im, 22, 12, 18, 9, 21, PAL["leaf"])
    for x in range(8, 38, 7):
        px(im, x, 8 + (x % 3), hexc("e04860"))
        px(im, x + 1, 7 + (x % 3), hexc("f08aa8"))
    box(im, 4, 16, 39, 29, 4, hexc("a8a498"), hexc("c8c4b8"))
    rect(im, 6, 17, 37, 18, PAL["soil"])
    return with_shadow(outline(im), 40)


def obj_bollard() -> Image.Image:
    im = new(10, 20)
    rect(im, 2, 3, 7, 16, hexc("4a525c"))
    rect(im, 2, 3, 2, 16, hexc("6a727e"))
    rect(im, 2, 6, 7, 7, hexc("e2bf48"))
    ImageDraw.Draw(im).ellipse([2, 1, 7, 5], fill=hexc("5a626c"))
    return with_shadow(outline(im), 8, 2)


def obj_stop_sign() -> Image.Image:
    im = new(22, 56)
    rect(im, 10, 18, 11, 52, PAL["metal"])
    rect(im, 11, 18, 11, 52, PAL["metal_lo"])
    oct_pts = [(6, 1), (15, 1), (20, 6), (20, 15), (15, 20), (6, 20), (1, 15), (1, 6)]
    ImageDraw.Draw(im).polygon(oct_pts, fill=hexc("d03a3a"))
    ImageDraw.Draw(im).polygon([(6, 2), (15, 2), (19, 6), (19, 15), (15, 19), (6, 19), (2, 15), (2, 6)], outline=hexc("f4f0e8"))
    text(im, 3, 8, "PARE", hexc("f4f0e8"))
    return with_shadow(outline(im), 10, 2)


def obj_kiosk() -> Image.Image:
    """Candy and newspaper stand (dulces y minutos)."""
    im = new(56, 60)
    for i, x in enumerate(range(2, 54, 6)):
        c = hexc(("3c8a4c", "f0d060")[i % 2])
        rect(im, x, 2, x + 5, 10, c)
        rect(im, x, 2, x + 5, 3, shade(c, 0.85))
        rect(im, x + 1, 11, x + 4, 12, c)
    rect(im, 2, 1, 53, 1, PAL["outline"])
    rect(im, 5, 13, 6, 32, PAL["metal"])
    rect(im, 49, 13, 50, 32, PAL["metal"])
    box(im, 3, 30, 52, 54, 6, hexc("3c6aa0"), hexc("e8e4d8"))
    rng = random.Random(5)
    for x in range(5, 51, 3):
        c = rng.choice([hexc("d03a3a"), hexc("f0d060"), hexc("4ab050"), hexc("f08aa8"), hexc("f4f0e8")])
        rect(im, x, 31, x + 1, 34, c)
    rect(im, 8, 20, 47, 28, hexc("f4f0e8"))
    for y in range(22, 28, 2):
        rect(im, 10, y, 45, y, hexc("9a9a96"))
    text(im, 11, 42, "DULCES", hexc("f4f0e0"))
    return with_shadow(outline(im), 52)


def obj_cart(kind: str) -> Image.Image:
    """Street stands for the tinto vendor (NPC-01) and the empanada vendor (NPC-05)."""
    im = new(60, 56)
    awning = ("b03a3a", "f4f0e8") if kind == "coffee" else ("e3b55a", "c83c3c")
    for i, x in enumerate(range(2, 58, 6)):
        c = hexc(awning[i % 2])
        rect(im, x, 2, x + 5, 10, c)
        rect(im, x, 2, x + 5, 3, shade(c, 0.85))
        rect(im, x + 1, 11, x + 4, 12, c)
    rect(im, 2, 1, 57, 1, PAL["outline"])
    for x in (5, 53):
        rect(im, x, 13, x + 1, 30, PAL["metal"])
    box(im, 3, 28, 56, 46, 4, PAL["wood"], hexc("e8e4d8"))
    if kind == "coffee":
        rect(im, 9, 18, 18, 28, hexc("c8c8c4"))
        rect(im, 9, 18, 10, 28, hexc("e4e4e0"))
        rect(im, 11, 16, 16, 17, hexc("5a5a62"))
        rect(im, 22, 20, 29, 28, hexc("b03a3a"))
        rect(im, 22, 20, 23, 28, hexc("d04a4a"))
        for x in (34, 39, 44):
            rect(im, x, 24, x + 3, 28, hexc("f4f0e8"))
            rect(im, x, 24, x + 3, 24, hexc("6a3a20"))
        for k in range(6):
            px(im, 13 + (k % 2), 14 - k, hexc("f4f0e8", 170))
        text(im, 20, 36, "TINTO", hexc("f4f0e0"))
    else:
        rect(im, 8, 16, 51, 28, hexc("bcd8e4", 150))
        rect(im, 8, 16, 51, 16, hexc("e8f4f8"))
        for x in range(11, 47, 7):
            ImageDraw.Draw(im).pieslice([x, 21, x + 8, 31], 180, 360, fill=hexc("e3a040"))
            px(im, x + 3, 23, hexc("f0c870"))
        text(im, 13, 36, "EMPANADAS"[:8], hexc("f4f0e0"))
    for cx in (10, 44):
        ImageDraw.Draw(im).ellipse([cx, 45, cx + 9, 54], fill=hexc("2a2a30"))
        ImageDraw.Draw(im).ellipse([cx + 3, 48, cx + 6, 51], fill=hexc("8a929c"))
    return with_shadow(outline(im), 54)


# office objects

def obj_office_desk() -> Image.Image:
    im = new(68, 48)
    box(im, 2, 16, 65, 38, 13, hexc("8a6440"), hexc("c49a68"))
    for x in range(4, 64, 9):
        px(im, x, 20, hexc("b48a58"))
    rect(im, 44, 30, 63, 37, hexc("9a7048"))
    rect(im, 46, 33, 61, 33, hexc("6b4a2b"))
    px(im, 53, 31, hexc("e3c060"))
    rect(im, 4, 39, 7, 45, hexc("4a321c"))
    rect(im, 60, 39, 63, 45, hexc("4a321c"))
    rect(im, 21, 1, 46, 16, hexc("2a2a30"))
    rect(im, 23, 3, 44, 14, hexc("3c78b0"))
    for y in range(5, 13, 2):
        rect(im, 25, y, 25 + (y * 7) % 14 + 4, y, hexc("a8d8f0"))
    rect(im, 39, 4, 43, 7, hexc("f0d060"))
    rect(im, 31, 17, 36, 19, hexc("3a3a40"))
    rect(im, 19, 22, 44, 25, hexc("e8e8e4"))
    for x in range(20, 44, 2):
        px(im, x, 23, hexc("a4a4a0"))
        px(im, x + 1, 24, hexc("b8b8b4"))
    rect(im, 47, 22, 50, 25, hexc("e8e8e4"))
    rect(im, 5, 18, 15, 26, hexc("f4f0e0"))
    rect(im, 7, 17, 17, 25, hexc("fbf8ee"))
    for y in range(19, 24, 2):
        rect(im, 9, y, 15, y, hexc("a4a4a0"))
    rect(im, 55, 19, 59, 24, hexc("d04040"))
    rect(im, 59, 20, 60, 22, hexc("d04040"))
    rect(im, 56, 19, 58, 19, hexc("6a3a20"))
    return with_shadow(outline(im), 64)


def obj_office_chair() -> Image.Image:
    im = new(24, 34)
    rect(im, 5, 2, 18, 15, hexc("2f3340"))
    rect(im, 6, 3, 17, 4, hexc("4a5262"))
    rect(im, 6, 5, 6, 14, hexc("3c4250"))
    box(im, 3, 15, 20, 21, 3, hexc("2f3340"), hexc("4a5262"))
    rect(im, 11, 22, 12, 27, PAL["metal"])
    rect(im, 4, 27, 19, 28, PAL["metal"])
    for x in (4, 11, 19):
        rect(im, x, 29, x + 1, 30, hexc("1a1a1a"))
    return with_shadow(outline(im), 20, 2)


def obj_cubicle(width: int = 72) -> Image.Image:
    im = new(width, 36)
    box(im, 1, 2, width - 2, 30, 3, hexc("7c8ca0"), hexc("c8ccd0"))
    noise = value_noise(3, 2)
    for y in range(6, 30):
        for x in range(2, width - 2):
            if noise(x, y) > 0.6:
                px(im, x, y, hexc("74849a"))
    for x in range(1, width - 1, 24):
        rect(im, x, 2, x + 1, 30, hexc("a8b0b8"))
    rect(im, 8, 10, 15, 18, hexc("f4f0a0"))
    rect(im, 20, 12, 27, 20, hexc("a8d8f0"))
    px(im, 11, 11, hexc("d03a3a"))
    px(im, 23, 13, hexc("d03a3a"))
    return outline(im)


def obj_printer() -> Image.Image:
    im = new(40, 44)
    box(im, 3, 4, 36, 38, 8, hexc("c8c8c4"), hexc("e0e0dc"))
    rect(im, 5, 5, 34, 9, hexc("5a5a62"))
    rect(im, 7, 6, 14, 8, hexc("6ab0e0"))
    for i, c in enumerate(("50d060", "e3b55a", "d04040")):
        px(im, 28 + i * 2, 7, hexc(c))
    rect(im, 8, 18, 31, 18, hexc("3a3a40"))
    rect(im, 10, 19, 29, 24, hexc("f6f4ec"))
    rect(im, 11, 20, 28, 20, hexc("b0b0b0"))
    for y in (28, 33):
        rect(im, 6, y, 33, y + 3, hexc("b4b4b0"))
        rect(im, 17, y + 1, 22, y + 1, hexc("6a6a70"))
    rect(im, 5, 39, 8, 41, hexc("4a4a50"))
    rect(im, 31, 39, 34, 41, hexc("4a4a50"))
    return with_shadow(outline(im), 36, 2)


def obj_coffee_station() -> Image.Image:
    im = new(52, 48)
    box(im, 2, 18, 49, 44, 6, hexc("8a6440"), hexc("d8d4c8"))
    rect(im, 4, 30, 24, 42, hexc("7a5638"))
    rect(im, 27, 30, 47, 42, hexc("7a5638"))
    px(im, 22, 36, hexc("e3c060"))
    px(im, 29, 36, hexc("e3c060"))
    rect(im, 8, 2, 23, 20, hexc("3a3a40"))
    rect(im, 8, 2, 9, 20, hexc("5a5a62"))
    rect(im, 10, 4, 17, 8, hexc("6ab0e0"))
    rect(im, 19, 4, 21, 5, hexc("d04040"))
    rect(im, 19, 7, 21, 8, hexc("50d060"))
    rect(im, 12, 12, 19, 18, hexc("1a1a1a"))
    rect(im, 14, 15, 17, 19, hexc("f4f0e8"))
    for x in (28, 34, 40):
        rect(im, x, 15, x + 3, 20, hexc("f4f0e8"))
        rect(im, x + 4, 16, x + 4, 18, hexc("f4f0e8"))
    rect(im, 28, 9, 35, 14, hexc("b03a3a"))
    text(im, 29, 10, "C", hexc("f4f0e0"))
    return with_shadow(outline(im), 48, 2)


def obj_water_cooler() -> Image.Image:
    im = new(20, 46)
    rect(im, 5, 2, 14, 15, hexc("8cc8f0", 220))
    rect(im, 6, 3, 8, 13, hexc("c8e8fc", 235))
    rect(im, 7, 1, 12, 2, hexc("3c78b0"))
    box(im, 4, 16, 15, 41, 2, hexc("e8e8e4"))
    rect(im, 6, 21, 8, 23, hexc("3a6ac8"))
    rect(im, 11, 21, 13, 23, hexc("d04040"))
    rect(im, 6, 29, 13, 30, hexc("9a9a96"))
    return with_shadow(outline(im), 16, 2)


def obj_plant_big() -> Image.Image:
    im = new(36, 64)
    foliage(im, 18, 22, 15, 20, 31)
    for k in range(4):
        line(im, 18, 46, 10 + k * 5, 30, hexc("4a6a30"))
    box(im, 9, 44, 26, 60, 3, hexc("e8e4d8"), hexc("f4f0e8"))
    rect(im, 10, 45, 25, 46, PAL["soil"])
    return with_shadow(outline(im), 22, 2)


def obj_plant() -> Image.Image:
    im = new(24, 40)
    foliage(im, 12, 13, 10, 11, 41)
    box(im, 6, 25, 17, 37, 3, hexc("b0543a"), hexc("c8664a"))
    rect(im, 7, 26, 16, 27, PAL["soil"])
    return with_shadow(outline(im), 14, 2)


def obj_filing_cabinet() -> Image.Image:
    im = new(26, 48)
    box(im, 3, 2, 22, 44, 4, hexc("8a929c"), hexc("aab2bc"))
    for y in (8, 20, 32):
        rect(im, 5, y, 20, y + 10, hexc("9aa2ac"))
        rect(im, 5, y, 20, y, hexc("b4bcc4"))
        rect(im, 5, y + 10, 20, y + 10, hexc("6a727e"))
        rect(im, 10, y + 4, 15, y + 5, hexc("4a505a"))
        rect(im, 9, y + 7, 16, y + 8, hexc("f4f0e8"))
    return with_shadow(outline(im), 22, 2)


def obj_bookshelf() -> Image.Image:
    im = new(52, 60)
    box(im, 2, 2, 49, 56, 4, PAL["wood"], PAL["wood_hi"])
    rng = random.Random(9)
    for shelf in (8, 24, 40):
        rect(im, 4, shelf, 47, shelf + 13, hexc("4a321c"))
        x = 5
        while x < 46:
            c = hexc(rng.choice(["d04040", "3c6aa0", "3a9a50", "e3b55a", "8a4ac8", "f4f0e8", "2a2a30"]))
            h = rng.randint(9, 13)
            rect(im, x, shelf + 13 - h, x + 2, shelf + 13, c)
            px(im, x, shelf + 13 - h, shade(c, 1.25))
            rect(im, x + 1, shelf + 9, x + 1, shelf + 10, shade(c, 1.4))
            x += 4
        rect(im, 4, shelf + 14, 47, shelf + 15, PAL["wood_hi"])
    return with_shadow(outline(im), 48, 2)


def obj_reception_desk() -> Image.Image:
    im = new(112, 52)
    box(im, 2, 10, 109, 46, 8, hexc("5a7088"), hexc("e4e0d4"))
    rect(im, 2, 24, 109, 26, hexc("c8a84a"))
    w = text_width("RECEPCION") + 10
    rect(im, 56 - w // 2, 30, 56 + w // 2, 40, hexc("2a3440"))
    text(im, 56 - w // 2 + 5, 33, "RECEPCION", hexc("f0e0a0"))
    rect(im, 70, 0, 89, 11, hexc("2a2a30"))
    rect(im, 72, 2, 87, 9, hexc("3c78b0"))
    rect(im, 14, 8, 25, 11, hexc("f4f0e8"))
    rect(im, 32, 7, 37, 11, hexc("4c8a3c"))
    rect(im, 33, 4, 36, 6, hexc("6aac50"))
    return with_shadow(outline(im), 108, 2)


def obj_sofa() -> Image.Image:
    im = new(68, 36)
    box(im, 4, 2, 63, 16, 4, hexc("8a3a34"), hexc("a84a42"))
    box(im, 2, 14, 65, 28, 5, hexc("7a322e"), hexc("a84a42"))
    for x in (22, 44):
        rect(im, x, 16, x, 27, hexc("5a2420"))
    box(im, 0, 10, 6, 30, 3, hexc("6a2a26"))
    box(im, 61, 10, 67, 30, 3, hexc("6a2a26"))
    rect(im, 5, 30, 7, 33, hexc("2a2a30"))
    rect(im, 60, 30, 62, 33, hexc("2a2a30"))
    return with_shadow(outline(im), 62, 2)


def obj_counter(letter: str) -> Image.Image:
    """Ventanilla A / B for the M/M/1 windows of Trabajo 3."""
    im = new(68, 60)
    rect(im, 26, 0, 41, 14, PAL["outline"])
    rect(im, 27, 1, 40, 13, hexc("1a1a1a"))
    color = hexc("f0d060") if letter == "A" else hexc("60c0f0")
    text(im, 31, 3, letter, color, size=2)
    rect(im, 2, 15, 65, 17, PAL["metal_lo"])
    rect(im, 3, 18, 64, 40, hexc("bcd8e4", 150))
    for i in range(20):
        px(im, 44 + i, 19 + i, hexc("f0f8fc", 220))
        px(im, 41 + i, 19 + i, hexc("e0f0f8", 170))
    rect(im, 3, 18, 3, 40, PAL["metal"])
    rect(im, 64, 18, 64, 40, PAL["metal"])
    rect(im, 22, 34, 45, 40, hexc("3a4050"))
    box(im, 1, 40, 66, 56, 5, hexc("5a7088"), hexc("e4e0d4"))
    rect(im, 8, 48, 20, 53, hexc("f4f0e0"))
    rect(im, 9, 49, 19, 49, hexc("a4a4a0"))
    return with_shadow(outline(im), 62, 2)


def obj_stanchion() -> Image.Image:
    im = new(52, 30)
    for x in (4, 44):
        rect(im, x + 1, 4, x + 2, 24, hexc("c8a84a"))
        rect(im, x + 1, 4, x + 1, 24, hexc("e8c86a"))
        ImageDraw.Draw(im).ellipse([x, 1, x + 3, 4], fill=hexc("e8c86a"))
        rect(im, x - 2, 24, x + 5, 26, hexc("8a7030"))
    for x in range(7, 45):
        sag = int(3 * math.sin((x - 7) / 38 * math.pi))
        rect(im, x, 7 + sag, x, 8 + sag, hexc("b03a3a"))
        px(im, x, 7 + sag, hexc("d04a4a"))
    return with_shadow(outline(im), 48, 2)


def obj_delivery_tray() -> Image.Image:
    """Punto de entrega de las carpetas (Trabajo 3)."""
    im = new(52, 48)
    box(im, 2, 18, 49, 44, 6, hexc("5a7088"), hexc("d8d4c8"))
    for i, y in enumerate((8, 12, 16)):
        rect(im, 10, y, 41, y + 2, hexc("8a929c"))
        rect(im, 12, y - 2, 39, y, hexc("f0d090") if i % 2 else hexc("f4f0e8"))
    rect(im, 10, 8, 10, 18, hexc("6a727e"))
    rect(im, 41, 8, 41, 18, hexc("6a727e"))
    w = text_width("ENTREGAS") + 6
    rect(im, 26 - w // 2, 30, 26 + w // 2, 38, hexc("2a3440"))
    text(im, 26 - w // 2 + 3, 32, "ENTREGAS", hexc("f0e0a0"))
    return with_shadow(outline(im), 48, 2)


def obj_boxes() -> Image.Image:
    im = new(36, 36)
    box(im, 2, 14, 33, 32, 5, hexc("b4864e"), hexc("caa068"))
    box(im, 6, 2, 27, 15, 4, hexc("a87a44"), hexc("c49a62"))
    rect(im, 16, 2, 17, 5, hexc("e8d8b0"))
    rect(im, 17, 14, 18, 18, hexc("e8d8b0"))
    rect(im, 9, 21, 20, 25, hexc("f4f0e8"))
    rect(im, 10, 23, 19, 23, hexc("9a9a96"))
    return with_shadow(outline(im), 32, 2)


def obj_office_trash() -> Image.Image:
    im = new(14, 18)
    rect(im, 3, 5, 10, 15, hexc("5a626c"))
    rect(im, 3, 5, 3, 15, hexc("7a828c"))
    rect(im, 2, 3, 11, 5, hexc("4a525c"))
    px(im, 6, 2, hexc("f4f0e8"))
    px(im, 7, 3, hexc("f4f0e8"))
    return with_shadow(outline(im), 10, 2)


def obj_extinguisher() -> Image.Image:
    im = new(12, 24)
    rect(im, 3, 6, 8, 20, hexc("d03a3a"))
    rect(im, 3, 6, 3, 20, hexc("e86a5a"))
    rect(im, 4, 3, 7, 5, hexc("2a2a30"))
    rect(im, 8, 3, 10, 4, hexc("2a2a30"))
    rect(im, 4, 11, 7, 13, hexc("f4f0e8"))
    return with_shadow(outline(im), 8, 2)


STREET_OBJECTS = {
    "obj_tree": obj_tree, "obj_lamppost": obj_lamppost, "obj_bus_stop": obj_bus_stop, "obj_bench": obj_bench,
    "obj_trash_can": obj_trash_can, "obj_hydrant": obj_hydrant, "obj_planter": obj_planter, "obj_bollard": obj_bollard,
    "obj_stop_sign": obj_stop_sign, "obj_kiosk": obj_kiosk,
    "obj_coffee_cart": lambda: obj_cart("coffee"), "obj_empanada_stand": lambda: obj_cart("empanada"),
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

# Backwards names used by the endings.
prop_lamppost = obj_lamppost
prop_office_desk = obj_office_desk

# Level recipes: background parameters and a suggested placement of the objects (x, y = top-left).
# The placements are only used for the preview; the levels place the objects as World/Entities props.
STREET_LEVELS = {
    "commute_01": dict(size=(1920, 360), seed=11, light=None,
                       street=dict(crossings=(640, 1300), pits=(90, 410, 860, 1180, 1560)),
                       objects=[("obj_tree", 70, 52), ("obj_tree", 390, 52), ("obj_tree", 840, 52), ("obj_tree", 1160, 52),
                                ("obj_tree", 1540, 52), ("obj_lamppost", 250, 62), ("obj_lamppost", 1000, 62),
                                ("obj_lamppost", 1700, 62), ("obj_coffee_cart", 470, 92), ("obj_trash_can", 560, 116),
                                ("obj_hydrant", 720, 128), ("obj_bench", 1400, 112), ("obj_stop_sign", 610, 92),
                                ("obj_kiosk", 1750, 86), ("obj_planter", 200, 300), ("obj_planter", 1100, 300),
                                ("obj_bollard", 630, 286), ("obj_bollard", 660, 286), ("obj_trash_can", 1500, 292)]),
    "commute_03": dict(size=(640, 360), seed=13, light=None,
                       street=dict(style="towers", crossings=(300,), tactile=True, bike_lane=True),
                       objects=[("obj_planter", 40, 104), ("obj_planter", 200, 104), ("obj_lamppost", 130, 62),
                                ("obj_lamppost", 420, 62), ("obj_bollard", 500, 128), ("obj_bollard", 520, 128),
                                ("obj_bench", 260, 300), ("obj_tree", 560, 240), ("obj_trash_can", 360, 116)]),
    "return_01": dict(size=(640, 360), seed=21, light="dusk",
                      street=dict(crossings=(420,), bus_lane=(60,), painted=((120, 230),)),
                      objects=[("obj_bus_stop", 130, 64), ("obj_empanada_stand", 450, 90), ("obj_lamppost", 320, 62),
                               ("obj_lamppost", 590, 62), ("obj_trash_can", 260, 116), ("obj_tree", 20, 230),
                               ("obj_bench", 520, 300)]),
    "return_02": dict(size=(640, 360), seed=22, light="evening",
                      street=dict(crossings=(200,), bottom="park", puddles=5),
                      objects=[("obj_lamppost", 100, 62), ("obj_lamppost", 320, 62), ("obj_lamppost", 540, 62),
                               ("obj_tree", 60, 262), ("obj_tree", 300, 262), ("obj_tree", 520, 262),
                               ("obj_bench", 400, 300), ("obj_trash_can", 240, 116)]),
    "return_03": dict(size=(640, 360), seed=23, light="night",
                      street=dict(pits=(150, 450), home_at=True),
                      objects=[("obj_lamppost", 100, 62), ("obj_lamppost", 320, 62), ("obj_lamppost", 540, 62),
                               ("obj_tree", 130, 52), ("obj_tree", 430, 52), ("obj_trash_can", 280, 116),
                               ("obj_planter", 560, 300)]),
}
LAMPS = {"return_01": (), "return_02": ((112, 128, 90), (332, 128, 90), (552, 128, 90)),
         "return_03": ((112, 128, 90), (332, 128, 90), (552, 128, 90))}
LIGHTS = {"dusk": DUSK, "evening": EVENING, "night": NIGHT}

OFFICE_LEVELS = {
    "work_01": dict(size=(800, 600), seed=31,
                    office=dict(lobby=(8, 248), features=(("elevator", 40), ("elevator", 140), ("poster", 210),
                                                          ("window", 290), ("board", 390), ("clock", 470), ("ac", 520),
                                                          ("whiteboard", 580), ("window", 680))),
                    objects=[("obj_reception_desk", 70, 250), ("obj_sofa", 40, 420), ("obj_sofa", 140, 420),
                             ("obj_plant_big", 20, 60), ("obj_plant_big", 210, 60), ("obj_office_desk", 300, 120),
                             ("obj_office_desk", 400, 120), ("obj_office_desk", 600, 120), ("obj_office_chair", 320, 170),
                             ("obj_office_chair", 420, 170), ("obj_office_chair", 620, 170), ("obj_cubicle", 300, 340),
                             ("obj_cubicle", 380, 340), ("obj_office_desk", 300, 380), ("obj_office_desk", 600, 380),
                             ("obj_water_cooler", 740, 70), ("obj_filing_cabinet", 760, 260), ("obj_bookshelf", 520, 60),
                             ("obj_plant", 760, 520), ("obj_extinguisher", 270, 70)]),
    "work_02": dict(size=(640, 360), seed=32,
                    office=dict(features=(("window", 40), ("whiteboard", 140), ("clock", 240), ("ac", 280),
                                          ("window", 340), ("board", 450), ("window", 530))),
                    objects=[("obj_cubicle", 40, 110), ("obj_cubicle", 112, 110), ("obj_cubicle", 330, 110),
                             ("obj_office_desk", 40, 140), ("obj_office_desk", 112, 140), ("obj_office_desk", 330, 140),
                             ("obj_cubicle", 40, 240), ("obj_cubicle", 112, 240), ("obj_office_desk", 40, 270),
                             ("obj_office_desk", 112, 270), ("obj_printer", 250, 250), ("obj_coffee_station", 560, 70),
                             ("obj_plant_big", 590, 270), ("obj_boxes", 420, 290), ("obj_office_trash", 200, 180),
                             ("obj_filing_cabinet", 480, 70)]),
    "work_03": dict(size=(640, 360), seed=33,
                    office=dict(features=(("window", 40), ("clock", 140), ("poster", 180), ("turno", 300),
                                          ("sign", 380), ("window", 520)),
                                queue_lines=((300, 430, 140), (300, 430, 270))),
                    objects=[("obj_counter_a", 430, 70), ("obj_counter_b", 430, 200), ("obj_stanchion", 320, 120),
                             ("obj_stanchion", 320, 250), ("obj_delivery_tray", 520, 120), ("obj_filing_cabinet", 580, 260),
                             ("obj_plant_big", 20, 270), ("obj_water_cooler", 240, 70), ("obj_sofa", 60, 300),
                             ("obj_printer", 150, 80), ("obj_office_trash", 260, 300)]),
}


def build_scenery() -> None:
    print("Street objects")
    street_objects = {}
    for name, fn in STREET_OBJECTS.items():
        image = fn()
        street_objects[name] = image
        save(image, STREET / "decoration" / f"{name}.png")
        save(grade(image, DUSK), STREET / "decoration" / f"{name}_dusk.png")
        save(grade(image, NIGHT), STREET / "decoration" / f"{name}_night.png")
    print("Office objects")
    office_objects = {name: fn() for name, fn in OFFICE_OBJECTS.items()}
    for name, image in office_objects.items():
        save(image, OFFICE / "decoration" / f"{name}.png")

    print("Street levels")
    for name, spec in STREET_LEVELS.items():
        w, h = spec["size"]
        floor, walls, lit = street_level(w, h, spec["seed"], **spec["street"])
        light = spec["light"]
        objects = street_objects
        if light:
            tint = LIGHTS[light]
            lamps = LAMPS.get(name, ())
            floor = grade(floor, tint, lamps=lamps)
            walls = grade(walls, tint, lit_rects=lit if light != "dusk" else ())
            objects = {k: grade(v, NIGHT if light == "night" else DUSK) for k, v in street_objects.items()}
        save(floor, STREET / f"bg_{name}_floor.png")
        save(walls, STREET / f"bg_{name}_walls.png")
        preview(name, floor, walls, objects, spec["objects"])

    print("Office levels")
    for name, spec in OFFICE_LEVELS.items():
        w, h = spec["size"]
        floor, walls, _ = office_level(w, h, spec["seed"], **spec["office"])
        save(floor, OFFICE / f"bg_{name}_floor.png")
        save(walls, OFFICE / f"bg_{name}_walls.png")
        preview(name, floor, walls, office_objects, spec["objects"])


# Set ART_PREVIEW=<folder> to also write composite previews (floor + walls + objects).
PREVIEW_DIR = Path(os.environ["ART_PREVIEW"]) if os.environ.get("ART_PREVIEW") else None


def preview(name, floor, walls, objects, placements) -> None:
    if PREVIEW_DIR is None:
        return
    out = floor.copy()
    out.alpha_composite(walls)
    for obj, x, y in sorted(placements, key=lambda p: p[2] + objects[p[0]].height):
        out.alpha_composite(objects[obj], (x, y))
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    out.save(PREVIEW_DIR / f"preview_{name}.png")


# ---------------------------------------------------------------- endings (320x180, saved x2)

def load_frame(path: Path, col: int, row: int, cell=(16, 24)) -> Image.Image:
    sheet_im = Image.open(path).convert("RGBA")
    return sheet_im.crop((col * cell[0], row * cell[1], (col + 1) * cell[0], (row + 1) * cell[1]))


def player(direction: int = 0) -> Image.Image:
    return load_frame(SPRITES / "player" / "player_idle.png", 0, direction)


def pockets_out(frame: Image.Image) -> Image.Image:
    out = frame.copy()
    for x in (4, 11):
        rect(out, x, 16, x, 18, hexc("f4f0e8"))
    return out


def sitting_player() -> Image.Image:
    """Side view (facing left) sitting on a curb: thighs forward, shins hanging down."""
    base = player(2)
    out = new(16, 24)
    out.alpha_composite(base.crop((0, 0, 16, 18)), (2, 1))
    pants, shoes = hexc("717171"), hexc("272727")
    rect(out, 2, 18, 11, 20, pants)
    rect(out, 2, 21, 4, 22, pants)
    rect(out, 0, 23, 4, 23, shoes)
    return outline(out)


MOM = {"skin": SKIN, "hair": hexc("9a9a9a"), "top": hexc("c0604a"), "pants": hexc("8a3a34"), "shoes": hexc("4a321c"),
       "extra": lambda im, d, f, b: rect(im, 5, 13 + b, 10, 18 + b, hexc("f0ece0")) if d == 0 else None}
KID = {"skin": SKIN_DARK, "hair": hexc("1a1a1a"), "top": hexc("e3b55a"), "pants": hexc("3f4b5e"), "shoes": hexc("b03a3a")}
DAD = {"skin": SKIN_DARK, "hair": hexc("4a3a2c"), "top": hexc("3c8a4c"), "pants": hexc("4a3a2c"), "shoes": hexc("1a1a1a")}


def place(canvas, sprite, x, y, factor=2):
    canvas.alpha_composite(scale(sprite, factor), (x, y))


def home_prop(name: str) -> Image.Image:
    return Image.open(SPRITES / "environment" / "home" / "decoration" / f"{name}.png").convert("RGBA")


def wood_floor(im, y0, rng):
    rect(im, 0, y0, im.width - 1, im.height - 1, hexc("b76f3d"))
    for y in range(y0, im.height, 8):
        rect(im, 0, y, im.width - 1, y, hexc("6f4932"))
        offset = rng.randint(0, 40)
        for x in range(offset, im.width, rng.randint(50, 90)):
            rect(im, x, y, x, y + 7, hexc("6f4932"))
    speckle(im, 0, y0, im.width - 1, im.height - 1, [hexc("a4643a"), hexc("c47c48")], 0.03, rng)


def vignette(im: Image.Image, strength: float = 0.45) -> Image.Image:
    out = im.copy()
    data = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            d = math.hypot((x - w / 2) / (w / 2), (y - h / 2) / (h / 2)) / math.sqrt(2)
            k = 1 - strength * max(0.0, d - 0.35) / 0.65
            r, g, b, a = data[x, y]
            data[x, y] = (int(r * k), int(g * k), int(b * k), a)
    return out


def tinted(im, tint):
    return grade(im, tint)


def steam(im, x, y, rng):
    for i in range(10):
        px(im, x + rng.randint(-2, 2), y - i, hexc("f4f0e8", 160))


def wall_clock(im, cx, cy, r, hour_angle, minute_angle, ring=hexc("2a2a30")):
    draw = ImageDraw.Draw(im)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ring)
    draw.ellipse([cx - r + 3, cy - r + 3, cx + r - 3, cy + r - 3], fill=hexc("f4f0e6"))
    for k in range(12):
        a = k * math.pi / 6
        x, y = cx + math.sin(a) * (r - 7), cy - math.cos(a) * (r - 7)
        rect(im, int(x), int(y), int(x) + (1 if r > 20 else 0), int(y) + (1 if r > 20 else 0), ring)
    for angle, length, width in ((hour_angle, r * 0.5, 2), (minute_angle, r * 0.78, 1)):
        x1, y1 = cx + math.sin(angle) * length, cy - math.cos(angle) * length
        draw.line([cx, cy, x1, y1], fill=ring, width=width)
    draw.line([cx, cy, cx + math.sin(minute_angle + 0.5) * r * 0.8, cy - math.cos(minute_angle + 0.5) * r * 0.8],
              fill=hexc("d03a3a"), width=1)


def ending_v01():
    rng = random.Random(101)
    im = new(320, 180, hexc("e2965a"))
    rect(im, 0, 82, 319, 119, hexc("f0dcbc"))
    for y in range(82, 120, 8):
        for x in range(0, 320, 8):
            if ((x + y) // 8) % 2:
                rect(im, x, y, x + 7, y + 7, hexc("e0c49c"))
    rect(im, 200, 18, 263, 70, hexc("f0ece0"))
    for y in range(20, 69):
        t = (y - 20) / 48
        rect(im, 202, y, 261, y, (255, int(190 - 70 * t), int(110 - 30 * t), 255))
    ImageDraw.Draw(im).ellipse([222, 44, 242, 64], fill=hexc("ffe08a"))
    rect(im, 231, 20, 232, 68, hexc("f0ece0"))
    wood_floor(im, 120, rng)
    im.alpha_composite(home_prop("obj_cocina"), (6, 64))
    im.alpha_composite(home_prop("obj_nevera"), (168, 52))
    im.alpha_composite(home_prop("obj_mesa_comedor"), (128, 112))
    ImageDraw.Draw(im).ellipse([150, 120, 170, 128], fill=hexc("8a3a34"))
    for x in (154, 160, 166):
        steam(im, x, 118, rng)
    place(im, person_frame(MOM, 3, 0), 96, 88)
    place(im, player(2), 210, 92)
    return vignette(tinted(im, (1.06, 0.94, 0.8)), 0.4)


def ending_v02():
    rng = random.Random(102)
    im = new(320, 180, hexc("2c2836"))
    rect(im, 0, 118, 319, 179, hexc("3a3038"))
    wood_floor(im, 118, rng)
    im = grade(im, (0.45, 0.42, 0.5))
    rect(im, 136, 30, 183, 118, hexc("f6dc9a"))
    rect(im, 132, 26, 187, 30, hexc("5a3d45"))
    rect(im, 132, 26, 135, 118, hexc("5a3d45"))
    rect(im, 184, 26, 187, 118, hexc("5a3d45"))
    for y in range(118, 180):
        spread = (y - 118) * 0.9
        for x in range(int(136 - spread), int(184 + spread)):
            blend(im, x, y, hexc("f6dc9a"), 0.35 * (1 - (y - 118) / 70))
    rect(im, 40, 60, 42, 118, hexc("4a3a2c"))
    rect(im, 32, 48, 50, 60, hexc("f0c86e"))
    for y in range(60, 120):
        for x in range(20, 62):
            if abs(x - 41) < (y - 60) * 0.5:
                blend(im, x, y, hexc("f0c86e"), 0.12)
    place(im, player(0), 144, 70)
    return vignette(im, 0.55)


def ending_v03():
    rng = random.Random(103)
    im = new(320, 180, hexc("c89650"))
    rect(im, 0, 0, 319, 6, hexc("a87840"))
    wood_floor(im, 110, rng)
    rect(im, 158, 0, 159, 28, hexc("3a2e28"))
    rect(im, 148, 28, 169, 34, hexc("f0c86e"))
    for y in range(34, 110):
        for x in range(100, 220):
            if abs(x - 158.5) < (y - 34) * 0.7:
                blend(im, x, y, hexc("ffe8a8"), 0.18)
    rect(im, 96, 104, 223, 132, hexc("8a5a34"))
    rect(im, 96, 104, 223, 108, hexc("a87048"))
    rect(im, 100, 133, 104, 150, hexc("6b4a2b"))
    rect(im, 215, 133, 219, 150, hexc("6b4a2b"))
    for x in (112, 144, 176, 204):
        ImageDraw.Draw(im).ellipse([x, 109, x + 14, 116], fill=hexc("f4f0e8"))
        ImageDraw.Draw(im).ellipse([x + 3, 110, x + 11, 114], fill=hexc("e3a040"))
    npc_neighbor = load_frame(SPRITES / "npcs" / "npc_neighbor.png", 0, 0)
    place(im, person_frame(MOM, 0, 0), 120, 58)
    place(im, npc_neighbor, 176, 58)
    place(im, player(3), 60, 92)
    place(im, person_frame(KID, 2, 0), 232, 100)
    place(im, person_frame(DAD, 0, 0), 148, 58)
    return vignette(tinted(im, (1.08, 0.96, 0.72)), 0.4)


def ending_v04():
    rng = random.Random(104)
    floor, walls, lit = office_level(320, 180, 104, features=(("window", 40), ("clock", 150), ("window", 210)))
    im = floor.copy()
    im.alpha_composite(walls)
    for x0 in (40, 210):
        for y in range(68, 180):
            shift = (y - 68) * 0.6
            for x in range(int(x0 + 10 + shift), int(x0 + 54 + shift)):
                blend(im, x, y, hexc("ffd890"), 0.22)
    for x in (30, 120, 220):
        im.alpha_composite(prop_office_desk(), (x, 104))
    folder = Image.open(SPRITES / "items" / "item_folder.png").convert("RGBA").crop((0, 0, 16, 16))
    place(im, player(0), 150, 118)
    place(im, folder, 176, 136, 1)
    return vignette(tinted(im, (1.06, 0.94, 0.82)), 0.35)


def ending_v05():
    rng = random.Random(105)
    im = new(320, 180, hexc("f0e0c0"))
    rect(im, 0, 0, 319, 12, hexc("b03a3a"))
    for x in range(0, 320, 16):
        rect(im, x, 12, x + 7, 18, hexc("b03a3a"))
    sign = "PANADERIA"
    rect(im, 160 - text_width(sign) // 2 - 6, 24, 160 + text_width(sign) // 2 + 6, 34, hexc("6f4932"))
    text(im, 160 - text_width(sign) // 2, 27, sign, hexc("f4e0a0"))
    for row, y in enumerate((44, 66)):
        rect(im, 20, y + 14, 299, y + 16, hexc("8a5a34"))
        for x in range(26, 296, 16):
            ImageDraw.Draw(im).ellipse([x, y + 4, x + 12, y + 13], fill=hexc("c8843c" if row else "e0a050"))
            rect(im, x + 3, y + 6, x + 9, y + 6, hexc("f0c070"))
    wood_floor(im, 140, rng)
    rect(im, 0, 104, 319, 140, hexc("8a5a34"))
    rect(im, 0, 104, 319, 108, hexc("a87048"))
    rect(im, 40, 92, 140, 104, hexc("bcd8e4", 170))
    for x in range(46, 136, 12):
        ImageDraw.Draw(im).ellipse([x, 96, x + 9, 103], fill=hexc("d89048"))
    rect(im, 220, 96, 229, 104, hexc("f4f0e8"))
    rect(im, 221, 97, 228, 99, hexc("6a3a20"))
    for x in (222, 226):
        steam(im, x, 94, rng)
    place(im, player(0), 168, 120)
    rect(im, 196, 150, 205, 162, hexc("c8a070"))
    rect(im, 196, 150, 205, 151, hexc("a88050"))
    return vignette(tinted(im, (1.06, 0.95, 0.82)), 0.35)


def ending_v06():
    """Bought "Gran Trancon VI" from the street vendor: game night at home with the kid."""
    rng = random.Random(106)
    im = new(320, 180, hexc("2a2440"))
    wood_floor(im, 118, rng)
    im = grade(im, (0.5, 0.48, 0.62))
    # TV with the game on: a night city, a taxi and the title.
    rect(im, 112, 40, 207, 100, hexc("1a1a22"))
    rect(im, 116, 44, 203, 94, hexc("2c3a66"))
    for x, h in ((120, 26), (134, 36), (150, 22), (166, 40), (184, 30)):
        rect(im, x, 94 - h, x + 12, 94, hexc("1c2440"))
        for wy in range(94 - h + 3, 92, 5):
            rect(im, x + 3, wy, x + 4, wy + 1, hexc("f0d070"))
    rect(im, 140, 86, 160, 91, hexc("e8c030"))
    rect(im, 144, 83, 156, 86, hexc("e8c030"))
    title = "GRAN TRANCON VI"
    text(im, 160 - text_width(title) // 2, 48, title, hexc("ff6a9a"))
    rect(im, 156, 100, 163, 110, hexc("1a1a22"))
    rect(im, 140, 110, 179, 113, hexc("3a2e28"))
    # TV glow on the floor and the room.
    for y in range(100, 180):
        spread = (y - 100) * 1.1
        for x in range(int(116 - spread), int(204 + spread)):
            blend(im, x, y, hexc("6a8ad0"), 0.22 * (1 - (y - 100) / 90))
    # Sofa, the player and the kid playing.
    rect(im, 96, 128, 223, 150, hexc("4a5a7a"))
    rect(im, 96, 120, 223, 130, hexc("5a6a8a"))
    place(im, player(1), 122, 92)
    place(im, person_frame(KID, 1, 0), 166, 100)
    rect(im, 136, 122, 141, 125, hexc("2a2a30"))
    rect(im, 178, 126, 183, 129, hexc("2a2a30"))
    # The box of the game on the floor.
    rect(im, 238, 150, 257, 164, hexc("e04a6a"))
    rect(im, 240, 152, 255, 155, hexc("f4e0a0"))
    return vignette(im, 0.5)


def ending_d01():
    im = new(320, 180)
    for y in range(180):
        rect(im, 0, y, 319, y, (int(70 + y * 0.1), int(78 + y * 0.1), int(92 + y * 0.12), 255))
    rect(im, 0, 140, 319, 179, hexc("4a505a"))
    ImageDraw.Draw(im).ellipse([128, 136, 192, 146], fill=(0, 0, 0, 70))
    place(im, pockets_out(player(0)), 136, 66, 3)
    wallet = new(20, 12)
    rect(wallet, 1, 2, 18, 10, hexc("6b4a2b"))
    rect(wallet, 9, 2, 10, 10, hexc("4a321c"))
    rect(wallet, 3, 4, 7, 8, hexc("3a2a1c"))
    rect(wallet, 12, 4, 16, 8, hexc("3a2a1c"))
    place(im, outline(wallet), 196, 112, 2)
    moth = new(9, 5)
    for x, y in ((0, 0), (1, 1), (2, 1), (3, 2), (5, 2), (6, 1), (7, 1), (8, 0), (4, 2), (4, 3), (1, 2), (7, 2)):
        px(moth, x, y, hexc("d8d0c0"))
    for mx, my in ((206, 92), (226, 74), (214, 56)):
        place(im, moth, mx, my, 2)
    return vignette(im, 0.5)


def ending_d02():
    rng = random.Random(202)
    walls, lit = facade_band(320, 96, 202, "barrio")
    im = new(320, 180)
    sidewalk(im, 0, 96, 319, 135, rng)
    shadow_band(im, 0, 96, 319, 103, "top", 0.42)
    curb(im, 0, 136, 319, 141)
    asphalt(im, 0, 142, 319, 179, rng)
    im.alpha_composite(walls)
    im.alpha_composite(prop_lamppost(), (220, 52))
    im = grade(im, NIGHT, lamps=((244, 132, 80),), lit_rects=lit)
    place(im, sitting_player(), 140, 98)
    return vignette(im, 0.55)


def ending_d03():
    im = new(320, 180)
    for y in range(180):
        rect(im, 0, y, 319, y, (int(70 - y * 0.15), int(30 - y * 0.05), int(36 - y * 0.05), 255))
    wall_clock(im, 160, 72, 64, math.radians(355), math.radians(330), ring=hexc("3a1a20"))
    rect(im, 0, 150, 319, 179, hexc("2a1418"))
    place(im, player(1), 148, 126, 2)
    return vignette(im, 0.5)


def ending_d04():
    rng = random.Random(204)
    im = new(320, 180, hexc("2a2636"))
    for x0, x1 in ((0, 70), (250, 319)):
        rect(im, x0, 0, x1, 179, hexc("3a3440"))
        for y in range(0, 180, 8):
            rect(im, x0, y, x1, y, hexc("2c2834"))
            for x in range(x0 + (y // 8 % 2) * 8, x1, 16):
                rect(im, x, y, x, y + 7, hexc("2c2834"))
    sidewalk(im, 71, 0, 249, 179, rng)
    im = grade(im, (0.5, 0.48, 0.66), lamps=((160, 40, 90),))
    for _ in range(7):
        x, y = rng.randint(90, 230), rng.randint(130, 170)
        rect(im, x, y, x + 5, y + 3, hexc("d8d4c8"))
    place(im, pockets_out(player(0)), 144, 84, 2)
    return vignette(im, 0.55)


def ending_d05():
    floor, walls, lit = office_level(320, 180, 205, features=(("window", 30), ("window", 226)))
    im = floor.copy()
    im.alpha_composite(walls)
    for x in (24, 124, 224):
        im.alpha_composite(prop_office_desk(), (x, 108))
    im = grade(im, (0.32, 0.36, 0.52))
    wall_clock(im, 160, 44, 30, 0.0, 0.0)
    for y in range(180):
        for x in range(320):
            d = math.hypot(x - 20, y - 10)
            if d < 150:
                blend(im, x, y, hexc("e03030"), 0.28 * (1 - d / 150))
    rng = random.Random(205)
    for _ in range(9):
        x, y = rng.randint(30, 290), rng.randint(140, 172)
        rect(im, x, y, x + 6, y + 4, hexc("9a9aa8"))
    return vignette(im, 0.5)


# ---------------------------------------------------------------- main

def main() -> None:
    print("Hostiles")
    for name, spec in HOSTILE_PEOPLE.items():
        save(sheet(lambda d, f, s=spec: person_frame(s, d, f)), ENEMIES / f"{name}.png")
    save(sheet(lambda d, f: email_frame(hexc("f4f2ea"), d, f)), ENEMIES / "hostile_email_white.png")
    save(sheet(lambda d, f: email_frame(hexc("f0d88a"), d, f)), ENEMIES / "hostile_email_yellow.png")
    save(sheet(lambda d, f: printer_zone_frame(f), cell=(32, 48), directions=1), ENEMIES / "hostile_printer_queue.png")
    save(sheet(fatigue_frame), ENEMIES / "hostile_fatigue.png")

    # Scenarios now come from generate_scenery_x2.py (pixel x2); build_scenery() is the old 1 px version.

    print("Endings")
    endings = {"v01": ending_v01, "v02": ending_v02, "v03": ending_v03, "v04": ending_v04, "v05": ending_v05, "v06": ending_v06,
               "d01": ending_d01, "d02": ending_d02, "d03": ending_d03, "d04": ending_d04, "d05": ending_d05}
    for name, fn in endings.items():
        save(scale(fn(), 2), ENDINGS / f"ending_{name}.png")


if __name__ == "__main__":
    main()

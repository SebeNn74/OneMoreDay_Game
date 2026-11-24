"""The boss of "La carta a García" (office, work_01): bald on top, gray at the sides, thick moustache,
black suit, white shirt and a dotted black tie.
    python tools/art/generate_boss_letter.py
Writes the NPC sheet (2 breathing frames, 16x24 each, facing down) and a portrait for his minigame.
"""
from pathlib import Path

from PIL import Image, ImageDraw

SPRITES = Path(__file__).resolve().parents[2] / "assets" / "sprites"

SKIN = (200, 150, 112, 255)
SKIN_SHADE = (170, 122, 90, 255)
SKIN_LIGHT = (222, 176, 136, 255)
HAIR = (70, 64, 60, 255)
HAIR_LIGHT = (120, 114, 108, 255)
MOUSTACHE = (40, 34, 30, 255)
SUIT = (34, 34, 40, 255)
SUIT_SHADE = (20, 20, 26, 255)
SHIRT = (240, 240, 236, 255)
TIE = (16, 16, 20, 255)
SHOES = (14, 12, 12, 255)
EYE = (30, 22, 18, 255)


def npc_frame(bob: int) -> Image.Image:
    im = Image.new("RGBA", (16, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((5, 19, 6, 21), fill=SUIT_SHADE)
    d.rectangle((9, 19, 10, 21), fill=SUIT_SHADE)
    d.rectangle((4, 22, 6, 22), fill=SHOES)
    d.rectangle((9, 22, 11, 22), fill=SHOES)
    b = bob
    d.rectangle((4, 12 + b, 11, 18), fill=SUIT)
    d.rectangle((11, 12 + b, 11, 18), fill=SUIT_SHADE)
    d.rectangle((6, 12 + b, 9, 14 + b), fill=SHIRT)              # Shirt.
    d.rectangle((7, 12 + b, 8, 16 + b), fill=TIE)                # Dotted tie.
    d.point((7, 14 + b), fill=SHIRT)
    d.rectangle((3, 13 + b, 3, 17 + b), fill=SUIT_SHADE)
    d.rectangle((12, 13 + b, 12, 17 + b), fill=SUIT_SHADE)
    d.point((3, 18 + b), fill=SKIN)
    d.point((12, 18 + b), fill=SKIN)
    d.rectangle((6, 11 + b, 9, 11 + b), fill=SKIN_SHADE)         # Neck.
    d.rectangle((4, 2 + b, 11, 10 + b), fill=SKIN)               # Head.
    d.rectangle((5, 1 + b, 10, 1 + b), fill=SKIN)
    d.rectangle((6, 2 + b, 8, 3 + b), fill=SKIN_LIGHT)           # Bald top, with a shine.
    d.rectangle((4, 4 + b, 4, 8 + b), fill=HAIR)                 # Gray at the sides.
    d.rectangle((11, 4 + b, 11, 8 + b), fill=HAIR)
    d.point((4, 4 + b), fill=HAIR_LIGHT)
    d.point((11, 4 + b), fill=HAIR_LIGHT)
    d.rectangle((5, 5 + b, 6, 5 + b), fill=HAIR)                 # Eyebrows.
    d.rectangle((9, 5 + b, 10, 5 + b), fill=HAIR)
    d.point((6, 6 + b), fill=EYE)
    d.point((9, 6 + b), fill=EYE)
    d.point((7, 7 + b), fill=SKIN_SHADE)                         # Nose.
    d.point((8, 7 + b), fill=SKIN_SHADE)
    d.rectangle((5, 8 + b, 10, 8 + b), fill=MOUSTACHE)           # Thick moustache.
    d.rectangle((6, 9 + b, 9, 9 + b), fill=MOUSTACHE)
    d.rectangle((7, 10 + b, 8, 10 + b), fill=SKIN_SHADE)
    return im


def portrait() -> Image.Image:
    """64x64 bust, serious, in the dark suit."""
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((6, 50, 57, 63), fill=SUIT)
    d.polygon([(25, 50), (32, 63), (39, 50)], fill=SHIRT)
    d.polygon([(30, 52), (34, 52), (35, 63), (29, 63)], fill=TIE)
    for x, y in ((31, 55), (33, 58), (31, 61)):
        d.point((x, y), fill=SHIRT)
    d.line([(25, 50), (31, 62)], fill=SUIT_SHADE)
    d.line([(39, 50), (33, 62)], fill=SUIT_SHADE)
    d.rectangle((26, 43, 38, 51), fill=SKIN_SHADE)               # Neck.
    d.ellipse((14, 4, 50, 50), fill=SKIN)                        # Head.
    d.ellipse((22, 6, 36, 14), fill=SKIN_LIGHT)                  # Bald top.
    d.rectangle((13, 18, 17, 34), fill=HAIR)                     # Sides of gray hair.
    d.rectangle((47, 18, 51, 34), fill=HAIR)
    d.rectangle((13, 18, 17, 21), fill=HAIR_LIGHT)
    d.rectangle((47, 18, 51, 21), fill=HAIR_LIGHT)
    d.rectangle((11, 24, 14, 31), fill=SKIN_SHADE)               # Ears.
    d.rectangle((50, 24, 53, 31), fill=SKIN_SHADE)
    d.rectangle((20, 21, 28, 23), fill=HAIR)                     # Eyebrows.
    d.rectangle((36, 21, 44, 23), fill=HAIR)
    d.rectangle((22, 26, 26, 28), fill=(250, 246, 240, 255))     # Eyes.
    d.rectangle((38, 26, 42, 28), fill=(250, 246, 240, 255))
    d.rectangle((23, 26, 25, 28), fill=EYE)
    d.rectangle((39, 26, 41, 28), fill=EYE)
    d.polygon([(32, 26), (29, 37), (35, 37)], fill=SKIN_SHADE)   # Nose.
    d.ellipse((21, 36, 43, 44), fill=MOUSTACHE)                  # Moustache.
    d.rectangle((26, 44, 38, 45), fill=(150, 80, 70, 255))       # Mouth.
    d.line([(20, 34), (22, 42)], fill=SKIN_SHADE)                # Lines of the face.
    d.line([(44, 34), (42, 42)], fill=SKIN_SHADE)
    return im


def outline(im: Image.Image) -> Image.Image:
    out = im.copy()
    w, h = im.size
    src = im.load()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0 and any(
                    0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy][3] > 0
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                dst[x, y] = (20, 14, 12, 255)
    return out


if __name__ == "__main__":
    sheet = Image.new("RGBA", (32, 24), (0, 0, 0, 0))
    sheet.alpha_composite(npc_frame(0), (0, 0))
    sheet.alpha_composite(npc_frame(1), (16, 0))
    sheet.save(SPRITES / "npcs" / "npc_boss_letter.png")
    outline(portrait()).save(SPRITES / "npcs" / "boss_letter_portrait.png")
    print("saved npc_boss_letter.png and boss_letter_portrait.png")

"""Abelardo, the politician of the morning bus, as a caricature with a huge forehead.
    python tools/art/generate_abelardo.py
Writes the NPC sheet (2 breathing frames, 16x24 each, facing down) and a portrait for his minigame.
"""
from pathlib import Path

from PIL import Image, ImageDraw

SPRITES = Path(__file__).resolve().parents[2] / "assets" / "sprites"

SKIN = (226, 182, 142, 255)
SKIN_SHADE = (196, 150, 112, 255)
SKIN_LIGHT = (240, 204, 168, 255)
HAIR = (34, 26, 22, 255)
BEARD = (58, 42, 32, 255)
SUIT = (30, 42, 78, 255)
SUIT_SHADE = (20, 28, 54, 255)
SHIRT = (240, 240, 236, 255)
SHOES = (20, 16, 14, 255)
EYE = (24, 18, 14, 255)
FLAG = [(246, 204, 30, 255), (30, 70, 160, 255), (200, 40, 40, 255)]


def npc_frame(bob: int) -> Image.Image:
    im = Image.new("RGBA", (16, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Legs and shoes (they do not breathe).
    d.rectangle((5, 19, 6, 21), fill=SUIT_SHADE)
    d.rectangle((9, 19, 10, 21), fill=SUIT_SHADE)
    d.rectangle((4, 22, 6, 22), fill=SHOES)
    d.rectangle((9, 22, 11, 22), fill=SHOES)
    b = bob
    # Suit, white shirt in a V, pocket square and the flag pin.
    d.rectangle((4, 13 + b, 11, 18), fill=SUIT)
    d.rectangle((11, 13 + b, 11, 18), fill=SUIT_SHADE)
    d.rectangle((7, 13 + b, 8, 16 + b), fill=SHIRT)
    d.point((10, 14 + b), fill=SHIRT)
    d.point((5, 14 + b), fill=FLAG[0])
    d.rectangle((3, 14 + b, 3, 17 + b), fill=SUIT_SHADE)
    d.rectangle((12, 14 + b, 12, 17 + b), fill=SUIT_SHADE)
    d.point((3, 18 + b), fill=SKIN)
    d.point((12, 18 + b), fill=SKIN)
    # The head: a forehead wider than the face and taller than everything else.
    d.rectangle((3, 1 + b, 12, 7 + b), fill=SKIN)           # Forehead.
    d.rectangle((4, 0 + b, 11, 0 + b), fill=SKIN)
    d.rectangle((3, 1 + b, 3, 7 + b), fill=SKIN_SHADE)
    d.rectangle((6, 2 + b, 8, 3 + b), fill=SKIN_LIGHT)      # Shine.
    d.rectangle((4, 0 + b, 11, 0 + b), fill=HAIR)           # Slicked-back hair, far up.
    d.point((3, 1 + b), fill=HAIR)
    d.point((12, 1 + b), fill=HAIR)
    d.rectangle((4, 8 + b, 11, 12 + b), fill=SKIN)          # Face.
    d.rectangle((5, 8 + b, 6, 8 + b), fill=HAIR)            # Eyebrows.
    d.rectangle((9, 8 + b, 10, 8 + b), fill=HAIR)
    d.point((6, 9 + b), fill=EYE)
    d.point((9, 9 + b), fill=EYE)
    d.rectangle((4, 11 + b, 11, 12 + b), fill=BEARD)        # Short beard and moustache.
    d.rectangle((6, 10 + b, 9, 10 + b), fill=BEARD)
    d.rectangle((7, 11 + b, 8, 11 + b), fill=SKIN_SHADE)    # Smile.
    return im


def portrait() -> Image.Image:
    """64x64: saluting, with the forehead taking half of the head."""
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Shoulders and suit.
    d.rectangle((8, 50, 55, 63), fill=SUIT)
    d.polygon([(26, 50), (32, 62), (38, 50)], fill=SHIRT)
    d.rectangle((44, 54, 48, 55), fill=SHIRT)                 # Pocket square.
    for i, color in enumerate(FLAG):                          # Flag pin.
        d.point((14, 53 + i), fill=color)
    d.line([(26, 50), (32, 60)], fill=SUIT_SHADE)
    d.line([(38, 50), (32, 60)], fill=SUIT_SHADE)
    # Neck.
    d.rectangle((27, 44, 37, 50), fill=SKIN_SHADE)
    # The head: a huge dome of forehead over a small face.
    d.ellipse((10, 0, 54, 40), fill=SKIN)
    d.ellipse((16, 4, 34, 16), fill=SKIN_LIGHT)               # Shine.
    d.ellipse((19, 6, 27, 10), fill=(250, 226, 196, 255))
    d.rectangle((17, 22, 47, 44), fill=SKIN)
    d.ellipse((17, 34, 47, 50), fill=SKIN)
    d.arc((12, -2, 52, 12), 200, 340, fill=HAIR, width=3)     # What is left of the hair, slicked back.
    d.rectangle((15, 2, 18, 8), fill=HAIR)
    d.rectangle((46, 2, 49, 8), fill=HAIR)
    for y in (12, 16, 20):                                    # Forehead lines.
        d.line([(24, y), (40, y)], fill=SKIN_SHADE)
    d.rectangle((21, 27, 28, 28), fill=HAIR)                  # Eyebrows.
    d.rectangle((36, 27, 43, 28), fill=HAIR)
    d.rectangle((23, 30, 26, 31), fill=EYE)
    d.rectangle((38, 30, 41, 31), fill=EYE)
    d.line([(32, 30), (31, 37)], fill=SKIN_SHADE)             # Nose.
    d.ellipse((18, 36, 46, 52), fill=BEARD)                   # Beard.
    d.rectangle((22, 37, 42, 39), fill=BEARD)                 # Moustache.
    d.rectangle((27, 42, 37, 43), fill=(240, 240, 236, 255))  # Smile.
    d.rectangle((24, 44, 40, 46), fill=BEARD)
    # Saluting hand at the forehead.
    d.rectangle((44, 14, 54, 22), fill=SKIN)
    d.rectangle((44, 14, 54, 15), fill=SKIN_SHADE)
    d.rectangle((50, 22, 58, 50), fill=SUIT)                  # Sleeve.
    d.rectangle((50, 22, 54, 26), fill=SHIRT)                 # Cuff.
    return im


def outline(im: Image.Image) -> Image.Image:
    """1 px dark outline around the opaque pixels, like the other portraits."""
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
    sheet.save(SPRITES / "npcs" / "npc_abelardo.png")
    outline(portrait()).save(SPRITES / "npcs" / "abelardo_portrait.png")
    print("saved npc_abelardo.png and abelardo_portrait.png")

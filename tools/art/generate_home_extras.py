"""Calendar and family photos for the home wall, in the "pixel x2" style (drawn at half size, shown x2).
    python tools/art/generate_home_extras.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[2] / "assets" / "sprites" / "environment" / "home" / "decoration"
LINE = (47, 27, 26, 255)  # Same outline as the home art.


def calendar() -> Image.Image:
    im = Image.new("RGBA", (12, 15), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 1, 11, 14), fill=(240, 234, 214, 255), outline=LINE)
    d.rectangle((1, 2, 10, 4), fill=(196, 64, 58, 255))          # Month band.
    d.point([(3, 0), (8, 0)], fill=(120, 120, 128, 255))          # Rings.
    for row in range(3):
        for col in range(4):
            d.point((2 + col * 2, 6 + row * 2), fill=(90, 84, 76, 255))
    d.rectangle((7, 10, 8, 11), outline=(196, 64, 58, 255))      # Payday circled.
    return im


def photos() -> Image.Image:
    im = Image.new("RGBA", (22, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Left: the family in the village (sky, green hills, two people).
    d.rectangle((0, 0, 10, 9), fill=(150, 98, 60, 255), outline=LINE)
    d.rectangle((2, 2, 8, 7), fill=(140, 196, 230, 255))
    d.rectangle((2, 6, 8, 7), fill=(98, 160, 84, 255))
    d.point([(4, 4), (6, 4)], fill=(224, 172, 128, 255))
    d.point([(4, 5), (6, 5)], fill=(70, 90, 160, 255))
    # Right: smaller portrait (mom).
    d.rectangle((13, 2, 21, 11), fill=(196, 160, 72, 255), outline=LINE)
    d.rectangle((15, 4, 19, 9), fill=(236, 220, 196, 255))
    d.rectangle((16, 5, 18, 6), fill=(224, 172, 128, 255))
    d.rectangle((16, 7, 18, 9), fill=(170, 70, 110, 255))
    d.point((17, 4), fill=(60, 40, 30, 255))
    return im


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    calendar().save(OUT / "obj_calendar.png")
    photos().save(OUT / "obj_photos.png")
    print("saved", OUT / "obj_calendar.png", OUT / "obj_photos.png")

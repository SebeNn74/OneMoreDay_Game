"""Draws the 4 decision NPCs as 16x24 pixel sprites (same cell as the player).

Output per NPC: a 32x96 idle sheet laid out exactly like player_idle.png:
2 "breathing" frames per row, rows = down, up, left, right.
Right is the left view mirrored. Frame 2 = upper body shifted 1 px down.
Each view is a grid of letters; every letter is a colour of that NPC's palette.
Usage: python generate_npc_sprites.py <out_dir> [<preview_dir> <player_idle.png>]
"""
import sys
from pathlib import Path
from PIL import Image

W, H = 16, 24
SKIN = {"F": "#edc39a", "O": "#e7b88b", "c": "#f0d2b5"}  # player's own skin tones
COMMON = {"Q": "#111111", "E": "#1a1a1a", "e": "#555555"}

NPCS = {
    # NPC-01 Vendedora de tinto (Ida 1): hair to the shoulders, mustard blouse,
    # cream apron, red thermos in her hand.
    "npc_coffee_vendor": {
        "shift_until": 16,
        "palette": {**SKIN, **COMMON,
                    "H": "#2b1d18", "h": "#4e3328",
                    "Y": "#e3a93b", "y": "#b47f20",
                    "W": "#f1ead9", "w": "#cdbfa3",
                    "P": "#3d3f55", "p": "#2a2c3d",
                    "R": "#c43a2e", "r": "#8e2219", "G": "#d9d9d9"},
        "down": [
            ".....HHHHHH.....",
            "....HhhhhhhH....",
            "...HHhhhhhhHH...",
            "...HHhFFFFhHH...",
            "...HFFQFFQFFH...",
            "...HHFFccFFHH...",
            "...HHOFFFFOHH...",
            "...hYYYOOYYYh...",
            "....YWWWWWWY....",
            "...yYWWWWWWYy.G.",
            "...yYWWWWWWYyGGG",
            "...yYWwwwwWYyRRr",
            "...yYWWWWWWYFRRr",
            "...yyWWWWWWyyRRr",
            "...OyWWWWWWyyRRr",
            "....wWWWWWWw.rrr",
            "....PPPPPPPP....",
            "....PPP..PPP....",
            "....PPp..PPp....",
            "....PPp..PPp....",
            "....PPp..PPp....",
            "....EEE..EEE....",
            "....EeE..EeE....",
            "................",
        ],
        "up": [
            ".....HHHHHH.....",
            "....HhhhhhhH....",
            "...HHhhhhhhHH...",
            "...HHhhhhhhHH...",
            "...HHhhhhhhHH...",
            "...HHHhhhhHHH...",
            "...HHHHHHHHHH...",
            "...hYYHHHHYYh...",
            "....YYYHHYYY....",
            ".G.yYYYYYYYYy...",
            "GGGyYYYYYYYYy...",
            "RRryYYYYYYYYy...",
            "RRrFYYYYYYYYy...",
            "RRryyYYYYYYyy...",
            "RRryyWWwWWyyO...",
            "rrr.yyyyyyyy....",
            "....PPPPPPPP....",
            "....PPP..PPP....",
            "....pPP..pPP....",
            "....pPP..pPP....",
            "....pPP..pPP....",
            "....EEE..EEE....",
            "....EEE..EEE....",
            "................",
        ],
        "left": [
            "......HHHH......",
            ".....HhhhhH.....",
            ".....HhhhhHH....",
            ".....hFFhhHH....",
            ".....FQFFhHH....",
            "....FFFccHHH....",
            ".....FFFFHHH....",
            ".......FFYYh....",
            "......YYYYYY....",
            ".....WWYYYYy....",
            "..G..WWYyYYy....",
            ".GGG.WWYyYYy....",
            ".RRrFWWYyYYy....",
            ".RRr.WWyyyyy....",
            ".RRr.WWyyyyy....",
            ".rrr.wWWwww.....",
            "......PPPP......",
            "......PPP.......",
            "......PPp.......",
            "......PPp.......",
            "......PPp.......",
            ".....EEEE.......",
            ".....EeEE.......",
            "................",
        ],
    },
    # NPC-02 Conductor de buseta (Ida 2): red cap, mustache, light-blue shirt,
    # the classic little towel on the shoulder.
    "npc_bus_driver": {
        "shift_until": 16,
        "palette": {**COMMON,
                    "F": "#c68b5e", "O": "#a87048", "c": "#d9a379",
                    "K": "#b83a32", "k": "#7e231d", "V": "#5e1a15", "L": "#ffffff",
                    "H": "#1c1c1c", "M": "#2a1a14",
                    "S": "#8fb8d8", "s": "#6a92b5",
                    "T": "#f2f2f2", "u": "#c9c9c9",
                    "B": "#2a1f1a", "G": "#d7b24a",
                    "P": "#3e5470", "p": "#2c3d53"},
        "down": [
            ".....KKKKKK.....",
            "....KKKLKKKK....",
            "....kKKKKKKk....",
            "...VVVVVVVVVV...",
            "...HFFQFFQFFH...",
            ".....FMMMMF.....",
            ".....FFccFF.....",
            "....TTSOOSSS....",
            "...TTuSSSSSSs...",
            "...TuSSSSSSSs...",
            "...TuSSSSSSSs...",
            "...uSSSSSSSSs...",
            "...sSSSSSSSSs...",
            "...sSSSSSSSSs...",
            "...FsSSSSSSsF...",
            "...OBBBGBBBBO...",
            "....PPPPPPPP....",
            "....PPP..PPP....",
            "....PPp..PPp....",
            "....PPp..PPp....",
            "....PPp..PPp....",
            "....EEE..EEE....",
            "....EeE..EeE....",
            "................",
        ],
        "up": [
            ".....KKKKKK.....",
            "....KKKKKKKK....",
            "....kKKKKKKk....",
            "....kkVVVVkk....",
            "....HHHHHHHH....",
            ".....HHHHHH.....",
            ".....FFFFFF.....",
            "....SSSSSSTT....",
            "...sSSSSSSTTu...",
            "...sSSSSSSSTu...",
            "...sSSSSSSSuS...",
            "...sSSSSSSSSs...",
            "...sSSSSSSSSs...",
            "...sSSSSSSSSs...",
            "...FsSSSSSSsF...",
            "...OBBBBBBBBO...",
            "....PPPPPPPP....",
            "....PPP..PPP....",
            "....pPP..pPP....",
            "....pPP..pPP....",
            "....pPP..pPP....",
            "....EEE..EEE....",
            "....EEE..EEE....",
            "................",
        ],
        "left": [
            "......KKKK......",
            ".....KKKKKk.....",
            ".....KKKKKk.....",
            "...VVVKKKKk.....",
            ".....FQFFHH.....",
            "....FMMFFHH.....",
            ".....FFFFH......",
            ".......FFSST....",
            "......SSSSTT....",
            ".....SSSSSSu....",
            ".....SSSsSSs....",
            ".....SSSsSSs....",
            ".....SSSFSSs....",
            ".....SSSFSSs....",
            ".....SSSOSSs....",
            ".....BBBBBB.....",
            "......PPPP......",
            "......PPP.......",
            "......PPp.......",
            "......PPp.......",
            "......PPp.......",
            ".....EEEE.......",
            ".....EeEE.......",
            "................",
        ],
    },
    # NPC-05 Vendedor de empanadas (Vuelta 1): green t-shirt, wicker basket
    # with golden empanadas and a napkin, held with both hands.
    "npc_empanada_vendor": {
        "shift_until": 16,
        "palette": {**COMMON,
                    "F": "#e0a77a", "O": "#c98e62", "c": "#ecbf98",
                    "H": "#1e1a18", "h": "#3a302a",
                    "G": "#3f9b5a", "g": "#2c7342", "d": "#1c4d2b",
                    "L": "#d39d57", "N": "#b07a3c", "n": "#7a5226",
                    "Y": "#f0b43c", "y": "#c98a20", "W": "#f4efe4",
                    "P": "#3d4a63", "p": "#2b3446"},
        "down": [
            ".....HHHHHH.....",
            "....HHhhhhHH....",
            "....HhhhhhhH....",
            "....HHHHHHHH....",
            "....FFQFFQFF....",
            ".....FFccFF.....",
            ".....FFFFFF.....",
            "....GGGOOGGG....",
            "....dGGGGGGd....",
            "...dGGGGGGGGd...",
            "...gGGGGGGGGg...",
            "...gYYyWYYyYg...",
            "..FLLLLLLLLLLF..",
            "...NNnNNnNNnN...",
            "...nNNnNNnNNn...",
            "....nnnnnnnn....",
            "....PPPPPPPP....",
            "....PPP..PPP....",
            "....PPp..PPp....",
            "....PPp..PPp....",
            "....PPp..PPp....",
            "....EEE..EEE....",
            "....EeE..EeE....",
            "................",
        ],
        "up": [
            ".....HHHHHH.....",
            "....HHhhhhHH....",
            "....HhhhhhhH....",
            "....HhhhhhhH....",
            "....HHhhhhHH....",
            ".....HHHHHH.....",
            ".....FFFFFF.....",
            "....GGGGGGGG....",
            "....dGGGGGGd....",
            "...dGGGGGGGGd...",
            "...gGGGGGGGGg...",
            "..LgGGGGGGGGgL..",
            "..NgGGGGGGGGgN..",
            "...gGGGGGGGGg...",
            "...ggGGGGGGgg...",
            "....gggggggg....",
            "....PPPPPPPP....",
            "....PPP..PPP....",
            "....pPP..pPP....",
            "....pPP..pPP....",
            "....pPP..pPP....",
            "....EEE..EEE....",
            "....EEE..EEE....",
            "................",
        ],
        "left": [
            "......HHHH......",
            ".....HHhhhH.....",
            ".....HhhhhH.....",
            ".....HHHHHH.....",
            ".....FQFFHH.....",
            "....FFFccHH.....",
            ".....FFFFH......",
            ".......FFGG.....",
            "......GGGGGd....",
            ".....GGGGGGd....",
            ".....GgGGGGd....",
            "..YyWYYgGGGd....",
            ".FLLLLLFGGGd....",
            "..NnNNnGGGGd....",
            "..nNNnNgGGGd....",
            "...nnnn.gggg....",
            "......PPPP......",
            "......PPP.......",
            "......PPp.......",
            "......PPp.......",
            "......PPp.......",
            ".....EEEE.......",
            ".....EeEE.......",
            "................",
        ],
    },
    # NPC-06 Vecina del barrio (Vuelta 3): grey bun, rosy cheeks, maroon dress
    # with a flowered apron, offering a plate of food. Flip-flops.
    "npc_neighbor": {
        "shift_until": 17,
        "palette": {**SKIN, **COMMON,
                    "H": "#7d7d84", "h": "#b4b4bc", "w": "#dcdce2", "r": "#e08a7a",
                    "D": "#8e3b5c", "d": "#692a44", "x": "#45192c",
                    "A": "#f3e7c9", "f": "#e07a8a",
                    "T": "#f5f5f5", "t": "#bdbdbd",
                    "Z": "#fbf6ea", "B": "#7a4a2a", "G": "#6ab04c",
                    "S": "#3c6fa8"},
        "down": [
            "......hwhh......",
            "......HhhH......",
            "....HhhwhhhH....",
            "....HhFFFFhH....",
            "....FFQFFQFF....",
            ".....rFccFr.....",
            ".....FFFFFF.....",
            "....DDDOODDD....",
            "....dAAAAAAd....",
            "...dDAfAAfADd...",
            "...dDAAAfAADd...",
            "....tTTTTTTt....",
            "..FTZZBBGGZZTF..",
            "...tTTTTTTTTt...",
            "...dDAAfAAADd...",
            "...xDAAAAfADx...",
            "....DDAAAADD....",
            "....dDDDDDDd....",
            ".....FF..FF.....",
            ".....FO..FO.....",
            ".....FO..FO.....",
            "....SSS..SSS....",
            "....SFS..SFS....",
            "................",
        ],
        "up": [
            "......hwhh......",
            "......HhhH......",
            "....HhhhhhhH....",
            "....HhhwhhhH....",
            "....HhhhhhhH....",
            ".....HhhhhH.....",
            ".....FFFFFF.....",
            "....DDDDDDDD....",
            "....dDDAADDd....",
            "...dDDDDDDDDd...",
            "...dDDDDDDDDd...",
            "..tdDDDDDDDDdt..",
            "..TdDDDAADDDdT..",
            "...dDDAfADDDd...",
            "...dDDDDDDDDd...",
            "...xDDDDDDDDx...",
            "....DDDDDDDD....",
            "....dDDDDDDd....",
            ".....FF..FF.....",
            ".....OF..OF.....",
            ".....OF..OF.....",
            "....SSS..SSS....",
            "....SSS..SSS....",
            "................",
        ],
        "left": [
            "........hwh.....",
            "......HHhhH.....",
            ".....HhhwhhH....",
            ".....hhhhhhH....",
            ".....FQFFhH.....",
            "....FFrFFHH.....",
            ".....FFFFH......",
            ".......FFDD.....",
            "......DDDDDd....",
            ".....AADDDDd....",
            ".....AfDdDDd....",
            ".tTTtAADdDDd....",
            "TZBGZFAdDDDd....",
            ".tTTtAAdDDDd....",
            ".....AfDDDDd....",
            ".....AADDDDx....",
            ".....ADDDDD.....",
            ".....dDDDDd.....",
            "......FF........",
            "......FO........",
            "......FO........",
            ".....SSSS.......",
            ".....SFSS.......",
            "................",
        ],
    },
}
VIEWS = ("down", "up", "left")  # sheet rows; "right" (row 3) = mirrored left


def rgba(hex_color):
    return tuple(int(hex_color[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def draw(rows, palette):
    assert len(rows) == H, f"{len(rows)} rows, expected {H}"
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        assert len(row) == W, f"row {y} has {len(row)} px: {row!r}"
        for x, ch in enumerate(row):
            if ch != ".":
                assert ch in palette, f"unknown colour {ch!r} in row {y}"
                img.putpixel((x, y), rgba(palette[ch]))
    return img


def breathe(rows, shift_until):
    """Frame 2: rows 0..shift_until move 1 px down; legs below stay put."""
    return ["." * W] + rows[:shift_until + 1] + rows[shift_until + 2:]


def build_sheet(spec):
    sheet = Image.new("RGBA", (W * 2, H * 4), (0, 0, 0, 0))
    for r, view in enumerate(VIEWS + ("right",)):
        rows = spec["left"] if view == "right" else spec[view]
        f1 = draw(rows, spec["palette"])
        f2 = draw(breathe(rows, spec["shift_until"]), spec["palette"])
        if view == "right":
            f1, f2 = (f.transpose(Image.FLIP_LEFT_RIGHT) for f in (f1, f2))
        sheet.paste(f1, (0, r * H))
        sheet.paste(f2, (W, r * H))
    return sheet


def save_preview(sheets, preview_dir, player_idle):
    """x6 grid: one column per character (player first), one row per direction."""
    sheets = [Image.open(player_idle).convert("RGBA")] + sheets
    scale, gap = 6, 4
    size = ((W + gap) * len(sheets) + gap, (H + gap) * 4 + gap)
    frames = []
    for i in range(2):
        canvas = Image.new("RGBA", size, (222, 214, 196, 255))
        for col, sheet in enumerate(sheets):
            for row in range(4):
                cell = sheet.crop((i * W, row * H, (i + 1) * W, (row + 1) * H))
                canvas.alpha_composite(cell, (gap + col * (W + gap), gap + row * (H + gap)))
        big = canvas.resize((size[0] * scale, size[1] * scale), Image.NEAREST)
        if i == 0:
            big.save(preview_dir / "npcs_preview.png")
        frames.append(big.convert("P", palette=Image.ADAPTIVE))
    frames[0].save(preview_dir / "npcs_idle.gif", save_all=True, append_images=frames[1:],
                   duration=333, loop=0)  # 3 fps, same as the player's idle


def main(out_dir, preview_dir=None, player_idle=None):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    sheets = []
    for name, spec in NPCS.items():
        sheet = build_sheet(spec)
        assert sheet.size == (32, 96)
        sheet.save(out_dir / f"{name}.png")
        sheets.append(sheet)
    if preview_dir:
        Path(preview_dir).mkdir(parents=True, exist_ok=True)
        save_preview(sheets, Path(preview_dir), player_idle)
    print("ok:", ", ".join(f"{n}.png" for n in NPCS))


if __name__ == "__main__":
    main(*sys.argv[1:4])

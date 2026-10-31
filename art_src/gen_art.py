#!/usr/bin/env python3
"""Generate all pixel-art assets as SVG, rasterize to PNG, then nearest-neighbor upscale.

Run: python3 art_src/gen_art.py
Requires: cairosvg, pillow
"""
import math
import os
import random

import cairosvg
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "art")
os.makedirs(OUT, exist_ok=True)
os.makedirs(os.path.join(OUT, "icons"), exist_ok=True)

INK = "#0b0618"
DEEP = "#140a2e"
PURPLE = "#24104a"
PLUM = "#3a1a6e"
VIOLET = "#5a2a8a"
MAGENTA = "#a83d8a"
GOLD = "#ffcc4d"
GOLD_D = "#b07d21"
CYAN = "#7cf6c9"
BLUE = "#5bb8ff"
RED = "#ff5a6e"
RED_D = "#a12b45"
WHITE = "#f5f1ff"
GREY = "#8f86a8"
DARK = "#080411"


def rects(items):
    out = []
    for it in items:
        if isinstance(it, str):
            out.append(it)
        else:
            x, y, w, h, c = it
            out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{c}"/>')
    return "".join(out)


def svg(w, h, body, bg=None):
    fill = f'<rect width="{w}" height="{h}" fill="{bg}"/>' if bg else ""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
        f'shape-rendering="crispEdges">{fill}{body}</svg>'
    )


def save(name, svg_text, scale=1):
    path = os.path.join(OUT, name)
    base = os.path.join(OUT, ".base.png")
    cairosvg.svg2png(bytestring=svg_text.encode(), write_to=base)
    im = Image.open(base).convert("RGBA")
    if scale != 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    im.save(path)
    print("wrote", path, im.size)


def stars(w, h, n=60, seed=7):
    rnd = random.Random(seed)
    out = []
    for _ in range(n):
        x = rnd.randrange(0, w)
        y = rnd.randrange(0, int(h * 0.7))
        c = rnd.choice([WHITE, CYAN, GOLD, "#b9a8ff"])
        s = rnd.choice([1, 1, 2])
        out.append((x, y, s, s, c))
    return rects(out)


# ---------------------------------------------------------------- backgrounds
def bg_title():
    w, h = 480, 270
    body = []
    for y in range(0, h, 6):
        t = y / h
        c = ("#140a2e", "#1a0f3d", "#22124a", "#2b1658", "#341a63")[min(4, int(t * 5))]
        body.append((0, y, w, 6, c))
    body.append(stars(w, h, 80, 3))
    # moon
    body.append(rects([(356, 42, 58, 58, "#f5d67a"), (350, 48, 6, 40, "#f5d67a"), (414, 50, 6, 34, "#f5d67a")]))
    body.append(rects([(356, 42, 58, 10, "#ffe9a8")]))
    # mountain layers
    body.append(rects([(0, 196, w, 74, "#120827")]))
    for x in range(0, w, 40):
        top = 176 + int(math.sin(x * 0.05) * 14)
        body.append((x, top, 44, 196 - top, "#1b0d35"))
    body.append(rects([(0, 232, w, 38, "#25104c")]))
    # arena grid floor
    for i in range(12):
        body.append((i * 40, 232, 2, 38, "#341a63"))
    for i in range(4):
        body.append((0, 240 + i * 8, w, 1, "#3a1a6e"))
    # floating cards
    for (x, y, r, c) in [(86, 92, 0, "#7cf6c9"), (126, 64, 0, "#ffcc4d"), (386, 120, 0, "#ff5a6e")]:
        body.append(rects([(x, y, 26, 34, c), (x + 4, y + 5, 18, 24, DEEP), (x + 8, y + 9, 10, 3, c)]))
    # pixel title banner
    body.append(rects([(64, 150, 352, 4, GOLD), (64, 186, 352, 4, GOLD)]))
    body.append(rects([(64, 154, 4, 32, GOLD), (412, 154, 4, 32, GOLD)]))
    save("bg_title.png", svg(w, h, rects(body)), scale=4)


def bg_lobby():
    w, h = 480, 270
    body = []
    for y in range(0, h, 8):
        t = y / h
        body.append((0, y, w, 8, ("#120827", "#170b32", "#1d0e3a")[int(t * 3)]))
    body.append(stars(w, h, 40, 11))
    body.append(rects([(0, 190, w, 80, "#0e0620")]))
    # hall pillars
    for x in [40, 150, 300, 410]:
        body.append(rects([(x, 70, 18, 170, "#221045"), (x + 4, 76, 10, 158, "#2d1559"),
                           (x - 4, 66, 26, 6, "#3a1a6e"), (x - 4, 236, 26, 6, "#3a1a6e")]))
    # banners
    for x, c in [(210, RED), (250, CYAN)]:
        body.append(rects([(x, 82, 20, 96, c), (x + 3, 88, 14, 80, DEEP)]))
        body.append(rects([(x + 6, 96, 8, 8, c), (x + 6, 128, 8, 8, c)]))
    # lanterns
    for x in [95, 360]:
        body.append(rects([(x, 96, 10, 16, GOLD), (x + 2, 100, 6, 8, "#fff0b0"), (x + 4, 86, 2, 10, GREY)]))
    # carpet
    body.append(rects([(0, 246, w, 24, "#2a1140")]))
    for i in range(8):
        body.append((i * 60, 252, 30, 2, "#4a2166"))
    # floor tiles
    for i in range(12):
        body.append((i * 40, 200, 1, 46, "#1a0d33"))
    save("bg_lobby.png", svg(w, h, rects(body)), scale=4)


def bg_room():
    w, h = 480, 270
    body = []
    for y in range(0, h, 6):
        body.append((0, y, w, 6, "#150a2f" if y < 140 else "#190c37"))
    body.append(stars(w, h, 30, 23))
    # big table
    body.append(rects([(40, 168, 400, 12, "#3a1a6e"), (48, 180, 384, 70, "#24104a"),
                       (60, 250, 12, 20, "#160a2c"), (408, 250, 12, 20, "#160a2c")]))
    # table map / cards
    for i in range(8):
        x = 84 + i * 40
        body.append(rects([(x, 190, 24, 34, ["#7cf6c9", "#ffcc4d", "#ff5a6e", "#5bb8ff"][i % 4]),
                           (x + 3, 194, 18, 24, DEEP)]))
    # chairs
    for x in [70, 180, 290, 400]:
        body.append(rects([(x, 138, 30, 26, "#2d1559"), (x + 4, 142, 22, 18, "#4677a0")]))
    # hanging lamps
    for x in [160, 320]:
        body.append(rects([(x, 20, 2, 34, GREY), (x - 8, 54, 18, 14, GOLD), (x - 4, 58, 10, 6, "#fff0b0")]))
    save("bg_room.png", svg(w, h, rects(body)), scale=4)


def bg_battle():
    w, h = 480, 270
    body = []
    for y in range(0, h, 5):
        c = ("#0d0620", "#140a2e", "#1b0e3c")[min(2, y // 90)]
        body.append((0, y, w, 5, c))
    body.append(stars(w, h, 50, 31))
    # distant arena walls
    body.append(rects([(0, 120, w, 80, "#1a0d34")]))
    for i in range(10):
        body.append((i * 52, 96 + (i % 2) * 12, 30, 104 - (i % 2) * 12, "#221045"))
    # floor
    body.append(rects([(0, 196, w, 74, "#24104a")]))
    for i in range(8):
        body.append((0, 204 + i * 9, w, 1, "#33195f"))
    for i in range(14):
        body.append((i * 36, 196, 1, 74, "#1c0c38"))
    # banners
    body.append(rects([(12, 40, 34, 110, RED), (16, 46, 26, 96, "#5c1024"), (24, 60, 10, 10, GOLD)]))
    body.append(rects([(434, 40, 34, 110, CYAN), (438, 46, 26, 96, "#124d47"), (448, 60, 10, 10, GOLD)]))
    # glow orbs
    for x, c in [(120, "#7cf6c9"), (360, "#ff5a6e")]:
        body.append(rects([(x, 150, 6, 6, c), (x - 6, 154, 18, 2, c), (x + 2, 144, 2, 18, c)]))
    save("bg_battle.png", svg(w, h, rects(body)), scale=4)


# ---------------------------------------------------------------- UI skins
def panel(name, fill, border, hi):
    w = h = 48
    b = 4
    body = [
        (0, 0, w, h, border),
        (b, b, w - 2 * b, h - 2 * b, fill),
        (b, b, w - 2 * b, 1, hi),
        (b, b, 1, h - 2 * b, hi),
        (b, h - b - 1, w - 2 * b, 1, "#00000055"),
        (w - b - 1, b, 1, h - 2 * b, "#00000055"),
    ]
    # corner notches
    for cx, cy in [(0, 0), (w - 4, 0), (0, h - 4), (w - 4, h - 4)]:
        body.append((cx, cy, 4, 4, border))
    save(name, svg(w, h, rects(body)), scale=2)


def button(name, top, bottom, border, text_c):
    w, h = 64, 32
    body = [
        (0, 0, w, h, "#080411"),
        (1, 1, w - 2, h - 2, border),
        (2, 2, w - 4, h - 4, top),
        (2, 2, w - 4, 2, "#ffffff30"),
        (2, h - 6, w - 4, 4, bottom),
    ]
    # pixel corner cut
    for cx, cy in [(1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)]:
        body.append((cx, cy, 1, 1, DARK))
    save(name, svg(w, h, rects(body)), scale=2)


def card_frame(name, bg, border, glow=None):
    w, h = 180, 112
    body = [(0, 0, w, h, "#060310"), (2, 2, w - 4, h - 4, border), (5, 5, w - 10, h - 10, bg)]
    if glow:
        body.append((2, 2, w - 4, 2, glow))
        body.append((2, h - 4, w - 4, 2, glow))
        body.append((2, 2, 2, h - 4, glow))
        body.append((w - 4, 2, 2, h - 4, glow))
    body.append((8, 8, w - 16, 26, "#00000038"))
    body.append((8, h - 22, w - 16, 14, "#00000030"))
    for cx, cy in [(4, 4), (w - 9, 4), (4, h - 9), (w - 9, h - 9)]:
        body.append((cx, cy, 5, 5, "#0b0618"))
    save(name, svg(w, h, rects(body)), scale=2)


def icon(name, pixels, palette):
    n = len(pixels)
    m = len(pixels[0])
    body = []
    for y, row in enumerate(pixels):
        for x, ch in enumerate(row):
            c = palette.get(ch)
            if c:
                body.append((x, y, 1, 1, c))
    save(os.path.join("icons", name + ".png"), svg(m, n, rects(body)), scale=4)


ICON_MAP = {
    "heart": [
        "................",
        "..RR....RR......",
        ".RRRR..RRRR.....",
        "RRRRRRRRRRRR....",
        "RRRRRRRRRRRR....",
        ".RRRRRRRRRR.....",
        "..RRRRRRRR......",
        "...RRRRRR.......",
        "....RRRR........",
        ".....RR.........",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
    "clock": [
        "................",
        "................",
        ".....GGGGGG.....",
        "...GG....GG.....",
        "..GG..W...GG....",
        "..G...WW..GG....",
        "..G...WW...G....",
        "..G...WW...G....",
        "..GG......GG....",
        "...GG....GG.....",
        ".....GGGGGG.....",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
    "dragon": [
        "................",
        "..CC........CC..",
        ".CCCC......CCCC.",
        "CCCCCC....CCCCCC",
        ".CCCCCCCCCCCCC..",
        "..CCCCCCCCCCC...",
        "...CC..CC..CC...",
        "..CCCCCCCCCCCC..",
        ".CCCC..CC..CCCC.",
        "CCCC....CC....CC",
        ".CC...........CC",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],

    "luck": [
        "................",
        ".......CC.......",
        "......CCCC......",
        ".....CCCCCC.....",
        "....CCCCCCCC....",
        ".....CCCCCC.....",
        "..CC..CCCC..CC..",
        ".CCCC.CCCC.CCCC.",
        ".CCCCCCCCCCCCCC.",
        "..CCCCCCCCCCCC..",
        "...CCCCCCCCCC...",
        "....CCCCCCCC....",
        "......GGGG......",
        ".......GG.......",
        "................",
        "................",
    ],
    "block": [
        "................",
        "....GGGGGGGG....",
        "...GWWWWWWWWG...",
        "..GWWGGGGGGWWG..",
        "..GWGGGGGGGGWG..",
        "..GWGGGGGGGGWG..",
        "..GWGGGGGGGGWG..",
        "..GWGGGGGGGGWG..",
        "..GWGGGGGGGGWG..",
        "...GWWGGGGWWG...",
        "....GWWWWWWG....",
        ".....GGGGGG.....",
        "................",
        "................",
        "................",
        "................",
    ],
    "absorb": [
        "................",
        ".....BBBBBB.....",
        "....BB....BB....",
        "...BB......BB...",
        "..BB........BB..",
        "..BB........BB..",
        "..BB........BB..",
        "..BB........BB..",
        "...BB......BB...",
        "....BB....BB....",
        ".....BBBBBB.....",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
    "dart": [
        "................",
        "............WW..",
        "...........WWW..",
        "..........WWW...",
        "...GGGGGGWWW....",
        "..GGGGGGGGGG....",
        "...GGGGGGWWW....",
        "..........WWW...",
        "...........WWW..",
        "............WW..",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
    "bomb": [
        "................",
        "..........RR....",
        ".........R.RR...",
        "........RRRRR...",
        "......RRRRRRR...",
        ".....RRRRRRRR...",
        "....RRRRRRRRRR..",
        "...RRRRRRRRRRR..",
        "...RRRRRRRRRRR..",
        "....RRRRRRRRRR..",
        ".....RRRRRRRR...",
        "......RRRRRR....",
        "................",
        "................",
        "................",
        "................",
    ],
    "shield": [
        "................",
        "...BBBBBBBBBB...",
        "..BBBBBBBBBBBB..",
        "..BBBBBBBBBBBB..",
        "..BBBBBBBBBBBB..",
        "..BBBBBBBBBBBB..",
        "..BBBBBBBBBBBB..",
        "...BBBBBBBBBB...",
        "....BBBBBBBB....",
        ".....BBBBBB.....",
        "......BBBB......",
        ".......BB.......",
        "................",
        "................",
        "................",
        "................",
    ],
    "dodge": [
        "................",
        "....CCCCCCCC....",
        "...CCCCCCCCCC...",
        "..CC..CCCC..CC..",
        "..CC..CCCC..CC..",
        "..CCCCCCCCCCCC..",
        "..CCCCCCCCCCCC..",
        "..CC..CCCC..CC..",
        "..CC..CCCC..CC..",
        "...CCCCCCCCCC...",
        "....CCCCCCCC....",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
    "peach": [
        "................",
        "......PP..PP....",
        ".....PPPPPPPP...",
        "....PPPPPPPPPP..",
        "...PPPPPPPPPPPP.",
        "...PPPPPPPPPPPP.",
        "...PPPPPPPPPPPP.",
        "....PPPPPPPPPP..",
        ".....PPPPPPPP...",
        "......PPPPPP....",
        ".......PPPP.....",
        "........PP......",
        "................",
        "................",
        "................",
        "................",
    ],
    "cannon": [
        "................",
        "................",
        ".....GGGGGGGG...",
        "....GGGGGGGGGG..",
        "...GGGGGGGGGGGG.",
        "...GGGGGGGGGGGG.",
        "...GGGGGGGGGGGG.",
        "....GGGGGGGGGG..",
        ".....GGGGGGGG...",
        "......DDDDDD....",
        ".....DDDDDDDD...",
        "......DDDDDD....",
        "................",
        "................",
        "................",
        "................",
    ],
    "sweep": [
        "................",
        "....WWWWWWWW....",
        "...WWWWWWWWWW...",
        "..WWWWWWWWWWWW..",
        "..WW..WW..WW..W.",
        "..WWWWWWWWWWWW..",
        "...WWWWWWWWWW...",
        "....WWWWWWWW....",
        "..WWWWWWWWWWWW..",
        "...W..W..W..W...",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
    "dot": [
        "................",
        "......RRRR......",
        ".....RRRRRR.....",
        "....RRRRRRRR....",
        "....RRRRRRRR....",
        "....RRRRRRRR....",
        ".....RRRRRR.....",
        "......RRRR......",
        ".......RR.......",
        "......RRRR......",
        ".....RRRRRR.....",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
    "turtle": [
        "................",
        "................",
        ".....GGGGGG.....",
        "....GGGGGGGG....",
        "...GGGGGGGGGG...",
        "..GGGGGGGGGGGG..",
        "..GGGGGGGGGGGG..",
        "..GGGGGGGGGGGG..",
        "...GGGGGGGGGG...",
        "....GGGGGGGG....",
        ".....G.GG.G.....",
        "....GG.GG.GG....",
        "................",
        "................",
        "................",
        "................",
    ],
    "skull": [
        "................",
        ".....WWWWWW.....",
        "....WWWWWWWW....",
        "...WWWWWWWWWW...",
        "...WW.WWWW.WW...",
        "...WW.WWWW.WW...",
        "...WWWWWWWWWW...",
        "....W.WWWW.W....",
        "....WWWWWWWW....",
        ".....W.WW.W.....",
        ".....W.WW.W.....",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
    "nuke": [
        "................",
        ".......YY.......",
        "......YYYY......",
        ".....YYYYYY.....",
        "....YY.RR.YY....",
        "...YYY.RR.YYY...",
        "..YYYYRRRRYYYY..",
        "..YYYYYYYYYYYY..",
        "...YY.RRRR.YY...",
        "....YY.RR.YY....",
        ".....YYYYYY.....",
        "......YYYY......",
        ".......YY.......",
        "................",
        "................",
        "................",
    ],
    "prism": [
        "................",
        ".......CC.......",
        "......CCCC......",
        ".....CCCCCC.....",
        "....CCCCCCCC....",
        "...CCCCCCCCCC...",
        "..CCCCCCCCCCCC..",
        ".CCCCCCCCCCCCCC.",
        "..CCCCCCCCCCCC..",
        "...CCCCCCCCCC...",
        "....CCCCCCCC....",
        ".....CCCCCC.....",
        "......CCCC......",
        ".......CC.......",
        "................",
        "................",
    ],
    "poison": [
        "................",
        ".......CC.......",
        "......CCCC......",
        ".....CCCCCC.....",
        "....CCCCCCCC....",
        "...CCCCCCCCCC...",
        "..CCCCCCCCCCCC..",
        "..CCCCCCCCCCCC..",
        "...CCCCCCCCCC...",
        "....CCCCCCCC....",
        ".....CCCCCC.....",
        "......CCCC......",
        ".......CC.......",
        "................",
        "................",
        "................",
    ],
    "gun": [
        "................",
        "................",
        "..GGGGGGGGGGGG..",
        "..GGGGGGGGGGGG..",
        "..GGGGGGGGGGGG..",
        "..GGGGGGGGGGGG..",
        "..GG..GGGGGGGG..",
        "..GG..GGGGGGGG..",
        "..GG..GGGGGGGG..",
        "..GG..GGGGGGGG..",
        "..GG..GGGGGGGG..",
        "..GGGGGGGGGGGG..",
        "................",
        "................",
        "................",
        "................",
    ],
    "duel": [
        "................",
        "..WW........WW..",
        "..WWW......WWW..",
        "...WWW....WWW...",
        "....WWWWWWWW....",
        ".....WWWWWW.....",
        "......WWWW......",
        ".....WWWWWW.....",
        "....WWWWWWWW....",
        "...WWW....WWW...",
        "..WWW......WWW..",
        "..WW........WW..",
        "................",
        "................",
        "................",
        "................",
    ],
    "revive": [
        "................",
        ".......GG.......",
        "......GGGG......",
        ".....GGGGGG.....",
        "....GGGGGGGG....",
        "...GGGGGGGGGG...",
        "..GGGGGGGGGGGG..",
        "..GGGGGGGGGGGG..",
        "...GGGGGGGGGG...",
        "....GGGGGGGG....",
        ".....GGGGGG.....",
        "......GGGG......",
        ".......GG.......",
        "................",
        "................",
        "................",
    ],
    "eye": [
        "................",
        "................",
        ".....KKKKKK.....",
        "...KK......KK...",
        "..KK..KKKK..KK..",
        ".KK..KKKKKK..KK.",
        ".KK..KKKKKK..KK.",
        "..KK..KKKK..KK..",
        "...KK......KK...",
        ".....KKKKKK.....",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
    "star": [
        "................",
        ".......YY.......",
        ".......YY.......",
        "......YYYY......",
        "..YYYYYYYYYYYY..",
        "...YYYYYYYYYY...",
        "....YYYYYYYY....",
        ".....YYYYYY.....",
        "....YYYYYYYY....",
        "...YYY....YYY...",
        "..YY........YY..",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
}

ICON_PAL = {
    "C": CYAN, "G": GOLD, "W": WHITE, "R": RED, "B": BLUE, "P": "#ff9ab5",
    "D": GOLD_D, "Y": "#ffe98a", "K": "#24104a",
}


# ---------------------------------------------------------------- avatars
def avatar(name, grid, pal):
    n = len(grid)
    m = len(grid[0])
    body = []
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            c = pal.get(ch)
            if c:
                body.append((x, y, 1, 1, c))
    save(name, svg(m, n, rects(body)), scale=4)


AVATAR_PAL = {
    "K": INK, "W": WHITE, "G": GOLD, "C": CYAN, "R": RED, "B": BLUE,
    "P": "#ff9ab5", "V": VIOLET, "S": "#c8b9ff", "D": GOLD_D,
}

AVATARS = [
    ("avatar_0.png", [
        "................",
        "................",
        "......CCCC......",
        "....CCCCCCCC....",
        "...CCCCCCCCCC...",
        "...CC.WW.WW.CC..",
        "...CC.KK.KK.CC..",
        "....CCCCCCCC....",
        "....CC.KK.CC....",
        "...CCCCCCCCCC...",
        "..CCCCCCCCCCCC..",
        "..CCCCCCCCCCCC..",
        "...CCCCCCCCCC...",
        "....CC....CC....",
        "....CC....CC....",
        "................",
    ]),
    ("avatar_1.png", [
        "................",
        "......RRRR......",
        "....RRRRRRRR....",
        "...RRRRRRRRRR...",
        "..RRRRRRRRRRRR..",
        "..RR.WW..WW.RR..",
        "..RR.KK..KK.RR..",
        "..RRRRRRRRRRRR..",
        "...RRRRRRRRRR...",
        "...WWWWWWWWWW...",
        "..WWWWWWWWWWWW..",
        "..WWWWWWWWWWWW..",
        "...WWWWWWWWWW...",
        "....WW....WW....",
        "....WW....WW....",
        "................",
    ]),
    ("avatar_2.png", [
        "................",
        "..GG..........GG",
        "..GGG........GGG",
        "...GGGGGGGGGGG..",
        "....GGGGGGGG....",
        "...GG.WW.WW.GG..",
        "...GG.CC.CC.GG..",
        "....GGGGGGGG....",
        ".....G.GG.G.....",
        "....GGGGGGGG....",
        "...GGGGGGGGGG...",
        "..GGGGGGGGGGGG..",
        "..GGGG.GG.GGGG..",
        "...GG..GG..GG...",
        ".......GG.......",
        "................",
    ]),
    ("avatar_3.png", [
        "................",
        "......BBBB......",
        "....BBBBBBBB....",
        "...BBBBBBBBBB...",
        "..BBBBBBBBBBBB..",
        "..BB.CC..CC.BB..",
        "..BB.CC..CC.BB..",
        "..BBBBBBBBBBBB..",
        "...BBBBBBBBBB...",
        "...BB.GGGG.BB...",
        "...BBGGGGGGBB...",
        "..BBBBBBBBBBBB..",
        "..BBBBBBBBBBBB..",
        "...BB......BB...",
        "...BB......BB...",
        "................",
    ]),
    ("avatar_4.png", [
        "................",
        ".......SS.......",
        ".....SSSSSS.....",
        "....SSSSSSSS....",
        "...SSSSSSSSSS...",
        "...SS.KK.KK.SS..",
        "...SS.KK.KK.SS..",
        "....SSSSSSSS....",
        ".....SSSSSS.....",
        "....SSSSSSSS....",
        "...SSSSSSSSSS...",
        "..SSSSSSSSSSSS..",
        "..SSSSSSSSSSSS..",
        "...SS.SS.SS.S...",
        "................",
        "................",
    ]),
    ("avatar_5.png", [
        "................",
        "......VVVV......",
        "....VVVVVVVV....",
        "...VVVVVVVVVV...",
        "..VVVVVVVVVVVV..",
        "..VV.WW..WW.VV..",
        "..VV.KK..KK.VV..",
        "..VVVVVVVVVVVV..",
        "...VVVVVVVVVV...",
        "...VV.WWWW.VV...",
        "..VVVVVVVVVVVV..",
        "..VVVVVVVVVVVV..",
        "..VVV.VVVV.VVV..",
        "...VV..VV..VV...",
        "................",
        "................",
    ]),
    ("avatar_6.png", [
        "................",
        ".RR..........RR.",
        ".RRR........RRR.",
        "..RRRRRRRRRRRR..",
        "...RRRRRRRRRR...",
        "...RR.WW.WW.RR..",
        "...RR.KK.KK.RR..",
        "....RRRRRRRR....",
        ".....R.KK.R.....",
        "....RRRRRRRR....",
        "...RRRRRRRRRR...",
        "..RRRRRRRRRRRR..",
        "...RRRR..RRRR...",
        "....RR....RR....",
        "....RR....RR....",
        "................",
    ]),
    ("avatar_7.png", [
        "................",
        "....VVVVVVVV....",
        "...VVVVVVVVVV...",
        "..VVVVVVVVVVVV..",
        "..VV.GG..GG.VV..",
        "..VV.KK..KK.VV..",
        "..VVVVVVVVVVVV..",
        "...VVVVVVVVVV...",
        "....VVVVVVVV....",
        "...VVVVVVVVVV...",
        "..VVVVVVVVVVVV..",
        "..VVVVVVVVVVVV..",
        "...VVVVVVVVVV...",
        "....VV....VV....",
        "................",
        "................",
    ]),
]


# ---------------------------------------------------------------- logo
def logo():
    body = [
        (10, 82, 460, 4, GOLD),
        (10, 92, 460, 4, GOLD_D),
    ]
    text = (
        '<text x="240" y="72" text-anchor="middle" font-family="DejaVu Sans Mono, monospace" '
        'font-weight="bold" font-size="58" fill="#ffcc4d" '
        'letter-spacing="2">MXDPPP+</text>'
    )
    body.append(text)
    save("logo.png", svg(480, 120, rects(body)), scale=4)



def check_icon(name, on):
    body = [(0,0,16,16,"#0b0618"), (1,1,14,14,"#2b1559"), (2,2,12,12,"#140a2e")]
    if on:
        for (x, y) in [(4,8),(5,9),(6,10),(7,9),(8,8),(9,7),(10,6),(11,5)]:
            body.append((x,y,2,2,"#7cf6c9"))
    else:
        body.append((2,2,12,12,"#8f86a8"))
        body.append((3,3,10,10,"#1a0d33"))
    save(os.path.join("icons", name + ".png"), svg(16,16,rects(body)))

# ---------------------------------------------------------------- main
def main():
    bg_title()
    bg_lobby()
    bg_room()
    bg_battle()
    panel("panel.png", "#1d0f3d", "#ffcc4d", "#4a2a7a")
    panel("panel_dark.png", "#120827", "#3a1a6e", "#2d1559")
    panel("panel_red.png", "#2a0d1e", "#ff5a6e", "#5c1024")
    panel("panel_cyan.png", "#0d2a2a", "#7cf6c9", "#1d4a44")
    button("btn.png", "#4a2585", "#2d1559", GOLD, WHITE)
    button("btn_hover.png", "#6a35b0", "#3a1a6e", "#ffe98a", WHITE)
    button("btn_pressed.png", "#2d1559", "#1a0d33", GOLD_D, "#d8cff0")
    button("btn_disabled.png", "#2a2438", "#171220", "#4a4458", "#7a728c")
    card_frame("card.png", "#24104a", "#3a1a6e")
    card_frame("card_sel.png", "#2f1660", GOLD, GOLD)
    card_frame("card_disabled.png", "#1a1228", "#3a3448")
    card_frame("card_red.png", "#2a1020", RED, RED)
    for name, grid in ICON_MAP.items():
        icon(name, grid, ICON_PAL)
    check_icon("check_on", True)
    check_icon("check_off", False)
    for name, grid in AVATARS:
        avatar(name, grid, AVATAR_PAL)
    logo()
    try:
        os.remove(os.path.join(OUT, ".base.png"))
    except FileNotFoundError:
        pass


if __name__ == "__main__":
    main()

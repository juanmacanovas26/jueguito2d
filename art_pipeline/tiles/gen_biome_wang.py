#!/usr/bin/env python3
"""Generates the 4 biome Wang sheets procedurally, in the exact format of
grass_dirt_wang.png (docs/ART.md): 16 tiles of 32x32 in a 4x4 grid with a 1px
transparent gutter, so each sheet is 131x131.

    water_sand_wang.png   0 = all water,  15 = all sand
    sand_grass_wang.png   0 = all sand,   15 = all grass
    stone_grass_wang.png  0 = all stone,  15 = all grass
    mud_grass_wang.png    0 = all mud,    15 = all grass

    index = TL*8 + TR*4 + BL*2 + BR*1   (1 = the second-named terrain)

Grass is copied pixel for pixel from tile #15 of grass_dirt_wang.png, and sand
is the same texture in both sheets that use it, so a pure tile of one sheet
is identical to the pure tile of any other that shares the terrain (Godot
does not blend between terrain sets, so this is what makes them line up).

Why edges always match: every texture, noise field and random choice is
periodic with period 32, and the corner blend ignores the far corners inside
a MARGIN-wide strip along each edge. So the border mask in that strip only
depends on the two corners the neighbouring tile shares, and the outline
effects (which look at most MARGIN pixels away) read the same mask from both
sides. The script checks this on a random map before saving anything.

Usage:
    python art_pipeline/tiles/gen_biome_wang.py [--out DIR] [--preview PNG]
"""
import argparse
import math
import random
import sys
from pathlib import Path

from PIL import Image

T = 32
GUTTER = 1
MARGIN = 3  # also the deepest outline effect, in pixels
ROOT = Path(__file__).resolve().parents[2]
TILES_DIR = ROOT / "game" / "assets" / "tiles"


def hexc(s):
    return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5))


def shade(c, k):
    return tuple(max(0, min(255, round(v * k))) for v in c)


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


# --- periodic helpers ------------------------------------------------------

def periodic_noise(seed, terms, max_freq):
    """Sum of sines with integer frequencies: tiles with period T."""
    rng = random.Random(seed)
    waves = []
    for _ in range(terms):
        fx, fy = 0, 0
        while fx == 0 and fy == 0:
            fx, fy = rng.randint(-max_freq, max_freq), rng.randint(-max_freq, max_freq)
        waves.append((fx, fy, rng.uniform(0, 2 * math.pi), rng.uniform(0.6, 1.0)))
    total = sum(w[3] for w in waves)

    def n(x, y):
        s = sum(a * math.sin(2 * math.pi * (fx * x + fy * y) / T + ph) for fx, fy, ph, a in waves)
        return s / total  # in [-1, 1]
    return n


def random_grid(seed):
    rng = random.Random(seed)
    return [[rng.random() for _ in range(T)] for _ in range(T)]


# --- terrain textures (32x32, tileable) ------------------------------------

def tex_grass():
    sheet = Image.open(TILES_DIR / "grass_dirt_wang.png").convert("RGB")
    cell = sheet.crop((3 * (T + GUTTER), 3 * (T + GUTTER), 3 * (T + GUTTER) + T, 3 * (T + GUTTER) + T))
    return [[cell.getpixel((x, y)) for x in range(T)] for y in range(T)]


SAND = {"base": hexc("#e2c387"), "light": hexc("#f0d9a6"), "dark": hexc("#c9a46c"),
        "pebble": hexc("#a8865a"), "wet": hexc("#c4a06a")}


def tex_sand():
    r = random_grid(101)
    n = periodic_noise(102, 4, 2)
    out = [[SAND["base"]] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            v = r[y][x]
            c = mix(SAND["base"], SAND["dark"], 0.25) if n(x, y) > 0.55 else SAND["base"]
            if v < 0.06:
                c = SAND["light"]
            elif v < 0.11:
                c = SAND["dark"]
            out[y][x] = c
    # a few 2px pebbles with a light top pixel
    rng = random.Random(103)
    for _ in range(3):
        px, py = rng.randrange(T), rng.randrange(T)
        out[py][px] = SAND["pebble"]
        out[py][(px + 1) % T] = SAND["pebble"]
        out[(py - 1) % T][px] = SAND["light"]
    return out


WATER = {"deep": hexc("#3593bb"), "base": hexc("#3a9cc4"), "light": hexc("#6cc2dd"),
         "glint": hexc("#b6e6ef"), "foam": hexc("#eaf7f4")}


def tex_water():
    n = periodic_noise(201, 5, 2)
    out = [[WATER["base"]] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            v = n(x, y)
            out[y][x] = WATER["deep"] if v < -0.65 else WATER["base"]
    # short horizontal wave dashes, light with a glint on the left end
    rng = random.Random(202)
    for _ in range(4):
        px, py, ln = rng.randrange(T), rng.randrange(T), rng.choice((2, 3))
        for i in range(ln):
            out[py][(px + i) % T] = WATER["light"]
        out[py][px] = WATER["glint"]
    return out


STONE = {"base": hexc("#9a958c"), "alt": hexc("#96928a"), "light": hexc("#aca79c"),
         "crack": hexc("#7a756d"), "dark": hexc("#8a857c")}


def tex_stone():
    """Flagstone ground: periodic Voronoi slabs with dark joints and a lit top edge."""
    rng = random.Random(301)
    pts = [(rng.uniform(0, T), rng.uniform(0, T)) for _ in range(5)]
    tones = [rng.choice((STONE["base"], STONE["base"], STONE["alt"])) for _ in pts]
    r = random_grid(302)

    def nearest(x, y):
        ds = []
        for i, (px, py) in enumerate(pts):
            dx = min(abs(x - px), T - abs(x - px))
            dy = min(abs(y - py), T - abs(y - py))
            ds.append((math.hypot(dx, dy), i))
        ds.sort()
        return ds[0][1], ds[1][0] - ds[0][0]

    cellid = [[0] * T for _ in range(T)]
    joint = [[False] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            i, gap = nearest(x + 0.5, y + 0.5)
            cellid[y][x] = i
            joint[y][x] = gap < 0.9
    out = [[STONE["base"]] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            if joint[y][x]:
                c = STONE["crack"]
            elif joint[(y - 1) % T][x]:
                c = STONE["light"]  # lit edge just below a joint
            else:
                c = tones[cellid[y][x]]
                if r[y][x] < 0.05:
                    c = STONE["dark"]
                elif r[y][x] < 0.08:
                    c = STONE["light"]
            out[y][x] = c
    return out


MUD = {"base": hexc("#71503a"), "dark": hexc("#664633"), "light": hexc("#8a6449")}


def tex_mud():
    n = periodic_noise(401, 5, 2)
    r = random_grid(402)
    out = [[MUD["base"]] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            v = n(x, y)
            c = MUD["dark"] if v < -0.6 else MUD["base"]
            if r[y][x] < 0.07:
                c = MUD["light"]
            elif r[y][x] < 0.12:
                c = MUD["dark"]
            out[y][x] = c
    return out


# --- corner blend ------------------------------------------------------------

def make_mask_fn(seed):
    low = periodic_noise(seed, 6, 3)
    high = periodic_noise(seed + 1, 8, 6)

    def ramp(p):
        t = (p + 0.5 - MARGIN) / (T - 2 * MARGIN)
        return min(1.0, max(0.0, t))

    def mask(corners, x, y):
        tl, tr, bl, br = corners
        u, v = ramp(x), ramp(y)
        f = (tl * (1 - u) + tr * u) * (1 - v) + (bl * (1 - u) + br * u) * v
        if tl == br and tr == bl and tl != tr:
            # Diagonal tiles sit on a saddle (f = 0.5 across the middle) and noise
            # alone shreds it into specks; lift the centre so the second-named
            # terrain crosses as one clean band. Zero in the edge strips.
            f += 0.35 * (4 * u * (1 - u)) * (4 * v * (1 - v))
        return f + 0.13 * low(x, y) + 0.04 * high(x, y) > 0.5
    return mask


def corners_of(index):
    return ((index >> 3) & 1, (index >> 2) & 1, (index >> 1) & 1, index & 1)


def upper_grid(mask, corners):
    """Mask over the tile plus a MARGIN-pixel apron, indexed [y+M][x+M]."""
    rng_ = range(-MARGIN, T + MARGIN)
    g = [[mask(corners, x, y) for x in rng_] for y in rng_]
    drop_specks(g)
    return g


def drop_specks(g, min_size=8):
    """Flips tiny islands of either terrain (noise specks around diagonal tiles).
    Only islands that stay clear of the edge strips are touched, so the strips
    the neighbouring tile also computes are never changed."""
    n = len(g)
    lo, hi = 2 * MARGIN, n - 2 * MARGIN  # grid rows/cols outside every edge strip
    seen = [[False] * n for _ in range(n)]
    for sy in range(n):
        for sx in range(n):
            if seen[sy][sx]:
                continue
            val, stack, comp = g[sy][sx], [(sx, sy)], []
            seen[sy][sx] = True
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < n and 0 <= ny < n and not seen[ny][nx] and g[ny][nx] == val:
                        seen[ny][nx] = True
                        stack.append((nx, ny))
            inside = all(lo <= x < hi and lo <= y < hi for x, y in comp)
            if inside and len(comp) < min_size:
                for x, y in comp:
                    g[y][x] = not val


def dist_to_other(g, x, y):
    """Manhattan distance (1..MARGIN) to the nearest pixel of the other terrain, else 0."""
    me = g[y + MARGIN][x + MARGIN]
    for d in range(1, MARGIN + 1):
        for dy in range(-d, d + 1):
            dx = d - abs(dy)
            for sx in ((dx, -dx) if dx else (0,)):
                if g[y + dy + MARGIN][x + sx + MARGIN] != me:
                    return d
    return 0


# --- how each pair draws its border ------------------------------------------

def grass_over(lower_tex, grass_tex, rim_noise):
    rims = (hexc("#426d19"), hexc("#48751d"))

    def px(up, d, x, y):
        if up:
            if d == 1:
                return rims[rim_noise[y][x] < 0.5]
            return grass_tex[y][x]
        base = lower_tex[y][x]
        if d == 1:
            return shade(base, 0.70)
        if d == 2:
            return shade(base, 0.86)
        return base
    return px


def sand_over_water(water_tex, sand_tex, r):
    def px(up, d, x, y):
        if up:
            if d == 1:
                return SAND["wet"]
            if d == 2:
                return mix(SAND["wet"], sand_tex[y][x], 0.5)
            return sand_tex[y][x]
        if d == 1:
            return WATER["foam"] if r[y][x] < 0.8 else WATER["glint"]
        if d == 2:
            return WATER["glint"] if r[y][x] < 0.35 else WATER["light"]
        if d == 3:
            return WATER["light"] if r[y][x] < 0.5 else WATER["base"]
        return water_tex[y][x]
    return px


# --- build -------------------------------------------------------------------

def build_tiles(pixel_fn, seed):
    mask = make_mask_fn(seed)
    tiles, grids = [], []
    for index in range(16):
        g = upper_grid(mask, corners_of(index))
        img = Image.new("RGBA", (T, T))
        for y in range(T):
            for x in range(T):
                up = g[y + MARGIN][x + MARGIN]
                img.putpixel((x, y), pixel_fn(up, dist_to_other(g, x, y), x, y) + (255,))
        tiles.append(img)
        grids.append(g)
    return tiles, grids


def assemble(tiles):
    size = 4 * T + 3 * GUTTER
    sheet = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for i, tile in enumerate(tiles):
        sheet.paste(tile, ((i % 4) * (T + GUTTER), (i // 4) * (T + GUTTER)))
    return sheet


def random_map(tiles, w, h, seed):
    """Lays the tiles out the way Godot's match-corners terrain would."""
    rng = random.Random(seed)
    corner = [[rng.random() < 0.5 for _ in range(w + 1)] for _ in range(h + 1)]
    img = Image.new("RGBA", (w * T, h * T))
    for ty in range(h):
        for tx in range(w):
            i = corner[ty][tx] * 8 + corner[ty][tx + 1] * 4 + corner[ty + 1][tx] * 2 + corner[ty + 1][tx + 1]
            img.paste(tiles[i], (tx * T, ty * T))
    return img


def check_seams(grids):
    """For every pair of tiles that can sit side by side, the strip of mask straddling
    their shared edge (tile pixels plus apron) must be identical from both sides —
    that is what guarantees the borders and their outlines meet. Returns mismatches."""
    M, bad = MARGIN, 0
    span = range(-M, M)
    for a in range(16):
        ca = corners_of(a)
        for b in range(16):
            cb = corners_of(b)
            ga, gb = grids[a], grids[b]
            if (ca[1], ca[3]) == (cb[0], cb[2]):  # a | b
                bad += sum(ga[y + M][T + c + M] != gb[y + M][c + M] for y in range(T) for c in span)
            if (ca[2], ca[3]) == (cb[0], cb[1]):  # a over b
                bad += sum(ga[T + c + M][x + M] != gb[c + M][x + M] for x in range(T) for c in span)
    return bad


PAIRS = [
    ("water_sand_wang.png", "water", "sand", 11),
    ("sand_grass_wang.png", "sand", "grass", 12),
    ("stone_grass_wang.png", "stone", "grass", 13),
    ("mud_grass_wang.png", "mud", "grass", 14),
]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=TILES_DIR)
    ap.add_argument("--preview", type=Path, help="also write a 4-sheet preview with a random map of each")
    args = ap.parse_args()

    tex = {"grass": tex_grass(), "sand": tex_sand(), "water": tex_water(),
           "stone": tex_stone(), "mud": tex_mud()}
    rim_noise = random_grid(500)

    sheets = []
    for name, lower, upper, seed in PAIRS:
        if upper == "grass":
            fn = grass_over(tex[lower], tex["grass"], rim_noise)
        else:
            fn = sand_over_water(tex["water"], tex["sand"], random_grid(501))
        tiles, grids = build_tiles(fn, seed)
        bad = check_seams(grids)
        if bad:
            print(f"error: {name} has {bad} border pixels that do not line up", file=sys.stderr)
            return 1
        sheets.append((name, tiles))

    args.out.mkdir(parents=True, exist_ok=True)
    for name, tiles in sheets:
        assemble(tiles).save(args.out / name)
        print(f"wrote {args.out / name}")

    if args.preview:
        scale, mw, mh = 2, 10, 6
        cols = []
        for name, tiles in sheets:
            sheet = assemble(tiles).resize((131 * scale, 131 * scale), Image.NEAREST)
            world = random_map(tiles, mw, mh, 7).resize((mw * T * scale, mh * T * scale), Image.NEAREST)
            col = Image.new("RGBA", (sheet.width + 16 + world.width, world.height), (40, 40, 46, 255))
            col.alpha_composite(sheet, (0, 0))
            col.paste(world, (sheet.width + 16, 0))
            cols.append(col)
        prev = Image.new("RGBA", (cols[0].width, sum(c.height + 16 for c in cols)), (40, 40, 46, 255))
        y = 0
        for c in cols:
            prev.paste(c, (0, y))
            y += c.height + 16
        prev.save(args.preview)
        print(f"wrote {args.preview}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

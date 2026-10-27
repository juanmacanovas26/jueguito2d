"""Renderiza las ilustraciones de docs/ZONA_INICIAL.md con el arte real del mapeador.

Uso: python3 art_pipeline/zona_inicial/render_zona.py . docs/img/zona_inicial
Reproduce el autotile Wang de BiomeTileset (scripts/world/biome_tileset.gd) y el
vallado de FenceAutotiler, y dibuja todo con orden por Y (como haría el juego con
Y-sort).
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(sys.argv[1])
OUT = Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)
A = REPO / "game/assets"
T = 32
W_T, H_T = 104, 80
W, H = W_T * T, H_T * T

FONT_B = "/usr/share/fonts/opentype/inter/Inter-Bold.otf"
FONT_S = "/usr/share/fonts/opentype/inter/Inter-SemiBold.otf"
FONT_R = "/usr/share/fonts/opentype/inter/Inter-Regular.otf"


def font(path, size):
    return ImageFont.truetype(path, size)


_cache = {}


def img(rel):
    if rel not in _cache:
        _cache[rel] = Image.open(A / rel).convert("RGBA")
    return _cache[rel]


def scaled(im, s):
    if s == 1:
        return im
    return im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.NEAREST)


def hue_shift(im, deg, sat=1.0, val=1.0):
    alpha = im.split()[3]
    hsv = im.convert("RGB").convert("HSV")
    h, s, v = hsv.split()
    h = h.point(lambda x: (x + int(deg / 360 * 255)) % 256)
    s = s.point(lambda x: min(255, int(x * sat)))
    v = v.point(lambda x: min(255, int(x * val)))
    out = Image.merge("HSV", (h, s, v)).convert("RGBA")
    out.putalpha(alpha)
    return out


# --------------------------------------------------------------------------
# Terreno: port directo de BiomeTileset.resolve()
# --------------------------------------------------------------------------
PRIORITY = {"agua": 4, "arena": 3, "piedra": 2, "barro": 1, "pasto": 0}
SHEETS = {
    "water_sand": ["agua", "arena"],
    "sand_grass": ["arena", "pasto"],
    "stone_grass": ["piedra", "pasto"],
    "mud_grass": ["barro", "pasto"],
}
PURE = {
    "agua": ["water_sand", 0],
    "arena": ["water_sand", 15],
    "piedra": ["stone_grass", 0],
    "barro": ["mud_grass", 0],
    "pasto": ["sand_grass", 15],
}


def sheet_for(a, b):
    for sh, pair in SHEETS.items():
        if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
            return sh
    return ""


def vertex(p, c):
    around = []
    for o in [(-1, -1), (0, -1), (-1, 0), (0, 0)]:
        t = p.get((c[0] + o[0], c[1] + o[1]), "pasto")
        if t not in around:
            around.append(t)
    around.sort(key=lambda t: -PRIORITY[t])
    for t in around:
        if all(o == t or sheet_for(t, o) for o in around):
            return t
    return around[0]


def index(sh, corners):
    upper = SHEETS[sh][1]
    i = 0
    for k in range(4):
        if corners[k] == upper:
            i |= 8 >> k
    return i


def pick(own, corners):
    distinct = []
    for t in corners:
        if t not in distinct:
            distinct.append(t)
    if len(distinct) == 1:
        return PURE[distinct[0]]
    if len(distinct) == 2:
        sh = sheet_for(*distinct)
        if sh:
            return [sh, index(sh, corners)]
    distinct.sort(key=lambda t: -PRIORITY[t])
    for other in distinct:
        if other == own:
            continue
        sh = sheet_for(own, other)
        if not sh:
            continue
        return [sh, index(sh, [other if t == other else own for t in corners])]
    return PURE[own]


def resolve(p):
    todo = set()
    for c in p:
        todo.add(c)
        if p[c] != "pasto":
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    todo.add((c[0] + dx, c[1] + dy))
    out = {}
    for c in todo:
        own = p.get(c, "pasto")
        corners = [vertex(p, c), vertex(p, (c[0] + 1, c[1])), vertex(p, (c[0], c[1] + 1)), vertex(p, (c[0] + 1, c[1] + 1))]
        pk = pick(own, corners)
        if c not in p and pk == PURE["pasto"]:
            continue
        out[c] = pk
    return out


def wang_tile(sheet, i):
    im = img(f"tiles/{sheet}_wang.png")
    x, y = (i % 4) * 33, (i // 4) * 33
    return im.crop((x, y, x + 32, y + 32))


# --------------------------------------------------------------------------
# Diseño de la zona (en tiles)
# --------------------------------------------------------------------------
rng = random.Random(7)
painted = {}


def paint(c, t):
    if 0 <= c[0] < W_T and 0 <= c[1] < H_T:
        painted[c] = t


def blob(cx, cy, rx, ry, t, wobble=0.18, seed=1):
    r = random.Random(seed)
    ph = [r.uniform(0, 6.28) for _ in range(3)]
    for y in range(int(cy - ry - 3), int(cy + ry + 4)):
        for x in range(int(cx - rx - 3), int(cx + rx + 4)):
            ang = math.atan2(y - cy, x - cx)
            k = 1 + wobble * (math.sin(3 * ang + ph[0]) * 0.5 + math.sin(5 * ang + ph[1]) * 0.3 + math.sin(2 * ang + ph[2]) * 0.4)
            if ((x - cx) / (rx * k)) ** 2 + ((y - cy) / (ry * k)) ** 2 <= 1:
                paint((x, y), t)


def rect(x0, y0, x1, y1, t):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            paint((x, y), t)


def path(pts, w, t):
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        steps = int(max(abs(bx - ax), abs(by - ay)) * 3) + 1
        for s in range(steps + 1):
            px = ax + (bx - ax) * s / steps
            py = ay + (by - ay) * s / steps
            for y in range(int(py - w), int(py + w) + 1):
                for x in range(int(px - w), int(px + w) + 1):
                    if (x + 0.5 - px) ** 2 + (y + 0.5 - py) ** 2 <= w * w:
                        paint((x, y), t)


# Town box (fence) in tiles
TX0, TY0, TX1, TY1 = 27, 29, 75, 69
GATE_N = range(55, 59)
GATE_S = range(49, 53)
GATE_W = range(50, 54)
GATE_E = range(50, 54)

# Biomas grandes
blob(13, 27, 12, 14, "piedra", seed=3)                  # Cantera Vieja
blob(91, 15, 12, 12, "barro", seed=5)                   # Hondonada
blob(96, 58, 11, 15, "arena", wobble=0.12, seed=9)      # orilla del lago
blob(97, 58, 8, 12, "agua", wobble=0.12, seed=9)        # lago
blob(14, 63, 5, 4, "arena", seed=11)                    # estanque de los campos
blob(14, 63, 3, 2.5, "agua", seed=11)

# Plaza y caminos
rect(42, 48, 63, 59, "piedra")
path([(56, 48), (56, 29), (56, 22), (52, 14), (50, 6)], 1.5, "barro")      # norte -> bosque
path([(51, 59), (51, 69), (51, 79)], 1.5, "barro")                           # sur -> campos
path([(42, 52), (27, 52), (21, 45), (15, 36)], 1.5, "barro")                 # oeste -> cantera
path([(63, 52), (75, 52), (80, 45), (85, 33), (88, 24)], 1.5, "barro")      # este -> hondonada
path([(80, 45), (84, 54), (86, 57)], 1.2, "barro")                           # -> muelle

# Overlays para las etiquetas (en tiles): nombre, caja, color
REGIONS = [
    ("1", "Pueblo del Alba", "zona segura", (TX0 - 0.5, TY0 - 0.5, TX1 + 1.5, TY1 + 1.5), (255, 236, 160)),
    ("2", "Campos del Alba", "anillo 1 · 0–15 pts", (2, 56, 26, 79), (170, 235, 120)),
    ("2", "Campos del Alba", "anillo 1 · 0–15 pts", (28, 71, 80, 79), (170, 235, 120)),
    ("3", "Bosque Susurrante", "anillo 2 · 15–40 pts", (29, 1, 77, 27), (110, 210, 200)),
    ("4", "Cantera Vieja", "anillo 2 · 15–40 pts", (1, 12, 26, 44), (190, 200, 215)),
    ("5", "Hondonada del Rey Slime", "anillo 3 · 40+ pts", (78, 2, 103, 29), (235, 140, 220)),
    ("6", "Lago y muelle", "futuro: pesca", (82, 42, 103, 76), (130, 190, 255)),
]

# --------------------------------------------------------------------------
# Objetos (todos anclados abajo-al-centro, en píxeles)
# --------------------------------------------------------------------------
objs = []  # (y_sort, x, y, image, tag)


def put(rel_or_im, tx, ty, s=1.0, tag=None, shadow=False, jitter=0):
    im = rel_or_im if isinstance(rel_or_im, Image.Image) else img(rel_or_im)
    im = scaled(im, s)
    x = tx * T + (rng.uniform(-jitter, jitter) if jitter else 0)
    y = ty * T + (rng.uniform(-jitter, jitter) if jitter else 0)
    objs.append((y, x, y, im, tag, shadow))


B = "world/buildings/"
D = "world/decor/plains/"
M = "world/decor/megapack/"

# --- Pueblo -----------------------------------------------------------------
put(B + "inn.png", 36.5, 47, tag="Posada · respawn y guardado")
put(B + "general_goods.png", 68.5, 46, tag="Tienda · vendedor")
put(B + "blacksmith_n.png", 32, 60, tag="Herrería · estación de craft (provisoria)")
put(M + "anvil_horn_block.png", 36.3, 60.2)
put(M + "quench_barrel_steam.png", 28.6, 60.5)
put(M + "firewood_pile_stacked.png", 35.8, 57.2)
put(B + "house_small_a.png", 37, 68, tag="Tu casa · se puede entrar")
put(B + "house_small_c.png", 43, 68)
put(B + "house_small_d.png", 61, 68)
put(B + "house_small_e.png", 67, 68)
put(B + "house_small_f.png", 72.3, 63.5)
put(B + "market_produce.png", 46, 58.6, tag="Puestos (provisorios)")
put(B + "market_spices.png", 59, 58.6)
put(D + "well.png", 52.5, 54)
put(M + "quest_board_parchment_blank.png", 47.5, 51.6, tag="Tablón de encargos")
put(M + "notice_board_standing.png", 60.3, 51)
for lx, ly in [(42.2, 48.6), (63.6, 48.6), (42.2, 59.8), (63.6, 59.8), (54.2, 30.5), (58.0, 30.5), (49.5, 68.4), (53.4, 68.4)]:
    put(M + "lantern_post_iron.png", lx, ly)
put(D + "bench.png", 50, 50.3)
put(D + "bench.png", 55, 50.3)
for x, y in [(66, 47), (66.9, 47.3), (71.4, 47.1)]:
    put(D + "barrel.png", x, y)
put(D + "crate.png", 72.3, 47.4)
put(M + "garden_plot_vegetables.png", 40, 69.6)
put(M + "garden_plot_vegetables.png", 64, 69.6)
put(M + "flower_patch_wild.png", 46.2, 64.8)
put(M + "flower_patch_wild.png", 57, 64.8)
put(M + "clothesline_posts.png", 64.5, 64.5)
put(M + "chicken_coop_wooden.png", 45.5, 63.2)
put(M + "wheelbarrow_wooden.png", 41.5, 57.5)
put(D + "wagon.png", 69, 56.5)
put(M + "signpost_wooden_blank.png", 25.3, 50.6)
put(M + "signpost_wooden_blank.png", 77, 50.6)
put(M + "signpost_wooden_blank.png", 54.5, 27.6)

# Patio de entrenamiento
for x, y in [(60.5, 34.5), (63.5, 34.5), (66.5, 34.5)]:
    put(M + "armor_stand_breastplate.png", x, y)
put(M + "weapon_rack_swords.png", 60, 31.6)
put(M + "weapon_rack_polearms.png", 64.5, 31.6)
put(M + "shield_stack_leaning.png", 67.6, 31.8)
put(M + "scarecrow_cross_frame.png", 69.5, 34.5)

# --- Mobs -------------------------------------------------------------------
SLIME = img("mobs/slime/idle.png")
MOB = {
    "debil": SLIME,
    "medio": hue_shift(SLIME, 95, 1.05, 1.0),
    "rango": hue_shift(SLIME, -95, 1.2, 1.05),
    "fuerte": hue_shift(SLIME, 160, 1.1, 0.85),
}
BOSS = scaled(hue_shift(SLIME, 160, 1.25, 0.8), 2.6)


def mob(kind, tx, ty, s=1.4):
    put(MOB[kind], tx, ty, s=s, shadow=True)


def pack(kind, cx, cy, n, spread=2.2, s=1.4):
    for _ in range(n):
        mob(kind, cx + rng.uniform(-spread, spread), cy + rng.uniform(-spread * 0.7, spread * 0.7), s)


# anillo 1
for c in [(10, 74, 2), (20, 76, 2), (36, 75, 3), (62, 75, 3), (74, 75, 2), (6, 52, 2)]:
    pack("debil", *c)
# anillo 2: bosque y cantera
for c in [(40, 20, 3), (64, 18, 3), (46, 9, 2), (68, 7, 2)]:
    pack("medio", *c)
for c in [(58, 12, 2), (34, 10, 1)]:
    pack("rango", *c)
for c in [(9, 22, 2), (18, 31, 2)]:
    pack("medio", *c)
for c in [(7, 36, 2), (20, 18, 1)]:
    pack("rango", *c)
# anillo 3
for c in [(84, 21, 3), (97, 22, 2), (83, 8, 2)]:
    pack("fuerte", *c, s=1.5)
put(BOSS, 92, 12.5, shadow=True, tag="Rey Slime · mini-jefe")

# --- Recursos ---------------------------------------------------------------
def res(kind, tx, ty, s=None):
    sizes = {"tree": 0.62, "rock": 0.55, "vein": 0.6}
    put(f"world/{kind}.png", tx, ty, s=s or sizes[kind], shadow=True)


for tx, ty in [(4, 66), (8, 69), (22, 69), (25, 74), (31, 77), (44, 76), (57, 77), (69, 77), (79, 70), (3, 58)]:
    res("tree" if rng.random() < 0.6 else "rock", tx, ty)
for tx, ty in [(37, 16), (44, 23), (61, 23), (70, 14), (39, 5), (63, 4), (50, 19), (72, 22)]:
    res("tree", tx, ty)
for tx, ty in [(5, 18), (12, 15), (21, 24), (6, 30), (16, 38), (22, 33), (11, 41)]:
    res("rock", tx, ty)
VEINS = [(9, 26), (14, 21), (17, 28), (5, 34), (13, 33)]
for tx, ty in VEINS:
    res("vein", tx, ty)

# --- Decor de exterior ------------------------------------------------------
# Bosque: borde denso de árboles decorativos (no talables) dejando claros.
clear_spots = [(40, 20, 4), (64, 18, 4), (46, 9, 3), (68, 7, 3), (58, 12, 3), (34, 10, 3), (52, 15, 3)]
for _ in range(330):
    tx, ty = rng.uniform(29, 78), rng.uniform(0.5, 27)
    if any((tx - cx) ** 2 + (ty - cy) ** 2 < r * r for cx, cy, r in clear_spots):
        continue
    if painted.get((int(tx), int(ty))) == "barro" or painted.get((int(tx), int(ty) + 1)) == "barro":
        continue
    if tx > 77 and ty < 28:
        continue
    k = rng.random()
    if k < 0.45:
        put(D + "tree_pine.png", tx, ty, shadow=True)
    elif k < 0.8:
        put(D + "tree_oak.png", tx, ty, shadow=True)
    else:
        put(D + "tree_round.png", tx, ty, shadow=True)
for _ in range(60):
    tx, ty = rng.uniform(30, 77), rng.uniform(1, 27)
    put(rng.choice([D + "mushrooms_red.png", D + "mushrooms_brown.png", D + "bush_fern.png", D + "grass_tall.png", D + "log_fallen.png", D + "stump.png"]), tx, ty)

# Cantera
for _ in range(14):
    tx, ty = rng.uniform(3, 23), rng.uniform(15, 42)
    if painted.get((int(tx), int(ty))) == "piedra":
        put(rng.choice([D + "rock_mossy.png", M + "boulder_moss_large.png", M + "rock_group_small.png", M + "stone_pile_field.png"]), tx, ty, shadow=True)
put(M + "coal_pile_shovel.png", 19, 20)
put(M + "handcart_single_axle.png", 22.5, 28.5)
put(D + "tent.png", 4.5, 42)

# Hondonada
put(D + "tent.png", 85.5, 13, tag=None)
put(D + "tent.png", 98, 10)
put(D + "campfire.png", 90, 18)
put(D + "cauldron.png", 92, 18.4)
put(D + "sign_skull.png", 86.6, 27)
put(D + "sign_skull.png", 79.5, 17)
put(M + "treasure_chest_closed.png", 95.5, 13.5, tag="Cofre del jefe")
put(M + "cage_iron_hanging.png", 81.5, 11)
put(M + "weapon_rack_swords.png", 88, 7)
put(M + "banner_pole_pennant.png", 89.5, 9.5)
put(M + "crate_weapons_open.png", 99, 17)
put(D + "barrel.png", 97.6, 17.2)
put(M + "stew_pot_hanging.png", 93.8, 18.6)
put(M + "firewood_pile_stacked.png", 87.6, 18.6)
for _ in range(16):
    tx, ty = rng.uniform(79, 103), rng.uniform(1, 28)
    if painted.get((int(tx), int(ty))) != "barro":
        put(rng.choice([D + "tree_pine.png", D + "stump.png", D + "log_fallen.png"]), tx, ty, shadow=True)

# Campos: trigo vallado, fardos, espantapájaros, estanque
for gx in range(5, 21):
    for gy in range(70, 78):
        if (gx + gy) % 1 == 0 and rng.random() < 0.85:
            put(D + "wheat.png", gx + 0.5 + rng.uniform(-0.2, 0.2), gy + 0.9)
put(M + "scarecrow_cross_frame.png", 13, 74)
for tx, ty in [(23, 61), (24, 62.5), (78, 66)]:
    put(D + "hay_bale.png", tx, ty)
put(M + "hay_cart_two_wheel.png", 25, 66)
put(D + "lilypad.png", 14, 63.2)
for _ in range(70):
    tx, ty = rng.uniform(1, 103), rng.uniform(28, 79)
    if TX0 - 1 < tx < TX1 + 1 and TY0 - 1 < ty < TY1 + 1:
        continue
    if painted.get((int(tx), int(ty))) in ("agua", "arena", "barro", "piedra"):
        continue
    put(rng.choice([D + "bush.png", D + "bush_berry.png", D + "grass_tuft.png", D + "grass_tall.png", D + "grass_tuft_b.png", D + "mushrooms_yellow.png"]), tx, ty)

# Lago
put(B + "dock.png", 87.5, 58.3, tag="Muelle (provisorio)")
put(D + "lilypad.png", 98, 50)
put(D + "lilypad.png", 95, 66)

# --------------------------------------------------------------------------
# Vallas (FenceAutotiler: N=1, E=2, W=4; el atlas es el bitmask)
# --------------------------------------------------------------------------
fence = set()
for x in range(TX0, TX1 + 1):
    if x not in GATE_N:
        fence.add((x, TY0))
    if x not in GATE_S:
        fence.add((x, TY1))
for y in range(TY0, TY1 + 1):
    if y not in GATE_W:
        fence.add((TX0, y))
    if y not in GATE_E:
        fence.add((TX1, y))
# corral del trigo
for x in range(4, 22):
    fence.add((x, 69))
    if x not in (12, 13):
        fence.add((x, 78))
for y in range(69, 79):
    fence.add((4, y))
    fence.add((21, y))
FENCE = img("world/fences/wood.png")
for (x, y) in fence:
    m = (1 if (x, y - 1) in fence else 0) | (2 if (x + 1, y) in fence else 0) | (4 if (x - 1, y) in fence else 0)
    tile = FENCE.crop((m * 32, 0, m * 32 + 32, 32))
    objs.append(((y + 1) * T - 1, x * T + 16, (y + 1) * T, tile, None, False))

# --------------------------------------------------------------------------
# Render
# --------------------------------------------------------------------------
def render_ground():
    g = Image.new("RGBA", (W, H))
    grass = [img("tiles/grass_01.png"), img("tiles/grass_02.png"), img("tiles/grass_03.png")]
    r = random.Random(1337)
    for ty in range(H_T):
        for tx in range(W_T):
            roll = r.random()
            g.paste(grass[2] if roll < 0.08 else grass[1] if roll < 0.22 else grass[0], (tx * T, ty * T))
    for (x, y), (sh, i) in resolve(painted).items():
        if 0 <= x < W_T and 0 <= y < H_T:
            g.alpha_composite(wang_tile(sh, i), (x * T, y * T))
    return g


def render_objects(base):
    shadow_layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow_layer)
    for _, x, y, im, _, shadow in objs:
        if shadow:
            w = im.width * 0.42
            sd.ellipse((x - w, y - w * 0.28, x + w, y + w * 0.22), fill=(10, 30, 10, 85))
    base.alpha_composite(shadow_layer.filter(ImageFilter.GaussianBlur(2)))
    for _, x, y, im, _, _ in sorted(objs, key=lambda o: (o[0], o[1])):
        base.alpha_composite(im, (int(x - im.width / 2), int(y - im.height)))
    return base


MAP = render_objects(render_ground())
MAP.convert("RGB").save(OUT / "00_mapa_completo.png", optimize=True)
print("map rendered")


# --------------------------------------------------------------------------
# Lámina 1: vista general anotada
# --------------------------------------------------------------------------
def pill(d, xy, text, fnt, fg=(255, 255, 255), bg=(20, 22, 30, 215), pad=(10, 5), anchor="mm"):
    bbox = d.textbbox(xy, text, font=fnt, anchor=anchor)
    d.rounded_rectangle((bbox[0] - pad[0], bbox[1] - pad[1], bbox[2] + pad[0], bbox[3] + pad[1]), radius=8, fill=bg)
    d.text(xy, text, font=fnt, fill=fg, anchor=anchor)


def overview():
    S = 0.5
    ov = MAP.resize((int(W * S), int(H * S)), Image.LANCZOS).convert("RGBA")
    lay = Image.new("RGBA", ov.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for num, name, sub, (x0, y0, x1, y1), col in REGIONS:
        box = (x0 * T * S, y0 * T * S, x1 * T * S, y1 * T * S)
        d.rounded_rectangle(box, radius=18, fill=col + (30,))
    o2 = Image.new("RGBA", ov.size, (0, 0, 0, 0))
    d2 = ImageDraw.Draw(o2)
    for num, name, sub, (x0, y0, x1, y1), col in REGIONS:
        box = (x0 * T * S, y0 * T * S, x1 * T * S, y1 * T * S)
        d2.rounded_rectangle(box, radius=18, outline=col + (220,), width=4)
    lay.alpha_composite(o2)
    d = ImageDraw.Draw(lay)
    arrows = [((51, 70), (51, 75)), ((56, 29), (54, 21)), ((27, 52), (19, 41)), ((75, 52), (84, 31))]
    for (ax, ay), (bx, by) in arrows:
        a = (ax * T * S, ay * T * S)
        b = (bx * T * S, by * T * S)
        d.line([a, b], fill=(255, 255, 255, 230), width=6)
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        L = 20
        d.polygon([b, (b[0] - L * math.cos(ang - 0.45), b[1] - L * math.sin(ang - 0.45)), (b[0] - L * math.cos(ang + 0.45), b[1] - L * math.sin(ang + 0.45))], fill=(255, 255, 255, 240))
    seen = set()
    for num, name, sub, (x0, y0, x1, y1), col in REGIONS:
        if name in seen:
            continue
        seen.add(name)
        box = (x0 * T * S, y0 * T * S, x1 * T * S, y1 * T * S)
        cx, cy = (box[0] + box[2]) / 2, box[1] + 30
        if num == "1":
            cx, cy = 46 * T * S, 32 * T * S
        if num == "2":
            cx, cy = box[0] + 170, box[1] + 30
        pill(d, (cx, cy), f"{num}  {name}", font(FONT_B, 24), bg=(18, 20, 28, 225))
        pill(d, (cx, cy + 32), sub, font(FONT_S, 17), fg=col, bg=(18, 20, 28, 200), pad=(8, 3))
    ov.alpha_composite(lay)
    # título
    hd = Image.new("RGBA", (ov.width, 96), (18, 20, 28, 255))
    hdd = ImageDraw.Draw(hd)
    hdd.text((28, 20), "Praderas del Alba — zona inicial", font=font(FONT_B, 34), fill=(255, 244, 214))
    hdd.text((28, 62), "104 × 80 tiles (3328 × 2560 px) · norte arriba · las flechas marcan el recorrido esperado", font=font(FONT_R, 18), fill=(190, 196, 210))
    full = Image.new("RGBA", (ov.width, ov.height + 96))
    full.paste(hd, (0, 0))
    full.paste(ov, (0, 96))
    full.convert("RGB").save(OUT / "01_vista_general.png", optimize=True)


overview()


# --------------------------------------------------------------------------
# Láminas de detalle (recortes a 2x, con callouts)
# --------------------------------------------------------------------------
def detail(name, title, sub, box_t, callouts, scale=2):
    x0, y0, x1, y1 = [v * T for v in box_t]
    crop = MAP.crop((x0, y0, x1, y1)).convert("RGBA")
    crop = crop.resize((crop.width * scale, crop.height * scale), Image.NEAREST)
    u = crop.width / 1700
    lay = Image.new("RGBA", crop.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    r = 20 * u
    for i, (tx, ty, text) in enumerate(callouts, 1):
        px, py = (tx * T - x0) * scale, (ty * T - y0) * scale
        qx, qy = px + 34 * u, py - 34 * u
        d.line([(px, py), (qx, qy)], fill=(255, 214, 90, 255), width=max(2, int(4 * u)))
        d.ellipse((px - 6 * u, py - 6 * u, px + 6 * u, py + 6 * u), fill=(255, 214, 90, 255))
        d.ellipse((qx - r, qy - r, qx + r, qy + r), fill=(255, 214, 90, 250), outline=(30, 20, 0, 255), width=max(2, int(3 * u)))
        d.text((qx, qy), str(i), font=font(FONT_B, int(24 * u)), fill=(30, 20, 0), anchor="mm")
    crop.alpha_composite(lay)
    lf = font(FONT_S, int(24 * u))
    rows = math.ceil(len(callouts) / 2)
    row_h = int(42 * u)
    leg_h = int(36 * u) + rows * row_h
    hd_h = int(110 * u)
    full = Image.new("RGBA", (crop.width, crop.height + hd_h + leg_h), (18, 20, 28, 255))
    full.paste(crop, (0, hd_h))
    d = ImageDraw.Draw(full)
    d.text((28 * u, 18 * u), title, font=font(FONT_B, int(38 * u)), fill=(255, 244, 214))
    d.text((28 * u, 68 * u), sub, font=font(FONT_R, int(22 * u)), fill=(190, 196, 210))
    colw = crop.width // 2
    for i, (_, _, text) in enumerate(callouts, 1):
        cx = 28 * u + ((i - 1) % 2) * colw
        cy = crop.height + hd_h + 22 * u + ((i - 1) // 2) * row_h
        d.ellipse((cx, cy, cx + 30 * u, cy + 30 * u), fill=(255, 214, 90))
        d.text((cx + 15 * u, cy + 15 * u), str(i), font=font(FONT_B, int(18 * u)), fill=(30, 20, 0), anchor="mm")
        d.text((cx + 44 * u, cy + 15 * u), text, font=lf, fill=(232, 234, 240), anchor="lm")
    full.convert("RGB").save(OUT / name, optimize=True)


detail(
    "02_pueblo.png", "1 · Pueblo del Alba (zona segura)",
    "Todo lo que el jugador necesita entre salida y salida, a menos de 15 segundos caminando de la plaza",
    (25, 28, 78, 72),
    [
        (36.5, 46.5, "Posada: respawn y punto de guardado"),
        (68.5, 45.5, "Tienda: comprar pociones / vender loot"),
        (32, 59.5, "Herrería: craftear y mejorar (arte provisorio)"),
        (37, 67.5, "Tu casa: única con puerta e interior"),
        (47.5, 51, "Tablón de encargos (primer NPC de quests)"),
        (52.5, 53.5, "Pozo: centro de la plaza, punto de reunión"),
        (52.5, 58, "Puestos de mercado (arte provisorio)"),
        (63.5, 34, "Patio de entrenamiento: muñecos (no dan skill)"),
        (57, 29, "Portón norte → Bosque Susurrante"),
        (27, 52, "Portón oeste → Cantera Vieja"),
        (75, 52, "Portón este → Hondonada y lago"),
    ],
)
detail(
    "03_campos.png", "2 · Campos del Alba (anillo 1)",
    "Slimes verdes sueltos, árboles y rocas: el primer arma, la primera poción y el primer descubrimiento",
    (0, 55, 54, 80),
    [
        (13, 73.5, "Trigal vallado con espantapájaros (decorado)"),
        (14, 63, "Estanque: referencia visual, sin uso todavía"),
        (10, 74, "Slimes verdes en pares: pegan poco, mueren rápido"),
        (8, 69, "Árboles y rocas talables junto al pueblo"),
        (25, 66, "Fardos y carro: marcan el borde del pueblo"),
        (51, 76, "Camino sur, sale del portón sur"),
    ],
)
detail(
    "04_bosque_cantera.png", "3 + 4 · Bosque Susurrante y Cantera Vieja (anillo 2)",
    "Dos zonas al mismo nivel que entrenan cosas distintas: el bosque, combate en claros; la cantera, minería con presión",
    (0, 0, 79, 46),
    [
        (40, 20, "Claro con slimes azules (melee, más vida)"),
        (58, 12, "Slimes rojos a distancia: obligan a esquivar"),
        (50, 19, "Árboles talables dentro del bosque"),
        (9, 26, "Venas de hierro inmortales (auto-farm con G)"),
        (7, 36, "Slime rojo cuidando las venas"),
        (4.5, 41.5, "Campamento minero (decorado)"),
        (54.5, 27, "Cartel: el camino norte entra al bosque"),
        (19, 41, "El camino oeste llega a la cantera"),
    ],
    scale=1,
)
detail(
    "05_hondonada.png", "5 · Hondonada del Rey Slime (anillo 3)",
    "Barro, campamento abandonado y packs de slimes violetas; el jefe custodia un cofre",
    (76, 0, 104, 30),
    [
        (92, 12, "Rey Slime: mini-jefe con 2–3 patrones"),
        (95.5, 13, "Cofre: loot garantizado la primera vez"),
        (84, 21, "Pack de 3 slimes violetas (pegan fuerte)"),
        (86.6, 26.5, "Carteles de calavera: aviso de peligro"),
        (90, 17.5, "Fogata: punto de descanso antes del jefe"),
    ],
)


# --------------------------------------------------------------------------
# Leyenda de enemigos
# --------------------------------------------------------------------------
def legend():
    entries = [
        (MOB["debil"], "Slime verde", "anillo 1", "hp 40 · daño 6 · skill_gain 10"),
        (MOB["medio"], "Slime azul", "anillo 2", "hp 90 · daño 12 · skill_gain 18"),
        (MOB["rango"], "Slime rojo (a distancia)", "anillo 2", "hp 60 · proyectil 12 · rango 200"),
        (MOB["fuerte"], "Slime violeta", "anillo 3", "hp 160 · daño 20 · skill_gain 28"),
        (hue_shift(SLIME, 160, 1.25, 0.8), "Rey Slime", "mini-jefe", "hp 900 · patrones con telegraph"),
    ]
    Wd, rowh = 1500, 120
    im = Image.new("RGBA", (Wd, 90 + rowh * len(entries)), (18, 20, 28, 255))
    d = ImageDraw.Draw(im)
    d.text((28, 22), "Enemigos de la zona (valores iniciales para calibrar)", font=font(FONT_B, 30), fill=(255, 244, 214))
    for i, (sp, name, ring, stats) in enumerate(entries):
        y = 90 + i * rowh
        if i % 2 == 0:
            d.rectangle((0, y, Wd, y + rowh), fill=(26, 29, 40, 255))
        s = scaled(sp, 3)
        im.alpha_composite(s, (60 + (96 - s.width) // 2, y + (rowh - s.height) // 2))
        d.text((200, y + 30), name, font=font(FONT_B, 26), fill=(240, 240, 245))
        d.text((200, y + 70), ring, font=font(FONT_S, 19), fill=(160, 200, 255))
        d.text((640, y + rowh / 2), stats, font=font(FONT_R, 24), fill=(205, 210, 222), anchor="lm")
    im.convert("RGB").save(OUT / "06_enemigos.png", optimize=True)


legend()
print("done")


# --------------------------------------------------------------------------
# Láminas técnicas: Y-sort y hitbox de la casa
# --------------------------------------------------------------------------
LPC = "lpc/spritesheets/"
LAYERS = ["body/bodies/male", "feet/shoes/basic/male", "legs/pants/male",
          "torso/clothes/longsleeve/longsleeve/male", "head/heads/human/male", "hair/bedhead/adult"]


def character(row=2):
    out = Image.new("RGBA", (64, 64))
    for l in LAYERS:
        out.alpha_composite(img(f"{LPC}{l}/idle.png").crop((0, row * 64, 64, row * 64 + 64)))
    return out.crop(out.getbbox())


HERO = character(2)
HERO_BACK = character(0)


def tiny_ground(w, h):
    g = Image.new("RGBA", (w, h))
    grass = [img("tiles/grass_01.png"), img("tiles/grass_02.png"), img("tiles/grass_03.png")]
    r = random.Random(5)
    for y in range(0, h, 32):
        for x in range(0, w, 32):
            k = r.random()
            g.paste(grass[2] if k < 0.08 else grass[1] if k < 0.22 else grass[0], (x, y))
    return g


def draw_items(base, items):
    """items: (sort_key, x, y_bottom, image, alpha)"""
    for _, x, y, im, alpha in sorted(items, key=lambda i: i[0]):
        if alpha < 1:
            im = im.copy()
            im.putalpha(im.split()[3].point(lambda a: int(a * alpha)))
        base.alpha_composite(im, (int(x - im.width / 2), int(y - im.height)))


def badge(d, xy, ok, text, u):
    x, y = xy
    col = (90, 200, 120) if ok else (235, 85, 85)
    d.ellipse((x - 22 * u, y - 22 * u, x + 22 * u, y + 22 * u), fill=col, outline=(20, 20, 20), width=int(3 * u))
    d.text((x, y), "✓" if ok else "✗", font=font("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", int(28 * u)), fill="white", anchor="mm")
    f = font(FONT_S, int(21 * u))
    bb = d.textbbox((x + 34 * u, y), text, font=f, anchor="lm")
    d.rounded_rectangle((bb[0] - 10 * u, bb[1] - 7 * u, bb[2] + 10 * u, bb[3] + 7 * u), radius=int(8 * u), fill=(18, 20, 28, 225))
    d.text((x + 34 * u, y), text, font=f, fill=(240, 240, 245), anchor="lm")


def panels(name, title, sub, pans, sc=3):
    ims = []
    for ptitle, pim, notes in pans:
        big = scaled(pim, sc).convert("RGBA")
        lay = Image.new("RGBA", big.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        for fn in notes:
            fn(d, sc)
        big.alpha_composite(lay)
        head = Image.new("RGBA", (big.width, 64), (30, 33, 46, 255))
        ImageDraw.Draw(head).text((22, 32), ptitle, font=font(FONT_B, 28), fill=(255, 244, 214), anchor="lm")
        col = Image.new("RGBA", (big.width, big.height + 64))
        col.paste(head, (0, 0))
        col.paste(big, (0, 64))
        ims.append(col)
    gap = 24
    wtot = sum(i.width for i in ims) + gap * (len(ims) + 1)
    htot = max(i.height for i in ims) + 120 + gap
    full = Image.new("RGBA", (wtot, htot), (18, 20, 28, 255))
    d = ImageDraw.Draw(full)
    d.text((gap, 22), title, font=font(FONT_B, 36), fill=(255, 244, 214))
    d.text((gap, 72), sub, font=font(FONT_R, 21), fill=(190, 196, 210))
    x = gap
    for i in ims:
        full.paste(i, (x, 120))
        x += i.width + gap
    full.convert("RGB").save(OUT / name, optimize=True)


# 07 · Y-sort ---------------------------------------------------------------
HOUSE = img(B + "house_small_a.png")
OAK = img(D + "tree_oak.png")
PW, PH = 400, 270
hx, hy = 120, 236        # pie de la casa
tx_, ty_ = 312, 200      # pie del árbol
p1 = (164, 246)          # delante de la casa
p2 = (318, 222)          # delante del árbol
p3 = (358, 186)          # detrás del árbol


def ysort_scene(mode):
    g = tiny_ground(PW, PH)
    if mode == "hoy":
        # orden real del juego hoy: Player primero en el árbol, después Markers
        # (casas, z 0) y la decoración con z_index 1 arriba de todo.
        items = [(0, p1[0], p1[1], HERO, 1), (0.1, p2[0], p2[1], HERO, 1), (0.2, p3[0], p3[1], HERO_BACK, 1),
                 (1, hx, hy, HOUSE, 1), (2, tx_, ty_, OAK, 1)]
    else:
        items = [(p1[1], p1[0], p1[1], HERO, 1), (p2[1], p2[0], p2[1], HERO, 1), (p3[1], p3[0], p3[1], HERO_BACK, 1),
                 (hy, hx, hy, HOUSE, 1), (ty_, tx_, ty_, OAK, 1)]
    draw_items(g, items)
    return g


u = 1.0
panels(
    "07_ysort.png", "Y-sort: quién se dibuja adelante",
    "Mismo lugar, mismas posiciones. Izquierda: cómo ordena hoy el juego (z_index fijo + orden del árbol). Derecha: ordenado por la Y de los pies.",
    [
        ("Hoy (sin Y-sort)", ysort_scene("hoy"), [
            lambda d, s: badge(d, (40 * s, (p1[1] + 6) * s), False, "la casa le tapa la cabeza", u),
            lambda d, s: badge(d, (p2[0] * s - 150, (p2[1] + 16) * s), False, "el árbol (z 1) siempre arriba", u),
            lambda d, s: badge(d, (p3[0] * s - 420, (p3[1] - 120) * s), True, "detrás: anda de casualidad", u),
        ]),
        ("Con Y-sort", ysort_scene("ysort"), [
            lambda d, s: badge(d, (40 * s, (p1[1] + 6) * s), True, "delante de la casa", u),
            lambda d, s: badge(d, (p2[0] * s - 150, (p2[1] + 16) * s), True, "delante del árbol", u),
            lambda d, s: badge(d, (p3[0] * s - 420, (p3[1] - 120) * s), True, "detrás del árbol", u),
        ]),
    ],
)

# 08 · Hitbox de la casa ----------------------------------------------------
# Medidas reales de scenes/world/buildings/house_small_a.tscn:
# sprite 176x224 anclado abajo, collider "Base" 126x56 centrado en y=-44
# (de -72 a -16). El techo va de y=-208 a -72 y es todo caminable.
QW, QH = 300, 330
qx, qy = 150, 290


def hitbox_scene(mode):
    g = tiny_ground(QW, QH)
    if mode == "hoy":
        ghost = (qx + 30, qy - 120)  # parado "adentro" del techo
        items = [(ghost[1], ghost[0], ghost[1], HERO, 1), (qy, qx, qy, HOUSE, 1),
                 (9999, ghost[0], ghost[1], HERO, 0.38)]  # fantasma: dónde está aunque no se vea
    else:
        behind = (qx + 40, qy - 152)
        front = (qx + 95, qy + 30)
        items = [(behind[1], behind[0], behind[1], HERO_BACK, 1), (qy, qx, qy, HOUSE, 1), (front[1], front[0], front[1], HERO, 1)]
    draw_items(g, items)
    return g


def rect_note(box, col, label, hatch=False, label_at="top"):
    def fn(d, s):
        x0, y0, x1, y1 = [v * s for v in box]
        if hatch:
            for k in range(int(x0 - (y1 - y0)), int(x1), 14):
                # líneas diagonales recortadas a la caja
                a = (max(x0, k), max(y0, y0 + (x0 - k)) if k < x0 else y0)
                pts = []
                for t in range(0, int((y1 - y0)) + 1, 2):
                    px, py = k + t, y0 + t
                    if x0 <= px <= x1 and y0 <= py <= y1:
                        pts.append((px, py))
                if len(pts) > 1:
                    d.line([pts[0], pts[-1]], fill=col + (150,), width=3)
        d.rectangle((x0, y0, x1, y1), outline=col + (255,), width=5)
        f = font(FONT_B, 22)
        ly = y0 - 22 if label_at == "top" else y1 + 22
        bb = d.textbbox(((x0 + x1) / 2, ly), label, font=f, anchor="mm")
        d.rounded_rectangle((bb[0] - 10, bb[1] - 6, bb[2] + 10, bb[3] + 6), radius=8, fill=(18, 20, 28, 230))
        d.text(((x0 + x1) / 2, ly), label, font=f, fill=col, anchor="mm")
    return fn


RED, YEL, GRN = (240, 90, 90), (255, 214, 90), (110, 220, 140)
panels(
    "08_hitbox_casa.png", "Por qué se puede “atravesar” la casa",
    "house_small_a: el collider cubre solo la pared (126×56). Todo el techo es piso caminable, y como la casa se dibuja encima, el personaje “entra” en ella.",
    [
        ("Hoy", hitbox_scene("hoy"), [
            rect_note((qx - 77, qy - 208, qx + 77, qy - 72), YEL, "caminable: quedás adentro del techo", hatch=True),
            rect_note((qx - 63, qy - 72, qx + 63, qy - 16), RED, "collider actual 126×56", label_at="bottom"),
            lambda d, s: badge(d, ((qx + 62) * s, (qy - 140) * s), False, "el personaje está acá", 1.0),
        ]),
        ("Propuesta", hitbox_scene("propuesta"), [
            rect_note((qx - 63, qy - 72, qx + 63, qy - 16), GRN, "pared 126×56", label_at="bottom"),
            rect_note((qx - 75, qy - 150, qx + 75, qy - 72), GRN, "+ techo 150×78"),
        ]),
    ],
)
print("tech done")

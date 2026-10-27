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
W_T, H_T = 250, 188
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
# Diseño de la zona (en tiles). Praderas del Alba mide 8000x6000 px
# (world_size en praderas_del_alba.tscn) = 250x188 tiles: es el cuadrante
# (0,0) del supermapa.
# --------------------------------------------------------------------------
rng = random.Random(7)
painted = {}
warnings = []


def paint(c, t):
    if 0 <= c[0] < W_T and 0 <= c[1] < H_T:
        painted[c] = t


def blob(cx, cy, rx, ry, t, wobble=0.18, seed=1):
    r = random.Random(seed)
    ph = [r.uniform(0, 6.28) for _ in range(3)]
    for y in range(int(cy - ry * 1.4), int(cy + ry * 1.4) + 1):
        for x in range(int(cx - rx * 1.4), int(cx + rx * 1.4) + 1):
            ang = math.atan2(y - cy, x - cx)
            k = 1 + wobble * (math.sin(3 * ang + ph[0]) * 0.5 + math.sin(5 * ang + ph[1]) * 0.3 + math.sin(2 * ang + ph[2]) * 0.4)
            if ((x - cx) / (rx * k)) ** 2 + ((y - cy) / (ry * k)) ** 2 <= 1:
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


def coast(x):
    """Primera fila de mar para la columna x: costa sur con una bahía honda frente al pueblo."""
    return (160 - 46 * math.exp(-((x - 62) / 24) ** 2) + 4 * math.sin(x / 17) + 2.5 * math.sin(x / 7.3)
            + max(0, x - 150) * 0.45)


# --- Mar y costa -------------------------------------------------------------
for x in range(W_T):
    c = coast(x)
    for y in range(H_T):
        if y >= c:
            paint((x, y), "agua")
        elif y >= c - 4 - 1.5 * math.sin(x / 5):
            paint((x, y), "arena")

# --- Biomas ------------------------------------------------------------------
blob(178, 120, 20, 16, "piedra", seed=3)          # Cantera Vieja
blob(222, 32, 22, 24, "barro", seed=5)            # Hondonada

# --- Caminos ------------------------------------------------------------------
PLAZA = (62, 97)
blob(PLAZA[0], PLAZA[1], 11, 7, "piedra", wobble=0.22, seed=21)
ROADS = {
    "norte": [(70, 91), (72, 80), (69, 66), (66, 48), (60, 26), (58, 0)],
    "oeste": [(51, 99), (42, 97), (30, 100), (18, 97), (6, 99), (0, 95)],
    "puerto": [(62, 104), (62, 111)],
    "este": [(73, 100), (88, 102), (106, 98), (130, 96), (155, 101), (175, 99), (205, 93), (249, 90)],
    "noreste": [(106, 98), (128, 78), (160, 56), (200, 38), (214, 32)],
    "cantera": [(155, 101), (170, 112)],
    "sureste": [(130, 96), (150, 128), (185, 150), (215, 165), (249, 172)],
}
STREETS = {
    "Bosque": [(70, 72), (60, 70), (48, 73), (36, 69), (22, 71), (6, 67), (0, 66)],
    "Molino": [(72, 82), (84, 79), (97, 82), (110, 78), (124, 80)],
    "Gaviotas": [(40, 98), (36, 112), (26, 118), (14, 122), (4, 128)],
    "Malecón": [(x, coast(x) - 3.6) for x in range(46, 84, 3)],
}
for pts in ROADS.values():
    path(pts, 1.5, "barro")
for pts in STREETS.values():
    path(pts, 1.2, "barro")


def street_y(pts, x):
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        if min(ax, bx) <= x <= max(ax, bx) and ax != bx:
            return ay + (by - ay) * (x - ax) / (bx - ax)
    # fuera del tramo: la calle termina ahí, vale la altura de su punta más cercana
    return min(pts, key=lambda p: abs(p[0] - x))[1]


# --------------------------------------------------------------------------
# Objetos (anclados abajo-al-centro, en píxeles)
# --------------------------------------------------------------------------
objs = []
solid = []  # (nombre, rect en tiles) que no se deben pisar: valida el layout y evita plantar árboles encima


def put(rel_or_im, tx, ty, s=1.0, shadow=False):
    im = rel_or_im if isinstance(rel_or_im, Image.Image) else img(rel_or_im)
    im = scaled(im, s)
    objs.append((ty * T, tx * T, ty * T, im, None, shadow))
    return im


def overlaps(r):
    return [o[0] for o in solid if r[0] < o[1][2] and o[1][0] < r[2] and r[1] < o[1][3] and o[1][1] < r[3]]


def building(name, tx, ty, label=None):
    im = put(B + name + ".png", tx, ty)
    r = (tx - im.width / T / 2, ty - im.height / T, tx + im.width / T / 2, ty)
    for o in overlaps(r):
        warnings.append(f"{label or name} se pisa con {o}")
    solid.append((label or name, r))
    return r


def free(tx, ty, pad=0.5):
    return not any(o[1][0] - pad <= tx <= o[1][2] + pad and o[1][1] - pad <= ty <= o[1][3] + pad for o in solid)


def on_road(tx, ty):
    return painted.get((int(tx), int(ty))) == "barro" and not (192 < tx and ty < 60)


B = "world/buildings/"
D = "world/decor/plains/"
M = "world/decor/megapack/"

# --- Lotes ---------------------------------------------------------------------
# Tamaño del lote (tiles, ancho x alto) -> tier máximo de casa. Cada tamaño entra
# justo el sprite de su tier máximo, más 3 tiles de patio adelante.
LOT_SIZES = {
    "chico": (10, 12, 2),
    "mediano": (13, 16, 3),
    "grande": (17, 21, 4),
    "finca": (29, 25, 5),
}
ALL_STREETS = {**ROADS, **STREETS}
LOTS = [
    # nombre, x izquierda, tamaño, calle a la que da el portón, casa actual (None = en venta)
    ("FINCA", 5, "finca", "Bosque", "house_large_cozy"),
    ("N8", 38, "mediano", "Bosque", None),
    ("N7", 54, "chico", "Bosque", "house_small_a"),
    ("W3", 4, "chico", "oeste", "house_small_f"),
    ("W2", 17, "grande", "oeste", "house_medium_common_b"),
    ("W1", 38, "chico", "oeste", "house_small_c"),
    ("W4", 8, "chico", "Gaviotas", None),
    ("W5", 20, "chico", "Gaviotas", "house_small_d"),
    ("N1", 75, "chico", "Molino", "house_small_e"),
    ("N2", 88, "mediano", "Molino", "house_medium_cozy"),
    ("N3", 105, "grande", "Molino", "house_medium_noble"),
    ("N5", 86, "chico", "este", "house_small_b"),
]
fence = set()
lot_rects = []
for name, lx, size, street, house in LOTS:
    w, h, tmax = LOT_SIZES[size]
    # el lote se apoya en su calle: la valla de adelante queda 2 tiles arriba del centro del camino
    # la calle puede venir en pendiente: el lote se apoya en su punto más alto bajo el lote
    top_of_street = min(street_y(ALL_STREETS[street], lx + k * w / 8) for k in range(9))
    ly = math.floor(top_of_street - 2.6 - h)
    lot = (lx, ly, lx + w, ly + h)
    for o in overlaps(lot):
        warnings.append(f"lote {name} se pisa con {o}")
    for y in range(ly, ly + h + 1):
        for x in range(lx, lx + w + 1):
            if painted.get((x, y)) == "barro":
                warnings.append(f"lote {name} pisa un camino en {(x, y)}")
                break
    lot_rects.append((name, lx, ly, w, h, size, tmax, house))
    gate = range(lx + w // 2 - 1, lx + w // 2 + 1)
    for x in range(lx, lx + w + 1):
        fence.add((x, ly))
        if x not in gate:
            fence.add((x, ly + h))
    for y in range(ly, ly + h + 1):
        fence.add((lx, y))
        fence.add((lx + w, y))
    cx, by = lx + w / 2 + 0.5, ly + h - 3
    if house:
        put(B + house + ".png", cx, by)
    else:
        put(D + "sign_wood.png", cx, ly + h - 1.2)
    r = random.Random(sum(map(ord, name)))
    for _ in range(2 if size in ("chico", "mediano") else 5):
        px = lx + r.uniform(1.2, w - 1.2)
        py = ly + h - r.uniform(0.6, 2.2)
        if abs(px - cx) < 1.6:
            continue
        put(r.choice([M + "garden_plot_vegetables.png", M + "flower_patch_wild.png", D + "barrel.png",
                      D + "bench.png", M + "rain_barrel_wooden.png", D + "bush_berry.png"]), px, py)
    solid.append((f"lote {name}", lot))

# --- Edificios del pueblo --------------------------------------------------------
building("inn", 59, 90.5, "posada")
building("general_goods", 79, 100, "tienda")
building("blacksmith_n", 86, 108.8, "herrería")
put(M + "anvil_horn_block.png", 90.2, 109)
put(M + "quench_barrel_steam.png", 82.2, 109.2)
put(B + "market_produce.png", 56, 103.5)
put(B + "market_spices.png", 68.5, 103.5)
put(D + "well.png", 62.5, 98.5)
put(M + "quest_board_parchment_blank.png", 54.5, 95.8)
put(D + "bench.png", 59, 94.8)
put(D + "bench.png", 66, 94.8)
# patio de entrenamiento, junto al camino norte
for x in (74.5, 77.5, 80.5):
    put(M + "armor_stand_breastplate.png", x, 50.5)
put(M + "weapon_rack_swords.png", 74, 47.6)
put(M + "weapon_rack_polearms.png", 78.5, 47.6)
put(M + "scarecrow_cross_frame.png", 83, 50.5)
solid.append(("patio de entrenamiento", (73, 46, 85, 51)))

# --- Puerto ------------------------------------------------------------------------
for dx in (55, 63.5, 72):
    building("dock", dx, coast(dx) + 2.4, f"muelle {dx}")
put(M + "stall_fish_table_ice.png", 50, coast(50) - 4.6)
put(M + "crate_produce_stack.png", 76, coast(76) - 4.4)
put(D + "barrel_water.png", 77.6, coast(77.6) - 4.4)
put(D + "crate.png", 47.5, coast(47.5) - 4.2)
put(D + "sack_grain.png", 48.8, coast(48.8) - 4.1)
put(M + "handcart_single_axle.png", 67.5, coast(67.5) - 5.4)
put(M + "chain_bundle_hook.png", 59.5, coast(59.5) - 5)
solid.append(("puerto", (44, coast(62) - 8, 82, coast(62) + 6)))
for x in (20, 32):
    put(D + "tent.png", x, coast(x) - 5)
put(M + "clothesline_posts.png", 26, coast(26) - 5)

# faroles cada ~8 tiles a lo largo de las calles del pueblo
for pts in [ROADS["norte"][:3], ROADS["oeste"], ROADS["este"][:3], ROADS["puerto"], STREETS["Bosque"], STREETS["Molino"],
            STREETS["Gaviotas"], STREETS["Malecón"]]:
    acc = 0.0
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        seg = math.hypot(bx - ax, by - ay)
        t = 0.0
        while t < seg:
            if acc <= 0:
                px, py = ax + (bx - ax) * t / seg, ay + (by - ay) * t / seg + 2.2
                if free(px, py, 0.3):
                    put(M + "lantern_post_iron.png", px, py)
                    solid.append(("farol", (px - 0.4, py - 0.4, px + 0.4, py + 0.1)))
                acc = 8.0
            step = 1.0
            t += step
            acc -= step

# --- Mobs ---------------------------------------------------------------------------
SLIME = img("mobs/slime/idle.png")
MOB = {
    "debil": SLIME,
    "medio": hue_shift(SLIME, 95, 1.05, 1.0),
    "rango": hue_shift(SLIME, -95, 1.2, 1.05),
    "fuerte": hue_shift(SLIME, 160, 1.1, 0.85),
}
BOSS = scaled(hue_shift(SLIME, 160, 1.25, 0.8), 2.6)


def pack(kind, cx, cy, n, spread=2.2, s=1.4):
    for _ in range(n):
        put(MOB[kind], cx + rng.uniform(-spread, spread), cy + rng.uniform(-spread * 0.7, spread * 0.7), s, shadow=True)


GREEN = [(112, 108), (124, 132), (142, 114), (104, 142), (138, 142), (150, 86), (118, 66), (96, 118), (130, 122), (14, 140), (36, 141),
         (160, 122), (146, 96), (118, 152), (152, 150), (170, 148), (96, 128)]
for c in GREEN:
    pack("debil", *c, 2)
FOREST_BLUE = [(22, 20), (56, 14), (96, 24), (128, 16), (150, 36), (36, 34), (112, 40)]
FOREST_RED = [(78, 30), (115, 10), (142, 26)]
for c in FOREST_BLUE:
    pack("medio", *c, 3)
for c in FOREST_RED:
    pack("rango", *c, 2)
for c in [(172, 72), (188, 58), (150, 66)]:
    pack("medio", *c, 2)
for c in [(168, 114), (188, 128)]:
    pack("medio", *c, 2)
for c in [(165, 126), (193, 112), (181, 134)]:
    pack("rango", *c, 1)
for c in [(210, 20), (236, 46), (205, 50), (239, 14), (224, 52)]:
    pack("fuerte", *c, 3, s=1.5)
put(BOSS, 222, 28, shadow=True)

# --- Recursos -------------------------------------------------------------------------
def res(kind, tx, ty):
    put(f"world/{kind}.png", tx, ty, s={"tree": 0.62, "rock": 0.55, "vein": 0.6}[kind], shadow=True)


for _ in range(26):
    tx, ty = rng.uniform(92, 162), rng.uniform(58, 150)
    if free(tx, ty, 1) and painted.get((int(tx), int(ty))) is None:
        res("tree" if rng.random() < 0.6 else "rock", tx, ty)
for tx, ty in [(2, 104), (4, 140), (36, 135), (2, 76), (94, 112), (98, 120)]:
    res("tree", tx, ty)
for _ in range(16):
    tx, ty = rng.uniform(4, 160), rng.uniform(4, 42)
    res("tree", tx, ty)
for _ in range(12):
    tx, ty = rng.uniform(162, 195), rng.uniform(108, 134)
    if painted.get((int(tx), int(ty))) == "piedra":
        res("rock", tx, ty)
VEINS = [(170, 118), (176, 108), (184, 116), (190, 124), (174, 128), (182, 132), (166, 122), (192, 116)]
for v in VEINS:
    res("vein", *v)

# --- Decorado exterior ---------------------------------------------------------------------
clearings = [(c[0], c[1], 4.5) for c in FOREST_BLUE + FOREST_RED]
for _ in range(1700):
    tx, ty = rng.uniform(0, 168), rng.uniform(0.5, 46)
    if any((tx - cx) ** 2 + (ty - cy) ** 2 < r * r for cx, cy, r in clearings):
        continue
    if painted.get((int(tx), int(ty))) or painted.get((int(tx), int(ty) + 1)):
        continue
    if not free(tx, ty, 1.5):
        continue
    k = rng.random()
    put(D + ("tree_pine.png" if k < 0.45 else "tree_oak.png" if k < 0.8 else "tree_round.png"), tx, ty, shadow=True)
for _ in range(260):
    tx, ty = rng.uniform(0, 168), rng.uniform(1, 46)
    if free(tx, ty, 1):
        put(rng.choice([D + "mushrooms_red.png", D + "mushrooms_brown.png", D + "bush_fern.png", D + "grass_tall.png",
                        D + "log_fallen.png", D + "stump.png"]), tx, ty)
# borde verde del pueblo: árboles y arbustos sueltos, sin muralla
for _ in range(90):
    tx, ty = rng.uniform(0, 125), rng.uniform(46, 150)
    if painted.get((int(tx), int(ty))) is None and free(tx, ty, 2.5) and not (46 < tx < 92 and 86 < ty < 116):
        put(rng.choice([D + "tree_oak.png", D + "tree_round.png", D + "bush.png", D + "bush.png"]), tx, ty, shadow=True)
# Lomas del este: transición entre el campo y la hondonada
for _ in range(220):
    tx, ty = rng.uniform(118, 205), rng.uniform(36, 96)
    if painted.get((int(tx), int(ty))) is None and free(tx, ty, 1):
        put(rng.choice([D + "tree_oak.png", D + "tree_round.png", D + "tree_pine.png", D + "bush.png", D + "rock_mossy.png",
                        M + "boulder_moss_large.png", M + "flower_patch_wild.png", D + "grass_tall.png", D + "stump.png"]), tx, ty, shadow=True)
for _ in range(14):
    tx, ty = rng.uniform(120, 200), rng.uniform(40, 95)
    if painted.get((int(tx), int(ty))) is None and free(tx, ty, 1):
        res("tree" if rng.random() < 0.5 else "rock", tx, ty)
put(M + "shrine_roadside_stone.png", 147, 62)
put(M + "beehive_skep_straw.png", 101, 114)
put(D + "beehive.png", 102.4, 114.3)
put(M + "chicken_coop_wooden.png", 148, 84)
# Cantera
for _ in range(30):
    tx, ty = rng.uniform(158, 198), rng.uniform(104, 136)
    if painted.get((int(tx), int(ty))) == "piedra":
        put(rng.choice([D + "rock_mossy.png", M + "boulder_moss_large.png", M + "rock_group_small.png", M + "stone_pile_field.png"]), tx, ty, shadow=True)
put(M + "coal_pile_shovel.png", 186, 110)
put(M + "handcart_single_axle.png", 172, 115)
put(D + "tent.png", 162, 108)
# Hondonada
for x, y in [(212, 26), (232, 22), (228, 40)]:
    put(D + "tent.png", x, y)
put(D + "campfire.png", 220, 36)
put(D + "cauldron.png", 222.3, 36.4)
put(M + "treasure_chest_closed.png", 226, 29.5)
for x, y in [(214.5, 33.5), (206, 38), (204, 30)]:
    put(D + "sign_skull.png", x, y)
put(M + "cage_iron_hanging.png", 216, 18)
put(M + "weapon_rack_swords.png", 230, 30)
put(M + "banner_pole_pennant.png", 219, 22)
for _ in range(60):
    tx, ty = rng.uniform(196, 250), rng.uniform(0, 70)
    if painted.get((int(tx), int(ty))) != "barro":
        put(rng.choice([D + "tree_pine.png", D + "stump.png", D + "log_fallen.png", D + "tree_pine.png"]), tx, ty, shadow=True)
# Campos: dos trigales vallados
for fx0, fy0, fx1, fy1 in [(104, 116, 124, 126), (134, 80, 150, 90), (100, 136, 116, 145)]:
    for gx in range(fx0 + 1, fx1):
        for gy in range(fy0 + 1, fy1):
            if rng.random() < 0.85:
                put(D + "wheat.png", gx + 0.5 + rng.uniform(-0.2, 0.2), gy + 0.9)
    gate = range((fx0 + fx1) // 2 - 1, (fx0 + fx1) // 2 + 1)
    for x in range(fx0, fx1 + 1):
        fence.add((x, fy0))
        if x not in gate:
            fence.add((x, fy1))
    for y in range(fy0, fy1 + 1):
        fence.add((fx0, y))
        fence.add((fx1, y))
    put(M + "scarecrow_cross_frame.png", (fx0 + fx1) / 2 + 3, (fy0 + fy1) / 2 + 1)
for tx, ty in [(126, 114), (127.2, 115.6), (152, 88), (118, 141)]:
    put(D + "hay_bale.png", tx, ty)
put(M + "hay_cart_two_wheel.png", 101, 128)
# pasto suelto en todo lo abierto
for _ in range(500):
    tx, ty = rng.uniform(0, 250), rng.uniform(46, 188)
    if painted.get((int(tx), int(ty))) is None and free(tx, ty, 0.8):
        put(rng.choice([D + "grass_tuft.png", D + "grass_tuft_b.png", D + "grass_tall.png", D + "bush.png",
                        D + "mushrooms_yellow.png", D + "bush_berry.png"]), tx, ty)
# Costa sureste: playa y rocas, reservada
for _ in range(40):
    tx = rng.uniform(150, 250)
    ty = coast(tx) - rng.uniform(1, 3.5)
    if ty < H_T - 1:
        put(rng.choice([D + "rock.png", D + "rock_mossy.png", D + "log_fallen.png", D + "stump.png"]), tx, ty)

# --- Vallas ---------------------------------------------------------------------
FENCE = img("world/fences/wood.png")
for (x, y) in fence:
    m = (1 if (x, y - 1) in fence else 0) | (2 if (x + 1, y) in fence else 0) | (4 if (x - 1, y) in fence else 0)
    objs.append(((y + 1) * T - 1, x * T + 16, (y + 1) * T, FENCE.crop((m * 32, 0, m * 32 + 32, 32)), None, False))

for w in warnings:
    print("AVISO:", w)


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
    shadow_layer = Image.new("LA", base.size, (0, 0))
    sd = ImageDraw.Draw(shadow_layer)
    for _, x, y, im, _, shadow in objs:
        if shadow:
            w = im.width * 0.42
            sd.ellipse((x - w, y - w * 0.28, x + w, y + w * 0.22), fill=(0, 85))
    sl = shadow_layer.filter(ImageFilter.GaussianBlur(2))
    dark = Image.new("RGBA", base.size, (10, 30, 10, 0))
    dark.putalpha(sl.split()[1])
    base.alpha_composite(dark)
    del dark, sl, shadow_layer
    for _, x, y, im, _, _ in sorted(objs, key=lambda o: (o[0], o[1])):
        base.alpha_composite(im, (int(x - im.width / 2), int(y - im.height)))
    return base


MAP = render_objects(render_ground())
MAP.convert("RGB").resize((W // 2, H // 2), Image.LANCZOS).save(OUT / "00_mapa_completo_mitad.png", optimize=True)
print("map rendered")


def pill(d, xy, text, fnt, fg=(255, 255, 255), bg=(20, 22, 30, 215), pad=(10, 5), anchor="mm"):
    bbox = d.textbbox(xy, text, font=fnt, anchor=anchor)
    d.rounded_rectangle((bbox[0] - pad[0], bbox[1] - pad[1], bbox[2] + pad[0], bbox[3] + pad[1]), radius=8, fill=bg)
    d.text(xy, text, font=fnt, fill=fg, anchor=anchor)


def arrow(d, a, b, col=(255, 255, 255, 235), wdt=6, L=20):
    d.line([a, b], fill=col, width=wdt)
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    d.polygon([b, (b[0] - L * math.cos(ang - 0.45), b[1] - L * math.sin(ang - 0.45)),
               (b[0] - L * math.cos(ang + 0.45), b[1] - L * math.sin(ang + 0.45))], fill=col)


REGIONS = [
    ("1", "Pueblo del Alba", "zona segura · lotes", (86, 58), (255, 236, 160)),
    ("2", "Campos del Alba", "anillo 1 · 0–15 pts", (130, 140), (170, 235, 120)),
    ("3", "Bosque Susurrante", "anillo 2 · 15–40 pts", (88, 6), (110, 210, 200)),
    ("4", "Cantera Vieja", "anillo 2 · 15–40 pts", (180, 140), (190, 200, 215)),
    ("·", "Lomas del Este", "transición 1→3", (165, 44), (220, 220, 180)),
    ("5", "Hondonada del Rey Slime", "anillo 3 · 40+ pts", (222, 5), (235, 140, 220)),
    ("6", "Puerto y mar", "futuro: barco y pesca", (62, 160), (130, 190, 255)),
    ("7", "Costa de las Gaviotas", "reservada", (205, 158), (200, 200, 200)),
]
EXITS = [
    ("salida norte", (58, 4), (58, -6)),
    ("salida oeste", (6, 90), (-4, 90)),
    ("salida este", (243, 90), (253, 90)),
    ("salida sureste", (240, 170), (252, 174)),
    ("ruta por mar", (63, 128), (63, 186)),
]


def overview():
    S = 0.25
    ov = MAP.resize((int(W * S), int(H * S)), Image.LANCZOS).convert("RGBA")
    lay = Image.new("RGBA", ov.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    p = lambda tx, ty: (tx * T * S, ty * T * S)
    for name, a, b in EXITS:
        arrow(d, p(*a), p(*b), col=(255, 214, 90, 245), wdt=7, L=22)
        lx, ly = p(*a)
        pill(d, (min(max(lx, 70), ov.width - 80), min(max(ly + (24 if a[1] < 10 else -26), 18), ov.height - 18)),
             name, font(FONT_S, 15), fg=(255, 214, 90), bg=(18, 20, 28, 220), pad=(7, 3))
    for num, name, sub, (tx, ty), col in REGIONS:
        cx, cy = p(tx, ty)
        pill(d, (cx, cy), f"{num}  {name}", font(FONT_B, 22), bg=(18, 20, 28, 225))
        pill(d, (cx, cy + 30), sub, font(FONT_S, 15), fg=col, bg=(18, 20, 28, 200), pad=(7, 3))
    ov.alpha_composite(lay)
    hd = Image.new("RGBA", (ov.width, 96), (18, 20, 28, 255))
    hdd = ImageDraw.Draw(hd)
    hdd.text((28, 20), "Praderas del Alba — cuadrante (0,0)", font=font(FONT_B, 34), fill=(255, 244, 214))
    hdd.text((28, 62), "250 × 188 tiles (8000 × 6000 px, el world_size actual) · norte arriba · en amarillo, las salidas a los cuadrantes vecinos",
             font=font(FONT_R, 17), fill=(190, 196, 210))
    full = Image.new("RGBA", (ov.width, ov.height + 96))
    full.paste(hd, (0, 0))
    full.paste(ov, (0, 96))
    full.convert("RGB").save(OUT / "01_vista_general.png", optimize=True)


overview()


def detail(name, title, sub, box_t, callouts, scale=1.0):
    x0, y0, x1, y1 = [v * T for v in box_t]
    crop = MAP.crop((x0, y0, x1, y1)).convert("RGBA")
    nw, nh = int(crop.width * scale), int(crop.height * scale)
    crop = crop.resize((nw, nh), Image.NEAREST if scale >= 1 else Image.LANCZOS)
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


LOT = {n: (lx + w / 2 + 0.5, ly + h - 3.2) for (n, lx, ly, w, h, *_rest) in lot_rects}
LOT_SIGN = {n: (lx + w / 2 + 0.5, ly + h - 1.4) for (n, lx, ly, w, h, *_rest) in lot_rects}
detail(
    "02_pueblo.png", "1 · Pueblo del Alba", "Un pueblo de puerto: plaza, calles que siguen el terreno y lotes vallados de distintos tamaños",
    (0, 38, 126, 140),
    [
        (59, 90, "Posada: respawn y guardado"),
        (79, 99.5, "Tienda"),
        (86, 108.3, "Herrería (provisoria)"),
        (62.5, 98, "Plaza con pozo y tablón de encargos"),
        (62, 103, "Puestos de mercado (provisorios)"),
        (*LOT["FINCA"], "Finca: el único lote de tier 5 (hoy T3)"),
        (*LOT["N3"], "Lote grande con casa T2: puede crecer hasta T4"),
        (*LOT_SIGN["W4"], "Lote libre, en venta"),
        (78.5, 50, "Patio de entrenamiento (muñecos no dan skill)"),
        (63.5, coast(63.5) + 0.5, "Puerto: tres muelles en la bahía"),
    ],
    scale=0.5,
)
detail(
    "04_puerto.png", "6 · Puerto del Alba", "La conexión al mar: hoy es decorado; mañana, el barco a otros cuadrantes y la pesca",
    (40, 100, 86, 130),
    [
        (63.5, coast(63.5) + 1.5, "Tres muelles sobre la bahía (arte provisorio)"),
        (50, coast(50) - 5, "Puesto de pescado"),
        (70, coast(70) - 3.6, "Malecón: la calle que bordea la bahía"),
        (62, 106, "Calle del Puerto, sale de la plaza"),
    ],
    scale=1.0,
)
detail(
    "05_campos.png", "2 · Campos del Alba (anillo 1)", "Al este del pueblo: trigales, árboles y rocas talables, slimes verdes de a dos",
    (90, 56, 165, 152),
    [
        (114, 121, "Trigal vallado (decorado)"),
        (112, 108, "Slimes verdes en pares"),
        (130, 96, "Cruce: camino este y camino a la costa"),
        (142, 85, "Segundo trigal"),
    ],
    scale=0.5,
)
detail(
    "06_bosque.png", "3 · Bosque Susurrante (anillo 2)", "Una franja de bosque denso al norte con claros donde están los packs",
    (0, 0, 170, 52),
    [
        (22, 20, "Claro con slimes azules (melee)"),
        (78, 30, "Slimes rojos a distancia: hay que esquivar"),
        (59.5, 12, "Camino norte → salida al cuadrante (0,-1)"),
        (128, 16, "Cada pack en su claro, rodeado de árboles"),
    ],
    scale=0.5,
)
detail(
    "07_cantera.png", "4 · Cantera Vieja (anillo 2)", "Piedra, rocas y ocho venas de hierro inmortales, cada una con algo cerca que interrumpe",
    (152, 96, 206, 142),
    [
        (176, 108, "Venas de hierro (auto-farm con G)"),
        (165, 126, "Slime rojo cuidando las venas"),
        (162, 108, "Campamento minero"),
        (160, 104, "Ramal desde el camino este"),
    ],
    scale=1.0,
)
detail(
    "08_hondonada.png", "5 · Hondonada del Rey Slime (anillo 3)", "Esquina noreste: barro, campamento abandonado, packs violetas y el jefe",
    (192, 0, 250, 66),
    [
        (222, 27.5, "Rey Slime: mini-jefe"),
        (226, 29, "Cofre: loot garantizado la primera vez"),
        (236, 46, "Pack de 3 slimes violetas"),
        (206, 37.5, "Carteles de calavera"),
        (220, 35.5, "Fogata: último lugar seguro"),
    ],
    scale=1.0,
)


# --------------------------------------------------------------------------
# Lámina de lotes y tiers
# --------------------------------------------------------------------------
def lots_plate():
    order = [("chico", "house_small_a", "house_medium_cozy"),
             ("mediano", "house_medium_common_b", "house_large_cozy"),
             ("grande", "house_large_common", "house_grand_cozy"),
             ("finca", "house_grand_common", "house_palace_cozy")]
    gap = 4
    wt = sum(LOT_SIZES[o[0]][0] for o in order) + gap * (len(order) + 1)
    ht = max(LOT_SIZES[o[0]][1] for o in order) + 6
    g = Image.new("RGBA", (wt * T, ht * T))
    grass = [img("tiles/grass_01.png"), img("tiles/grass_02.png"), img("tiles/grass_03.png")]
    r = random.Random(3)
    for y in range(ht):
        for x in range(wt):
            k = r.random()
            g.paste(grass[2] if k < 0.08 else grass[1] if k < 0.22 else grass[0], (x * T, y * T))
    items, notes = [], []
    lot_fence = set()
    x = gap
    base_y = ht - 3
    for size, now, maxh in order:
        w, h, tmax = LOT_SIZES[size]
        ly = base_y - h
        gate = range(x + w // 2 - 1, x + w // 2 + 1)
        for fx in range(x, x + w + 1):
            lot_fence.add((fx, ly))
            if fx not in gate:
                lot_fence.add((fx, ly + h))
        for fy in range(ly, ly + h + 1):
            lot_fence.add((x, fy))
            lot_fence.add((x + w, fy))
        cx = (x + w / 2 + 0.5) * T
        by = (ly + h - 3) * T
        ghost = img(B + maxh + ".png").copy()
        ghost.putalpha(ghost.split()[3].point(lambda a: int(a * 0.28)))
        items.append((by - 0.5, cx, by, ghost))
        items.append((by, cx, by, img(B + now + ".png")))
        notes.append((x, ly, w, h, size, tmax, now))
        x += w + gap
    for (fx, fy) in lot_fence:
        m = (1 if (fx, fy - 1) in lot_fence else 0) | (2 if (fx + 1, fy) in lot_fence else 0) | (4 if (fx - 1, fy) in lot_fence else 0)
        items.append(((fy + 1) * T - 1, fx * T + 16, (fy + 1) * T, FENCE.crop((m * 32, 0, m * 32 + 32, 32))))
    for _, xx, yy, im in sorted(items, key=lambda i: i[0]):
        g.alpha_composite(im, (int(xx - im.width / 2), int(yy - im.height)))
    lay = Image.new("RGBA", g.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    cur_tier = {"house_small_a": 1, "house_medium_common_b": 2, "house_large_common": 3, "house_grand_common": 4}
    for (lx, ly, w, h, size, tmax, now) in notes:
        cx = (lx + w / 2 + 0.5) * T
        pill(d, (cx, (ly + h) * T + 44), f"Lote {size} · {w}×{h} tiles", font(FONT_B, 24), bg=(18, 20, 28, 230))
        pill(d, (cx, (ly + h) * T + 82), f"casa actual T{cur_tier[now]} · máximo T{tmax}", font(FONT_S, 18), fg=(255, 214, 90), bg=(18, 20, 28, 210), pad=(8, 4))
    g.alpha_composite(lay)
    hd_h = 110
    full = Image.new("RGBA", (g.width, g.height + hd_h), (18, 20, 28, 255))
    full.paste(g, (0, hd_h))
    d = ImageDraw.Draw(full)
    d.text((28, 18), "Lotes y tiers: el tamaño del lote pone el techo", font=font(FONT_B, 38), fill=(255, 244, 214))
    d.text((28, 68), "La valla es el límite del lote. Sólida: la casa de hoy. Transparente: la casa más grande que entra en ese lote. Adelante quedan 3 tiles de patio.",
           font=font(FONT_R, 21), fill=(190, 196, 210))
    full.convert("RGB").save(OUT / "03_lotes.png", optimize=True)


lots_plate()


# --------------------------------------------------------------------------
# Supermapa: cómo crece por cuadrantes
# --------------------------------------------------------------------------
def supermap_plate():
    cw, ch, gap = 440, 330, 14
    cols, rows = 3, 3
    Wd = cols * cw + (cols + 1) * gap
    Hd = rows * ch + (rows + 1) * gap + 120
    im = Image.new("RGBA", (Wd, Hd), (18, 20, 28, 255))
    d = ImageDraw.Draw(im)
    d.text((gap + 10, 20), "El supermapa, cuadrante por cuadrante", font=font(FONT_B, 36), fill=(255, 244, 214))
    d.text((gap + 10, 70), "Una sola escena que crece: cada cuadrante es un bloque de 8000 × 6000 px del mismo mundo, y caminos, costa y terreno siguen de corrido.",
           font=font(FONT_R, 19), fill=(190, 196, 210))
    thumb = MAP.resize((cw, ch), Image.LANCZOS)
    cells = {
        (-1, -1): ("(-1,-1)", "por diseñar", "land"), (0, -1): ("(0,-1)", "más allá del bosque", "land"),
        (1, -1): ("(1,-1)", "por diseñar", "land"),
        (-1, 0): ("(-1,0)", "camino del oeste", "land"), (0, 0): ("(0,0)", "Praderas del Alba", "here"),
        (1, 0): ("(1,0)", "más allá de la cantera", "land"),
        (-1, 1): ("(-1,1)", "mar abierto", "sea"), (0, 1): ("(0,1)", "mar: ruta en barco", "sea"),
        (1, 1): ("(1,1)", "costa sureste", "coast"),
    }
    pos = {}
    for (qx, qy), (lab, sub, kind) in cells.items():
        x = gap + (qx + 1) * (cw + gap)
        y = 120 + gap + (qy + 1) * (ch + gap)
        pos[(qx, qy)] = (x, y)
        if kind == "here":
            im.paste(thumb, (x, y))
            d.rectangle((x, y, x + cw, y + ch), outline=(255, 214, 90), width=5)
        else:
            fill = {"land": (44, 58, 40), "sea": (34, 64, 96), "coast": (58, 70, 60)}[kind]
            cell = Image.new("RGBA", (cw, ch), fill + (255,))
            cd = ImageDraw.Draw(cell)
            for k in range(0, cw + ch, 26):
                cd.line([(k, 0), (k - ch, ch)], fill=tuple(min(255, c + 10) for c in fill), width=2)
            cd.rectangle((0, 0, cw - 1, ch - 1), outline=(90, 100, 110), width=2)
            im.paste(cell, (x, y))
        pill(d, (x + cw / 2, y + ch / 2 - 16), lab, font(FONT_B, 26), bg=(18, 20, 28, 220))
        pill(d, (x + cw / 2, y + ch / 2 + 20), sub, font(FONT_S, 17), fg=(255, 214, 90) if kind == "here" else (200, 205, 215), bg=(18, 20, 28, 200), pad=(8, 3))
    lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    dl = ImageDraw.Draw(lay)
    x0, y0 = pos[(0, 0)]
    sx, sy = cw / W_T, ch / H_T
    for name, a, b in EXITS:
        pa = (x0 + a[0] * sx, y0 + a[1] * sy)
        pb = (x0 + (a[0] + (b[0] - a[0]) * 3.2) * sx, y0 + (a[1] + (b[1] - a[1]) * 3.2) * sy)
        arrow(dl, pa, pb, col=(255, 214, 90, 250), wdt=6, L=18)
    im.alpha_composite(lay)
    im.convert("RGB").save(OUT / "12_supermapa.png", optimize=True)


supermap_plate()
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
    im.convert("RGB").save(OUT / "09_enemigos.png", optimize=True)


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
    "10_ysort.png", "Y-sort: quién se dibuja adelante",
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
    "11_hitbox_casa.png", "Por qué se puede “atravesar” la casa",
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

#!/usr/bin/env python3
"""Bakes scripts/world/road_autotile_table.gd from the road tile PNGs.

    python game/tools/bake_road_autotile.py        # run from the repo root

The road art (assets/world/roads/, see SOURCE.txt there) is a blob/Wang set
cut out of composed shapes: every tile is a piece of a FILLED REGION, and
which piece it is is written in its own alpha channel. A tile that belongs at
the west edge of a road is opaque along its N/E/S borders and transparent
along W. So instead of hand-mapping 207 numbered tiles onto the blob cases --
exactly the kind of positional table that rots the moment a tile is renamed,
the same trap PaintedFloorTileset's class doc describes -- this reads the
alpha back and derives the mapping.

Per tile it samples the outermost pixel row/column at the middle of each edge
and the 2x2 block at each corner, thresholds at 128, and builds the standard
8-bit blob mask (N=1 NE=2 E=4 SE=8 S=16 SW=32 W=64 NW=128, a corner bit only
set when both its cardinals are). Tiles then bucket by mask, and within a
bucket the OPAQUE FRACTION tells the variants apart:

  * corner buckets: the fullest tile is the rounded corner (a small notch),
    the emptiest is the 45-degree bevel. RoadAutotiler picks between them --
    rounded for a lone turn, bevelled for a step in a diagonal run, which is
    what makes a staircase of cells read as one clean diagonal edge.
  * edge buckets: the emptiest tile is the one whose empty side is a clean
    straight strip; the fuller ones dip in and out and tile visibly worse.
  * mask 255: fully opaque, i.e. an interior piece. These are NOT
    interchangeable variants of one texture -- they are the insides of the
    different decorated shapes the pack composes (a plain field, a panel with
    a border, a slab with an inlay; "losa" has 40 of them). Picking among them
    per cell makes a wide road a patchwork of mismatched patterns, so exactly
    ONE is kept per style: the one that tiles best against ITSELF, measured by
    self_tiling_score().

A style only ships as an auto-road brush if its EDGE pieces actually repeat
along their own run -- see run_seam(). Two of them do not: the pack draws
"madera" and "losa" as framed platforms, so their west edge carries a rim on
its top and bottom and a long vertical road comes out as stacked boxes rather
than a road. Those styles stay out of the brush (and stay available piece by
piece under SUELO, which is what they are good for). Re-slice their art with
repeating middles and they qualify again automatically -- nothing here names
them.

Masks with no art of their own are filled in by mirroring a tile that has it
(flip_h swaps E/W, flip_v swaps N/S), emitted as Godot's alternative-tile
transform bits. That alone completes the four corners and all four edges for
every style -- e.g. "piedra" ships no south edge, and gets its north edge
flipped vertically.

Regenerate after adding, removing or renaming road art. The output is checked
in so the game never pays for this at load time.
"""

import glob
import os
import re
import sys
from collections import defaultdict

try:
    from PIL import Image
except ImportError:  # pragma: no cover - dev-machine tooling, not shipped
    sys.exit("This tool needs Pillow:  pip install Pillow")

ROADS_DIR = os.path.join("game", "assets", "world", "roads")
OUT_PATH = os.path.join("game", "scripts", "world", "road_autotile_table.gd")
# Tile ids are emitted the way PaintedFloorTileset keys its TileSet sources
# (its ROAD_PREFIX), so world_zone.gd can look a resolved tile straight up in
# the map it already built instead of reassembling the name at paint time.
ID_PREFIX = "road_"

N, NE, E, SE, S, SW, W, NW = 1, 2, 4, 8, 16, 32, 64, 128

# Godot's TileSetAtlasSource transform bits, OR-ed into the alternative-tile
# id passed to TileMapLayer.set_cell().
FLIP_H = 4096
FLIP_V = 8192

# The blob cases a road actually needs, and what each one is for. Everything
# else RoadAutotiler resolves at runtime by falling back within this set.
CORNER_MASKS = {
    N | NE | E: "corner, road to N and E",
    E | SE | S: "corner, road to E and S",
    S | SW | W: "corner, road to S and W",
    W | NW | N: "corner, road to W and N",
}
EDGE_MASKS = {
    N | NE | E | SE | S: "west edge",
    E | SE | S | SW | W: "north edge",
    S | SW | W | NW | N: "east edge",
    W | NW | N | NE | E: "south edge",
}
CAP_MASKS = {N: "cap, road to N", S: "cap, road to S"}
# Concave notches: every cardinal is road, one diagonal is not.
INNER_MASKS = {
    255 & ~NE: "inner corner, no road NE",
    255 & ~SE: "inner corner, no road SE",
    255 & ~SW: "inner corner, no road SW",
    255 & ~NW: "inner corner, no road NW",
}

THRESHOLD = 128

# A 45-degree bevel cuts away roughly half the tile, so it lands near 0.6
# opaque. Some styles also ship a much thinner sliver in the same bucket
# ("piedra" has one at 0.27) -- picking that as the bevel would put a
# near-empty cell in the middle of a solid diagonal edge, so the emptiest
# CANDIDATE is only considered from here up.
MIN_BEVEL_COVERAGE = 0.45

# How badly a style's edge pieces may seam against themselves along their own
# run before the style is dropped from the brush (see run_seam()). Today's art
# splits wide: 17-66 for the three that work, 122 and 183 for the two that do
# not, so anything in that gap separates them.
MAX_RUN_SEAM = 100.0


def self_tiling_score(path, split=False):
    """How badly a tile seams against a copy of itself, lower is better.

    Not pixel equality -- a repeating pattern is not supposed to have equal
    opposite edges. What matters is whether the jump ACROSS the seam looks
    like the ordinary variation INSIDE the tile; a framed panel has a hard
    rim there and scores far worse than a continuous field.
    """
    rgb = Image.open(path).convert("RGB")
    px = rgb.load()
    w, h = rgb.size

    def diff(a, b):
        return sum(abs(a[i] - b[i]) for i in range(3))

    seam_h = sum(diff(px[w - 1, y], px[0, y]) for y in range(h)) / float(h)
    seam_v = sum(diff(px[x, h - 1], px[x, 0]) for x in range(w)) / float(w)
    inner_h = sum(diff(px[x, y], px[x + 1, y])
                  for x in range(w - 1) for y in range(h)) / float((w - 1) * h)
    inner_v = sum(diff(px[x, y], px[x, y + 1])
                  for x in range(w) for y in range(h - 1)) / float(w * (h - 1))
    horizontal = abs(seam_h - inner_h)
    vertical = abs(seam_v - inner_v)
    return (horizontal, vertical) if split else horizontal + vertical


def run_seam(paths, entries):
    """How badly a style's edges repeat along the direction they run in.

    A west or east edge is stacked VERTICALLY down the side of a road, so what
    matters for it is its top/bottom seam; a north or south edge is laid out
    horizontally, so its left/right seam is the one that shows. Scored with
    the same seam-vs-internal-variation measure as self_tiling_score(), and
    reported as the worst of them -- one bad edge is enough to make roads in
    that style unusable in that direction.
    """
    worst = 0.0
    for mask, vertical in ((N | NE | E | SE | S, True), (S | SW | W | NW | N, True),
                           (E | SE | S | SW | W, False), (W | NW | N | NE | E, False)):
        entry = entries.get(mask)
        if entry is None:
            continue
        seam_h, seam_v = self_tiling_score(paths[entry[0]], split=True)
        worst = max(worst, seam_v if vertical else seam_h)
    return worst


def measure(path):
    """-> (mask, opaque fraction) read off the tile's alpha channel."""
    alpha = Image.open(path).convert("RGBA").split()[3]
    px = alpha.load()
    w, h = alpha.size
    if (w, h) != (32, 32):
        return None, 0.0

    def mean(points):
        return sum(px[x, y] for x, y in points) / float(len(points))

    n = mean([(x, 0) for x in range(11, 21)])
    s = mean([(x, 31) for x in range(11, 21)])
    west = mean([(0, y) for y in range(11, 21)])
    e = mean([(31, y) for y in range(11, 21)])
    nw = mean([(0, 0), (1, 0), (0, 1), (1, 1)])
    ne = mean([(31, 0), (30, 0), (31, 1), (30, 1)])
    sw = mean([(0, 31), (1, 31), (0, 30), (1, 30)])
    se = mean([(31, 31), (30, 31), (31, 30), (30, 30)])

    mask = 0
    if n > THRESHOLD:
        mask |= N
    if e > THRESHOLD:
        mask |= E
    if s > THRESHOLD:
        mask |= S
    if west > THRESHOLD:
        mask |= W
    if nw > THRESHOLD and n > THRESHOLD and west > THRESHOLD:
        mask |= NW
    if ne > THRESHOLD and n > THRESHOLD and e > THRESHOLD:
        mask |= NE
    if sw > THRESHOLD and s > THRESHOLD and west > THRESHOLD:
        mask |= SW
    if se > THRESHOLD and s > THRESHOLD and e > THRESHOLD:
        mask |= SE

    opaque = sum(1 for v in alpha.getdata() if v > THRESHOLD)
    return mask, opaque / float(w * h)


def flip_h(mask):
    out = mask & (N | S)
    for a, b in ((E, W), (NE, NW), (SE, SW)):
        if mask & a:
            out |= b
        if mask & b:
            out |= a
    return out


def flip_v(mask):
    out = mask & (E | W)
    for a, b in ((N, S), (NE, SE), (NW, SW)):
        if mask & a:
            out |= b
        if mask & b:
            out |= a
    return out


def variants_of(mask):
    """Every (source mask, transform bits) that renders as `mask`."""
    yield mask, 0
    yield flip_h(mask), FLIP_H
    yield flip_v(mask), FLIP_V
    yield flip_h(flip_v(mask)), FLIP_H | FLIP_V


def pick(by_mask, mask, fullest, floor=0.0):
    """Best (tile, transform) for `mask`. Untransformed art always wins over
    a mirror of the same shape, so a style that ships the real piece never
    renders a flipped stand-in for it."""
    best = None
    for source_mask, bits in variants_of(mask):
        for tile, coverage in by_mask.get(source_mask, []):
            if coverage < floor:
                continue
            key = (bits != 0, -coverage if fullest else coverage, tile)
            if best is None or key < best[0]:
                best = (key, tile, bits)
    return (best[1], best[2]) if best else None


def style_of(name):
    return re.sub(r"_\d+$", "", name)


def sort_key(tile):
    """Numeric, so fill variant 9 sorts before 10 rather than after."""
    match = re.search(r"_(\d+)$", tile)
    return (tile[: match.start()], int(match.group(1))) if match else (tile, 0)


def bake():
    by_style = defaultdict(lambda: defaultdict(list))
    paths = {}
    for path in sorted(glob.glob(os.path.join(ROADS_DIR, "*.png"))):
        name = os.path.splitext(os.path.basename(path))[0]
        mask, coverage = measure(path)
        if mask is None:
            print("  skipped (not 32x32): %s" % name)
            continue
        by_style[style_of(name)][mask].append((ID_PREFIX + name, coverage))
        paths[ID_PREFIX + name] = path

    if not by_style:
        sys.exit("No road tiles under %s -- run this from the repo root." % ROADS_DIR)

    labelled = {}
    labelled.update(CORNER_MASKS)
    labelled.update(EDGE_MASKS)
    labelled.update(CAP_MASKS)
    labelled.update(INNER_MASKS)

    # Resolve every style first, then decide which ones ship: whether a style
    # qualifies depends on the edge tiles this picks for it.
    resolved = {}
    for style in sorted(by_style):
        by_mask = by_style[style]
        candidates = sorted((t for t, _ in by_mask.get(255, [])), key=sort_key)
        if not candidates:
            print("  WARNING: %s has no interior fill tile (mask 255) -- skipped" % style)
            continue
        ranked = sorted((self_tiling_score(paths[t]), t) for t in candidates)
        groups = {}
        for label, masks in (("round", labelled), ("diag", CORNER_MASKS)):
            picked = {}
            for mask in sorted(masks):
                # Edges have no rounded/bevelled split: the emptiest tile is
                # the one with the clean straight border either way.
                fullest = label == "round" and mask not in EDGE_MASKS
                floor = MIN_BEVEL_COVERAGE if label == "diag" else 0.0
                got = pick(by_mask, mask, fullest, floor)
                if got is not None:
                    picked[mask] = got
            groups[label] = picked
        resolved[style] = {
            "fill": ranked[0][1],
            "fill_note": "best of %d, self-seam %.0f (worst %.0f)"
                         % (len(candidates), ranked[0][0], ranked[-1][0]),
            "groups": groups,
            "seam": run_seam(paths, groups["round"]),
        }

    shipped = [s for s in sorted(resolved) if resolved[s]["seam"] <= MAX_RUN_SEAM]
    dropped = [s for s in sorted(resolved) if resolved[s]["seam"] > MAX_RUN_SEAM]
    if not shipped:
        sys.exit("No style's edges repeat well enough to ship -- check the art.")

    lines = [
        "class_name RoadAutotileTable",
        "extends RefCounted",
        "## GENERATED by tools/bake_road_autotile.py -- do not hand-edit.",
        "##",
        "## Blob mask -> road tile, per style, derived from the tiles' own alpha",
        "## channels. Read RoadAutotiler (which consumes this) for what the masks",
        "## mean and how a mask with no entry here is resolved, and the baker's",
        "## docstring for how the art is measured.",
        "##",
        "## Each entry is [tile id, alternative-tile transform bits]. A non-zero",
        "## transform is a mirror of a tile the style does ship, standing in for a",
        "## piece it doesn't (TileSetAtlasSource.TRANSFORM_FLIP_H / _FLIP_V).",
    ]
    if dropped:
        lines += [
            "##",
            "## Styles the pack has art for but that are NOT offered as a brush,",
            "## because their edge pieces do not repeat along their own run -- the",
            "## pack draws them as framed platforms, so a long road comes out as",
            "## stacked boxes. Worst run seam, against a budget of %.0f:" % MAX_RUN_SEAM,
        ]
        lines += ["##   %-10s %.0f" % (s, resolved[s]["seam"]) for s in dropped]
        lines += ["## They stay paintable piece by piece under SUELO. Re-slice their",
                  "## art with repeating middles and they come back automatically."]
    lines += [
        "",
        "const STYLES: Array[String] = [%s]" % ", ".join('"%s"' % s for s in shipped),
        "",
        "const TABLE := {",
    ]

    for style in shipped:
        entry = resolved[style]
        lines.append('	"%s": {' % style)
        lines.append('		"fill": "%s", # %s' % (entry["fill"], entry["fill_note"]))
        lines.append('		# edges repeat along their run, worst seam %.0f.' % entry["seam"])
        for label, masks in (("round", labelled), ("diag", CORNER_MASKS)):
            lines.append('		"%s": {' % label)
            for mask in sorted(entry["groups"][label]):
                tile, bits = entry["groups"][label][mask]
                lines.append('			%d: ["%s", %d], # %s' % (mask, tile, bits, masks[mask]))
            lines.append("		},")
        lines.append("	},")
    lines.append("}")

    with open(OUT_PATH, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")

    print("wrote %s" % OUT_PATH)
    for style in sorted(resolved):
        by_mask = by_style[style]
        print("  %-9s %3d tiles, %2d masks, run seam %5.1f  %s"
              % (style, sum(len(v) for v in by_mask.values()), len(by_mask),
                 resolved[style]["seam"],
                 "brush" if style in shipped else "DROPPED (edges do not repeat)"))
    if dropped:
        print("")
        print("Not offered as a brush: %s" % ", ".join(dropped))
        print('BuildCatalog "camino" entries must be: %s' % ", ".join(shipped))


if __name__ == "__main__":
    bake()

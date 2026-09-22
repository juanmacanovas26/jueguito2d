#!/usr/bin/env python3
"""Packs 16 already-cleaned Wang tile PNGs (see process_sprites.py) into this
project's Wang sheet format: a 4x4 grid with a 1px transparent gutter between
cells (so a 32x32-tile sheet is 131x131, not 128x128) — the exact layout
BiomeTileset._add_pair() / FloorTileset._add_wang_source() expect.

Cell order is a plain 4x4 grid, LEFT-TO-RIGHT then TOP-TO-BOTTOM, and MUST
already be the project's Wang index convention:

    index = TL*8 + TR*4 + BL*2 + BR*1   (1 = the "upper"/second-named terrain)
    #0  = all "lower" terrain (e.g. all sand)
    #15 = all "upper" terrain (e.g. all path/grass/whatever pairs with it)

i.e. tile 00 is pure lower-terrain, tile 15 is pure upper-terrain, and
everything between is whichever corners are which — see docs/ART.md's
worked example. If the 16 source images were generated and named by hand
(wang_00.png .. wang_15.png), that naming already encodes this order.

Usage:
    python assemble_wang_sheet.py IN_DIR output_wang.png [--tile-size 32]

IN_DIR must contain exactly 16 PNGs, all the same size, that sort
(alphabetically) into index order 0..15 — e.g. named wang_00.png .. wang_15.png,
or frame_00.png .. frame_15.png (process_sprites.py's default batch output).
"""
import argparse
import sys
from pathlib import Path

from PIL import Image

GUTTER = 1
COLUMNS = 4
EXPECTED = 16


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("in_dir", type=Path)
    ap.add_argument("output_png", type=Path)
    ap.add_argument("--tile-size", type=int, default=32)
    args = ap.parse_args()

    files = sorted(p for p in args.in_dir.iterdir() if p.suffix.lower() == ".png")
    if len(files) != EXPECTED:
        print(f"error: expected exactly {EXPECTED} PNGs in {args.in_dir}, found {len(files)}", file=sys.stderr)
        return 1

    tile = args.tile_size
    canvas_size = tile * COLUMNS + GUTTER * (COLUMNS - 1)
    out = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))

    for idx, f in enumerate(files):
        img = Image.open(f).convert("RGBA")
        if img.size != (tile, tile):
            print(f"error: {f.name} is {img.size[0]}x{img.size[1]}, expected {tile}x{tile} — "
                  f"run process_sprites.py with --canvas {tile}x{tile} first", file=sys.stderr)
            return 1
        col, row = idx % COLUMNS, idx // COLUMNS
        out.paste(img, (col * (tile + GUTTER), row * (tile + GUTTER)))

    args.output_png.parent.mkdir(parents=True, exist_ok=True)
    out.save(args.output_png)
    print(f"wrote {args.output_png} ({out.size[0]}x{out.size[1]}) from {len(files)} tiles")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

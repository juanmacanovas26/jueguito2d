"""Cuts one row (one color variant) out of an Effects/ sprite sheet into
individual frame PNGs for game/assets/vfx/<effect_id>/.

The Effects/ packs ship each effect as a grid: one row per color, one column
per animation frame. We only ever want one color at a time, so this slices a
single row and writes it as `frame_00.png`, `frame_01.png`, ... in original
resolution — no rescaling, same rule as the LPC pipeline.

Usage:
    python art_pipeline/vfx/slice_effect.py <sheet.png> <row> <effect_id> \
        [--rows N] [--cell N] [--start-col N] [--end-col N]

Column count is measured from the sheet width, not guessed — the packs vary
it per effect (8, 9, 12, 15 columns all show up). `--start-col`/`--end-col`
(inclusive) keep only part of the row, for effects whose first column or two
is a near-empty "growing in" spark you don't want in a looping cycle. Left at
their defaults, every column is kept — a spark growing in and dissolving out
is exactly what those near-empty edge frames are for on a one-shot effect.
"""
import argparse
import sys
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[2]
OUT_ROOT = REPO_ROOT / "game" / "assets" / "vfx"


def slice_row(sheet_path: Path, row: int, effect_id: str, rows: int, cell: int,
              start_col: int, end_col: int) -> int:
    im = Image.open(sheet_path).convert("RGBA")
    w, h = im.size
    if h % rows != 0:
        sys.exit(f"sheet is {w}x{h}, height does not divide evenly into {rows} rows")
    ch = h // rows
    if ch != cell:
        sys.exit(f"measured cell height {ch} does not match --cell {cell}")
    if w % cell != 0:
        sys.exit(f"sheet width {w} is not a multiple of --cell {cell}")
    cols = w // cell
    if row < 0 or row >= rows:
        sys.exit(f"row {row} out of range 0..{rows - 1}")
    last_col = cols - 1 if end_col < 0 else end_col
    if not (0 <= start_col <= last_col < cols):
        sys.exit(f"--start-col/--end-col out of range 0..{cols - 1}")

    out_dir = OUT_ROOT / effect_id
    out_dir.mkdir(parents=True, exist_ok=True)
    count = 0
    for c in range(start_col, last_col + 1):
        cell_im = im.crop((c * cell, row * ch, (c + 1) * cell, (row + 1) * ch))
        cell_im.save(out_dir / f"frame_{c:02d}.png")
        count += 1
    return count


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("sheet", type=Path)
    ap.add_argument("row", type=int)
    ap.add_argument("effect_id")
    ap.add_argument("--rows", type=int, default=9)
    ap.add_argument("--cell", type=int, default=64)
    ap.add_argument("--start-col", type=int, default=0)
    ap.add_argument("--end-col", type=int, default=-1, help="inclusive, -1 = last column")
    args = ap.parse_args()

    n = slice_row(args.sheet, args.row, args.effect_id, args.rows, args.cell,
                  args.start_col, args.end_col)
    print(f"{args.effect_id}: wrote {n} frames to game/assets/vfx/{args.effect_id}/")


if __name__ == "__main__":
    main()

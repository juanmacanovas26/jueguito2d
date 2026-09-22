#!/usr/bin/env python3
"""Composite several separately-generated parts into one wide sprite.

For buildings too large to come out of a single ChatGPT render. Above roughly
350-400px of final content width a 1024-1536px render leaves under ~2.5 screen
pixels per art-pixel, and the result stops reading as pixel art (see the
sprite-pipeline skill's notes on the downscale ratio). The way past that is to
draw the building as several structures — a gate wall, a main block, a tower —
each rendered at full canvas size, and butt them together on one ground line.

Every part is divided by the SAME --scale, never fitted individually: that is
what keeps one stone block the same size in the wall as on the manor. Get the
factor by measuring the part you want at a known final height (scale =
raw_subject_height / wanted_height) and pass the same number for all of them.
If the parts disagree on masonry scale, this script cannot fix it — that is a
regenerate, in the same conversation, pinning the stone block size in pixels.

Parts are laid out left to right in the order given, bottom-aligned on a shared
base line, each overlapping the previous one by --overlap pixels (one value, or
one per gap). Later parts draw over earlier ones.

Output is the trimmed composite with a transparent background; it is NOT
quantized or padded. Run it through process_sprites.py afterwards with
--canvas/--colors, so the whole assembly gets ONE palette rather than a
per-part palette that would make the pieces look like different materials:

    compose_parts.py out.png --parts wall.png manor.png tower.png \\
        --scale 2.292 --overlap 70 15
    process_sprites.py out.png final.png --key "#FF00FF" \\
        --canvas 1024x800 --colors 56
"""
import argparse
import sys
from pathlib import Path

from PIL import Image


def trim(img: Image.Image) -> Image.Image:
    bbox = img.split()[3].point(lambda a: 255 if a > 8 else 0).getbbox()
    return img if bbox is None else img.crop(bbox)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("output", type=Path)
    ap.add_argument("--parts", type=Path, nargs="+", required=True,
                    help="part PNGs, left to right; backgrounds already removed")
    ap.add_argument("--scale", type=float, required=True,
                    help="single divisor applied to every part (see module docstring)")
    ap.add_argument("--overlap", type=int, nargs="+", default=[0],
                    help="pixels each part overlaps the previous one: one value for "
                         "all gaps, or one per gap")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    if len(args.parts) < 2:
        print("need at least two parts", file=sys.stderr)
        return 2
    gaps = len(args.parts) - 1
    overlaps = args.overlap * gaps if len(args.overlap) == 1 else args.overlap
    if len(overlaps) != gaps:
        print(f"expected 1 or {gaps} --overlap values, got {len(overlaps)}", file=sys.stderr)
        return 2
    if args.output.exists() and not args.force:
        print(f"{args.output} exists (use --force)", file=sys.stderr)
        return 1

    images = []
    for p in args.parts:
        im = trim(Image.open(p).convert("RGBA"))
        im = im.resize((max(1, round(im.width / args.scale)),
                        max(1, round(im.height / args.scale))), Image.LANCZOS)
        images.append(im)
        print(f"  {p.name}: {im.width}x{im.height}")

    width = sum(i.width for i in images) - sum(overlaps)
    height = max(i.height for i in images)
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    x = 0
    for i, im in enumerate(images):
        out.alpha_composite(im, (x, height - im.height))
        if i < gaps:
            x += im.width - overlaps[i]

    out = trim(out)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    out.save(args.output)
    print(f"wrote {args.output} ({out.width}x{out.height})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

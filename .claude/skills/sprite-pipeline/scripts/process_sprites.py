#!/usr/bin/env python3
"""Chroma-key removal + trim + pixelate + canvas-fit for sprites generated
outside the project (ChatGPT), so they can drop straight into game/assets/.
Pure Pillow — no external service involved.

Three invocations:

  Single image:
    process_sprites.py IN.png OUT.png --key "#FF00FF" [--canvas 32x32] [--colors 24]

  Batch (several separate PNGs, one per animation frame, sharing one palette):
    process_sprites.py IN_DIR OUT_DIR --key "#FF00FF" --prefix walk \
        --canvas 32x32 --colors 24

  Sheet (one image containing a grid of frames), sliced + shared palette:
    process_sprites.py IN.png OUT_DIR --key "#FF00FF" --sheet-grid 4x2 \
        --prefix walk --canvas 32x32 --colors 24

Pipeline per frame: chroma-key removal (flood-fill from the border, so
interior pixels that happen to share the key color survive) -> trim to
content -> downscale to fit the target box (this is what turns a big soft
ChatGPT render into something pixel-sized) -> optional color quantization
(this is what makes it *read* as pixel art instead of a shrunk photo) ->
center-pad into the fixed canvas, if one was given.

For batch/sheet modes, when --colors is set the palette is derived once from
ALL frames together and then reused for each one, so an animation doesn't
drift or flicker between frames the way independently-quantized frames would.

Omit --canvas for world props/tiles, which don't share a fixed frame size in
this project — use --max-size instead to cap how big they get without
padding them onto a transparent canvas.
"""
import argparse
import sys
from collections import deque
from pathlib import Path

from PIL import Image


def parse_hex_color(s: str) -> tuple[int, int, int]:
    s = s.strip().lstrip("#")
    if len(s) != 6:
        raise argparse.ArgumentTypeError(f"expected a 6-digit hex color, got {s!r}")
    return tuple(int(s[i : i + 2], 16) for i in (0, 2, 4))


def parse_dims(s: str) -> tuple[int, int]:
    parts = s.lower().split("x")
    if len(parts) != 2:
        raise argparse.ArgumentTypeError(f"expected WxH, got {s!r}")
    return int(parts[0]), int(parts[1])


def color_distance(a, b) -> float:
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def remove_chroma_key(
    img: Image.Image, key: tuple[int, int, int], tolerance: float, global_fill: bool = False
) -> Image.Image:
    """Seeds the fill from the image border, so key-colored pixels that are
    part of the art survive. `global_fill` seeds from EVERY key-colored
    pixel instead, which is what an architectural sprite with enclosed
    openings needs — a belfry arch, an arcade, a flying buttress's void:
    background fully ringed by the subject, unreachable from the border, and
    left as a magenta blob inside the sprite. Only safe when the subject's
    own palette stays clear of the key (check before passing it).
    """
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()

    removed = [[False] * w for _ in range(h)]
    visited = [[False] * w for _ in range(h)]
    q = deque()

    def close_enough(x, y, tol):
        r, g, b, a = px[x, y]
        return a > 0 and color_distance((r, g, b), key) <= tol

    if global_fill:
        for y in range(h):
            for x in range(w):
                visited[y][x] = True
                if close_enough(x, y, tolerance):
                    q.append((x, y))
    else:
        for x in range(w):
            for y in (0, h - 1):
                if not visited[y][x]:
                    visited[y][x] = True
                    if close_enough(x, y, tolerance):
                        q.append((x, y))
        for y in range(h):
            for x in (0, w - 1):
                if not visited[y][x]:
                    visited[y][x] = True
                    if close_enough(x, y, tolerance):
                        q.append((x, y))

    while q:
        x, y = q.popleft()
        removed[y][x] = True
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
                visited[ny][nx] = True
                if close_enough(nx, ny, tolerance):
                    q.append((nx, ny))

    halo_tolerance = tolerance * 2.0
    for y in range(h):
        for x in range(w):
            if removed[y][x]:
                px[x, y] = (0, 0, 0, 0)
                continue
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            dist = color_distance((r, g, b), key)
            if dist <= halo_tolerance:
                adjacent_removed = any(
                    0 <= x + dx < w and 0 <= y + dy < h and removed[y + dy][x + dx]
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                )
                if adjacent_removed:
                    factor = max(0.0, min(1.0, (dist - tolerance) / tolerance))
                    px[x, y] = (r, g, b, int(a * factor))

    return img


def trim_to_content(img: Image.Image, alpha_threshold: int = 8) -> Image.Image:
    alpha = img.split()[3]
    mask = alpha.point(lambda a: 255 if a > alpha_threshold else 0)
    bbox = mask.getbbox()
    if bbox is None:
        return img
    return img.crop(bbox)


def downscale_to_fit(img: Image.Image, box: tuple[int, int]) -> Image.Image:
    """Aspect-preserving resize so img fits within box. Never upscales
    (a ChatGPT render trimmed down to something already small is just soft,
    not usable pixel art, so blowing it up further wouldn't help)."""
    bw, bh = box
    iw, ih = img.size
    if iw <= bw and ih <= bh:
        return img
    scale = min(bw / iw, bh / ih)
    new_size = (max(1, round(iw * scale)), max(1, round(ih * scale)))
    return img.resize(new_size, Image.LANCZOS)


def pad_to_canvas(img: Image.Image, canvas: tuple[int, int]) -> Image.Image:
    cw, ch = canvas
    iw, ih = img.size
    if iw > cw or ih > ch:
        left = max(0, (iw - cw) // 2)
        top = max(0, (ih - ch) // 2)
        img = img.crop((left, top, left + min(iw, cw), top + min(ih, ch)))
        iw, ih = img.size
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    # No mask: a straight copy of RGBA bytes. Pasting *with* img as its own
    # mask would alpha-composite semi-transparent edge pixels against this
    # fully-transparent (black) canvas, darkening their RGB and quietly
    # multiplying the color count — harmless-looking but defeats --colors
    # and can fringe dark at tile edges once Godot samples it.
    out.paste(img, ((cw - iw) // 2, (ch - ih) // 2))
    return out


def _extract_palette_colors(quantized_p_image: Image.Image, max_colors: int) -> list[tuple[int, int, int]]:
    pal = quantized_p_image.getpalette() or []
    n = min(max_colors, len(pal) // 3)
    return [tuple(pal[i * 3 : i * 3 + 3]) for i in range(n)]


def _nearest_color_map(img: Image.Image, palette_colors: list[tuple[int, int, int]]) -> Image.Image:
    """Snap every opaque pixel to its nearest color in palette_colors. Flat,
    undithered mapping — dithering would fight the 'clean hard outlines, no
    soft shading' look this pipeline is aiming for."""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            key = (r, g, b)
            best = cache.get(key)
            if best is None:
                best = min(palette_colors, key=lambda c: color_distance(c, key))
                cache[key] = best
            px[x, y] = (best[0], best[1], best[2], a)
    return img


def quantize_colors(img: Image.Image, colors: int) -> Image.Image:
    # Palette comes from the OPAQUE pixels only, via the same helper batch mode
    # uses. Quantizing img.convert("RGB") directly would hand MEDIANCUT one
    # black pixel per transparent one (RGBA -> RGB keeps a removed pixel's
    # zeroed RGB), and on a trimmed sprite that transparent margin is 30-40% of
    # the image: the biggest single population in the histogram, so the cut
    # spends entries resolving shades of nothing and starves small real
    # regions. Foliage was the visible casualty — every leaf on a 48-color
    # building collapsing into one near-black olive.
    palette = build_shared_palette([img], colors)
    if not palette:
        return img
    return _nearest_color_map(img, palette)


def _mediancut_palette(pixels: list[tuple[int, int, int]], colors: int) -> list[tuple[int, int, int]]:
    if len(pixels) > 20000:
        pixels = pixels[:: len(pixels) // 20000 + 1]
    strip = Image.new("RGB", (len(pixels), 1))
    strip.putdata(pixels)
    return _extract_palette_colors(strip.quantize(colors=colors, method=Image.MEDIANCUT), colors)


def build_shared_palette(images: list[Image.Image], colors: int) -> list[tuple[int, int, int]] | None:
    """Derive one palette from the opaque pixels of every frame together, so
    mapping each frame onto it keeps their colors in sync.

    Two passes, because plain MEDIANCUT splits the histogram by PIXEL COUNT and
    a building sprite is mostly a few enormous flat fields (plaster, roof,
    timber). Small saturated regions lose every split: on a 48-color facade the
    entire foliage — leaves, ivy, window boxes — collapsed into a single
    near-black olive, which is what "las flores estan negras" looks like. So the
    first pass spends most of the budget the normal way, keeping those big
    fields banding-free, and the reserve is then fitted to the pixels the first
    pass represents WORST. Error-driven rather than area-driven, the leftover
    entries land exactly on the starved regions.

    MAXCOVERAGE looks like the obvious fix and is not: it restores the greens
    but mottles the large flat areas into color noise (mean per-pixel error
    roughly doubles). This keeps that error flat while still recovering the
    shading steps.
    """
    # Fully opaque only. remove_chroma_key() leaves a 1px rim of part-alpha
    # pixels whose RGB is still half key color; they are transition pixels, not
    # art, and the reserve pass below is exactly the thing that would "rescue"
    # them — handing the chroma key its own palette entry and rimming the
    # finished sprite in cyan or magenta. A sprite that is genuinely soft-alpha
    # throughout (some VFX) would have almost nothing left, so fall back rather
    # than quantize off a handful of pixels.
    pixels = []
    partial = []
    for im in images:
        for r, g, b, a in im.convert("RGBA").getdata():
            if a == 255:
                pixels.append((r, g, b))
            elif a > 0:
                partial.append((r, g, b))
    if len(pixels) < max(64, (len(pixels) + len(partial)) // 10):
        pixels += partial
    if not pixels:
        return None

    reserve = max(4, colors // 6)
    if colors <= 8 or len(pixels) < 500:
        return _mediancut_palette(pixels, colors)

    base = _mediancut_palette(pixels, colors - reserve)
    sample = pixels[:: max(1, len(pixels) // 20000)]
    scored = sorted(
        ((min(color_distance(p, c) for c in base), p) for p in sample), key=lambda t: -t[0]
    )
    worst = [p for _, p in scored[: max(200, len(scored) // 12)]]
    return base + _mediancut_palette(worst, reserve)


def apply_shared_palette(img: Image.Image, palette_colors: list[tuple[int, int, int]]) -> Image.Image:
    return _nearest_color_map(img, palette_colors)


def prepare_frame(img: Image.Image, key, tolerance, box, global_fill: bool = False) -> Image.Image:
    """Chroma-key removal, trim, downscale-to-fit. Stops short of palette
    quantization / canvas padding so callers can share a palette first."""
    img = remove_chroma_key(img, key, tolerance, global_fill)
    img = trim_to_content(img)
    if box is not None:
        img = downscale_to_fit(img, box)
    return img


def finish_frame(img: Image.Image, colors, canvas, shared_palette) -> Image.Image:
    if shared_palette is not None:
        img = apply_shared_palette(img, shared_palette)
    elif colors is not None:
        img = quantize_colors(img, colors)
    if canvas is not None:
        img = pad_to_canvas(img, canvas)
    return img


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input", type=Path, help="source PNG, or a directory of frame PNGs in batch mode")
    ap.add_argument("output", type=Path, help="output PNG (single mode) or output directory (batch/sheet modes)")
    ap.add_argument("--key", type=parse_hex_color, required=True, help="background color to remove, e.g. #FF00FF")
    ap.add_argument("--tolerance", type=float, default=40.0, help="color-distance tolerance for the key (default 40)")
    ap.add_argument("--key-global", action="store_true",
                    help="remove key-colored pixels anywhere, not just those connected to the "
                         "border — for subjects with enclosed openings (arcades, belfries, "
                         "tracery). Only safe when the art itself contains no near-key color.")
    ap.add_argument("--canvas", type=parse_dims, default=None, help="WxH to center-pad the result into (mobs/vfx/icons)")
    ap.add_argument("--max-size", type=parse_dims, default=None, help="WxH cap to downscale into without padding (props/tiles)")
    ap.add_argument("--colors", type=int, default=None, help="quantize to this many colors (recommended: 16-32)")
    ap.add_argument("--sheet-grid", type=parse_dims, default=None, help="COLSxROWS: slice the input as a grid of equal frames")
    ap.add_argument("--prefix", type=str, default="frame", help="filename prefix for batch/sheet modes (default 'frame')")
    ap.add_argument("--force", action="store_true", help="overwrite existing output files")
    args = ap.parse_args()

    box = args.canvas or args.max_size

    if args.sheet_grid:
        cols, rows = args.sheet_grid
        src = Image.open(args.input)
        sw, sh = src.size
        if sw % cols or sh % rows:
            print(f"warning: {sw}x{sh} does not divide evenly into {cols}x{rows} cells", file=sys.stderr)
        cell_w, cell_h = sw // cols, sh // rows
        cells = [
            src.crop((c * cell_w, r * cell_h, (c + 1) * cell_w, (r + 1) * cell_h))
            for r in range(rows)
            for c in range(cols)
        ]
        prepared = [prepare_frame(cell, args.key, args.tolerance, box, args.key_global) for cell in cells]
        palette = build_shared_palette(prepared, args.colors) if args.colors else None
        args.output.mkdir(parents=True, exist_ok=True)
        for idx, frame in enumerate(prepared):
            result = finish_frame(frame, args.colors, args.canvas, palette)
            out_path = args.output / f"{args.prefix}_{idx:02d}.png"
            if out_path.exists() and not args.force:
                print(f"skip (exists): {out_path}", file=sys.stderr)
            else:
                result.save(out_path)
                print(f"wrote {out_path} ({result.size[0]}x{result.size[1]})")

    elif args.input.is_dir():
        files = sorted(p for p in args.input.iterdir() if p.suffix.lower() == ".png")
        if not files:
            print(f"no .png files found in {args.input}", file=sys.stderr)
            sys.exit(1)
        prepared = [prepare_frame(Image.open(f), args.key, args.tolerance, box, args.key_global) for f in files]
        palette = build_shared_palette(prepared, args.colors) if args.colors else None
        args.output.mkdir(parents=True, exist_ok=True)
        for idx, (f, frame) in enumerate(zip(files, prepared)):
            result = finish_frame(frame, args.colors, args.canvas, palette)
            out_path = args.output / f"{args.prefix}_{idx:02d}.png"
            if out_path.exists() and not args.force:
                print(f"skip (exists): {out_path}", file=sys.stderr)
            else:
                result.save(out_path)
                print(f"wrote {out_path} ({result.size[0]}x{result.size[1]}) <- {f.name}")

    else:
        frame = prepare_frame(Image.open(args.input), args.key, args.tolerance, box, args.key_global)
        result = finish_frame(frame, args.colors, args.canvas, None)
        if args.output.exists() and not args.force:
            print(f"refusing to overwrite existing file: {args.output} (use --force)", file=sys.stderr)
            sys.exit(1)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        result.save(args.output)
        print(f"wrote {args.output} ({result.size[0]}x{result.size[1]})")


if __name__ == "__main__":
    main()

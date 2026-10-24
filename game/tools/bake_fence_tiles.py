"""Hornea el atlas de un estilo de valla a partir de su hoja de origen.

    python game/tools/bake_fence_tiles.py            # todos los estilos
    python game/tools/bake_fence_tiles.py wood       # uno solo

Lee `game/assets/_incoming/fences/<estilo>/source.png` y escribe
`game/assets/world/fences/<estilo>.png`: 8 tiles de 32x32 en fila, uno por
combinación de vecinos. El crudo se queda fuera del repo, como todo
`_incoming`; lo versionado es el resultado. Mismo reparto que el resto del
pipeline de arte.

POR QUÉ 8 Y NO 16. El arte no son 16 piezas cerradas: es un poste con
barandas que salen hacia los bordes de la celda. Y el poste está anclado
abajo, con el tronco llegando al borde inferior, así que **una conexión hacia
el SUR no necesita dibujo**: la celda de abajo pone su propia baranda norte y
las dos se encuentran en la costura. Quedan tres bits que sí cambian el
dibujo (N, E, O) = 8 combinaciones.

Eso es lo que hace barato un estilo nuevo: cuatro primitivas recortadas de
una hoja, no dieciséis dibujos. El pack de 12 estilos que hay dando vueltas
entra por la misma puerta.

GEOMETRÍA DE LA HOJA. Medida sobre spr_fencePost.png, no supuesta: el poste
ocupa las columnas 10-21 (12px centrados en la celda de 32), la baranda este
las columnas 22-31, la oeste las 0-9, y la norte las filas 0-5 por encima de
la cabeza del poste. Una hoja nueva que respete ese reparto se hornea igual;
una que no, se describe en LAYOUTS.
"""

import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Falta Pillow: pip install pillow")

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC_DIR = os.path.join(REPO, "game", "assets", "_incoming", "fences")
OUT_DIR = os.path.join(REPO, "game", "assets", "world", "fences")

TILE = 32

# Bits de vecino. El orden es el que lee FenceAutotiler: cambiar esto sin
# cambiarlo allá rompe el atlas en silencio, y validate_fence.gd falla.
N, E, W = 1, 2, 4

# De qué celda de la hoja sale cada primitiva, y qué recorte. (fila, columna)
# de la hoja, y el rectángulo dentro de esa celda.
#
# "post" sale de la celda que tiene SOLO poste + baranda este, recortada a la
# columna del poste: así no arrastra baranda de ningún lado.
LAYOUTS = {
    "default": {
        "post": {"cell": (0, 1), "box": (10, 6, 22, 32)},
        "rail_n": {"cell": (1, 1), "box": (10, 0, 22, 6)},
        "rail_e": {"cell": (0, 1), "box": (22, 0, 32, 32)},
        "rail_w": {"cell": (1, 2), "box": (0, 0, 10, 32)},
    },
}


def cut(sheet, spec):
    """La primitiva como un canvas de 32x32 con la pieza en su lugar — así
    componer es un alpha_composite en (0,0) y ninguna combinación tiene que
    acordarse de ningún offset."""
    row, col = spec["cell"]
    x0, y0, x1, y1 = spec["box"]
    piece = sheet.crop((col * TILE + x0, row * TILE + y0, col * TILE + x1, row * TILE + y1))
    canvas = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    canvas.alpha_composite(piece, (x0, y0))
    return canvas


def bake(style):
    src = os.path.join(SRC_DIR, style, "source.png")
    if not os.path.isfile(src):
        print("  sin source.png, salteado: %s" % style)
        return False

    sheet = Image.open(src).convert("RGBA")
    layout = LAYOUTS.get(style, LAYOUTS["default"])
    parts = {name: cut(sheet, spec) for name, spec in layout.items()}

    atlas = Image.new("RGBA", (TILE * 8, TILE), (0, 0, 0, 0))
    for mask in range(8):
        tile = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
        # Las barandas van primero y el poste encima: la baranda nace detrás
        # del poste, y al revés se le ve el corte por delante.
        if mask & W:
            tile.alpha_composite(parts["rail_w"])
        if mask & E:
            tile.alpha_composite(parts["rail_e"])
        if mask & N:
            tile.alpha_composite(parts["rail_n"])
        tile.alpha_composite(parts["post"])
        atlas.alpha_composite(tile, (mask * TILE, 0))

    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, "%s.png" % style)
    atlas.save(out)
    print("  %s -> %s (8 tiles)" % (style, os.path.relpath(out, REPO)))
    return True


def main():
    if not os.path.isdir(SRC_DIR):
        sys.exit("No existe %s — el arte crudo vive en _incoming (ver README)" % SRC_DIR)
    wanted = sys.argv[1:]
    styles = wanted or sorted(
        d for d in os.listdir(SRC_DIR) if os.path.isdir(os.path.join(SRC_DIR, d))
    )
    done = 0
    for style in styles:
        if bake(style):
            done += 1
    print("%d estilo(s) horneado(s)" % done)


if __name__ == "__main__":
    main()

# Art Bible

> **El personaje jugable usa Universal LPC Spritesheet** (paperdoll por capas,
> 64×64, 4 direcciones con arte real). El pipeline completo está en
> **`art_pipeline/lpc/README.md`** — esa es la fuente de verdad para todo lo que
> sea personajes y equipamiento.
>
> Lo que sigue cubre tiles, mobs y el estilo general. Las secciones sobre el
> personaje de 96×96 de PixelLab quedaron obsoletas; ese pipeline está retirado
> en `manualgenerated/_deprecated_pixellab/`.

## Personaje jugable (resumen)

```text
Frame:        64×64 px, escala 1:1, nunca se reescala
Direcciones:  north / west / south / east, LAS 4 CON ARTE REAL
Composición:  paperdoll en runtime (cuerpo + cabeza + pelo + torso + piernas
              + casco + arma), ordenado por el zPos de LPC
Animaciones:  idle 2 · walk 9 · attack 6 · dash 8 · death 6 frames
```

El canvas de 64 px **no es la hitbox**: la colisión del jugador sigue siendo
18×26 y no depende del sprite.

Agregar arte = sumar el nombre a `art_pipeline/lpc/selection.json` y correr el
importador. Darle apariencia a un item = una línea en `LpcEquipment.PIECES`.

---

## Estilo

Medieval fantástico **cozy/anime**: colores cálidos y pastel, contornos suaves, personajes expresivos.
Paleta base sugerida: marrones tierra + verdes suaves + acentos dorados/teal.

## Resolución

- **Tile:** 32×32 px
- **Mobs:** 32×32 (slime y mobs chicos) — todavía con placeholders procedurales
- **Cámara:** 1:1, sin zoom ni reescalado → pixel-perfect,
  `default_texture_filter = Nearest`

## Animaciones de mobs

| Animación | Frames |
|-----------|--------|
| idle | 1 |
| walk | 4 |
| attack | 2 |
| death | 1 |

Los arma `game/scripts/enemy/mob_sprites.gd`; mientras no haya PNG reales,
`placeholder_sprite.gd` los dibuja por código.

## Tiles de piso (TileMapLayer)

Carpeta: `game/assets/tiles/`. Tile **32×32**, PNG. Los arma
`game/scripts/world/floor_tileset.gd`.

### Wang tileset de pasto/tierra (lo que se usa hoy)

`grass_dirt_wang.png` — **16 tiles en grilla 4×4 con separador transparente de
1 px**, así que la hoja mide **131×131**, no 128×128.

El orden de las celdas es la enumeración binaria de qué esquinas son pasto:

```text
indice = TL*8 + TR*4 + BL*2 + BR*1
#0  = todo tierra        #15 = todo pasto
```

Se registra como **terrain set de Godot en modo match-corners**, así que
`TileMapLayer.set_cells_terrain_connect()` elige el tile de borde solo. El mundo
se pinta con pasto y parches orgánicos de tierra generados con ruido — la
cantidad y el tamaño se ajustan desde `world_zone.gd` con `dirt_coverage` y
`dirt_patch_scale`, sin tocar código.

Si querés otro par de terrenos (arena/agua, piedra/pasto), generá otra hoja con
**exactamente esa disposición** y registrala igual.

### Tiles planos sueltos (legacy, siguen funcionando)

`grass_01.png` (base), `grass_02.png` / `grass_03.png` (variantes),
`dirt_path.png`. Quedan como sources 0-3 del TileSet por compatibilidad, y son
el fallback: si falta la hoja Wang, el piso vuelve al scatter de variantes.

Mientras un archivo no exista, `floor_tileset.gd` genera un tile de color plano
como placeholder — no hace falta tocar código al agregar el PNG real, solo
guardarlo con ese nombre exacto.

**Un PNG con el tamaño equivocado se rechaza con un warning** que dice qué
archivo es y qué medida necesita, y se usa el placeholder. Un tile más chico que
32×32 rompía el TileSet entero (`dirt_path.png` está hoy a 16×16 y avisa).

## Dónde enchufar

- **Personaje jugable:** `art_pipeline/lpc/README.md`. El componente es
  `game/scripts/visual/character_visual.gd`; los paths de sprites viven
  **únicamente** en `lpc_library.gd`.
- **Mobs:** `game/scripts/art/placeholder_sprite.gd` y `mob_sprites.gd`
  (reemplazar por sprites reales cambiando `sprite_frames`).
- **Iconos de item:** `game/scripts/ui/item_icons.gd` los dibuja por código a
  partir del `color` y el `type` del item. Si dropeás
  `res://assets/icons/<item_id>.png`, usa ese en su lugar.

## Regla de oro (del contrato)

La **animación lee el estado**, nunca lo define. Si un cambio visual pide tocar
lógica de combate, es un error de arquitectura. Ver `docs/ARQUITECTURA.md`.

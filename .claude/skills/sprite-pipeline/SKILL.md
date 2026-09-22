---
name: sprite-pipeline
description: Craft precise ChatGPT image-generation prompts for game sprites (mobs, VFX, icons, world props), then clean up and import the results into game/assets/ with this project's conventions. Use when the user wants to generate sprite art via ChatGPT and get it working in the Godot project.
---

# Sprite pipeline: ChatGPT prompt → clean pixel art → game/assets/

Two phases. Do phase 1 fully (get the user prompts, let them go generate in
ChatGPT) before starting phase 2 — phase 2 needs the raw files on disk.

## Project conventions (already established in this repo — follow them exactly)

| Category | Fixed canvas | Filenames | Destination |
|---|---|---|---|
| Item/skill icon | 32x32 | `<item_id>.png` or `skill_<id>.png` | `game/assets/icons/` |
| Mob animation | per-mob (check sibling mobs, default 32x32) | `idle.png`, `walk_0.png`, `walk_1.png`…, `attack_0.png`, `attack_1.png`, `death.png` | `game/assets/mobs/<mob_name>/` |
| VFX sequence | per-effect (default 64x64) | `frame_00.png`, `frame_01.png`, … | `game/assets/vfx/<effect_name>/` |
| World prop/decor/tile | none — trim to content only | `<name>.png` | `game/assets/world/decor/`, `world/structures/`, `world/buildings/`, or `world/` for terrain |
| Wang/autotile terrain pair (curved paths, biome borders) | 32x32 per cell, 131x131 full sheet | `<pair_name>_wang.png` | `game/assets/tiles/` — see **Wang tilesets** section below, this does NOT follow the normal Phase 1/2 flow |

Before generating prompts for a mob or vfx, check `game/assets/mobs/` or
`game/assets/vfx/` for an existing sibling asset and read its PNG size with
Pillow to confirm the canvas — don't just assume the defaults above.

Icons: `game/scripts/ui/item_icons.gd` and `skill_icons.gd` already fall back
to a real PNG at `res://assets/icons/<id>.png` / `skill_<id>.png` if present,
so dropping the file in is enough — no script changes needed.

## Phase 1 — Prompt crafting

Ask the user (skip what they already told you): what asset (name/id),
which category, and for animated categories which specific frames/poses are
needed. Then:

1. **Pick the target canvas** `CANVAS_W x CANVAS_H` from the conventions
   table (check a sibling asset's real size for mobs/vfx, don't assume the
   default). **Pick a color budget** `N` — 16 for icons/mobs, 24 for props,
   8-12 for flat-shaded VFX. Use the *same* `CANVAS`/`N` values you'll pass
   to `process_sprites.py --canvas/--colors` in phase 2 — the prompt and the
   cleanup step must target the same numbers or the cleanup does more
   destructive remapping than it needs to.
2. **Pick a chroma-key color** the subject won't contain — default pure
   magenta `#FF00FF`. If the subject is pink/red/purple, use pure green
   `#00FF00` instead; if it's plant-like/green, use `#FF00FF` or pure cyan
   `#00FFFF`. State the chosen hex explicitly, you'll need it again in phase 2.
3. **Fill this exact template, one instance per required image** — don't
   paraphrase or shorten it, every clause below is there to remove one
   specific degree of freedom ChatGPT would otherwise drift on:

   ```
   [SUBJECT], [POSE/ACTION], viewed from [ANGLE — top-down 3/4 for
   mobs/props matching this game's existing LPC-style characters; flat
   frontal for icons; whatever reads clearest at small size for VFX].

   Style: 2D pixel art sprite for a cozy medieval-fantasy MMORPG, in the
   style of classic 16-bit JRPG sprites. Render on a virtual grid of
   exactly [CANVAS_W]x[CANVAS_H] pixels, then scale up so every art-pixel
   is a large, sharp, flat-colored square block. No anti-aliasing, no
   smoothing, no soft gradients, no blur, no dithering, no glow, no drop
   shadow, no ambient occlusion. Hard 1px outlines only. Flat cel-shaded
   fills, a maximum of [N] distinct colors in the whole image.

   Composition: the subject is centered and fully visible, occupying
   70-80% of the canvas height, with a flat-color margin of at least 10%
   on all four sides — no part of it touches or is cropped by the canvas
   edge. [Animations only:] identical camera distance, identical subject
   scale, and identical ground/feet baseline as the other frames in this
   sequence — do not zoom, pan, or reposition between poses.

   Background: solid flat fill, pure [COLOR NAME] (hex [HEX]), completely
   uniform with zero gradient, zero shadow, zero vignette, filling the
   canvas edge to edge behind the subject.

   Do not include: text, watermark, signature, border, frame, perspective
   distortion, motion blur, lighting effects, or any second subject.
   ```

   Also tell the user which aspect ratio to pick in ChatGPT's image tool
   (square for a square `CANVAS`, closest available otherwise) — the
   composition margin rule above only works if the canvas ratio is close to
   `CANVAS_W:CANVAS_H` to begin with.
4. **For multi-frame animations, lock consistency across frames**: tell the
   user to generate the first (reference) frame, then for every subsequent
   frame stay in the *same* ChatGPT conversation and prompt with "same
   character — same colors, proportions, outfit and camera as the previous
   image — now show them in [pose]", attaching/referencing the earlier
   image if the ChatGPT UI allows it. Warn them explicitly: a fresh chat per
   frame will drift in scale and colors no matter how good the template is
   — that's the #1 way this pipeline produces unusable sheets, not the
   prompt wording.
5. Tell the user where to save the results:
   `game/assets/_incoming/<name>/raw/` (create it if it doesn't exist), one
   PNG per frame, named however is convenient — phase 2 renames them.
6. Set expectations once, briefly: even a precise prompt won't land on exact
   pixel dimensions or the exact color count — ChatGPT doesn't support
   that — so phase 2's downscale/quantize step still runs on everything.
   The template's job is to shrink *how much* that step has to correct, not
   to eliminate it.

Give the prompts as a numbered, copy-pasteable list. End your turn with an
explicit hand-off, e.g. "Pegá esto en ChatGPT, guardá las imágenes en
`game/assets/_incoming/<name>/raw/`, y avisame cuando estén — ahí sigo con
el recorte e import." Do not start phase 2 in the same turn, and do not poll
or check the folder yourself — wait for the user's next message.

## Phase 2 — Import

Run once the user confirms the raw PNGs are in
`game/assets/_incoming/<name>/raw/`. Everything here is a single local
script (`scripts/process_sprites.py`, Pillow-only) — no external service is
called.

1. **List the raw files** and confirm the count matches what phase 1 asked for.
2. **Run the script** with the destination filename/canvas from the
   conventions table, the chroma-key hex, and the *same* `N` you put in the
   phase 1 prompt template (`--colors`) — that's what makes the result read
   as pixel art instead of a shrunk photo. Pick one of:

   - **Single icon or prop** (one raw file → one output file):
     ```
     python .claude/skills/sprite-pipeline/scripts/process_sprites.py \
       game/assets/_incoming/<name>/raw/<file>.png \
       game/assets/<category-destination>/<final-name>.png \
       --key "<hex>" --canvas <WxH> --colors 24
     ```
     Omit `--canvas` for world props/tiles and use `--max-size <WxH>`
     instead (downscales without padding onto a transparent canvas — props
     don't share a fixed frame size in this project).

   - **Animation as separate raw files, one per frame** (a folder → a
     folder; frames share ONE derived palette so the animation doesn't
     flicker between frames):
     ```
     python .claude/skills/sprite-pipeline/scripts/process_sprites.py \
       game/assets/_incoming/<name>/raw/ \
       game/assets/<mobs-or-vfx-destination>/<name>/ \
       --key "<hex>" --canvas <WxH> --colors 24 --prefix walk
     ```
     Files are read in sorted order, so name the raw files so that sort
     order matches frame order (`01.png`, `02.png`, …). Then rename the
     script's `<prefix>_00.png`, `_01.png`, … output to the exact
     convention filenames (`walk_0.png`, `walk_1.png`, …).

   - **Animation as one sheet image** (a grid of frames in a single raw
     file), also with a shared palette across cells:
     ```
     python .claude/skills/sprite-pipeline/scripts/process_sprites.py \
       game/assets/_incoming/<name>/raw/<sheet>.png \
       game/assets/<mobs-or-vfx-destination>/<name>/ \
       --key "<hex>" --sheet-grid <COLSxROWS> --canvas <WxH> --colors 24 --prefix walk
     ```

3. **Rename the script's output** to the exact convention filenames from the
   table above if `--prefix` didn't already match (e.g. `walk_0.png` not
   `walk_00.png`), and move/confirm each file is at its final destination
   path.
4. **List the files written** and their destination paths for the user to
   review. Do not delete `_incoming/` — leave it for the user to clean up
   once they've checked the results in the Godot editor (opening the
   project once will auto-generate the missing `.import` files).
5. If anything looks off:
   - Magenta fringe/halo left around edges → re-run with a higher
     `--tolerance` (default 40).
   - Result looks like a blurry shrunk photo, not pixel art → lower
     `--colors` (try 12-16).
   - Colors drifted between animation frames → make sure you used the
     batch/sheet mode (shared palette), not several separate single-file
     invocations.
   - If none of that fixes it, ask the user to regenerate from ChatGPT with
     a more explicit "chunky pixel art, flat colors" prompt before
     reprocessing.

## Wang tilesets (curved paths, biome borders, any corner-blended terrain)

Use this instead of the normal flow whenever the ask is a terrain that
**auto-curves** where it meets another terrain — a path/road, a biome edge
(sand↔grass, water↔sand, etc.), anything painted through
`BiomeTileset`/`FloorTileset` with Godot's corner-match terrain system. It is
NOT a ChatGPT-friendly single image or animation sheet: it's 16 distinct
32x32 tiles, one per corner combination, assembled into a 131x131 sheet with
a 1px gutter — the exact format `BiomeTileset._add_pair()` /
`FloorTileset._add_wang_source()` load (see `docs/ART.md` and
`game/scripts/world/biome_tileset.gd`'s class doc for the existing pairs).
Generate art via ChatGPT ONLY — no external tileset-generation service.

### The 16-tile convention (memorize this table, it's fixed)

Every pair has a "lower" terrain (e.g. sand) and an "upper" terrain (e.g.
path). Each of the 4 corners of a cell — TL, TR, BL, BR — is independently
either terrain. Index = TL*8 + TR*4 + BL*2 + BR*1, arranged row-major into a
4x4 grid (col = index % 4, row = index / 4):

| idx | TL | TR | BL | BR | idx | TL | TR | BL | BR |
|---|---|---|---|---|---|---|---|---|---|
| 00 | lower | lower | lower | lower | 08 | upper | lower | lower | lower |
| 01 | lower | lower | lower | upper | 09 | upper | lower | lower | upper |
| 02 | lower | lower | upper | lower | 10 | upper | lower | upper | lower |
| 03 | lower | lower | upper | upper | 11 | upper | lower | upper | upper |
| 04 | lower | upper | lower | lower | 12 | upper | upper | lower | lower |
| 05 | lower | upper | lower | upper | 13 | upper | upper | lower | upper |
| 06 | lower | upper | upper | lower | 14 | upper | upper | upper | lower |
| 07 | lower | upper | upper | upper | 15 | upper | upper | upper | upper |

#0 is pure lower, #15 is pure upper — everything between is a corner/edge
piece. This is a fixed enumeration, never re-derive or renumber it.

### Phase 1 — 16 chained ChatGPT prompts (one per tile, same conversation)

Ask the user (skip what they already told you): the pair's name, the lower
terrain, the upper terrain, and what a chroma-key-free background should be
(there is no background here — see below).

1. **Generate tile #00 first as the reference** — pure lower terrain, no
   upper terrain at all, filling the whole frame edge-to-edge (this is a
   *tileable texture swatch*, not a centered subject on a background — do
   not reuse the icon/mob composition rules):

   ```
   A seamless, edge-to-edge top-down texture tile of [LOWER TERRAIN
   DESCRIPTION], for a cozy medieval-fantasy MMORPG. 2D pixel art, in the
   style of classic 16-bit JRPG tile textures. Render on a virtual grid of
   exactly 32x32 pixels, then scale up so every art-pixel is a large, sharp,
   flat-colored square block. No anti-aliasing, no soft gradients, no blur,
   no dithering, no glow, no drop shadow. Flat cel-shaded fills, a maximum
   of [N] distinct colors.

   The texture must fill the ENTIRE frame corner to corner with no border,
   margin, vignette, or background of any other color — every edge of the
   image must be ready to tile seamlessly against a copy of itself (left
   edge continues right edge, top edge continues bottom edge).

   Do not include: text, watermark, signature, border, frame, any object or
   subject, any second material, lighting falloff, or perspective distortion.
   ```

2. **For tiles #01 through #15, stay in the SAME conversation** (critical —
   a fresh chat drifts in tone/palette exactly like animation frames do) and
   reference tile #00's image each time, substituting the corner layout from
   the table above:

   ```
   Same tessellating top-down tile texture, same palette, same lighting,
   same pixel-art style and scale as the previous image — but now [N] of
   its four corners are [UPPER TERRAIN DESCRIPTION] instead: the
   [top-left/top-right/bottom-left/bottom-right corner(s)] show(s) [UPPER
   TERRAIN], the rest stays [LOWER TERRAIN]. The boundary between the two
   materials is a soft, rounded, curved edge (never a hard jagged
   staircase or a straight diagonal line) — [TRANSITION DESCRIPTION, e.g.
   "the packed path's edge crumbles gently into the looser sand"].

   Still fills the entire frame edge to edge with no border or background,
   still ready to tile seamlessly on all 4 sides.
   ```

   Translate "[N] of its four corners are..." into the actual corners for
   that index from the table (e.g. idx 5 = "the top-right and bottom-right
   corners", a vertical split; idx 6 = "the top-right and bottom-left
   corners ONLY, diagonally opposite — the top-left and bottom-right stay
   [LOWER]", a checkerboard diagonal — call out diagonal-only cases
   explicitly, they're the ones ChatGPT is likeliest to get wrong).
3. Tell the user where to save: `game/assets/_incoming/<pair_name>/raw/`,
   named `wang_00.png` through `wang_15.png` matching the index — this
   exact naming is what makes phase 2 trivial, insist on it rather than
   "however is convenient".
4. Set expectations: seamless tiling and exact corner geometry are the two
   things freeform image generation is worst at — some tiles will likely
   need a regenerate-and-retry, and a visible seam or slightly-off corner
   after assembly is normal, not a sign the prompt was wrong. Phase 2 can
   quantize color/scale but can't fix a wrong corner layout or a broken
   seam — that always means regenerating that one tile in the same
   conversation, not patching the PNG.

End your turn with an explicit hand-off, same spirit as the normal flow:
wait for the user to confirm all 16 are saved before starting phase 2.

### Phase 2 — Import

1. **List the raw files**, confirm all 16 are present and named
   `wang_00.png`..`wang_15.png`.
2. **Clean them as a batch** (shared palette across all 16, so the sheet
   doesn't flicker/drift tile to tile):
   ```
   python .claude/skills/sprite-pipeline/scripts/process_sprites.py \
     game/assets/_incoming/<pair_name>/raw/ \
     game/assets/_incoming/<pair_name>/clean/ \
     --key "<hex>" --canvas 32x32 --colors <N> --prefix wang
   ```
   Note there's no real chroma-key subject here (tiles fill the frame edge
   to edge) — pass whatever hex the raw art's corners don't contain; the
   flood-fill only strips pixels connected to the image border, so a
   correctly-generated edge-to-edge tile won't lose real content. If a tile
   comes back with content eaten from its edges, that tile touched the key
   color at its border — regenerate it with a different `--key`, or reprocess
   just that one file with `--key` disabled (small local edit) rather than
   forcing a project-wide key change.
3. **Assemble the 131x131 sheet**:
   ```
   python .claude/skills/sprite-pipeline/scripts/assemble_wang_sheet.py \
     game/assets/_incoming/<pair_name>/clean/ \
     game/assets/tiles/<pair_name>_wang.png
   ```
   It reads the 16 files in sorted order — `wang_00`..`wang_15` from step 2
   sorts correctly — and packs them at the right grid position with the 1px
   gutter. It refuses (clear error) if the count isn't exactly 16 or any
   tile isn't 32x32, rather than silently producing a malformed sheet.
4. **Wire it into code** — this is the part that's specific to this
   project's terrain system, not generic art import:
   - `game/scripts/world/biome_tileset.gd`: add an entry to `_PAIR_FILES`
     (pair id → filename) and two entries to `PAINT_KINDS` (one per
     terrain side, `{"pair": ..., "terrain": 0 or 1}`) — copy the shape of
     an existing pair exactly, terrain 0 = lower, terrain 1 = upper.
   - `game/scripts/world/build_catalog.gd`: add one `terrain_<id>` entry
     per new `PAINT_KINDS` key to `ENTRIES`, category `"terrain"` — this is
     what gives it a palette button and hotbar slot, `build_icons.gd` derives
     its icon automatically from the sheet, no icon script changes needed.
   - `game/tools/validate_build_mode.gd` hardcodes the total catalog count
     (`BuildCatalog.all_ids()` size) — bump that number by however many
     entries you added, or `run_tests.ps1`'s buildmode suite fails on a
     stale count.
5. **Validate**: `powershell -File run_tests.ps1` — the buildmode suite
   exercises every `terrain_*` id (icon resolves, palette button exists,
   `terrain_set_for()` resolves) and the boot check will surface a
   `[BiomeTileset]` size-mismatch `push_warning` if the assembled sheet
   isn't exactly 131x131 (check `run_tests.ps1`'s per-suite log under
   `%TEMP%\jueguito_tests\` if something looks off, boot warnings don't fail
   the suite but are worth grepping for).
6. Don't delete `_incoming/`; same as the normal flow, leave cleanup to the
   user.

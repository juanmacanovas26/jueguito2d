#!/usr/bin/env python3
"""Bundle a curated slice of the Universal LPC Spritesheet library into the game.

    python art_pipeline/lpc/import_lpc.py

Design rule: we follow the UPSTREAM LPC layout exactly. Sheets and sheet
definitions are copied to game/assets/lpc/ at their ORIGINAL relative paths,
byte for byte. Nothing is renamed, re-foldered or re-encoded.

Why: adding art later is then just "copy the folder from lpc/ keeping its path",
and any LPC asset pack drops in unchanged. The game reads LPC's own metadata
format instead of a translation of it.

The one thing generated is index.json — Godot cannot list res:// directories in
an exported build, so it needs an explicit index of what was bundled. It also
records each sheet's grid geometry, which is measured, never assumed.
"""
import json, os, shutil, sys
from collections import OrderedDict
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LPC = os.path.join(ROOT, "lpc")
SRC_DEFS = os.path.join(LPC, "sheet_definitions")
SRC_SHEETS = os.path.join(LPC, "spritesheets")
OUT = os.path.join(ROOT, "game", "assets", "lpc")
SELECTION = os.path.join(os.path.dirname(__file__), "selection.json")

# Every LPC directional animation is laid out as 4 rows (north, west, south,
# east); "hurt" is the exception at 1 row. So frame size = height / rows, and
# the column count falls out of the width. Deriving it this way instead of
# assuming a column count per animation is what lets the oversized weapon
# sheets (128px and 192px) identify themselves, and it caught two assets whose
# folder name does not match the animation they actually contain.
SINGLE_ROW_ANIMS = {"hurt", "climb"}

## Which LPC type_name(s) each of our slots accepts. Without this an asset name
## that exists in two categories resolves to the wrong one.
SLOT_TYPES = {
    "body": ["body"],
    "head": ["head"],
    "hair": ["hair"],
    "torso": ["clothes", "armour", "chainmail", "torso"],
    "legs": ["legs"],
    "hat": ["hat"],
    "weapon": ["weapon"],
    # A quiver shares the off-hand slot with a shield in-game (see
    # player.gd has_shield/has_arrows), so both LPC categories bucket here.
    "shield": ["shield", "quiver"],
    "feet": ["shoes"],
    "arms": ["arms"],
    "gloves": ["gloves"],
    "shoulders": ["shoulders"],
    "wrists": ["wrists", "bracers"],
}


def rows_of(lpc_anim):
    return 1 if lpc_anim in SINGLE_ROW_ANIMS else 4


def load_definitions():
    out = []
    for dp, _, fs in os.walk(SRC_DEFS):
        for fn in fs:
            if not fn.endswith(".json") or fn.startswith("meta_"):
                continue
            p = os.path.join(dp, fn)
            try:
                d = json.load(open(p, encoding="utf-8"))
            except Exception:
                continue
            if d.get("name"):
                out.append((d, p))
    return out


def pick_variant(d, prefs):
    variants = d.get("variants") or []
    if not variants:
        return None
    for p in prefs:
        if p in variants:
            return p
    return variants[0]


def copy_verbatim(rel_path, src_root, dst_root):
    src = os.path.join(src_root, rel_path)
    dst = os.path.join(dst_root, rel_path)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if not os.path.exists(dst):
        shutil.copyfile(src, dst)
    return dst


def geometry(png_path, lpc_anim):
    rows = rows_of(lpc_anim)
    with Image.open(png_path) as im:
        w, h = im.size
    frame = h // rows
    cols = w // frame if frame else 0
    return OrderedDict(frame=frame, cols=cols, rows=rows, width=w, height=h)


def main():
    sel = json.load(open(SELECTION, encoding="utf-8"))
    body_type = sel.get("body_type", "male")
    anim_map = {k: v for k, v in sel["animations"].items() if not k.startswith("_")}
    attack_layers = {k: v for k, v in sel.get("attack_layers", {}).items()
                     if not k.startswith("_")}
    fallbacks = {k: v for k, v in sel.get("fallbacks", {}).items() if not k.startswith("_")}
    prefs = sel.get("variant_preference", [])
    include = sel["include"]

    # Path segment -> the game animation a layer in that folder belongs to.
    seg_owner = dict(attack_layers.items())
    for ga, la in anim_map.items():
        seg_owner.setdefault(la, ga)

    # A display name is only unique WITHIN a category: LPC has an "Armour" for
    # the torso and another for the legs. Keying on the name alone made the legs
    # resolve to the chest plate's sheets. Slots are matched against type_name.
    wanted = {}
    for slot, names in include.items():
        for n in names:
            wanted[(slot, n)] = True

    defs = load_definitions()
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)

    index = OrderedDict(
        format="lpc-upstream-v1", body_type=body_type,
        directions=["north", "west", "south", "east"],
        animations=anim_map, pieces=OrderedDict(),
    )
    problems, sheets, seen, borrowed = [], 0, set(), []
    # Frame counts the body defines; every other layer must match per animation.
    body_geometry = {}
    for game_anim, lpc_anim in anim_map.items():
        bp = os.path.join(SRC_SHEETS, f"body/bodies/{body_type}/{lpc_anim}.png")
        if os.path.exists(bp):
            body_geometry[game_anim] = geometry(bp, lpc_anim)["cols"]
    print("body frame counts: " + ", ".join(f"{k}={v}" for k, v in body_geometry.items()))

    for (slot, name) in wanted:
        matches = [(d, p) for d, p in defs
                   if d.get("name") == name
                   and str(d.get("type_name", "")) in SLOT_TYPES.get(slot, [slot])
                   and any(k.startswith("layer_") and isinstance(v, dict) and v.get(body_type)
                           for k, v in d.items())]
        if not matches:
            problems.append(f"'{name}' ({slot}): no definition with type_name in "
                            f"{SLOT_TYPES.get(slot, [slot])} and a '{body_type}' layer")
            continue
        if len(matches) > 1:
            problems.append(f"'{name}' ({slot}): {len(matches)} definitions match; using "
                            f"{os.path.relpath(matches[0][1], ROOT)}")
        d, defpath = matches[0]
        variant = pick_variant(d, prefs)
        def_rel = os.path.relpath(defpath, SRC_DEFS).replace("\\", "/")
        copy_verbatim(def_rel, SRC_DEFS, os.path.join(OUT, "sheet_definitions"))

        entry = OrderedDict(name=name, slot=slot, type_name=d.get("type_name", ""),
                            definition=def_rel, variant=variant, layers=[])

        for k, v in sorted(d.items()):
            if not k.startswith("layer_") or not isinstance(v, dict):
                continue
            rel_dir = (v.get(body_type) or "").strip("/")
            if not rel_dir:
                continue
            # LPC weapons come in three path shapes and the folder tells you
            # which: a melee swing lives in its own attack_* folder, a bow keeps
            # its walk art in a walk/ folder, and everything else nests the
            # animation inside a universal layer. When a path SEGMENT names an
            # animation, that layer belongs to it and the file is just the
            # variant; otherwise the animation is a subfolder.
            segments = rel_dir.strip("/").split("/")
            owner_anim = ""
            for seg in segments:
                if seg in seg_owner:
                    owner_anim = seg_owner[seg]
                    break
            is_attack_layer = owner_anim != ""
            if owner_anim == "" and any(s.startswith("attack_") for s in segments):
                continue  # a swing we do not use (reverse, halfslash...)
            for game_anim, lpc_anim in anim_map.items():
                if is_attack_layer and game_anim != owner_anim:
                    continue
                # An attack layer bakes the animation into its folder name, so
                # its file is just the variant. Every other layer keeps the
                # animation in the path — never fall back to the bare variant
                # there, or one sheet gets claimed by every animation.
                cands = []
                if is_attack_layer:
                    if variant:
                        cands.append(f"{rel_dir}/{variant}.png")
                    cands.append(f"{rel_dir}/{lpc_anim}.png")
                else:
                    if variant:
                        cands.append(f"{rel_dir}/{lpc_anim}/{variant}.png")
                    cands.append(f"{rel_dir}/{lpc_anim}.png")
                rel = next((c for c in cands if os.path.exists(os.path.join(SRC_SHEETS, c))), None)
                borrowed_from = ""
                if rel is None and not is_attack_layer and game_anim in fallbacks:
                    # Declared fallback: this layer has no art for the animation,
                    # so it borrows another one (see selection.json "fallbacks").
                    fb_game = fallbacks[game_anim]
                    fb_lpc = anim_map.get(fb_game, fb_game)
                    fb_cands = ([f"{rel_dir}/{fb_lpc}/{variant}.png"] if variant else []) +                                [f"{rel_dir}/{fb_lpc}.png"]
                    rel = next((c for c in fb_cands if os.path.exists(os.path.join(SRC_SHEETS, c))), None)
                    if rel is not None:
                        borrowed_from = fb_game
                if rel is None:
                    continue
                dst = copy_verbatim(rel, SRC_SHEETS, os.path.join(OUT, "spritesheets"))
                if rel not in seen:
                    seen.add(rel)
                    sheets += 1
                geo = geometry(dst, lpc_anim)
                if geo["frame"] % 64 != 0 or geo["frame"] == 0:
                    problems.append(f"'{name}' {rel}: frame {geo['frame']}px is not a multiple of 64")
                body_cols = body_geometry.get(borrowed_from or game_anim)
                if body_cols and geo["cols"] != body_cols:
                    problems.append(
                        f"'{name}' {rel}: {geo['cols']} frames for '{game_anim}' but the body has "
                        f"{body_cols} — this layer would desync")
                layer_rec = OrderedDict(
                    z=int(v.get("zPos", 0)), layer=k, animation=game_anim,
                    sheet=rel, **geo)
                if borrowed_from:
                    layer_rec["borrowed_from"] = borrowed_from
                    borrowed.append(f"{name}: '{game_anim}' borrows '{borrowed_from}' art")
                entry["layers"].append(layer_rec)
        if not entry["layers"]:
            problems.append(f"'{name}' ({slot}): resolved no sheets (variant={variant})")
            continue
        index["pieces"][f"{slot}/{name}"] = entry

    os.makedirs(OUT, exist_ok=True)
    json.dump(index, open(os.path.join(OUT, "index.json"), "w", encoding="utf-8"), indent=1)

    print(f"pieces  : {len(index['pieces'])} / {len(wanted)} requested")
    print(f"sheets  : {sheets} copied (upstream paths preserved)")
    print(f"output  : {os.path.relpath(OUT, ROOT)}")
    if problems:
        print(f"\nproblems ({len(problems)}):")
        for p in problems:
            print("  " + p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

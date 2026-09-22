class_name BuildIcons
extends RefCounted
## Palette + placement-ghost icons for build mode (hud.gd's BuildPanel,
## world_zone.gd's cursor preview). Reuses the real art resource_node.gd and
## chase_mob.gd already load where it exists; POI kinds have no in-world
## sprite yet, so they get a small procedural icon — same approach as
## item_icons.gd for inventory icons.
##
## Icons are cached — a given kind is only ever drawn/resized once.

const SIZE := 32

## kind -> the real prop art it shares with resource_node.gd (see ART_PATHS
## there). Kept as its own const rather than importing ResourceNode's, since
## this only needs the path, not the whole node.
const RESOURCE_ART := {
	"tree": "res://assets/world/tree.png",
	"rock": "res://assets/world/rock.png",
	"vein": "res://assets/world/vein.png",
}
const MOB_ART := "res://assets/mobs/slime/idle.png"

## Shape id (StructureTileset.WALL_PIECES, plus "floor") -> its icon art,
## always rendered in the "stone" material — the icon shows the SHAPE the
## button places; Game.build_wall_material (chosen separately, see hud.gd)
## decides which material it actually paints with.
const STRUCTURE_ART := {
	"wall_n": "res://assets/world/structures/kit/stone/wall_n.png",
	"wall_e": "res://assets/world/structures/kit/stone/wall_e.png",
	"wall_s": "res://assets/world/structures/kit/stone/wall_s.png",
	"wall_w": "res://assets/world/structures/kit/stone/wall_w.png",
	"corner_out_ne": "res://assets/world/structures/kit/stone/corner_out_ne.png",
	"corner_out_nw": "res://assets/world/structures/kit/stone/corner_out_nw.png",
	"corner_out_se": "res://assets/world/structures/kit/stone/corner_out_se.png",
	"corner_out_sw": "res://assets/world/structures/kit/stone/corner_out_sw.png",
	"corner_in_ne": "res://assets/world/structures/kit/stone/corner_in_ne.png",
	"corner_in_nw": "res://assets/world/structures/kit/stone/corner_in_nw.png",
	"corner_in_se": "res://assets/world/structures/kit/stone/corner_in_se.png",
	"corner_in_sw": "res://assets/world/structures/kit/stone/corner_in_sw.png",
	"partition_n": "res://assets/world/structures/kit/stone/partition_n.png",
	"partition_e": "res://assets/world/structures/kit/stone/partition_e.png",
	"partition_s": "res://assets/world/structures/kit/stone/partition_s.png",
	"partition_w": "res://assets/world/structures/kit/stone/partition_w.png",
	"partition_hub": "res://assets/world/structures/kit/stone/partition_hub.png",
	"column": "res://assets/world/structures/kit/stone/column.png",
	"floor": "res://assets/world/structures/kit/floor.png",
	"door": "res://assets/world/structures/door.png",
	"window_arched": "res://assets/world/decor/window_arched.png",
	"window_small": "res://assets/world/decor/window_small.png",
	"window_medium": "res://assets/world/decor/window_medium.png",
	"window_large": "res://assets/world/decor/window_large.png",
	"window_flowerbox": "res://assets/world/decor/window_flowerbox.png",
	"torch": "res://assets/world/decor/torch.png",
}

## "roof_<piece>" palette id -> its icon art, always rendered in the "slate"
## material — same split as STRUCTURE_ART: the icon shows the shape,
## Game.build_roof_material decides the material.
const ROOF_ART := {
	"roof_eave_n": "res://assets/world/structures/kit/roof_slate/eave_n.png",
	"roof_eave_e": "res://assets/world/structures/kit/roof_slate/eave_e.png",
	"roof_eave_s": "res://assets/world/structures/kit/roof_slate/eave_s.png",
	"roof_eave_w": "res://assets/world/structures/kit/roof_slate/eave_w.png",
	"roof_hip_ne": "res://assets/world/structures/kit/roof_slate/hip_ne.png",
	"roof_hip_nw": "res://assets/world/structures/kit/roof_slate/hip_nw.png",
	"roof_hip_se": "res://assets/world/structures/kit/roof_slate/hip_se.png",
	"roof_hip_sw": "res://assets/world/structures/kit/roof_slate/hip_sw.png",
	"roof_valley_ne": "res://assets/world/structures/kit/roof_slate/valley_ne.png",
	"roof_valley_nw": "res://assets/world/structures/kit/roof_slate/valley_nw.png",
	"roof_valley_se": "res://assets/world/structures/kit/roof_slate/valley_se.png",
	"roof_valley_sw": "res://assets/world/structures/kit/roof_slate/valley_sw.png",
	"roof_ridge_ew": "res://assets/world/structures/kit/roof_slate/ridge_ew.png",
	"roof_ridge_ns": "res://assets/world/structures/kit/roof_slate/ridge_ns.png",
	"roof_end_n": "res://assets/world/structures/kit/roof_slate/end_n.png",
	"roof_end_e": "res://assets/world/structures/kit/roof_slate/end_e.png",
	"roof_end_s": "res://assets/world/structures/kit/roof_slate/end_s.png",
	"roof_end_w": "res://assets/world/structures/kit/roof_slate/end_w.png",
	"roof_pyramid": "res://assets/world/structures/kit/roof_slate/pyramid.png",
	"roof_interior": "res://assets/world/structures/kit/roof_slate/interior.png",
}

const POI_COLORS := {
	"vendor": Color(0.3, 0.55, 0.85),
	"bank": Color(0.75, 0.65, 0.15),
	"repair": Color(0.5, 0.5, 0.85),
	"dungeon_entrance": Color(0.55, 0.15, 0.6),
	"mini_boss": Color(0.75, 0.1, 0.1),
}

static var _cache: Dictionary = {}


## `facing_steps` only matters for a "building_<kind>" whose art is a real
## 4-direction set (BuildingMarker.has_directional_art()) — the build-mode
## ghost preview passes the facing it's about to place at (see
## build_ghost.gd) so the preview shows the right sprite instead of always
## the front one. Every other kind ignores it.
static func get_icon(kind: String, facing_steps: int = 0) -> Texture2D:
	var cache_key := "%s#%d" % [kind, facing_steps]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var tex := _build(kind, facing_steps)
	_cache[cache_key] = tex
	return tex


static func clear_cache() -> void:
	_cache.clear()


static func _build(kind: String, facing_steps: int) -> Texture2D:
	if kind == "mob":
		return _load_square(MOB_ART)
	if RESOURCE_ART.has(kind):
		return _load_square(str(RESOURCE_ART[kind]))
	if STRUCTURE_ART.has(kind):
		return _load_square(str(STRUCTURE_ART[kind]))
	if ROOF_ART.has(kind):
		return _load_square(str(ROOF_ART[kind]))
	if kind.begins_with("decor_"):
		return _load_square(DecorMarker.texture_path(kind.trim_prefix("decor_")))
	if PaintLayer.is_paint_id(kind):
		return _load_square(PaintLayer.texture_path(PaintLayer.texture_of(kind)))
	if kind.begins_with("floor_"):
		return _load_square(PaintedFloorTileset.path_for(kind.trim_prefix("floor_")))
	if kind.begins_with("building_"):
		return _load_square(BuildingMarker.texture_path(kind.trim_prefix("building_"), facing_steps))
	if kind.begins_with("collision_"):
		return _collision_icon()
	if POI_COLORS.has(kind):
		return _poi_icon(kind, POI_COLORS[kind])
	return _blank()


## No in-world sprite of its own (see collision_marker.gd) — a plain "no
## entry" glyph, same procedural-icon spirit as POI_COLORS below.
static func _collision_icon() -> Texture2D:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(0.85, 0.2, 0.2, 0.9)
	for i in range(6, 26):
		_px(img, i, i, c)
		_px(img, i, i - 1, c)
		_px(img, i, 31 - i, c)
		_px(img, i, 32 - i, c)
	return ImageTexture.create_from_image(img)


## Real art doesn't need pre-resizing to SIZE — the palette buttons already
## have expand_icon=true (scales to fit the button) and the world ghost
## preview draws through draw_texture_rect (scales to fit its target rect),
## so both callers fit whatever native size this returns on their own.
## (An earlier version round-tripped through Image.get_image()/resize() here
## — unnecessary, and fragile: a texture whose import format can't convert
## back to a CPU Image raises an error that aborted hud.gd's whole button-
## wiring loop partway through, silently leaving every kind after the first
## un-clickable.)
static func _load_square(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return _blank()
	var tex: Resource = load(path)
	return tex as Texture2D if tex is Texture2D else _blank()


static func _poi_icon(kind: String, color: Color) -> Texture2D:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark := Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 1.0)
	match kind:
		"vendor":
			_disc(img, 16, 18, 9, color)
			_rect(img, 13, 6, 6, 6, dark) # coin-purse tie
		"bank":
			_rect(img, 6, 16, 20, 11, color)     # vault body
			_rect(img, 6, 16, 20, 3, dark)       # roofline
			_disc(img, 16, 21, 3, dark)          # dial
		"repair":
			_rect(img, 14, 5, 4, 22, color)      # wrench shaft
			_disc(img, 16, 8, 6, color)
			_disc(img, 16, 8, 3, Color(0, 0, 0, 0))
		"dungeon_entrance":
			_rect(img, 9, 8, 14, 18, dark)
			_disc(img, 16, 8, 7, dark)
			_rect(img, 12, 12, 8, 14, color)     # doorway
		"mini_boss":
			_disc(img, 16, 16, 10, color)
			_rect(img, 9, 8, 3, 6, dark)         # horns
			_rect(img, 20, 8, 3, 6, dark)
		_:
			_disc(img, 16, 16, 10, color)
	return ImageTexture.create_from_image(img)


static func _blank() -> Texture2D:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 0.6))
	return ImageTexture.create_from_image(img)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for dy in h:
		for dx in w:
			_px(img, x + dx, y + dy, c)


static func _disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				_px(img, cx + dx, cy + dy, c)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return
	img.set_pixel(x, y, c)

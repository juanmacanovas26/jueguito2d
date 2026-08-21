class_name LpcLibrary
extends RefCounted
## Reads the bundled slice of the Universal LPC Spritesheet library.
##
## The art keeps LPC's own layout and metadata (see art_pipeline/lpc/), so this
## is a thin reader over index.json rather than a translation layer. Adding art
## means re-running the importer; nothing here changes.
##
## LPC facts this encodes, all measured at import time rather than assumed:
## - frames are laid out as a grid, one ROW per direction, in the order
##   north, west, south, east;
## - "hurt" is the one animation with a single row;
## - a layer's frame size is its own (64px for bodies and worn gear, 128 or
##   192 for weapons whose swing arc leaves the body box). Layers of different
##   sizes still line up because every frame is centred on the same origin.

const INDEX_PATH := "res://assets/lpc/index.json"
const SHEET_ROOT := "res://assets/lpc/spritesheets"

## LPC row order. Our Direction enum is ordered differently, so this is the
## bridge; it is the ONLY place that knows LPC's row convention.
const DIRECTION_ROW := {
	CharacterFacing.Direction.NORTH: 0,
	CharacterFacing.Direction.WEST: 1,
	CharacterFacing.Direction.SOUTH: 2,
	CharacterFacing.Direction.EAST: 3,
}

static var _index: Dictionary = {}
static var _atlas_cache: Dictionary = {}
static var _sheet_cache: Dictionary = {}
static var _loaded := false


static func load_index() -> Dictionary:
	if _loaded:
		return _index
	_loaded = true
	if not FileAccess.file_exists(INDEX_PATH):
		push_error("[LpcLibrary] %s missing — run art_pipeline/lpc/import_lpc.py" % INDEX_PATH)
		return _index
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[LpcLibrary] %s is not valid JSON" % INDEX_PATH)
		return _index
	_index = parsed
	return _index


## All piece keys, e.g. "hair/Afro", "weapon/Arming Sword".
static func piece_keys() -> Array:
	return load_index().get("pieces", {}).keys()


static func pieces_in_slot(slot: String) -> Array:
	var out: Array = []
	for key in piece_keys():
		if str(key).begins_with(slot + "/"):
			out.append(key)
	out.sort()
	return out


static func get_piece(key: String) -> Dictionary:
	return load_index().get("pieces", {}).get(key, {})


static func has_piece(key: String) -> bool:
	return load_index().get("pieces", {}).has(key)


## Every layer a piece draws for one animation, already sorted back-to-front by
## LPC's zPos. A piece can contribute several layers (a weapon splits into the
## part behind the body and the part in front of it).
static func layers_for(piece_key: String, anim: StringName) -> Array:
	var piece := get_piece(piece_key)
	var out: Array = []
	for layer in piece.get("layers", []):
		if StringName(str(layer.get("animation", ""))) == anim:
			out.append(layer)
	out.sort_custom(func(a, b): return int(a.get("z", 0)) < int(b.get("z", 0)))
	return out


## How many frames this piece's art actually has for an animation. Returns 0
## when the piece does not cover it at all.
static func frame_count(piece_key: String, anim: StringName) -> int:
	var best := 0
	for layer in layers_for(piece_key, anim):
		best = maxi(best, int(layer.get("cols", 0)))
	return best


## One frame of one layer, as an AtlasTexture over the shared sheet — no
## per-frame image is ever created or copied.
static func frame_texture(layer: Dictionary, d: CharacterFacing.Direction, frame: int) -> Texture2D:
	var sheet_rel := str(layer.get("sheet", ""))
	if sheet_rel == "":
		return null
	var size := int(layer.get("frame", 64))
	var cols := int(layer.get("cols", 0))
	var rows := int(layer.get("rows", 0))
	if size <= 0 or cols <= 0 or rows <= 0:
		return null
	var col := clampi(frame, 0, cols - 1)
	# Single-row animations (hurt) only exist facing one way.
	var row := 0 if rows == 1 else int(DIRECTION_ROW.get(d, 2))
	row = clampi(row, 0, rows - 1)

	var key := "%s|%d|%d" % [sheet_rel, col, row]
	if _atlas_cache.has(key):
		return _atlas_cache[key]

	var sheet := _load_sheet(sheet_rel)
	if sheet == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(col * size, row * size, size, size)
	# Keeps the region from bleeding into its neighbours at non-integer offsets.
	atlas.filter_clip = true
	_atlas_cache[key] = atlas
	return atlas


static func _load_sheet(rel: String) -> Texture2D:
	if _sheet_cache.has(rel):
		return _sheet_cache[rel]
	var path := "%s/%s" % [SHEET_ROOT, rel]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			tex = res
	else:
		push_error("[LpcLibrary] missing sheet %s" % path)
	_sheet_cache[rel] = tex
	return tex


static func clear_cache() -> void:
	_index.clear()
	_atlas_cache.clear()
	_sheet_cache.clear()
	_loaded = false

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

const POI_COLORS := {
	"vendor": Color(0.3, 0.55, 0.85),
	"bank": Color(0.75, 0.65, 0.15),
	"repair": Color(0.5, 0.5, 0.85),
	"dungeon_entrance": Color(0.55, 0.15, 0.6),
	"mini_boss": Color(0.75, 0.1, 0.1),
}

static var _cache: Dictionary = {}


static func get_icon(kind: String) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	var tex := _build(kind)
	_cache[kind] = tex
	return tex


static func clear_cache() -> void:
	_cache.clear()


static func _build(kind: String) -> Texture2D:
	if kind == "mob":
		return _load_square(MOB_ART)
	if RESOURCE_ART.has(kind):
		return _load_square(str(RESOURCE_ART[kind]))
	if POI_COLORS.has(kind):
		return _poi_icon(kind, POI_COLORS[kind])
	return _blank()


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

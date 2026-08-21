class_name ItemIcons
extends RefCounted
## Procedural inventory icons, drawn from data ItemDB already has.
##
## Items carry a `color` and a `type` but no artwork, so the inventory used to
## be a wall of text. Rather than block the UI on 18 hand-drawn icons, each type
## gets a recognisable silhouette tinted with the item's own colour. Real art
## can replace this later the same way PlaceholderSprite works: drop the PNGs in
## and point `_load_real_icon()` at them.
##
## Icons are cached — a given item id is only ever drawn once.

const SIZE := 32
## Where hand-drawn icons go when they exist. Checked before drawing.
const ICON_DIR := "res://assets/icons"

## rarity -> the colour its NAME is written in. Beyond the two tiers in ItemDB
## today, so the ladder in docs/GDD.md works without touching this again.
const RARITY_COLORS := {
	"common": Color(0.88, 0.88, 0.85),
	"uncommon": Color(0.45, 0.85, 0.45),
	"rare": Color(0.40, 0.65, 1.0),
	"epic": Color(0.72, 0.45, 0.95),
	"legendary": Color(1.0, 0.65, 0.25),
	"mythic": Color(1.0, 0.35, 0.35),
}

static var _cache: Dictionary = {}


static func get_icon(item_id: String) -> Texture2D:
	if _cache.has(item_id):
		return _cache[item_id]
	var tex := _load_real_icon(item_id)
	if tex == null:
		tex = _lpc_icon(item_id)
	if tex == null:
		tex = _draw(item_id)
	_cache[item_id] = tex
	return tex


## Equipment shows the real LPC art it will appear as when worn, cropped from
## the south-facing idle frame. Beats a procedural guess: what you see in the
## bag is literally what goes on the character.
##
## Weapons are drawn held in the hand rather than as a standalone object, so
## their idle frame is mostly the (invisible) character. Their oversized attack
## sheets show the blade clearly instead, so that is what gets cropped.
static func _lpc_icon(item_id: String) -> Texture2D:
	var def := ItemDB.get_item(item_id)
	var visual_state := str(def.get("visual_state", ""))
	if visual_state == "":
		return null
	var piece := LpcEquipment.piece_for(str(def.get("type", "")), visual_state)
	if piece == "":
		return null
	var anim := &"attack" if str(def.get("type", "")) == "weapon" else &"idle"
	var layers := LpcLibrary.layers_for(piece, anim)
	if layers.is_empty():
		return null

	# Compose the piece's own layers onto a transparent square.
	var canvas: int = 0
	for l in layers:
		canvas = maxi(canvas, int(l.get("frame", 64)))
	if canvas <= 0:
		return null
	var img := Image.create(canvas, canvas, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var drew := false
	for l in layers:
		var tex := LpcLibrary.frame_texture(l, CharacterFacing.Direction.SOUTH, _icon_frame(l, anim))
		if tex == null:
			continue
		var src := tex.get_image()
		if src == null:
			continue
		var f: int = src.get_width()
		var off := (canvas - f) / 2
		img.blend_rect(src, Rect2i(0, 0, f, f), Vector2i(off, off))
		drew = true
	if not drew:
		return null
	var box := img.get_used_rect()
	if box.size.x <= 0 or box.size.y <= 0:
		return null
	# Crop to what is actually drawn, then pad back to a square so nothing is
	# stretched — icons must stay pixel-accurate.
	var side: int = maxi(box.size.x, box.size.y)
	var out := Image.create(side, side, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blend_rect(img, box, Vector2i((side - box.size.x) / 2, (side - box.size.y) / 2))
	return ImageTexture.create_from_image(out)


## Which frame reads best as a still. Mid-swing shows a weapon fully extended.
static func _icon_frame(layer: Dictionary, anim: StringName) -> int:
	var cols := int(layer.get("cols", 1))
	if anim == &"attack":
		return clampi(int(cols * 0.7), 0, cols - 1)
	return 0


static func rarity_color(item_id: String) -> Color:
	var rarity := str(ItemDB.get_item(item_id).get("rarity", "common"))
	return RARITY_COLORS.get(rarity, RARITY_COLORS["common"])


static func clear_cache() -> void:
	_cache.clear()


## Hand-drawn icon if someone made one: res://assets/icons/<item_id>.png
static func _load_real_icon(item_id: String) -> Texture2D:
	var path := "%s/%s.png" % [ICON_DIR, item_id]
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	return res if res is Texture2D else null


static func _draw(item_id: String) -> Texture2D:
	var def := ItemDB.get_item(item_id)
	var base: Color = def.get("color", Color.WHITE)
	var dark := Color(base.r * 0.55, base.g * 0.55, base.b * 0.55, 1.0)
	var light := Color(minf(base.r * 1.35, 1.0), minf(base.g * 1.35, 1.0), minf(base.b * 1.35, 1.0), 1.0)

	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	match str(def.get("type", "misc")):
		"weapon":
			_weapon(img, base, dark, light, item_id)
		"armor":
			_armor(img, base, dark, light)
		"helmet":
			_helmet(img, base, dark, light)
		"secondary":
			if item_id.contains("tome") or item_id.contains("book"):
				_tome(img, base, dark, light)
			else:
				_shield(img, base, dark, light)
		"consumable":
			_flask(img, base, dark, light)
		"currency":
			_coin(img, base, dark, light)
		_:
			_chunk(img, base, dark, light)
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ shapes
# Kept deliberately blocky: these read better at 24px than detailed drawings.


static func _weapon(img: Image, base: Color, dark: Color, light: Color, item_id: String) -> void:
	var staff := item_id.contains("staff")
	if staff:
		_rect(img, 15, 6, 3, 22, base)          # shaft
		_rect(img, 15, 6, 3, 22, base)
		_disc(img, 16, 6, 5, light)             # orb
		_disc(img, 16, 6, 3, base)
		return
	# blade, pointing up-right
	for i in 16:
		_rect(img, 8 + i, 22 - i, 3, 3, base if i % 3 else light)
	_rect(img, 7, 20, 8, 3, dark)               # crossguard
	_rect(img, 5, 22, 5, 5, dark)               # grip
	_rect(img, 4, 26, 4, 3, dark)               # pommel


static func _armor(img: Image, base: Color, dark: Color, light: Color) -> void:
	_rect(img, 8, 8, 16, 4, dark)               # shoulders
	_rect(img, 6, 10, 20, 12, base)             # chest
	_rect(img, 9, 22, 14, 4, dark)              # skirt
	_rect(img, 14, 12, 4, 8, light)             # centre highlight


static func _helmet(img: Image, base: Color, dark: Color, light: Color) -> void:
	_disc(img, 16, 15, 9, base)                 # dome
	_rect(img, 7, 15, 18, 8, base)
	_rect(img, 10, 17, 12, 3, dark)             # visor slit
	_rect(img, 7, 23, 18, 3, dark)              # rim
	_rect(img, 15, 6, 2, 5, light)              # crest


static func _shield(img: Image, base: Color, dark: Color, light: Color) -> void:
	_rect(img, 8, 6, 16, 14, base)
	for i in 8:                                  # tapered bottom
		_rect(img, 8 + i, 20 + i, 16 - i * 2, 1, base)
	_rect(img, 8, 6, 16, 2, dark)
	_rect(img, 14, 10, 4, 10, light)             # boss


static func _tome(img: Image, base: Color, dark: Color, light: Color) -> void:
	_rect(img, 7, 7, 18, 18, base)
	_rect(img, 7, 7, 3, 18, dark)                # spine
	_rect(img, 12, 11, 9, 2, light)              # pages
	_rect(img, 12, 15, 9, 2, light)
	_rect(img, 12, 19, 6, 2, light)


static func _flask(img: Image, base: Color, dark: Color, light: Color) -> void:
	_rect(img, 13, 5, 6, 5, dark)                # neck
	_rect(img, 11, 8, 10, 3, dark)               # lip
	_disc(img, 16, 20, 8, base)                  # bulb
	_disc(img, 13, 17, 3, light)                 # glint


static func _coin(img: Image, base: Color, dark: Color, light: Color) -> void:
	_disc(img, 16, 16, 10, dark)
	_disc(img, 16, 16, 8, base)
	_disc(img, 13, 13, 3, light)


static func _chunk(img: Image, base: Color, dark: Color, light: Color) -> void:
	_rect(img, 9, 13, 14, 11, base)
	_rect(img, 12, 8, 9, 6, base)
	_rect(img, 9, 22, 14, 2, dark)
	_rect(img, 13, 10, 4, 4, light)


# ------------------------------------------------------------------ helpers


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

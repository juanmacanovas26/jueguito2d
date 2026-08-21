class_name SkillIcons
extends RefCounted
## Skill-bar icons, mirroring ItemIcons' 3-tier fallback exactly.
##
## Tier 1: a hand-drawn res://assets/icons/skill_<id>.png, if someone made one.
## Tier 2: a still frame cropped out of the skill's own VfxLibrary effect, if it
## has one — reuses real in-game art instead of drawing a guess.
## Tier 3: fully procedural, shaped generically from targeting_of()+dash_speed
## rather than per-id, so a future mutation-generated skill id still gets a
## sane icon with zero code changes.
##
## Icons are cached — a given skill id is only ever drawn once.

const SIZE := 32
const ICON_DIR := "res://assets/icons"

static var _cache: Dictionary = {}


static func get_icon(skill_id: String) -> Texture2D:
	if _cache.has(skill_id):
		return _cache[skill_id]
	var tex := _load_real_icon(skill_id)
	if tex == null:
		tex = _vfx_icon(skill_id)
	if tex == null:
		tex = _draw(skill_id)
	_cache[skill_id] = tex
	return tex


static func clear_cache() -> void:
	_cache.clear()


## Hand-drawn icon if someone made one: res://assets/icons/skill_<id>.png
static func _load_real_icon(skill_id: String) -> Texture2D:
	var path := "%s/skill_%s.png" % [ICON_DIR, skill_id]
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	return res if res is Texture2D else null


## A still cropped from the skill's own VFX, if it has one. `visual_effect`
## (the flight sprite) wins over `impact_vfx`/`end_vfx` (a landing burst) since
## it is the skill's signature look; the middle frame of the animation is used
## since VFX bursts grow-then-fade and the middle frame is closest to "fully
## bloomed" (frame 0 is near-empty, the last frame is dissolving away).
static func _vfx_icon(skill_id: String) -> Texture2D:
	var s := SkillDB.get_skill(skill_id)
	var effect_id := ""
	for field in ["visual_effect", "impact_vfx", "end_vfx"]:
		effect_id = str(s.get(field, ""))
		if effect_id != "":
			break
	if effect_id == "":
		return null
	var frames := VfxLibrary.frames_for(effect_id)
	if frames.is_empty():
		return null
	var tex := frames[frames.size() / 2]
	var src := tex.get_image()
	if src == null:
		return null
	var box := src.get_used_rect()
	if box.size.x <= 0 or box.size.y <= 0:
		return null
	# Crop to what is actually drawn, then pad back to a square — same rule as
	# ItemIcons._lpc_icon, nothing gets stretched.
	var side: int = maxi(box.size.x, box.size.y)
	var out := Image.create(side, side, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blend_rect(src, box, Vector2i((side - box.size.x) / 2, (side - box.size.y) / 2))
	return ImageTexture.create_from_image(out)


static func _draw(skill_id: String) -> Texture2D:
	var s := SkillDB.get_skill(skill_id)
	var base: Color = s.get("color", Color.WHITE)
	var dark := Color(base.r * 0.55, base.g * 0.55, base.b * 0.55, 1.0)
	var light := Color(minf(base.r * 1.35, 1.0), minf(base.g * 1.35, 1.0), minf(base.b * 1.35, 1.0), 1.0)

	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var has_dash := float(s.get("dash_speed", 0.0)) > 0.0
	match _shape_for(SkillDB.targeting_of(skill_id), has_dash):
		"dash":
			_dash(img, base, dark, light)
		"swirl":
			_swirl(img, base, dark, light)
		"spikes":
			_spikes(img, base, dark, light)
		"arrow":
			_arrow(img, base, dark, light)
		_:
			_reticle(img, base, dark, light)
	return ImageTexture.create_from_image(img)


## Shape choice, exposed standalone so it can be tested directly without
## needing five real skills that happen to hit each branch.
static func _shape_for(targeting: SkillDB.Targeting, has_dash: bool) -> String:
	match targeting:
		SkillDB.Targeting.SELF:
			return "dash" if has_dash else "swirl"
		SkillDB.Targeting.GROUND_AOE:
			return "spikes"
		SkillDB.Targeting.SKILLSHOT:
			return "arrow"
		_:
			return "reticle"


# ------------------------------------------------------------------ shapes
# Kept deliberately blocky: these read better at 32px than detailed drawings.


static func _dash(img: Image, base: Color, dark: Color, light: Color) -> void:
	for i in 3:
		_rect(img, 4 + i * 5, 13, 3, 6, dark)        # trailing motion ticks
	for i in 10:
		var w := 10 - i
		_rect(img, 19 + i, 16 - w / 2, 1, w, base if i % 3 else light)  # chevron head


static func _swirl(img: Image, base: Color, dark: Color, light: Color) -> void:
	_disc(img, 16, 16, 12, dark)
	for w in range(6):
		var a := TAU * float(w) / 6.0
		var cx := 16 + int(cos(a) * 6)
		var cy := 16 + int(sin(a) * 6)
		_disc(img, cx, cy, 3, base if w % 2 else light)
	_disc(img, 16, 16, 3, light)


static func _spikes(img: Image, base: Color, dark: Color, light: Color) -> void:
	_disc(img, 16, 20, 7, dark)                      # ground shadow
	for a in [PI * 0.5, PI * 1.166, PI * 1.833]:      # 3 outward spikes
		for i in 9:
			var t := float(i) / 8.0
			var x := 16 + int(cos(a) * t * 11)
			var y := 20 - int(sin(a) * t * 11)
			_px(img, x, y, base if i % 2 else light)
			_px(img, x + 1, y, base)


static func _arrow(img: Image, base: Color, dark: Color, light: Color) -> void:
	_rect(img, 6, 15, 16, 3, dark)                   # shaft
	for i in 8:
		_rect(img, 21 + i, 16 - i / 2, 1, 1 + i, base if i % 2 else light)  # head


static func _reticle(img: Image, base: Color, dark: Color, light: Color) -> void:
	for i in 12:
		var t := float(i) / 11.0
		var x := 16 + int(lerp(-9.0, 9.0, t))
		var yoff := int(9.0 * (1.0 - absf(t - 0.5) * 2.0))
		_px(img, x, 16 - yoff, base)
		_px(img, x, 16 + yoff, base)
	_disc(img, 16, 16, 3, light)
	_disc(img, 16, 16, 1, dark)


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

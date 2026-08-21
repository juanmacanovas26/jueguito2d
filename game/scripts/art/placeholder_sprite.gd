class_name PlaceholderSprite
extends RefCounted
## Procedural placeholder sprites so the animation pipeline runs without art.
## Replace these SpriteFrames with imported Aseprite sheets when real art exists.

const HERO_BODY := Color(0.45, 0.72, 0.95)
const HERO_HEAD := Color(0.95, 0.85, 0.7)
const HERO_WEAPON := Color(0.85, 0.85, 0.9)
const SLIME_BODY := Color(0.45, 0.7, 0.4)
const SLIME_DARK := Color(0.25, 0.45, 0.28)


static func make_hero() -> SpriteFrames:
	var sf := SpriteFrames.new()
	_add(sf, "idle", [_hero(0.0, 0, 0)])
	_add(sf, "walk", [_hero(-1.0, 0, 0), _hero(1.0, 0, 0)])
	_add(sf, "attack", [_hero(0.0, 8, 0), _hero(0.0, 16, 0)])
	_add(sf, "dodge", [_hero(0.0, 0, 1)])
	_add(sf, "death", [_hero(0.0, 0, 2)])
	sf.set_animation_speed("walk", 8.0)
	sf.set_animation_speed("attack", 12.0)
	return sf


static func make_slime() -> SpriteFrames:
	var sf := SpriteFrames.new()
	_add(sf, "idle", [_slime(1.0)])
	_add(sf, "walk", [_slime(1.0), _slime(1.2), _slime(1.0), _slime(0.85)])
	_add(sf, "attack", [_slime(1.1), _slime(1.3)])
	_add(sf, "death", [_slime(0.4)])
	sf.set_animation_speed("walk", 8.0)
	sf.set_animation_speed("attack", 10.0)
	return sf


static func _add(sf: SpriteFrames, anim_name: String, frames: Array) -> void:
	sf.add_animation(anim_name)
	for f in frames:
		sf.add_frame(anim_name, f)


static func _hero(bob: float, weapon_ext: int, pose: int) -> Texture2D:
	var w := 32
	var h := 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if pose == 2: # death — flattened
		img.fill_rect(Rect2i(6, h - 8, 20, 6), HERO_BODY)
		return ImageTexture.create_from_image(img)
	var body_h := 18.0
	var y0 := int(h - 16 - body_h + bob + (2.0 if pose == 1 else 0.0))
	img.fill_rect(Rect2i(8, y0, 16, int(body_h)), HERO_BODY)
	_circle(img, 16, y0 - 4, 5, HERO_HEAD)
	var wl := weapon_ext if weapon_ext > 0 else 6
	img.fill_rect(Rect2i(22, y0 + 4, wl, 2), HERO_WEAPON)
	return ImageTexture.create_from_image(img)


static func _slime(stretch: float) -> Texture2D:
	var w := 32
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# The radii are driven by `stretch` (wide+flat above 1.0, narrow+tall below),
	# so extreme values used to push the ellipse off the canvas and spam
	# set_pixel errors on every boot. Clamp both radii and the centre so the
	# whole shape always fits.
	var rw := clampi(int(13.0 * stretch), 1, (w - 1) / 2)
	var rh := clampi(int(11.0 / stretch), 1, (h - 1) / 2)
	var cx := w / 2
	var cy := clampi(h - rh - 4, rh, h - 1 - rh)
	for dy in range(-rh, rh + 1):
		for dx in range(-rw, rw + 1):
			var nx := float(dx) / float(rw)
			var ny := float(dy) / float(rh)
			if nx * nx + ny * ny <= 1.0:
				_set_px(img, cx + dx, cy + dy, SLIME_BODY)
	_set_px(img, cx - 4, cy - 3, SLIME_DARK)
	_set_px(img, cx + 4, cy - 3, SLIME_DARK)
	return ImageTexture.create_from_image(img)


## Bounds-checked set_pixel. Godot pushes an error (and drops the write) when a
## coordinate falls outside the image, which is noise, not information, for
## procedural placeholder art.
static func _set_px(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, color)


static func _circle(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				_set_px(img, cx + dx, cy + dy, color)

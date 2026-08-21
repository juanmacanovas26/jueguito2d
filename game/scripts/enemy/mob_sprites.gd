class_name MobSprites
extends RefCounted
## Builds the SpriteFrames used by mobs' AnimatedSprite2D (see chase_mob.gd).
## Each frame is a single 32x32 PNG. Drop the real art at these paths (same
## names) and it's picked up automatically, frame by frame — no code changes
## needed. Missing frames fall back to the PlaceholderSprite slime so the
## scene keeps running meanwhile.

const SLIME_DIR := "res://assets/mobs/slime/"

static var _slime_cache: SpriteFrames = null


static func build_slime() -> SpriteFrames:
	if _slime_cache == null:
		_slime_cache = _build_slime()
	return _slime_cache


static func _build_slime() -> SpriteFrames:
	var placeholder := PlaceholderSprite.make_slime()
	var sf := SpriteFrames.new()
	_build_anim(sf, placeholder, &"idle", [SLIME_DIR + "idle.png"], 5.0)
	_build_anim(sf, placeholder, &"walk", [
		SLIME_DIR + "walk_0.png", SLIME_DIR + "walk_1.png",
		SLIME_DIR + "walk_2.png", SLIME_DIR + "walk_3.png",
	], 8.0)
	_build_anim(sf, placeholder, &"attack", [
		SLIME_DIR + "attack_0.png", SLIME_DIR + "attack_1.png",
	], 10.0)
	_build_anim(sf, placeholder, &"death", [SLIME_DIR + "death.png"], 5.0)
	return sf


static func _build_anim(sf: SpriteFrames, placeholder: SpriteFrames, anim: StringName, paths: Array, fps: float) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	for i in paths.size():
		sf.add_frame(anim, _load_or_placeholder(paths[i], placeholder, anim, i))


static func _load_or_placeholder(path: String, placeholder: SpriteFrames, anim: StringName, index: int) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex: Resource = load(path)
		if tex is Texture2D:
			return tex
	return placeholder.get_frame_texture(anim, index)

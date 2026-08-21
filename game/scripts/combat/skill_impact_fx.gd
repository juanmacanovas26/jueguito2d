class_name SkillImpactFx
extends Node2D
## A one-shot sprite effect dropped where a skill actually lands.
##
## Purely presentation, and deliberately after the fact: SkillCaster has
## already resolved who got hit by the time this spawns, so a missing or ugly
## effect never changes the outcome of a fight (docs/ARQUITECTURA.md).
##
## Plays its frames once at FPS and frees itself — no looping, no owner to
## clean it up.

const FPS := 24.0

var _frames: Array[Texture2D] = []
var _elapsed: float = 0.0
var _sprite: Sprite2D


## Drops the named effect (game/assets/vfx/<effect_id>/) at `pos`. If `radius`
## is given, the effect is scaled so its drawn radius matches the skill's
## actual hit radius instead of whatever size the source sheet happened to be.
static func spawn(pos: Vector2, effect_id: String, radius: float = 0.0) -> void:
	var frames := VfxLibrary.frames_for(effect_id)
	if frames.is_empty():
		return
	var fx := SkillImpactFx.new()
	fx._frames = frames
	fx.z_index = 5
	if radius > 0.0:
		var native_radius := frames[0].get_size().x * 0.5
		if native_radius > 0.0:
			fx.scale = Vector2.ONE * (radius / native_radius)
	Game.spawn_node(fx, pos, null)


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.texture = _frames[0]
	add_child(_sprite)


func _process(delta: float) -> void:
	_elapsed += delta
	var idx := int(_elapsed * FPS)
	if idx >= _frames.size():
		queue_free()
		return
	_sprite.texture = _frames[idx]

@tool
class_name MobSpawnMarker
extends Marker2D
## Author-time placement for a chase_mob spawn: drag it in the 2D viewport,
## tune the fields in the inspector. ZoneBuilder reads these at zone _ready()
## and turns each marker into a live enemy — see docs/GDD.md's "5-8 zonas +
## 2 dungeons" MVP target; this is what makes producing them fast instead of
## hand-typing Vector2/Dictionary arrays (the old world_zone.gd approach).

@export var max_hp: float = 80.0
@export var speed: float = 95.0
@export var damage: float = 12.0
@export var skill_gain: int = 18
@export var gold_max: int = 4
@export var ranged: bool = false
@export var body_color: Color = Color(0.8, 0.4, 0.35)
@export var projectile_damage: float = 12.0
@export var projectile_speed: float = 240.0
@export var attack_range: float = 200.0
@export var attack_cooldown: float = 1.3

const _MELEE_COLOR := Color(0.85, 0.15, 0.15, 0.9)
const _RANGED_COLOR := Color(0.9, 0.55, 0.15, 0.9)

## Cached across every MobSpawnMarker, same reasoning as MobSprites' own
## internal cache: every mob uses the same slime SpriteFrames today (see
## chase_mob.gd), only body_color differs, so there's nothing per-marker to
## rebuild here.
static var _idle_tex: Texture2D = null


func _ready() -> void:
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var col := _RANGED_COLOR if ranged else _MELEE_COLOR
	var tex := _idle_texture()
	if tex == null:
		draw_circle(Vector2.ZERO, 9.0, col)
	else:
		# Real art, tinted by body_color — matches chase_mob.gd's own
		# `sprite.modulate = body_color`, so the editor preview shows what
		# this marker actually turns into once ZoneBuilder spawns it.
		var size := Vector2(tex.get_size())
		draw_texture_rect(tex, Rect2(-size / 2.0, size), false, body_color)
	if ranged and attack_range > 0.0:
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.35), 1.5)


func _idle_texture() -> Texture2D:
	if _idle_tex == null:
		var frames := MobSprites.build_slime()
		if frames.has_animation(&"idle") and frames.get_frame_count(&"idle") > 0:
			_idle_tex = frames.get_frame_texture(&"idle", 0)
	return _idle_tex

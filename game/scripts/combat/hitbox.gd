class_name Hitbox
extends Area2D

@export var team: StringName = &"player"
@export var damage: float = 10.0
@export var poise_damage: float = 5.0
@export var knockback: float = 0.0
@export var hit_stun: float = 0.08
## 0..1 chance to whiff even on overlap (e.g. attacking while sprinting)
@export var miss_chance: float = 0.0
@export var damage_mul: float = 1.0

var _active: bool = false
var _hit_ids: Dictionary = {}
var _swing_id: int = 0



func _ready() -> void:
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)
	_set_layers()
	deactivate()


func _set_layers() -> void:
	collision_layer = 0
	if team == &"player":
		collision_mask = 1 << 2
		collision_layer = 1 << 3
	else:
		collision_mask = 1 << 1
		collision_layer = 1 << 4


func configure(p_team: StringName, p_damage: float, p_poise: float = 5.0, p_kb: float = 0.0) -> void:
	team = p_team
	damage = p_damage
	poise_damage = p_poise
	knockback = p_kb
	miss_chance = 0.0
	damage_mul = 1.0
	_set_layers()


func set_accuracy(p_miss_chance: float, p_damage_mul: float) -> void:
	miss_chance = clampf(p_miss_chance, 0.0, 1.0)
	damage_mul = maxf(0.0, p_damage_mul)


func begin_swing() -> void:
	_swing_id += 1
	_hit_ids.clear()
	_active = false
	set_deferred("monitoring", false)
	visible = false



func activate() -> void:
	if _active:
		return
	_active = true
	set_deferred("monitoring", true)
	visible = true
	call_deferred("_scan_overlaps")


func deactivate() -> void:
	_active = false
	set_deferred("monitoring", false)
	visible = false


func _scan_overlaps() -> void:
	if not _active:
		return
	for area in get_overlapping_areas():
		_try_hit(area)


func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return
	_try_hit(area)


func _try_hit(area: Area2D) -> void:
	if not _active:
		return
	if not area.has_method("apply_hit"):
		return
	var id := area.get_instance_id()
	if _hit_ids.has(id):
		return
	# Mark resolved either way so one swing can't re-roll forever on same target
	_hit_ids[id] = true
	if miss_chance > 0.0 and randf() < miss_chance:
		if area is Node2D:
			FloatingText.spawn("MISS", Color(0.85, 0.85, 0.92), (area as Node2D).global_position, 12)
		return
	var dir := Vector2.RIGHT
	var src: Node = owner if owner else get_parent()
	if src is Node2D and area is Node2D:
		dir = ((area as Node2D).global_position - (src as Node2D).global_position).normalized()
	var hit := {
		"damage": damage * damage_mul,
		"poise_damage": poise_damage * damage_mul,
		"knockback": knockback,
		"hit_stun": hit_stun,
		"direction": dir,
		"team": team,
		"source": src,
		"swing_id": _swing_id,
	}
	area.apply_hit(hit)


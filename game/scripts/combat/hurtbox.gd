class_name Hurtbox
extends Area2D

signal hurt(hit_data: Dictionary)

@export var team: StringName = &"enemy"
@export var invulnerable: bool = false

var _owner_health: Node = null
var _resolve_target: Node = null


func _ready() -> void:
	monitorable = true
	monitoring = false
	collision_layer = 0
	collision_mask = 0


func setup(health_node: Node, p_team: StringName, resolve_target: Node = null) -> void:
	_owner_health = health_node
	_resolve_target = resolve_target
	team = p_team
	if team == &"player":
		collision_layer = 1 << 1
	else:
		collision_layer = 1 << 2


func set_invulnerable(value: bool) -> void:
	invulnerable = value


func apply_hit(hit_data: Dictionary) -> bool:
	if invulnerable:
		return false
	if hit_data.get("team", &"") == team:
		return false

	var data: Dictionary = hit_data.duplicate()
	if _resolve_target and _resolve_target.has_method("resolve_incoming_hit"):
		var result: Variant = _resolve_target.resolve_incoming_hit(data)
		if typeof(result) == TYPE_DICTIONARY:
			data = result
			if data.get("cancelled", false):
				hurt.emit(data)
				_spawn_damage_float(data)
				return true
		elif result == false:
			return false

	hurt.emit(data)
	if _owner_health and _owner_health.has_method("take_damage"):
		_owner_health.take_damage(data)
	_spawn_damage_float(data)
	return true


func _spawn_damage_float(data: Dictionary) -> void:
	if data.get("parried", false):
		FloatingText.spawn("PARRY!", Color(1.0, 0.95, 0.4), global_position, 15)
		return
	if data.get("blocked", false):
		FloatingText.spawn("BLOCK", Color(0.5, 0.75, 1.0), global_position, 13)
		return
	var amount := float(data.get("damage", 0.0))
	if amount <= 0.0:
		return
	var col := Color(1.0, 0.4, 0.4) if team == &"player" else Color(1.0, 0.92, 0.55)
	var size := 16
	if amount >= 25.0:
		size = 20
		col = Color(1.0, 0.6, 0.3) if team != &"player" else col
	FloatingText.spawn(str(int(round(amount))), col, global_position, size)

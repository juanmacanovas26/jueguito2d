class_name ResourceNode
extends StaticBody2D
## Gatherable node.
## - Normal (immortal=false): depletes on hits, drops resources, respawns.
## - Immortal (immortal=true): never depletes; gives a resource per hit.
##   Manual hits give +20% (chance of +1); auto-farm calls gather(false).

@export var display_name: String = "Tree"
@export var visual_type: String = "tree" # "tree", "rock", "vein"
@export var max_hp: float = 40.0
@export var drop_id: String = "wood_log"
@export var drop_min: int = 1
@export var drop_max: int = 3
@export var xp_reward: int = 5
@export var respawn_time: float = 6.0
@export var visual_radius: float = 26.0
@export var collision_radius: float = 18.0
@export var immortal: bool = false
## Minimum seconds between per-hit yields (immortal only)
@export var hit_cooldown: float = 0.6
## Manual bonus: chance (0..1) of an extra resource on a manual hit
@export var manual_bonus_chance: float = 0.2

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health: Health = $Health
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var visual_root: Node2D = $Visual

const LootDropScene := preload("res://scenes/world/loot_drop.tscn")

var _dead: bool = false
var _last_attacker: Node = null
var _cooldown_t: float = 0.0


func _ready() -> void:
	add_to_group("gatherable")
	if immortal:
		add_to_group("immortal_node")
	health.max_hp = max_hp
	health.hp = max_hp
	health.start_full = true
	hurtbox.setup(health, &"enemy", self)
	hurtbox.collision_layer = 1 << 2
	hurtbox.collision_mask = 0
	hurtbox.hurt.connect(_on_hurt)
	health.damaged_by.connect(_on_damaged_by)
	health.died.connect(_on_died)
	_setup_shapes()
	_build_visual()


func _process(delta: float) -> void:
	if _cooldown_t > 0.0:
		_cooldown_t -= delta


func _setup_shapes() -> void:
	var c := collision_shape.shape as CircleShape2D
	c.radius = collision_radius
	var h := hurtbox_shape.shape as CircleShape2D
	h.radius = maxf(collision_radius, 20.0)


func _build_visual() -> void:
	for ch in visual_root.get_children():
		ch.queue_free()
	if visual_type == "tree":
		var trunk := Polygon2D.new()
		trunk.color = Color(0.35, 0.24, 0.16)
		trunk.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(4, 20), Vector2(-4, 20)])
		visual_root.add_child(trunk)
		var canopy := Polygon2D.new()
		canopy.color = Color(0.20, 0.45, 0.22)
		canopy.polygon = _circle_pts(visual_radius, 8)
		canopy.position = Vector2(0, -6)
		visual_root.add_child(canopy)
	elif visual_type == "vein":
		var vein := Polygon2D.new()
		vein.color = Color(0.72, 0.55, 0.25)
		vein.polygon = _circle_pts(visual_radius, 8)
		visual_root.add_child(vein)
		var shine := Polygon2D.new()
		shine.color = Color(1.0, 0.9, 0.4, 0.5)
		shine.polygon = _circle_pts(visual_radius * 0.45, 6)
		visual_root.add_child(shine)
	else:
		var rock := Polygon2D.new()
		rock.color = Color(0.5, 0.5, 0.55)
		rock.polygon = _circle_pts(visual_radius, 8)
		visual_root.add_child(rock)


func _circle_pts(radius: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func resolve_incoming_hit(hit_data: Dictionary) -> Dictionary:
	if immortal:
		var d := hit_data.duplicate()
		d["cancelled"] = true
		d["damage"] = 0.0
		return d
	return hit_data


func _on_hurt(data: Dictionary) -> void:
	if not immortal:
		return
	# Manual hit (came through a real attack) → manual bonus
	gather(true, data.get("source"))


func _on_damaged_by(_amount: float, _current: float, source: Node) -> void:
	if source and (source.is_in_group("player") or (source.get_parent() and source.get_parent().is_in_group("player"))):
		_last_attacker = source if source.is_in_group("player") else source.get_parent()


func _on_died() -> void:
	if _dead or immortal:
		return
	_dead = true

	if _last_attacker:
		var prog: Progress = _last_attacker.get_node_or_null("Progress") as Progress
		if prog:
			prog.add_xp(xp_reward)
			if Game.has_method("toast"):
				Game.toast("+%d XP (%s)" % [xp_reward, display_name])

	var parent := Game.get_world()
	if parent:
		var amt := randi_range(drop_min, drop_max)
		var drop = Game.spawn(LootDropScene, global_position + Vector2(randf_range(-6, 6), randf_range(-3, 3)), parent)
		drop.setup(drop_id, amt)

	visual_root.visible = false
	hurtbox.collision_layer = 0
	set_collision_layer_value(1, false)

	await get_tree().create_timer(respawn_time).timeout
	_respawn()


## Per-hit yield for immortal nodes. `manual` adds +20% (chance of +1).
func gather(manual: bool, source: Node = null) -> void:
	if _dead:
		return
	if _cooldown_t > 0.0:
		return
	_cooldown_t = hit_cooldown

	var amount := 1
	if manual and randf() < manual_bonus_chance:
		amount = 2

	var inv: Inventory = null
	if source and source.has_node("Inventory"):
		inv = source.get_node("Inventory") as Inventory
	if inv:
		inv.add_item(drop_id, amount)

	var item_color: Color = ItemDB.get_item(drop_id).get("color", Color.WHITE)
	FloatingText.spawn("+%d %s" % [amount, ItemDB.display_name(drop_id)], item_color, global_position + Vector2(0, -visual_radius - 6), 13)


func _respawn() -> void:
	_dead = false
	health.is_dead = false
	health.hp = health.max_hp
	health.poise = health.max_poise
	_last_attacker = null
	visual_root.visible = true
	hurtbox.collision_layer = 1 << 2
	set_collision_layer_value(1, true)
	health.health_changed.emit(health.hp, health.max_hp)

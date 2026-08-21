extends Node
## Central "seam" for future netcode. All world/entity access and spawning MUST
## go through here so a server can be inserted later without touching gameplay.

signal player_stats_changed(
	hp: float,
	max_hp: float,
	stamina: float,
	max_stamina: float,
	mana: float,
	max_mana: float,
	defend_style: String,
	defense_msg: String,
	level: int,
	xp: int,
	xp_to_next: int,
	gold: int
)
signal inventory_changed(inv: Inventory)
signal toast_msg(text: String)

var debug_hitboxes: bool = true

## Authoritative world root (the current zone). Set by the zone's _ready().
var world: Node = null
## The local player entity. In netcode this becomes "my entity by network id".
var local_player: Node = null

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func register_world(node: Node) -> void:
	world = node


func register_player(p: Node) -> void:
	local_player = p


func get_world() -> Node:
	return world if world != null and is_instance_valid(world) else null


func get_local_player() -> Node:
	if local_player != null and is_instance_valid(local_player):
		return local_player
	return null


## All dynamic node spawning goes through here (loot, projectiles, etc.).
## In netcode this is where a spawn RPC / server message would be emitted.
## Same contract as spawn(), for a node that is already built (procedural
## visuals, pooled objects). Everything that enters the world still goes through
## here — see docs/ARQUITECTURA.md.
func spawn_node(node: Node, pos: Vector2, parent: Node = null) -> Node:
	var p := parent if parent != null else get_world()
	if p == null:
		p = self
	p.add_child(node)
	if node is Node2D:
		(node as Node2D).global_position = pos
	return node


func spawn(scene: PackedScene, pos: Vector2, parent: Node = null) -> Node:
	var p := parent if parent != null else get_world()
	if p == null:
		p = self
	var node := scene.instantiate()
	p.add_child(node)
	if node is Node2D:
		(node as Node2D).global_position = pos
	return node


## Deterministic/sharable RNG. Server becomes the single source of randomness later.
func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


func toast(text: String) -> void:
	toast_msg.emit(text)

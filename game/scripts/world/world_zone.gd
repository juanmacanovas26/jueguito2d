extends Node2D
## Simple hand-built zone: floor tilemap, world walls, obstacles, mob spawns, player.

const MobScene := preload("res://scenes/enemy/chase_mob.tscn")
const ResourceNodeScene := preload("res://scenes/world/resource_node.tscn")
const TILE_PX := 32

@export var zone_name: String = "Praderas del Alba"
@export var world_size: Vector2 = Vector2(2400, 1800)
@export var player_spawn: Vector2 = Vector2.ZERO
@export var show_debug_grid: bool = false
## How much of the floor is dirt rather than grass, 0.0-1.0. Only used when the
## grass/dirt Wang tileset is present; the borders between the two are picked
## automatically by the terrain system.
@export_range(0.0, 1.0, 0.01) var dirt_coverage: float = 0.18
## Size of the dirt patches. Lower = fewer, bigger blobs.
@export_range(0.01, 0.2, 0.005) var dirt_patch_scale: float = 0.05
@export var rock_positions: Array[Vector2] = [
	Vector2(-400, -300), Vector2(-380, -260), Vector2(300, 320),
	Vector2(600, -200), Vector2(-700, 400), Vector2(500, 500),
	Vector2(-200, 600), Vector2(800, 300), Vector2(-900, -400),
	Vector2(900, -500), Vector2(-600, -700), Vector2(400, -600),
]
@export var tree_positions: Array[Vector2] = [
	Vector2(-200, -150), Vector2(150, 200), Vector2(-500, 150),
	Vector2(700, 80), Vector2(-100, 400), Vector2(350, -350),
	Vector2(-800, -150), Vector2(650, -450), Vector2(-450, 500),
	Vector2(150, -700), Vector2(1000, 150), Vector2(-1000, 200),
]
@export var vein_positions: Array[Vector2] = [
	Vector2(-60, -40), Vector2(420, 240), Vector2(-620, -240),
	Vector2(240, -500),
]
## { pos, max_hp, speed, damage, xp, gold_max, [ranged, body_color, projectile_damage, projectile_speed, attack_range] }
@export var mob_spawns: Array[Dictionary] = [
	{"pos": Vector2(-250, 250), "max_hp": 80.0, "speed": 95.0, "damage": 12.0, "xp": 18, "gold_max": 4},
	{"pos": Vector2(0, -300), "max_hp": 80.0, "speed": 95.0, "damage": 12.0, "xp": 18, "gold_max": 4},
	{"pos": Vector2(300, 180), "max_hp": 60.0, "speed": 110.0, "damage": 9.0, "xp": 14, "gold_max": 3},
	{"pos": Vector2(-500, -400), "max_hp": 90.0, "speed": 90.0, "damage": 14.0, "xp": 22, "gold_max": 5},
	{"pos": Vector2(550, 350), "max_hp": 60.0, "speed": 115.0, "damage": 9.0, "xp": 14, "gold_max": 3},
	{"pos": Vector2(-650, 250), "max_hp": 100.0, "speed": 85.0, "damage": 16.0, "xp": 26, "gold_max": 6},
	{"pos": Vector2(-300, 480), "max_hp": 55.0, "speed": 90.0, "damage": 8.0, "xp": 20, "gold_max": 4, "ranged": true, "body_color": Color(0.8, 0.4, 0.35), "projectile_damage": 12.0, "projectile_speed": 240.0, "attack_range": 200.0, "attack_cooldown": 1.3},
	{"pos": Vector2(700, -300), "max_hp": 55.0, "speed": 90.0, "damage": 8.0, "xp": 20, "gold_max": 4, "ranged": true, "body_color": Color(0.8, 0.4, 0.35), "projectile_damage": 12.0, "projectile_speed": 240.0, "attack_range": 200.0, "attack_cooldown": 1.3},
]

var _grid_color := Color(1.0, 1.0, 1.0, 0.06)
var _player: Node = null


func _ready() -> void:
	z_index = -5
	Game.register_world(self)
	_build_floor()
	_build_world()
	_spawn_player()


func _draw() -> void:
	if not show_debug_grid:
		return
	var step := 80.0
	var hw := world_size.x * 0.5
	var hh := world_size.y * 0.5
	var x := -hw
	while x <= hw:
		draw_line(Vector2(x, -hh), Vector2(x, hh), _grid_color, 1.0)
		x += step
	var y := -hh
	while y <= hh:
		draw_line(Vector2(-hw, y), Vector2(hw, y), _grid_color, 1.0)
		y += step


func _build_floor() -> void:
	var floor_layer: TileMapLayer = $Floor
	floor_layer.tile_set = FloorTileset.build()

	var tiles_x := int(ceil(world_size.x / float(TILE_PX)))
	var tiles_y := int(ceil(world_size.y / float(TILE_PX)))
	# Center the painted grid on the origin, same as world_size; ceil() may
	# overshoot by a few px per axis when world_size isn't a multiple of the
	# tile size — that sliver ends up hidden under the boundary walls.
	floor_layer.position = Vector2(-tiles_x * TILE_PX * 0.5, -tiles_y * TILE_PX * 0.5)

	if FloorTileset.wang_source_id() >= 0:
		_paint_terrain_floor(floor_layer, tiles_x, tiles_y)
	else:
		_paint_scattered_floor(floor_layer, tiles_x, tiles_y)


## Grass with organic dirt patches, using the Wang tileset's terrain set. The
## border tiles are chosen by Godot from the corner data, so nothing here has to
## know which sprite goes where.
func _paint_terrain_floor(floor_layer: TileMapLayer, tiles_x: int, tiles_y: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 1337 # fixed: the floor pattern is decoration, not state.
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = dirt_patch_scale

	# Turn the coverage fraction into a noise threshold by sampling the field.
	var samples: Array[float] = []
	for ty in range(tiles_y):
		for tx in range(tiles_x):
			samples.append(noise.get_noise_2d(float(tx), float(ty)))
	samples.sort()
	var cut := clampi(int(samples.size() * (1.0 - dirt_coverage)), 0, samples.size() - 1)
	var threshold: float = samples[cut]

	var grass_cells: Array[Vector2i] = []
	var dirt_cells: Array[Vector2i] = []
	for ty in range(tiles_y):
		for tx in range(tiles_x):
			var cell := Vector2i(tx, ty)
			if noise.get_noise_2d(float(tx), float(ty)) > threshold:
				dirt_cells.append(cell)
			else:
				grass_cells.append(cell)

	# Grass first as the base, then the dirt patches carve into it — the second
	# pass is what produces the blended borders.
	floor_layer.set_cells_terrain_connect(grass_cells, FloorTileset.TERRAIN_SET, FloorTileset.TERRAIN_GRASS, false)
	if not dirt_cells.is_empty():
		floor_layer.set_cells_terrain_connect(dirt_cells, FloorTileset.TERRAIN_SET, FloorTileset.TERRAIN_DIRT, false)


## Fallback for when the Wang sheet is missing: the original weighted scatter of
## flat grass variants.
func _paint_scattered_floor(floor_layer: TileMapLayer, tiles_x: int, tiles_y: int) -> void:
	var grass_ids := FloorTileset.grass_source_ids()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337 # fixed seed: the floor pattern is decoration, not state — keep it stable across runs.
	for ty in range(tiles_y):
		for tx in range(tiles_x):
			var source_id := grass_ids[0]
			var roll := rng.randf()
			if roll < 0.08:
				source_id = grass_ids[2]
			elif roll < 0.22:
				source_id = grass_ids[1]
			floor_layer.set_cell(Vector2i(tx, ty), source_id, Vector2i.ZERO)


func _build_world() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)

	var hw := world_size.x * 0.5
	var hh := world_size.y * 0.5
	var thickness := 60.0
	_add_wall(walls, Vector2(0, -hh - thickness * 0.5), Vector2(world_size.x + thickness * 2, thickness))
	_add_wall(walls, Vector2(0, hh + thickness * 0.5), Vector2(world_size.x + thickness * 2, thickness))
	_add_wall(walls, Vector2(-hw - thickness * 0.5, 0), Vector2(thickness, world_size.y + thickness * 2))
	_add_wall(walls, Vector2(hw + thickness * 0.5, 0), Vector2(thickness, world_size.y + thickness * 2))

	var obstacles := Node2D.new()
	obstacles.name = "Obstacles"
	add_child(obstacles)

	for p in tree_positions:
		_add_resource(obstacles, p, "tree", "wood_log", 1, 3, 5, 40.0)
	for p in rock_positions:
		_add_resource(obstacles, p, "rock", "stone_chunk", 1, 2, 5, 50.0)
	for p in vein_positions:
		_add_vein(obstacles, p)

	var mobs := Node2D.new()
	mobs.name = "Mobs"
	add_child(mobs)
	for cfg in mob_spawns:
		_add_mob(mobs, cfg)


func _add_wall(parent: Node, pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	body.position = pos
	parent.add_child(body)

	var vis := Polygon2D.new()
	vis.color = Color(0.14, 0.17, 0.15)
	vis.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5),
	])
	vis.z_index = -1
	body.add_child(vis)


func _add_resource(parent: Node, pos: Vector2, type: String, drop_id: String, dmin: int, dmax: int, xp: int, hp: float) -> void:
	var node = ResourceNodeScene.instantiate()
	node.position = pos
	node.visual_type = type
	node.drop_id = drop_id
	node.drop_min = dmin
	node.drop_max = dmax
	node.xp_reward = xp
	node.max_hp = hp
	parent.add_child(node)


func _add_vein(parent: Node, pos: Vector2) -> void:
	var node = ResourceNodeScene.instantiate()
	node.position = pos
	node.visual_type = "vein"
	node.display_name = "Iron Vein"
	node.drop_id = "iron_ore"
	node.drop_min = 1
	node.drop_max = 1
	node.xp_reward = 0
	node.max_hp = 999999.0
	node.immortal = true
	node.visual_radius = 24.0
	node.collision_radius = 20.0
	node.hit_cooldown = 0.7
	parent.add_child(node)


func _add_mob(parent: Node, cfg: Dictionary) -> void:
	var mob = MobScene.instantiate()
	mob.position = cfg.get("pos", Vector2.ZERO)
	parent.add_child(mob)
	_set_mob_prop(mob, cfg, "max_hp")
	_set_mob_prop(mob, cfg, "speed", "move_speed")
	_set_mob_prop(mob, cfg, "damage", "attack_damage")
	_set_mob_prop(mob, cfg, "xp", "xp_reward")
	_set_mob_prop(mob, cfg, "gold_max")
	_set_mob_prop(mob, cfg, "ranged")
	_set_mob_prop(mob, cfg, "body_color")
	_set_mob_prop(mob, cfg, "projectile_damage")
	_set_mob_prop(mob, cfg, "projectile_speed")
	_set_mob_prop(mob, cfg, "attack_range")
	_set_mob_prop(mob, cfg, "attack_cooldown")


func _set_mob_prop(mob: Node, cfg: Dictionary, cfg_key: String, prop_key: String = "") -> void:
	if prop_key == "":
		prop_key = cfg_key
	if cfg.has(cfg_key):
		mob.set(prop_key, cfg[cfg_key])


func _spawn_player() -> void:
	_player = Game.get_local_player()
	if _player == null:
		return
	Game.register_player(_player)
	_player.global_position = player_spawn
	if _player.has_node("Health"):
		var h: Health = _player.get_node("Health")
		h.died.connect(_on_player_died)


func _on_player_died() -> void:
	if _player == null:
		return
	await get_tree().create_timer(2.0).timeout
	if _player and is_instance_valid(_player):
		_player.call("respawn", player_spawn)

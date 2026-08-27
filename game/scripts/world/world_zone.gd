extends Node2D
## Zone: floor tilemap, world walls, and whatever a "Markers" child node
## contains (mob spawns / gatherables / POIs, authored via MobSpawnMarker /
## ResourceNodeMarker / POIMarker and turned into live entities by
## ZoneBuilder — see docs/GDD.md's mapping-tool note under Fase 2). A zone
## with no Markers node just gets floor + walls + player, no content.

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

var _grid_color := Color(1.0, 1.0, 1.0, 0.06)
var _player: Node = null
## POI markers found under "Markers" (vendor/bank/repair/dungeon_entrance/
## mini_boss). Nothing reads this yet — Fase 3 wires the city hub and the
## first dungeon up against it.
var pois: Array[POIMarker] = []
## marker -> the live entity ZoneBuilder spawned for it, so build mode's
## right-click removal can free that entity too. Deliberately NOT stored as
## marker metadata (Node.set_meta()) — metadata gets serialized whenever the
## marker is packed by save_markers_layout(), which would embed a full copy
## of the live node (and everything it references) into the saved .tscn.
var _marker_spawns: Dictionary = {}


const BuildGhostScript := preload("res://scripts/world/build_ghost.gd")


func _ready() -> void:
	z_index = -5
	Game.register_world(self)
	_build_floor()
	_build_world()
	_spawn_player()
	# A separate CanvasItem, not drawn through this node's own _draw() — see
	# build_ghost.gd for why (this node's z_index = -5 would hide it).
	var ghost := Node2D.new()
	ghost.name = "BuildGhost"
	ghost.set_script(BuildGhostScript)
	add_child(ghost)


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

	_load_markers_override()
	var markers := get_node_or_null("Markers")
	if markers:
		pois = ZoneBuilder.build(markers, self, _marker_spawns)


## Path a build-mode save writes to (see save_markers_layout()) — next to the
## zone scene itself, e.g. pradera.tscn -> pradera_markers.tscn.
func _markers_override_path() -> String:
	return scene_file_path.get_basename() + "_markers.tscn"


## If a previous build-mode session saved a layout for this zone, it replaces
## whatever "Markers" node is baked into the .tscn — the save file is always
## the latest authored state once one exists.
func _load_markers_override() -> void:
	var path := _markers_override_path()
	if not ResourceLoader.exists(path):
		return
	var existing := get_node_or_null("Markers")
	if existing:
		remove_child(existing)
		existing.queue_free()
	var packed: PackedScene = load(path)
	var instanced := packed.instantiate()
	instanced.name = "Markers"
	add_child(instanced)


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


func _spawn_player() -> void:
	_player = Game.get_local_player()
	if _player == null:
		return
	Game.register_player(_player)
	_player.global_position = player_spawn
	if _player.has_node("Health"):
		var h: Health = _player.get_node("Health")
		h.died.connect(_on_player_died)
	if SaveSystem.pending_load:
		SaveSystem.pending_load = false
		var data := SaveSystem.load_data()
		if not data.is_empty() and _player.has_method("apply_save_data"):
			_player.apply_save_data(data)


## Death has to cost something even offline (see docs/GDD.md's "muerte:
## definir drop de gold/items" rule) — this is the single-player-scale version
## of that: a gold cut instead of the full open-world item drop.
const DEATH_GOLD_PENALTY_PCT := 0.1


func _on_player_died() -> void:
	if _player == null:
		return
	if "inventory" in _player and _player.inventory:
		var inv: Inventory = _player.inventory
		var penalty := int(round(inv.gold * DEATH_GOLD_PENALTY_PCT))
		if penalty > 0:
			inv.gold -= penalty
			inv.changed.emit()
			Game.toast("Moriste — perdiste %d de oro" % penalty)
	await get_tree().create_timer(2.0).timeout
	if _player and is_instance_valid(_player):
		_player.call("respawn", player_spawn)


# --------------------------------------------------------------- build mode
# Runtime map-building overlay: hud.gd's BuildPanel toggles Game.build_mode
# and picks Game.build_selected_kind; this is where clicks turn into
# markers. Kept zone-generic (not pradera-specific) so every future zone
# (Fase 3's 2nd zone, dungeon, city) gets it for free — and, per the design
# goal behind Fase 2, so an eventual online building mode (player housing)
# can grow out of the same place->save->reload loop instead of a new system.


func _unhandled_input(event: InputEvent) -> void:
	if not Game.build_mode or not (event is InputEventMouseButton) or not event.pressed:
		return
	var world_pos := get_global_mouse_position()
	if event.button_index == MOUSE_BUTTON_LEFT:
		_place_marker(Game.build_selected_kind, world_pos)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_remove_nearest_marker(world_pos)


func _place_marker(kind: String, world_pos: Vector2) -> void:
	if not is_placement_valid(world_pos):
		return
	var marker := _instantiate_marker(kind)
	if marker == null:
		return
	var markers := get_node_or_null("Markers")
	if markers == null:
		markers = Node2D.new()
		markers.name = "Markers"
		add_child(markers)
	markers.add_child(marker)
	marker.owner = markers
	marker.global_position = world_pos
	marker.rotation = Game.build_rotation
	var spawned := ZoneBuilder.build_one(marker, self)
	if spawned:
		_marker_spawns[marker] = spawned


## False when world_pos is outside the zone's bounds or too close to an
## existing marker — the same signal a Rust/Valheim-style building ghost
## turning red gives before you commit to a spot. Public (no leading
## underscore) so build_ghost.gd can query it every frame for the preview
## tint, the same way it queries Game.build_selected_kind.
const MIN_MARKER_SPACING := 20.0


func is_placement_valid(world_pos: Vector2) -> bool:
	var hw := world_size.x * 0.5
	var hh := world_size.y * 0.5
	if absf(world_pos.x) > hw or absf(world_pos.y) > hh:
		return false
	var markers := get_node_or_null("Markers")
	if markers:
		for child in markers.get_children():
			if child is Node2D and (child as Node2D).global_position.distance_to(world_pos) < MIN_MARKER_SPACING:
				return false
	return true


func _instantiate_marker(kind: String) -> Node2D:
	match kind:
		"mob":
			return MobSpawnMarker.new()
		"tree":
			return ResourceNodeMarker.new()
		"rock":
			var m := ResourceNodeMarker.new()
			m.kind = ResourceNodeMarker.Kind.ROCK
			m.drop_id = "stone_chunk"
			m.drop_max = 2
			m.max_hp = 50.0
			return m
		"vein":
			var m := ResourceNodeMarker.new()
			m.kind = ResourceNodeMarker.Kind.VEIN
			m.display_name = "Iron Vein"
			m.drop_id = "iron_ore"
			m.drop_max = 1
			m.skill_gain = 0
			m.max_hp = 999999.0
			m.immortal = true
			return m
		"vendor", "bank", "repair", "dungeon_entrance", "mini_boss":
			var p := POIMarker.new()
			p.kind = POIMarker.Kind[kind.to_upper()] as POIMarker.Kind
			return p
		_:
			return null


## Deletes the closest marker within reach (and the live entity it spawned,
## if any) — the undo button for _place_marker().
func _remove_nearest_marker(world_pos: Vector2, max_dist: float = 24.0) -> void:
	var markers := get_node_or_null("Markers")
	if markers == null:
		return
	var closest: Node2D = null
	var closest_dist := max_dist
	for child in markers.get_children():
		if not (child is Node2D):
			continue
		var d: float = (child as Node2D).global_position.distance_to(world_pos)
		if d <= closest_dist:
			closest = child
			closest_dist = d
	if closest == null:
		return
	if _marker_spawns.has(closest):
		var spawned: Node = _marker_spawns[closest]
		if is_instance_valid(spawned):
			spawned.queue_free()
		_marker_spawns.erase(closest)
	markers.remove_child(closest)
	closest.queue_free()


## Packs the current "Markers" subtree (original content + anything placed
## this session) into its own .tscn next to the zone scene, so the next time
## this zone loads, _load_markers_override() picks it up automatically — no
## editor round-trip needed. In an exported build res:// is read-only, so
## this only works run from the editor; that is fine for now since this is a
## dev-authoring tool. The future online building mode would save player
## layouts to user:// instead — same place->pack->save shape, different
## destination because that content belongs to a player, not the project.
func save_markers_layout() -> bool:
	var markers := get_node_or_null("Markers")
	if markers == null:
		return false
	_reown_recursive(markers, markers)
	var packed := PackedScene.new()
	if packed.pack(markers) != OK:
		return false
	return ResourceSaver.save(packed, _markers_override_path()) == OK


## pack() only includes descendants whose `owner` is the node being packed.
## Markers loaded from the .tscn are owned by the zone root, and markers
## placed at runtime have no owner at all — both need re-owning before a save.
func _reown_recursive(node: Node, new_owner: Node) -> void:
	for child in node.get_children():
		child.owner = new_owner
		_reown_recursive(child, new_owner)

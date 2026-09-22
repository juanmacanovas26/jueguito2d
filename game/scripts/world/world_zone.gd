@tool
class_name WorldZone
extends Node2D
## Zone: floor tilemap, world walls, and whatever a "Markers" child node
## contains (mob spawns / gatherables / POIs, authored via MobSpawnMarker /
## ResourceNodeMarker / POIMarker and turned into live entities by
## ZoneBuilder — see docs/GDD.md's mapping-tool note under Fase 2). A zone
## with no Markers node just gets floor + walls + player, no content.
##
## @tool ONLY so the build-mode EditorPlugin (addons/build_mode_editor) can
## call ensure_render_layers()/_rebuild_structures() on
## this script while just editing a scene (no Play). Without @tool, Godot
## gives a non-tool script attached to an edited node a "placeholder"
## instance in the editor — @export vars still show in the Inspector, but
## calling any regular method on it fails with "Attempt to call a method on
## a placeholder instance" (this is what silently broke every editor
## placement before this fix; the marker itself got created fine, since
## that's a separate script, but the repaint call into this script never
## actually ran). _ready() is guarded below so none of its Play-only setup
## (spawning the player, registering with the Game autoload, turning
## mob/resource/POI markers into live entities) runs while just editing —
## only real Play still does any of that, exactly as before.

const TILE_PX := BuildGrid.TILE_SIZE

## Draw order for everything a zone renders, as z_index RELATIVE to this node
## (which itself sits at z_index -5). Relative on purpose: Roof/WallDecor use
## ABSOLUTE z (z_as_relative = false) because they have to beat the build
## ghost too, but the ground stack only has to order itself against the
## "Markers" subtree, and markers sit at relative 0 by default.
##
## Without these, the ground layers drew ON TOP of the props: _ensure_layer()
## creates them with add_child(), which appends them AFTER "Markers" in the
## tree, and equal-z siblings draw in tree order. So a painted road covered
## the barrels standing on it.
const Z_FLOOR := -4       # procedural/baked base ground
const Z_PINTURA := -3     # free-brush ground (PaintLayer), no grid
const Z_SUELO := -2       # hand-painted floor + terrain pieces
const Z_STRUCTURES := -1  # walls and interior floors
## Markers (buildings, decor, mobs, resources, POIs) sit at relative 0, and
## order among themselves through the per-marker z below.
const Z_BUILDING := 0
const Z_DECOR := 1        # decor goes over buildings AND over painted floor

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
## CollisionMarker -> the StaticBody2D _rebuild_collision() spawned for it.
## Same "not marker metadata" reasoning as _marker_spawns above.
var _collision_bodies: Dictionary = {}
## TileSet source_id for the shared floor piece (Structures layer) — see
## _build_structures().
var _floor_source_id: int = -1
## StructureTileset.WALL_PIECES entry -> {material -> TileSet source_id}
## (Structures layer, see _build_structures()). Every StructureMarker picks
## its texture from here by its own `piece`/`wall_material`.
var _wall_piece_source_ids: Dictionary = {}
## StructureTileset.ROOF_PIECES entry -> {material -> TileSet source_id}
## (Roof layer). Every RoofMarker picks its texture from here by its own
## `piece`/`roof_material`.
var _roof_piece_source_ids: Dictionary = {}
## StructureTileset.WALL_DECOR key -> TileSet source_id (WallDecor layer).
var _wall_decor_source_ids: Dictionary = {}
## PaintedFloorTileset tile id -> TileSet source_id (Suelo layer).
var _floor_tile_source_ids: Dictionary = {}


const BuildGhostScript := preload("res://scripts/world/build_ghost.gd")

## Cells this script painted on each layer last rebuild, keyed by layer name.
## The marker-driven repaint erases ONLY these instead of clear()ing the
## layer, so tiles painted by hand in the Godot editor survive. Without it,
## opening a hand-authored zone wiped the map on the first rebuild.
var _owned_cells: Dictionary = {}


## The layer named `name`, reusing one already present in the zone scene
## (hand-authored) and creating it only if absent. Creating unconditionally
## made Godot rename the new node to "Walls2" and left the hand-authored
## "Walls" permanently unpainted.
func _ensure_layer(name: String, tileset_path: String, z: int = 0) -> TileMapLayer:
	var existing := get_node_or_null(name)
	if existing is TileMapLayer:
		var layer := existing as TileMapLayer
		if layer.tile_set == null and ResourceLoader.exists(tileset_path):
			layer.tile_set = load(tileset_path)
		return layer
	var made := TileMapLayer.new()
	made.name = name
	made.position = Vector2(-TILE_PX / 2.0, -TILE_PX / 2.0)
	if ResourceLoader.exists(tileset_path):
		made.tile_set = load(tileset_path)
	if z != 0:
		made.z_as_relative = false
		made.z_index = z
	add_child(made)
	return made


## Repaints `layer` with `cells` (cell -> [source_id, atlas_coord]) while
## leaving anything this script did not put there alone.
func _repaint_owned(layer: TileMapLayer, key: String, cells: Dictionary) -> void:
	var previously: Dictionary = _owned_cells.get(key, {})
	for cell in previously:
		if not cells.has(cell):
			layer.erase_cell(cell)
	for cell in cells:
		var entry: Array = cells[cell]
		# A third element is an alternative-tile id, used only to carry
		# TileSetAtlasSource's mirror bits — see RoadAutotileTable, where a
		# style borrows a flipped copy of a piece it doesn't ship.
		layer.set_cell(cell, int(entry[0]), entry[1], int(entry[2]) if entry.size() > 2 else 0)
	_owned_cells[key] = cells


func _ready() -> void:
	if Engine.is_editor_hint():
		# Paint whatever's already saved under "Markers" the moment the scene
		# is opened — not only after the build-mode EditorPlugin places or
		# removes something. Without this, a zone with real, saved walls/roof
		# looked completely blank on open (reported: "lo que ya existe al
		# abrir el editor no muestra los sprites"), and reopening after
		# placing pieces and saving lost the visual too, since nothing had
		# ever repainted them for THIS fresh scene instance. Deliberately
		# does NOT call _load_markers_override() (that's the separate runtime
		# save file from actually playing the game — loading it here would
		# silently replace the scene's own authored "Markers" content with
		# whatever a past Play session saved, which is not what opening the
		# .tscn for editing should ever do) or spawn any live entity — both
		# stay Play-only, same as before.
		ensure_render_layers()
		_rebuild_structures()
		_rebuild_floor_tiles()
		return
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
	# Before the early-out below: a baked floor takes that branch and still
	# has to sit at the bottom of the stack. Shared with the editor path,
	# which reaches it through ensure_render_layers() instead.
	_pin_floor_z()
	if not floor_layer.get_used_cells().is_empty():
		# Already baked (tools/bake_floor.gd) or hand-painted in the Godot
		# editor's own tilemap tools — same "don't clobber what's already
		# there" rule _ensure_layer()/_repaint_owned() already follow for
		# Structures/Roof (see docs/GDD.md's "mapear a mano" entry).
		# Without this, opening pradera.tscn showed a blank Floor node —
		# the grass/dirt pattern only existed once Play regenerated it every
		# single time, so there was nothing to look at (or hand-edit) in the
		# editor itself. A fresh zone scene that was never baked (its Floor
		# node has no cells yet) falls through to the procedural pass below,
		# so this doesn't break a brand new test/dev scene.
		if floor_layer.tile_set == null:
			floor_layer.tile_set = FloorTileset.build()
		return
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


## Editor-only entry point the build-mode EditorPlugin (addons/
## build_mode_editor) calls before placing/removing a piece: makes sure every
## render layer (Structures/WallDecor/Roof) and its TileSet source-id table
## exist, without any of _ready()'s Play-only side effects (player spawn,
## Game.register_world(), ZoneBuilder spawning live mob/resource entities,
## _load_markers_override() reading the saved layout). None of those make
## sense while just editing a scene — the editor's own "Markers" subtree IS
## the data being edited, there is no separate save file to load from. Safe
## to call repeatedly: _build_structures() only (re)creates a layer if it is
## missing (see _ensure_layer()) and always refreshes its TileSet from
## StructureTileset, so calling this again after an asset change also picks
## that up without needing Play.
func ensure_render_layers() -> void:
	_pin_floor_z()
	_build_structures()
	_build_floor_tiles()
	_build_paint_layers()


## Pins the base Floor layer to the bottom of the draw stack.
##
## Has to be reachable from BOTH entry points. _build_floor() used to be the
## only place that set it, and that runs on Play only — so in the Godot
## editor the Floor kept z_index 0 while "Suelo" got Z_SUELO (-2), and every
## tile you painted went UNDER the grass and looked like nothing happened.
## Reported as "los nuevos pisos no se pintan encima del piso".
func _pin_floor_z() -> void:
	var floor_layer := get_node_or_null("Floor")
	if floor_layer is TileMapLayer:
		(floor_layer as TileMapLayer).z_index = Z_FLOOR


## Creates the "Suelo" TileMapLayer (the hand-painted floor/terrain pieces,
## see PaintedFloorTileset) and caches its id -> source_id map. Sits directly above
## the zone's own procedural Floor and below everything else, so painting a
## pond over the generated grass just covers it.
##
## The TileSet is rebuilt from the PNGs on every call rather than loaded from
## a baked .tres — see PaintedFloorTileset's class doc for why the old baked/
## positional approach was dropped.
func _build_floor_tiles() -> void:
	var layer := _ensure_layer("Suelo", "")
	layer.position = Vector2(-TILE_PX / 2.0, -TILE_PX / 2.0)
	layer.z_index = Z_SUELO
	var built := PaintedFloorTileset.build()
	layer.tile_set = built["tileset"]
	_floor_tile_source_ids = built["source_ids"]


## Repaints "Suelo" from every FloorTileMarker under "Markers" — same
## redo-from-scratch shape as _rebuild_structures(), and cheap for the same
## reason (it only touches cells this script owns, see _repaint_owned()).
##
## Repainting EVERYTHING rather than the one cell that changed is also what
## makes the auto-road brush work for free: a cell's art depends on its
## neighbours, so placing one road cell changes up to eight others, and a
## full repaint already covers that with no neighbour bookkeeping.
func _rebuild_floor_tiles() -> void:
	var layer: TileMapLayer = get_node_or_null("Suelo")
	if layer == null:
		return
	var markers := get_node_or_null("Markers")
	var cells := {}
	if markers != null:
		var painted := ZoneBuilder.collect_floor_tiles(markers)
		# Auto-road cells read their neighbours, so every cell has to be
		# known before any of them can be resolved — hence the first pass.
		# Kept per style, so two road styles meeting keep their own edges
		# instead of merging into one blob.
		var road_cells := {}
		for m in painted:
			if RoadAutotiler.is_auto(m.tile_id):
				var style := RoadAutotiler.style_of(m.tile_id)
				if not road_cells.has(style):
					road_cells[style] = {}
				road_cells[style][m.grid_pos] = true
		for m in painted:
			var tile_id := m.tile_id
			var alternative := 0
			if RoadAutotiler.is_auto(tile_id):
				var of_style: Dictionary = road_cells[RoadAutotiler.style_of(tile_id)]
				var mask := RoadAutotiler.mask_at(of_style, m.grid_pos)
				var picked := RoadAutotiler.resolve(
					RoadAutotiler.style_of(tile_id), mask,
					RoadAutotiler.bevel_at(of_style, m.grid_pos, mask))
				if picked.is_empty():
					continue
				tile_id = str(picked[0])
				alternative = int(picked[1])
			var source_id := int(_floor_tile_source_ids.get(tile_id, -1))
			if source_id >= 0:
				cells[m.grid_pos] = [source_id, Vector2i.ZERO, alternative]
	_repaint_owned(layer, "Suelo", cells)


## One PaintLayer per paintable texture, between the base Floor and the
## painted Suelo: a dirt track runs OVER the generated grass and UNDER a road
## someone laid on top of it.
##
## They are real children of the zone with `owner` set, not runtime-only
## scaffolding, because their mask is what the brush paints and it has to be
## saved with the zone (see PaintLayer's class doc). Created empty and cheap —
## an untouched layer stores no mask at all.
func _build_paint_layers() -> void:
	for texture_id in PaintLayer.TEXTURES:
		var layer_name := "Pintura_" + str(texture_id)
		var layer := get_node_or_null(layer_name) as PaintLayer
		if layer == null:
			layer = PaintLayer.new()
			layer.name = layer_name
			layer.texture_id = str(texture_id)
			add_child(layer)
			# Only meaningful while editing a scene; at Play there is nothing
			# to save it into and owner stays null harmlessly.
			if Engine.is_editor_hint() and is_inside_tree():
				layer.owner = get_tree().edited_scene_root
		layer.world_size = world_size
		layer.z_as_relative = false
		layer.z_index = Z_PINTURA


## The PaintLayer a "paint_<texture>" palette id draws into, or null.
func paint_layer_for(kind: String) -> PaintLayer:
	if not PaintLayer.is_paint_id(kind):
		return null
	return get_node_or_null("Pintura_" + PaintLayer.texture_of(kind)) as PaintLayer


## One dab of the free brush. `erase` is the right-click half — the same
## gesture that deletes a marker takes coverage away here.
##
## `radius` is passed IN, in world pixels, rather than read off
## Game.build_brush_size: the editor plugin calls this too, and the `Game`
## autoload is a Play-mode concept that is not reliably there while a scene is
## merely being edited (plugin.gd's class doc is explicit about it, and this
## method silently did nothing in the editor until it stopped touching Game).
## Each front-end passes its own brush size — the HUD's, or the dock's.
func paint_at(kind: String, world_pos: Vector2, erase: bool, radius: float) -> void:
	var layer := paint_layer_for(kind)
	if layer == null or not is_within_bounds(world_pos):
		return
	layer.paint(world_pos, radius, erase)


func _begin_paint_stroke(kind: String) -> void:
	var layer := paint_layer_for(kind)
	if layer != null:
		layer.begin_stroke()


## Closes the open stroke and files it as ONE undo step, the same way a drag
## of a grid brush folds into one. The step carries only the stroke's dirty
## rect, not the whole mask.
func _end_paint_stroke(kind: String) -> void:
	var layer := paint_layer_for(kind)
	if layer == null:
		return
	var step := layer.end_stroke()
	if not step.is_empty():
		_record_undo({"op": "paint", "layer": layer, "rect": step["rect"], "before": step["before"]})


func _build_world() -> void:
	var walls := StaticBody2D.new()
	# NOT "Walls": that name now belongs to the autotiled wall TileMapLayer
	# (see _build_structures()). This node is the zone's outer boundary
	# collider, which is what the name should have said all along — the
	# collision meant get_node("Walls") silently handed back a StaticBody2D
	# where a TileMapLayer was expected.
	walls.name = "WorldBounds"
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

	# _load_markers_override() (a per-client local "Guardar zona" save file,
	# pradera_markers.tscn) is deliberately NOT called here any more: this is
	# a server-authoritative MMO (see docs/GDD.md), so a local file
	# silently overriding whatever's authored in the zone scene never made
	# sense for real player saves, and during THIS dev-authoring phase it
	# actively bit — content built in the editor (baked straight into
	# pradera.tscn) went invisible at Play whenever an older override file
	# still existed from a previous test session. The zone scene itself,
	# built by hand in the editor (addons/build_mode_editor), is now the
	# single source of truth Play reads from — same principle
	# ensure_render_layers() already documents for the editor side.
	# save_markers_layout()/_load_markers_override() themselves are left in
	# place (still covered by validate_build_mode.gd's round-trip tests) in
	# case a real, server-side save/load feature wants the same pack/
	# instantiate mechanics later; they're just not wired into normal play.
	var markers := get_node_or_null("Markers")
	if markers:
		pois = ZoneBuilder.build(markers, self, _marker_spawns)
	_build_structures()
	_rebuild_structures()
	_rebuild_collision()
	_build_floor_tiles()
	_rebuild_floor_tiles()
	_build_paint_layers()


## Diffs every CollisionMarker under "Markers" against _collision_bodies:
## spawns a StaticBody2D for a new one, frees the body for one that's gone.
## Play-only (see world_zone.gd's build-mode section) — a physics body does
## nothing while just editing a scene, and CollisionMarker's own _draw()
## already shows the red square in the editor without it. Deliberately no
## visual of its own at runtime either (see CollisionMarker's class doc):
## whatever's actually painted at that cell (Floor/Structures) already reads
## as the reason it's solid.
func _rebuild_collision() -> void:
	var markers := get_node_or_null("Markers")
	var collision_markers: Array[CollisionMarker] = (
		ZoneBuilder.collect_collision(markers) if markers else ([] as Array[CollisionMarker])
	)
	var current := {}
	for m in collision_markers:
		current[m] = true
		if not _collision_bodies.has(m):
			_collision_bodies[m] = _make_collision_body(m.grid_pos)
	for m in _collision_bodies.keys():
		if not current.has(m):
			var body: Node = _collision_bodies[m]
			if is_instance_valid(body):
				body.queue_free()
			_collision_bodies.erase(m)


func _make_collision_body(grid_pos: Vector2i) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE_PX, TILE_PX)
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	body.global_position = BuildGrid.cell_to_world(grid_pos)
	return body


## Creates the "Structures" (walls/corners/floor), "WallDecor" (doors/
## windows/torches), and "Roof" TileMapLayers, built once per zone from flat
## tiles at assets/world/structures/ and assets/world/decor/
## (StructureTileset). Positioned half a tile negative on both axes so Godot
## cell N renders CENTERED on world N*TILE_PX — matching
## BuildGrid.snap()/cell_to_world(), which is where a StructureMarker's own
## position already sits.
##
## v1 limitation: visual only, no collision yet — a placed wall doesn't
## block movement. This is still the Fase 2 dev mapping tool (BuildCatalog's
## "structure" category is dev_only), so that's deferred to whenever this
## becomes player-facing construction, not a gap in THIS pass.
func _build_structures() -> void:
	var offset := Vector2(-TILE_PX / 2.0, -TILE_PX / 2.0)

	var structures_layer := _ensure_layer("Structures", "")
	structures_layer.position = offset
	structures_layer.z_index = Z_STRUCTURES
	var walls_built := StructureTileset.build_walls()
	var shared_tileset: TileSet = walls_built["tileset"]
	structures_layer.tile_set = shared_tileset
	_floor_source_id = int(walls_built["floor_source_id"])
	_wall_piece_source_ids = walls_built["piece_source_ids"]

	# Roof has to render above the player/mobs (you're standing UNDER it),
	# unlike Structures which sits at ground level with everything else this
	# zone's z_index = -5 covers — same z_as_relative escape hatch
	# build_ghost.gd uses, just a lower z_index so the ghost still wins.
	# Reuses whatever "Roof" node the scene already has (so a hand-placed
	# position/z_index survives), but its TileSet always comes fresh from
	# StructureTileset — the old hand-paintable baked roof tileset (6 flat
	# field/ridge/eave sources) went away with the piece-based kit; see
	# docs/GDD.md.
	var roof_layer := _ensure_layer("Roof", "", 50)
	# Strip any inherited `owner` — a "Roof" node baked into an older save
	# (back when roof WAS a hand-painted layer) keeps that owner across
	# every _ensure_layer() reuse, which means Godot re-serializes whatever
	# happens to be painted at the moment the scene is saved as if it were
	# real authored content. Roof is 100% derived from RoofMarkers now (see
	# _rebuild_structures()); _repaint_owned() only erases cells IT painted
	# THIS session, so any such baked residue could never actually be
	# cleared — a fresh zone instance's _owned_cells starts empty, so
	# leftover baked cells from a stale save just sat underneath every
	# rebuild forever (reported as tests failing on "painting walls wrote
	# NOTHING to the roof layer" against a pradera.tscn that had picked up
	# exactly this residue from ordinary in-editor use).
	roof_layer.owner = null
	# Also clear whatever cells the layer already has — owner=null only stops
	# a FUTURE save from re-baking them; a node loaded from a .tscn that
	# still has stale tile_map_data (like pradera.tscn did when this was
	# found) already carries those cells the instant it's instantiated,
	# before this function ever runs. _rebuild_structures() repaints the
	# real content from RoofMarkers immediately after anyway, so clearing
	# first is always safe — there is no "real" data living on this layer
	# itself any more, only on the markers.
	roof_layer.clear()
	var roof_built := StructureTileset.build_roof()
	roof_layer.tile_set = roof_built["tileset"]
	_roof_piece_source_ids = roof_built["piece_source_ids"]

	# A door/window/torch is drawn ON TOP of its wall cell, not instead of
	# it — the wall stays fully painted underneath (see
	# _rebuild_structures()), so this is a separate layer rather than a
	# second source_id choice within Structures (one TileMapLayer cell can
	# only hold one tile). Above Roof so a door reads through the roof (see
	# _rebuild_structures()'s door exemption); a window/torch on a
	# roof-covered cell just doesn't get painted at all.
	var wall_decor_layer := _ensure_layer("WallDecor", "", 52)
	wall_decor_layer.position = offset
	var wall_decor_built := StructureTileset.build_wall_decor()
	wall_decor_layer.tile_set = wall_decor_built["tileset"]
	_wall_decor_source_ids = wall_decor_built["source_ids"]


## RoofMarker.roof_material value meaning "don't place/generate roof here" —
## see Game.build_roof_material.
const ROOF_NONE := "none"


## Recomputes the Structures/WallDecor/Roof TileMapLayers from every
## StructureMarker/RoofMarker under "Markers", from scratch. Called after any
## build-mode change to a structure or roof cell — cheap enough at this scale
## (a handful of cells at most) to just redo the whole thing rather than
## track deltas.
func _rebuild_structures() -> void:
	var structures_layer: TileMapLayer = get_node_or_null("Structures")
	var wall_decor_layer: TileMapLayer = get_node_or_null("WallDecor")
	var roof_layer: TileMapLayer = get_node_or_null("Roof")
	if structures_layer == null or wall_decor_layer == null or roof_layer == null:
		return
	var markers := get_node_or_null("Markers")
	var structure_markers: Array[StructureMarker] = (
		ZoneBuilder.collect_structures(markers) if markers else ([] as Array[StructureMarker])
	)

	# Every occupied cell paints Structures with its own piece/material, no
	# neighbour inference — StructureMarker.piece IS the answer, picked by
	# the player when they clicked that shape button in the palette. The
	# roof (painted below) covers every wall uniformly now, front included —
	# no more separate above-roof "Facade" repaint for the south row (that
	# was a deliberate earlier choice, reversed on request: the roof should
	# read as covering the whole building from above, not leave the front
	# wall poking out over it).
	var wall_decor_by_cell := {}
	var piece_cells := {}
	for m in structure_markers:
		if m.wall_decor != "":
			wall_decor_by_cell[m.grid_pos] = m.wall_decor
		var source_id := _piece_source_id(_wall_piece_source_ids, m.piece, m.wall_material)
		if source_id >= 0:
			piece_cells[m.grid_pos] = [source_id, Vector2i.ZERO]
	_repaint_owned(structures_layer, "Structures", piece_cells)

	# Roof: same idea, one RoofMarker per cell with its own explicit piece —
	# painted by hand, or stamped in bulk by generate_roof_over_walls() ("G").
	# No shape inference here either; the only thing this loop still decides
	# is which roof cells stay unpainted because a door needs to be seen
	# through them.
	var roof_markers: Array[RoofMarker] = (
		ZoneBuilder.collect_roofs(markers) if markers else ([] as Array[RoofMarker])
	)
	var roof_paint := {}
	var roof_pieces_by_cell := {}
	for m in roof_markers:
		# A door cell skips the ROOF paint entirely (not just the door's own
		# visibility, which is handled uniformly for every wall_decor kind
		# below) — a door reads as an opening, not "solid roof over a solid
		# wall", so there's nothing to paint there in the first place.
		var is_door_cell: bool = str(wall_decor_by_cell.get(m.grid_pos, "")) == "door"
		if is_door_cell:
			continue
		var source_id := _piece_source_id(_roof_piece_source_ids, m.piece, m.roof_material)
		if source_id >= 0:
			roof_paint[m.grid_pos] = [source_id, Vector2i.ZERO]
			roof_pieces_by_cell[m.grid_pos] = m.piece

	# One extra roof row along the NORTH edge, but ONLY for a roof cell whose
	# OWN piece is a north-facing shape (NORTH_FACING_ROOF_PIECES: eave_n,
	# hip_ne, hip_nw) — those pieces' art is itself taller than one cell (same
	# anchoring as wall pieces, see StructureTileset's note), so their own
	# upper portion rises into the row ABOVE, which the roof (one tile per
	# cell) doesn't reach on its own: from outside, a band of that piece — or
	# the wall underneath it — would poke out over the top. Reusing the
	# cell's own source_id for the row above it hides that.
	#
	# Keyed off the ROOF piece, not the wall underneath (tried that first —
	# broke the floor-cell case below, where the underlying StructureMarker
	# is a plain "floor" but generate_roof_over_walls() still puts a real
	# hip_ne/hip_nw there, which needs the same extension its neighboring
	# wall corner gets). Reported bug this fixes: placing a single
	# roof_eave_e/w over an east/west wall stub with nothing north of it
	# painted TWO cells from one click — the OLD unrestricted
	# piece_cells.has(cell) check fired for ANY wall, stacking the eave into
	# a tall, blocky, "frontal" looking double tile instead of a slim side
	# eave. In a real, fully enclosed room this specific case never mattered
	# (every east/west wall cell already has either a north corner or
	# another wall cell directly above it, so the roof piece placed there is
	# never eave_e/eave_w sitting with open sky above), but an incomplete or
	# standalone east/west wall run — exactly what triggered the report —
	# has nothing above its top cell, and got the same "hide the bleed"
	# treatment a north-facing piece needs even though eave_e/eave_w's own
	# bleed isn't what's being covered there.
	#
	# ALSO requires piece_cells.has(cell) — an actual wall/floor marker
	# under THIS cell — on top of the roof-piece-type check above. Missed
	# that the first time around: with only the piece-type check, a
	# hip_ne/hip_nw placed standalone with nothing under it (no wall at
	# all, e.g. testing a corner by itself) still duplicated into the cell
	# above, reported as "las esquinas se ponen dobles con 1 clic" — there's
	# no wall bleed to hide there in the first place. Both conditions
	# together match the original justification exactly: hide the WALL's
	# bleed (piece_cells), and only for the north-facing shapes that
	# actually sit at a structure's north edge (NORTH_FACING_ROOF_PIECES).
	const NORTH_FACING_ROOF_PIECES := ["eave_n", "hip_ne", "hip_nw"]
	for cell in roof_paint.keys():
		if not (piece_cells.has(cell) and NORTH_FACING_ROOF_PIECES.has(str(roof_pieces_by_cell.get(cell, "")))):
			continue
		var above: Vector2i = cell + Vector2i(0, -1)
		if roof_paint.has(above) or piece_cells.has(above):
			continue
		roof_paint[above] = roof_paint[cell]

	_repaint_owned(roof_layer, "Roof", roof_paint)

	# The wall_decor overlay LAST: door, window, or torch, painted on top of
	# whatever piece that cell already got, not instead of it. Painted after
	# the roof so this layer's z-order (above Roof) actually shows through —
	# a door/window/torch is an opening or fixture on the WALL'S OWN FACE
	# (the vertical surface you're looking at, same reason a wall's tall
	# canvas bleeds upward past its cell — see StructureTileset's anchoring
	# note), not on the roof's horizontal plane, so the roof covering that
	# cell structurally doesn't mean the opening in the wall beneath it
	# should disappear. Windows/torch used to be hidden whenever the roof
	# painted their cell (only doors were exempt) — reported after the roof
	# was changed to cover every wall uniformly, front included: the eave
	# would have to be shrunk to a sliver to avoid swallowing a door/window
	# entirely, and even then it's an all-or-nothing per-cell check, not a
	# real pixel overlap, so a "smaller" eave wouldn't actually have fixed
	# it. Simplest correct fix: every wall_decor kind gets the same
	# always-visible treatment a door already had, not just doors.
	var decor_cells := {}
	for cell in wall_decor_by_cell:
		var kind: String = str(wall_decor_by_cell[cell])
		var source_id := int(_wall_decor_source_ids.get(kind, -1))
		if source_id >= 0:
			decor_cells[cell] = [source_id, Vector2i.ZERO]
	_repaint_owned(wall_decor_layer, "WallDecor", decor_cells)


## `table` (piece -> {material -> source_id}) lookup for "floor" (no
## material axis, see StructureTileset.FLOOR_FILE) and every other piece
## (keyed by both piece and material). -1 when the piece/material combo
## isn't in the table at all (an unknown/typo'd piece id).
func _piece_source_id(table: Dictionary, piece: String, material: String) -> int:
	if piece == "floor":
		return _floor_source_id
	var by_material: Dictionary = table.get(piece, {})
	return int(by_material.get(material, -1))


## The explicit "roof this building" action (G in build mode, see hud.gd) —
## the ONLY thing that turns walls into roof cells now that the wall brush
## no longer does it as a side effect. Fills the bounding box of the current
## walls with RoofMarkers in Game.build_roof_material, skipping cells that
## already have one, and counts as a single undo step.
##
## Returns how many cells it added, so the caller can report honestly rather
## than claiming success on a no-op.
func generate_roof_over_walls() -> int:
	var markers := get_node_or_null("Markers")
	if markers == null:
		return 0
	var material := Game.build_roof_material
	if material == ROOF_NONE:
		return 0
	var occupied := {}
	var door_cells := {}
	for m in ZoneBuilder.collect_structures(markers):
		occupied[m.grid_pos] = true
		if m.wall_decor == "door":
			door_cells[m.grid_pos] = true
	if occupied.is_empty():
		return 0
	var taken := {}
	for m in ZoneBuilder.collect_roofs(markers):
		taken[m.grid_pos] = true
	# The one remaining exemption: a door is never roofed over on any side,
	# because a door you cannot see is not a door. Every other wall —
	# including the south/front row — gets roofed like any other cell now.
	begin_build_action()
	var added := 0
	var roof_pieces := StructureGrid.compute_roof(occupied)
	for cell in roof_pieces:
		if taken.has(cell) or door_cells.has(cell):
			continue
		var r := RoofMarker.new()
		r.roof_material = material
		r.piece = StructureGrid.roof_piece_id(roof_pieces[cell])
		markers.add_child(r)
		r.owner = markers
		r.grid_pos = cell
		_record_undo({"op": "add", "marker": r})
		added += 1
	if added > 0:
		_rebuild_structures()
	return added


## The StructureMarker occupying world_pos's grid cell, or null. world_pos
## does not need to be pre-snapped — this snaps it itself.
func _structure_marker_at(world_pos: Vector2) -> StructureMarker:
	var markers := get_node_or_null("Markers")
	if markers == null:
		return null
	var cell := BuildGrid.to_cell(BuildGrid.snap(world_pos))
	for m in ZoneBuilder.collect_structures(markers):
		if m.grid_pos == cell:
			return m
	return null


## The RoofMarker occupying world_pos's grid cell, or null — same shape as
## _structure_marker_at(), used for "roof_*"'s per-cell dedup.
func _roof_marker_at(world_pos: Vector2) -> RoofMarker:
	var markers := get_node_or_null("Markers")
	if markers == null:
		return null
	var cell := BuildGrid.to_cell(BuildGrid.snap(world_pos))
	for m in ZoneBuilder.collect_roofs(markers):
		if m.grid_pos == cell:
			return m
	return null


## The CollisionMarker occupying world_pos's grid cell, or null — same shape
## as _structure_marker_at(), used for "collision_*"'s per-cell dedup.
func _collision_marker_at(world_pos: Vector2) -> CollisionMarker:
	var markers := get_node_or_null("Markers")
	if markers == null:
		return null
	var cell := BuildGrid.to_cell(BuildGrid.snap(world_pos))
	for m in ZoneBuilder.collect_collision(markers):
		if m.grid_pos == cell:
			return m
	return null


## The FloorTileMarker occupying world_pos's grid cell, or null — same shape
## as _structure_marker_at(), used by "floor_*" to repaint a cell in place.
func _floor_tile_marker_at(world_pos: Vector2) -> FloorTileMarker:
	var markers := get_node_or_null("Markers")
	if markers == null:
		return null
	var cell := BuildGrid.to_cell(BuildGrid.snap(world_pos))
	for m in ZoneBuilder.collect_floor_tiles(markers):
		if m.grid_pos == cell:
			return m
	return null


## Detaches one marker, routing it through the same undo bookkeeping
## _remove_nearest_marker() uses — factored out so painting a floor tile over
## an occupied cell can replace what's there without duplicating that logic.
func _remove_marker(marker: Node2D) -> void:
	var markers := get_node_or_null("Markers")
	if markers == null or marker.get_parent() != markers:
		return
	if _marker_spawns.has(marker):
		var spawned: Node = _marker_spawns[marker]
		if is_instance_valid(spawned):
			spawned.queue_free()
		_marker_spawns.erase(marker)
	markers.remove_child(marker)
	# Same rule as _remove_nearest_marker(): an orphan held by an open undo
	# action is what undo puts back, so it must not be freed yet.
	if _recording_action:
		_record_undo({"op": "remove", "marker": marker})
	else:
		marker.queue_free()


## The "door"/"window_*"/"torch" build-mode tools: paint `kind` onto an
## EXISTING wall/corner cell instead of placing a new marker — a door or
## window is a property of a wall cell (StructureMarker.wall_decor), not a
## separate piece the player stamps down. Clicking the SAME kind again on a
## cell that already has it clears it (a toggle, same UX the old is_door
## boolean had); clicking a DIFFERENT kind replaces whatever was there.
func _paint_wall_decor(kind: String, world_pos: Vector2) -> void:
	var marker := _structure_marker_at(world_pos)
	if marker == null:
		return
	var previous := marker.wall_decor
	var next := "" if marker.wall_decor == kind else kind
	if next == previous:
		return
	_record_undo({"op": "decor", "marker": marker, "was": previous})
	marker.wall_decor = next
	_rebuild_structures()


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


## Camera2D.zoom: <1.0 is zoomed IN, >1.0 is zoomed OUT (confirmed by trial —
## counter-intuitive at a glance). MIN keeps the normal in-combat framing as
## the closest build mode gets; MAX is enough to see a whole cluster of
## placed houses/structures at once when laying out a large area.
const MIN_BUILD_ZOOM := 1.0
const MAX_BUILD_ZOOM := 3.5
const BUILD_ZOOM_STEP := 0.25


## Which mouse button is currently held down for a drag-paint, or 0 for
## none — see _unhandled_input()'s motion branch.
var _build_drag_button: int = 0

# ------------------------------------------------------------------ undo
# Build-mode undo stack. Each entry is one ACTION — a whole gesture, so a
# single drag that painted 30 wall cells undoes as one step rather than
# thirty, which is what makes undo actually usable while mapping. An action
# is a list of reversible steps recorded as they happen:
#   {"op": "add",   "marker": Node2D}                     -> undo removes it
#   {"op": "remove","marker": Node2D, "spawned": Node}    -> undo re-adds it
#   {"op": "decor", "marker": StructureMarker, "was": String} -> restores it
# Removed markers are kept alive (orphaned, not queue_free()'d) precisely so
# undo can put the SAME node back with all its properties intact instead of
# rebuilding an approximation of it.
const MAX_UNDO_ACTIONS := 64
var _undo_stack: Array = []
var _current_action: Array = []
var _recording_action: bool = false


## Opens a new undo action. Every _place_marker/_remove_nearest_marker call
## until the next begin_build_action() folds into this one step.
func begin_build_action() -> void:
	_flush_build_action()
	_current_action = []
	_recording_action = true


func _record_undo(step: Dictionary) -> void:
	if _recording_action:
		_current_action.append(step)


func _flush_build_action() -> void:
	if _recording_action and not _current_action.is_empty():
		_undo_stack.append(_current_action)
		while _undo_stack.size() > MAX_UNDO_ACTIONS:
			# Dropping the oldest action also drops its claim on any markers
			# it was holding for a possible re-add; those are freed here
			# rather than leaking as permanent orphans.
			var dropped: Array = _undo_stack.pop_front()
			for step in dropped:
				if str(step.get("op", "")) == "remove":
					var m: Node = step.get("marker")
					# get_parent(), not is_inside_tree(): a zone under test (and
					# an editor-side zone) is itself outside the scene tree, so
					# is_inside_tree() is false for markers that ARE still
					# parented and live. Parentage is the real question here.
					if m and is_instance_valid(m) and m.get_parent() == null:
						m.queue_free()
	_current_action = []
	_recording_action = false


## Reverses the most recent action. Public so hud.gd can bind Ctrl+Z.
## Returns false when there was nothing left to undo.
func undo_build_action() -> bool:
	_flush_build_action()
	if _undo_stack.is_empty():
		return false
	var markers := get_node_or_null("Markers")
	if markers == null:
		return false
	var action: Array = _undo_stack.pop_back()
	var touched_structure := false
	var touched_collision := false
	var touched_floor_tile := false
	# Reverse order: a gesture's steps have to unwind last-in-first-out or a
	# remove-then-add on the same cell would restore in the wrong order.
	for i in range(action.size() - 1, -1, -1):
		var step: Dictionary = action[i]
		# A brush stroke undoes by putting its dirty rect of the coverage mask
		# back; it has no marker, so it is handled before the marker branches.
		if str(step.get("op", "")) == "paint":
			var painted: PaintLayer = step.get("layer")
			if painted != null and is_instance_valid(painted):
				painted.restore(step.get("rect"), step.get("before"))
			continue
		var marker: Node2D = step.get("marker")
		if marker == null or not is_instance_valid(marker):
			continue
		match str(step.get("op", "")):
			"add":
				if _marker_spawns.has(marker):
					var spawned: Node = _marker_spawns[marker]
					if is_instance_valid(spawned):
						spawned.queue_free()
					_marker_spawns.erase(marker)
				# See _flush_build_action() on why parentage, not is_inside_tree().
				if marker.get_parent() == markers:
					markers.remove_child(marker)
				marker.queue_free()
			"remove":
				markers.add_child(marker)
				marker.owner = markers
				var respawned := ZoneBuilder.build_one(marker, self)
				if respawned:
					_marker_spawns[marker] = respawned
			"decor":
				(marker as StructureMarker).wall_decor = str(step.get("was", ""))
		if marker is StructureMarker or marker is RoofMarker:
			touched_structure = true
		elif marker is CollisionMarker:
			touched_collision = true
		elif marker is FloorTileMarker:
			touched_floor_tile = true
	if touched_structure:
		_rebuild_structures()
	if touched_collision:
		_rebuild_collision()
	if touched_floor_tile:
		_rebuild_floor_tiles()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not Game.build_mode:
		return

	# Drag-painting: holding the button and sweeping fills a run of cells
	# instead of needing one click per cell, which is the single biggest
	# time sink when laying out a building or a path by hand. Only grid
	# kinds drag — a free-placed prop swept across the screen would spray
	# dozens of overlapping barrels, so those stay click-per-item.
	if event is InputEventMouseMotion and _build_drag_button != 0:
		var drag_kind := Game.build_selected_kind
		# The free brush is the one tool that WANTS every motion event: the
		# stroke is the drag, not a run of cells.
		if PaintLayer.is_paint_id(drag_kind):
			paint_at(drag_kind, get_global_mouse_position(),
				_build_drag_button == MOUSE_BUTTON_RIGHT,
				PaintLayer.radius_for(Game.build_brush_size))
		elif _is_grid_kind(drag_kind):
			var drag_pos := get_global_mouse_position()
			if _build_drag_button == MOUSE_BUTTON_LEFT:
				_place_marker(drag_kind, drag_pos)
			else:
				_remove_nearest_marker(drag_pos)
		return

	if not (event is InputEventMouseButton):
		return
	if not event.pressed:
		if event.button_index == _build_drag_button:
			_build_drag_button = 0
			# A stroke ends on the release, not on the next gesture's begin —
			# that is the moment its dirty rect is known and can be filed.
			if PaintLayer.is_paint_id(Game.build_selected_kind):
				_end_paint_stroke(Game.build_selected_kind)
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		# Plain Containers/Labels never consume a wheel notch themselves, so
		# it reaches _unhandled_input even while the mouse sits right over
		# the palette — without this check, scrolling over the BuildPanel
		# zoomed the world underneath it instead. Only zoom when there's no
		# UI under the cursor at all.
		if get_viewport().gui_get_hovered_control() != null:
			return
		_zoom_build_camera(-BUILD_ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else BUILD_ZOOM_STEP)
		return

	# A click that starts over the palette must not also place a marker in
	# the world behind it.
	if get_viewport().gui_get_hovered_control() != null:
		return

	var world_pos := get_global_mouse_position()
	var kind := Game.build_selected_kind
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return
	_build_drag_button = event.button_index
	begin_build_action()
	if PaintLayer.is_paint_id(kind):
		_begin_paint_stroke(kind)
		paint_at(kind, world_pos, event.button_index == MOUSE_BUTTON_RIGHT,
			PaintLayer.radius_for(Game.build_brush_size))
	elif event.button_index == MOUSE_BUTTON_LEFT:
		_place_marker(kind, world_pos)
	else:
		_remove_nearest_marker(world_pos)


## True for kinds that occupy one fixed grid cell (walls, wall decor, roof)
## rather than being free-placed at an arbitrary position.
func _is_grid_kind(kind: String) -> bool:
	return BuildPlacement.is_grid_kind(kind)


func _zoom_build_camera(delta_zoom: float) -> void:
	var player := Game.get_local_player()
	if player == null or not ("camera" in player) or player.camera == null:
		return
	var cam: Camera2D = player.camera
	var z := clampf(cam.zoom.x + delta_zoom, MIN_BUILD_ZOOM, MAX_BUILD_ZOOM)
	cam.zoom = Vector2(z, z)


## Every "ESTRUCTURA" palette id that places a StructureMarker — one shape
## button per StructureTileset.WALL_PIECES entry, plus "floor" (see its
## class doc). Which MATERIAL a placed piece gets is a separate axis
## (Game.build_wall_material), not part of this id — see _place_marker().
## Alias of BuildPlacement.WALL_PIECE_IDS — the editor plugin shares that
## list, so it lives there (see build_placement.gd's class doc).
const WALL_PIECE_IDS := BuildPlacement.WALL_PIECE_IDS


## `single_cell` is only ever true for _paint_floor_brush()'s re-entry below
## — everything else leaves it alone and gets the brush the user chose.
func _place_marker(kind: String, world_pos: Vector2, single_cell: bool = false) -> void:
	if not single_cell and kind.begins_with("floor_") and _brush_size(kind) > 1:
		_paint_floor_brush(kind, world_pos)
		return
	# "door"/"window_*"/"torch" never place a new marker — they paint onto
	# an existing wall cell (see _paint_wall_decor()). A wall/floor/roof kind
	# snaps to the grid and refuses a cell that's already occupied, same
	# spirit as is_placement_valid() below but grid-aware instead of
	# distance-aware.
	if StructureTileset.WALL_DECOR.has(kind):
		_paint_wall_decor(kind, world_pos)
		return
	var is_wall := WALL_PIECE_IDS.has(kind)
	var is_roof := kind.begins_with("roof_")
	var is_collision := kind.begins_with("collision_")
	var is_floor_tile := kind.begins_with("floor_")
	# A roof piece with no material selected (Game.build_roof_material ==
	# "none") has nothing to paint with — refuse the click rather than
	# stamp a RoofMarker whose material has no art (see StructureTileset;
	# it would silently paint nothing, which reads as a broken click).
	if is_roof and Game.build_roof_material == ROOF_NONE:
		return
	if is_wall or is_roof or is_collision or is_floor_tile:
		world_pos = BuildGrid.snap(world_pos)
		var dup: Node2D = null
		if is_wall:
			dup = _structure_marker_at(world_pos)
		elif is_roof:
			dup = _roof_marker_at(world_pos)
		elif is_collision:
			dup = _collision_marker_at(world_pos)
		else:
			# Repainting a cell that already holds a DIFFERENT floor tile
			# replaces it (that's what painting over something means), but
			# re-painting the same tile is a no-op — otherwise a single drag
			# across one cell would stack duplicate markers on it.
			var existing := _floor_tile_marker_at(world_pos)
			if existing != null:
				if existing.tile_id == kind.trim_prefix("floor_"):
					return
				_remove_marker(existing)
		if dup != null:
			return
		# Bounds only — not is_placement_valid()'s marker-spacing rule, which
		# would leave an unbuildable hole in a room over an unrelated nearby
		# marker. See is_within_bounds()'s doc comment.
		if not is_within_bounds(world_pos):
			return
	else:
		# Off by default: raw cursor position, for organic scatter (bushes,
		# rocks, mobs). On (T, see hud.gd) snaps to the same grid "wall"
		# already always uses, so decor lines up cleanly against a painted
		# wall instead of needing to be pixel-hunted into place.
		if Game.build_snap_to_grid:
			world_pos = BuildGrid.snap(world_pos)
		if not is_placement_valid(world_pos, kind):
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
	_record_undo({"op": "add", "marker": marker})
	if is_wall:
		var sm := marker as StructureMarker
		sm.wall_material = Game.build_wall_material
		sm.grid_pos = BuildGrid.to_cell(world_pos)
		_rebuild_structures()
	elif is_roof:
		var rm := marker as RoofMarker
		rm.roof_material = Game.build_roof_material
		rm.grid_pos = BuildGrid.to_cell(world_pos)
		_rebuild_structures()
	elif is_collision:
		(marker as CollisionMarker).grid_pos = BuildGrid.to_cell(world_pos)
		_rebuild_collision()
	elif is_floor_tile:
		(marker as FloorTileMarker).grid_pos = BuildGrid.to_cell(world_pos)
		_rebuild_floor_tiles()
	else:
		marker.global_position = world_pos
		# Buildings don't get the flat free-45°-steps rotation every other
		# free-placed prop does — some (houses/mansion/bank) always face
		# front, others (market/blacksmith/dock) only rotate in the 4
		# cardinal directions, and a directional one of those (blacksmith)
		# swaps its sprite instead of transforming it. See
		# BuildingMarker.placement_for().
		if kind.begins_with("building_"):
			var placement := BuildingMarker.placement_for(kind.trim_prefix("building_"), Game.build_rotation)
			marker.rotation = placement["rotation"]
			(marker as BuildingMarker).facing_steps = placement["facing_steps"]
		else:
			marker.rotation = Game.build_rotation
		var spawned := ZoneBuilder.build_one(marker, self)
		if spawned:
			_marker_spawns[marker] = spawned


## Stamps a Game.build_brush_size square of cells centred on the click, one
## FloorTileMarker per cell. One marker per cell rather than one bigger
## marker on purpose: the cells stay independently erasable and repaintable,
## the saved layout gains nothing new to represent, and the auto-road mask
## (which only ever asks "is this cell road?") needs to know nothing about
## brushes at all.
##
## Re-enters _place_marker() per cell so the dedup, bounds and undo rules
## stay in one place; the whole stamp still folds into the single undo action
## the click opened.
func _paint_floor_brush(kind: String, world_pos: Vector2) -> void:
	var size := _brush_size(kind)
	# Biased up-left of the cursor: an even-sided block has no centre cell to
	# put under it, and picking a side keeps a drag from wobbling.
	var start := BuildGrid.to_cell(BuildGrid.snap(world_pos)) - Vector2i(size / 2, size / 2)
	for dy in size:
		for dx in size:
			_place_marker(kind, BuildGrid.cell_to_world(start + Vector2i(dx, dy)), true)


## Cells a side one click of `kind` paints: the brush the user set, raised to
## the minimum the kind's art can actually draw (only auto-roads have one,
## see RoadAutotiler.brush_size_for()).
func _brush_size(kind: String) -> int:
	return RoadAutotiler.brush_size_for(kind, clampi(Game.build_brush_size, 1, Game.MAX_BRUSH_SIZE))


## False when world_pos is outside the zone's bounds or too close to an
## existing marker — the same signal a Rust/Valheim-style building ghost
## turning red gives before you commit to a spot. Public (no leading
## underscore) so build_ghost.gd can query it every frame for the preview
## tint, the same way it queries Game.build_selected_kind.
const MIN_MARKER_SPACING := 20.0


## Every actual marker type this build mode places — used to filter
## ZoneBuilder._all_descendants() results down to real markers, excluding the
## plain Node2D (or instanced sub-scene root) an author might use to GROUP
## several markers together under "Markers" — e.g. building one house, then
## saving that group as its own scene to instance repeatedly elsewhere
## (Godot's equivalent of a prefab). Without this filter, that grouping
## node's own origin would count as "a marker" for spacing/removal purposes,
## which is never what's wanted (removing the group's container instead of
## the one piece you clicked, or refusing a placement too close to a house's
## origin rather than its actual walls).
func _is_marker(node: Node) -> bool:
	return BuildPlacement.is_marker(node)


## `kind` is optional (build_ghost.gd and _place_marker() both pass
## Game.build_selected_kind/the kind being placed; anything else defaults to
## the flat MIN_MARKER_SPACING). A "building_*" kind gets a clearance sized
## to its own sprite instead — see BuildingMarker.clearance_for()'s doc: a
## whole prefab house 20px from the nearest barrel is still a house stamped
## on top of a barrel, not a valid placement. Checked both ways (the
## clearance of the kind being placed AND of whatever existing marker it's
## being measured against), so a small prop also can't be dropped inside an
## already-placed building's footprint.
func is_placement_valid(world_pos: Vector2, kind: String = "") -> bool:
	if not is_within_bounds(world_pos):
		return false
	var markers := get_node_or_null("Markers")
	if markers == null:
		return true
	var own_clearance := _clearance_for_kind(kind)
	for child in ZoneBuilder._all_descendants(markers):
		# Only free-placed markers crowd each other. Ground and structure
		# cells never block a prop — see BuildPlacement.blocks_free_placement().
		if not BuildPlacement.blocks_free_placement(child):
			continue
		var other_clearance := MIN_MARKER_SPACING
		if child is BuildingMarker:
			other_clearance = BuildingMarker.clearance_for((child as BuildingMarker).building_id)
		if (child as Node2D).global_position.distance_to(world_pos) < maxf(own_clearance, other_clearance):
			return false
	return true


func _clearance_for_kind(kind: String) -> float:
	if kind.begins_with("building_"):
		return BuildingMarker.clearance_for(kind.trim_prefix("building_"))
	return MIN_MARKER_SPACING


## Bounds only, no marker-spacing check — what "wall" placement uses instead
## of is_placement_valid(). A wall cell already refuses to double up on
## itself via _structure_marker_at() (grid dedup is exact-cell, not a 20px
## radius), and MIN_MARKER_SPACING existing to keep scattered mobs/resources/
## POIs from overlapping isn't a reason to leave an unbuildable hole in a
## room just because a tree happens to sit within 20px of one of its grid
## points — see world_zone.gd's build-mode section / docs/GDD.md.
func is_within_bounds(world_pos: Vector2) -> bool:
	var hw := world_size.x * 0.5
	var hh := world_size.y * 0.5
	return absf(world_pos.x) <= hw and absf(world_pos.y) <= hh


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
			if WALL_PIECE_IDS.has(kind):
				var sm := StructureMarker.new()
				sm.piece = kind
				# wall_material is set by the caller (_place_marker()) right
				# after this returns — it's Game.build_wall_material, a
				# world_pos-independent global this factory has no reason to
				# know about.
				return sm
			if kind.begins_with("decor_"):
				var d := DecorMarker.new()
				d.decor_id = kind.trim_prefix("decor_")
				return d
			if kind.begins_with("building_"):
				var b := BuildingMarker.new()
				b.building_id = kind.trim_prefix("building_")
				return b
			if kind.begins_with("roof_"):
				var r := RoofMarker.new()
				r.piece = kind.trim_prefix("roof_")
				# roof_material is set by the caller (_place_marker()), same
				# reasoning as wall_material above.
				return r
			if kind.begins_with("collision_"):
				return CollisionMarker.new()
			if kind.begins_with("floor_"):
				var f := FloorTileMarker.new()
				f.tile_id = kind.trim_prefix("floor_")
				return f
			return null


## Deletes the closest marker within reach (and the live entity it spawned,
## if any) — the undo button for _place_marker().
func _remove_nearest_marker(world_pos: Vector2, max_dist: float = 24.0) -> void:
	var markers := get_node_or_null("Markers")
	if markers == null:
		return
	var closest: Node2D = null
	var closest_dist := max_dist
	for child in ZoneBuilder._all_descendants(markers):
		if not _is_marker(child):
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
	var was_structure := closest is StructureMarker or closest is RoofMarker
	var was_collision := closest is CollisionMarker
	var was_floor_tile := closest is FloorTileMarker
	markers.remove_child(closest)
	# NOT queue_free()'d when an undo action is open: the orphaned node is
	# what undo puts back, with every property already intact. _flush_build_
	# action() frees it once the action falls off the end of the stack.
	if _recording_action:
		_record_undo({"op": "remove", "marker": closest})
	else:
		closest.queue_free()
	if was_structure:
		_rebuild_structures()
	elif was_collision:
		_rebuild_collision()
	elif was_floor_tile:
		_rebuild_floor_tiles()


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

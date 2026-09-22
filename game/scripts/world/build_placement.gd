class_name BuildPlacement
extends RefCounted
## The rules of "what does placing this id mean", shared by BOTH build-mode
## front-ends: the in-game overlay (world_zone.gd) and the Godot editor
## plugin (addons/build_mode_editor/plugin.gd).
##
## It exists because those two used to carry their own copies of this logic,
## kept in sync by hand — and they drifted, every time. A new palette id had
## to be taught to two factories, two "is this a marker" checks and two
## per-cell dedup helpers, and forgetting one produced the worst kind of bug:
## the piece works in game and silently does nothing in the editor, or vice
## versa. Anything that answers "what class is this id / does it snap to the
## grid / what already occupies this cell" belongs here, so adding a palette
## id stays a one-place change.
##
## What deliberately does NOT live here: how a marker is attached to the
## scene and how that is undone. In game that's world_zone.gd's own undo
## stack; in the editor it has to be EditorUndoRedoManager or Ctrl+Z inside
## Godot won't see it. Those are genuinely different and stay with each
## caller.

## Ids that place a StructureMarker (the wall kit, plus its interior floor).
const WALL_PIECE_IDS: Array[String] = [
	"wall_n", "wall_e", "wall_s", "wall_w",
	"corner_in_ne", "corner_in_nw", "corner_in_se", "corner_in_sw",
	"corner_out_ne", "corner_out_nw", "corner_out_se", "corner_out_sw",
	"partition_hub", "partition_n", "partition_e", "partition_s", "partition_w",
	"column", "floor",
]


static func is_wall(kind: String) -> bool:
	return WALL_PIECE_IDS.has(kind)


static func is_roof(kind: String) -> bool:
	return kind.begins_with("roof_")


static func is_collision(kind: String) -> bool:
	return kind.begins_with("collision_")


## The painted floor/terrain tiles (the "SUELO" category's floor_* half).
## NOT the same as the bare "floor" id above, which is the structure kit's
## interior floor piece — hence the underscore in the prefix.
static func is_floor_tile(kind: String) -> bool:
	return kind.begins_with("floor_")


## Ids that occupy one fixed grid cell rather than being free-placed at an
## arbitrary position. Drives grid snapping, the per-cell dedup below, and
## whether a drag across the viewport paints a run of cells.
static func is_grid_kind(kind: String) -> bool:
	return (is_wall(kind)
		or StructureTileset.WALL_DECOR.has(kind)
		or is_roof(kind)
		or is_collision(kind)
		or is_floor_tile(kind))


## Every node type build mode can place. Used to tell a marker apart from a
## grouping node (a "House" Node2D holding a room's pieces) when walking the
## Markers subtree.
static func is_marker(node: Node) -> bool:
	return (node is StructureMarker or node is RoofMarker
		or node is DecorMarker or node is MobSpawnMarker or node is ResourceNodeMarker
		or node is POIMarker or node is BuildingMarker
		or node is CollisionMarker or node is FloorTileMarker)


## True only for markers that occupy real SPACE in the world — the ones the
## minimum-spacing rule exists for, so two barrels (or a mob and a tree)
## don't end up inside each other.
##
## Grid-cell markers are deliberately excluded. They are ground and
## structure, not objects: a painted floor tile, a collision brush cell, a
## wall or a roof must never stop you from dropping a prop on top of it.
## Counting them made the map progressively unbuildable — every painted cell
## planted a FloorTileMarker, cells sit 32px apart, and the spacing radius is
## 20px, so once an area was painted there was nowhere left to click. The
## same bug also blocked placing anything inside a finished room.
static func blocks_free_placement(node: Node) -> bool:
	if not is_marker(node):
		return false
	return not (node is FloorTileMarker or node is CollisionMarker
		or node is StructureMarker or node is RoofMarker)


## The marker a palette id places, fully configured except for its position.
##
## `wall_material`/`roof_material` are passed in rather than read from a
## global: the editor plugin has no access to the `Game` autoload (an
## autoload only exists while the game runs, not while a scene is being
## edited), so the choice has to arrive as an argument for both callers to
## share this one factory.
static func make_marker(kind: String, wall_material: String = "", roof_material: String = "") -> Node2D:
	if is_wall(kind):
		var sm := StructureMarker.new()
		sm.piece = kind
		if wall_material != "":
			sm.wall_material = wall_material
		return sm
	if is_roof(kind):
		var rm := RoofMarker.new()
		rm.piece = kind.trim_prefix("roof_")
		if roof_material != "":
			rm.roof_material = roof_material
		return rm
	if is_collision(kind):
		return CollisionMarker.new()
	if is_floor_tile(kind):
		var ft := FloorTileMarker.new()
		ft.tile_id = kind.trim_prefix("floor_")
		return ft
	if kind.begins_with("decor_"):
		var dm := DecorMarker.new()
		dm.decor_id = kind.trim_prefix("decor_")
		return dm
	if kind.begins_with("building_"):
		var bm := BuildingMarker.new()
		bm.building_id = kind.trim_prefix("building_")
		return bm
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
	return null


## Whatever grid marker of `kind`'s own family already sits on `cell`, or
## null. Searches at any depth (ZoneBuilder.collect_*), so a piece grouped
## inside a house still counts as occupying its cell.
##
## Families are kept separate on purpose: a collision brush and a wall can
## share a cell, and painting a floor tile under an existing wall has to
## work. Only a piece of the SAME family blocks (or replaces) another.
static func grid_marker_at(markers: Node, kind: String, cell: Vector2i) -> Node2D:
	if markers == null:
		return null
	if is_wall(kind):
		for m in ZoneBuilder.collect_structures(markers):
			if m.grid_pos == cell:
				return m
	elif is_roof(kind):
		for m in ZoneBuilder.collect_roofs(markers):
			if m.grid_pos == cell:
				return m
	elif is_collision(kind):
		for m in ZoneBuilder.collect_collision(markers):
			if m.grid_pos == cell:
				return m
	elif is_floor_tile(kind):
		for m in ZoneBuilder.collect_floor_tiles(markers):
			if m.grid_pos == cell:
				return m
	return null


## True when placing `kind` on a cell already holding `existing` should be a
## no-op instead of a replacement. Painting a floor tile over a DIFFERENT
## floor tile repaints the cell (that is what painting means); every other
## grid family refuses a second piece on an occupied cell, and repainting the
## identical tile is a no-op so one drag across a cell can't stack markers.
static func is_redundant_placement(kind: String, existing: Node2D) -> bool:
	if existing == null:
		return false
	if is_floor_tile(kind) and existing is FloorTileMarker:
		return (existing as FloorTileMarker).tile_id == kind.trim_prefix("floor_")
	return true

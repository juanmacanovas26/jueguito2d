@tool
extends EditorPlugin
## Editor-side counterpart to world_zone.gd's runtime build mode — places the
## same markers (StructureMarker/RoofMarker/DecorMarker/mob/
## resource/POI) directly in the 2D editor viewport, repainting the real
## Structures/Roof/WallDecor TileMapLayers immediately, no
## Play required. See docs/GDD.md.
##
## Deliberately does NOT call world_zone.gd's own _place_marker() — that
## method reads Game.build_wall_material/build_rotation/etc., and the `Game`
## autoload is a Play-mode concept, not reliably present while just editing a
## scene. Instead both front-ends share BuildPlacement, which owns every rule
## about what an id places, whether it snaps to the grid, and what already
## occupies a cell. This file used to keep its OWN copy of that mapping "in
## sync by hand" and it drifted every single time a palette id was added —
## the piece would work in game and silently do nothing here.
## _rebuild_structures()/_rebuild_floor_tiles() don't touch Game (confirmed
## by reading world_zone.gd) so those are called directly on the edited zone.
##
## What still differs from the in-game tool, on purpose: undo goes through
## EditorUndoRedoManager (so Ctrl+Z inside Godot sees it and the scene is
## marked unsaved), and the wall/roof material and rotation come from this
## plugin's dock instead of the `Game` autoload.
##
## Every placement goes through the EditorUndoRedoManager (get_undo_redo())
## rather than a plain add_child() — that's what makes Ctrl+Z inside the
## editor work AND is what marks the scene as unsaved, matching how every
## other Godot editor tool behaves.

const BuildDockScript := preload("res://addons/build_mode_editor/build_dock.gd")
const MIN_MARKER_SPACING := 20.0

var _dock: Control
var _edited_zone: Node2D
## The zone ensure_render_layers() has already run for, or null. Compared by
## identity against _edited_zone each click (not a plain bool) so switching
## between two open zone tabs re-runs it for whichever one is new, without
## redoing it pointlessly on every single click for the one already primed.
var _layers_ready_for: Node2D = null


func _enter_tree() -> void:
	_dock = PanelContainer.new()
	_dock.set_script(BuildDockScript)
	_dock.name = "Build Mode"
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _dock)
	_dock.zone_open_requested.connect(_on_zone_open_requested)
	_dock.zone_create_requested.connect(_on_zone_create_requested)
	# Belt-and-suspenders: SHOULD make Godot forward canvas input to this
	# plugin unconditionally, regardless of node selection. In testing on
	# 4.7.1 this alone was not enough — clicks never reached
	# _forward_canvas_gui_input() at all once _handles()/_edit() stopped
	# being the thing granting access (see _handles() below for the actual
	# fix that made it work). Left in since it should only ever ADD
	# forwarding, never remove it.
	set_input_event_forwarding_always_enabled()
	print("[BuildModeEditor] plugin loaded")


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


## Godot only calls _forward_canvas_gui_input() for a plugin that has
## "claimed" the CURRENTLY SELECTED node via this pair of callbacks — but
## clicking anywhere in the 2D viewport re-selects whatever node is under the
## cursor (Floor, a TileMapLayer covering the whole map, in practice), which
## would un-claim the zone on the very first click if _handles() only
## accepted the zone root itself (reported: clicking did nothing once
## "Floor" had gotten selected). Fix: accept ANY node that belongs to a zone
## scene, not just its root — Floor/Roof/a marker/anything else being
## selected still counts as "editing this zone" as far as this plugin cares,
## since _current_zone() below re-resolves the actual zone from the open
## scene's root anyway, not from whatever object triggered this check.
func _handles(object: Object) -> bool:
	return object is Node and _current_zone() != null


func _edit(_object: Object) -> void:
	pass # nothing to store — _current_zone() is re-resolved fresh every click.


## The zone this input should apply to: the root of whatever scene is
## currently open in the 2D viewport, if it looks like a zone (has a
## "Markers" node) — regardless of which node is actually selected.
func _current_zone() -> Node2D:
	var root := get_editor_interface().get_edited_scene_root()
	if root is Node2D and (root as Node2D).get_node_or_null("Markers") != null:
		return root as Node2D
	return null


## world_zone.gd's Structures/WallDecor/Roof TileMapLayers (and
## the TileSet source-id tables _rebuild_structures() reads
## from) are normally only built by _ready(), which never runs while just
## editing a scene — only on Play. Without this, _rebuild_structures() would
## silently no-op forever (it bails out the instant any of those layers is
## missing), so a piece placed in the editor would create the marker node
## but never actually paint anything.
func _ensure_zone_layers() -> void:
	print("[BuildModeEditor] _ensure_zone_layers: ready_for=", _layers_ready_for, " edited=", _edited_zone)
	if _layers_ready_for == _edited_zone:
		print("[BuildModeEditor] _ensure_zone_layers: already primed, skipping")
		return
	if _edited_zone.has_method("ensure_render_layers"):
		_edited_zone.call("ensure_render_layers")
		print("[BuildModeEditor] ensure_render_layers() called on ", _edited_zone.name)
	else:
		print("[BuildModeEditor] WARNING: ", _edited_zone.name, " has no ensure_render_layers() — script may be stale, try reloading the scene")
	_layers_ready_for = _edited_zone


## --------------------------------------------------------------- zones
## Multi-zone: build_dock.gd's "Zona" section does the listing (read-only,
## no EditorPlugin privilege needed) and emits a signal for the two things
## that DO need it — switching the open scene, and creating+saving a new
## one. See build_dock.gd's class doc for why the split is here.

const ZONE_DIR := "res://scenes/world/"
const WorldZoneScript := preload("res://scripts/world/world_zone.gd")


func _on_zone_open_requested(path: String) -> void:
	if not ResourceLoader.exists(path):
		print("[BuildModeEditor] zone scene not found: ", path)
		return
	get_editor_interface().open_scene_from_path(path)


## Builds the same minimal skeleton _build_world()/_ready() expect to find —
## a "Floor" TileMapLayer (no tile_set, no cells: _build_floor() fills it in
## procedurally the first time this zone actually plays) and an empty
## "Markers" Node2D. Getting the Floor node's NAME exactly right matters: a
## zone without one crashes on Play (see docs/GDD.md — this is the exact bug
## a stray node rename produced earlier this session).
func _on_zone_create_requested(display_name: String) -> void:
	var slug := _slugify(display_name)
	if slug == "":
		print("[BuildModeEditor] '", display_name, "' has no usable characters after slugifying, refusing to create a zone")
		return
	var path := ZONE_DIR + slug + ".tscn"
	if ResourceLoader.exists(path):
		print("[BuildModeEditor] ", path, " already exists — opening it instead of overwriting")
		_on_zone_open_requested(path)
		return

	var root := Node2D.new()
	root.name = slug.capitalize().replace(" ", "")
	root.set_script(WorldZoneScript)
	root.set("zone_name", display_name)

	var floor_layer := TileMapLayer.new()
	floor_layer.name = "Floor"
	root.add_child(floor_layer)
	floor_layer.owner = root

	var markers := Node2D.new()
	markers.name = "Markers"
	root.add_child(markers)
	markers.owner = root

	var packed := PackedScene.new()
	var ok := packed.pack(root) == OK and ResourceSaver.save(packed, path) == OK
	root.free()
	if not ok:
		print("[BuildModeEditor] failed to create/save the new zone scene at ", path)
		return

	print("[BuildModeEditor] created zone '", display_name, "' at ", path)
	get_editor_interface().get_resource_filesystem().scan()
	if _dock and _dock.has_method("refresh_zone_list"):
		_dock.call("refresh_zone_list")
	_on_zone_open_requested(path)


## Lowercase ascii letters/digits, everything else collapses to a single "_"
## — good enough for a filename; unicode accents just get dropped rather
## than transliterated (a mapper can still see the real name in zone_name,
## this only decides the .tscn's path).
static func _slugify(name: String) -> String:
	var out := ""
	var last_was_underscore := false
	for c in name.strip_edges().to_lower():
		var is_alnum := (c >= "a" and c <= "z") or (c >= "0" and c <= "9")
		if is_alnum:
			out += c
			last_was_underscore = false
		elif not last_was_underscore:
			out += "_"
			last_was_underscore = true
	return out.trim_prefix("_").trim_suffix("_")


## Which mouse button is currently held down for a drag-paint, or 0. Mirrors
## world_zone.gd's _build_drag_button: holding and sweeping fills a run of
## cells instead of needing one click per cell, which is the single biggest
## time sink when laying out a road or a building by hand.
var _drag_button: int = 0


## Screen -> world for the 2D editor viewport's current pan/zoom.
func _viewport_world_pos(screen_pos: Vector2) -> Vector2:
	var viewport := get_editor_interface().get_editor_viewport_2d()
	return viewport.global_canvas_transform.affine_inverse() * screen_pos


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if _dock == null or not _dock.tool_active:
		return false

	var zone := _current_zone()
	if zone == null:
		return false

	# Drag-painting. Only grid kinds drag: sweeping a free-placed prop across
	# the viewport would spray hundreds of barrels, so those stay click-only —
	# the same split world_zone.gd's _unhandled_input() makes in game.
	if event is InputEventMouseMotion:
		# Feed the ghost preview even when not dragging — that's the whole
		# point of a preview.
		_ghost_pos = _viewport_world_pos((event as InputEventMouseMotion).position)
		update_overlays()

	if event is InputEventMouseMotion and _drag_button != 0:
		# The free brush is not a grid kind but IS the tool that most wants a
		# drag: the stroke is the gesture (see PaintLayer).
		# Typed, not inferred: _dock is a plain Control here, so := cannot work
		# out what selected_kind is and the whole plugin fails to parse.
		var dragging: String = _dock.selected_kind
		if not (BuildPlacement.is_grid_kind(dragging) or PaintLayer.is_paint_id(dragging)):
			return true
		_edited_zone = zone
		_ensure_zone_layers()
		var drag_pos := _viewport_world_pos((event as InputEventMouseMotion).position)
		if PaintLayer.is_paint_id(_dock.selected_kind):
			_paint(_dock.selected_kind, drag_pos, _drag_button == MOUSE_BUTTON_RIGHT)
		elif _drag_button == MOUSE_BUTTON_LEFT:
			_place(_dock.selected_kind, drag_pos)
		else:
			_remove_nearest(drag_pos)
		return true

	if not (event is InputEventMouseButton):
		return false
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
		return false
	if mb.ctrl_pressed or mb.shift_pressed or mb.alt_pressed:
		return false # let modified clicks (box-select, etc.) work as normal

	# Swallow the release half of the click too, not just the press — left
	# unhandled, it fell through to the editor's own click-to-select, which
	# ran AFTER this function had already placed a piece on the press event
	# and reselected whatever node sits under the cursor (reported: clicking
	# with the zone root selected ended with "Floor" selected instead, even
	# though the piece really was getting placed on the press).
	if not mb.pressed:
		if mb.button_index == _drag_button:
			_drag_button = 0
			# A stroke is only undoable once its dirty rect is known, which is
			# on release — see _end_paint_stroke().
			if PaintLayer.is_paint_id(_dock.selected_kind):
				_end_paint_stroke(_dock.selected_kind)
		return true

	_drag_button = mb.button_index
	_edited_zone = zone
	_ensure_zone_layers()

	var world_pos := _viewport_world_pos(mb.position)

	if PaintLayer.is_paint_id(_dock.selected_kind):
		_begin_paint_stroke(_dock.selected_kind)
		_paint(_dock.selected_kind, world_pos, mb.button_index == MOUSE_BUTTON_RIGHT)
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		_place(_dock.selected_kind, world_pos)
	else:
		_remove_nearest(world_pos)
	return true


## ------------------------------------------------------------- placement

func _place(kind: String, world_pos: Vector2) -> void:
	var markers := _edited_zone.get_node_or_null("Markers")
	if markers == null:
		return

	if StructureTileset.WALL_DECOR.has(kind):
		_paint_wall_decor(kind, world_pos)
		return

	var is_grid := BuildPlacement.is_grid_kind(kind)

	var snapped := world_pos
	if is_grid:
		snapped = BuildGrid.snap(world_pos)
		var cell := BuildGrid.to_cell(snapped)
		var occupying := BuildPlacement.grid_marker_at(markers, kind, cell)
		if occupying != null:
			# Same rule the in-game tool uses: a floor tile paints OVER a
			# different floor tile (that's what painting means), anything else
			# refuses an occupied cell, and repainting the identical tile is a
			# no-op so dragging across one cell can't stack markers on it.
			if BuildPlacement.is_redundant_placement(kind, occupying):
				return
			_do_remove_marker(markers, occupying, _edited_zone)
	else:
		# Free-placed kinds (decor/mob/resource/POI/building) still refuse to
		# stack two markers on top of each other, same spirit as the runtime
		# tool's MIN_MARKER_SPACING. Walks the whole subtree (not just direct
		# children of "Markers") so this still catches a marker grouped
		# inside a house, and _is_marker() keeps the grouping node itself
		# from counting as "too close" at its own origin. A "building_*" kind
		# (whole prefab house, much bigger than a barrel) gets a clearance
		# sized to its own sprite instead of the flat default — see
		# BuildingMarker.clearance_for() — checked both ways so a small prop
		# also can't land inside an already-placed building's footprint.
		var own_clearance := (BuildingMarker.clearance_for(kind.trim_prefix("building_"))
			if kind.begins_with("building_") else MIN_MARKER_SPACING)
		for child in ZoneBuilder._all_descendants(markers):
			# Same rule as the in-game tool: ground and structure cells don't
			# crowd a prop, only other free-placed markers do.
			if not BuildPlacement.blocks_free_placement(child):
				continue
			var other_clearance := MIN_MARKER_SPACING
			if child is BuildingMarker:
				other_clearance = BuildingMarker.clearance_for((child as BuildingMarker).building_id)
			if (child as Node2D).global_position.distance_to(world_pos) < maxf(own_clearance, other_clearance):
				return

	var marker := _make_marker(kind, _dock.wall_material, _dock.roof_material)
	if marker == null:
		return
	if is_grid:
		marker.set("grid_pos", BuildGrid.to_cell(snapped))
	else:
		marker.global_position = world_pos
		if kind.begins_with("building_"):
			var placement := BuildingMarker.placement_for(kind.trim_prefix("building_"), _dock.building_rotation)
			marker.rotation = placement["rotation"]
			(marker as BuildingMarker).facing_steps = placement["facing_steps"]

	var zone := _edited_zone
	var undo_redo := get_undo_redo()
	# MERGE_ALL: a drag fires this once per cell, and thirty separate undo
	# steps for one sweep is unusable. Consecutive actions with the same name
	# collapse into one, which is how the in-game tool behaves (one gesture =
	# one undo step). Different kinds keep separate names, so switching piece
	# mid-drag still breaks the merge where you'd expect.
	undo_redo.create_action("Place %s" % kind, UndoRedo.MERGE_ALL)
	undo_redo.add_do_method(self, "_do_add_marker", markers, marker, zone)
	undo_redo.add_undo_method(self, "_do_remove_marker", markers, marker, zone)
	undo_redo.add_do_reference(marker)
	undo_redo.commit_action()


func _paint_wall_decor(kind: String, world_pos: Vector2) -> void:
	var markers := _edited_zone.get_node_or_null("Markers")
	if markers == null:
		return
	var cell := BuildGrid.to_cell(BuildGrid.snap(world_pos))
	var marker := BuildPlacement.grid_marker_at(markers, "wall_n", cell) as StructureMarker
	if marker == null:
		return
	var previous: String = marker.wall_decor
	var next := "" if previous == kind else kind
	if next == previous:
		return
	var zone := _edited_zone
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Paint %s" % kind)
	undo_redo.add_do_method(self, "_do_set_wall_decor", marker, next, zone)
	undo_redo.add_undo_method(self, "_do_set_wall_decor", marker, previous, zone)
	undo_redo.commit_action()


func _remove_nearest(world_pos: Vector2, max_dist: float = 24.0) -> void:
	var markers := _edited_zone.get_node_or_null("Markers")
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
	# The marker's REAL parent, not always `markers` — it could be nested a
	# level or two down inside a grouped house, and undo needs to put it back
	# exactly where it came from, not flatten it back under "Markers".
	var parent := closest.get_parent()
	var zone := _edited_zone
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Remove marker", UndoRedo.MERGE_ALL)
	undo_redo.add_do_method(self, "_do_remove_marker", parent, closest, zone)
	undo_redo.add_undo_method(self, "_do_add_marker", parent, closest, zone)
	undo_redo.add_undo_reference(closest)
	undo_redo.commit_action()


## ------------------------------------------------------- the free brush

func _paint_layer(kind: String) -> PaintLayer:
	if _edited_zone == null or not _edited_zone.has_method("paint_layer_for"):
		return null
	return _edited_zone.call("paint_layer_for", kind)


func _begin_paint_stroke(kind: String) -> void:
	var layer := _paint_layer(kind)
	if layer != null:
		layer.begin_stroke()


func _paint(kind: String, world_pos: Vector2, erase: bool) -> void:
	if _edited_zone != null and _edited_zone.has_method("paint_at"):
		_edited_zone.call("paint_at", kind, world_pos, erase, float(_dock.brush_radius))


## Files the finished stroke with the EDITOR's undo stack, so Ctrl+Z inside
## Godot sees it and the scene is marked dirty — the same contract every other
## action here follows (see this file's class doc). The step carries the two
## versions of the stroke's dirty rect; nothing else in the mask is touched.
func _end_paint_stroke(kind: String) -> void:
	var layer := _paint_layer(kind)
	if layer == null:
		return
	var step: Dictionary = layer.end_stroke()
	if step.is_empty():
		return
	var rect: Rect2i = step["rect"]
	var before: Image = step["before"]
	var after: Image = layer.region(rect)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Pincel %s" % kind)
	undo_redo.add_do_method(layer, "restore", rect, after)
	undo_redo.add_undo_method(layer, "restore", rect, before)
	undo_redo.add_do_reference(after)
	undo_redo.add_undo_reference(before)
	undo_redo.commit_action(false) # already painted; don't redo it now


## ---------------------------------------------------- do/undo primitives
## Kept as separate methods (rather than lambdas) because
## EditorUndoRedoManager.add_do_method()/add_undo_method() need a real
## method name to call back into on Ctrl+Z/Ctrl+Y.

func _do_add_marker(markers: Node, marker: Node, zone: Node2D) -> void:
	print("[BuildModeEditor] _do_add_marker() entered")
	markers.add_child(marker)
	marker.owner = zone
	_rebuild(zone, marker)


func _do_remove_marker(markers: Node, marker: Node, zone: Node2D) -> void:
	if marker.get_parent() == markers:
		markers.remove_child(marker)
	_rebuild(zone, marker)


func _do_set_wall_decor(marker: StructureMarker, value: String, zone: Node2D) -> void:
	marker.wall_decor = value
	if zone.has_method("_rebuild_structures"):
		zone.call("_rebuild_structures")


func _rebuild(zone: Node2D, marker: Node) -> void:
	print("[BuildModeEditor] _rebuild() entered, marker is StructureMarker=", marker is StructureMarker,
		" is RoofMarker=", marker is RoofMarker, " is CollisionMarker=", marker is CollisionMarker)
	if (marker is StructureMarker or marker is RoofMarker) and zone.has_method("_rebuild_structures"):
		zone.call("_rebuild_structures")
		print("[BuildModeEditor] _rebuild_structures() called")
	elif marker is FloorTileMarker and zone.has_method("_rebuild_floor_tiles"):
		zone.call("_rebuild_floor_tiles")
		print("[BuildModeEditor] _rebuild_floor_tiles() called")
	elif marker is CollisionMarker:
		pass # no TileMapLayer/visual to rebuild — CollisionMarker's own
		# editor-only _draw() already shows it; the real StaticBody2D is
		# Play-only (see world_zone.gd's _rebuild_collision() doc).
	else:
		print("[BuildModeEditor] WARNING _rebuild: no matching rebuild method for marker class ", marker.get_class())


## ----------------------------------------------------------------- lookups

## Per-cell dedup goes through BuildPlacement.grid_marker_at(), which the
## in-game tool uses too. It searches at any nesting depth (via
## ZoneBuilder.collect_*) rather than a flat get_children() loop, so a piece
## inside a grouped house is still found, exactly as if it were flat.


## Every actual marker type this plugin places — used to filter
## ZoneBuilder._all_descendants() results down to real markers, excluding the
## plain Node2D (or instanced sub-scene root) grouping several of them
## together — e.g. building one house, then saving that group as its own
## scene to instance repeatedly elsewhere (Godot's equivalent of a prefab).
## Same reasoning and same list as world_zone.gd's own _is_marker().
func _is_marker(node: Node) -> bool:
	return BuildPlacement.is_marker(node)


## ----------------------------------------------------------------- factory
## Delegates to BuildPlacement, which world_zone.gd's _instantiate_marker()
## also uses. This used to be a hand-maintained copy of that factory and it
## drifted every time a palette id was added — see build_placement.gd.
func _make_marker(kind: String, wall_material: String, roof_material: String) -> Node2D:
	return BuildPlacement.make_marker(kind, wall_material, roof_material)


## ------------------------------------------------------------------ ghost
## The same cursor preview the in-game tool draws (scripts/world/
## build_ghost.gd), reproduced with the EditorPlugin overlay API. It has to
## be redrawn here rather than reused directly: build_ghost.gd is a Node2D
## living inside the running zone and reads the `Game` autoload for the
## selected kind, neither of which exists while editing a scene.
##
## Anchoring matches build_ghost.gd exactly, because a preview that sits
## somewhere other than where the piece lands is worse than none: grid kinds
## hang from the cell's bottom edge (StructureTileset anchors oversized tiles
## bottom-centred, and the layer itself is offset half a cell), everything
## else is bottom-centred on the cursor.

var _ghost_pos: Vector2 = Vector2.ZERO


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if _dock == null or not _dock.tool_active:
		return
	if _current_zone() == null:
		return
	var kind: String = _dock.selected_kind
	if kind == "":
		return

	var xform_now := get_editor_interface().get_editor_viewport_2d().global_canvas_transform
	# The free brush previews the circle it will actually paint. The editor
	# draws its OWN overlay (build_ghost.gd is a runtime node and never runs
	# here), so the round preview has to exist in both places or the editor
	# shows a square swatch of texture for a round brush.
	if PaintLayer.is_paint_id(kind):
		var centre := xform_now * _ghost_pos
		var r := float(_dock.brush_radius) * xform_now.get_scale().x
		overlay.draw_circle(centre, r, Color(0.95, 0.85, 0.45, 0.16))
		overlay.draw_arc(centre, r, 0.0, TAU, 48, Color(0.95, 0.85, 0.45, 0.9), 1.5)
		return

	var is_grid := BuildPlacement.is_grid_kind(kind)
	var world_pos := BuildGrid.snap(_ghost_pos) if is_grid else _ghost_pos

	var facing_steps := 0
	var draw_rotation := 0.0
	if not is_grid and kind.begins_with("building_"):
		var placement := BuildingMarker.placement_for(
			kind.trim_prefix("building_"), _dock.building_rotation)
		draw_rotation = placement["rotation"]
		facing_steps = placement["facing_steps"]

	var tex := BuildIcons.get_icon(kind, facing_steps)
	if tex == null:
		return

	var xform := get_editor_interface().get_editor_viewport_2d().global_canvas_transform
	var size := Vector2(tex.get_size())
	var half_cell := Vector2(StructureTileset.TILE_SIZE) * 0.5
	var origin := Vector2(-size.x * 0.5, -size.y)
	if is_grid:
		origin += Vector2(0, half_cell.y)

	# Drawn in the overlay's screen space, so the rect has to carry the
	# viewport's zoom — otherwise the preview stays a fixed pixel size while
	# the map under it scales, and stops matching what will be placed.
	var screen_pos := xform * (world_pos + origin)
	var scale := xform.get_scale()
	overlay.draw_texture_rect(
		tex, Rect2(screen_pos, size * scale), false, Color(0.55, 1.0, 0.55, 0.65))

	if is_grid:
		# The cell outline, so it's obvious which cell a click lands on.
		var cell_size := Vector2(StructureTileset.TILE_SIZE) * scale
		var cell_origin := xform * (world_pos - half_cell)
		overlay.draw_rect(Rect2(cell_origin, cell_size), Color(0.55, 1.0, 0.55, 0.5), false, 1.0)

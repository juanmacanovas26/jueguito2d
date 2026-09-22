@tool
class_name BuildingMarker
extends Marker2D
## Author-time placement for one whole prefab building — a single baked
## sprite (walls, roof, door, chimney, all pre-composed by PixelLab) dropped
## in one click, instead of assembling a house wall-by-wall with
## StructureMarker/RoofMarker. The "acelerar creación de ciudades" shortcut
## requested alongside the piece-by-piece ESTRUCTURA/TECHO tools — both
## coexist: this is for stamping a finished building fast, those are for
## anything custom this catalog doesn't cover.
##
## Free-placed like DecorMarker/POIMarker (not grid-snapped like a wall
## cell) — a building's footprint doesn't need to land on a grid line, and
## unlike StructureMarker/RoofMarker it paints nothing onto any
## TileMapLayer, so instancing/duplicating/dragging one around just works
## with Godot's ordinary node transform, none of the grid_pos-is-absolute
## caveat that makes StructureMarker-built houses non-relocatable (see
## docs/GDD.md).
##
## No collision yet, same v1 gap as StructureMarker walls — this is visual
## city-dressing, not a physical obstacle, until build mode grows real
## construction collision.
##
## Anchored bottom-center, same convention as every other world sprite
## (resource_node.gd's trees/rocks, DecorMarker's props, StructureTileset's
## pieces) — the building "stands" on the spot it was clicked, its door
## roughly at the marker's own position.

## _PATHS entry is either a String (one isotropic sprite — the FIXED_FRONT
## case, or a CARDINAL_ROTATE_KINDS building with no directional art yet, see
## has_directional_art()) or a Dictionary {"n":path,"e":..,"s":..,"w":..}: a
## real 4-direction set. "Rotating" a directional building swaps which of
## the 4 sprites is shown instead of applying a Transform2D rotation to one
## image — a flat top-down sprite spun 90° in 2D does not look like the same
## building actually viewed from its side (reported: the herrería's forge
## archway/roofline just tilted, it didn't turn into a side wall). "n" is
## always the front/default (the one with the door/forge visible) regardless
## of whatever compass label the art tool itself used.
const _PATHS := {
	"house_small_a": "res://assets/world/buildings/house_small_a.png",
	"house_small_b": "res://assets/world/buildings/house_small_b.png",
	"house_small_c": "res://assets/world/buildings/house_small_c.png",
	"house_small_d": "res://assets/world/buildings/house_small_d.png",
	"house_small_e": "res://assets/world/buildings/house_small_e.png",
	"house_small_f": "res://assets/world/buildings/house_small_f.png",
	"house_medium_common_a": "res://assets/world/buildings/house_medium_common_a.png",
	"house_medium_common_b": "res://assets/world/buildings/house_medium_common_b.png",
	"house_medium_common_c": "res://assets/world/buildings/house_medium_common_c.png",
	"house_medium_common_d": "res://assets/world/buildings/house_medium_common_d.png",
	"house_medium_common_e": "res://assets/world/buildings/house_medium_common_e.png",
	"house_medium_noble": "res://assets/world/buildings/house_medium_noble.png",
	"house_medium_mage": "res://assets/world/buildings/house_medium_mage.png",
	"house_medium_gothic": "res://assets/world/buildings/house_medium_gothic.png",
	"house_medium_cozy": "res://assets/world/buildings/house_medium_cozy.png",
	"house_large_common": "res://assets/world/buildings/house_large_common.png",
	"house_large_noble": "res://assets/world/buildings/house_large_noble.png",
	"house_large_mage": "res://assets/world/buildings/house_large_mage.png",
	"house_large_gothic": "res://assets/world/buildings/house_large_gothic.png",
	"house_large_cozy": "res://assets/world/buildings/house_large_cozy.png",
	"house_grand_common": "res://assets/world/buildings/house_grand_common.png",
	"house_grand_noble": "res://assets/world/buildings/house_grand_noble.png",
	"house_grand_mage": "res://assets/world/buildings/house_grand_mage.png",
	"house_grand_gothic": "res://assets/world/buildings/house_grand_gothic.png",
	"house_grand_cozy": "res://assets/world/buildings/house_grand_cozy.png",
	"house_palace_common": "res://assets/world/buildings/house_palace_common.png",
	"house_palace_noble": "res://assets/world/buildings/house_palace_noble.png",
	"house_palace_mage": "res://assets/world/buildings/house_palace_mage.png",
	"house_palace_gothic": "res://assets/world/buildings/house_palace_gothic.png",
	"house_palace_cozy": "res://assets/world/buildings/house_palace_cozy.png",
	"mansion": "res://assets/world/buildings/mansion.png",
	"bank": "res://assets/world/buildings/bank.png",
	"inn": "res://assets/world/buildings/inn.png",
	"temple": "res://assets/world/buildings/temple.png",
	"blacksmith": {
		"n": "res://assets/world/buildings/blacksmith_n.png",
		"e": "res://assets/world/buildings/blacksmith_e.png",
		"s": "res://assets/world/buildings/blacksmith_s.png",
		"w": "res://assets/world/buildings/blacksmith_w.png",
	},
	"general_goods": "res://assets/world/buildings/general_goods.png",
	"market_produce": "res://assets/world/buildings/market_produce.png",
	"market_textiles": "res://assets/world/buildings/market_textiles.png",
	"market_spices": "res://assets/world/buildings/market_spices.png",
	"dock": "res://assets/world/buildings/dock.png",
}

const _FACING_KEYS := ["n", "e", "s", "w"]

## Buildings whose art only reads correctly from one side (a single drawn
## facade — door, steps, columns — with no back/side view ever generated):
## these ALWAYS place facing front, ignoring whatever Game.build_rotation /
## the editor dock's rotation control currently holds. Houses/mansion are a
## request ("de frente sí o sí"); `bank` joins them for the same reason —
## its generated art is a formal columned facade, not a 4-sided building.
const FIXED_FRONT_KINDS: Array[String] = [
	"house_small_a", "house_small_b", "house_small_c", "house_small_d",
	"house_small_e", "house_small_f",
	"house_medium_common_a", "house_medium_common_b", "house_medium_common_c",
	"house_medium_common_d", "house_medium_common_e",
	"house_medium_noble", "house_medium_mage", "house_medium_gothic", "house_medium_cozy",
	"house_large_common", "house_large_noble", "house_large_mage",
	"house_large_gothic", "house_large_cozy",
	"house_grand_common", "house_grand_noble", "house_grand_mage",
	"house_grand_gothic", "house_grand_cozy",
	"house_palace_common", "house_palace_noble", "house_palace_mage",
	"house_palace_gothic", "house_palace_cozy",
	"mansion", "bank", "general_goods", "inn", "temple",
]

## Buildings placed against a directional constraint (a market stall facing
## a street, a forge archway, a dock's pier reaching toward water) — these
## rotate in the 4 cardinal directions instead of free 45° steps, and
## instead of being locked to 0 like FIXED_FRONT_KINDS. See placement_for().
## Not every member has directional art yet (see has_directional_art()) —
## one without it just rotates its single sprite the old way as a stand-in.
const CARDINAL_ROTATE_KINDS: Array[String] = [
	"market_produce", "market_textiles", "market_spices", "blacksmith", "dock",
]


## True when `id` has a real 4-sprite set (a Dictionary in _PATHS) rather
## than one sprite rotated in software.
static func has_directional_art(id: String) -> bool:
	return typeof(_PATHS.get(id)) == TYPE_DICTIONARY


## The texture path for `id` facing `facing_steps` (0=n/1=e/2=s/3=w, wrapped).
## For a plain isotropic entry, facing_steps is irrelevant and the one path
## is always returned.
static func texture_path(id: String, facing_steps: int = 0) -> String:
	var entry = _PATHS.get(id)
	if typeof(entry) == TYPE_DICTIONARY:
		var key: String = _FACING_KEYS[((facing_steps % 4) + 4) % 4]
		return str((entry as Dictionary).get(key, ""))
	return str(entry) if entry != null else ""


## What a placed building's Node2D.rotation AND facing_steps should be, given
## whatever rotation was dialed in (Game.build_rotation at runtime, or the
## editor dock's own building_rotation) — the single place world_zone.gd's
## _place_marker(), build_ghost.gd's preview, and plugin.gd's _place() all
## call, so the rule can't drift between them. The two outputs are mutually
## exclusive per building: a directional building never gets a Transform
## rotation (rotation always 0, the different sprite already IS the rotated
## view); a plain one never changes facing_steps (always 0, meaningless for
## a single-sprite entry). Plain decor/mob/resource/POI markers never call
## this at all.
static func placement_for(id: String, requested_rotation: float) -> Dictionary:
	if FIXED_FRONT_KINDS.has(id):
		return {"rotation": 0.0, "facing_steps": 0}
	if CARDINAL_ROTATE_KINDS.has(id):
		var steps := int(roundf(requested_rotation / (PI / 2.0)))
		steps = ((steps % 4) + 4) % 4
		if has_directional_art(id):
			return {"rotation": 0.0, "facing_steps": steps}
		return {"rotation": steps * (PI / 2.0), "facing_steps": 0}
	return {"rotation": requested_rotation, "facing_steps": 0}


## Palette id is "building_<kind>" (see world_zone.gd's _instantiate_marker());
## this is just "<kind>" — the key into _PATHS and BuildIcons' get_icon().
@export var building_id: String = "house_small_a":
	set(value):
		building_id = value
		_load_texture()
		queue_redraw()

## Which of the 4 sprites to show for a directional building (see
## has_directional_art()) — meaningless (always 0) for an isotropic one.
## Set via placement_for()'s result, not dialed by hand.
@export_range(0, 3, 1) var facing_steps: int = 0:
	set(value):
		facing_steps = ((value % 4) + 4) % 4
		_load_texture()
		queue_redraw()

var _tex: Texture2D


func _ready() -> void:
	# Explicit rather than "whatever tree order gives us": decor is meant to
	# sit ON TOP of buildings (see world_zone.gd's Z_* block), and that only
	# holds if buildings pin themselves to the marker baseline.
	z_index = WorldZone.Z_BUILDING
	_load_texture()
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	draw_texture(_tex, Vector2(-_tex.get_width() / 2.0, -_tex.get_height()))


func _load_texture() -> void:
	var path := BuildingMarker.texture_path(building_id, facing_steps)
	_tex = load(path) if path != "" and ResourceLoader.exists(path) else null


## Half the sprite's longer side (plus a small buffer) — used instead of the
## flat MIN_MARKER_SPACING every other free-placed marker gets, so two
## buildings stamped near each other don't just overlap into a pixel mush
## the way two barrels 20px apart harmlessly would. See world_zone.gd's
## is_placement_valid() / plugin.gd's _place(). Always measured off the
## front (facing 0) sprite, even for a directional building — the 4 views
## are similar enough in size that a per-facing clearance isn't worth the
## complexity. Falls back to a MIN_MARKER_SPACING-sized clearance when the
## art hasn't been generated yet (ResourceLoader.exists() false), so a
## missing PNG degrades to "placeable like any other prop" rather than
## silently refusing every click.
static func clearance_for(id: String) -> float:
	var path := texture_path(id, 0)
	if path == "" or not ResourceLoader.exists(path):
		return 20.0
	var tex: Texture2D = load(path)
	if tex == null:
		return 20.0
	return maxf(tex.get_width(), tex.get_height()) * 0.5 + 8.0

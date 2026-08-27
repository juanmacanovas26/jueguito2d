@tool
class_name POIMarker
extends Marker2D
## Author-time placement for a non-mob point of interest: a city NPC
## (vendor/bank/repair), a dungeon entrance, or a mini-boss spawn. Fase 3
## (city hub + first dungeon) is what actually consumes these; for now
## ZoneBuilder just collects them so world_zone.gd doesn't need new code
## every time a new POI kind is added.
##
## Draws itself both in the editor AND at runtime (unlike the other two
## marker types, which vanish once ZoneBuilder spawns their real entity) —
## a POI has no spawned entity to show it exists, so without this a placed
## POI would be completely invisible in Play mode.

enum Kind { VENDOR, BANK, REPAIR, DUNGEON_ENTRANCE, MINI_BOSS }

@export var kind: Kind = Kind.VENDOR
@export var display_name: String = ""
## Free-form payload for whatever consumes this POI kind (e.g. a
## dungeon_entrance's target scene path, a mini_boss's stat overrides). A
## Dictionary instead of new export fields per kind so adding a kind later
## doesn't require touching this script.
@export var data: Dictionary = {}


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var tex := BuildIcons.get_icon(kind_name())
	if tex == null:
		return
	var draw_size := Vector2.ONE * 32.0
	draw_texture_rect(tex, Rect2(-draw_size * 0.5, draw_size), false)


## The string BuildIcons/world_zone.gd's _instantiate_marker() use for this kind.
func kind_name() -> String:
	match kind:
		Kind.VENDOR:
			return "vendor"
		Kind.BANK:
			return "bank"
		Kind.REPAIR:
			return "repair"
		Kind.DUNGEON_ENTRANCE:
			return "dungeon_entrance"
		Kind.MINI_BOSS:
			return "mini_boss"
		_:
			return "vendor"

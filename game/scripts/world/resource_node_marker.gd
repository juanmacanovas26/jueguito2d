@tool
class_name ResourceNodeMarker
extends Marker2D
## Author-time placement for a gatherable (tree/rock/vein). Mirrors the
## fields resource_node.gd exposes; ZoneBuilder instances the real scene from
## these at zone _ready(). Kind only picks the sprite/behaviour category —
## drop_id/drop_min/drop_max/skill_gain/max_hp still need setting per node in
## the inspector, same as any other authored content.

enum Kind { TREE, ROCK, VEIN }

@export var kind: Kind = Kind.TREE
## Empty keeps resource_node.gd's own default ("Tree") for the kind.
@export var display_name: String = ""
@export var drop_id: String = "wood_log"
@export var drop_min: int = 1
@export var drop_max: int = 3
@export var skill_gain: int = 5
@export var max_hp: float = 40.0
## Immortal nodes (iron veins) never deplete and support auto-farm — see
## docs/GDD.md's "nodos inmortales" design note.
@export var immortal: bool = false

const _COLORS := {
	Kind.TREE: Color(0.35, 0.65, 0.3, 0.9),
	Kind.ROCK: Color(0.55, 0.55, 0.55, 0.9),
	Kind.VEIN: Color(0.85, 0.7, 0.2, 0.9),
}


func _ready() -> void:
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_circle(Vector2.ZERO, 8.0, _COLORS.get(kind, Color.WHITE))


## The string resource_node.gd's visual_type expects.
func visual_type_name() -> String:
	match kind:
		Kind.ROCK:
			return "rock"
		Kind.VEIN:
			return "vein"
		_:
			return "tree"

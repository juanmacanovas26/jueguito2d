@tool
class_name ResourceNodeMarker
extends Marker2D
## Author-time placement for a gatherable (tree/rock/vein). Mirrors the
## fields resource_node.gd exposes; ZoneBuilder instances the real scene from
## these at zone _ready(). Kind only picks the sprite/behaviour category —
## drop_id/drop_min/drop_max/skill_gain/max_hp still need setting per node in
## the inspector, same as any other authored content.

enum Kind { TREE, ROCK, VEIN }

@export var kind: Kind = Kind.TREE:
	set(value):
		kind = value
		if Engine.is_editor_hint():
			_load_texture()
			queue_redraw()
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
## Same paths ResourceNode.ART_PATHS uses at runtime — duplicated rather than
## referenced (ResourceNode extends StaticBody2D, a much heavier class to
## pull in just for a constant) so the editor preview shows the real art
## instead of a flat colored circle, matching what this marker actually
## turns into once ZoneBuilder spawns it.
const _ART_PATHS := {
	Kind.TREE: "res://assets/world/tree.png",
	Kind.ROCK: "res://assets/world/rock.png",
	Kind.VEIN: "res://assets/world/vein.png",
}
## Mirrors zone_builder.gd's _build_resource(): a vein renders bigger than
## resource_node.gd's own default — keep the editor preview honest about it
## instead of showing every kind at the same size.
const _VISUAL_RADIUS := {
	Kind.VEIN: 24.0,
}
const _DEFAULT_VISUAL_RADIUS := 26.0

var _tex: Texture2D


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	# Editor-only preview art: ZoneBuilder spawns a completely separate
	# ResourceNode scene from this marker's fields at real Play/runtime (see
	# class doc), so loading a Texture2D here that _draw() below never even
	# renders outside the editor would be pure waste on every marker, every
	# zone — worse on a dedicated server, which never renders anything at all.
	if Engine.is_editor_hint():
		_load_texture()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if _tex == null:
		draw_circle(Vector2.ZERO, 8.0, _COLORS.get(kind, Color.WHITE))
		return
	var native_w := _tex.get_width()
	var radius: float = _VISUAL_RADIUS.get(kind, _DEFAULT_VISUAL_RADIUS)
	var scale_factor := (radius * 2.0 / float(native_w)) if native_w > 0 else 1.0
	var size := Vector2(_tex.get_size()) * scale_factor
	draw_texture_rect(_tex, Rect2(-size / 2.0, size), false)


func _load_texture() -> void:
	var path := str(_ART_PATHS.get(kind, ""))
	_tex = load(path) if path != "" and ResourceLoader.exists(path) else null


## The string resource_node.gd's visual_type expects.
func visual_type_name() -> String:
	match kind:
		Kind.ROCK:
			return "rock"
		Kind.VEIN:
			return "vein"
		_:
			return "tree"

extends Node2D
## Always-on-top build-mode placement preview.
##
## world_zone.gd (the zone root) sets z_index = -5 so its floor/content sit
## behind entities — drawing the ghost directly on that node put it BEHIND
## the floor tilemap and everything else, since a Node2D's own _draw() output
## renders before its children within the same relative z layer. This is a
## separate CanvasItem with z_as_relative = false so it always renders on top
## regardless of what the zone root (or anything else) is doing.
##
## Also shows rotation (Q/E, see hud.gd) and placement validity — green when
## the click would succeed, red when it would be refused — the same signal
## Rust/Valheim/Fortnite-style building tools give before you commit.

func _ready() -> void:
	z_as_relative = false
	z_index = 100


func _process(_delta: float) -> void:
	if Game.build_mode:
		global_position = get_global_mouse_position()
	queue_redraw()


func _draw() -> void:
	if not Game.build_mode:
		return
	var tex := BuildIcons.get_icon(Game.build_selected_kind)
	if tex == null:
		return
	var valid := true
	var zone := get_parent()
	if zone and zone.has_method("is_placement_valid"):
		valid = zone.is_placement_valid(global_position)
	var tint := Color(0.55, 1.0, 0.55, 0.65) if valid else Color(1.0, 0.35, 0.35, 0.65)
	var draw_size := Vector2.ONE * 48.0
	draw_set_transform(Vector2.ZERO, Game.build_rotation, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-draw_size * 0.5, draw_size), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

class_name SkillTelegraph
extends Node2D
## The warning circle a ground AoE puts down before it lands.
##
## Purely presentation: it never decides who gets hit. SkillCaster resolves the
## hit on its own timer, so what you see and what lands agree, but the visual is
## not the authority (docs/ARQUITECTURA.md).
##
## The ring fills up over the delay, which is the player's cue for how long they
## have to walk out.

var _radius: float = 48.0
var _delay: float = 0.5
var _elapsed: float = 0.0
var _color: Color = Color(1.0, 0.45, 0.35, 0.35)


## Drops a telegraph into the world. Goes through Game.spawn per the contract.
static func spawn(pos: Vector2, radius: float, delay: float, color: Color) -> SkillTelegraph:
	var t := SkillTelegraph.new()
	t._radius = radius
	t._delay = maxf(delay, 0.01)
	t._color = color
	t.z_index = -3
	Game.spawn_node(t, pos, null)
	return t


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= _delay + 0.12:
		queue_free()


func _draw() -> void:
	var t := clampf(_elapsed / _delay, 0.0, 1.0)
	# Outline: where it will land.
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, Color(_color.r, _color.g, _color.b, 0.9), 2.0)
	# Fill: how much time is left.
	draw_circle(Vector2.ZERO, _radius * t, _color)

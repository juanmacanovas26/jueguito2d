class_name FloatingText
extends Label
## Floating combat number. Spawned at a world position, drifts up and fades.

const FloatTextScene := preload("res://scenes/ui/floating_text.tscn")

var _random_offset: float = 0.0


static func spawn(text: String, color: Color, world_pos: Vector2, size: int = 16) -> void:
	var scene := Game.get_world()
	if scene == null:
		return
	var ft = FloatTextScene.instantiate()
	scene.add_child(ft)
	ft.setup(text, color, world_pos, size)


func setup(text: String, color: Color, world_pos: Vector2, size: int = 16) -> void:
	self.text = text
	add_theme_font_size_override("font_size", size)
	modulate = color
	global_position = world_pos + Vector2(randf_range(-8, 8), randf_range(-4, 4))
	z_index = 50


func _ready() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 34.0, 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.65) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)

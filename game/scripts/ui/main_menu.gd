extends Control
## Entry point (project.godot run/main_scene). Only one overworld zone is
## live at a time, so both New Game and Continue point at it directly; once
## Fase 3 adds more zones, Continue should read the saved "zone" path instead.

## The MVP zone being built (town + surrounding field, 8000x6000). The older
## pradera.tscn is deliberately left in the project as a scratch/test zone —
## it still opens and plays, it just isn't what the menu boots into any more.
const ZONE_SCENE := "res://scenes/world/praderas_del_alba.tscn"

@onready var new_game_button: Button = $Center/VBox/NewGameButton
@onready var continue_button: Button = $Center/VBox/ContinueButton
@onready var quit_button: Button = $Center/VBox/QuitButton


func _ready() -> void:
	continue_button.disabled = not SaveSystem.has_save()
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_new_game_pressed() -> void:
	SaveSystem.pending_load = false
	get_tree().change_scene_to_file(ZONE_SCENE)


func _on_continue_pressed() -> void:
	SaveSystem.pending_load = true
	get_tree().change_scene_to_file(ZONE_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()

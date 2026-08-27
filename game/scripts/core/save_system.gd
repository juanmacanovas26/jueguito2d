extends Node
## Single seam for save/load, same spirit as the Game autoload's spawn
## contract (see docs/ARQUITECTURA.md) — all persistence goes through here so
## the format only has to change in one place.

## Not a const: the validate_save test suite points this at a throwaway file
## for the duration of its run, so it can exercise the real file I/O without
## ever touching (or clobbering) an actual player's save.
var save_path: String = "user://savegame.json"

## Set by the main menu's Continue button before changing scene; the zone
## reads it once in _ready() and clears it. Lives here (not on the zone)
## because it has to survive the scene change.
var pending_load: bool = false


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(save_path)


## Pulls save data from the local player and the current zone and writes it
## to disk. Returns false if there is nothing to save yet (no zone loaded).
func save_game() -> bool:
	var player := Game.get_local_player()
	if player == null or not player.has_method("get_save_data"):
		return false
	var data: Dictionary = player.get_save_data()
	var world := Game.get_world()
	data["zone"] = world.scene_file_path if world else ""
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true


## Returns the saved data, or {} if there is no save or it can't be parsed.
func load_data() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

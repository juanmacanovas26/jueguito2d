extends Node
## Recorre una casa en la zona real, con el input de verdad: planta
## house_small_a al lado del spawn de Praderas del Alba, camina hacia arriba
## hasta la puerta, saca captura adentro, camina hacia abajo hasta el felpudo
## y saca otra al volver. Lo que la suite (validate_housing) no puede juzgar:
## cómo se ve la sala, el fundido y que la cámara no cruce el mapa.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/housing_screenshot.tscn -- C:/carpeta/de/salida
##
## Sin argumento escribe en user://.

const ZONE_SCENE := "res://scenes/world/praderas_del_alba.tscn"

var _out_dir := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = str(args[0])
	var zone: Node = (load(ZONE_SCENE) as PackedScene).instantiate()
	add_child(zone)
	await _frames(20)

	var player := Game.get_local_player() as Node2D
	zone.call("_place_marker", "building_house_small_a", player.global_position + Vector2(0, -60))
	await _frames(5)
	var door := zone.find_child("Door", true, false) as BuildingDoor
	var travel := InteriorTravel.of(zone)
	player.global_position = door.exit_position() + Vector2(0, 30)
	(player.get_node("Camera2D") as Camera2D).reset_smoothing()
	await _shot("1_outside.png")

	var t := await _walk("move_up", func() -> bool: return travel.is_inside())
	print("in after %d frames" % t)
	while travel._busy:
		await get_tree().process_frame
	await _shot("2_inside.png")

	t = await _walk("move_down", func() -> bool: return not travel.is_inside())
	print("out after %d frames" % t)
	while travel._busy:
		await get_tree().process_frame
	await _shot("3_back_outside.png")
	get_tree().quit(0)


func _walk(action: String, until: Callable) -> int:
	Input.action_press(action)
	var t := 0
	while not until.call() and t < 600:
		await get_tree().physics_frame
		t += 1
	Input.action_release(action)
	return t


func _shot(name: String) -> void:
	await _frames(6)
	var path := _out_dir.path_join(name)
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

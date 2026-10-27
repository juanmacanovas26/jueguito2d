extends Node
## Suite de las casas: la puerta del edificio, entrar a la sala de interior y
## volver a salir frente a la puerta, con el mundo intacto detrás.
##
##   Godot_v4.7.1-stable_win64_console.exe --headless --path game \
##       res://tools/validate_housing.tscn
##
## Recorre el camino real: una zona en Play, el jugador de verdad, la casa
## colocada con _place_marker() y la puerta disparada por la física al pisarla.

const WORLD_ZONE_SCRIPT := preload("res://scripts/world/world_zone.gd")
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const HOUSE_ID := "house_small_a"
const HOUSE_SCENE := "res://scenes/world/buildings/house_small_a.tscn"
## Piso real de checks: si una sección aborta antes de tiempo, esto lo grita.
const MIN_CHECKS := 28

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	await _run()
	if _checks < MIN_CHECKS:
		_fail("only %d checks ran but at least %d are expected — a section aborted early" % [_checks, MIN_CHECKS])
	print("\n-- %d checks, %d failures --" % [_checks, _failures.size()])
	for f in _failures:
		print("   FAIL ", f)
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _ok(label: String) -> void:
	_checks += 1
	print("  ok   ", label)


func _fail(label: String) -> void:
	_checks += 1
	_failures.append(label)
	print("  FAIL ", label)


func _expect(cond: bool, label: String) -> void:
	if cond:
		_ok(label)
	else:
		_fail(label)


func _run() -> void:
	print("== validate_housing ==")
	_check_house_scene()
	_check_collider_editor_keeps_the_door()
	await _check_enter_and_exit()


## The door lives in the building's own scene and sits on the base of its
## collider, where someone walking up to the house actually touches it.
func _check_house_scene() -> void:
	print("\n[1] the house scene carries its door")
	var root: Node = (load(HOUSE_SCENE) as PackedScene).instantiate()
	var door := root.get_node_or_null("Door") as BuildingDoor
	_expect(door != null, "%s has a BuildingDoor named 'Door'" % HOUSE_ID)
	if door == null:
		root.free()
		return
	_expect(ResourceLoader.exists(door.interior_scene), "  its interior scene exists (%s)" % door.interior_scene)
	var room := (load(door.interior_scene) as PackedScene).instantiate()
	_expect(room is InteriorRoom, "  and is an InteriorRoom")
	room.free()

	var base := root.get_node("Base") as CollisionShape2D
	var base_rect := Rect2(base.position - (base.shape as RectangleShape2D).size / 2.0, (base.shape as RectangleShape2D).size)
	var door_shape := door.get_node("Shape") as CollisionShape2D
	var door_size: Vector2 = (door_shape.shape as RectangleShape2D).size
	var door_rect := Rect2(door.position + door_shape.position - door_size / 2.0, door_size)
	_expect(door_rect.position.y < base_rect.end.y and door_rect.end.y > base_rect.end.y,
		"  the door straddles the bottom of the building's collider (%s vs base bottom %s)" % [door_rect, base_rect.end.y])
	_expect(not door_rect.has_point(door.position + door.exit_offset),
		"  the exit spot is outside the door, so coming out does not walk you back in")
	root.free()


## Retouching a building's footprint in tools/collider_editor.tscn rebuilds its
## scene from scratch; the door has to ride along or it vanishes on save.
func _check_collider_editor_keeps_the_door() -> void:
	print("\n[2] collider_editor keeps what it does not edit")
	var editor_script: GDScript = load("res://tools/collider_editor.gd")
	var kept: Array = editor_script.call("_extra_children", HOUSE_SCENE)
	var names := kept.map(func(n: Node) -> String: return str(n.name))
	_expect(names == ["Door"], "  only the door is carried over, not the sprite or the colliders (%s)" % [names])
	_expect(kept.size() == 1 and kept[0].get_child_count() == 1, "  with its own shape inside it")
	for n in kept:
		n.free()


func _check_enter_and_exit() -> void:
	print("\n[3] walking in and out")
	var zone := Node2D.new()
	zone.set_script(WORLD_ZONE_SCRIPT)
	zone.set("world_size", Vector2(1600, 1200))
	# Every zone scene carries this layer (the editor plugin creates it).
	var floor_layer := TileMapLayer.new()
	floor_layer.name = "Floor"
	zone.add_child(floor_layer)
	var player: Node2D = load(PLAYER_SCENE).instantiate()
	zone.add_child(player)
	add_child(zone)
	await get_tree().physics_frame

	var travel := InteriorTravel.of(zone)
	_expect(travel != null, "the zone sets up an InteriorTravel when it starts")
	if travel == null:
		zone.queue_free()
		return
	travel.fade_time = 0.0

	zone.call("_place_marker", "building_" + HOUSE_ID, Vector2(0, 300))
	await get_tree().physics_frame
	var door := zone.find_child("Door", true, false) as BuildingDoor
	_expect(door != null, "placing %s puts its door in the world" % HOUSE_ID)
	if door == null:
		zone.queue_free()
		return

	# Build mode freezes the door: you are editing the map, not visiting it.
	Game.build_mode = true
	player.global_position = door.global_position + Vector2(0, 6)
	await _frames(10)
	_expect(not travel.is_inside(), "  touching the door in build mode does not go in")
	Game.build_mode = false
	player.global_position = door.global_position + Vector2(0, 120)
	await _frames(4)

	# Step onto the door.
	player.global_position = door.global_position + Vector2(0, 6)
	var went_in := await _wait_for(func() -> bool: return travel.is_inside() and not travel._busy)
	_expect(went_in, "stepping onto the door takes you inside")
	if not went_in:
		zone.queue_free()
		return
	var room := travel.current
	var room_rect := Rect2(room.to_global(room.floor_rect().position), room.floor_rect().size)
	_expect(room.get_parent() == zone, "  the room is loaded into the zone, the world stays loaded")
	_expect(room_rect.has_point(player.global_position), "  you stand on the room's floor (%s)" % player.global_position)
	_expect(player.global_position.y < -600.0, "  which is out past the map, not on top of it")
	_expect(Game.interior_return_position is Vector2 and Game.interior_return_position == door.exit_position(),
		"  the way back is remembered: in front of the door")
	var saved: Dictionary = player.call("get_save_data")
	_expect(Vector2(saved["position"]["x"], saved["position"]["y"]) == door.exit_position(),
		"  saving inside records the door, since the room is not saved")
	_expect(is_instance_valid(door) and door.is_inside_tree(), "  the house is still standing out in the world")
	var walls := room.get_node_or_null("Walls") as StaticBody2D
	_expect(walls != null and walls.get_child_count() == 4 and walls.collision_layer == 1,
		"  the room has solid walls on all four sides")

	# Inside, the room's own exit should not fire on arrival.
	await _frames(10)
	_expect(travel.is_inside(), "  arriving does not trip the exit mat")

	# Walk onto the mat.
	var mat := room.get_node("Exit") as Area2D
	player.global_position = mat.global_position
	var came_out := await _wait_for(func() -> bool: return not travel.is_inside() and not travel._busy)
	_expect(came_out, "stepping on the mat takes you back out")
	_expect(player.global_position == door.exit_position(), "  right in front of the door (%s)" % player.global_position)
	_expect(Game.interior_return_position == null, "  and the way-back marker is cleared")
	await _frames(2)
	_expect(not is_instance_valid(room), "  the room is freed")
	await _frames(10)
	_expect(not travel.is_inside(), "  coming out does not walk you straight back in")

	# Dying inside: the room closes and nothing is left behind.
	player.global_position = door.global_position + Vector2(0, 6)
	var back_in := await _wait_for(func() -> bool: return travel.is_inside() and not travel._busy)
	_expect(back_in, "you can go in again")
	var second := travel.current
	travel.abandon()
	await _frames(2)
	_expect(not travel.is_inside() and not is_instance_valid(second), "abandon() (respawn after dying) closes the room")
	_expect(Game.interior_return_position == null, "  and clears the way-back marker")

	# A door whose interior does not exist must not strand the player.
	player.global_position = door.global_position + Vector2(0, 160)
	await _frames(4)
	door.interior_scene = "res://scenes/world/interiors/does_not_exist.tscn"
	player.global_position = door.global_position + Vector2(0, 6)
	await _frames(12)
	_expect(not travel.is_inside() and not travel._busy, "a door to a missing interior does nothing instead of breaking")

	Game.build_mode = false
	zone.queue_free()
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_for(cond: Callable, frames := 120) -> bool:
	for i in frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()

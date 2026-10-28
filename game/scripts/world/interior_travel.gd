class_name InteriorTravel
extends Node
## Entrar y salir de los edificios. Vive como hijo de la zona ("InteriorTravel",
## lo agrega world_zone.gd al arrancar el juego).
##
## La sala se instancia al entrar y se libera al salir, y el mundo NO se
## descarga mientras tanto: la sala se ubica en un espacio propio, lejos del
## mapa, y el jugador se teletransporta. Así volver es instantáneo, el mundo
## conserva su estado (mobs, loot en el piso) y sigue vivo detrás, que es como
## se va a comportar con un servidor. Con netcode, esto pasa a ser una
## instancia de verdad; la puerta y la sala no cambian.
##
## Mientras el jugador está adentro, Game.interior_return_position guarda dónde
## está la puerta de afuera, para que guardar la partida adentro no deje al
## jugador flotando en el vacío al cargar.

signal entered(room: InteriorRoom)
signal exited

## Las salas van debajo del mapa, a esta distancia de su borde.
const ORIGIN_MARGIN := 4096.0
const FADE_TIME := 0.18

## Seconds per half of the fade. The test suite sets it to 0.
var fade_time := FADE_TIME
var current: InteriorRoom = null
var _return_position := Vector2.ZERO
var _busy := false
var _fade: ColorRect


static func of(zone: Node) -> InteriorTravel:
	if zone == null:
		return null
	return zone.get_node_or_null("InteriorTravel") as InteriorTravel


func is_inside() -> bool:
	return current != null


func enter(door: BuildingDoor) -> void:
	if _busy or current != null:
		return
	var scene := load(door.interior_scene) as PackedScene if ResourceLoader.exists(door.interior_scene) else null
	if scene == null:
		Game.toast("Esta puerta no lleva a ningún lado todavía")
		return
	var room := scene.instantiate() as InteriorRoom
	if room == null:
		push_warning("[InteriorTravel] %s is not an InteriorRoom" % door.interior_scene)
		return
	_busy = true
	_return_position = door.exit_position()
	# El fundido también saca el cambio de este frame del callback de física
	# de la puerta, donde no se pueden agregar cuerpos.
	await _fade_to(1.0)
	room.position = _origin()
	get_parent().add_child(room)
	room.exit_requested.connect(exit)
	current = room
	Game.interior_return_position = _return_position
	_move_player(room.spawn_position())
	await _fade_to(0.0)
	_busy = false
	entered.emit(room)


func exit() -> void:
	if _busy or current == null:
		return
	_busy = true
	await _fade_to(1.0)
	_move_player(_return_position)
	_close()
	await _fade_to(0.0)
	_busy = false
	exited.emit()


## Cierra la sala sin mover a nadie: para cuando el jugador sale por otro lado
## (morir y reaparecer en el mundo).
func abandon() -> void:
	if current != null:
		_close()
		exited.emit()


func _close() -> void:
	current.queue_free()
	current = null
	Game.interior_return_position = null


func _origin() -> Vector2:
	var zone := get_parent()
	if zone != null and zone.has_method("world_rect"):
		# Arriba del mapa, a una altura de mapa del borde: lejos de todo lo que
		# hay en el mundo aunque el mapa haya crecido para un costado.
		var rect: Rect2 = zone.call("world_rect")
		return Vector2(rect.get_center().x, rect.position.y - rect.size.y * 0.5 - ORIGIN_MARGIN)
	var size: Vector2 = zone.get("world_size") if zone != null else Vector2.ZERO
	return Vector2(0, -(size.y + ORIGIN_MARGIN))


func _move_player(pos: Vector2) -> void:
	var player := Game.get_local_player() as Node2D
	if player == null:
		return
	player.global_position = pos
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	# Sin esto la cámara cruzaría el mapa entero suavizando hasta la sala.
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.reset_smoothing()


func _fade_to(alpha: float) -> void:
	if _fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color(0, 0, 0, 0)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(_fade)
	if fade_time <= 0.0:
		_fade.color.a = alpha
		await get_tree().physics_frame
		return
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, fade_time)
	await tween.finished

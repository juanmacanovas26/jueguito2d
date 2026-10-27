class_name InteriorRoom
extends Node2D
## Una sala de interior: lo que se carga al cruzar la puerta de un edificio
## (BuildingDoor -> InteriorTravel). Por ahora un placeholder que se arma solo
## a partir de su tamaño: piso de madera, pared del fondo vista de frente
## (como un interior de Stardew), paredes laterales, colisión en el borde y un
## felpudo abajo al centro que es la salida.
##
## El origen es la esquina de arriba a la izquierda del piso; la pared del
## fondo se dibuja por encima de él.

signal exit_requested

## Piso caminable, en celdas de BuildGrid.
@export var size_cells: Vector2i = Vector2i(9, 6)

const TILE := BuildGrid.TILE_SIZE
## La pared del fondo, en celdas: se ve de frente, así que ocupa alto.
const BACK_WALL_CELLS := 2
## Grosor de las paredes laterales y de abajo, que se ven de canto.
const SIDE_WALL_PX := 12
const FLOOR_TEXTURE := "res://assets/world/roads/madera_12.png"
const WALL_COLOR := Color(0.86, 0.80, 0.69)
const WALL_SHADE := Color(0.70, 0.62, 0.50)
const TRIM_COLOR := Color(0.42, 0.29, 0.19)
const EDGE_COLOR := Color(0.25, 0.17, 0.12)
const MAT_COLOR := Color(0.62, 0.22, 0.20)
const MAT_SIZE := Vector2(48, 20)
const PLAYER_LAYER := 2

var _floor_tex: Texture2D


func _ready() -> void:
	if ResourceLoader.exists(FLOOR_TEXTURE):
		_floor_tex = load(FLOOR_TEXTURE)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_build_walls()
	_build_exit()
	queue_redraw()


func floor_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size_cells * TILE))


## Donde aparece quien entra: arriba del felpudo, sin tocarlo.
func spawn_position() -> Vector2:
	return to_global(_mat_center() + Vector2(0, -44))


func _mat_center() -> Vector2:
	var f := floor_rect()
	return Vector2(f.size.x / 2.0, f.size.y - MAT_SIZE.y / 2.0 - 2)


func _build_walls() -> void:
	var f := floor_rect()
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	# Arriba la colisión es el pie de la pared del fondo; el resto, el borde.
	var back := Rect2(-SIDE_WALL_PX, -BACK_WALL_CELLS * TILE, f.size.x + SIDE_WALL_PX * 2, BACK_WALL_CELLS * TILE)
	_add_box(body, back)
	_add_box(body, Rect2(-SIDE_WALL_PX * 2, 0, SIDE_WALL_PX * 2, f.size.y))
	_add_box(body, Rect2(f.size.x, 0, SIDE_WALL_PX * 2, f.size.y))
	_add_box(body, Rect2(-SIDE_WALL_PX, f.size.y, f.size.x + SIDE_WALL_PX * 2, SIDE_WALL_PX * 2))


func _add_box(body: StaticBody2D, rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)


func _build_exit() -> void:
	var area := Area2D.new()
	area.name = "Exit"
	area.collision_layer = 0
	area.collision_mask = PLAYER_LAYER
	area.monitorable = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = MAT_SIZE
	shape.shape = box
	area.add_child(shape)
	area.position = _mat_center()
	add_child(area)
	area.body_entered.connect(func(body: Node) -> void:
		if body == Game.get_local_player():
			exit_requested.emit())


func _draw() -> void:
	var f := floor_rect()
	var back := Rect2(0, -BACK_WALL_CELLS * TILE, f.size.x, BACK_WALL_CELLS * TILE)
	# Negro alrededor, como afuera de una sala de Stardew: la sala flota sola
	# en su espacio y lo que rodea no es nada.
	draw_rect(f.grow(4096), Color.BLACK)
	# Piso.
	if _floor_tex != null:
		draw_texture_rect(_floor_tex, f, true)
	else:
		draw_rect(f, Color(0.55, 0.38, 0.24))
	# Pared del fondo, de frente, con zócalo y una sombra sobre el piso.
	draw_rect(back, WALL_COLOR)
	draw_rect(Rect2(back.position, Vector2(back.size.x, 6)), WALL_SHADE)
	draw_rect(Rect2(0, -10, f.size.x, 10), TRIM_COLOR)
	draw_rect(Rect2(0, 0, f.size.x, 4), Color(0, 0, 0, 0.18))
	# Paredes laterales y de abajo, de canto.
	var outer := Rect2(-SIDE_WALL_PX, back.position.y, f.size.x + SIDE_WALL_PX * 2, f.size.y + back.size.y + SIDE_WALL_PX)
	draw_rect(Rect2(outer.position, Vector2(SIDE_WALL_PX, outer.size.y)), TRIM_COLOR)
	draw_rect(Rect2(f.size.x, outer.position.y, SIDE_WALL_PX, outer.size.y), TRIM_COLOR)
	draw_rect(Rect2(-SIDE_WALL_PX, f.size.y, outer.size.x, SIDE_WALL_PX), TRIM_COLOR)
	draw_rect(outer, EDGE_COLOR, false, 2.0)
	# El felpudo de la salida.
	var mat := Rect2(_mat_center() - MAT_SIZE / 2.0, MAT_SIZE)
	draw_rect(mat, MAT_COLOR)
	draw_rect(mat.grow(-3), MAT_COLOR.lightened(0.15), false, 1.0)

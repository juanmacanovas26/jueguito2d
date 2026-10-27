class_name BuildingDoor
extends Area2D
## La puerta de un edificio: un Area2D dentro de su escena
## (`scenes/world/buildings/<id>.tscn`), puesta sobre la puerta del dibujo.
## Cuando el jugador la toca, la zona lo lleva al interior (InteriorTravel), y
## al salir lo deja en `exit_position()`, frente a esta misma puerta.
##
## Se entra caminando contra la puerta, como en Stardew: el área se apoya en
## el borde de abajo del collider del edificio, así que la toca quien camina
## hacia ella, no quien pasa por al lado.

## La sala que se carga al entrar.
@export_file("*.tscn") var interior_scene: String = "res://scenes/world/interiors/interior_small.tscn"
## Dónde aparece el jugador al salir, relativo a la puerta. Fuera del área,
## para que volver a salir no lo meta de nuevo en el mismo cuadro.
@export var exit_offset: Vector2 = Vector2(0, 34)

## La capa del jugador (scenes/player/player.tscn). Nada más dispara la puerta.
const PLAYER_LAYER := 2


func _ready() -> void:
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	monitorable = false
	body_entered.connect(_on_body_entered)


func exit_position() -> Vector2:
	return global_position + exit_offset


func _on_body_entered(body: Node) -> void:
	if body != Game.get_local_player() or Game.build_mode:
		return
	var travel := InteriorTravel.of(Game.get_world())
	if travel != null:
		travel.enter(self)

@tool
class_name FenceMarker
extends Marker2D
## Una celda de vallado — la herramienta "VALLADO (auto)" del build mode.
##
## Misma forma que FloorTileMarker/StructureMarker: lo que se guarda es la
## celda y el estilo, nada de arte. El dibujo lo pone world_zone.gd en la
## TileMapLayer "Vallas" resolviendo el vecindario (ver FenceAutotiler), así
## que doscientas celdas de valla cuestan una capa y no doscientos
## CanvasItems — y mover una celda recalcula a sus vecinas sin que este nodo
## tenga que enterarse.
##
## grid_pos es la fuente de verdad y la posición se deriva de ella, por lo
## mismo que en los otros markers de grilla: guardar y recargar nunca tiene
## que preocuparse de que la posición y la celda discrepen por un redondeo.

@export var grid_pos: Vector2i = Vector2i.ZERO:
	set(value):
		grid_pos = value
		position = BuildGrid.cell_to_world(grid_pos)

## Qué atlas usa esta celda (ver FenceAutotiler.styles()). Dos estilos
## distintos no se conectan entre sí.
@export var style: String = "wood":
	set(value):
		style = value
		queue_redraw()


func _ready() -> void:
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	queue_redraw()


## Gizmo solo de editor, igual que el resto de los markers de grilla: en el
## juego la celda ya se ve como la valla pintada en la capa.
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(Vector2(-14, -14), Vector2(28, 28)), Color(0.72, 0.45, 0.2, 0.9), false, 2.0)

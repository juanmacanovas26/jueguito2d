extends Control
## Herramienta para ponerle colliders a los modelos — hoy edificios.
##
##     Godot -> abrir tools/collider_editor.tscn -> F6
##
## Elegís un edificio de la lista, dibujás los rectángulos de su planta sobre
## el sprite, y "Guardar" escribe scenes/world/buildings/<id>.tscn: raíz
## StaticBody2D, el Sprite2D anclado abajo-al-centro y un CollisionShape2D por
## rectángulo. Desde ese momento el BuildingMarker instancia ESA escena en vez
## de dibujar el PNG suelto, así que cada casa colocada en el mundo —las ya
## puestas también— entra con sus colliders (ver building_marker.gd).
##
## Por qué una herramienta y no medir los píxeles del sprite: el alero se
## dibuja hacia arriba y no ocupa suelo, y ningún criterio automático sabe
## dónde termina la pared y empieza el techo en un palacio con torres. La
## medición existe igual, pero como BOTÓN ("Sugerir planta") — un punto de
## partida razonable que después se corrige a ojo, que es lo único que de
## verdad acierta.
##
## Guarda directo sobre res://, así que solo funciona corriendo desde el
## editor. Es una herramienta de autor, no algo que se exporte con el juego.

const ART_DIR := BuildingMarker.ART_DIR
const SCENE_DIR := BuildingMarker.SCENE_DIR

## Lado del cuadradito que se agarra para redimensionar, en píxeles de
## PANTALLA — constante al zoom que sea, porque es del mouse, no del mundo.
const HANDLE_PX := 9.0
const MIN_RECT := 4.0

const COL_BG := Color(0.11, 0.12, 0.15)
const COL_GRID := Color(1, 1, 1, 0.05)
const COL_GROUND := Color(0.4, 0.9, 1.0, 0.5)
const COL_RECT := Color(0.3, 1.0, 0.45, 0.22)
const COL_RECT_LINE := Color(0.3, 1.0, 0.45, 0.9)
const COL_SEL := Color(1.0, 0.85, 0.2, 0.28)
const COL_SEL_LINE := Color(1.0, 0.85, 0.2, 1.0)

var _ids: Array[String] = []
var _id: String = ""
var _tex: Texture2D
## Los rects de la planta, en coordenadas de MUNDO: (0,0) es el pie del
## edificio (el ancla del marker), Y negativa hacia arriba. Es exactamente lo
## que termina guardado en la escena, sin conversiones de por medio.
var _rects: Array[Rect2] = []
var _selected: int = -1
var _undo: Array = []

var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _snap: int = 2

enum Drag { NONE, NEW, MOVE, RESIZE, PAN }
var _drag: int = Drag.NONE
var _drag_from: Vector2
var _drag_rect_start: Rect2
var _resize_corner: int = 0

var _canvas: Control
var _list: ItemList
var _status: Label
var _info: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_scan_ids()
	# Un frame antes de elegir el primero: _fit_view() necesita el tamaño real
	# del canvas, y recién después del primer layout deja de ser (0, 0).
	await get_tree().process_frame
	if not _ids.is_empty():
		_list.select(0)
		_select_id(_ids[0])


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var split := HBoxContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.add_theme_constant_override("separation", 0)
	add_child(split)

	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(250, 0)
	split.add_child(side)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	side.add_child(col)

	var title := Label.new()
	title.text = "Colliders de edificios"
	col.add_child(title)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(i: int) -> void: _select_id(_ids[i]))
	col.add_child(_list)

	col.add_child(_button("Sugerir planta", _suggest))
	col.add_child(_button("Borrar seleccionado", _delete_selected))
	col.add_child(_button("Borrar todos", func() -> void:
		_push_undo()
		_rects.clear()
		_selected = -1
		_redraw()))
	col.add_child(_snap_row())
	col.add_child(HSeparator.new())
	col.add_child(_button("Guardar escena", _save))
	col.add_child(_button("Recargar desde disco", func() -> void: _select_id(_id)))

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_info)

	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	help.text = "Arrastrar en vacío: rect nuevo. Arrastrar adentro: mover. Esquinas: redimensionar. Click derecho: borrar. Rueda: zoom. Botón del medio: pan. Ctrl+Z: deshacer."
	col.add_child(help)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_status)

	_canvas = Control.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_on_canvas_input)
	split.add_child(_canvas)


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	return b


func _snap_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Snap:"
	row.add_child(label)
	var opt := OptionButton.new()
	var values := [1, 2, 4, 8, 16, 32]
	for v in values:
		opt.add_item("%dpx" % v)
	opt.selected = values.find(_snap)
	opt.item_selected.connect(func(i: int) -> void: _snap = values[i])
	row.add_child(opt)
	return row


# ---------------------------------------------------------------- datos

## Un edificio por PNG, no por entrada del catálogo: las vistas direccionales
## (blacksmith_n/_e/_s/_w) son cuatro plantas distintas y cada una necesita su
## escena, que es justo como BuildingMarker.scene_path() las busca.
func _scan_ids() -> void:
	_ids.clear()
	_list.clear()
	var dir := DirAccess.open(ART_DIR)
	if dir == null:
		_say("No se pudo abrir %s" % ART_DIR)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".png"):
			_ids.append(file.get_basename())
		file = dir.get_next()
	dir.list_dir_end()
	_ids.sort()
	for id in _ids:
		# El tilde marca lo que ya tiene escena: en una lista de 45, saber qué
		# falta es la mitad del trabajo.
		var done := ResourceLoader.exists(SCENE_DIR + id + ".tscn")
		_list.add_item(("✓ " if done else "   ") + id)


func _select_id(id: String) -> void:
	_id = id
	_rects.clear()
	_selected = -1
	_undo.clear()
	var tex_path := ART_DIR + id + ".png"
	_tex = load(tex_path) if ResourceLoader.exists(tex_path) else null

	var scene_path := SCENE_DIR + id + ".tscn"
	if ResourceLoader.exists(scene_path):
		_load_rects_from(scene_path)
		_say("%s — %d rect(s) desde la escena existente." % [id, _rects.size()])
	else:
		_say("%s — sin escena todavía. Dibujá la planta y guardá." % id)

	_fit_view()
	_redraw()


## Lee los CollisionShape2D rectangulares de una escena ya guardada para poder
## seguir editándola. Un shape que no sea rectángulo (un polígono dibujado a
## mano en Godot) se avisa y se deja intacto en disco: esta herramienta no lo
## sabe editar, pero tampoco tiene por qué romperlo.
func _load_rects_from(path: String) -> void:
	var packed: Resource = load(path)
	if not (packed is PackedScene):
		return
	var root: Node = (packed as PackedScene).instantiate()
	var skipped := 0
	for child in root.get_children():
		if child is CollisionShape2D:
			var shape := (child as CollisionShape2D).shape
			if shape is RectangleShape2D:
				var size: Vector2 = (shape as RectangleShape2D).size
				_rects.append(Rect2((child as CollisionShape2D).position - size * 0.5, size))
			else:
				skipped += 1
	root.free()
	if skipped > 0:
		_say("Ojo: %d shape(s) no rectangulares — guardar los reemplaza." % skipped)


# ---------------------------------------------------------------- medición

## El punto de partida automático: la caja de lo opaco por debajo del alero.
## Mismo criterio que explica el encabezado — el ancho opaco de cada fila crece
## mientras baja el techo, toca un máximo en el borde del alero y cae cuando
## empieza la pared, que es más angosta. Se toma lo que hay debajo de esa fila.
func _suggest() -> void:
	if _tex == null:
		return
	var image := _tex.get_image()
	var w := image.get_width()
	var h := image.get_height()

	var first := {}
	var last := {}
	for y in h:
		for x in w:
			if image.get_pixel(x, y).a >= 0.03:
				if not first.has(y):
					first[y] = x
				last[y] = x
	if first.is_empty():
		_say("El sprite está vacío.")
		return

	var top: int = first.keys().min()
	var bottom: int = first.keys().max()
	var widest := 0
	for y in first:
		widest = maxi(widest, int(last[y]) - int(first[y]))
	var eave := top
	for y in first:
		if int(last[y]) - int(first[y]) == widest:
			eave = maxi(eave, y)

	# Debajo del alero, no incluyéndolo: la fila más ancha ES el borde del
	# techo, y meterla adentro devuelve el ancho del techo en vez del de la
	# pared.
	var band_top: int = mini(eave + 1, bottom)
	# Piso de la banda: un sprite sin caída de ancho (un muelle plano) daría
	# una planta de un píxel de alto.
	band_top = mini(band_top, bottom - int(round((bottom - top + 1) * 0.22)) + 1)
	band_top = maxi(band_top, top)

	var x0 := w
	var x1 := 0
	for y in first:
		if y >= band_top:
			x0 = mini(x0, int(first[y]))
			x1 = maxi(x1, int(last[y]))

	_push_undo()
	_rects = [Rect2(x0 - w / 2.0, band_top - h, x1 - x0 + 1, bottom - band_top + 1)]
	_selected = 0
	_say("Planta sugerida: %dx%d. Corregila a ojo." % [_rects[0].size.x, _rects[0].size.y])
	_redraw()


# ---------------------------------------------------------------- guardado

func _save() -> void:
	if _id == "" or _tex == null:
		return
	if _rects.is_empty():
		_say("Sin rectángulos: un edificio sin collider es el sprite vacío de antes.")
		return

	var root := StaticBody2D.new()
	root.name = _node_name(_id)
	# Capa 1 = lo sólido del mundo, igual que WorldBounds y CollisionMarker en
	# world_zone.gd. Mask 0: una casa no detecta, es detectada.
	root.collision_layer = 1
	root.collision_mask = 0

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = _tex
	# Ancla abajo-al-centro, la convención de todo sprite de mundo del
	# proyecto: el origen de la escena queda al pie del edificio.
	sprite.offset = Vector2(0, -_tex.get_height() / 2.0)
	root.add_child(sprite)
	sprite.owner = root

	for i in _rects.size():
		var shape_node := CollisionShape2D.new()
		shape_node.name = "Base" if i == 0 else "Base%d" % (i + 1)
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = _rects[i].size
		shape_node.shape = rect_shape
		shape_node.position = _rects[i].get_center()
		root.add_child(shape_node)
		shape_node.owner = root

	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		root.free()
		_say("No se pudo empaquetar la escena.")
		return

	if not DirAccess.dir_exists_absolute(SCENE_DIR):
		DirAccess.make_dir_recursive_absolute(SCENE_DIR)
	var path := SCENE_DIR + _id + ".tscn"
	var err := ResourceSaver.save(packed, path)
	root.free()
	if err != OK:
		_say("Error guardando %s (código %d)." % [path, err])
		return

	_say("Guardado %s — %d collider(s)." % [path, _rects.size()])
	var keep := _list.get_selected_items()
	_scan_ids()
	if not keep.is_empty():
		_list.select(keep[0])


func _node_name(id: String) -> String:
	var out := ""
	for part in id.split("_"):
		out += String(part).capitalize()
	return out


# ---------------------------------------------------------------- input

func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var world := _to_world(mb.position)
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.1)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = Drag.PAN if mb.pressed else Drag.NONE
			_drag_from = mb.position
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var hit := _rect_at(world)
			if hit >= 0:
				_push_undo()
				_rects.remove_at(hit)
				_selected = -1
				_redraw()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_left_drag(mb.position, world)
			else:
				_end_drag()
	elif event is InputEventMouseMotion and _drag != Drag.NONE:
		_update_drag((event as InputEventMouseMotion).position)


func _begin_left_drag(screen: Vector2, world: Vector2) -> void:
	_drag_from = world
	var corner := _handle_at(screen)
	if corner >= 0:
		_push_undo()
		_drag = Drag.RESIZE
		_resize_corner = corner
		_drag_rect_start = _rects[_selected]
		return
	var hit := _rect_at(world)
	if hit >= 0:
		_push_undo()
		_selected = hit
		_drag = Drag.MOVE
		_drag_rect_start = _rects[hit]
		_redraw()
		return
	_push_undo()
	_rects.append(Rect2(_snapped(world), Vector2.ZERO))
	_selected = _rects.size() - 1
	_drag = Drag.NEW


func _update_drag(screen: Vector2) -> void:
	if _drag == Drag.PAN:
		_pan += screen - _drag_from
		_drag_from = screen
		_redraw()
		return
	if _selected < 0:
		return
	var world := _snapped(_to_world(screen))
	match _drag:
		Drag.NEW:
			var from := _snapped(_drag_from)
			_rects[_selected] = Rect2(
				Vector2(minf(from.x, world.x), minf(from.y, world.y)),
				(world - from).abs())
		Drag.MOVE:
			_rects[_selected] = Rect2(
				_snapped(_drag_rect_start.position + (world - _snapped(_drag_from))),
				_drag_rect_start.size)
		Drag.RESIZE:
			_rects[_selected] = _resized(_drag_rect_start, _resize_corner, world)
	_redraw()


func _end_drag() -> void:
	if _drag == Drag.NEW and _selected >= 0:
		# Un click suelto no deja un rect de 0x0 invisible tirado en la lista.
		if _rects[_selected].size.x < MIN_RECT or _rects[_selected].size.y < MIN_RECT:
			_rects.remove_at(_selected)
			_selected = -1
			_undo.pop_back()
	_drag = Drag.NONE
	_redraw()


## El rect resultante de arrastrar `corner` (0=NO,1=NE,2=SE,3=SO) hasta
## `world`, normalizado para que cruzar la esquina opuesta no deje tamaño
## negativo.
func _resized(base: Rect2, corner: int, world: Vector2) -> Rect2:
	var x0 := base.position.x
	var y0 := base.position.y
	var x1 := base.position.x + base.size.x
	var y1 := base.position.y + base.size.y
	match corner:
		0:
			x0 = world.x
			y0 = world.y
		1:
			x1 = world.x
			y0 = world.y
		2:
			x1 = world.x
			y1 = world.y
		3:
			x0 = world.x
			y1 = world.y
	return Rect2(Vector2(minf(x0, x1), minf(y0, y1)), Vector2(absf(x1 - x0), absf(y1 - y0)))


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_Z and key.ctrl_pressed:
		_undo_last()
	elif key.keycode == KEY_DELETE:
		_delete_selected()


func _delete_selected() -> void:
	if _selected < 0 or _selected >= _rects.size():
		return
	_push_undo()
	_rects.remove_at(_selected)
	_selected = -1
	_redraw()


func _push_undo() -> void:
	_undo.append(_rects.duplicate())
	if _undo.size() > 64:
		_undo.pop_front()


func _undo_last() -> void:
	if _undo.is_empty():
		return
	_rects.assign(_undo.pop_back())
	_selected = -1
	_redraw()


# ---------------------------------------------------------------- vista

func _to_world(screen: Vector2) -> Vector2:
	return (screen - _origin()) / _zoom


func _to_screen(world: Vector2) -> Vector2:
	return world * _zoom + _origin()


## Dónde cae el (0,0) del mundo —el pie del edificio— en la pantalla.
func _origin() -> Vector2:
	return Vector2(_canvas.size.x * 0.5, _canvas.size.y * 0.72) + _pan


func _zoom_at(screen: Vector2, factor: float) -> void:
	var before := _to_world(screen)
	_zoom = clampf(_zoom * factor, 0.15, 8.0)
	_pan += screen - _to_screen(before)
	_redraw()


func _fit_view() -> void:
	_pan = Vector2.ZERO
	_zoom = 1.0
	if _tex == null or _canvas == null:
		return
	var margin := 80.0
	var fit_x := (_canvas.size.x - margin) / maxf(_tex.get_width(), 1.0)
	var fit_y := (_canvas.size.y - margin) / maxf(_tex.get_height(), 1.0)
	_zoom = clampf(minf(fit_x, fit_y), 0.15, 4.0)


func _snapped(world: Vector2) -> Vector2:
	if _snap <= 1:
		return world.round()
	return Vector2(
		roundf(world.x / _snap) * _snap,
		roundf(world.y / _snap) * _snap)


func _rect_at(world: Vector2) -> int:
	# De atrás para adelante: si dos se superponen, se agarra el de arriba,
	# que es el que se está viendo.
	for i in range(_rects.size() - 1, -1, -1):
		if _rects[i].has_point(world):
			return i
	return -1


## Índice de la esquina del rect seleccionado bajo el mouse, o -1. En píxeles
## de pantalla: al zoom chico las esquinas no se vuelven imposibles de agarrar.
func _handle_at(screen: Vector2) -> int:
	if _selected < 0 or _selected >= _rects.size():
		return -1
	var corners := _corners(_rects[_selected])
	for i in corners.size():
		if _to_screen(corners[i]).distance_to(screen) <= HANDLE_PX:
			return i
	return -1


func _corners(rect: Rect2) -> Array:
	return [
		rect.position,
		Vector2(rect.position.x + rect.size.x, rect.position.y),
		rect.position + rect.size,
		Vector2(rect.position.x, rect.position.y + rect.size.y),
	]


func _redraw() -> void:
	if _canvas:
		_canvas.queue_redraw()
	_update_info()


func _update_info() -> void:
	if _info == null:
		return
	if _selected >= 0 and _selected < _rects.size():
		var r := _rects[_selected]
		_info.text = "Rect %d/%d — %d x %d px\nen (%d, %d)" % [
			_selected + 1, _rects.size(), r.size.x, r.size.y, r.position.x, r.position.y]
	else:
		_info.text = "%d rect(s). Ninguno seleccionado." % _rects.size()


func _say(text: String) -> void:
	if _status:
		_status.text = text


# ---------------------------------------------------------------- dibujo

func _draw_canvas() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), COL_BG)
	_draw_grid()

	var origin := _origin()
	if _tex != null:
		var size := Vector2(_tex.get_width(), _tex.get_height()) * _zoom
		_canvas.draw_texture_rect(_tex, Rect2(origin - Vector2(size.x * 0.5, size.y), size), false)

	# La línea del suelo: donde se apoya el edificio y donde se hizo el click
	# al colocarlo. Todo rect tiene que terminar sobre ella, no flotando.
	_canvas.draw_line(Vector2(0, origin.y), Vector2(_canvas.size.x, origin.y), COL_GROUND, 1.0)
	_canvas.draw_line(Vector2(origin.x, 0), Vector2(origin.x, _canvas.size.y), COL_GROUND * Color(1, 1, 1, 0.5), 1.0)

	for i in _rects.size():
		var screen_rect := Rect2(_to_screen(_rects[i].position), _rects[i].size * _zoom)
		var is_sel := i == _selected
		_canvas.draw_rect(screen_rect, COL_SEL if is_sel else COL_RECT)
		_canvas.draw_rect(screen_rect, COL_SEL_LINE if is_sel else COL_RECT_LINE, false, 2.0)
		if is_sel:
			for corner in _corners(_rects[i]):
				var at := _to_screen(corner)
				_canvas.draw_rect(
					Rect2(at - Vector2(HANDLE_PX, HANDLE_PX) * 0.5,
						Vector2(HANDLE_PX, HANDLE_PX)), COL_SEL_LINE)


## Una celda de grilla = un tile del mundo (BuildGrid.TILE_SIZE), para poder
## pensar la planta en tiles y no en píxeles sueltos.
func _draw_grid() -> void:
	var step := BuildGrid.TILE_SIZE * _zoom
	if step < 6.0:
		return
	var origin := _origin()
	var x := fmod(origin.x, step)
	while x < _canvas.size.x:
		_canvas.draw_line(Vector2(x, 0), Vector2(x, _canvas.size.y), COL_GRID, 1.0)
		x += step
	var y := fmod(origin.y, step)
	while y < _canvas.size.y:
		_canvas.draw_line(Vector2(0, y), Vector2(_canvas.size.x, y), COL_GRID, 1.0)
		y += step

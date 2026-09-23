@tool
extends PanelContainer
## The editor-dock counterpart to hud.gd's BuildPanel — same data source
## (BuildCatalog/BuildIcons), so a new placeable id shows up in BOTH the
## in-game palette and this dock automatically, no second place to edit.
##
## Deliberately does NOT touch the `Game` autoload: autoloads are only
## reliably present while the game is actually running, not while just
## editing a scene in-editor, so this dock keeps its own selection state
## instead (selected_kind/wall_material/roof_material) and plugin.gd reads
## it directly rather than going through Game.build_selected_kind etc.

signal selection_changed
## Emitted by the "Zona" section's buttons — plugin.gd (which actually has
## get_editor_interface()/ResourceSaver access, this plain Control doesn't)
## does the real work. See plugin.gd's _on_zone_open_requested()/
## _on_zone_create_requested().
signal zone_open_requested(path: String)
signal zone_create_requested(display_name: String)

const ZONE_DIR := "res://scenes/world/"

## Off by default: a plain click in the 2D viewport should keep doing what
## it always does (select/move nodes) until this is explicitly turned on —
## hijacking every click the moment a zone scene is open would be a
## surprising, unwelcome default.
var tool_active: bool = false
var selected_kind: String = "wall_n"
var wall_material: String = "stone"
var roof_material: String = "slate"
## Free-brush radius in world pixels (PaintLayer). Lives here, not in
## Game.build_brush_size, for the reason plugin.gd's class doc gives: the
## `Game` autoload is a Play-mode concept and the editor cannot rely on it.
var brush_radius: int = 48
## Only applies to BuildingMarker.CARDINAL_ROTATE_KINDS (market/blacksmith/
## dock, see plugin.gd's _place()) — a FIXED_FRONT_KINDS building (house/
## mansion/bank) always places at 0 regardless of this, and every other
## palette kind ignores it entirely (no runtime Game.build_rotation
## equivalent exists in the editor). Cycled in 90° steps by _rotation_row()'s
## button, not free like the in-game Q/E — see BuildingMarker.placement_for().
var building_rotation: float = 0.0

const WALL_MATERIALS := ["stone", "brick", "plain", "wood"]
const ROOF_MATERIALS := ["slate", "red"]
const _CARDINAL_LABELS := ["Norte", "Este", "Sur", "Oeste"]

var _kind_buttons: Dictionary = {}
var _status_label: Label
## Filtro de la paleta. El catálogo pasó de una docena de ids a varios
## cientos (los ~200 tiles de camino, 45 edificios, 8 pinceles): scrollear
## hasta encontrar algo dejó de ser viable. Ninguno de los dos filtra el
## catálogo de verdad, solo qué botones se dibujan — la selección activa
## sobrevive aunque el filtro la esconda.
var _search_text: String = ""
var _category_filter: String = ""
var _categories_box: VBoxContainer
var _match_label: Label
var _rotation_button: Button
var _zone_dropdown: OptionButton
## Parallel to _zone_dropdown's items — index i's path is this zone_id's
## scene. Kept as its own array (not encoded into the item text) so
## "Abrir"/refresh never has to parse a display string back into a path.
var _zone_paths: Array[String] = []
var _zone_name_edit: LineEdit


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Build mode (editor) — click en el viewport 2D: colocar. Click derecho: borrar."
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(title)

	vbox.add_child(_zone_section())
	vbox.add_child(HSeparator.new())

	var active_check := CheckBox.new()
	active_check.text = "Herramienta activa (si no, los clicks funcionan normal)"
	active_check.button_pressed = tool_active
	active_check.toggled.connect(func(pressed: bool) -> void:
		tool_active = pressed
		selection_changed.emit()
	)
	vbox.add_child(active_check)

	vbox.add_child(_material_row("Material pared:", WALL_MATERIALS, wall_material, "wall"))
	vbox.add_child(_material_row("Material techo:", ROOF_MATERIALS, roof_material, "roof"))
	vbox.add_child(_rotation_row())
	vbox.add_child(_brush_row())

	vbox.add_child(_filter_row())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_categories_box = VBoxContainer.new()
	_categories_box.add_theme_constant_override("separation", 4)
	_categories_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_categories_box)

	_populate_palette()

	_status_label = Label.new()
	_status_label.text = "Selección: %s" % BuildCatalog.label_for(selected_kind)
	vbox.add_child(_status_label)


## Zone list + "New zone" — the multi-zone half of the tool. Listing existing
## zones and building/saving a brand new one are both plain filesystem/
## resource work (no EditorPlugin privilege needed), so they happen right
## here; only actually SWITCHING the open scene needs plugin.gd (see the
## signals this emits, and its class doc).
func _zone_section() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.text = "Zona"
	box.add_child(header)

	var open_row := HBoxContainer.new()
	_zone_dropdown = OptionButton.new()
	_zone_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_row.add_child(_zone_dropdown)
	var open_button := Button.new()
	open_button.text = "Abrir"
	open_button.pressed.connect(func() -> void:
		var i := _zone_dropdown.selected
		if i >= 0 and i < _zone_paths.size():
			zone_open_requested.emit(_zone_paths[i])
	)
	open_row.add_child(open_button)
	box.add_child(open_row)
	_populate_zone_dropdown()

	var create_row := HBoxContainer.new()
	_zone_name_edit = LineEdit.new()
	_zone_name_edit.placeholder_text = "Nombre de zona nueva"
	_zone_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_row.add_child(_zone_name_edit)
	var create_button := Button.new()
	create_button.text = "Crear zona nueva"
	create_button.pressed.connect(func() -> void:
		var typed := _zone_name_edit.text.strip_edges()
		if typed == "":
			return
		zone_create_requested.emit(typed)
		_zone_name_edit.text = ""
	)
	create_row.add_child(create_button)
	box.add_child(create_row)

	return box


## Called by plugin.gd after it saves a new zone scene, so the dropdown
## offers it immediately — without this the dock would only pick up a
## freshly-created zone the next time the editor reloads the whole dock.
func refresh_zone_list() -> void:
	if _zone_dropdown:
		_populate_zone_dropdown()


func _populate_zone_dropdown() -> void:
	_zone_dropdown.clear()
	_zone_paths = _scan_zone_scenes()
	for path in _zone_paths:
		_zone_dropdown.add_item(path.get_file().get_basename())


## Every .tscn directly under ZONE_DIR whose root has a direct "Markers"
## child — same "does this look like a zone" heuristic plugin.gd's
## _current_zone() already uses, just applied to a file on disk instead of
## the currently-open scene. Inspects the PackedScene's SceneState instead
## of instantiate()-ing it: cheap, and never runs a zone's own @tool code
## just to list it.
static func _scan_zone_scenes() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(ZONE_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tscn"):
			var path := ZONE_DIR + entry
			if _looks_like_zone(path):
				out.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


static func _looks_like_zone(path: String) -> bool:
	var packed: Resource = load(path)
	if not (packed is PackedScene):
		return false
	var state := (packed as PackedScene).get_state()
	for i in state.get_node_count():
		# get_node_path() includes the root's own "." segment, so a DIRECT
		# child of root (e.g. "./Markers") has name_count 2, not 1 — verified
		# empirically against pradera.tscn (root itself: path=".", count=1;
		# "Floor"/"Markers": path="./Floor" etc., count=2), not assumed.
		if state.get_node_name(i) == "Markers" and state.get_node_path(i).get_name_count() == 2:
			return true
	return false


## Radius of the "PINCEL (libre)" brush. Shown unconditionally, same
## reasoning as the material rows: irrelevant while placing a mob, but a row
## that appears and disappears is worse than one that is simply ignored.
func _brush_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Pincel (radio):"
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 4
	slider.max_value = 160
	slider.step = 2
	slider.value = brush_radius
	slider.custom_minimum_size = Vector2(110, 0)
	row.add_child(slider)
	var value := Label.new()
	value.text = "%dpx" % brush_radius
	row.add_child(value)
	slider.value_changed.connect(func(v: float) -> void:
		brush_radius = int(v)
		value.text = "%dpx" % brush_radius
		selection_changed.emit()
	)
	return row


func _material_row(label_text: String, options: Array, current: String, axis: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)
	var opt := OptionButton.new()
	for m in options:
		opt.add_item(str(m))
	var idx: int = options.find(current)
	opt.selected = maxi(idx, 0)
	opt.item_selected.connect(func(i: int) -> void:
		var value: String = options[i]
		if axis == "wall":
			wall_material = value
		else:
			roof_material = value
		selection_changed.emit()
	)
	row.add_child(opt)
	return row


## Only meaningful for "building_market_*"/"building_blacksmith"/"building_dock"
## (BuildingMarker.CARDINAL_ROTATE_KINDS) — shown unconditionally rather than
## toggled per-selection, same reasoning as the wall/roof material rows
## (which are just as irrelevant while placing a mob, but always visible):
## keeping the row count/layout stable is simpler than rebuilding the dock on
## every kind change, and the tooltip on the button explains when it applies.
func _rotation_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Rotación edificio:"
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)
	_rotation_button = Button.new()
	_rotation_button.tooltip_text = "Solo aplica a Mercado/Herrería/Muelle — casas/mansión/banco siempre van de frente."
	_update_rotation_button_text()
	_rotation_button.pressed.connect(func() -> void:
		building_rotation = wrapf(building_rotation + PI / 2.0, 0.0, TAU)
		_update_rotation_button_text()
		selection_changed.emit()
	)
	row.add_child(_rotation_button)
	return row


func _update_rotation_button_text() -> void:
	if _rotation_button == null:
		return
	var steps := int(roundf(building_rotation / (PI / 2.0))) % 4
	_rotation_button.text = "⟳ %s" % _CARDINAL_LABELS[steps]


## Buscador + filtro por categoría. Los dos son del DOCK, no del catálogo:
## no hay forma de que un filtro mal puesto haga desaparecer un placeable del
## juego, solo de esta lista.
func _filter_row() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var search := LineEdit.new()
	search.placeholder_text = "Buscar (nombre o id)…"
	search.clear_button_enabled = true
	search.text = _search_text
	search.text_changed.connect(func(text: String) -> void:
		_search_text = text
		_populate_palette())
	box.add_child(search)

	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Categoría:"
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)

	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_item("Todas")
	# Paralelo a los items, igual que _zone_paths con el dropdown de zonas:
	# el índice 0 es "Todas" y de ahí en adelante sigue el orden de CATEGORIES.
	var filter_ids: Array[String] = [""]
	for cat in BuildCatalog.CATEGORIES:
		var category_id := str(cat[0])
		if BuildCatalog.ids_in_category(category_id).is_empty():
			continue
		opt.add_item(str(cat[1].get("label", category_id)))
		filter_ids.append(category_id)
	opt.selected = maxi(filter_ids.find(_category_filter), 0)
	opt.item_selected.connect(func(i: int) -> void:
		_category_filter = filter_ids[i] if i < filter_ids.size() else ""
		_populate_palette())
	row.add_child(opt)
	box.add_child(row)

	_match_label = Label.new()
	box.add_child(_match_label)

	return box


## Redibuja los botones de la paleta aplicando los filtros. Se llama en cada
## tecla del buscador, así que rehace SOLO esta lista y no el dock entero:
## reconstruir todo perdería el foco del LineEdit en la primera letra.
func _populate_palette() -> void:
	if _categories_box == null:
		return
	for child in _categories_box.get_children():
		_categories_box.remove_child(child)
		child.queue_free()

	var group := ButtonGroup.new()
	_kind_buttons.clear()
	var shown := 0
	var total := 0

	for cat in BuildCatalog.CATEGORIES:
		var category_id := str(cat[0])
		var category_label := str(cat[1].get("label", category_id))
		var ids := BuildCatalog.ids_in_category(category_id)
		total += ids.size()
		if _category_filter != "" and category_id != _category_filter:
			continue

		var matching: Array[String] = []
		for id in ids:
			if _matches(id):
				matching.append(id)
		if matching.is_empty():
			continue
		shown += matching.size()

		var header := Label.new()
		header.text = category_label
		_categories_box.add_child(header)

		var grid := GridContainer.new()
		grid.columns = 5
		_categories_box.add_child(grid)

		for id in matching:
			var button := Button.new()
			button.toggle_mode = true
			button.button_group = group
			button.custom_minimum_size = Vector2(36, 36)
			button.icon = BuildIcons.get_icon(id)
			button.expand_icon = true
			button.tooltip_text = BuildCatalog.label_for(id)
			button.button_pressed = (id == selected_kind)
			button.toggled.connect(_on_kind_toggled.bind(id))
			grid.add_child(button)
			_kind_buttons[id] = button

	if _match_label:
		if shown == total:
			_match_label.text = "%d placeables" % total
		elif shown == 0:
			_match_label.text = "Nada coincide con el filtro (%d en total)" % total
		else:
			_match_label.text = "%d de %d" % [shown, total]


## Un id entra si el texto buscado aparece en su etiqueta o en el id mismo.
## Busca en los dos porque se lo piensa de las dos formas: "herrería" es lo
## que dice el botón, "blacksmith" es como se llama el archivo.
func _matches(id: String) -> bool:
	if _search_text.strip_edges() == "":
		return true
	var needle := _fold(_search_text)
	return _fold(BuildCatalog.label_for(id)).contains(needle) or _fold(id).contains(needle)


## Minúsculas y sin tildes. Medio catálogo está acentuado ("Árbol",
## "Antorcha", "Cumbrera", "Límatesa") y nadie escribe las tildes buscando.
func _fold(text: String) -> String:
	var out := text.to_lower()
	const ACCENTS := {
		"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u",
		"à": "a", "è": "e", "ì": "i", "ò": "o", "ù": "u",
		"ä": "a", "ë": "e", "ï": "i", "ö": "o", "ü": "u",
		"ñ": "n", "ç": "c",
	}
	for accented in ACCENTS:
		out = out.replace(accented, str(ACCENTS[accented]))
	return out


func _on_kind_toggled(pressed: bool, id: String) -> void:
	if not pressed:
		return
	selected_kind = id
	if _status_label:
		_status_label.text = "Selección: %s" % BuildCatalog.label_for(id)
	selection_changed.emit()

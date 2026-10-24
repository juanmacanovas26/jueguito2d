extends Node
## Suite del vallado: el autotiler de 3 bits, el atlas horneado, la colisión
## que viaja en el TileSet, y la tirada recta del gesto tipo AoE.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/validate_fence.tscn
##
## Lo que NO se puede medir acá —si la valla se ve continua— se miró con una
## captura real (tools/fence_screenshot.tscn), igual que el pincel y el techo.

const WORLD_ZONE_SCRIPT := preload("res://scripts/world/world_zone.gd")
## Piso real de checks: si una sección se saltea (ver _ready()), esto es lo
## que lo grita. No bajarlo para que "pase" — ese fue exactamente el error.
const MIN_CHECKS := 50

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	# await, no _run() a secas: _run() tiene awaits adentro, así que sin
	# esperarlo _ready() sigue de largo y reporta el resultado antes de que
	# la mitad de las secciones hayan corrido. Pasó: la suite daba verde
	# salteando el round-trip por la zona, y el piso de MIN_CHECKS fue lo
	# único que lo delató.
	await _run()
	_check_ran_enough()
	print("\n-- %d checks, %d failures --" % [_checks, _failures.size()])
	for f in _failures:
		print("   FAIL ", f)
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _ok(label: String) -> void:
	_checks += 1
	print("      ok   ", label)


func _fail(label: String) -> void:
	_checks += 1
	_failures.append(label)
	print("      FAIL ", label)


func _expect(cond: bool, label: String) -> void:
	if cond:
		_ok(label)
	else:
		_fail(label)


func _check_ran_enough() -> void:
	if _checks < MIN_CHECKS:
		_failures.append("solo %d checks, se esperaban al menos %d — ¿se salteó una sección?"
			% [_checks, MIN_CHECKS])


func _make_zone() -> Node2D:
	var zone := Node2D.new()
	zone.set_script(WORLD_ZONE_SCRIPT)
	add_child(zone)
	return zone


func _run() -> void:
	print("== validate_fence ==")
	_check_mask()
	_check_line()
	_check_atlas()
	_check_tileset_and_collision()
	await _check_zone_round_trip()
	await _check_editor_path()
	_check_palette_icon()


## El bitmask: solo cruz, sin diagonales, y el sur no cuenta porque no tiene
## dibujo propio (el tronco del poste ya llega al borde de abajo).
func _check_mask() -> void:
	print("\n[1] FenceAutotiler: bitmask de 3 bits")
	var cells := {}
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 1)]:
		cells[c] = true

	var mask := FenceAutotiler.mask_at(cells, Vector2i(0, 0))
	_expect(mask & FenceAutotiler.N != 0, "una vecina al norte prende el bit N")
	_expect(mask & FenceAutotiler.E != 0, "una vecina al este prende el bit E")
	_expect(mask & FenceAutotiler.W != 0, "una vecina al oeste prende el bit O")
	_expect(mask <= 7, "el mask nunca se va de 3 bits (el sur no tiene bit)")

	var solo := FenceAutotiler.mask_at({Vector2i(5, 5): true}, Vector2i(5, 5))
	_expect(solo == 0, "una celda sola es el poste aislado (mask 0)")

	var diag := FenceAutotiler.mask_at(
		{Vector2i(0, 0): true, Vector2i(1, 1): true}, Vector2i(0, 0))
	_expect(diag == 0, "una vecina en diagonal NO conecta (una valla no hace curvas)")

	var south_only := FenceAutotiler.mask_at(
		{Vector2i(0, 0): true, Vector2i(0, 1): true}, Vector2i(0, 0))
	_expect(south_only == 0,
		"conectar solo hacia el sur no cambia la pieza: la celda de abajo pone su baranda norte")

	for m in FenceAutotiler.TILES_PER_STYLE:
		var coords := FenceAutotiler.atlas_coords(m)
		_expect(coords == Vector2i(m, 0), "el mask %d cae en el tile %d del atlas" % [m, m])


## La tirada recta del gesto de AoE.
func _check_line() -> void:
	print("\n[2] FenceAutotiler: tirada recta (gesto AoE)")
	var horiz := FenceAutotiler.line_cells(Vector2i(0, 0), Vector2i(4, 0))
	_expect(horiz.size() == 5, "una tirada de 0 a 4 son 5 celdas (ambas puntas incluidas)")
	_expect(horiz[0] == Vector2i(0, 0) and horiz[4] == Vector2i(4, 0),
		"la tirada arranca y termina donde se hizo click")

	var back := FenceAutotiler.line_cells(Vector2i(4, 0), Vector2i(0, 0))
	_expect(back.size() == 5, "arrastrar hacia atrás da la misma cantidad de celdas")

	var vert := FenceAutotiler.line_cells(Vector2i(2, 2), Vector2i(2, -3))
	_expect(vert.size() == 6, "una tirada vertical también cierra en ambas puntas")
	var all_same_column := true
	for c in vert:
		if c.x != 2:
			all_same_column = false
	_expect(all_same_column, "una tirada vertical no se desvía de su columna")

	# Arrastrar en diagonal se queda con un eje: una escalera de postes casi
	# nunca es lo que se quiso (ver line_cells()).
	var diag := FenceAutotiler.line_cells(Vector2i(0, 0), Vector2i(5, 2))
	var straight := true
	for c in diag:
		if c.y != 0:
			straight = false
	_expect(straight and diag.size() == 6,
		"un arrastre diagonal se endereza al eje más largo, no hace escalera")

	var dot := FenceAutotiler.line_cells(Vector2i(7, 7), Vector2i(7, 7))
	_expect(dot.size() == 1 and dot[0] == Vector2i(7, 7),
		"un click sin arrastre es una tirada de una celda")


## El atlas horneado tiene que existir y tener la forma que el tileset espera.
func _check_atlas() -> void:
	print("\n[3] El atlas horneado")
	var styles := FenceAutotiler.styles()
	_expect(not styles.is_empty(), "hay al menos un estilo de valla en el catálogo")
	for style in styles:
		var path := FenceAutotiler.atlas_path(style)
		_expect(ResourceLoader.exists(path), "'%s' tiene su atlas en disco" % style)
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var expected_w := BuildGrid.TILE_SIZE * FenceAutotiler.TILES_PER_STYLE
		_expect(int(tex.get_width()) == expected_w and int(tex.get_height()) == BuildGrid.TILE_SIZE,
			"'%s' mide %dx%d (8 tiles de 32)" % [style, expected_w, BuildGrid.TILE_SIZE])

		# Que las 8 combinaciones sean DISTINTAS: si el baker se equivoca de
		# recorte, lo más probable es que escriba ocho veces lo mismo y todo
		# "funcione" con una valla que nunca conecta.
		var img := tex.get_image()
		var seen := {}
		var distinct := true
		for m in FenceAutotiler.TILES_PER_STYLE:
			var tile := img.get_region(Rect2i(m * BuildGrid.TILE_SIZE, 0,
				BuildGrid.TILE_SIZE, BuildGrid.TILE_SIZE))
			var key := tile.get_data().hex_encode()
			if seen.has(key):
				distinct = false
			seen[key] = true
		_expect(distinct, "'%s': las 8 combinaciones son dibujos distintos" % style)


## La colisión viaja adentro del TileSet, que es lo que hace que poner la
## valla YA la vuelva sólida sin pintar colisión aparte.
func _check_tileset_and_collision() -> void:
	print("\n[4] FenceTileset: colisión en la capa de física")
	var built := FenceTileset.build()
	var ts: TileSet = built["tileset"]
	var ids: Dictionary = built["source_ids"]
	_expect(ts != null and ts.get_physics_layers_count() == 1,
		"el TileSet declara una capa de física")
	_expect(ts.get_physics_layer_collision_layer(0) == 1,
		"la valla vive en la capa 1, la misma que todo lo sólido del mundo")
	_expect(ts.get_physics_layer_collision_mask(0) == 0,
		"mask 0: una valla es detectada, no detecta")
	_expect(not ids.is_empty(), "el tileset trae al menos un estilo")

	for style in ids:
		var src := ts.get_source(int(ids[style])) as TileSetAtlasSource
		_expect(src != null and src.get_tiles_count() == FenceAutotiler.TILES_PER_STYLE,
			"'%s' aporta los 8 tiles" % style)
		if src == null:
			continue
		for m in FenceAutotiler.TILES_PER_STYLE:
			var data := src.get_tile_data(FenceAutotiler.atlas_coords(m), 0)
			var polys := data.get_collision_polygons_count(0) if data else 0
			# Siempre el poste, más una caja por baranda dibujada.
			var rails := 0
			for bit in [FenceAutotiler.N, FenceAutotiler.E, FenceAutotiler.W]:
				if m & bit:
					rails += 1
			_expect(polys == 1 + rails,
				"el tile %d tiene %d polígono(s): poste + %d baranda(s)" % [m, 1 + rails, rails])


## El viaje completo por la zona: colocar, resolver el vecindario, borrar.
func _check_zone_round_trip() -> void:
	print("\n[5] WorldZone: colocar, autotilear y borrar")
	var zone := _make_zone()
	zone.call("_build_fences")

	var style: String = FenceAutotiler.styles()[0]
	var kind := FenceAutotiler.palette_id(style)
	for x in 3:
		zone.call("_place_marker", kind, BuildGrid.cell_to_world(Vector2i(x, 0)))
	await get_tree().process_frame

	var markers: Node = zone.get_node_or_null("Markers")
	var placed := ZoneBuilder.collect_fences(markers)
	_expect(placed.size() == 3, "tres clicks dejan tres celdas de valla (quedaron %d)" % placed.size())
	_expect(placed.size() > 0 and placed[0].style == style,
		"el estilo del id de paleta llega al marker")

	var layer: TileMapLayer = zone.get_node_or_null("Vallas")
	_expect(layer != null, "la zona arma la capa 'Vallas'")
	if layer != null:
		_expect(layer.get_used_cells().size() == 3, "la capa pinta las tres celdas")
		# La del medio conecta a los dos lados; las puntas a uno solo.
		var middle := layer.get_cell_atlas_coords(Vector2i(1, 0))
		_expect(middle.x == (FenceAutotiler.E | FenceAutotiler.W),
			"la celda del medio resuelve a la tirada horizontal")
		var left := layer.get_cell_atlas_coords(Vector2i(0, 0))
		_expect(left.x == FenceAutotiler.E, "la punta izquierda solo conecta al este")
		var right := layer.get_cell_atlas_coords(Vector2i(2, 0))
		_expect(right.x == FenceAutotiler.W, "la punta derecha solo conecta al oeste")

	# Volver a poner el mismo estilo en una celda ocupada no apila markers.
	zone.call("_place_marker", kind, BuildGrid.cell_to_world(Vector2i(1, 0)))
	await get_tree().process_frame
	_expect(ZoneBuilder.collect_fences(markers).size() == 3,
		"repasar una celda con el mismo estilo no apila un segundo marker")

	# Borrar la del medio parte la tirada: las dos que quedan pasan a ser
	# puntas sueltas, que es lo que prueba que el vecindario se recalcula.
	zone.call("_remove_marker", placed[1])
	zone.call("_rebuild_fences")
	await get_tree().process_frame
	if layer != null:
		_expect(layer.get_used_cells().size() == 2, "borrar una celda la saca de la capa")
		_expect(layer.get_cell_atlas_coords(Vector2i(0, 0)).x == 0,
			"al partirse la tirada, la celda que quedó sola vuelve a poste aislado")
	zone.free()


## La regresión de "no veo el sprite en el editor". En el editor la zona no
## pasa por _build_world() —eso es solo al jugar— sino por
## ensure_render_layers(), y la capa "Vallas" no es un nodo guardado en el
## .tscn de la zona: nace vacía cada vez que se abre la escena. Si
## ensure_render_layers() no la repinta desde los markers, el editor muestra
## el gizmo del marker y ningún sprite.
func _check_editor_path() -> void:
	print("
[6] El camino del editor (ensure_render_layers)")
	var zone := _make_zone()
	var kind := FenceAutotiler.palette_id(FenceAutotiler.styles()[0])
	for x in 2:
		zone.call("_place_marker", kind, BuildGrid.cell_to_world(Vector2i(x, 9)))
	await get_tree().process_frame

	# Tirar la capa y rearmar por donde entra el editor: es exactamente lo
	# que pasa al cerrar y volver a abrir la escena.
	var layer: TileMapLayer = zone.get_node_or_null("Vallas")
	_expect(layer != null, "la capa existe después de colocar")
	if layer != null:
		layer.free()
	_expect(zone.get_node_or_null("Vallas") == null, "la capa se fue, como al reabrir la escena")

	zone.call("ensure_render_layers")
	var rebuilt: TileMapLayer = zone.get_node_or_null("Vallas")
	_expect(rebuilt != null, "ensure_render_layers() vuelve a armar la capa")
	if rebuilt != null:
		_expect(rebuilt.get_used_cells().size() == 2,
			"y la REPINTA desde los markers (si no, en el editor no se ve nada)")
		_expect(rebuilt.collision_enabled == false or not Engine.is_editor_hint(),
			"la colisión no se arma de gusto mientras se mapea")
	zone.free()


## El botón de la paleta: el atlas son 8 combinaciones en fila, así que el
## ícono tiene que ser un recorte y no el PNG entero — si no, el botón
## muestra ocho vallas apretadas.
func _check_palette_icon() -> void:
	print("
[7] El ícono de la paleta")
	var style: String = FenceAutotiler.styles()[0]
	var icon := BuildIcons.get_icon(FenceAutotiler.palette_id(style))
	_expect(icon != null, "la paleta resuelve un ícono para la valla")
	_expect(icon is AtlasTexture, "es un recorte del atlas, no el atlas entero")
	if icon is AtlasTexture:
		var region := (icon as AtlasTexture).region
		_expect(int(region.size.x) == BuildGrid.TILE_SIZE
			and int(region.size.y) == BuildGrid.TILE_SIZE,
			"el recorte es de una celda")
		_expect(int(region.position.x) == FenceAutotiler.ICON_MASK * BuildGrid.TILE_SIZE,
			"muestra la tirada horizontal, que es la que se lee como 'valla'")

class_name FenceTileset
extends RefCounted
## Arma el TileSet de la capa "Vallas" a partir de los atlas horneados en
## assets/world/fences/ (uno por estilo, 8 tiles en fila — ver
## FenceAutotiler y tools/bake_fence_tiles.py).
##
## Una fuente de atlas por estilo y los 8 tiles adentro, en vez de una fuente
## por tile: el atlas ya viene en un solo PNG y las coordenadas son el
## bitmask, así que no hay nada que mapear.
##
## LA COLISIÓN VIVE ACÁ, en la capa de física del TileSet, y no en
## StaticBody2D sueltos como CollisionMarker. Una valla es sólida siempre y
## en todas las celdas: dejarlo en manos del que mapea —acordarse de pintar
## colisión encima de cada tramo— es exactamente el error que se comete. Con
## la capa de física, poner la valla YA la hace sólida, y la TileMapLayer
## arma los cuerpos sola.
##
## Las cajas siguen al arte, medidas sobre el atlas horneado y no inventadas:
## el poste ocupa 12px centrados por 26 de alto, y cada baranda 10x16 hacia su
## borde. Poste + barandas cubren la celda entera en el eje en que la valla
## conecta, así que una tirada no tiene agujeros por donde colarse.

const TILE_SIZE := BuildGrid.TILE_SIZE_2I

## Cajas en coordenadas locales al CENTRO del tile, que es como Godot quiere
## los polígonos de colisión de un tile. Medidas sobre el alfa del atlas
## (ver tools/bake_fence_tiles.py): poste x 10-21 y 6-31, barandas y 12-27.
const POST_BOX := Rect2(-6, -10, 12, 26)
const RAIL_E_BOX := Rect2(6, -4, 10, 16)
const RAIL_W_BOX := Rect2(-16, -4, 10, 16)
const RAIL_N_BOX := Rect2(-3, -16, 6, 6)


## Devuelve {"tileset": TileSet, "source_ids": {estilo -> int}}. Se llama una
## vez por zona (world_zone.gd's _build_fences()); volver a llamarla
## reconstruye de cero, así que también levanta estilos agregados desde la
## última vez.
static func build() -> Dictionary:
	var ts := TileSet.new()
	ts.tile_size = TILE_SIZE
	# Capa 1 = lo sólido del mundo, la misma que WorldBounds, CollisionMarker
	# y las escenas de edificio. Mask 0: una valla no detecta, es detectada.
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	var ids := {}
	for style in FenceAutotiler.styles():
		var path := FenceAutotiler.atlas_path(style)
		if not ResourceLoader.exists(path):
			push_warning("[FenceTileset] falta %s — se saltea el estilo '%s'." % [path, style])
			continue
		var tex: Resource = load(path)
		if not (tex is Texture2D):
			continue
		var size: Vector2 = (tex as Texture2D).get_size()
		var expected := TILE_SIZE.x * FenceAutotiler.TILES_PER_STYLE
		if int(size.x) != expected or int(size.y) != TILE_SIZE.y:
			push_warning(("[FenceTileset] %s es %dx%d pero un atlas de valla es %dx%d "
				+ "(%d tiles) — se saltea. ¿Falta correr bake_fence_tiles.py?")
				% [path, int(size.x), int(size.y), expected, TILE_SIZE.y,
					FenceAutotiler.TILES_PER_STYLE])
			continue

		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = TILE_SIZE
		# La fuente entra al TileSet ANTES de crear los tiles: un TileData
		# solo conoce las capas de física del TileSet al que ya pertenece, y
		# pedirle un polígono a una fuente suelta falla con "p_layer_id = 0
		# is out of bounds". Costó una corrida de tests averiguarlo.
		var id := ts.get_next_source_id()
		ts.add_source(src, id)
		for mask in FenceAutotiler.TILES_PER_STYLE:
			var coords := FenceAutotiler.atlas_coords(mask)
			src.create_tile(coords)
			_add_collision(src.get_tile_data(coords, 0), mask)
		ids[style] = id
	return {"tileset": ts, "source_ids": ids}


## El poste siempre, y cada baranda que esta combinación dibuje. Un polígono
## por caja en vez de uno solo con forma de cruz: son convexos, que es lo que
## el motor de física quiere, y la unión de varios cuerpos convexos no deja
## las esquinas raras que deja un cóncavo mal triangulado.
static func _add_collision(tile_data: TileData, mask: int) -> void:
	if tile_data == null:
		return
	var boxes: Array[Rect2] = [POST_BOX]
	if mask & FenceAutotiler.E:
		boxes.append(RAIL_E_BOX)
	if mask & FenceAutotiler.W:
		boxes.append(RAIL_W_BOX)
	if mask & FenceAutotiler.N:
		boxes.append(RAIL_N_BOX)
	for i in boxes.size():
		var box := boxes[i]
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, i, PackedVector2Array([
			box.position,
			Vector2(box.position.x + box.size.x, box.position.y),
			box.position + box.size,
			Vector2(box.position.x, box.position.y + box.size.y),
		]))

class_name BiomeTileset
extends RefCounted
## The "TERRENO (auto)" brush: paint WHICH terrain a cell is (agua, arena,
## piedra, barro, pasto) and the borders between terrains are drawn on their
## own, from the four Wang sheets in assets/tiles/ (made by
## art_pipeline/tiles/gen_biome_wang.py, same format as grass_dirt_wang.png).
##
## Why the brush names a terrain and not "one side of one sheet": a pond is
## water, a ring of sand, then the grass of the field. The sand ring borders
## water on one side and grass on the other, so it needs a different sheet on
## each side. If a cell stored "the sand half of water_sand" it could never
## blend into the grass around it. Resolving per corner instead lets every
## cell pick whichever sheet its own four corners call for.
##
## The rules, all in resolve():
##  - Each grid VERTEX gets the highest-priority terrain among the up-to-four
##    cells around it (PRIORITY). Painted terrain beats grass, so a painted
##    stroke grows half a cell into the grass around it instead of shrinking.
##  - A cell with one terrain on its corners gets that terrain's pure tile; with
##    two, the sheet for that pair. Pairs with no sheet (agua-pasto, say) fall
##    back to a hard edge: put arena between agua and pasto.
##  - Unpainted cells count as pasto, and get a tile only when a border runs
##    through them, so the zone's own Floor (grass with dirt patches) still
##    shows everywhere else.
##
## Not Godot's terrain system: set_cells_terrain_connect() only knows one
## terrain set at a time, and this needs four that share terrains.

const TILE_SIZE := Vector2i(32, 32)
const SEPARATION := 1
const COLUMNS := 4
const DIR := "res://assets/tiles/"

## FloorTileMarker.tile_id prefix; the palette id is "floor_" + this + terrain.
const ID_PREFIX := "terreno_"
const GRASS := "pasto"

## Who wins a shared vertex. Ties never happen: every value is distinct.
const PRIORITY := {"agua": 4, "arena": 3, "piedra": 2, "barro": 1, "pasto": 0}

## Sheet -> [lower, upper]. In a sheet, index = TL*8 + TR*4 + BL*2 + BR*1 and a
## set bit means that corner is the upper terrain.
const SHEETS := {
	"water_sand": ["agua", "arena"],
	"sand_grass": ["arena", "pasto"],
	"stone_grass": ["piedra", "pasto"],
	"mud_grass": ["barro", "pasto"],
}

## Where each terrain's pure tile is read from. Pasto comes from sand_grass,
## whose grass is a pixel copy of grass_dirt_wang.png's, so it matches the Floor.
const PURE := {
	"agua": ["water_sand", 0],
	"arena": ["water_sand", 15],
	"piedra": ["stone_grass", 0],
	"barro": ["mud_grass", 0],
	"pasto": ["sand_grass", 15],
}


static func is_terrain_id(tile_id: String) -> bool:
	return tile_id.begins_with(ID_PREFIX)


static func terrain_of(tile_id: String) -> String:
	return tile_id.trim_prefix(ID_PREFIX)


static func palette_id(terrain: String) -> String:
	return "floor_" + ID_PREFIX + terrain


static func path_for(sheet: String) -> String:
	return DIR + sheet + "_wang.png"


static func atlas_coords(index: int) -> Vector2i:
	return Vector2i(index % COLUMNS, index / COLUMNS)


## Returns {"tileset": TileSet, "source_ids": {sheet -> int}}. A missing or
## wrongly sized sheet is skipped with a warning; cells that need it stay blank.
static func build() -> Dictionary:
	var ts := TileSet.new()
	ts.tile_size = TILE_SIZE
	var ids := {}
	var expected := TILE_SIZE.x * COLUMNS + SEPARATION * (COLUMNS - 1)
	for sheet in SHEETS:
		var path := path_for(sheet)
		if not ResourceLoader.exists(path):
			push_warning("[BiomeTileset] missing %s — terrain using it will not draw." % path)
			continue
		var tex: Resource = load(path)
		if not (tex is Texture2D):
			continue
		var size: Vector2 = (tex as Texture2D).get_size()
		if int(size.x) != expected or int(size.y) != expected:
			push_warning("[BiomeTileset] %s is %dx%d but a Wang sheet must be %dx%d — skipping it."
				% [path, int(size.x), int(size.y), expected, expected])
			continue
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = TILE_SIZE
		src.separation = Vector2i(SEPARATION, SEPARATION)
		for index in 16:
			src.create_tile(atlas_coords(index))
		var id := ts.get_next_source_id()
		ts.add_source(src, id)
		ids[sheet] = id
	return {"tileset": ts, "source_ids": ids}


## `painted` is {Vector2i cell -> terrain}. Returns {Vector2i cell -> [sheet,
## index]} for every cell that should draw something: the painted ones, plus
## unpainted neighbours that a border runs through.
static func resolve(painted: Dictionary) -> Dictionary:
	var todo := {}
	for cell in painted:
		todo[cell] = true
		if painted[cell] != GRASS:
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					todo[cell + Vector2i(dx, dy)] = true
	var out := {}
	for cell in todo:
		var own: String = painted.get(cell, GRASS)
		var corners: Array[String] = [
			_vertex(painted, cell),
			_vertex(painted, cell + Vector2i(1, 0)),
			_vertex(painted, cell + Vector2i(0, 1)),
			_vertex(painted, cell + Vector2i(1, 1)),
		]
		var picked := _pick(own, corners)
		if not painted.has(cell) and picked == PURE[GRASS]:
			continue
		out[cell] = picked
	return out


## The terrain at the top-left vertex of `cell`: the strongest terrain among the
## four cells around it that has a sheet with every other terrain there. Where
## water, sand and grass meet that is sand, not water (water has no sheet with
## grass), so every cell sharing the vertex can draw it and the shore stays
## continuous. With no such terrain it is simply the strongest.
static func _vertex(painted: Dictionary, cell: Vector2i) -> String:
	var around: Array[String] = []
	for offset in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i.ZERO]:
		var t: String = painted.get(cell + offset, GRASS)
		if not around.has(t):
			around.append(t)
	around.sort_custom(func(a: String, b: String) -> bool: return PRIORITY[a] > PRIORITY[b])
	for t in around:
		var drawable := true
		for o in around:
			if o != t and _sheet_for(t, o) == "":
				drawable = false
				break
		if drawable:
			return t
	return around[0]


static func _pick(own: String, corners: Array[String]) -> Array:
	var distinct: Array[String] = []
	for t in corners:
		if not distinct.has(t):
			distinct.append(t)
	if distinct.size() == 1:
		return PURE[distinct[0]]
	if distinct.size() == 2:
		var sheet := _sheet_for(distinct[0], distinct[1])
		if sheet != "":
			return [sheet, _index(sheet, corners)]
	# No sheet covers these corners (only when terrains with no sheet between
	# them touch — _vertex() already settles three-way shores): keep this
	# cell's own terrain and the strongest other one it does have a sheet
	# with; any remaining corner is drawn as its own terrain, a hard edge.
	distinct.sort_custom(func(a: String, b: String) -> bool: return PRIORITY[a] > PRIORITY[b])
	for other in distinct:
		if other == own:
			continue
		var sheet := _sheet_for(own, other)
		if sheet == "":
			continue
		var mapped: Array[String] = []
		for t in corners:
			mapped.append(other if t == other else own)
		return [sheet, _index(sheet, mapped)]
	return PURE[own]


static func _sheet_for(a: String, b: String) -> String:
	for sheet in SHEETS:
		var pair: Array = SHEETS[sheet]
		if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
			return sheet
	return ""


static func _index(sheet: String, corners: Array[String]) -> int:
	var upper: String = SHEETS[sheet][1]
	var index := 0
	for i in 4:
		if corners[i] == upper:
			index |= 8 >> i
	return index


## The palette button / ghost picture for a terrain: its pure tile.
static func icon(terrain: String) -> Texture2D:
	if not PURE.has(terrain):
		return null
	var path := path_for(PURE[terrain][0])
	if not ResourceLoader.exists(path):
		return null
	var at := AtlasTexture.new()
	at.atlas = load(path)
	var coords := atlas_coords(int(PURE[terrain][1]))
	at.region = Rect2(Vector2(coords * (TILE_SIZE + Vector2i(SEPARATION, SEPARATION))), Vector2(TILE_SIZE))
	return at

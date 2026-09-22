@tool
class_name PaintLayer
extends Sprite2D
## The "PINCEL (libre)" tool: a round, free-form brush that paints a patch of
## ground wherever the cursor goes, with no grid and no autotiling — for dirt
## tracks worn across a field, muddy verges, a clearing. The one ground layer
## in the project that is NOT a TileMapLayer.
##
## Everything else here (Floor, Suelo, Structures, Roof) snaps to BuildGrid's
## 32px cells, and for built things that is right. A footpath is not a built
## thing: forcing it onto the grid gives a staircase of 32px blocks, and
## autotiling it gives the shape the TILESET can express rather than the shape
## you drew. So this stores a COVERAGE MASK instead of cells, and the shader
## (assets/shaders/painted_ground.gdshader) cuts a repeating ground texture out
## of it.
##
## The mask lives at MASK_SCALE of the world's resolution — a 2400x1800 zone
## costs ~1MB rather than ~17MB — and the edge is still crisp because the
## shader thresholds per world pixel, not per mask texel. See the shader.
##
## It is saved INSIDE the zone scene as a PNG blob (mask_png below), the same
## way the markers are baked into it: no second file to keep in sync, no import
## step, and the editor's ordinary "save the scene" already covers it.

## Mask pixels per world pixel. Halving it costs a little brush precision and
## quarters the memory; the shader's per-world-pixel threshold means it does
## NOT cost edge sharpness.
const MASK_SCALE := 0.5

const SHADER_PATH := "res://assets/shaders/painted_ground.gdshader"
const TILES_DIR := "res://assets/world/decor/plains/tiles/"

## Brush id -> the seamless texture it paints with. These MUST tile against
## themselves: the shader repeats them across the whole zone, so a texture with
## a border baked in would draw a grid of borders. validate_paint_layer.gd
## measures that rather than trusting this list (the road art turned out to be
## full of pieces that look seamless and are not — see RoadAutotiler).
## Curated BY EYE against a 3x3 render (tools/paint_screenshot.tscn's sampler),
## not by the seam number alone — see validate_paint_layer.gd, where the
## automated check is honest about being a smoke test. The brick here scores
## terribly on a naive seam metric and tiles perfectly; a shore tile scores
## well and is a stripe, not a ground.
const ROADS_DIR := "res://assets/world/roads/"
const TEXTURES := {
	"tierra": TILES_DIR + "tierra_05.png",
	"pasto": TILES_DIR + "pasto_01.png",
	"agua": TILES_DIR + "estanque_05.png",
	"adoquin": ROADS_DIR + "adoquin_02.png",
	"ladrillo": ROADS_DIR + "ladrillo_12.png",
	"piedra": ROADS_DIR + "piedra_20.png",
	"losa": ROADS_DIR + "losa_29.png",
	"madera": ROADS_DIR + "madera_12.png",
}

## Palette ids are "paint_<texture>".
const ID_PREFIX := "paint_"

## The zone this covers, in world pixels. Setting it (re)allocates the mask.
@export var world_size: Vector2 = Vector2(2400, 1800):
	set(value):
		world_size = value
		_rebuild()

## Which of TEXTURES this layer draws. One layer per texture — two dirt
## patches share a mask, dirt and grass do not.
@export var texture_id: String = "tierra":
	set(value):
		texture_id = value
		_rebuild()

## The coverage mask, PNG-encoded, as it is saved into the zone scene. Read
## back into _mask on load. Empty until something is painted.
@export var mask_png: PackedByteArray = PackedByteArray():
	set(value):
		mask_png = value
		if not _writing_back:
			_load_mask_png()

## True only while _notification() is writing the mask back for a save, so the
## mask_png setter does not immediately decode what it just encoded.
var _writing_back := false
var _mask: Image = null
var _mask_texture: ImageTexture = null
## Whole-mask copy taken when a stroke starts, cropped to the stroke's dirty
## rect when it ends — see begin_stroke(). Only ever one alive at a time.
var _stroke_backup: Image = null
var _stroke_rect := Rect2i()
## Round falloff stamps, keyed by radius — rebuilding one per motion event
## showed up immediately while dragging.
var _stamps: Dictionary = {}


static func palette_id(texture_id_: String) -> String:
	return ID_PREFIX + texture_id_


static func is_paint_id(kind: String) -> bool:
	return kind.begins_with(ID_PREFIX) and TEXTURES.has(kind.trim_prefix(ID_PREFIX))


static func texture_of(kind: String) -> String:
	return kind.trim_prefix(ID_PREFIX)


static func texture_path(texture_id_: String) -> String:
	return str(TEXTURES.get(texture_id_, ""))


## Brush radius in WORLD pixels for Game.build_brush_size, so the free brush
## rides the [ and ] keys the grid brushes already use instead of adding a
## second size control. Half a cell per step: 16px at 1, 96px at 6.
static func radius_for(brush_size: int) -> float:
	return maxf(1.0, float(brush_size) * BuildGrid.TILE_SIZE * 0.5)


func _init() -> void:
	centered = false
	# LINEAR so the half-resolution mask reads as smooth coverage; the shader
	# is what turns that back into a crisp edge.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _ready() -> void:
	_rebuild()


## The mask lives in an Image while painting and only becomes bytes when the
## scene is written — encoding it on every dab would be absurd, and leaving it
## unencoded would lose the stroke. Godot sends this right before it writes
## the .tscn, which is exactly the moment to fold it back in.
func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_writing_back = true
		mask_png = encode_mask()
		_writing_back = false


func _mask_size() -> Vector2i:
	return Vector2i(maxi(1, int(world_size.x * MASK_SCALE)),
		maxi(1, int(world_size.y * MASK_SCALE)))


func _rebuild() -> void:
	if _mask != null and _mask.get_size() != _mask_size():
		# Keep whatever is already painted when the zone is resized.
		var wanted := _mask_size()
		var fresh := Image.create(wanted.x, wanted.y, false, Image.FORMAT_RGBA8)
		fresh.fill(Color(1, 1, 1, 0))
		fresh.blit_rect(_mask, Rect2i(Vector2i.ZERO, _mask.get_size().min(wanted)), Vector2i.ZERO)
		_mask = fresh
		_mask_texture = ImageTexture.create_from_image(_mask)
	texture = _mask_texture
	# One mask pixel covers 1/MASK_SCALE world pixels.
	scale = Vector2.ONE / MASK_SCALE
	position = -world_size * 0.5
	_apply_material()


## The mask is only allocated once something is actually painted into it.
##
## There is one layer per texture in TEXTURES and a zone builds them all up
## front, so eager allocation meant every zone paid for every brush whether or
## not it used it — eight brushes at 1200x900 RGBA8 is ~34MB of masks for a
## map that might have one dirt path on it. An unpainted layer now costs a
## node and nothing else, and a Sprite2D with no texture draws nothing.
func _ensure_mask() -> void:
	if _mask != null:
		return
	var size := _mask_size()
	_mask = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	_mask.fill(Color(1, 1, 1, 0))
	_mask_texture = ImageTexture.create_from_image(_mask)
	texture = _mask_texture


func _apply_material() -> void:
	var shader: Resource = load(SHADER_PATH)
	if not (shader is Shader):
		push_warning("[PaintLayer] missing %s — the layer will draw the raw mask." % SHADER_PATH)
		return
	var mat := material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		material = mat
	mat.shader = shader
	var path := texture_path(texture_id)
	if ResourceLoader.exists(path):
		mat.set_shader_parameter("ground", load(path))
	else:
		push_warning("[PaintLayer] unknown paint texture '%s'." % texture_id)
	mat.set_shader_parameter("world_size", world_size)
	mat.set_shader_parameter("ground_tile_px", float(BuildGrid.TILE_SIZE))


## World position -> mask pixel.
func to_mask(world_pos: Vector2) -> Vector2i:
	var local := world_pos - position
	return Vector2i(local * MASK_SCALE)


## True when anything at all has been painted — used to skip saving an empty
## mask into the zone scene.
func is_empty() -> bool:
	if _mask == null:
		return true
	return _mask.get_used_rect().size == Vector2i.ZERO


## Opens an undoable stroke. Everything painted until end_stroke() counts as
## one step, matching how a drag of the grid brushes folds into one undo.
func begin_stroke() -> void:
	# Allocated here rather than left null: end_stroke() needs a "before" to
	# hand to undo even for the first stroke on an untouched layer.
	_ensure_mask()
	_stroke_backup = _mask.duplicate()
	_stroke_rect = Rect2i()


## Closes the stroke and returns {"rect", "before"} to hand to the undo stack,
## or an empty Dictionary when nothing was actually painted. Only the dirty
## rect is kept, so an undo step costs the size of the stroke rather than the
## size of the zone.
func end_stroke() -> Dictionary:
	var backup := _stroke_backup
	_stroke_backup = null
	if backup == null or _stroke_rect.size == Vector2i.ZERO:
		return {}
	return {"rect": _stroke_rect, "before": backup.get_region(_stroke_rect)}


## Coverage at a world position, 0..1 — what the shader thresholds. Public so
## tests can read the mask back without reaching into it.
func coverage_at(world_pos: Vector2) -> float:
	if _mask == null:
		return 0.0
	var at := to_mask(world_pos)
	if not Rect2i(Vector2i.ZERO, _mask.get_size()).has_point(at):
		return 0.0
	return _mask.get_pixel(at.x, at.y).a


## A copy of one region of the mask — the "after" half of an editor undo
## step (see the plugin's _end_paint_stroke()).
func region(rect: Rect2i) -> Image:
	if _mask == null:
		return null
	return _mask.get_region(rect)


## Puts a region back, for undo.
func restore(rect: Rect2i, before: Image) -> void:
	if _mask == null or before == null:
		return
	_mask.blit_rect(before, Rect2i(Vector2i.ZERO, before.get_size()), rect.position)
	_mask_texture.update(_mask)


## Paints (or erases) a round dab centred on `world_pos`. `radius` is in WORLD
## pixels; `hardness` is the fraction of the radius that stays fully covered
## before the falloff starts.
func paint(world_pos: Vector2, radius: float, erase: bool, hardness: float = 0.55) -> void:
	if erase and _mask == null:
		return # nothing painted yet, so nothing to take away
	_ensure_mask()
	var mask_radius := maxi(1, int(radius * MASK_SCALE))
	var stamp := _stamp(mask_radius, hardness)
	var size := mask_radius * 2 + 1
	var at := to_mask(world_pos) - Vector2i(mask_radius, mask_radius)
	var area := Rect2i(at, Vector2i(size, size)).intersection(
		Rect2i(Vector2i.ZERO, _mask.get_size()))
	if area.size.x <= 0 or area.size.y <= 0:
		return

	# MAX, not alpha-over. Image.blend_rect() would be the fast C++ path, but
	# it composites, and a drag lays down hundreds of overlapping dabs: even a
	# 0.1-coverage edge pixel hit twenty times saturates to ~0.9, which
	# flattens the brush's falloff into a hard circle. The whole ragged edge
	# depends on that falloff surviving, so coverage takes the strongest dab
	# that touched it instead of accumulating. Cost is bounded to the dab.
	var region := _mask.get_region(area)
	var from := area.position - at
	for y in area.size.y:
		for x in area.size.x:
			var dab: float = stamp.get_pixel(from.x + x, from.y + y).a
			if dab <= 0.0:
				continue
			var had: float = region.get_pixel(x, y).a
			var now: float = maxf(0.0, had - dab) if erase else maxf(had, dab)
			region.set_pixel(x, y, Color(1, 1, 1, now))
	_mask.blit_rect(region, Rect2i(Vector2i.ZERO, area.size), area.position)

	_mask_texture.update(_mask)
	_stroke_rect = area if _stroke_rect.size == Vector2i.ZERO else _stroke_rect.merge(area)


## A white dab whose ALPHA is the falloff — that is the coverage the shader
## thresholds, so the brush's softness is what decides how ragged the edge is.
func _stamp(mask_radius: int, hardness: float) -> Image:
	var key := "%d#%.2f" % [mask_radius, hardness]
	if _stamps.has(key):
		return _stamps[key]
	var size := mask_radius * 2 + 1
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var solid := maxf(0.001, float(mask_radius) * clampf(hardness, 0.0, 0.99))
	for y in size:
		for x in size:
			var d := Vector2(x - mask_radius, y - mask_radius).length()
			if d > float(mask_radius):
				continue
			var a := 1.0 if d <= solid else 1.0 - (d - solid) / (float(mask_radius) - solid)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_stamps[key] = img
	return img


## PNG bytes of the current mask, for saving into the zone scene. Empty when
## nothing is painted, so an untouched layer adds nothing to the .tscn.
func encode_mask() -> PackedByteArray:
	if _mask == null or is_empty():
		return PackedByteArray()
	return _mask.save_png_to_buffer()


func _load_mask_png() -> void:
	if mask_png.is_empty():
		return
	var img := Image.new()
	if img.load_png_from_buffer(mask_png) != OK:
		push_warning("[PaintLayer] could not decode the saved mask.")
		return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	_mask = img
	_mask_texture = ImageTexture.create_from_image(_mask)
	texture = _mask_texture

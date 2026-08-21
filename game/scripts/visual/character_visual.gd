class_name CharacterVisual
extends Node2D
## The character's whole presentation layer, composed as an LPC paperdoll.
##
## It owns: which animation is playing, which frame it is on, which direction is
## shown, and the stack of layers that make up the character. It owns none of
## the simulation: it never reads input, never touches physics, never decides a
## direction. The owner (player.gd) tells it what the simulation already decided:
##
##     visual.set_direction(facing_dir)      # resolved by CharacterFacing
##     visual.play(&"attack", true, 0.36)    # 0.36s = the real gameplay window
##     visual.set_equipment("armor", "iron_armor")
##
## ONE AUTHORITATIVE CLOCK
## There is a single (animation, direction, frame) triple and every layer is
## written from it in the same pass, so a helmet can never lag a frame behind
## the head wearing it.
##
## LAYERS ARE DYNAMIC
## Unlike a fixed body/armour/weapon stack, LPC pieces declare their own zPos,
## and one piece can contribute several layers at different depths (a sword
## draws partly behind the body and partly in front of it). So the stack is
## rebuilt per animation from the data and sorted by zPos; the sprite nodes are
## just a pool. Nothing here hardcodes a draw order.
##
## The frame NEVER drives gameplay. Damage, hitbox windows and i-frames are
## time-based in player.gd and know nothing about this node — see
## docs/ARQUITECTURA.md.

## Sprite pool size. LPC's heaviest combination (full armour plus a weapon that
## splits front/back) sits well under this.
const MAX_LAYERS := 24

## Drawn above every composed layer and never touched by composition: hit flash,
## buffs, poison, selection rings, auras.
const EFFECTS_Z := 1000

## Equipment slots this character composes, matching Player.get_visual_loadout().
const SLOTS := ["armor", "legs", "feet", "arms", "gloves", "shoulders",
		"wrists", "helmet", "weapon", "secondary"]

signal animation_finished(anim: StringName)

## Per-animation FPS and end behaviour. Frame COUNTS come from the art itself.
@export var visual_set: CharacterVisualSet

## LPC piece keys that make up the naked character.
@export var body_piece: String = "body/Body Color"
@export var head_piece: String = "head/Human Male"
@export var hair_piece: String = "hair/Spiked"

## Shifts the art so the character's feet land where it actually stands. LPC
## frames put the feet near the bottom of the 64px box.
@export var feet_offset: Vector2 = Vector2(0, -8)

@export var autoplay: StringName = &"idle"

var _sprites: Array[Sprite2D] = []
var _effects: Sprite2D = null
var _equipment: Dictionary = {}

var _dir: CharacterFacing.Direction = CharacterFacing.Direction.SOUTH
var _anim_id: StringName = &""
var _anim: CharacterAnimation = null
var _time: float = 0.0
var _frame: int = 0
var _frame_count: int = 1
var _speed_scale: float = 1.0
var _duration: float = 0.0
var _finished_emitted: bool = false
var _tint: Color = Color.WHITE
var _last_key: String = ""


func _ready() -> void:
	_build_pool()
	LpcLibrary.load_index()
	if visual_set == null:
		push_error("[CharacterVisual] no visual_set assigned on %s" % get_path())
		return
	play(autoplay, true)


func _process(delta: float) -> void:
	if _anim == null:
		return
	_time += delta * _speed_scale
	var count: int = maxi(1, _frame_count)
	var raw := int(_time * _anim.fps)
	var next := _frame
	match _anim.finish:
		CharacterAnimation.Finish.LOOP:
			if raw >= count and _anim.fps > 0.0:
				_time = fmod(_time, float(count) / _anim.fps)
				raw = int(_time * _anim.fps)
			next = raw % count
		CharacterAnimation.Finish.HOLD_LAST:
			next = mini(raw, count - 1)
			if raw >= count:
				_emit_finished_once()
		CharacterAnimation.Finish.RETURN_TO_IDLE:
			if raw >= count:
				_emit_finished_once()
				play(visual_set.fallback_animation, true)
				return
			next = raw
	if next != _frame:
		_frame = next
	_refresh()


# ---------------------------------------------------------------- public API


## Set the logical direction. Resolved by gameplay (CharacterFacing) and handed
## down — this node never derives it from a vector, so the sprite and the
## simulation can never disagree about which way the character faces.
func set_direction(d: CharacterFacing.Direction) -> void:
	if d == _dir:
		return
	_dir = d
	_invalidate()


func get_direction() -> CharacterFacing.Direction:
	return _dir


## Play an animation.
## restart  - force it back to frame 0 even if it is already playing.
## duration - the real gameplay window in seconds this has to fit into (attack
##            window, dodge duration...). Playback speed is scaled to match.
##            0 keeps the authored FPS.
func play(anim_id: StringName, restart: bool = false, duration: float = 0.0) -> void:
	if visual_set == null:
		return
	var anim := visual_set.resolve_animation(anim_id)
	if anim == null:
		push_error("[CharacterVisual] unknown animation '%s' and no fallback" % anim_id)
		return
	if anim.id == _anim_id and not restart:
		_duration = duration
		_sync_timeline()
		return
	_anim_id = anim.id
	_anim = anim
	_duration = duration
	_time = 0.0
	_frame = 0
	_finished_emitted = false
	_sync_timeline()
	_invalidate()


func get_animation_id() -> StringName:
	return _anim_id


func get_frame() -> int:
	return _frame


func get_frame_count() -> int:
	return _frame_count


## Jump to a specific frame and hold it. For tools and paused inspection.
func seek_frame(index: int) -> void:
	if _anim == null:
		return
	_frame = clampi(index, 0, _frame_count - 1)
	_time = float(_frame) / maxf(_anim.fps, 0.001)
	_invalidate()


## Show a piece of equipment in a slot, or clear it with "".
## visual_state is the item key from ItemDB; LpcEquipment maps it to an LPC
## piece. An item with no mapping simply draws nothing.
func set_equipment(slot: String, visual_state: String) -> void:
	var piece_key := LpcEquipment.piece_for(slot, visual_state)
	if str(_equipment.get(slot, "")) == piece_key:
		return
	_equipment[slot] = piece_key
	_invalidate()


func get_equipment_piece(slot: String) -> String:
	return str(_equipment.get(slot, ""))


## Swap the naked character underneath the gear (character creator, races...).
func set_appearance(body: String, head: String, hair: String) -> void:
	body_piece = body
	head_piece = head
	hair_piece = hair
	_sync_timeline()
	_invalidate()


## Tint the character. Deliberately does not touch the effects layer, whose own
## colours must survive.
func set_tint(c: Color) -> void:
	if c == _tint:
		return
	_tint = c
	for s in _sprites:
		s.modulate = c


## The Sprite2D other systems can hang status/aura visuals on.
func get_effects_layer() -> Sprite2D:
	return _effects


# ------------------------------------------------------------------ internal


func _build_pool() -> void:
	for i in MAX_LAYERS:
		var s := Sprite2D.new()
		s.name = "Layer%02d" % i
		s.centered = true
		s.offset = feet_offset
		s.visible = false
		add_child(s)
		_sprites.append(s)
	_effects = Sprite2D.new()
	_effects.name = "Effects"
	_effects.centered = true
	_effects.offset = feet_offset
	_effects.z_index = EFFECTS_Z
	_effects.visible = false
	add_child(_effects)


## Every piece that makes up the character right now. Order does not matter —
## the layers carry their own zPos.
##
## Hair is dropped while a helmet is on: LPC hair is drawn to sit on a bare
## head, so under a helm it pokes straight through the metal.
func _active_pieces() -> Array:
	var out: Array = [body_piece, head_piece]
	if not _helmet_hides_hair():
		out.append(hair_piece)
	for slot in SLOTS:
		var key := str(_equipment.get(slot, ""))
		if key != "" and not LpcEquipment.is_hidden_on_body(key):
			out.append(key)
	return out


func _helmet_hides_hair() -> bool:
	return str(_equipment.get("helmet", "")) != ""


## The body defines the timeline; every other layer follows it.
func _sync_timeline() -> void:
	if _anim == null:
		return
	var count := LpcLibrary.frame_count(body_piece, _anim_id)
	_frame_count = maxi(1, count if count > 0 else _anim.frame_count)
	_speed_scale = 1.0
	if _duration > 0.0:
		var nominal := _anim.nominal_duration(_frame_count)
		if nominal > 0.0:
			_speed_scale = nominal / _duration
	if _frame >= _frame_count:
		_frame = _frame_count - 1


## Force the next _refresh() to redraw. Needed when something other than
## (animation, direction, frame) changed — swapping gear does not move the
## clock, so without this the new art would not appear until the next tick, and
## never at all while idle.
func _invalidate() -> void:
	_last_key = ""
	_refresh()


## Writes every layer from the single (animation, direction, frame) triple.
func _refresh() -> void:
	if _anim == null or _sprites.is_empty():
		return
	var key := "%s|%d|%d|%d" % [_anim_id, _dir, _frame, _equipment.hash()]
	if key == _last_key:
		return
	_last_key = key

	var layers: Array = []
	for piece_key in _active_pieces():
		for layer in LpcLibrary.layers_for(piece_key, _anim_id):
			layers.append(layer)
	layers.sort_custom(func(a, b): return int(a.get("z", 0)) < int(b.get("z", 0)))

	var used := 0
	for layer in layers:
		if used >= MAX_LAYERS:
			push_warning("[CharacterVisual] over %d layers; raise MAX_LAYERS" % MAX_LAYERS)
			break
		var tex := LpcLibrary.frame_texture(layer, _dir, _frame)
		if tex == null:
			continue
		var s := _sprites[used]
		s.texture = tex
		s.z_index = int(layer.get("z", 0))
		s.modulate = _tint
		s.visible = true
		used += 1
	for i in range(used, MAX_LAYERS):
		_sprites[i].texture = null
		_sprites[i].visible = false


func _emit_finished_once() -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	animation_finished.emit(_anim_id)

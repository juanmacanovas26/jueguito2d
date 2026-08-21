class_name SkillSlot
extends Control
## One skill's slot in the bar: icon, radial cooldown sweep, countdown number,
## bound key, and a border that echoes SkillAimer's cyan "LoL UI" language so
## the bar and the in-world aim preview read as the same system.

const SIZE := 48
## Cached once — a plain filled disc used as every slot's radial-fill mask.
static var _disc_tex: Texture2D = null

@onready var _icon: TextureRect = $Icon
@onready var _cooldown: TextureProgressBar = $CooldownOverlay
@onready var _count: Label = $CountLabel
@onready var _key: Label = $KeyLabel
@onready var _border: Control = $Border

var skill_id: String = ""
var _was_ready: bool = true
var _armed: bool = false
var _flash_tween: Tween = null
var _glow_tween: Tween = null


func _ready() -> void:
	if _cooldown:
		_cooldown.texture_progress = _get_disc_tex()
		_cooldown.max_value = 1.0
		# Range's default step is 1.0 — with max_value 1.0 that would round every
		# fractional cooldown ratio to 0 or 1, so the sweep only ever shows fully
		# covered or fully clear. 0 turns off step-snapping entirely.
		_cooldown.step = 0.0
		_cooldown.fill_mode = TextureProgressBar.FILL_CLOCKWISE
		_cooldown.self_modulate = Color(0, 0, 0, 0.72)
	_border.draw.connect(_on_border_draw)


func setup(id: String, key_label: String) -> void:
	skill_id = id
	_icon.texture = SkillIcons.get_icon(id)
	_key.text = key_label
	_was_ready = true
	_set_armed(false)


func update(caster: SkillCaster, aimer: SkillAimer) -> void:
	if skill_id == "" or caster == null:
		return
	var total := maxf(0.01, float(SkillDB.get_skill(skill_id).get("cooldown", 1.0)))
	var left := caster.cooldown_left(skill_id)
	if _cooldown:
		_cooldown.value = clampf(left / total, 0.0, 1.0)
	var show_count := left > 0.3
	if _count:
		_count.visible = show_count
		if show_count:
			_count.text = str(ceili(left))

	var ready := caster.is_ready(skill_id)
	if ready and not _was_ready:
		_flash_ready()
	_was_ready = ready

	var armed := aimer != null and aimer.is_aiming() and aimer.current_skill() == skill_id
	if armed != _armed:
		_set_armed(armed)


func _set_armed(on: bool) -> void:
	_armed = on
	if _glow_tween:
		_glow_tween.kill()
		_glow_tween = null
	if on:
		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_property(_border, "modulate:a", 0.55, 0.5)
		_glow_tween.tween_property(_border, "modulate:a", 1.0, 0.5)
	else:
		_border.modulate.a = 1.0
	_border.queue_redraw()


func _flash_ready() -> void:
	if _flash_tween:
		_flash_tween.kill()
	scale = Vector2(1.18, 1.18)
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)


func _on_border_draw() -> void:
	var ring: Color = SkillAimer.RETICLE_COLOR
	var r := Rect2(1.0, 1.0, SIZE - 2.0, SIZE - 2.0)
	if _armed:
		_border.draw_rect(r.grow(2.0), Color(ring.r, ring.g, ring.b, 0.20), true)
		_border.draw_rect(r, Color(ring.r, ring.g, ring.b, 0.95), false, 2.5)
		_border.draw_rect(r.grow(-3.0), Color(ring.r, ring.g, ring.b, 0.5), false, 1.0)
	else:
		_border.draw_rect(r, Color(ring.r, ring.g, ring.b, 0.35), false, 1.5)


static func _get_disc_tex() -> Texture2D:
	if _disc_tex:
		return _disc_tex
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := SIZE / 2
	for dy in range(-r, r):
		for dx in range(-r, r):
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(r + dx, r + dy, Color.WHITE)
	_disc_tex = ImageTexture.create_from_image(img)
	return _disc_tex

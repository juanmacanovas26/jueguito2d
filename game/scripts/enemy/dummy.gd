extends CharacterBody2D

@onready var body: Polygon2D = $Body
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health: Health = $Health
@onready var hp_label: Label = $HpLabel
@onready var flash_timer: Timer = $FlashTimer

var _base_color := Color(0.75, 0.35, 0.4)
var _dps_window: float = 0.0
var _dps_damage: float = 0.0
var _last_dps: float = 0.0


func _ready() -> void:
	health.max_hp = 500.0
	health.hp = 500.0
	hurtbox.setup(health, &"enemy")
	hurtbox.collision_layer = 1 << 2
	hurtbox.collision_mask = 0
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.health_changed.connect(_on_hp)
	flash_timer.one_shot = true
	flash_timer.timeout.connect(_on_flash_end)
	_on_hp(health.hp, health.max_hp)


func _physics_process(delta: float) -> void:
	if _dps_window > 0.0:
		_dps_window -= delta
		if _dps_window <= 0.0:
			_last_dps = _dps_damage / 3.0
			_dps_damage = 0.0
			_refresh_label()


func _on_damaged(amount: float, _current: float) -> void:
	body.color = Color(1, 1, 1)
	flash_timer.start(0.08)
	_dps_window = 3.0
	_dps_damage += amount
	_refresh_label()


func _on_flash_end() -> void:
	if not health.is_dead:
		body.color = _base_color


func _on_died() -> void:
	body.color = Color(0.25, 0.2, 0.22)
	hp_label.text = "DEAD — R to reset"
	await get_tree().create_timer(1.2).timeout
	_reset()


func _on_hp(_current: float, _maximum: float) -> void:
	_refresh_label()


func _refresh_label() -> void:
	if health.is_dead:
		return
	var dps_txt := ""
	if _dps_window > 0.0:
		dps_txt = " | hit-sum: %.0f" % _dps_damage
	elif _last_dps > 0.0:
		dps_txt = " | ~DPS: %.1f" % _last_dps
	hp_label.text = "Dummy %.0f/%.0f%s" % [health.hp, health.max_hp, dps_txt]


func _reset() -> void:
	health.is_dead = false
	health.hp = health.max_hp
	health.poise = health.max_poise
	body.color = _base_color
	_dps_damage = 0.0
	_dps_window = 0.0
	health.health_changed.emit(health.hp, health.max_hp)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_reset()

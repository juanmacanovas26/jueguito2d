extends CharacterBody2D
## Dummy that periodically swings at the player so you can test block/parry/energy.

@onready var body: Polygon2D = $Body
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Facing/Hitbox
@onready var facing: Node2D = $Facing
@onready var health: Health = $Health
@onready var hp_label: Label = $HpLabel
@onready var flash_timer: Timer = $FlashTimer
@onready var attack_timer: Timer = $AttackTimer

var _base_color := Color(0.75, 0.35, 0.4)
var _attacking := false
var _attack_t := 0.0
const ATK_START := 0.35
const ATK_ACTIVE := 0.12
const ATK_RECOVERY := 0.40
const RANGE := 48.0


func _ready() -> void:
	health.max_hp = 500.0
	health.hp = 500.0
	hurtbox.setup(health, &"enemy")
	hurtbox.collision_layer = 1 << 2
	hitbox.configure(&"enemy", 14.0, 8.0, 0.0)
	hitbox.owner = self
	hitbox.begin_swing()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	flash_timer.one_shot = true
	flash_timer.timeout.connect(_on_flash_end)
	attack_timer.wait_time = 1.6
	attack_timer.timeout.connect(_try_start_attack)
	attack_timer.start()
	_refresh_label()


func _physics_process(delta: float) -> void:
	var p := Game.get_local_player()
	if p == null or not (p is Node2D):
		return
	var dir := ((p as Node2D).global_position - global_position)
	if dir.length_squared() > 1.0:
		facing.rotation = dir.angle()

	if not _attacking:
		return

	_attack_t += delta
	if _attack_t < ATK_START:
		hitbox.deactivate()
		body.color = Color(0.9, 0.5, 0.3)
	elif _attack_t < ATK_START + ATK_ACTIVE:
		if not hitbox._active:
			hitbox.begin_swing()
			hitbox.activate()
		body.color = Color(1.0, 0.3, 0.2)
	elif _attack_t < ATK_START + ATK_ACTIVE + ATK_RECOVERY:
		hitbox.deactivate()
		body.color = Color(0.6, 0.3, 0.3)
	else:
		_attacking = false
		hitbox.deactivate()
		body.color = _base_color


func _try_start_attack() -> void:
	if health.is_dead or _attacking:
		return
	var p := Game.get_local_player()
	if p == null or not (p is Node2D):
		return
	if global_position.distance_to((p as Node2D).global_position) > RANGE:
		return
	_attacking = true
	_attack_t = 0.0
	hitbox.configure(&"enemy", 14.0, 8.0, 0.0)
	hitbox.owner = self
	hitbox.begin_swing()


func _on_damaged(amount: float, _current: float) -> void:
	body.color = Color(1, 1, 1)
	flash_timer.start(0.08)
	_refresh_label()
	hp_label.text += "  -%.0f" % amount


func _on_flash_end() -> void:
	if not health.is_dead and not _attacking:
		body.color = _base_color


func _on_died() -> void:
	body.color = Color(0.25, 0.2, 0.22)
	hp_label.text = "DEAD — R reset"
	_attacking = false
	hitbox.deactivate()
	await get_tree().create_timer(1.2).timeout
	_reset()


func _refresh_label() -> void:
	if health.is_dead:
		return
	hp_label.text = "Trainer %.0f/%.0f (attacks you)" % [health.hp, health.max_hp]


func _reset() -> void:
	health.is_dead = false
	health.hp = health.max_hp
	health.poise = health.max_poise
	body.color = _base_color
	_attacking = false
	health.health_changed.emit(health.hp, health.max_hp)
	_refresh_label()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_reset()

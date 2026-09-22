extends CharacterBody2D
## Grind mob: idle → chase → attack → die → xp + loot → respawn.
## Melee by default; set `ranged=true` for projectile attackers.

enum AIState { IDLE, CHASE, ATTACK, HURT, DEAD, RETURN }

@export var max_hp: float = 80.0
@export var move_speed: float = 119.0
@export var aggro_range: float = 220.0
@export var deaggro_range: float = 340.0
@export var attack_range: float = 70.0
@export var attack_damage: float = 12.0
@export var attack_cooldown: float = 0.85
@export var respawn_time: float = 4.0
@export var leash_range: float = 420.0
@export var skill_gain: int = 18
@export var gold_min: int = 1
@export var gold_max: int = 4
@export var ranged: bool = false
@export var projectile_damage: float = 10.0
@export var projectile_speed: float = 300.0
## Past this distance from the player an IDLE mob sleeps: it stops running
## the state machine, move_and_slide() and its animation until the player
## comes back. Without it every mob in a zone costs a physics query every
## frame forever, which is what actually caps how big a zone can be — the
## tile count never does (see docs/GDD.md).
##
## Only ever applied while IDLE and standing on its home spot, so a mob can
## never freeze mid-chase far from where it belongs. Clamped at runtime to
## stay well outside deaggro_range, otherwise a mob could fall asleep at a
## distance where it is still supposed to notice the player.
@export var sleep_range: float = 900.0
@export var body_color: Color = Color(1, 1, 1) # multiply tint on the sprite; white = show art as-is
## Drop table: Array of { id, chance 0..1, min, max }
@export var drop_table: Array = [
	{"id": "slime_goo", "chance": 0.65, "min": 1, "max": 2},
	{"id": "health_herb", "chance": 0.22, "min": 1, "max": 2},
	{"id": "mana_potion", "chance": 0.15, "min": 1, "max": 1},
	{"id": "rusty_blade", "chance": 0.08, "min": 1, "max": 1},
	{"id": "mana_dust", "chance": 0.12, "min": 1, "max": 1},
	{"id": "iron_sword", "chance": 0.03, "min": 1, "max": 1},
	{"id": "oak_staff", "chance": 0.03, "min": 1, "max": 1},
	{"id": "leather_armor", "chance": 0.10, "min": 1, "max": 1},
	{"id": "wooden_shield", "chance": 0.08, "min": 1, "max": 1},
	{"id": "apprentice_tome", "chance": 0.08, "min": 1, "max": 1},
	{"id": "iron_armor", "chance": 0.03, "min": 1, "max": 1},
	{"id": "iron_helmet", "chance": 0.03, "min": 1, "max": 1},
]

const ATK_START := 0.5
const ATK_ACTIVE := 0.10
const ATK_RECOVERY := 0.36
const HURT_TIME := 0.18
## How often a sleeping mob re-checks the player's distance, in physics
## frames. At 60 fps that's ~7 checks a second; the player covers ~27px
## between checks, so with sleep_range hundreds of px outside aggro_range
## there is no way to sneak up on a sleeping mob.
const WAKE_CHECK_FRAMES := 8
const ACCEL := 900.0
const FRICTION := 1200.0
const LUNGE_SPEED := 400.0

const LootDropScene := preload("res://scenes/world/loot_drop.tscn")
const ProjectileScene := preload("res://scenes/combat/projectile.tscn")

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Facing/Hitbox
@onready var facing: Node2D = $Facing
@onready var health: Health = $Health
@onready var hp_label: Label = $HpLabel
@onready var flash_timer: Timer = $FlashTimer

var ai: AIState = AIState.IDLE
var _home: Vector2 = Vector2.ZERO
var _base_color := Color(1, 1, 1)
var _attack_t := 0.0
var _cd := 0.0
var _hurt_t := 0.0
var _hitbox_on := false
var _projectile_spawned := false
var _last_attacker: Node = null
## True while this mob is skipping its per-frame work (see sleep_range).
var _asleep := false
## Physics frames left before the next wake check. Seeded to a per-mob
## random offset so a field of mobs spreads its checks across frames
## instead of every one of them testing on the same tick.
var _wake_countdown := 0


func _ready() -> void:
	_home = global_position
	_base_color = body_color
	sleep_range = maxf(sleep_range, maxf(deaggro_range, leash_range) + 200.0)
	_wake_countdown = randi() % WAKE_CHECK_FRAMES
	sprite.sprite_frames = MobSprites.build_slime()
	health.max_hp = max_hp
	health.hp = max_hp
	health.start_full = true
	hurtbox.setup(health, &"enemy")
	hurtbox.collision_layer = 1 << 2
	hitbox.configure(&"enemy", attack_damage, 6.0, 0.0)
	hitbox.owner = self
	hitbox.begin_swing()
	hitbox.deactivate()
	health.damaged.connect(_on_damaged)
	if health.has_signal("damaged_by"):
		health.damaged_by.connect(_on_damaged_by)
	health.died.connect(_on_died)
	flash_timer.one_shot = true
	flash_timer.timeout.connect(_on_flash_end)
	_refresh_label()
	_set_idle_visual()


func _process(_delta: float) -> void:
	# Pure presentation: read `facing` (set by the AI below), never write it.
	sprite.flip_h = cos(facing.rotation) < 0.0


func _physics_process(delta: float) -> void:
	if _asleep:
		_wake_countdown -= 1
		if _wake_countdown > 0:
			return
		_wake_countdown = WAKE_CHECK_FRAMES
		var near := _get_player()
		if near == null or global_position.distance_squared_to(near.global_position) > sleep_range * sleep_range:
			return
		_wake_up()

	_cd = maxf(0.0, _cd - delta)

	if ai == AIState.DEAD:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		move_and_slide()
		return

	if ai == AIState.HURT:
		_hurt_t -= delta
		# No freeze on basic hits: keep momentum (movement continues through flinch)
		move_and_slide()
		if _hurt_t <= 0.0:
			ai = AIState.CHASE
			_set_chase_visual()
		return

	if ai == AIState.ATTACK:
		_process_attack(delta)
		move_and_slide()
		return

	var player := _get_player()
	if player == null:
		_go_idle_or_return(delta)
		move_and_slide()
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var home_dist := global_position.distance_to(_home)

	if home_dist > leash_range:
		ai = AIState.RETURN

	match ai:
		AIState.IDLE:
			if dist <= aggro_range:
				ai = AIState.CHASE
				_set_chase_visual()
			else:
				velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
				# Standing still at home with the player far away: nothing
				# this mob does for the next few seconds can matter, so stop
				# paying for it. Requires being settled at home (not merely
				# IDLE) so it can never doze off somewhere it doesn't belong.
				if dist > sleep_range and home_dist <= 16.0 and velocity.is_zero_approx():
					_fall_asleep()
					return
		AIState.CHASE:
			if dist > deaggro_range or home_dist > leash_range:
				ai = AIState.RETURN
			elif dist <= attack_range and _cd <= 0.0:
				_start_attack(to_player)
			else:
				_chase(to_player, delta)
		AIState.RETURN:
			if dist <= aggro_range * 0.7 and home_dist < leash_range * 0.85:
				ai = AIState.CHASE
				_set_chase_visual()
			elif global_position.distance_to(_home) < 12.0:
				global_position = _home
				velocity = Vector2.ZERO
				ai = AIState.IDLE
				_set_idle_visual()
			else:
				var to_home := (_home - global_position).normalized()
				facing.rotation = to_home.angle()
				velocity = velocity.move_toward(to_home * move_speed * 0.9, ACCEL * delta)
				sprite.modulate = _base_color
				sprite.play(&"walk")

	move_and_slide()
	_refresh_label()


## Stops everything a far-away idle mob was paying for every frame: the
## physics query in move_and_slide(), the sprite's animation stepping, and
## _process()'s facing flip. Deliberately does NOT hide the mob or touch its
## collision — it stays solid and hittable, so a stray projectile or an AoE
## still lands on it exactly as before.
func _fall_asleep() -> void:
	if _asleep:
		return
	_asleep = true
	velocity = Vector2.ZERO
	sprite.stop()
	set_process(false)
	_wake_countdown = WAKE_CHECK_FRAMES


func _wake_up() -> void:
	if not _asleep:
		return
	_asleep = false
	set_process(true)
	_set_idle_visual()


## Anything that damages a sleeping mob has to wake it first, or it would
## take the hit and go on standing there — a ranged attack from beyond
## sleep_range is the obvious way to hit one (see _on_damaged()).
func _wake_if_asleep() -> void:
	if _asleep:
		_wake_up()


func _go_idle_or_return(delta: float) -> void:
	if global_position.distance_to(_home) > 16.0:
		ai = AIState.RETURN
		var to_home := (_home - global_position).normalized()
		velocity = velocity.move_toward(to_home * move_speed * 0.9, ACCEL * delta)
	else:
		ai = AIState.IDLE
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		_set_idle_visual()


func _chase(to_player: Vector2, delta: float) -> void:
	if to_player.length_squared() < 0.01:
		return
	var dir := to_player.normalized()
	facing.rotation = dir.angle()
	if to_player.length() > attack_range * 0.75:
		velocity = velocity.move_toward(dir * move_speed, ACCEL * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	_set_chase_visual()


func _start_attack(to_player: Vector2) -> void:
	ai = AIState.ATTACK
	_attack_t = 0.0
	_hitbox_on = false
	_projectile_spawned = false
	velocity = Vector2.ZERO
	if to_player.length_squared() > 0.01:
		facing.rotation = to_player.angle()
	hitbox.configure(&"enemy", attack_damage, 6.0, 0.0)
	hitbox.owner = self
	hitbox.begin_swing()
	hitbox.deactivate()
	sprite.modulate = _base_color
	sprite.play(&"attack")


func _process_attack(delta: float) -> void:
	_attack_t += delta
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	if ranged:
		_process_ranged_attack()
		return

	if _attack_t < ATK_START:
		var p := _get_player()
		if p:
			var d := p.global_position - global_position
			if d.length_squared() > 1.0:
				facing.rotation = d.angle()
		hitbox.deactivate()
		_hitbox_on = false
	elif _attack_t < ATK_START + ATK_ACTIVE:
		if not _hitbox_on:
			hitbox.begin_swing()
			hitbox.activate()
			_hitbox_on = true
			velocity = Vector2.RIGHT.rotated(facing.rotation) * LUNGE_SPEED
	elif _attack_t < ATK_START + ATK_ACTIVE + ATK_RECOVERY:
		hitbox.deactivate()
		_hitbox_on = false
	else:
		hitbox.deactivate()
		_hitbox_on = false
		_cd = attack_cooldown
		ai = AIState.CHASE
		_set_chase_visual()


func _process_ranged_attack() -> void:
	var p := _get_player()
	if p and _attack_t < ATK_START:
		var d := p.global_position - global_position
		if d.length_squared() > 1.0:
			facing.rotation = d.angle()
	if _attack_t >= ATK_START and not _projectile_spawned:
		_projectile_spawned = true
		_shoot(p)
	if _attack_t >= ATK_START + ATK_RECOVERY:
		_cd = attack_cooldown
		ai = AIState.CHASE
		_set_chase_visual()


func _shoot(target: Node2D) -> void:
	var dir := Vector2.RIGHT
	if target:
		dir = (target.global_position - global_position).normalized()
	var proj = Game.spawn(ProjectileScene, global_position + dir * 16.0)
	proj.setup(dir, &"enemy", projectile_damage, 4.0, projectile_speed, 2.5, self, Color(1.0, 0.45, 0.3, 0.95), 4.0)


func _get_player() -> Node2D:
	var p := Game.get_local_player()
	if p == null or not (p is Node2D):
		return null
	if p.has_node("Health"):
		var h: Health = p.get_node("Health")
		if h.is_dead:
			return null
	return p


func _on_damaged_by(_amount: float, _current: float, source: Node) -> void:
	if source and source.is_in_group("player"):
		_last_attacker = source
	elif source and source.get_parent() and source.get_parent().is_in_group("player"):
		_last_attacker = source.get_parent()


func _on_damaged(_amount: float, _current: float) -> void:
	if ai == AIState.DEAD:
		return
	# Before anything else: a mob shot from outside sleep_range is asleep,
	# and would otherwise absorb the hit without ever starting to chase.
	_wake_if_asleep()
	if _last_attacker == null:
		_last_attacker = Game.get_local_player()

	sprite.modulate = Color(3, 3, 3) # overbright flash — (1,1,1) would be a no-op tint on a real texture
	flash_timer.start(0.07)
	if ai == AIState.IDLE or ai == AIState.RETURN:
		ai = AIState.CHASE
	# DESIGN RULE: a basic attack never interrupts. A mob hit mid-swing used to
	# have its hitbox killed and get knocked into HURT, so the player could
	# stunlock it out of every attack just by connecting first. The swing now
	# plays out; only the damage lands. See docs/COMBATE.md ("Interrupción").
	if ai != AIState.DEAD and ai != AIState.ATTACK:
		ai = AIState.HURT
		_hurt_t = HURT_TIME
	_refresh_label()


func _on_flash_end() -> void:
	if ai == AIState.DEAD or ai == AIState.HURT or ai == AIState.ATTACK:
		return
	if ai == AIState.CHASE:
		_set_chase_visual()
	elif ai == AIState.IDLE:
		_set_idle_visual()


func _on_died() -> void:
	# A mob killed outright while asleep (an AoE from off-screen) still has to
	# run its death/respawn sequence, which lives in _physics_process().
	_wake_if_asleep()
	ai = AIState.DEAD
	hitbox.deactivate()
	_hitbox_on = false
	velocity = Vector2.ZERO
	sprite.modulate = _base_color
	sprite.play(&"death")
	modulate.a = 0.55
	hp_label.text = "DEAD"
	set_collision_layer_value(3, false)
	hurtbox.collision_layer = 0

	_grant_rewards()
	_spawn_loot()

	await get_tree().create_timer(respawn_time).timeout
	_respawn()


func _grant_rewards() -> void:
	var target: Node = _last_attacker
	if target == null:
		target = _get_player()
	if target == null:
		return
	var sk: Skills = target.get_node_or_null("Skills") as Skills
	if sk:
		var skill_id := "heavy_swords"
		if target.has_method("combat_skill_id"):
			skill_id = target.combat_skill_id()
		sk.gain(skill_id, skill_gain)


func _spawn_loot() -> void:
	var parent := Game.get_world()
	if parent == null:
		return

	var gold_amt := randi_range(gold_min, gold_max)
	if gold_amt > 0:
		_spawn_one_drop(parent, "gold_coin", gold_amt, Vector2(randf_range(-4, 4), randf_range(-2, 2)))

	for entry in drop_table:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var chance := float(entry.get("chance", 0.0))
		if randf() > chance:
			continue
		var id := str(entry.get("id", ""))
		if id == "":
			continue
		var amin := int(entry.get("min", 1))
		var amax := int(entry.get("max", 1))
		var amt := randi_range(amin, amax)
		_spawn_one_drop(parent, id, amt, Vector2(randf_range(-5, 5), randf_range(-3, 3)))


func _spawn_one_drop(parent: Node, id: String, amt: int, offset: Vector2) -> void:
	var drop = Game.spawn(LootDropScene, global_position + offset, parent)
	if drop.has_method("setup"):
		drop.setup(id, amt)


func _respawn() -> void:
	global_position = _home
	health.is_dead = false
	health.hp = health.max_hp
	health.poise = health.max_poise
	ai = AIState.IDLE
	_cd = 0.5
	_last_attacker = null
	modulate.a = 1.0
	set_collision_layer_value(3, true)
	hurtbox.collision_layer = 1 << 2
	_set_idle_visual()
	health.health_changed.emit(health.hp, health.max_hp)
	_refresh_label()


func _set_idle_visual() -> void:
	sprite.modulate = _base_color
	sprite.play(&"idle")


func _set_chase_visual() -> void:
	sprite.modulate = _base_color
	sprite.play(&"walk")


func _refresh_label() -> void:
	if ai == AIState.DEAD:
		hp_label.text = "DEAD"
		return
	var st := ""
	match ai:
		AIState.IDLE: st = "idle"
		AIState.CHASE: st = "chase"
		AIState.ATTACK: st = "atk"
		AIState.HURT: st = "hurt"
		AIState.RETURN: st = "return"
	hp_label.text = "Mob %.0f  [%s]" % [health.hp, st]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if ai != AIState.DEAD:
			health.hp = health.max_hp
			health.health_changed.emit(health.hp, health.max_hp)
			_refresh_label()

extends CharacterBody2D

enum State { FREE, ATTACK, CHARGE, GUARD, DODGE, HURT, DEAD, CAST }
enum DefendStyle { SHIELD, PARRY, ENERGY }
enum Kit { WARRIOR, MAGE, ARCHER }

const MOVE_SPEED := 200.0
const SPRINT_MULT := 1.35
const ATTACK_MOVE_MULT := 0.92
const HEAVY_MOVE_MULT := 0.78
const CHARGE_MOVE_MULT := 0.85
const MAGE_ATTACK_MOVE_MULT := 0.88
const GUARD_MOVE_MULT := 0.55
const ACCEL := 1800.0
const FRICTION := 1600.0

const MAX_STAMINA := 100.0
const MAX_MANA := 100.0
const STAMINA_REGEN := 28.0
const MANA_REGEN := 16.0
const STAMINA_REGEN_DELAY := 0.55
const MANA_REGEN_DELAY := 0.35
const DODGE_COST := 28.0
const HEAVY_COST_MIN := 12.0
const HEAVY_COST_MAX := 22.0
const SPRINT_COST_PER_SEC := 18.0

## Testing aid: equipment dropped straight into the starting inventory so
## the equip flow can be tested without farming mobs for drops.
## Testing aid: the bag starts with one of EVERY item so the whole catalogue —
## and every LPC appearance — can be tried without farming. Built from ItemDB
## rather than a hand-kept list, so a new item shows up here automatically.
const DEBUG_GIVE_EVERYTHING := true

## Softcap of the armour formula (see defense_reduction). Lower = armour matters
## more. At 30, the full starting kit absorbs ~33% of incoming damage.
const DEFENSE_SOFTCAP := 30.0

const DODGE_DURATION := 0.40
const DODGE_IFRAME_START := 0.06
const DODGE_IFRAME_END := 0.28
const DODGE_SPEED := 400.0

const GCD := 0.32
const SPRINT_ATTACK_MISS := 0.12
const SPRINT_ATTACK_DMG_MUL := 0.88
const MOVE_ATTACK_MISS := 0.04
const MOVE_ATTACK_DMG_MUL := 0.96

const CHARGE_TAP_MAX := 0.18
const CHARGE_MIN := 0.22
const CHARGE_MAX := 0.85

const PARRY_WINDOW := 0.18
const PARRY_RECOVERY := 0.22
## Damage that gets through a raised shield with NO shield equipped is not a
## thing: the SHIELD style now requires one. How much it stops scales with the
## shield's own defense_bonus, between these two.
const SHIELD_BLOCK_MUL_MIN := 0.45   # a flimsy shield lets 45% through
const SHIELD_BLOCK_MUL_MAX := 0.15   # the best one lets 15% through
## defense_bonus at which a shield reaches SHIELD_BLOCK_MUL_MAX.
const SHIELD_DEFENSE_CAP := 9.0
const SHIELD_STAMINA_PER_HIT := 16.0
const ENERGY_BLOCK_MUL := 0.20
const ENERGY_COST_PER_HIT := 18.0
const ENERGY_DRAIN_PER_SEC := 8.0
const GUARD_STAMINA_DRAIN := 4.0

const LIGHT_REACH := 26.0
const HEAVY_REACH := 30.0
const LIGHT_WIDTH := 16.0
const HEAVY_WIDTH := 20.0
const HITBOX_ORIGIN_X := 10.0

const AUTO_GATHER_RANGE := 70.0

# Mage bolt (basic = free skillshot; charged spends mana)
const MAGE_BOLT_MANA_MIN := 10.0
const MAGE_BOLT_MANA_MAX := 28.0
const MAGE_BOLT_DMG_BASIC := 9.0
const MAGE_BOLT_DMG_MAX := 26.0
const MAGE_BOLT_SPEED_BASIC := 380.0
const MAGE_BOLT_SPEED_CHARGED := 300.0
const MAGE_BOLT_LIFE := 1.35

# Archer arrow (faster than mage; charged shot pierces, -10% dmg per enemy pierced)
const ARROW_STAMINA_MIN := 10.0
const ARROW_STAMINA_MAX := 24.0
const ARROW_DMG_BASIC := 8.0
const ARROW_DMG_MAX := 24.0
const ARROW_SPEED_BASIC := 520.0
const ARROW_SPEED_CHARGED := 420.0
const ARROW_LIFE := 1.6
const ARROW_PIERCE := 3
const ARROW_PIERCE_FALLOFF := 0.10

const ProjectileScene := preload("res://scenes/combat/projectile.tscn")

@onready var body_sprite: Polygon2D = $Body
@onready var visual: CharacterVisual = $CharacterVisual
@onready var facing_marker: Node2D = $Facing
@onready var hitbox: Hitbox = $Facing/Hitbox
@onready var hitbox_shape: CollisionShape2D = $Facing/Hitbox/CollisionShape2D
@onready var slash_fx: Polygon2D = $Facing/Hitbox/Slash
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health: Health = $Health
@onready var inventory: Inventory = $Inventory
@onready var progress: Progress = $Progress
@onready var anim_timer: Timer = $AnimTimer
@onready var gcd_timer: Timer = $GcdTimer
@onready var camera: Camera2D = $Camera2D
@onready var skills: SkillCaster = $SkillCaster
@onready var aimer: SkillAimer = $SkillAimer
@onready var guard_fx: Polygon2D = $GuardFx
@onready var charge_fx: Polygon2D = $ChargeFx


var state: State = State.FREE
var kit: Kit = Kit.WARRIOR
var defend_style: DefendStyle = DefendStyle.SHIELD
var stamina: float = MAX_STAMINA
var mana: float = MAX_MANA
var _stamina_delay: float = 0.0
var _mana_delay: float = 0.0
var facing: Vector2 = Vector2.RIGHT
var _dodge_dir: Vector2 = Vector2.RIGHT
var _dodge_time: float = 0.0
var _attack_phase: StringName = &""
var _combo_step: int = 0
var _combo_window: float = 0.0
var _attack_elapsed: float = 0.0
var _attack_startup: float = 0.0
var _attack_active: float = 0.0
var _attack_recovery: float = 0.0
var _i_frame: bool = false
var _hitbox_was_active: bool = false
var _aim_locked: bool = false
var _locked_facing: Vector2 = Vector2.RIGHT
var _attack_move_mult: float = ATTACK_MOVE_MULT
var _spawned_projectile: bool = false
var _pending_bolt: Dictionary = {}

var _charge_time: float = 0.0
var _charging: bool = false
var _guard_time: float = 0.0
var _parry_active: bool = false
var _last_defense_msg: String = ""
var _weapon_item: String = ""
var _weapon_def: Dictionary = {}
var _armor_item: String = ""
var _armor_def: Dictionary = {}
var _helmet_item: String = ""
var _helmet_def: Dictionary = {}
var _secondary_item: String = ""
var _secondary_def: Dictionary = {}
var _legs_item: String = ""
var _legs_def: Dictionary = {}
var _feet_item: String = ""
var _feet_def: Dictionary = {}
var _arms_item: String = ""
var _arms_def: Dictionary = {}
var _gloves_item: String = ""
var _gloves_def: Dictionary = {}
var _shoulders_item: String = ""
var _shoulders_def: Dictionary = {}
var _wrists_item: String = ""
var _wrists_def: Dictionary = {}
var auto_gather: bool = false
## Logical facing. Simulation state, not a visual detail: it is resolved here
## (CharacterFacing) and handed down to CharacterVisual, so the sprite can never
## disagree with the simulation about which way the character is looking.
var facing_dir: CharacterFacing.Direction = CharacterFacing.Direction.SOUTH
## Last state the visual saw, so one-shot animations restart on re-entry.
var _visual_last_state: State = State.FREE
## Skill currently being cast, for the animation. "" when not casting.
var _casting_skill: String = ""
## Movement multiplier while casting; a skill can pin you or let you walk.
var _cast_move_mult: float = 0.0
## True for the rest of the frame in which a click confirmed a skill, so the
## normal attack does not fire on that same click.
var _skill_click_consumed: bool = false
## Charge state: where the dash is heading and how fast. 0 speed = not dashing.
var _cast_dash_target: Vector2 = Vector2.ZERO
var _cast_dash_speed: float = 0.0


func _ready() -> void:
	Game.register_player(self)
	health.max_hp = 100.0
	health.hp = 100.0
	hurtbox.setup(health, &"player", self)
	hurtbox.collision_layer = 1 << 1
	hurtbox.collision_mask = 0
	hitbox.configure(&"player", 12.0, 8.0, 0.0)
	hitbox.owner = self
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.health_changed.connect(_on_health_changed)
	if progress:
		progress.xp_changed.connect(_on_xp_changed)
		progress.leveled_up.connect(_on_leveled_up)
	if inventory:
		inventory.changed.connect(_on_inventory_changed)
		inventory.item_added.connect(_on_item_added)
		if DEBUG_GIVE_EVERYTHING:
			for item_id in ItemDB.ITEMS:
				if str(item_id) == "gold_coin":
					continue
				inventory.add_item(str(item_id), 1)
	gcd_timer.one_shot = true
	anim_timer.one_shot = true
	if guard_fx:
		guard_fx.visible = false
	if charge_fx:
		charge_fx.visible = false
	skills.setup(self, &"player")
	aimer.setup(self)
	skills.cast_finished.connect(_on_cast_finished)
	skills.telegraph_placed.connect(_on_telegraph_placed)
	_apply_kit_defaults()
	_emit_stats()


func _physics_process(delta: float) -> void:
	_skill_click_consumed = false
	_update_aim()
	_regen_resources(delta)
	_combo_window = maxf(0.0, _combo_window - delta)
	_handle_hotkeys()
	_handle_skill_input()
	_handle_auto_gather_cancel()

	match state:
		State.FREE:
			_process_free(delta)
		State.CHARGE:
			_process_charge(delta)
		State.GUARD:
			_process_guard(delta)
		State.ATTACK:
			_process_attack(delta)
		State.DODGE:
			_process_dodge(delta)
		State.HURT:
			_process_hurt(delta)
		State.CAST:
			_process_cast(delta)
		State.DEAD:
			velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	move_and_slide()
	_process_auto_gather(delta)
	_emit_stats()
	_update_visuals()


## Skill slots. Pressing one ARMS the skill instead of firing it: the range and
## the area it covers are drawn, and the next click commits. Judging placement
## is most of the decision with a ground AoE, so firing on keypress would take
## that away.
##
## The loadout comes from the kit, so the same keys mean different things per
## class — see SkillDB.LOADOUTS.
func _handle_skill_input() -> void:
	if state == State.DEAD or skills.is_casting():
		if aimer.is_aiming():
			aimer.cancel()
		return

	# While aiming: left click commits, right click or the same key cancels.
	if aimer.is_aiming():
		var armed: String = aimer.current_skill()
		# Presentation reads this every frame rather than only at arm time, so
		# unequipping mid-aim (or aiming before ever having gear) still warns.
		var armed_skill := SkillDB.get_skill(armed)
		aimer.blocked = bool(armed_skill.get("requires_bow", false)) and not (has_bow() and has_arrows())
		if Input.is_action_just_pressed("guard"):
			aimer.cancel()
			return
		if Input.is_action_just_pressed("attack_light"):
			_try_cast(armed, aimer.aim_point())
			aimer.cancel()
			# The same click must not also swing the weapon this frame.
			_skill_click_consumed = true
			return

	var loadout := SkillDB.loadout_for(_kit_name().to_lower())
	for i in loadout.size():
		if not Input.is_action_just_pressed("skill_%d" % (i + 1)):
			continue
		var id := str(loadout[i])
		if aimer.is_aiming() and aimer.current_skill() == id:
			aimer.cancel()          # pressing it again puts it away
			return
		if not skills.is_ready(id):
			return
		# Everything arms, including self-cast: seeing the area you are about to
		# cover — and, for a charge, where it drops you — is part of the call.
		aimer.arm(id)
		return


## True while a skill is armed and waiting for the confirming click, so the
## normal attack does not also fire on that click.
func is_aiming_skill() -> bool:
	return aimer != null and aimer.is_aiming()


## Casting is an input command: the click position goes in, the caster decides
## what it actually hit. Nothing is locked on beforehand.
func _try_cast(skill_id: String, aim_point: Vector2 = Vector2.INF) -> bool:
	if not skills.is_ready(skill_id):
		return false
	var aim := aim_point if aim_point != Vector2.INF else get_global_mouse_position()
	var ok: bool = skills.cast(skill_id, aim, func(s: Dictionary) -> bool:
		# Same rule as the archer's basic/charged shot: no bow+arrows, no
		# arrows fired — checked before any cost is spent.
		if bool(s.get("requires_bow", false)) and not (has_bow() and has_arrows()):
			_last_defense_msg = "No bow/arrows equipped"
			return false
		var mana_cost := float(s.get("mana_cost", 0.0))
		var stam_cost := float(s.get("stamina_cost", 0.0))
		if mana_cost > 0.0 and mana < mana_cost:
			return false
		if stam_cost > 0.0 and stamina < stam_cost:
			return false
		if mana_cost > 0.0:
			_spend_mana(mana_cost)
		if stam_cost > 0.0:
			_spend_stamina(stam_cost)
		return true)
	if not ok:
		return false
	_casting_skill = skill_id
	var s := SkillDB.get_skill(skill_id)
	_cast_move_mult = float(s.get("move_mult", 0.0))
	# A charge travels TO the aimed point rather than firing off an impulse that
	# decays wherever, so you land where the preview said you would.
	_cast_dash_speed = float(s.get("dash_speed", 0.0))
	_cast_dash_target = aim
	if _cast_dash_speed > 0.0:
		var dir := (aim - global_position).normalized()
		if dir != Vector2.ZERO:
			facing = dir
			facing_marker.rotation = dir.angle()
	state = State.CAST
	gcd_timer.start(GCD)
	return true


func _process_cast(delta: float) -> void:
	if _cast_dash_speed > 0.0:
		var to_target := _cast_dash_target - global_position
		if to_target.length() > 6.0:
			velocity = to_target.normalized() * _cast_dash_speed
		else:
			velocity = Vector2.ZERO
			_cast_dash_speed = 0.0
		return
	if _cast_move_mult > 0.0:
		_apply_move(delta, _cast_move_mult)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta * 1.5)


func _on_cast_finished(_skill_id: String) -> void:
	_casting_skill = ""
	_cast_move_mult = 0.0
	_cast_dash_speed = 0.0
	if state == State.CAST:
		state = State.FREE


## A ground AoE announces itself before it lands, so it can be walked out of.
func _on_telegraph_placed(_skill_id: String, pos: Vector2, radius: float, delay: float) -> void:
	SkillTelegraph.spawn(pos, radius, delay, Color(1.0, 0.45, 0.35, 0.35))


func _handle_hotkeys() -> void:
	if Input.is_action_just_pressed("kit_warrior"):
		_set_kit(Kit.WARRIOR)
	elif Input.is_action_just_pressed("kit_mage"):
		_set_kit(Kit.MAGE)
	elif Input.is_action_just_pressed("kit_archer"):
		_set_kit(Kit.ARCHER)
	if Input.is_action_just_pressed("auto_gather"):
		auto_gather = not auto_gather
		_last_defense_msg = "Auto-gather ON" if auto_gather else "Auto-gather OFF"
		_emit_stats()

	if Input.is_action_just_pressed("defend_style_1"):
		defend_style = DefendStyle.SHIELD
		_last_defense_msg = "Defense: SHIELD"
	elif Input.is_action_just_pressed("defend_style_2"):
		defend_style = DefendStyle.PARRY
		_last_defense_msg = "Defense: PARRY"
	elif Input.is_action_just_pressed("defend_style_3"):
		defend_style = DefendStyle.ENERGY
		_last_defense_msg = "Defense: ENERGY"


func _set_kit(k: Kit) -> void:
	if state != State.FREE and state != State.DEAD:
		return
	kit = k
	_apply_kit_defaults()
	_combo_step = 0
	_last_defense_msg = "Kit: %s" % _kit_name()


func _apply_kit_defaults() -> void:
	match kit:
		Kit.WARRIOR:
			defend_style = DefendStyle.SHIELD
			# The real attack-swing sprite frames carry this now; the flat
			# wedge used to be the only swing feedback but now just overlaps
			# the animated sword on top of the character.
			if slash_fx:
				slash_fx.visible = false
		Kit.MAGE:
			defend_style = DefendStyle.ENERGY
			if slash_fx:
				slash_fx.visible = false
			hitbox.deactivate()
		Kit.ARCHER:
			defend_style = DefendStyle.PARRY
			if slash_fx:
				slash_fx.visible = false
			hitbox.deactivate()
	# Every kit now shares the same base body art; the per-kit weapon will come
	# in as an equipment overlay, which needs no change here. The flat-color
	# Body polygon stays in the scene (other code still tints it to signal
	# charge/guard/dodge state) but is no longer drawn.
	body_sprite.visible = false
	_sync_equipment_visuals()


func _process_free(delta: float) -> void:
	_apply_move(delta, 1.0)
	_hide_guard_fx()
	_hide_charge_fx()

	if Input.is_action_just_pressed("dodge"):
		_try_dodge()
		return
	if Input.is_action_just_pressed("guard"):
		_try_start_guard()
		return
	if Input.is_action_just_pressed("attack_light") and not is_aiming_skill() and not _skill_click_consumed:
		_start_charge()
		return


func _process_charge(delta: float) -> void:
	_apply_move(delta, CHARGE_MOVE_MULT)
	_charge_time += delta
	_update_charge_fx()

	if Input.is_action_just_pressed("dodge"):
		_cancel_charge()
		_try_dodge()
		return
	if Input.is_action_just_pressed("guard"):
		_cancel_charge()
		_try_start_guard()
		return

	if not Input.is_action_pressed("attack_light"):
		_release_charge()
		return

	if _charge_time > CHARGE_MAX + 0.5:
		_charge_time = CHARGE_MAX + 0.5


func _process_guard(delta: float) -> void:
	_apply_move(delta, GUARD_MOVE_MULT)
	_guard_time += delta
	_update_parry_window()
	_update_guard_fx()

	match effective_defend_style():
		DefendStyle.SHIELD:
			if stamina > 0.0:
				_spend_stamina(GUARD_STAMINA_DRAIN * delta * 0.35)
			if not Input.is_action_pressed("guard") or stamina <= 0.0:
				_end_guard()
				return
		DefendStyle.PARRY:
			if _guard_time > PARRY_WINDOW + PARRY_RECOVERY:
				_end_guard()
				return
			if not Input.is_action_pressed("guard") and _guard_time > PARRY_WINDOW:
				_end_guard()
				return
		DefendStyle.ENERGY:
			if mana > 0.0:
				_spend_mana(ENERGY_DRAIN_PER_SEC * delta)
			if not Input.is_action_pressed("guard") or mana <= 0.0:
				_end_guard()
				return

	if Input.is_action_just_pressed("dodge"):
		_end_guard()
		_try_dodge()
		return


func _process_attack(delta: float) -> void:
	_apply_move(delta, _attack_move_mult)
	_attack_elapsed += delta
	_hide_charge_fx()

	if Input.is_action_just_pressed("dodge"):
		_try_dodge()
		return

	var active_end := _attack_startup + _attack_active

	if kit == Kit.MAGE and _attack_phase == &"bolt":
		# Spawn projectile once when active frames begin
		if _attack_elapsed >= _attack_startup and not _spawned_projectile:
			_spawn_pending_bolt()
			_spawned_projectile = true
		if _attack_elapsed >= _attack_startup + _attack_active + _attack_recovery:
			_unlock_aim()
			state = State.FREE
			_combo_window = 0.28
		return

	if kit == Kit.ARCHER and _attack_phase == &"arrow":
		if _attack_elapsed >= _attack_startup and not _spawned_projectile:
			_spawn_pending_bolt()
			_spawned_projectile = true
		if _attack_elapsed >= _attack_startup + _attack_active + _attack_recovery:
			_unlock_aim()
			state = State.FREE
			_combo_window = 0.28
		return

	# Melee warrior path
	if _attack_elapsed < _attack_startup:
		if _hitbox_was_active:
			hitbox.deactivate()
			_hitbox_was_active = false
	elif _attack_elapsed < active_end:
		if not _hitbox_was_active:
			hitbox.activate()
			_hitbox_was_active = true
	else:
		if _hitbox_was_active:
			hitbox.deactivate()
			_hitbox_was_active = false

	var total := _attack_startup + _attack_active + _attack_recovery
	if _attack_elapsed >= total:
		if _hitbox_was_active:
			hitbox.deactivate()
			_hitbox_was_active = false
		_unlock_aim()
		state = State.FREE
		_combo_window = 0.35


func _process_dodge(delta: float) -> void:
	_dodge_time += delta
	velocity = _dodge_dir * DODGE_SPEED
	var iframe := _dodge_time >= DODGE_IFRAME_START and _dodge_time <= DODGE_IFRAME_END
	_set_iframe(iframe)
	if _dodge_time >= DODGE_DURATION:
		_set_iframe(false)
		state = State.FREE
		velocity *= 0.4


func _process_hurt(delta: float) -> void:
	# No freeze on basic hits: keep moving through the flinch
	_apply_move(delta, 0.9)
	if anim_timer.is_stopped():
		state = State.FREE


func _start_charge() -> void:
	if state != State.FREE:
		return
	if not gcd_timer.is_stopped():
		return
	# No bow, no arrows, no shot — refused up front so a bare-handed archer
	# doesn't even get the charge windup for an attack that was never coming.
	if kit == Kit.ARCHER and not (has_bow() and has_arrows()):
		_last_defense_msg = "No bow/arrows equipped"
		return
	_charging = true
	_charge_time = 0.0
	state = State.CHARGE
	_combo_step = 0
	_show_charge_fx()


func _cancel_charge() -> void:
	_charging = false
	_charge_time = 0.0
	_hide_charge_fx()
	if state == State.CHARGE:
		state = State.FREE


func _release_charge() -> void:
	var t := _charge_time
	_charging = false
	_hide_charge_fx()
	if kit == Kit.MAGE:
		_release_mage_charge(t)
		return
	if kit == Kit.ARCHER:
		_release_archer_charge(t)
		return

	if t < CHARGE_TAP_MAX:
		if _combo_window > 0.0 and _combo_step > 0 and _combo_step < 3:
			_start_light_combo(_combo_step)
		else:
			_combo_step = 0
			_start_light_combo(0)
	else:
		var charge_ratio := clampf((t - CHARGE_MIN) / (CHARGE_MAX - CHARGE_MIN), 0.0, 1.0)
		if t < CHARGE_MIN:
			charge_ratio = 0.35
		_start_heavy_charged(charge_ratio)


func _release_mage_charge(t: float) -> void:
	if t < CHARGE_TAP_MAX:
		# Basic bolt — free (no mana), like warrior light
		_start_mage_bolt(0.0, false)
	else:
		var charge_ratio := clampf((t - CHARGE_MIN) / (CHARGE_MAX - CHARGE_MIN), 0.0, 1.0)
		if t < CHARGE_MIN:
			charge_ratio = 0.35
		var cost := lerpf(MAGE_BOLT_MANA_MIN, MAGE_BOLT_MANA_MAX, charge_ratio)
		if mana < cost:
			# Not enough mana → basic free bolt
			_start_mage_bolt(0.0, false)
			_last_defense_msg = "No mana — basic bolt"
			return
		_spend_mana(cost)
		_start_mage_bolt(charge_ratio, true)


func _release_archer_charge(t: float) -> void:
	if t < CHARGE_TAP_MAX:
		# Basic arrow — free, fast
		_start_arrow(0.0, false)
	else:
		var charge_ratio := clampf((t - CHARGE_MIN) / (CHARGE_MAX - CHARGE_MIN), 0.0, 1.0)
		if t < CHARGE_MIN:
			charge_ratio = 0.35
		var cost := lerpf(ARROW_STAMINA_MIN, ARROW_STAMINA_MAX, charge_ratio)
		if stamina < cost:
			# Not enough stamina → basic free arrow
			_start_arrow(0.0, false)
			_last_defense_msg = "No stamina — basic arrow"
			return
		_spend_stamina(cost)
		_start_arrow(charge_ratio, true)


func _start_arrow(charge_ratio: float, charged: bool) -> void:
	_attack_phase = &"arrow"
	_lock_aim()
	_spawned_projectile = false
	_combo_step = 0

	var base := _ranged_base_damage()
	var dmg_bonus := _weapon_dmg_bonus()
	if charged:
		_attack_startup = lerpf(0.10, 0.22, charge_ratio)
		_attack_active = 0.05
		_attack_recovery = lerpf(0.14, 0.24, charge_ratio)
		var dmg := lerpf(base * 1.5, base * 2.9, charge_ratio) + dmg_bonus
		var spd := lerpf(ARROW_SPEED_CHARGED + 40.0, ARROW_SPEED_CHARGED, charge_ratio)
		# Near-white so the arrow's own wood/metal colors show; only a slight
		# gold sheen creeps in as it charges, same "charged = warmer" language
		# the mage's bolt uses.
		var col := Color(0.95, 0.95, 0.9, 0.95).lerp(Color(1.0, 0.85, 0.5), charge_ratio)
		_pending_bolt = {
			"damage": dmg,
			"poise": lerpf(5.0, 14.0, charge_ratio),
			"speed": spd,
			"lifetime": ARROW_LIFE + charge_ratio * 0.3,
			"color": col,
			"radius": lerpf(3.5, 5.5, charge_ratio),
			"pierce": ARROW_PIERCE,
			"pierce_falloff": ARROW_PIERCE_FALLOFF,
			"visual_effect": "arrow",
			"visual_scale": 4.3,
		}
		body_sprite.color = Color(0.85, 0.8, 0.3)
	else:
		_attack_startup = 0.06
		_attack_active = 0.04
		_attack_recovery = 0.12
		_pending_bolt = {
			"damage": base + dmg_bonus,
			"poise": 3.0,
			"speed": ARROW_SPEED_BASIC,
			"lifetime": ARROW_LIFE,
			"color": Color(0.95, 0.95, 0.9, 0.95),
			"radius": 3.0,
			"pierce": 0,
			"pierce_falloff": 0.0,
			"visual_effect": "arrow",
			"visual_scale": 5.0,
		}
		body_sprite.color = Color(0.7, 0.8, 0.5)

	_attack_move_mult = ATTACK_MOVE_MULT
	_attack_elapsed = 0.0
	state = State.ATTACK
	# Archer shoots faster than mage: shorter GCD
	gcd_timer.start(GCD * 0.82)
	if slash_fx:
		slash_fx.visible = false
	hitbox.deactivate()



func _start_mage_bolt(charge_ratio: float, charged: bool) -> void:
	_attack_phase = &"bolt"
	_lock_aim()
	_spawned_projectile = false
	_combo_step = 0

	var base := _spell_base_damage()
	var sbonus := _weapon_spell_bonus()
	if charged:
		_attack_startup = lerpf(0.12, 0.28, charge_ratio)
		_attack_active = 0.06
		_attack_recovery = lerpf(0.18, 0.32, charge_ratio)
		var dmg := lerpf(base * 1.5, base * 2.8, charge_ratio) + sbonus
		var spd := lerpf(MAGE_BOLT_SPEED_CHARGED + 40.0, MAGE_BOLT_SPEED_CHARGED, charge_ratio)
		var rad := lerpf(5.5, 9.0, charge_ratio)
		var col := Color(0.45 + 0.4 * charge_ratio, 0.55, 1.0, 0.95)
		_pending_bolt = {
			"damage": dmg,
			"poise": lerpf(6.0, 16.0, charge_ratio),
			"speed": spd,
			"lifetime": MAGE_BOLT_LIFE + charge_ratio * 0.25,
			"color": col,
			"radius": rad,
			"visual_effect": "bolt_charged",
			"visual_scale": 2.9,
		}
		body_sprite.color = Color(0.55, 0.45, 0.95)
	else:
		_attack_startup = 0.08
		_attack_active = 0.05
		_attack_recovery = 0.16
		_pending_bolt = {
			"damage": base + sbonus,
			"poise": 4.0,
			"speed": MAGE_BOLT_SPEED_BASIC,
			"lifetime": MAGE_BOLT_LIFE,
			"color": Color(0.55, 0.8, 1.0, 0.95),
			"radius": 4.5,
			"visual_effect": "bolt_plain",
			"visual_scale": 5.5,
		}
		body_sprite.color = Color(0.6, 0.7, 1.0)

	_attack_move_mult = MAGE_ATTACK_MOVE_MULT
	_attack_elapsed = 0.0
	state = State.ATTACK
	gcd_timer.start(GCD)
	if slash_fx:
		slash_fx.visible = false
	hitbox.deactivate()


func _spawn_pending_bolt() -> void:
	var dir := _locked_facing if _aim_locked else facing
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	var spawn_pos := global_position + dir.normalized() * 16.0
	var bolt: Projectile = Game.spawn(ProjectileScene, spawn_pos)
	# Mage advantage: bolts never whiff from movement/accuracy — full damage on hit.
	bolt.setup(
		dir,
		&"player",
		float(_pending_bolt.get("damage", MAGE_BOLT_DMG_BASIC)),
		float(_pending_bolt.get("poise", 4.0)),
		float(_pending_bolt.get("speed", MAGE_BOLT_SPEED_BASIC)),
		float(_pending_bolt.get("lifetime", MAGE_BOLT_LIFE)),
		self,
		_pending_bolt.get("color", Color(0.55, 0.8, 1.0)),
		float(_pending_bolt.get("radius", 5.0)),
		int(_pending_bolt.get("pierce", 0)),
		float(_pending_bolt.get("pierce_falloff", 0.0)),
		str(_pending_bolt.get("visual_effect", "")),
		float(_pending_bolt.get("visual_scale", 1.0))
	)


func _try_start_guard() -> void:
	if state != State.FREE and state != State.CHARGE:
		return
	if state == State.CHARGE:
		_cancel_charge()

	match effective_defend_style():
		DefendStyle.SHIELD:
			if stamina < 5.0:
				return
		DefendStyle.PARRY:
			pass
		DefendStyle.ENERGY:
			if mana < 5.0:
				return

	_guard_time = 0.0
	_parry_active = true
	state = State.GUARD
	_show_guard_fx()


func _end_guard() -> void:
	_parry_active = false
	_hide_guard_fx()
	if state == State.GUARD:
		state = State.FREE


func _update_parry_window() -> void:
	_parry_active = _guard_time <= PARRY_WINDOW


## Entry point for every hit aimed at the player (called from Hurtbox). Guard,
## parry and block are resolved first, then worn armour reduces whatever damage
## is left — so armour helps whether or not you were blocking.
func resolve_incoming_hit(hit_data: Dictionary) -> Dictionary:
	var data := _resolve_guard(hit_data)
	if bool(data.get("cancelled", false)):
		return data
	var raw := float(data.get("damage", 0.0))
	if raw > 0.0:
		data["damage"] = raw * (1.0 - defense_reduction())
	return data


## Whether a shield is actually equipped in the off-hand. The SHIELD defend
## style is gated on this: raising a shield you do not have was free mitigation.
func has_shield() -> bool:
	return _secondary_item != "" and float(_secondary_def.get("defense_bonus", 0.0)) > 0.0


## A bow-class weapon in the weapon slot — same signal LpcEquipment/animation
## already use (attack_anim == attack_shoot), not a hardcoded item id, so any
## future ranged weapon qualifies for free.
func has_bow() -> bool:
	return _weapon_item != "" and ItemDB.attack_anim(_weapon_item) == &"attack_shoot"


## Arrows in the off-hand (see ItemDB "quiver": same slot a shield uses).
func has_arrows() -> bool:
	return _secondary_item != "" and bool(_secondary_def.get("is_ammo", false))


## How much damage a raised shield lets through, driven by the shield itself.
## A better shield blocks more, so the off-hand slot is a real choice.
func shield_block_mul() -> float:
	if not has_shield():
		return 1.0
	var def := float(_secondary_def.get("defense_bonus", 0.0))
	var t := clampf(def / SHIELD_DEFENSE_CAP, 0.0, 1.0)
	return lerpf(SHIELD_BLOCK_MUL_MIN, SHIELD_BLOCK_MUL_MAX, t)


## The defend style that can actually be used right now. SHIELD silently falls
## back to PARRY when the off-hand is empty, so losing your shield mid-fight
## leaves you defending badly rather than not at all.
func effective_defend_style() -> DefendStyle:
	if defend_style == DefendStyle.SHIELD and not has_shield():
		return DefendStyle.PARRY
	return defend_style


## Sum of defense_bonus across the worn pieces (armor + helmet + secondary).
## Weapons never contribute.
func total_defense() -> float:
	var total := 0.0
	for piece in [_armor_def, _legs_def, _feet_def, _arms_def, _gloves_def,
			_shoulders_def, _wrists_def, _helmet_def, _secondary_def]:
		total += float(piece.get("defense_bonus", 0.0))
	return total


## Fraction of incoming damage the current gear absorbs, 0.0-1.0.
##
## Diminishing returns instead of flat subtraction: flat would make the full
## kit (8 + 3 + 4 = 15) cancel an entire base hit (10), and it can never reach
## 100% no matter how much defense gets stacked later.
##   leather only (3)  ->  9%
##   iron armor  (8)   -> 21%
##   full kit    (15)  -> 33%
func defense_reduction() -> float:
	var total := total_defense()
	if total <= 0.0:
		return 0.0
	return total / (total + DEFENSE_SOFTCAP)


func _resolve_guard(hit_data: Dictionary) -> Dictionary:
	var data := hit_data.duplicate()
	if state == State.DEAD or _i_frame:
		data["cancelled"] = true
		return data

	if state != State.GUARD:
		return data

	if _parry_active:
		data["cancelled"] = true
		data["parried"] = true
		data["damage"] = 0.0
		_last_defense_msg = "PARRY!"
		_on_successful_parry(data)
		return data

	match effective_defend_style():
		DefendStyle.SHIELD:
			if stamina <= 0.0:
				return data
			data["damage"] = float(data.get("damage", 0.0)) * shield_block_mul()
			data["blocked"] = true
			_spend_stamina(SHIELD_STAMINA_PER_HIT)
			_last_defense_msg = "BLOCK"
			if stamina <= 0.0:
				_last_defense_msg = "GUARD BREAK"
				_end_guard()
				state = State.HURT
				anim_timer.start(0.25)
			return data
		DefendStyle.PARRY:
			return data
		DefendStyle.ENERGY:
			if mana <= 0.0:
				return data
			data["damage"] = float(data.get("damage", 0.0)) * ENERGY_BLOCK_MUL
			data["blocked"] = true
			_spend_mana(ENERGY_COST_PER_HIT)
			_last_defense_msg = "BARRIER"
			if mana <= 0.0:
				_last_defense_msg = "BARRIER DOWN"
				_end_guard()
			return data

	return data


func _on_successful_parry(_data: Dictionary) -> void:
	stamina = minf(MAX_STAMINA, stamina + 8.0)
	body_sprite.color = Color(1.0, 1.0, 0.55)
	if defend_style == DefendStyle.PARRY:
		_end_guard()


func _try_dodge() -> void:
	if state == State.DEAD:
		return
	if stamina < DODGE_COST:
		return
	if state == State.ATTACK:
		if _attack_elapsed < _attack_startup + _attack_active:
			return
	if state == State.CHARGE:
		_cancel_charge()
	if state == State.GUARD:
		_end_guard()

	_spend_stamina(DODGE_COST)
	hitbox.deactivate()
	_hitbox_was_active = false
	_unlock_aim()
	var dir := _get_move_input()
	if dir == Vector2.ZERO:
		dir = facing
	_dodge_dir = dir.normalized()
	_dodge_time = 0.0
	state = State.DODGE
	_combo_step = 0


func _start_light_combo(step: int) -> void:
	_combo_step = step + 1
	_attack_phase = &"light"
	_lock_aim()
	var base := _melee_base_damage()
	var bonus := _weapon_dmg_bonus()
	match step:
		0:
			_attack_startup = 0.10
			_attack_active = 0.08
			_attack_recovery = 0.18
			hitbox.configure(&"player", base * 1.0 + bonus, 6.0, 0.0)
			_set_hitbox_size(16.0, LIGHT_WIDTH, LIGHT_REACH)
		1:
			_attack_startup = 0.08
			_attack_active = 0.08
			_attack_recovery = 0.16
			hitbox.configure(&"player", base * 1.2 + bonus, 7.0, 0.0)
			_set_hitbox_size(16.0, LIGHT_WIDTH, LIGHT_REACH)
		_:
			_attack_startup = 0.12
			_attack_active = 0.10
			_attack_recovery = 0.28
			hitbox.configure(&"player", base * 1.8 + bonus, 14.0, 0.0)
			_set_hitbox_size(18.0, LIGHT_WIDTH + 2.0, LIGHT_REACH + 2.0)
			_combo_step = 0

	hitbox.owner = self
	_apply_attack_accuracy()
	hitbox.begin_swing()
	_hitbox_was_active = false
	_attack_move_mult = ATTACK_MOVE_MULT
	_attack_elapsed = 0.0
	state = State.ATTACK
	gcd_timer.start(GCD)
	body_sprite.color = Color(0.95, 0.85, 0.45)


func _start_heavy_charged(charge_ratio: float) -> void:
	var cost := lerpf(HEAVY_COST_MIN, HEAVY_COST_MAX, charge_ratio)
	if stamina < cost:
		_combo_step = 0
		_start_light_combo(0)
		return

	_spend_stamina(cost)
	_attack_phase = &"heavy"
	_lock_aim()
	var base := _melee_base_damage()
	var dmg := lerpf(base * 2.0, base * 3.6, charge_ratio) + _weapon_dmg_bonus()
	var poise := lerpf(14.0, 28.0, charge_ratio)
	_attack_startup = lerpf(0.16, 0.28, charge_ratio)
	_attack_active = 0.10
	_attack_recovery = lerpf(0.28, 0.40, charge_ratio)
	hitbox.configure(&"player", dmg, poise, 0.0)
	hitbox.owner = self
	_apply_attack_accuracy()
	hitbox.begin_swing()
	_hitbox_was_active = false
	var reach := lerpf(HEAVY_REACH - 2.0, HEAVY_REACH + 4.0, charge_ratio)
	_set_hitbox_size(18.0, HEAVY_WIDTH, reach)
	_attack_move_mult = HEAVY_MOVE_MULT
	_attack_elapsed = 0.0
	_combo_step = 0
	state = State.ATTACK
	gcd_timer.start(GCD)
	body_sprite.color = Color(0.95, 0.45 + 0.2 * (1.0 - charge_ratio), 0.30)


func _apply_move(delta: float, speed_mul: float) -> void:
	var input_dir := _get_move_input()
	var can_sprint := state == State.FREE or state == State.CHARGE
	var sprinting := can_sprint and Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO and stamina > 1.0
	var speed := MOVE_SPEED * speed_mul * (SPRINT_MULT if sprinting else 1.0)
	if sprinting:
		_spend_stamina(SPRINT_COST_PER_SEC * delta)
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * speed, ACCEL * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)


func _is_sprinting_now() -> bool:
	var input_dir := _get_move_input()
	return Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO and stamina > 1.0


func _is_moving_now() -> bool:
	return _get_move_input() != Vector2.ZERO


func _apply_attack_accuracy() -> void:
	if _is_sprinting_now():
		hitbox.set_accuracy(SPRINT_ATTACK_MISS, SPRINT_ATTACK_DMG_MUL)
	elif _is_moving_now():
		hitbox.set_accuracy(MOVE_ATTACK_MISS, MOVE_ATTACK_DMG_MUL)
	else:
		hitbox.set_accuracy(0.0, 1.0)


func _lock_aim() -> void:
	var dir := get_global_mouse_position() - global_position
	if dir.length_squared() > 4.0:
		facing = dir.normalized()
	_aim_locked = true
	_locked_facing = facing
	facing_marker.rotation = _locked_facing.angle()


func _unlock_aim() -> void:
	_aim_locked = false
	var dir := get_global_mouse_position() - global_position
	if dir.length_squared() > 4.0:
		facing = dir.normalized()
		facing_marker.rotation = facing.angle()


func _set_hitbox_size(length: float, width: float, reach_end: float) -> void:
	var start_x := HITBOX_ORIGIN_X
	var end_x := reach_end
	length = minf(length, maxf(4.0, end_x - start_x))
	var center_x := start_x + length * 0.5
	var rect := hitbox_shape.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		hitbox_shape.shape = rect
	rect.size = Vector2(length, width)
	hitbox_shape.position = Vector2(center_x, 0)
	var half_l := length * 0.5
	var half_w := width * 0.5
	slash_fx.polygon = PackedVector2Array([
		Vector2(center_x - half_l, -half_w),
		Vector2(center_x + half_l, -half_w * 0.7),
		Vector2(center_x + half_l, half_w * 0.7),
		Vector2(center_x - half_l, half_w),
	])
	slash_fx.color = Color(1, 0.85, 0.4, 0.5)


func _update_aim() -> void:
	if _aim_locked and state == State.ATTACK:
		facing = _locked_facing
		facing_marker.rotation = _locked_facing.angle()
		return
	var mouse := get_global_mouse_position()
	var dir := (mouse - global_position)
	if dir.length_squared() > 4.0:
		facing = dir.normalized()
		facing_marker.rotation = facing.angle()


func _get_move_input() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return v.normalized() if v.length_squared() > 1.0 else v


func _handle_auto_gather_cancel() -> void:
	if auto_gather and _get_move_input() != Vector2.ZERO:
		auto_gather = false
		_last_defense_msg = "Auto-gather OFF"
		_emit_stats()


func _process_auto_gather(_delta: float) -> void:
	if not auto_gather:
		return
	if state != State.FREE:
		return
	var node := _find_nearest_immortal_node()
	if node == null:
		return
	var dir := (node.global_position - global_position).normalized()
	if dir.length_squared() > 0.01:
		facing = dir
		facing_marker.rotation = dir.angle()
	if node.has_method("gather"):
		node.gather(false, self)


func _find_nearest_immortal_node() -> Node2D:
	var nodes: Array[Node] = get_tree().get_nodes_in_group("immortal_node")
	var best: Node2D = null
	var best_d := AUTO_GATHER_RANGE
	for n in nodes:
		if not (n is Node2D):
			continue
		var d := global_position.distance_to((n as Node2D).global_position)
		if d <= best_d:
			best_d = d
			best = n
	return best


func _spend_stamina(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	_stamina_delay = STAMINA_REGEN_DELAY


func _spend_mana(amount: float) -> void:
	mana = maxf(0.0, mana - amount)
	_mana_delay = MANA_REGEN_DELAY


func _regen_resources(delta: float) -> void:
	if state != State.DODGE and state != State.GUARD:
		if _stamina_delay > 0.0:
			_stamina_delay -= delta
		elif state != State.ATTACK or _attack_phase != &"heavy":
			stamina = minf(MAX_STAMINA, stamina + STAMINA_REGEN * delta)

	if state == State.GUARD and defend_style == DefendStyle.ENERGY:
		return
	if state == State.ATTACK and _attack_phase == &"bolt" and _pending_bolt.get("charged", false):
		return
	if _mana_delay > 0.0:
		_mana_delay -= delta
	else:
		mana = minf(MAX_MANA, mana + MANA_REGEN * delta)


func _set_iframe(value: bool) -> void:
	_i_frame = value
	hurtbox.set_invulnerable(value)
	modulate.a = 0.55 if value else 1.0


## States the character is committed to: once started, a basic hit must let them
## play out. See _on_damaged and docs/COMBATE.md ("Interrupción").
const COMMITTED_STATES := [State.ATTACK, State.CHARGE, State.DODGE]


func _on_damaged(_amount: float, _current: float) -> void:
	if state == State.DEAD:
		return
	if _i_frame:
		return
	if state == State.GUARD:
		return
	# DESIGN RULE: a basic attack never interrupts. Getting hit mid-swing used
	# to drop you into HURT, kill the hitbox in the middle of the active window
	# and wipe the combo — i.e. whoever landed the first hit won the trade for
	# free. Committed actions now play out; only the damage lands.
	# Interruption is reserved for effects that ask for it explicitly.
	if aimer and aimer.is_aiming():
		aimer.cancel()
	if COMMITTED_STATES.has(state):
		body_sprite.color = Color(0.9, 0.3, 0.3)
		return
	_hide_guard_fx()
	_hide_charge_fx()
	_charging = false
	hitbox.deactivate()
	_hitbox_was_active = false
	state = State.HURT
	anim_timer.start(0.15)
	body_sprite.color = Color(0.9, 0.3, 0.3)
	_combo_step = 0


func _on_died() -> void:
	state = State.DEAD
	hitbox.deactivate()
	_hitbox_was_active = false
	_hide_guard_fx()
	_hide_charge_fx()
	body_sprite.color = Color(0.3, 0.3, 0.3)
	modulate.a = 0.7


func _on_health_changed(_current: float, _maximum: float) -> void:
	_emit_stats()


func _on_xp_changed(_level: int, _xp: int, _xp_to_next: int) -> void:
	_emit_stats()


func _on_leveled_up(level: int) -> void:
	_last_defense_msg = "LEVEL UP! %d" % level
	if Game.has_method("toast"):
		Game.toast("LEVEL UP! %d" % level)
	_apply_level_stats()
	if health:
		health.heal(health.max_hp * 0.25)
	_emit_stats()


func _apply_level_stats() -> void:
	var lv := get_level()
	var new_max := 100.0 + (lv - 1) * 12.0
	var old_max := health.max_hp
	health.max_hp = new_max
	if new_max > old_max:
		health.hp += (new_max - old_max)
	health.hp = minf(health.max_hp, health.hp)


func get_level() -> int:
	return progress.level if progress else 1


func _melee_base_damage() -> float:
	return 10.0 + (get_level() - 1) * 1.5


func _spell_base_damage() -> float:
	return 9.0 + (get_level() - 1) * 1.2


func _ranged_base_damage() -> float:
	return 8.0 + (get_level() - 1) * 1.3


func _weapon_dmg_bonus() -> float:
	return float(_weapon_def.get("dmg_bonus", 0.0)) if not _weapon_def.is_empty() else 0.0


func _weapon_spell_bonus() -> float:
	return float(_weapon_def.get("spell_bonus", 0.0)) if not _weapon_def.is_empty() else 0.0


func equip_weapon(item_id: String) -> bool:
	if not ItemDB.is_weapon(item_id):
		return false
	if inventory == null:
		return false
	# Take the new weapon out FIRST. Returning the old one before confirming the
	# swap could succeed duplicated it whenever remove_item failed.
	if inventory.remove_item(item_id, 1) < 1:
		return false
	if _weapon_item != "":
		inventory.add_item(_weapon_item, 1)
	_weapon_item = item_id
	_weapon_def = ItemDB.get_item(item_id)
	_last_defense_msg = "Equipped %s" % str(_weapon_def.get("name", item_id))
	_sync_equipment_visuals()
	_emit_stats()
	Game.inventory_changed.emit(inventory)
	return true


func equip_armor(item_id: String) -> bool:
	return _equip_gear_slot(item_id, ItemDB.is_armor, "_armor_item", "_armor_def")


func equip_helmet(item_id: String) -> bool:
	return _equip_gear_slot(item_id, ItemDB.is_helmet, "_helmet_item", "_helmet_def")


func equip_legs(item_id: String) -> bool:
	return _equip_gear_slot(item_id, ItemDB.is_legs, "_legs_item", "_legs_def")


func equip_feet(item_id: String) -> bool:
	return _equip_gear_slot(item_id, ItemDB.is_feet, "_feet_item", "_feet_def")


func equip_arms(item_id: String) -> bool:
	return _equip_gear_slot(item_id, ItemDB.is_arms, "_arms_item", "_arms_def")


func equip_gloves(item_id: String) -> bool:
	return _equip_gear_slot(item_id, ItemDB.is_gloves, "_gloves_item", "_gloves_def")


func equip_shoulders(item_id: String) -> bool:
	return _equip_gear_slot(item_id, ItemDB.is_shoulders, "_shoulders_item", "_shoulders_def")


func equip_wrists(item_id: String) -> bool:
	return _equip_gear_slot(item_id, ItemDB.is_wrists, "_wrists_item", "_wrists_def")


func equip_secondary(item_id: String) -> bool:
	return _equip_gear_slot(item_id, ItemDB.is_secondary, "_secondary_item", "_secondary_def")


## Shared by equip_armor/equip_helmet/equip_secondary — same swap-back-into-
## inventory logic as equip_weapon, just parameterized by which slot.
func _equip_gear_slot(item_id: String, type_check: Callable, item_field: StringName, def_field: StringName) -> bool:
	if not type_check.call(item_id):
		return false
	if inventory == null:
		return false
	# Same ordering fix as equip_weapon: remove first, then hand the old piece
	# back, so a failed swap can never leave the item in both places.
	if inventory.remove_item(item_id, 1) < 1:
		return false
	var current: String = get(item_field)
	if current != "":
		inventory.add_item(current, 1)
	set(item_field, item_id)
	var def := ItemDB.get_item(item_id)
	set(def_field, def)
	_last_defense_msg = "Equipped %s" % str(def.get("name", item_id))
	_sync_equipment_visuals()
	_emit_stats()
	Game.inventory_changed.emit(inventory)
	return true


## Equipment slot -> the two player fields backing it. Used by unequip() and by
## the slot queries below so the slot list lives in exactly one place.
const _SLOT_FIELDS := {
	"weapon": ["_weapon_item", "_weapon_def"],
	"armor": ["_armor_item", "_armor_def"],
	"legs": ["_legs_item", "_legs_def"],
	"feet": ["_feet_item", "_feet_def"],
	"arms": ["_arms_item", "_arms_def"],
	"gloves": ["_gloves_item", "_gloves_def"],
	"shoulders": ["_shoulders_item", "_shoulders_def"],
	"wrists": ["_wrists_item", "_wrists_def"],
	"helmet": ["_helmet_item", "_helmet_def"],
	"secondary": ["_secondary_item", "_secondary_def"],
}


## Item id currently equipped in a slot, "" when empty or the slot is unknown.
func get_equipped(slot: String) -> String:
	if not _SLOT_FIELDS.has(slot):
		return ""
	return str(get(_SLOT_FIELDS[slot][0]))


## Take the piece off and put it back in the bag. Returns false (and changes
## nothing) when the slot is already empty or the inventory has no room —
## dropping gear on the floor because the bag is full would be worse.
func unequip(slot: String) -> bool:
	if not _SLOT_FIELDS.has(slot) or inventory == null:
		return false
	var fields: Array = _SLOT_FIELDS[slot]
	var item_id := str(get(fields[0]))
	if item_id == "":
		return false
	if not inventory.has_space_for(item_id, 1):
		_last_defense_msg = "No room to unequip %s" % ItemDB.display_name(item_id)
		_emit_stats()
		return false
	inventory.add_item(item_id, 1)
	set(fields[0], "")
	set(fields[1], {})
	_last_defense_msg = "Unequipped %s" % ItemDB.display_name(item_id)
	_sync_equipment_visuals()
	_emit_stats()
	Game.inventory_changed.emit(inventory)
	return true


## One visual_state key per equipment slot (see ItemDB), "" when the slot is
## empty. This is the whole contract between gameplay and the character's
## appearance — the visual layer maps each key to an LPC piece on its own (see
## LpcEquipment), so adding a new armour never touches this file.
func get_visual_loadout() -> Dictionary:
	return {
		"armor": str(_armor_def.get("visual_state", "")),
		"legs": str(_legs_def.get("visual_state", "")),
		"feet": str(_feet_def.get("visual_state", "")),
		"arms": str(_arms_def.get("visual_state", "")),
		"gloves": str(_gloves_def.get("visual_state", "")),
		"shoulders": str(_shoulders_def.get("visual_state", "")),
		"wrists": str(_wrists_def.get("visual_state", "")),
		"helmet": str(_helmet_def.get("visual_state", "")),
		"weapon": str(_weapon_def.get("visual_state", "")),
		"secondary": str(_secondary_def.get("visual_state", "")),
	}


## Pushes the current loadout to the presentation layer. Called after every
## equip; a slot whose art has not been made yet simply draws nothing.
func _sync_equipment_visuals() -> void:
	if visual == null:
		return
	var loadout := get_visual_loadout()
	for slot in loadout:
		visual.set_equipment(slot, str(loadout[slot]))


func use_consumable(item_id: String) -> bool:
	if not ItemDB.is_consumable(item_id):
		return false
	if inventory == null:
		return false
	var def := ItemDB.get_item(item_id)
	var heal := float(def.get("heal", 0.0))
	var restore := float(def.get("restore_mana", 0.0))
	if inventory.remove_item(item_id, 1) < 1:
		return false
	if heal > 0.0 and health:
		health.heal(heal)
	if restore > 0.0:
		mana = minf(MAX_MANA, mana + restore)
	_last_defense_msg = "Used %s" % str(def.get("name", item_id))
	_emit_stats()
	Game.inventory_changed.emit(inventory)
	return true


func get_weapon_name() -> String:
	if _weapon_item == "":
		return "Fists"
	return str(_weapon_def.get("name", _weapon_item))


func get_armor_name() -> String:
	return str(_armor_def.get("name", _armor_item)) if _armor_item != "" else "None"


func get_helmet_name() -> String:
	return str(_helmet_def.get("name", _helmet_item)) if _helmet_item != "" else "None"


func get_secondary_name() -> String:
	return str(_secondary_def.get("name", _secondary_item)) if _secondary_item != "" else "None"


func try_craft(recipe_id: String) -> bool:
	if inventory == null:
		return false
	var recipe := CraftDB.get_recipe(recipe_id)
	if recipe.is_empty():
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	for item_id in inputs:
		if inventory.count_item(str(item_id)) < int(inputs[item_id]):
			_last_defense_msg = "Missing materials"
			if Game.has_method("toast"):
				Game.toast("Missing materials for %s" % str(recipe.get("name", recipe_id)))
			_emit_stats()
			return false
	for item_id in inputs:
		inventory.remove_item(str(item_id), int(inputs[item_id]))
	var out_id := str(recipe.get("output_id", ""))
	var out_amt := int(recipe.get("output_amount", 1))
	inventory.add_item(out_id, out_amt)
	_last_defense_msg = "Crafted %s" % ItemDB.display_name(out_id)
	if Game.has_method("toast"):
		Game.toast("Crafted %s" % ItemDB.display_name(out_id))
	_emit_stats()
	Game.inventory_changed.emit(inventory)
	return true


func _on_inventory_changed() -> void:
	_emit_stats()
	Game.inventory_changed.emit(inventory)


func _on_item_added(_item_id: String, _amount: int) -> void:
	pass


func _emit_stats() -> void:
	var lv := 1
	var xp_v := 0
	var xp_next := 50
	var gold_v := 0
	if progress:
		lv = progress.level
		xp_v = progress.xp
		xp_next = progress.xp_to_next_level()
	if inventory:
		gold_v = inventory.gold
	Game.player_stats_changed.emit(
		health.hp,
		health.max_hp,
		stamina,
		MAX_STAMINA,
		mana,
		MAX_MANA,
		"%s / %s / %s" % [_kit_name(), _style_name(), get_weapon_name()],
		_last_defense_msg,
		lv,
		xp_v,
		xp_next,
		gold_v
	)


func _kit_name() -> String:
	match kit:
		Kit.WARRIOR:
			return "WARRIOR"
		Kit.MAGE:
			return "MAGE"
		Kit.ARCHER:
			return "ARCHER"
	return "?"


## What the HUD shows: the style actually in force, not the one selected. With
## an empty off-hand you are parrying whether you picked SHIELD or not.
func _style_name() -> String:
	match effective_defend_style():
		DefendStyle.SHIELD:
			return "SHIELD"
		DefendStyle.PARRY:
			return "PARRY"
		DefendStyle.ENERGY:
			return "ENERGY"
	return "?"


func _show_charge_fx() -> void:
	if charge_fx:
		charge_fx.visible = true


func _hide_charge_fx() -> void:
	if charge_fx:
		charge_fx.visible = false


func _update_charge_fx() -> void:
	if not charge_fx:
		return
	var t := clampf(_charge_time / CHARGE_MAX, 0.0, 1.0)
	var is_ready := _charge_time >= CHARGE_MIN
	charge_fx.scale = Vector2.ONE * (0.6 + t * 0.8)
	if kit == Kit.MAGE:
		charge_fx.color = Color(0.45, 0.55 + 0.35 * t, 1.0, 0.35 + 0.4 * t) if is_ready else Color(0.5, 0.55, 0.8, 0.25 + t * 0.2)
	elif kit == Kit.ARCHER:
		charge_fx.color = Color(0.5 + 0.4 * t, 0.85, 0.35, 0.35 + 0.4 * t) if is_ready else Color(0.55, 0.65, 0.4, 0.25 + t * 0.2)
	else:
		charge_fx.color = Color(1.0, 0.5 + 0.4 * t, 0.2, 0.35 + 0.4 * t) if is_ready else Color(0.7, 0.7, 0.8, 0.25 + t * 0.2)


func _show_guard_fx() -> void:
	if guard_fx:
		guard_fx.visible = true


func _hide_guard_fx() -> void:
	if guard_fx:
		guard_fx.visible = false


func _update_guard_fx() -> void:
	if not guard_fx:
		return
	match effective_defend_style():
		DefendStyle.SHIELD:
			guard_fx.color = Color(0.55, 0.75, 1.0, 0.55 if _parry_active else 0.35)
			guard_fx.scale = Vector2(1.15, 1.15) if _parry_active else Vector2.ONE
		DefendStyle.PARRY:
			guard_fx.color = Color(1.0, 0.95, 0.4, 0.65 if _parry_active else 0.15)
			guard_fx.scale = Vector2(1.2, 1.2) if _parry_active else Vector2(0.8, 0.8)
		DefendStyle.ENERGY:
			guard_fx.color = Color(0.55, 0.4, 1.0, 0.5)
			guard_fx.scale = Vector2(1.25, 1.25)


func _update_visuals() -> void:
	match state:
		State.FREE:
			if kit == Kit.MAGE:
				body_sprite.color = Color(0.55, 0.55, 0.95)
			elif kit == Kit.ARCHER:
				body_sprite.color = Color(0.45, 0.7, 0.45)
			else:
				body_sprite.color = Color(0.45, 0.72, 0.95)
		State.CHARGE:
			if kit == Kit.MAGE:
				body_sprite.color = Color(0.7, 0.55, 0.95)
			elif kit == Kit.ARCHER:
				body_sprite.color = Color(0.7, 0.85, 0.4)
			else:
				body_sprite.color = Color(0.95, 0.7, 0.4)
		State.GUARD:
			match effective_defend_style():
				DefendStyle.SHIELD:
					body_sprite.color = Color(0.5, 0.65, 0.95)
				DefendStyle.PARRY:
					body_sprite.color = Color(0.95, 0.9, 0.5) if _parry_active else Color(0.7, 0.7, 0.55)
				DefendStyle.ENERGY:
					body_sprite.color = Color(0.65, 0.5, 0.95)
		State.DODGE:
			body_sprite.color = Color(0.7, 0.9, 1.0)
		_:
			pass

	_update_hero_sprite()

	if Game.debug_hitboxes and kit == Kit.WARRIOR:
		hitbox.modulate = Color(1, 0.2, 0.2, 0.45) if hitbox._active else Color(1, 1, 1, 0)


## Tells the presentation layer what the simulation already decided. It does not
## pick textures, frames or flips — CharacterVisual owns all of that. The only
## thing that crosses over is timing, and only in this direction: the real
## gameplay window is handed to the animation so the two line up. The frame
## never feeds back into damage (see docs/ARQUITECTURA.md).
func _update_hero_sprite() -> void:
	var move_dir := _get_move_input()
	# Walking faces where the feet are going; attacking/charging faces the
	# mouse aim instead (mouse jitters far more than movement input, which
	# was resetting the walk animation constantly and looked like floating).
	var orient_dir := move_dir
	match state:
		State.ATTACK, State.CHARGE:
			orient_dir = _locked_facing if _aim_locked else facing
		State.DODGE:
			orient_dir = _dodge_dir

	facing_dir = CharacterFacing.from_vector(orient_dir, facing_dir)
	visual.set_direction(facing_dir)

	var anim: StringName = &"idle"
	var duration := 0.0
	match state:
		State.DODGE:
			anim = &"dash"
			duration = DODGE_DURATION
		State.DEAD:
			anim = &"death"
		State.CAST:
			# The skill picks its own animation; the weapon does not.
			anim = StringName(str(SkillDB.get_skill(_casting_skill).get("anim", "attack_cast")))
			duration = SkillDB.duration_of(_casting_skill)
		State.ATTACK:
			# The weapon decides HOW the character attacks: a sword slashes, a
			# spear thrusts, a staff casts, a bow shoots. Unarmed falls back to
			# the slash. See ItemDB.attack_anim.
			anim = ItemDB.attack_anim(_weapon_item)
			duration = _attack_startup + _attack_active + _attack_recovery
		_:
			anim = &"walk" if move_dir.length_squared() > 0.01 else &"idle"
	# One-shot animations restart on every fresh entry into the state, so the
	# second hit of a combo replays from frame 0 instead of continuing the
	# previous swing.
	var restart := state != _visual_last_state
	_visual_last_state = state
	visual.play(anim, restart and duration > 0.0, duration)

	visual.set_tint(Color(3, 3, 3) if state == State.HURT else Color.WHITE)


func respawn(pos: Vector2) -> void:
	global_position = pos
	health.is_dead = false
	health.hp = health.max_hp
	stamina = MAX_STAMINA
	mana = MAX_MANA
	state = State.FREE
	modulate.a = 1.0
	_hide_guard_fx()
	_hide_charge_fx()
	health.health_changed.emit(health.hp, health.max_hp)

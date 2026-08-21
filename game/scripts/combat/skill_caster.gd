class_name SkillCaster
extends Node
## Runs a skill's timeline for whoever owns it. Knows nothing about any specific
## skill — everything comes from SkillDB, so a new skill is a row of data.
##
## Deliberately NOT part of player.gd: that file is already large, and mobs will
## want to cast the same way.
##
## THE CAST IS AN INPUT COMMAND
## `cast()` takes the world point the player clicked and, for point-and-click,
## the click is resolved HERE against what is actually under it. Nothing is
## locked on in advance. That keeps the whole thing re-resolvable by a server
## later: the client sends "skill X at position P", the server decides what it
## hit (docs/ARQUITECTURA.md).
##
## TIMING IS IN SECONDS. The animation is stretched onto the window, never the
## other way round, so a skill never depends on a frame count.

signal cast_started(skill_id: String, duration: float)
signal cast_landed(skill_id: String)
signal cast_finished(skill_id: String)
## Emitted when a ground AoE is committed, so the world can show the telegraph.
signal telegraph_placed(skill_id: String, position: Vector2, radius: float, delay: float)

enum Phase { IDLE, STARTUP, ACTIVE, RECOVERY }

const ProjectileScene := preload("res://scenes/combat/projectile.tscn")

var caster: Node2D = null
var team: StringName = &"player"

var _skill_id: String = ""
var _phase: Phase = Phase.IDLE
var _elapsed: float = 0.0
var _landed: bool = false
var _aim_point: Vector2 = Vector2.ZERO
var _cooldowns: Dictionary = {}


func setup(p_caster: Node2D, p_team: StringName) -> void:
	caster = p_caster
	team = p_team


func _physics_process(delta: float) -> void:
	for id in _cooldowns:
		_cooldowns[id] = maxf(0.0, float(_cooldowns[id]) - delta)
	if _phase == Phase.IDLE:
		return
	_elapsed += delta
	var s := SkillDB.get_skill(_skill_id)
	var startup := float(s.get("startup", 0.0))
	var active := float(s.get("active", 0.0))
	if _elapsed < startup:
		_phase = Phase.STARTUP
	elif _elapsed < startup + active:
		if not _landed:
			_landed = true
			_resolve(s)
			cast_landed.emit(_skill_id)
		_phase = Phase.ACTIVE
	elif _elapsed < SkillDB.duration_of(_skill_id):
		_phase = Phase.RECOVERY
	else:
		var done := _skill_id
		_skill_id = ""
		_phase = Phase.IDLE
		cast_finished.emit(done)


# ------------------------------------------------------------------ queries


func is_casting() -> bool:
	return _phase != Phase.IDLE


func current_skill() -> String:
	return _skill_id


func cooldown_left(skill_id: String) -> float:
	return float(_cooldowns.get(skill_id, 0.0))


func is_ready(skill_id: String) -> bool:
	return SkillDB.has_skill(skill_id) and cooldown_left(skill_id) <= 0.0 and not is_casting()


# -------------------------------------------------------------------- cast


## Begin a cast. `aim_point` is where the player clicked, in world space.
## Returns false and changes nothing when it cannot be cast.
##
## `spend` is called with the skill dict so the owner can charge mana/stamina
## and refuse; it returns false to abort. Cost is spent HERE, not on hit, so a
## whiff still costs.
func cast(skill_id: String, aim_point: Vector2, spend: Callable = Callable()) -> bool:
	if not is_ready(skill_id):
		return false
	var s := SkillDB.get_skill(skill_id)
	if s.is_empty() or caster == null:
		return false

	# Out-of-range casts are refused rather than fizzling, so the resource is
	# not eaten by a misclick on the far side of the map.
	var max_range := float(s.get("cast_range", 0.0))
	if max_range > 0.0 and caster.global_position.distance_to(aim_point) > max_range:
		return false

	if spend.is_valid() and not bool(spend.call(s)):
		return false

	_skill_id = skill_id
	_aim_point = aim_point
	_elapsed = 0.0
	_landed = false
	_phase = Phase.STARTUP
	_cooldowns[skill_id] = float(s.get("cooldown", 0.0))
	cast_started.emit(skill_id, SkillDB.duration_of(skill_id))
	return true


# ---------------------------------------------------------------- resolution


func _resolve(s: Dictionary) -> void:
	match SkillDB.targeting_of(_skill_id):
		SkillDB.Targeting.SELF:
			var radius := float(s.get("radius", 32.0))
			_hit_circle(caster.global_position, radius, s)
			_spawn_impact_vfx(s, caster.global_position, radius)
		SkillDB.Targeting.TARGET:
			_resolve_click(s)
		SkillDB.Targeting.GROUND_AOE:
			_resolve_ground(s)
		SkillDB.Targeting.SKILLSHOT:
			_fire_projectiles(s)


## Point-and-click, AO style: whatever the click actually landed on takes the
## hit. Nothing was locked on, so a target that moved out from under the cursor
## simply is not there — the cast is spent and nothing happens. That miss is the
## counterplay, and `click_slack` is how forgiving it is.
func _resolve_click(s: Dictionary) -> void:
	var slack := float(s.get("click_slack", 12.0))
	var victim := _nearest_hurtbox(_aim_point, slack)
	if victim == null:
		return
	victim.apply_hit(_hit_data(s, (victim.global_position - caster.global_position).normalized()))


## Committed at the click, but it lands after `telegraph` seconds — long enough
## to be walked out of. The world draws the warning; we only hit what is still
## standing there when it goes off.
func _resolve_ground(s: Dictionary) -> void:
	var radius := float(s.get("radius", 48.0))
	var delay := float(s.get("telegraph", 0.0))
	telegraph_placed.emit(_skill_id, _aim_point, radius, delay)
	if delay <= 0.0:
		_hit_circle(_aim_point, radius, s)
		_spawn_impact_vfx(s, _aim_point, radius)
		return
	var where := _aim_point
	var snapshot := s.duplicate()
	get_tree().create_timer(delay).timeout.connect(
		func():
			if is_instance_valid(caster):
				_hit_circle(where, radius, snapshot)
				_spawn_impact_vfx(snapshot, where, radius))


## Optional sprite dropped where the hit actually landed. Spawned after
## `_hit_circle` on purpose — resolution never depends on whether it exists.
func _spawn_impact_vfx(s: Dictionary, pos: Vector2, radius: float) -> void:
	var effect_id := str(s.get("impact_vfx", ""))
	if effect_id != "":
		SkillImpactFx.spawn(pos, effect_id, radius)


func _fire_projectiles(s: Dictionary) -> void:
	var dir := (_aim_point - caster.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var count := maxi(1, int(s.get("projectile_count", 1)))
	var spread := deg_to_rad(float(s.get("spread_deg", 0.0)))

	# If the shot isn't stopped first (wall, or used up its pierce), it still
	# lands a small burst at the very end of its travel — arcane_bolt's "pierce
	# the first enemy, splash where it finally runs out of range".
	var end_burst := {}
	var end_radius := float(s.get("end_radius", 0.0))
	if end_radius > 0.0:
		end_burst = {
			"radius": end_radius,
			"damage": _damage(s) * float(s.get("end_damage_mul", 0.0)),
			"poise": float(s.get("end_poise_damage", 0.0)),
			"effect": str(s.get("end_vfx", "")),
		}

	for i in count:
		var offset := 0.0
		if count > 1:
			offset = -spread * 0.5 + spread * (float(i) / float(count - 1))
		var proj: Node = Game.spawn(ProjectileScene, caster.global_position, null)
		proj.setup(dir.rotated(offset), team, _damage(s),
			float(s.get("poise_damage", 0.0)),
			float(s.get("projectile_speed", 320.0)),
			float(s.get("projectile_life", 1.4)),
			caster, s.get("color", Color.WHITE), float(s.get("radius", 6.0)),
			int(s.get("pierce", 0)), float(s.get("pierce_falloff", 0.0)),
			str(s.get("visual_effect", "")), float(s.get("visual_scale", 1.0)),
			end_burst)


## Everything inside the circle takes the hit. Used by SELF skills around the
## caster and by ground AoEs at their landing point.
func _hit_circle(centre: Vector2, radius: float, s: Dictionary) -> void:
	for hurtbox in _hurtboxes_in(centre, radius):
		hurtbox.apply_hit(_hit_data(s, (hurtbox.global_position - centre).normalized()))


func _hit_data(s: Dictionary, dir: Vector2) -> Dictionary:
	var data := {
		"damage": _damage(s),
		"poise_damage": float(s.get("poise_damage", 0.0)),
		"knockback": float(s.get("knockback", 0.0)),
		"hit_stun": float(s.get("hit_stun", 0.0)),
		"direction": dir,
		"team": team,
		"source": caster,
		"swing_id": _skill_id,
	}
	# Only a skill that asks for it interrupts — a basic attack never does.
	# See docs/COMBATE.md ("Interrupción").
	if bool(s.get("interrupt", false)):
		data["interrupt"] = true
	return data


func _damage(s: Dictionary) -> float:
	var base := 10.0
	if caster and caster.has_method("_melee_base_damage"):
		base = float(caster._melee_base_damage())
	return base * float(s.get("damage_mul", 1.0))


## Hurtboxes of the opposing team within a radius. Goes through Game rather than
## the scene tree, per the netcode contract.
func _hurtboxes_in(centre: Vector2, radius: float) -> Array:
	var out: Array = []
	var space := caster.get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, centre)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	# Hurtboxes of both teams sit on the body layers; the team check below is
	# what actually decides friend from foe.
	params.collision_mask = 0xFFFFFFFF
	for hit in space.intersect_shape(params, 32):
		var area = hit.get("collider")
		if area is Hurtbox and area.has_method("apply_hit"):
			if area.team != team:
				out.append(area)
	return out


func _nearest_hurtbox(point: Vector2, slack: float) -> Hurtbox:
	var best: Hurtbox = null
	var best_d := INF
	for h in _hurtboxes_in(point, slack):
		var d: float = h.global_position.distance_to(point)
		if d < best_d:
			best_d = d
			best = h
	return best

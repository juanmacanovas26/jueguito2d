extends Node
## Headless coverage of the gameplay systems that have to keep working while
## the art gets replaced: static data integrity, the damage pipeline, the
## inventory and crafting. Progression-by-use (Skills) has its own suite,
## tools/validate_skills.gd.
##
##   Godot_v4.7.1-stable_win64_console.exe --headless --path game \
##       res://tools/validate_systems.tscn
##
## Exits 0 when everything passes, 1 otherwise.

const PLAYER_SCENE := "res://scenes/player/player.tscn"

## Floor for how many checks this suite must run (see _check_ran_enough).
const MIN_CHECKS := 150

var _failures: Array = []
var _checks := 0


func _ready() -> void:
	await _run()


func _run() -> void:
	print("== validate_systems ==")
	_check_data_integrity()
	await _check_damage_pipeline()
	await _check_inventory()
	await _check_crafting()
	await _check_basic_attacks_never_interrupt()
	await _check_mob_sleep()
	await _check_archer_needs_bow()
	await _check_skills()
	await _check_skill_aiming()
	await _check_open_skill_network()
	await _check_discovery()
	await _check_gm_mode_and_build_zoom()
	await _check_architecture_contract()

	_check_ran_enough()
	print("\n-- %d checks, %d failures --" % [_checks, _failures.size()])
	for f in _failures:
		print("FAIL: " + f)
	print("RESULT: " + ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _ok(label: String) -> void:
	_checks += 1
	print("  ok   " + label)


func _fail(label: String) -> void:
	_checks += 1
	_failures.append(label)
	print("  FAIL " + label)


func _expect(cond: bool, label: String) -> void:
	if cond:
		_ok(label)
	else:
		_fail(label)


## Sections announce themselves so the numbering stays right when one is added.
var _sections: int = 0


func _section(name: String) -> void:
	_sections += 1
	print("\n[%d] %s" % [_sections, name])


## A suite that only counts the checks it MANAGED to run will happily report
## PASS after a section died half way through — which is exactly how a broken
## player.gd once slipped past with 57 of 164 checks. The floor below turns
## "far fewer checks than usual ran" into a failure. Raise it as the suite
## grows; it can only ever fail safe.
func _check_ran_enough() -> void:
	if _checks < MIN_CHECKS:
		_fail("only %d checks ran but at least %d are expected — a section aborted early"
			% [_checks, MIN_CHECKS])



func _spawn() -> Node:
	var p = load(PLAYER_SCENE).instantiate()
	add_child(p)
	await get_tree().physics_frame
	p.inventory.clear()
	for slot in DataIntegrity.EQUIPPABLE_TYPES:
		p.unequip(slot)
	p.inventory.clear()
	return p


# ------------------------------------------------------------------ checks


func _check_data_integrity() -> void:
	print("\n[1] Static data integrity")
	var problems := DataIntegrity.check()
	_expect(problems.is_empty(), "ItemDB + CraftDB are coherent (%d problems)" % problems.size())
	for p in problems:
		print("       -> " + str(p))

	# The checker itself has to be able to fail, or it proves nothing.
	_expect(DataIntegrity.VALID_TYPES.has("weapon"), "the type whitelist covers equipment")
	_expect(not DataIntegrity.VALID_TYPES.has("wepon"), "a typo'd type would not be accepted")

	# Every equippable resolves through the whole visual chain.
	for id in ItemDB.ITEMS:
		var def: Dictionary = ItemDB.ITEMS[id]
		if not DataIntegrity.EQUIPPABLE_TYPES.has(str(def.get("type", ""))):
			continue
		var slot := str(def["type"])
		var vs := str(def.get("visual_state", ""))
		# Resolving must never crash or invent a piece, whether or not LPC art
		# exists for this item yet.
		var piece := LpcEquipment.piece_for(slot, vs)
		_expect(piece == "" or LpcLibrary.has_piece(piece),
			"'%s' maps to a bundled LPC piece or to nothing, never garbage (got '%s')" % [id, piece])


func _check_damage_pipeline() -> void:
	print("\n[2] Damage pipeline: hitbox -> hurtbox -> guard -> armour -> health")
	var p = await _spawn()
	var hp0: float = p.health.hp

	# A plain hit lands in full.
	p.hurtbox.apply_hit({"damage": 20.0, "team": &"enemy", "poise_damage": 5.0})
	_expect(is_equal_approx(p.health.hp, hp0 - 20.0),
		"an unguarded hit removes exactly its damage (%.1f -> %.1f)" % [hp0, p.health.hp])

	# Armour reduces it.
	p.health.hp = hp0
	p.inventory.add_item("plate_armor", 1)
	p.equip_armor("plate_armor")
	p.hurtbox.apply_hit({"damage": 20.0, "team": &"enemy"})
	var armored_loss: float = hp0 - p.health.hp
	_expect(armored_loss < 20.0 and armored_loss > 0.0,
		"armour reduces but does not cancel the hit (%.1f lost)" % armored_loss)

	# i-frames cancel it entirely.
	p.health.hp = hp0
	p._set_iframe(true)
	p.hurtbox.apply_hit({"damage": 20.0, "team": &"enemy"})
	_expect(is_equal_approx(p.health.hp, hp0), "i-frames cancel the hit completely")
	p._set_iframe(false)

	# Death fires once and further hits do nothing.
	p.health.hp = 5.0
	var deaths := [0]
	p.health.died.connect(func(): deaths[0] += 1)
	p.hurtbox.apply_hit({"damage": 999.0, "team": &"enemy"})
	_expect(p.health.is_dead and deaths[0] == 1, "lethal damage kills once")
	p.hurtbox.apply_hit({"damage": 999.0, "team": &"enemy"})
	_expect(deaths[0] == 1, "hitting a corpse does not fire death again")
	_expect(p.health.hp >= 0.0, "hp never goes negative (%.1f)" % p.health.hp)

	# Healing a corpse is refused.
	p.health.heal(50.0)
	_expect(p.health.hp <= 0.0, "a dead entity cannot be healed back up")
	p.free()


func _check_inventory() -> void:
	print("\n[3] Inventory")
	var p = await _spawn()
	var inv = p.inventory

	# Stacking respects the item's stack size.
	var stack: int = int(ItemDB.get_item("iron_ore").get("stack", 99))
	inv.add_item("iron_ore", stack + 5)
	_expect(inv.count_item("iron_ore") == stack + 5,
		"items beyond one stack still all arrive (%d)" % inv.count_item("iron_ore"))
	_expect(inv.get_filled_slots().size() == 2,
		"and they spill into a second slot (%d used)" % inv.get_filled_slots().size())

	# Removing more than you have removes only what is there.
	var removed: int = inv.remove_item("iron_ore", 9999)
	_expect(removed == stack + 5, "remove_item returns how many it actually took (%d)" % removed)
	_expect(inv.count_item("iron_ore") == 0, "and the item is gone")
	_expect(inv.get_filled_slots().is_empty(), "emptied slots are released")

	# Gold is not a slot item.
	inv.clear()
	inv.add_item("gold_coin", 500)
	_expect(inv.gold == 500 and inv.get_filled_slots().is_empty(),
		"gold goes to the purse, not to a slot")
	_expect(inv.count_item("gold_coin") == 500, "and count_item reports the purse")

	# A full bag rejects new items instead of silently dropping them.
	inv.clear()
	for i in inv.max_slots:
		inv.add_item("dagger", 1)
	_expect(inv.get_filled_slots().size() == inv.max_slots, "the bag filled up")
	_expect(not inv.has_space_for("iron_ore", 1), "has_space_for says there is no room")
	var added: int = inv.add_item("iron_ore", 1)
	_expect(added == 0 and inv.count_item("iron_ore") == 0,
		"adding to a full bag adds nothing and reports 0")

	# Negative / zero amounts are refused.
	inv.clear()
	_expect(inv.add_item("iron_ore", 0) == 0, "adding 0 does nothing")
	_expect(inv.add_item("iron_ore", -5) == 0, "adding a negative amount does nothing")
	_expect(inv.count_item("iron_ore") == 0, "and nothing appeared")
	p.free()


func _check_crafting() -> void:
	print("\n[4] Crafting")
	var p = await _spawn()
	var inv = p.inventory

	var recipe := CraftDB.get_recipe("arming_sword")
	_expect(not recipe.is_empty(), "the iron_sword recipe exists")
	var inputs: Dictionary = recipe.get("inputs", {})

	# Without materials it must refuse and consume nothing.
	_expect(not p.try_craft("arming_sword"), "crafting without materials fails")
	_expect(inv.count_item("arming_sword") == 0, "and produces nothing")

	# With exactly the materials it succeeds and consumes them.
	for item_id in inputs:
		inv.add_item(str(item_id), int(inputs[item_id]))
	_expect(p.try_craft("arming_sword"), "crafting with exact materials succeeds")
	_expect(inv.count_item("arming_sword") == int(recipe.get("output_amount", 1)),
		"the output landed in the bag")
	for item_id in inputs:
		_expect(inv.count_item(str(item_id)) == 0,
			"input '%s' was consumed" % str(item_id))

	# One material short must not partially consume.
	inv.clear()
	var first := ""
	for item_id in inputs:
		first = str(item_id)
		break
	for item_id in inputs:
		if str(item_id) != first:
			inv.add_item(str(item_id), int(inputs[item_id]))
	_expect(not p.try_craft("arming_sword"), "one material short fails")
	for item_id in inputs:
		if str(item_id) != first:
			_expect(inv.count_item(str(item_id)) == int(inputs[item_id]),
				"'%s' was NOT consumed by the failed craft" % str(item_id))

	_expect(not p.try_craft("does_not_exist"), "an unknown recipe fails safely")
	p.free()


## DESIGN RULE (docs/COMBATE.md, "Interrupción"): a basic attack must never
## interrupt anyone. Interruption comes only from effects that ask for it.
## This locks that in — wiring poise into the damage path would fail here.
func _check_basic_attacks_never_interrupt() -> void:
	print("\n[6] Basic attacks never interrupt")
	var p = await _spawn()
	p.state = p.State.ATTACK
	p._attack_startup = 0.10
	p._attack_active = 0.08
	p._attack_recovery = 0.18
	var poise0: float = p.health.poise

	# Hammer it with enough poise damage to bottom the bar out several times.
	for i in 12:
		p.hurtbox.apply_hit({"damage": 1.0, "team": &"enemy", "poise_damage": 50.0})

	_expect(p.health.poise <= 0.0,
		"the poise bar does bottom out under sustained hits (%.1f -> %.1f)" % [poise0, p.health.poise])
	_expect(p.health.is_staggered(),
		"is_staggered() reports the broken poise, for future interrupt effects")
	_expect(p.state == p.State.ATTACK,
		"the player's swing is NOT cancelled: still in ATTACK (got %s)" % p.state)

	# A charge must survive too.
	p.health.poise = p.health.max_poise
	p.state = p.State.CHARGE
	p.hurtbox.apply_hit({"damage": 1.0, "team": &"enemy", "poise_damage": 50.0})
	_expect(p.state == p.State.CHARGE, "a charge is not cancelled by a basic hit")

	# But a hit while idle still flinches — that is feedback, not interruption.
	p.state = p.State.FREE
	p.hurtbox.apply_hit({"damage": 1.0, "team": &"enemy"})
	_expect(p.state == p.State.HURT,
		"an idle target still flinches (nothing was interrupted)")

	# The same must hold for a mob, which has its own state machine.
	var mob = load("res://scenes/enemy/chase_mob.tscn").instantiate()
	add_child(mob)
	await get_tree().physics_frame
	mob.ai = mob.AIState.ATTACK
	mob._attack_t = 0.0
	mob._hitbox_on = true
	for i in 12:
		mob.hurtbox.apply_hit({"damage": 1.0, "team": &"player", "poise_damage": 50.0})
	_expect(mob.health.poise <= 0.0, "a mob's poise also bottoms out")
	_expect(mob.ai == mob.AIState.ATTACK,
		"the mob's swing is NOT cancelled mid-attack (got %s)" % mob.ai)
	_expect(mob._hitbox_on, "and its hitbox stays active through the hits")
	mob.free()

	# And no basic attack may tag its payload as an interrupt.
	var player_src := FileAccess.get_file_as_string("res://scripts/player/player.gd")
	_expect(not player_src.contains("\"interrupt\""),
		"player.gd does not tag any basic attack as an interrupt")

	# Nothing in the damage path may consult is_staggered() to change state.
	for path in ["res://scripts/combat/hurtbox.gd", "res://scripts/combat/hitbox.gd",
			"res://scripts/player/player.gd", "res://scripts/enemy/chase_mob.gd"]:
		var src := FileAccess.get_file_as_string(path)
		_expect(not src.contains("is_staggered"),
			"%s does not turn broken poise into a state change" % path.get_file())
	p.free()


## Mobs sleep when the player is far away (chase_mob.gd's sleep_range), which
## is what lets a zone hold hundreds of them. The danger of an optimization
## like this is that it changes behaviour: a sleeping mob that ignores a
## ranged hit, or one that dozes off mid-chase and freezes in a field, is a
## worse bug than the cost it saves. These checks pin exactly that.
func _check_mob_sleep() -> void:
	_section("Mobs sleep far from the player and wake correctly")
	var p = await _spawn()
	p.global_position = Vector2.ZERO

	var mob = load("res://scenes/enemy/chase_mob.tscn").instantiate()
	add_child(mob)
	mob.global_position = Vector2(5000, 0) # far outside any sleep_range
	mob._home = mob.global_position
	await get_tree().physics_frame

	_expect(mob.sleep_range > mob.deaggro_range and mob.sleep_range > mob.leash_range,
		"sleep_range is clamped outside deaggro/leash (%.0f vs %.0f/%.0f)"
		% [mob.sleep_range, mob.deaggro_range, mob.leash_range])

	# A few frames of standing at home with nobody near is enough to doze off.
	for i in 12:
		await get_tree().physics_frame
	_expect(mob._asleep, "an idle mob far from the player falls asleep")
	_expect(not mob.is_processing(), "  and stops its per-frame _process() work")

	# Asleep is not the same as gone: it must still be solid and hittable.
	_expect(mob.get_collision_layer_value(3), "  but stays solid (collision untouched)")
	_expect(mob.hurtbox.collision_layer != 0, "  and stays hittable")

	# A ranged hit from outside sleep_range has to wake it AND aggro it,
	# otherwise a sleeping mob just absorbs arrows without reacting.
	var hp_before: float = mob.health.hp
	mob.hurtbox.apply_hit({"damage": 5.0, "team": &"player"})
	_expect(not mob._asleep, "a hit from beyond sleep_range wakes it")
	_expect(mob.health.hp < hp_before, "  the damage lands (%.0f -> %.0f)" % [hp_before, mob.health.hp])
	# HURT, not CHASE: a hit flinches first and CHASE comes after the flinch
	# window. What matters here is that it left IDLE and is running its state
	# machine again instead of absorbing arrows asleep.
	_expect(mob.ai == mob.AIState.HURT, "  and it reacts (HURT) instead of standing there (got %s)" % mob.ai)

	# Walking up to it wakes it within the staggered check window.
	mob.ai = mob.AIState.IDLE
	mob.global_position = mob._home
	mob.velocity = Vector2.ZERO
	for i in 12:
		await get_tree().physics_frame
	_expect(mob._asleep, "it goes back to sleep once idle at home again")
	p.global_position = mob._home + Vector2(mob.aggro_range * 0.5, 0)
	for i in mob.WAKE_CHECK_FRAMES + 3:
		await get_tree().physics_frame
	_expect(not mob._asleep, "the player walking into range wakes it")
	_expect(mob.ai == mob.AIState.CHASE, "  and it aggros normally")

	# The rule that keeps it safe: never doze off while away from home.
	mob.ai = mob.AIState.CHASE
	mob.global_position = mob._home + Vector2(300, 0)
	p.global_position = Vector2(-9000, 0) # yank the player far away mid-chase
	for i in 12:
		await get_tree().physics_frame
	_expect(not mob._asleep,
		"a mob that lost its target far from home does NOT freeze there — it walks back first")

	mob.free()
	p.free()


## An archer bare-handed shouldn't be able to loose an arrow — the visual only
## exists because there's a real bow drawing a real arrow. Drives the actual
## input path (attack_light), not _start_arrow() directly, for the same reason
## the skill-aiming section does: the internal call can pass while the real
## key -> shot flow is broken.
func _check_archer_needs_bow() -> void:
	_section("Archer needs a bow + arrows to shoot")
	var p = await _spawn()
	p.kit = p.Kit.ARCHER
	p._apply_kit_defaults()
	p.state = p.State.FREE
	p.stamina = p.MAX_STAMINA
	await get_tree().physics_frame

	_expect(not p.has_bow(), "a fresh archer has no bow equipped")
	_expect(not p.has_arrows(), "  or arrows")

	# Bare-handed: pressing attack does nothing at all — not even a charge
	# windup for a shot that was never coming.
	Input.action_press("attack_light")
	await get_tree().physics_frame
	Input.action_release("attack_light")
	await get_tree().physics_frame
	_expect(p.state == p.State.FREE, "no bow/arrows: attack_light does nothing")

	# A bow alone is not enough — still needs arrows in the off-hand.
	p.inventory.add_item("slingshot", 1)
	p.equip_weapon("slingshot")
	await get_tree().physics_frame
	_expect(p.has_bow(), "equipping the slingshot counts as a bow (attack_shoot)")
	_expect(not p.has_arrows(), "  but there are still no arrows")
	Input.action_press("attack_light")
	await get_tree().physics_frame
	Input.action_release("attack_light")
	await get_tree().physics_frame
	_expect(p.state == p.State.FREE, "bow without arrows: still refused")

	# Both equipped: the shot actually goes out.
	p.inventory.add_item("quiver", 1)
	p.equip_secondary("quiver")
	await get_tree().physics_frame
	_expect(p.has_arrows(), "equipping the quiver counts as arrows")
	Input.action_press("attack_light")
	# just_pressed can take an extra frame to register in this harness (see
	# the other Input-driven sections) — press-and-immediately-check is a frame
	# too eager, so give it a second one before reading the CHARGE state.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(p.state == p.State.CHARGE, "bow + arrows: attack_light finally charges")
	Input.action_release("attack_light")
	await get_tree().physics_frame
	_expect(p.state == p.State.ATTACK, "  and releasing actually fires the shot")

	# multishot is gated the same way (requires_bow in SkillDB) — take the
	# quiver back off and it has to refuse too, without spending stamina.
	p.state = p.State.FREE
	p.unequip("secondary")
	p.stamina = p.MAX_STAMINA
	var caster: SkillCaster = p.get_node("SkillCaster")
	caster._cooldowns.clear()
	var cast_ok: bool = p._try_cast("multishot", p.global_position + Vector2(100, 0))
	_expect(not cast_ok, "multishot also refuses without arrows equipped")
	_expect(is_equal_approx(p.stamina, p.MAX_STAMINA), "  and costs nothing when refused")
	_expect(p._last_defense_msg == "No bow/arrows equipped",
		"  and warns the player why (got: '%s')" % p._last_defense_msg)

	# The aim preview itself must show the same warning while armed, not just
	# refuse silently on the click — this is what SkillAimer.blocked drives.
	p.aimer.arm("multishot")
	await get_tree().physics_frame
	_expect(p.aimer.blocked, "aiming multishot without arrows marks the aim as blocked")
	p.inventory.add_item("quiver", 1)
	p.equip_secondary("quiver")
	await get_tree().physics_frame
	_expect(not p.aimer.blocked, "  re-equipping the quiver clears it while still aiming")
	p.aimer.cancel()
	p.free()


## Skills are the core of the combat design, so the three targeting modes each
## get exercised end to end against a real dummy.
func _check_skills() -> void:
	_section("Skills: data, cost, cooldown and the three targeting modes")
	var p = await _spawn()
	var caster: SkillCaster = p.get_node("SkillCaster")

	# --- data integrity ---------------------------------------------------
	var bad: Array = []
	for id in SkillDB.SKILLS:
		var s: Dictionary = SkillDB.SKILLS[id]
		if not SkillDB.TARGETING_NAMES.has(str(s.get("targeting", ""))):
			bad.append("%s: unknown targeting '%s'" % [id, s.get("targeting")])
		if SkillDB.duration_of(str(id)) <= 0.0:
			bad.append("%s: zero duration" % id)
		if float(s.get("cooldown", 0.0)) <= 0.0:
			bad.append("%s: no cooldown" % id)
		if float(s.get("mana_cost", 0.0)) <= 0.0 and float(s.get("stamina_cost", 0.0)) <= 0.0:
			bad.append("%s: free to cast" % id)
	_expect(bad.is_empty(), "every skill is coherent (%d problems)" % bad.size())
	for b in bad:
		print("       -> " + str(b))

	# Every loadout entry must exist, and its animation must too.
	var set_res: CharacterVisualSet = load("res://resources/visuals/lpc_male_set.tres")
	for kit in SkillDB.LOADOUTS:
		for id in SkillDB.loadout_for(str(kit)):
			_expect(SkillDB.has_skill(str(id)), "'%s' loadout references '%s'" % [kit, id])
			var anim := StringName(str(SkillDB.get_skill(str(id)).get("anim", "")))
			_expect(set_res.get_animation(anim) != null,
				"  '%s' uses animation '%s', which exists" % [id, anim])

	# --- cost and cooldown -------------------------------------------------
	p.mana = p.MAX_MANA
	p.stamina = p.MAX_STAMINA
	var mana0: float = p.mana
	_expect(caster.is_ready("arcane_bolt"), "arcane_bolt starts ready")
	_expect(p._try_cast("arcane_bolt"), "casting it succeeds")
	_expect(p.mana < mana0, "and it charged mana (%.0f -> %.0f)" % [mana0, p.mana])
	_expect(p.state == p.State.CAST, "the player is locked into State.CAST")
	_expect(not caster.is_ready("arcane_bolt"), "it is on cooldown right after")
	_expect(not p._try_cast("frost_nova"), "and no second skill can start mid-cast")

	# The lock lasts exactly the skill's window, not an animation length.
	var dur := SkillDB.duration_of("arcane_bolt")
	var waited := 0.0
	while caster.is_casting() and waited < 3.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	_expect(absf(waited - dur) < 0.15,
		"the cast lasted its declared %.2fs (took %.2fs)" % [dur, waited])
	_expect(p.state == p.State.FREE, "and the player is free again")

	# A cast with no resource is refused and costs nothing.
	p.mana = 0.0
	var before: float = p.mana
	_expect(not p._try_cast("frost_nova"), "a skill you cannot afford is refused")
	_expect(is_equal_approx(p.mana, before), "and charges nothing")

	# --- the three modes, against a real target ----------------------------
	var dummy = load("res://scenes/enemy/chase_mob.tscn").instantiate()
	add_child(dummy)
	await get_tree().physics_frame
	dummy.global_position = p.global_position + Vector2(60, 0)
	dummy.health.max_hp = 9999.0
	dummy.health.hp = 9999.0
	await get_tree().physics_frame

	# TARGET: a click that lands damages; a click that misses does not.
	p.mana = p.MAX_MANA
	var hp_before: float = dummy.health.hp
	caster._skill_id = "smite"
	caster._aim_point = dummy.global_position
	caster._resolve(SkillDB.get_skill("smite"))
	_expect(dummy.health.hp < hp_before, "TARGET: a click on the enemy lands")

	hp_before = dummy.health.hp
	caster._aim_point = dummy.global_position + Vector2(400, 0)
	caster._resolve(SkillDB.get_skill("smite"))
	_expect(is_equal_approx(dummy.health.hp, hp_before),
		"TARGET: a click that misses does nothing — movement is the counter")

	# smite: cursor_only (no telegraph), unlimited range, and cost only sticks
	# on an actual hit — but the short retry cooldown applies either way.
	var smite_data := SkillDB.get_skill("smite")
	_expect(bool(smite_data.get("cursor_only", false)),
		"smite is cursor_only — SkillAimer draws nothing for it, just a cursor")
	p.mana = p.MAX_MANA
	var smite_mana0: float = p.mana
	var far_away: Vector2 = dummy.global_position + Vector2(5000, 0)
	_expect(p._try_cast("smite", far_away),
		"smite's cast_range is 0 (no cap) — even a very distant click is accepted")
	_expect(p.mana < smite_mana0, "the cost is charged immediately, like any other cast")
	await get_tree().create_timer(float(smite_data.get("startup", 0.2)) + 0.08).timeout
	_expect(is_equal_approx(p.mana, smite_mana0),
		"  but refunded in full once it resolves as a miss (it never actually 'launched')")
	_expect(not caster.is_ready("smite"),
		"  the retry cooldown still applies even though the cost refunded")

	await get_tree().create_timer(float(smite_data.get("cooldown", 1.0)) + 0.1).timeout
	_expect(caster.is_ready("smite"), "the retry cooldown is exactly the declared 1s, not the old 5s")
	var hp_before_smite: float = dummy.health.hp
	var mana_before_hit: float = p.mana
	_expect(p._try_cast("smite", dummy.global_position), "smite hits: the cast commits")
	await get_tree().create_timer(float(smite_data.get("startup", 0.2)) + 0.08).timeout
	_expect(dummy.health.hp < hp_before_smite, "  a real hit actually damages the enemy")
	_expect(p.mana < mana_before_hit, "  and the cost stays spent (no refund on a real hit)")
	await get_tree().create_timer(SkillDB.duration_of("smite") + 0.1).timeout

	# SELF: hits what is around the caster.
	hp_before = dummy.health.hp
	caster._skill_id = "whirlwind"
	caster._resolve(SkillDB.get_skill("whirlwind"))
	_expect(dummy.health.hp < hp_before, "SELF: whirlwind hits what is next to you")

	# GROUND_AOE: telegraphs first, and only hits what is still there.
	hp_before = dummy.health.hp
	var announced := [Vector2.ZERO, 0.0]
	caster.telegraph_placed.connect(func(_id, pos, _r, delay):
		announced[0] = pos
		announced[1] = delay)
	caster._skill_id = "frost_nova"
	caster._aim_point = dummy.global_position
	caster._resolve(SkillDB.get_skill("frost_nova"))
	_expect(announced[1] > 0.0, "GROUND_AOE: it announces a telegraph first (%.2fs)" % announced[1])
	_expect(is_equal_approx(dummy.health.hp, hp_before),
		"  and has NOT landed yet during the telegraph")
	# Walk out of it.
	dummy.global_position += Vector2(500, 0)
	await get_tree().create_timer(float(announced[1]) + 0.1).timeout
	_expect(is_equal_approx(dummy.health.hp, hp_before),
		"  walking out of the circle avoids it entirely")

	# SKILLSHOT: spawns travelling projectiles.
	var before_count := _count_projectiles()
	caster._skill_id = "multishot"
	caster._aim_point = p.global_position + Vector2(100, 0)
	caster._resolve(SkillDB.get_skill("multishot"))
	await get_tree().physics_frame
	_expect(_count_projectiles() > before_count,
		"SKILLSHOT: multishot spawns projectiles (%d -> %d)" % [before_count, _count_projectiles()])
	dummy.free()
	# multishot's own pellets are still travelling — let a fresh flight path
	# start clean instead of them clipping the next dummies.
	_free_all_projectiles()

	# arcane_bolt: pierces the first enemy (doesn't die on it), then — if
	# nothing else stops it — drops a small burst at the very end of its range.
	var near = load("res://scenes/enemy/chase_mob.tscn").instantiate()
	var far = load("res://scenes/enemy/chase_mob.tscn").instantiate()
	add_child(near)
	add_child(far)
	await get_tree().physics_frame
	var ab := SkillDB.get_skill("arcane_bolt")
	var travel: float = float(ab.get("projectile_speed", 320.0)) * float(ab.get("projectile_life", 1.4))
	near.global_position = p.global_position + Vector2(40, 0)
	# Off the flight line, inside end_radius of the final position but outside
	# the projectile's own collision radius — a hit here can ONLY be the burst.
	far.global_position = p.global_position + Vector2(travel - 5.0, 26.0)
	for d in [near, far]:
		d.health.max_hp = 9999.0
		d.health.hp = 9999.0
		# These are damage probes, not combatants — freeze their own chase/
		# return AI so they don't wander off their test position during the
		# ~1.5s real-time wait for the bolt to reach the end of its range.
		d.set_physics_process(false)
	await get_tree().physics_frame
	caster._skill_id = "arcane_bolt"
	caster._aim_point = p.global_position + Vector2(1, 0)
	caster._resolve(ab)
	# 40px at projectile_speed takes real time to travel — one physics frame
	# isn't enough for the bolt to have reached it yet.
	var near_dist: float = near.global_position.distance_to(p.global_position)
	var speed := float(ab.get("projectile_speed", 320.0))
	await get_tree().create_timer(near_dist / speed + 0.1).timeout
	_expect(near.health.hp < 9999.0, "arcane_bolt pierces the first enemy — it takes the direct hit")
	var direct_dmg: float = 9999.0 - near.health.hp
	_expect(_count_projectiles() > 0, "  and the bolt survives past that hit instead of dying on it")

	await get_tree().create_timer(float(ab.get("projectile_life", 1.4)) + 0.15).timeout
	_expect(far.health.hp < 9999.0,
		"  a small burst lands at the end of its range even with no second target in its path")
	var burst_dmg: float = 9999.0 - far.health.hp
	_expect(burst_dmg < direct_dmg,
		"  and it hits for less than the direct hit (%.1f < %.1f)" % [burst_dmg, direct_dmg])

	near.free()
	far.free()
	_free_all_projectiles()

	# The other way the burst can trigger: using up the pierce budget on a
	# SECOND enemy detonates right there, well before the end of the range —
	# it doesn't wait for the range to run out too.
	var sec_pierced = load("res://scenes/enemy/chase_mob.tscn").instantiate()
	var sec_target = load("res://scenes/enemy/chase_mob.tscn").instantiate()
	add_child(sec_pierced)
	add_child(sec_target)
	await get_tree().physics_frame
	sec_pierced.global_position = p.global_position + Vector2(40, 0)
	# On the flight line: the SECOND thing this bolt hits.
	sec_target.global_position = p.global_position + Vector2(90, 0)
	for d in [sec_pierced, sec_target]:
		d.health.max_hp = 9999.0
		d.health.hp = 9999.0
		d.set_physics_process(false)
	await get_tree().physics_frame

	caster._skill_id = "arcane_bolt"
	caster._aim_point = p.global_position + Vector2(1, 0)
	caster._resolve(ab)
	var sec_dist: float = sec_target.global_position.distance_to(p.global_position)
	await get_tree().create_timer(sec_dist / speed + 0.15).timeout
	_expect(sec_pierced.health.hp < 9999.0 and sec_target.health.hp < 9999.0,
		"a second enemy in its path also takes the hit (and the burst on top)")
	_expect(_count_projectiles() == 0,
		"  the bolt is gone — it detonated there instead of flying on to the end of its range")

	sec_pierced.free()
	sec_target.free()
	p.free()


func _count_projectiles() -> int:
	var n := 0
	for c in get_tree().root.get_children():
		n += _count_in(c)
	return n


func _count_in(node: Node) -> int:
	var n := 1 if node is Projectile else 0
	for c in node.get_children():
		n += _count_in(c)
	return n


## Frees every live Projectile — used before a test that needs a clean flight
## path, so an earlier section's still-travelling bolts (e.g. multishot's)
## can't collide with this section's dummies.
func _free_all_projectiles() -> void:
	for c in get_tree().root.get_children():
		_free_in(c)


func _free_in(node: Node) -> void:
	for c in node.get_children():
		_free_in(c)
	if node is Projectile:
		node.free()


## Pressing a skill must ARM it, not fire it: the player has to see the range
## and the area before committing.
func _check_skill_aiming() -> void:
	_section("Skill aiming: arm, preview, click to cast")
	var p = await _spawn()
	var aimer: SkillAimer = p.get_node("SkillAimer")
	var caster: SkillCaster = p.get_node("SkillCaster")
	p.mana = p.MAX_MANA
	p.stamina = p.MAX_STAMINA

	_expect(not aimer.is_aiming(), "nothing is armed to begin with")
	_expect(not aimer.visible, "and the indicator is hidden")

	# Arming must NOT cast.
	aimer.arm("frost_nova")
	await get_tree().process_frame
	_expect(aimer.is_aiming() and aimer.current_skill() == "frost_nova",
		"arming a ground AoE puts it in the aimer")
	_expect(aimer.visible, "the indicator is showing")
	_expect(not caster.is_casting(), "and nothing has been cast yet")
	_expect(p.is_aiming_skill(), "the player reports it is aiming")

	# The reticle/warning/ring/cursor art must be real, not a broken preload.
	_expect(SkillAimer.AOE_MARKER_TEX.get_size().x > 0, "SkillAimer.AOE_MARKER_TEX resolves a real texture")
	_expect(SkillAimer.BLOCKED_TEX.get_size().x > 0, "SkillAimer.BLOCKED_TEX resolves a real texture")
	_expect(SkillAimer.CURSOR_TEX.get_size().x > 0, "SkillAimer.CURSOR_TEX resolves a real texture")
	_expect(not aimer.blocked, "a ground AoE (no requires_bow) is never blocked")

	# The preview is clamped to the skill's own range, so it cannot promise a
	# cast the caster would then refuse.
	var reach := float(SkillDB.get_skill("frost_nova").get("cast_range", 0.0))
	p.global_position = Vector2.ZERO
	aimer._point = Vector2.ZERO
	await get_tree().process_frame
	var aimed: Vector2 = aimer.aim_point()
	_expect(aimed.length() <= reach + 1.0,
		"the aim point stays inside the %.0f range (%.0f)" % [reach, aimed.length()])

	# Committing casts at the previewed point, not wherever the mouse is.
	var target := Vector2(120, 0)
	_expect(p._try_cast("frost_nova", target), "clicking commits the cast")
	_expect(caster.is_casting(), "and the caster is now busy")
	_expect(is_equal_approx(caster._aim_point.x, target.x),
		"it cast at the previewed point (%.0f)" % caster._aim_point.x)
	aimer.cancel()
	while caster.is_casting():
		await get_tree().physics_frame

	# Cancelling costs nothing.
	var mana_before: float = p.mana
	aimer.arm("arcane_bolt")
	aimer.cancel()
	_expect(not aimer.is_aiming(), "cancelling disarms")
	_expect(is_equal_approx(p.mana, mana_before), "and charges no mana")

	_expect(SkillDB.targeting_of("whirlwind") == SkillDB.Targeting.SELF,
		"whirlwind is a self skill")

	# --- THE INPUT PATH, not the internals -------------------------------
	# The previous version of this test called _try_cast() directly and passed
	# while the actual key -> click flow was broken. Drive real input instead.
	p.mana = p.MAX_MANA
	p.stamina = p.MAX_STAMINA
	p.state = p.State.FREE
	aimer.cancel()
	p.kit = p.Kit.MAGE
	p._apply_kit_defaults()
	# known_abilities is the actual input->skill source now (see
	# player.gd's _handle_skill_input); it doesn't follow `kit` on its own
	# outside of _switch_kit_live(), which this direct poke bypasses on
	# purpose (same as everywhere else in this test).
	p.known_abilities.assign(SkillDB.loadout_for("mage"))
	# frost_nova was cast further up; without this it is still on cooldown and
	# the key press would be refused for a reason that has nothing to do with
	# what this section is testing.
	caster._cooldowns.clear()
	await get_tree().physics_frame

	Input.action_press("skill_1")
	await get_tree().physics_frame
	Input.action_release("skill_1")
	await get_tree().physics_frame
	_expect(aimer.is_aiming(), "pressing the skill key arms it")
	_expect(not caster.is_casting(), "  and does NOT cast yet")

	var mana_pre: float = p.mana
	Input.action_press("attack_light")
	await get_tree().physics_frame
	Input.action_release("attack_light")
	await get_tree().physics_frame
	_expect(caster.is_casting(), "clicking actually casts it")
	_expect(caster.current_skill() == "frost_nova", "  the right skill (%s)" % caster.current_skill())
	_expect(p.state == p.State.CAST, "  and the player is locked into CAST")
	_expect(p.mana < mana_pre, "  and it charged mana (%.0f -> %.0f)" % [mana_pre, p.mana])
	_expect(not aimer.is_aiming(), "  the aim is put away after committing")
	while caster.is_casting():
		await get_tree().physics_frame

	# Right click cancels instead of casting.
	caster._cooldowns.clear()
	Input.action_press("skill_1")
	await get_tree().physics_frame
	Input.action_release("skill_1")
	await get_tree().physics_frame
	var mana_hold: float = p.mana
	Input.action_press("guard")
	await get_tree().physics_frame
	Input.action_release("guard")
	await get_tree().physics_frame
	_expect(not aimer.is_aiming(), "right click cancels the aim")
	# Mana regenerates between frames, so the check is that it never went DOWN.
	_expect(not caster.is_casting() and p.mana >= mana_hold,
		"  and casts nothing, charges nothing (%.0f -> %.0f)" % [mana_hold, p.mana])
	p.state = p.State.FREE

	# Being hit drops the aim.
	aimer.arm("frost_nova")
	p.state = p.State.FREE
	p._on_damaged(5.0, 50.0)
	_expect(not aimer.is_aiming(), "taking a hit cancels the aim")

	# --- self-cast skills aim too -----------------------------------------
	# They used to fire straight off the keypress, which meant a whirlwind gave
	# you no idea what it would sweep and a charge no idea where it dropped you.
	# Both are decisions, so both get a preview.
	p.kit = p.Kit.WARRIOR
	p._apply_kit_defaults()
	p.known_abilities.assign(SkillDB.loadout_for("warrior"))
	p.state = p.State.FREE
	p.stamina = p.MAX_STAMINA
	caster._cooldowns.clear()
	aimer.cancel()
	await get_tree().physics_frame

	Input.action_press("skill_1")
	await get_tree().physics_frame
	Input.action_release("skill_1")
	await get_tree().physics_frame
	_expect(aimer.is_aiming(), "a self skill arms instead of firing on the keypress")
	_expect(aimer.current_skill() == "shoulder_bash",
		"  the warrior slot is the bash (%s)" % aimer.current_skill())
	_expect(not caster.is_casting(), "  and nothing has been cast yet")

	# The preview cannot promise a charge further than the dash actually goes.
	var bash := SkillDB.get_skill("shoulder_bash")
	var bash_range := float(bash.get("cast_range", 0.0))
	_expect(bash_range > 0.0, "the bash declares a cast_range (%.0f)" % bash_range)
	_expect(float(bash.get("dash_speed", 0.0)) > 0.0, "  and a dash speed")
	await get_tree().process_frame
	var bash_aim: Vector2 = aimer.aim_point()
	var bash_from: Vector2 = p.global_position
	_expect(bash_from.distance_to(bash_aim) <= bash_range + 1.0,
		"  the aimed point is clamped to that range")

	# Whirlwind has no dash, so its preview is the circle around you.
	var ww := SkillDB.get_skill("whirlwind")
	_expect(float(ww.get("radius", 0.0)) > 0.0,
		"whirlwind declares the radius its preview draws (%.0f)" % float(ww.get("radius", 0.0)))
	_expect(float(ww.get("dash_speed", 0.0)) == 0.0,
		"  and no dash, so the circle stays on the caster")

	# The charge travels TO the aimed point rather than firing off an impulse
	# that decays wherever — otherwise the preview would be a lie.
	var start: Vector2 = p.global_position
	var bash_target: Vector2 = aimer.aim_point()
	Input.action_press("attack_light")
	await get_tree().physics_frame
	Input.action_release("attack_light")
	await get_tree().physics_frame
	_expect(caster.is_casting() and caster.current_skill() == "shoulder_bash",
		"clicking commits the self skill too")
	var guard_frames := 0
	while caster.is_casting() and guard_frames < 240:
		guard_frames += 1
		await get_tree().physics_frame
	var ended: Vector2 = p.global_position
	_expect(ended.distance_to(start) > 1.0, "  the bash actually moved you")
	_expect(ended.distance_to(bash_target) < start.distance_to(bash_target),
		"  and moved you toward where the preview pointed")
	p.free()


## Open skill network (docs/GDD.md): abilities are learned per-character
## (Player.known_abilities/learn_ability()), not fixed by kit. Q/E/F is a
## live testing toggle for the current prototype stage (not the final game's
## one-time archetype pick), so switching kit resets known_abilities and
## progression back to that kit's defaults — see _switch_kit_live().
func _check_open_skill_network() -> void:
	_section("Open skill network: learn_ability() and kit-switch reset")
	var p = await _spawn()

	_expect(p.known_abilities == SkillDB.loadout_for("warrior"),
		"a fresh WARRIOR spawn knows exactly the warrior default loadout")

	_expect(not p.learn_ability("not_a_real_skill_id"), "learning an unknown id fails")
	_expect(not p.known_abilities.has("not_a_real_skill_id"), "  and nothing was added")

	_expect(p.learn_ability("frost_nova"), "learning a valid off-kit ability succeeds")
	_expect(p.known_abilities.has("frost_nova"), "  and it's now known")
	_expect(not p.learn_ability("frost_nova"), "learning it again fails (already known)")

	p.progression.gain("heavy_swords", 25.0)
	_expect(p.progression.total_points() > 0.0, "some progression was earned before switching")

	p._switch_kit_live(p.Kit.MAGE)
	_expect(p.kit == p.Kit.MAGE, "switching kit live actually changes it")
	_expect(is_equal_approx(p.progression.total_points(), 0.0),
		"...and resets progression to a clean slate")
	_expect(p.known_abilities == SkillDB.loadout_for("mage"),
		"...and resets known_abilities to the new kit's defaults (frost_nova learn didn't survive)")

	# Switching to the SAME kit again must be a no-op — nothing to reset.
	p.progression.gain("spellcraft", 10.0)
	var pts_before: float = p.progression.total_points()
	p._switch_kit_live(p.Kit.MAGE)
	_expect(is_equal_approx(p.progression.total_points(), pts_before),
		"switching to the kit you're already on does not reset anything")

	# apply_save_data() also calls _set_kit() (to restore a loaded kit) and
	# must NOT trigger this reset — that would erase the save it just loaded.
	p.progression.gain("mining", 15.0)
	p.learn_ability("shoulder_bash")
	var data: Dictionary = p.get_save_data()
	var q = await _spawn()
	q.apply_save_data(data)
	_expect(is_equal_approx(q.progression.total_points(), p.progression.total_points()),
		"apply_save_data()'s internal _set_kit() call does not wipe the progression it just restored")
	_expect(q.known_abilities.has("shoulder_bash"),
		"  or the known_abilities it just restored")

	p.free()
	q.free()


## Discovery ("1 de 3", docs/GDD.md): SkillDB.kit_of(), the weighted
## candidate roll (Player._discovery_candidates()), and the threshold
## trigger emitting Game.discovery_offered (Player._check_discovery_threshold()).
func _check_discovery() -> void:
	_section("Discovery: kit_of(), weighted candidates, threshold trigger")

	_expect(SkillDB.kit_of("shoulder_bash") == "warrior", "kit_of() finds a warrior default")
	_expect(SkillDB.kit_of("frost_nova") == "mage", "kit_of() finds a mage default")
	_expect(SkillDB.kit_of("caltrops") == "archer", "kit_of() finds an archer default")
	_expect(SkillDB.kit_of("not_a_real_skill") == "", "kit_of() returns \"\" for an unknown id")

	var p = await _spawn()
	_expect(p.known_abilities.size() == 2, "fresh WARRIOR knows exactly its 2 defaults")

	var all_ids: Array = []
	for id in SkillDB.SKILLS:
		all_ids.append(str(id))
	var unknown_count: int = all_ids.size() - int(p.known_abilities.size())

	var picks: Array = p._discovery_candidates(3)
	_expect(picks.size() == mini(3, unknown_count),
		"_discovery_candidates(3) returns min(3, pool size) ids (%d)" % picks.size())
	var picks_unique := {}
	for id in picks:
		picks_unique[id] = true
		_expect(not p.known_abilities.has(id), "  '%s' is not already known" % id)
		_expect(SkillDB.has_skill(id), "  '%s' is a real skill id" % id)
	_expect(picks_unique.size() == picks.size(), "  no duplicates in one roll")

	# Learn everything: the pool is empty, so there is nothing left to offer.
	for id in all_ids:
		p.learn_ability(id)
	_expect(p.known_abilities.size() == all_ids.size(), "learning every ability actually knows all of them")
	_expect(p._discovery_candidates(3).is_empty(), "an empty pool offers nothing")
	p.free()

	# Weighted preference: same-kit candidates should come up more often than
	# other-kit ones (DISCOVERY_SAME_KIT_WEIGHT vs DISCOVERY_OTHER_KIT_WEIGHT).
	# A fresh WARRIOR already knows its own 2 abilities from spawn — with only
	# 7 abilities total and none spare per kit, "same-kit but not yet known"
	# cannot happen through normal play today. Clearing known_abilities
	# directly (poking internals, like _check_open_skill_network() already
	# does) is the only way to isolate the weighting math itself; this is a
	# unit test of _discovery_candidates(), not a claim about reachable state.
	var w = await _spawn()
	w.known_abilities.clear()
	for id in all_ids:
		if id != "whirlwind" and id != "frost_nova":
			w.known_abilities.append(id)
	var same_kit_hits := 0
	const TRIALS := 600
	for i in TRIALS:
		var pick: Array = w._discovery_candidates(1)
		if pick.size() == 1 and pick[0] == "whirlwind":
			same_kit_hits += 1
	var ratio := float(same_kit_hits) / float(TRIALS)
	# Expected ~0.75 (weight 3 vs 1); wide bounds to keep this non-flaky while
	# still catching the weighting being broken/reversed/absent (~0.5 or ~0.25).
	_expect(ratio > 0.60 and ratio < 0.90,
		"same-kit candidate picked more often than other-kit (%.2f, expected ~0.75)" % ratio)
	w.free()

	# Threshold trigger: crossing DISCOVERY_THRESHOLDS[0] in a combat skill
	# fires Game.discovery_offered; staying under it, or gaining a
	# non-combat skill by the same amount, must not.
	var t = await _spawn()
	var offered: Array = []
	var conn := func(ids): offered.append(ids)
	Game.discovery_offered.connect(conn)

	var threshold: float = t.DISCOVERY_THRESHOLDS[0]
	t.progression.gain("heavy_swords", threshold - 5.0)
	_expect(offered.is_empty(), "staying under the first threshold does not offer anything")

	t.progression.gain("mining", threshold)
	_expect(offered.is_empty(), "crossing the SAME point value in a non-combat skill does not offer anything")

	t.progression.gain("heavy_swords", 10.0)  # now past `threshold`
	_expect(offered.size() == 1, "crossing the threshold in a combat skill offers exactly once (%d)" % offered.size())
	_expect(offered.is_empty() or (offered[0] as Array).size() > 0, "  and the offer is non-empty")

	Game.discovery_offered.disconnect(conn)
	t.free()


## Game.gm_mode (F2, hud.gd): a fly/no-clip dev tool for exploring a large
## map — damage is cancelled outright (same shape as the i-frame check in
## [2]) and collision_mask flips 0/1 on the on/off edge (see player.gd's
## _physics_process). Also covers world_zone.gd's build-mode camera zoom
## (mouse wheel), which is unrelated to gm_mode but small enough not to need
## its own suite.
func _check_gm_mode_and_build_zoom() -> void:
	print("\n[8] GM mode and build-mode camera zoom")
	var p = await _spawn()

	var hp0: float = p.health.hp
	Game.gm_mode = true
	p.hurtbox.apply_hit({"damage": 999.0, "team": &"enemy"})
	_expect(is_equal_approx(p.health.hp, hp0), "gm_mode cancels incoming damage completely")

	p._physics_process(0.016)
	_expect(p.collision_mask == 0, "gm_mode drops collision_mask to 0 (no-clip)")

	Game.gm_mode = false
	p._physics_process(0.016)
	_expect(p.collision_mask == 1, "leaving gm_mode restores collision_mask to 1 (world)")

	var zone := Node2D.new()
	zone.set_script(load("res://scripts/world/world_zone.gd"))
	p.camera.zoom = Vector2(1.0, 1.0)
	zone._zoom_build_camera(-1.0) # would go below MIN_BUILD_ZOOM unclamped
	_expect(is_equal_approx(p.camera.zoom.x, zone.MIN_BUILD_ZOOM),
		"zooming in past the minimum clamps to MIN_BUILD_ZOOM (%.2f)" % p.camera.zoom.x)
	zone._zoom_build_camera(10.0) # would go above MAX_BUILD_ZOOM unclamped
	_expect(is_equal_approx(p.camera.zoom.x, zone.MAX_BUILD_ZOOM),
		"zooming out past the maximum clamps to MAX_BUILD_ZOOM (%.2f)" % p.camera.zoom.x)

	zone.free()
	p.free()
	Game.gm_mode = false


func _check_architecture_contract() -> void:
	print("\n[7] docs/ARQUITECTURA.md contract")
	# "Logic in _physics_process only" — a system regenerating on _process is
	# frame-rate dependent, which breaks determinism for server-authoritative
	# play. Health is the one that used to violate it.
	var health_src := FileAccess.get_file_as_string("res://scripts/combat/health.gd")
	_expect(not health_src.contains("func _process("),
		"health.gd does not run logic in _process")
	_expect(health_src.contains("func _physics_process("),
		"health.gd regenerates poise in _physics_process")

	# Presentation must not be the authority on damage: nothing in gameplay may
	# key off animation frames.
	for path in ["res://scripts/player/player.gd", "res://scripts/combat/hitbox.gd",
			"res://scripts/combat/hurtbox.gd", "res://scripts/combat/health.gd"]:
		var src := FileAccess.get_file_as_string(path)
		_expect(not src.contains("frame_changed") and not src.contains("animation_finished"),
			"%s does not drive gameplay from animation frames" % path.get_file())

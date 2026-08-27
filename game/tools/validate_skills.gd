extends Node
## Headless coverage for progression-by-use (Skills, game/scripts/player/skills.gd)
## replacing the old character level/XP — the engine itself (gain curve, per-
## skill and total caps, vitality kicker, save round trip) plus the places
## that grant it: player.gd's derived stats, resource_node.gd gathering,
## chase_mob.gd kills, and Player.try_craft().
##
##   Godot_v4.7.1-stable_win64_console.exe --headless --path game \
##       res://tools/validate_skills.tscn
##
## Exits 0 when everything passes, 1 otherwise.

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const RESOURCE_NODE_SCENE := "res://scenes/world/resource_node.tscn"
const MOB_SCENE := "res://scenes/enemy/chase_mob.tscn"
const MIN_CHECKS := 30

var _failures: Array = []
var _checks := 0


func _ready() -> void:
	await _run()


func _run() -> void:
	print("== validate_skills ==")
	_check_gain_curve()
	_check_total_cap()
	_check_vitality_kicker()
	_check_signal_and_snapshot()
	await _check_player_derived_stats()
	await _check_crafting_grants_skill()
	await _check_gathering_grants_skill()
	await _check_kill_grants_combat_skill()

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


func _check_ran_enough() -> void:
	if _checks < MIN_CHECKS:
		_fail("only %d checks ran but at least %d are expected — a section aborted early"
			% [_checks, MIN_CHECKS])


func _spawn_player() -> Node:
	var p = load(PLAYER_SCENE).instantiate()
	add_child(p)
	await get_tree().physics_frame
	p.inventory.clear()
	return p


func _check_gain_curve() -> void:
	print("\n[1] Skills.gain() curve")
	var s := Skills.new()

	_expect(s.get_points("heavy_swords") == 0.0, "an untouched skill starts at 0")

	var g1 := s.gain("heavy_swords", 10.0)
	_expect(is_equal_approx(g1, 10.0), "full efficiency at 0 points grants the raw amount")

	s.points["heavy_swords"] = 90.0
	var g2 := s.gain("heavy_swords", 10.0)
	_expect(g2 < 10.0 and g2 > 0.0, "diminishing returns grant less than the raw amount near the cap")
	_expect(s.get_points("heavy_swords") <= Skills.SKILL_CAP, "a skill never exceeds SKILL_CAP")

	s.points["heavy_swords"] = Skills.SKILL_CAP
	var g3 := s.gain("heavy_swords", 5.0)
	_expect(is_equal_approx(g3, 0.0), "a maxed skill grants nothing more")

	_expect(is_equal_approx(s.gain("archery", 0.0), 0.0), "zero amount grants nothing")
	_expect(is_equal_approx(s.gain("archery", -5.0), 0.0), "negative amount grants nothing")
	_expect(s.get_points("archery") == 0.0, "...and doesn't touch the skill's points")


func _check_total_cap() -> void:
	print("\n[2] Total budget cap (Skills.TOTAL_CAP)")
	var s := Skills.new()
	# Seven synthetic filler skills at their own SKILL_CAP eat the entire
	# shared budget exactly (7 * SKILL_CAP == TOTAL_CAP), leaving "mining" —
	# nowhere near its OWN cap — with zero room. This isolates the
	# total-budget block from the per-skill cap block tested in [1].
	for i in 7:
		s.points["filler_%d" % i] = Skills.SKILL_CAP
	_expect(is_equal_approx(s.total_points(), Skills.TOTAL_CAP), "budget is fully spent")
	_expect(s.get_points("mining") < Skills.SKILL_CAP, "the target skill itself is nowhere near its own cap")

	var granted := s.gain("mining", 5.0)
	_expect(is_equal_approx(granted, 0.0), "gaining a non-maxed skill fails once the total budget is spent")
	_expect(is_equal_approx(s.get_points("mining"), 0.0), "...and its points are unchanged")


func _check_vitality_kicker() -> void:
	print("\n[3] Every gain also feeds Vitality")
	var s := Skills.new()
	var granted := s.gain("mining", 20.0)
	_expect(is_equal_approx(s.get_points(Skills.VITALITY_ID), granted * Skills.VITALITY_SHARE),
		"gaining mining also grants a VITALITY_SHARE slice of vitality")

	var vit_before := s.get_points(Skills.VITALITY_ID)
	s.gain(Skills.VITALITY_ID, 10.0)
	_expect(s.get_points(Skills.VITALITY_ID) > vit_before,
		"gaining vitality directly still raises it")
	# If gaining vitality also kicked itself, the delta would be inflated by
	# (1 + VITALITY_SHARE) instead of exactly the gain() call's own return.
	var vit_before2 := s.get_points(Skills.VITALITY_ID)
	var direct_gain := s.gain(Skills.VITALITY_ID, 10.0)
	_expect(is_equal_approx(s.get_points(Skills.VITALITY_ID), vit_before2 + direct_gain),
		"gaining vitality does not recursively kick itself")


func _check_signal_and_snapshot() -> void:
	print("\n[4] skill_changed signal + save snapshot round trip")
	var s := Skills.new()
	var seen: Array = []
	s.skill_changed.connect(func(id, points, delta): seen.append([id, points, delta]))
	s.gain("archery", 15.0)
	_expect(seen.size() >= 1 and seen[0][0] == "archery", "skill_changed fires for the skill that gained")
	# vitality's own kick emits a second signal for a different id.
	var saw_vitality := false
	for e in seen:
		if e[0] == Skills.VITALITY_ID:
			saw_vitality = true
	_expect(saw_vitality, "skill_changed also fires for vitality's automatic slice")

	seen.clear()
	s.points["woodcutting"] = Skills.SKILL_CAP
	s.gain("woodcutting", 5.0)
	_expect(seen.is_empty(), "a fully blocked gain does not emit skill_changed")

	var snap := s.get_snapshot()
	_expect(snap.get("archery", 0.0) == s.get_points("archery"), "get_snapshot() captures current points")

	var s2 := Skills.new()
	s2.load_snapshot(snap)
	_expect(is_equal_approx(s2.get_points("archery"), s.get_points("archery")), "load_snapshot() restores points")

	var s3 := Skills.new()
	s3.load_snapshot({"archery": -5.0, "mining": 999.0})
	_expect(s3.get_points("archery") == 0.0, "load_snapshot() clamps a negative value to 0 (and drops it)")
	_expect(is_equal_approx(s3.get_points("mining"), Skills.SKILL_CAP),
		"load_snapshot() clamps an over-cap value down to SKILL_CAP")

	_expect(Skills.label_for("heavy_swords") == "Espadas Pesadas", "label_for() resolves a known id")
	_expect(Skills.label_for("made_up_id") == "made_up_id", "label_for() falls back to the raw id")


func _check_player_derived_stats() -> void:
	print("\n[5] Player derived stats read Skills, not a level")
	var p = await _spawn_player()

	var hp_at_zero: float = p.health.max_hp
	_expect(is_equal_approx(hp_at_zero, p.BASE_HP), "max HP at 0 vitality is BASE_HP")

	p.progression.gain(Skills.VITALITY_ID, 40.0)
	_expect(p.health.max_hp > hp_at_zero, "gaining vitality raised max HP (signal-driven, no manual call needed)")

	var hp_now: float = p.health.max_hp
	p._apply_derived_stats()
	_expect(is_equal_approx(p.health.max_hp, hp_now), "re-applying derived stats at the same points is idempotent")
	_expect(p.health.hp <= p.health.max_hp, "current hp never exceeds max")

	p.kit = p.Kit.WARRIOR
	_expect(p.combat_skill_id() == "heavy_swords", "warrior's combat skill is heavy_swords")
	p.kit = p.Kit.MAGE
	_expect(p.combat_skill_id() == "spellcraft", "mage's combat skill is spellcraft")
	p.kit = p.Kit.ARCHER
	_expect(p.combat_skill_id() == "archery", "archer's combat skill is archery")

	var melee_before: float = p._melee_base_damage()
	p.progression.gain("heavy_swords", 30.0)
	_expect(p._melee_base_damage() > melee_before, "melee base damage scales with heavy_swords points")

	var spell_before: float = p._spell_base_damage()
	p.progression.gain("spellcraft", 30.0)
	_expect(p._spell_base_damage() > spell_before, "spell base damage scales with spellcraft points")

	var ranged_before: float = p._ranged_base_damage()
	p.progression.gain("archery", 30.0)
	_expect(p._ranged_base_damage() > ranged_before, "ranged base damage scales with archery points")

	p.free()


func _check_crafting_grants_skill() -> void:
	print("\n[6] try_craft() grants blacksmithing")
	var p = await _spawn_player()
	_expect(p.progression.get_points("blacksmithing") == 0.0, "starts untrained")

	# health_potion recipe: 2x health_herb (see CraftDB).
	p.inventory.add_item("health_herb", 2)
	var crafted: bool = p.try_craft("health_potion")
	_expect(crafted, "the craft succeeds with materials in hand")
	_expect(p.progression.get_points("blacksmithing") > 0.0, "a successful craft grants blacksmithing")

	var before: float = p.progression.get_points("blacksmithing")
	var failed: bool = p.try_craft("health_potion")
	_expect(not failed, "crafting again without materials fails")
	_expect(is_equal_approx(p.progression.get_points("blacksmithing"), before),
		"...and a failed craft grants nothing")

	p.free()


func _check_gathering_grants_skill() -> void:
	print("\n[7] Gathering grants woodcutting/mining")
	var p = await _spawn_player()

	# Non-immortal path: a tree's death (resource_node.gd's _on_died()).
	var tree = load(RESOURCE_NODE_SCENE).instantiate()
	tree.visual_type = "tree"
	tree.skill_gain = 5
	add_child(tree)
	await get_tree().physics_frame
	tree._last_attacker = p
	tree.health.take_damage({"damage": tree.health.max_hp + 10.0})
	_expect(is_equal_approx(p.progression.get_points("woodcutting"), 5.0),
		"killing a tree grants exactly its skill_gain in woodcutting")
	tree.free()

	# Immortal per-hit path: a vein's gather() (resource_node.gd, no death).
	var vein = load(RESOURCE_NODE_SCENE).instantiate()
	vein.visual_type = "vein"
	vein.immortal = true
	vein.manual_bonus_chance = 0.0  # keep the yielded amount deterministic (always 1)
	add_child(vein)
	await get_tree().physics_frame
	var mining_before: float = p.progression.get_points("mining")
	vein.gather(true, p)
	_expect(p.progression.get_points("mining") > mining_before,
		"gathering from a vein (per-hit, never dies) grants mining")
	vein.free()

	p.free()


func _check_kill_grants_combat_skill() -> void:
	print("\n[8] Killing a mob grants the killer's combat skill")
	var p = await _spawn_player()
	p.kit = p.Kit.ARCHER

	var mob = load(MOB_SCENE).instantiate()
	mob.max_hp = 10.0
	mob.skill_gain = 18
	add_child(mob)
	await get_tree().physics_frame
	mob._last_attacker = p
	mob.health.take_damage({"damage": mob.health.max_hp + 10.0})

	_expect(is_equal_approx(p.progression.get_points("archery"), 18.0),
		"killing a mob as ARCHER grants exactly its skill_gain in archery")

	mob.free()
	p.free()

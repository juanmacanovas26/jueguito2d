extends Node
## Headless coverage for the save/load system (SaveSystem + Player.
## get_save_data()/apply_save_data()) — the Fase 1 prerequisite everything
## else in a real playthrough depends on.
##
##   Godot_v4.7.1-stable_win64_console.exe --headless --path game \
##       res://tools/validate_save.tscn
##
## Exits 0 when everything passes, 1 otherwise.

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const MIN_CHECKS := 15

var _failures: Array = []
var _checks := 0


func _ready() -> void:
	await _run()


func _run() -> void:
	print("== validate_save ==")
	await _check_round_trip_in_memory()
	await _check_save_system_file_io()

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


## Same floor rationale as validate_systems.gd: a suite that only counts what
## it managed to run before an early return would report a false PASS.
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


func _check_round_trip_in_memory() -> void:
	print("\n[1] get_save_data() / apply_save_data() round trip")
	var p = await _spawn()

	p.progression.gain("heavy_swords", 40.0)
	p.progression.gain("mining", 12.0)
	p.inventory.gold = 250
	p.inventory.add_item("iron_ore", 7)
	p.inventory.add_item("arming_sword", 1)
	p.equip_weapon("arming_sword")
	p.kit = p.Kit.MAGE
	p._apply_kit_defaults()
	p._apply_derived_stats()
	# Poking `kit` directly (not through _switch_kit_live()) leaves
	# known_abilities exactly as _ready() set it (warrior's default:
	# shoulder_bash/whirlwind) — learning frost_nova on top proves the open
	# skill network survives a save as its own field, not derived from kit.
	p.learn_ability("frost_nova")
	p.health.hp = p.health.max_hp - 10.0
	p.mana = 30.0
	p.stamina = 55.0
	var spawn_pos := Vector2(123.0, -45.0)
	p.global_position = spawn_pos

	var data: Dictionary = p.get_save_data()
	_expect(data.has("position") and data.has("inventory") and data.has("equipped"),
		"get_save_data() returns the expected top-level keys")
	var saved_skills: Dictionary = data.get("skills", {})
	_expect(is_equal_approx(float(saved_skills.get("heavy_swords", -1.0)), 40.0), "skills are captured")
	_expect(int(data.get("gold", -1)) == 250, "gold is captured")
	_expect(str(data.get("equipped", {}).get("weapon", "")) == "arming_sword",
		"the equipped weapon is captured")
	var saved_abilities: Array = data.get("known_abilities", [])
	_expect(saved_abilities.has("shoulder_bash") and saved_abilities.has("frost_nova"),
		"known_abilities captures both the original default and the learned off-kit move")

	var bag_has_weapon := false
	for s in data.get("inventory", []):
		if str(s.get("id", "")) == "arming_sword":
			bag_has_weapon = true
	_expect(not bag_has_weapon, "an equipped item is not ALSO left sitting in the bag list")

	var q = await _spawn()
	q.apply_save_data(data)
	# No physics_frame await here on purpose: _regen_resources() ticks mana and
	# stamina toward max every physics step, which would nudge the values this
	# section is about to compare with is_equal_approx() and fail on drift that
	# has nothing to do with apply_save_data() itself.

	_expect(is_equal_approx(q.progression.get_points("heavy_swords"), 40.0)
			and is_equal_approx(q.progression.get_points("mining"), 12.0),
		"skills restored")
	_expect(q.inventory.gold == 250, "gold restored")
	_expect(q.inventory.count_item("iron_ore") == 7, "bag contents restored")
	_expect(q.get_equipped("weapon") == "arming_sword", "equipped weapon restored")
	_expect(q.kit == p.Kit.MAGE, "kit restored")
	_expect(q.known_abilities.has("frost_nova") and q.known_abilities.has("shoulder_bash"),
		"known_abilities restored, including the learned off-kit move")
	_expect(is_equal_approx(q.global_position.x, spawn_pos.x)
			and is_equal_approx(q.global_position.y, spawn_pos.y),
		"position restored")
	_expect(is_equal_approx(q.mana, 30.0), "mana restored")
	_expect(is_equal_approx(q.stamina, 55.0), "stamina restored")
	_expect(q.health.hp < q.health.max_hp, "hp restored below max (was damaged when saved)")

	p.free()
	q.free()


## Points SaveSystem at a throwaway file for the duration of this check, so a
## real player's savegame.json is never touched by the test run.
func _check_save_system_file_io() -> void:
	print("\n[2] SaveSystem file round trip")
	var original_path := SaveSystem.save_path
	SaveSystem.save_path = "user://validate_save_tmp.json"
	SaveSystem.delete_save()
	_expect(not SaveSystem.has_save(), "starts with no save file")
	_expect(SaveSystem.load_data().is_empty(), "load_data() on a missing file returns {}")

	var p = await _spawn()
	p.inventory.gold = 77
	Game.register_player(p)

	var saved := SaveSystem.save_game()
	_expect(saved, "save_game() succeeds with a registered player")
	_expect(SaveSystem.has_save(), "has_save() is true right after saving")

	var loaded := SaveSystem.load_data()
	_expect(int(loaded.get("gold", -1)) == 77, "the written file round-trips through load_data()")

	SaveSystem.delete_save()
	_expect(not SaveSystem.has_save(), "delete_save() removes it")

	SaveSystem.save_path = original_path
	p.free()

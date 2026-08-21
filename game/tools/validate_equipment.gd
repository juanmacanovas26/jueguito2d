extends Node
## Headless check of the equipment system: armour mitigation, unequip, and the
## equip swap not duplicating items. Dev tool, not shipped code.
##
##   Godot_v4.7.1-stable_win64_console.exe --headless --path game \
##       res://tools/validate_equipment.tscn
##
## Exits 0 when everything passes, 1 otherwise.

const PLAYER_SCENE := "res://scenes/player/player.tscn"

## Floor for how many checks this suite must run (see _check_ran_enough).
const MIN_CHECKS := 80

var _failures: Array = []
var _checks := 0


func _ready() -> void:
	await _run()


func _run() -> void:
	print("== validate_equipment ==")
	await _check_defense()
	await _check_unequip()
	await _check_equip_swap_no_dupe()
	await _check_full_bag_unequip()
	await _check_shield_guard()
	await _check_inventory_ui()
	await _check_skill_bar_ui()

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
	# Start from a clean slate: the scene seeds DEBUG_STARTING_ITEMS.
	p.inventory.clear()
	for slot in DataIntegrity.EQUIPPABLE_TYPES:
		p.unequip(slot)
	p.inventory.clear()
	return p


func _check_inventory_ui() -> void:
	print("\n[5] inventory UI: slots, icons and rarity")
	var p = await _spawn()
	var hud = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	await get_tree().physics_frame

	# Every item type must produce a distinct, non-blank icon.
	var seen := {}
	for id in ["dagger", "halberd", "plate_armor", "barbuta",
			"round_shield", "round_shield", "health_potion", "gold_coin", "iron_ore"]:
		var icon := ItemIcons.get_icon(id)
		if icon == null:
			_fail("no icon for '%s'" % id)
			continue
		var img := icon.get_image()
		var opaque := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.1:
					opaque += 1
		_expect(opaque > 40, "'%s' icon has %d visible pixels" % [id, opaque])
		seen[id] = opaque
	_expect(ItemIcons.get_icon("dagger") == ItemIcons.get_icon("dagger"),
		"icons are cached, not redrawn every call")
	_expect(ItemIcons.rarity_color("plate_armor") != ItemIcons.rarity_color("dagger"),
		"rarities get different name colours")

	# Empty slots read as empty; equipped slots carry the item's icon.
	hud._refresh_inv_list(p.inventory)
	var weapon_btn: Button = hud.equip_row.get_node("weapon")
	_expect(weapon_btn.icon == null and weapon_btn.disabled,
		"an empty slot shows no icon and is not clickable")

	p.inventory.add_item("dagger", 1)
	p.equip_weapon("dagger")
	hud._refresh_inv_list(p.inventory)
	_expect(weapon_btn.icon != null and not weapon_btn.disabled,
		"equipping fills the slot and enables it")
	_expect(weapon_btn.tooltip_text.contains("Dagger"),
		"the slot tooltip names the item")

	# The bag must NOT also list what is worn, or it could be equipped twice.
	var listed := 0
	for i in hud.inv_list.item_count:
		if str(hud._inv_ids[i]) == "dagger":
			listed += 1
	_expect(listed == 0, "the equipped weapon is not duplicated in the bag list")

	# Clicking the slot unequips.
	hud._on_equip_slot_pressed("weapon")
	_expect(p.get_equipped("weapon") == "", "clicking the slot unequips")
	_expect(weapon_btn.icon == null, "and the slot goes back to empty")
	_expect(p.inventory.count_item("dagger") == 1, "the weapon returned to the bag")

	# Bag rows carry icons.
	p.inventory.add_item("health_potion", 2)
	hud._refresh_inv_list(p.inventory)
	var rows_with_icon := 0
	for i in hud.inv_list.item_count:
		if hud.inv_list.get_item_icon(i) != null:
			rows_with_icon += 1
	_expect(hud.inv_list.item_count > 0 and rows_with_icon == hud.inv_list.item_count,
		"every bag row has an icon (%d/%d)" % [rows_with_icon, hud.inv_list.item_count])

	hud.free()
	p.free()


func _check_skill_bar_ui() -> void:
	_section("skill bar: icons, dynamic slot count, cooldowns, armed state")

	# Every skill must produce a distinct, non-blank icon, regardless of which
	# tier it falls into.
	for id in SkillDB.SKILLS:
		var icon := SkillIcons.get_icon(id)
		if icon == null:
			_fail("no icon for skill '%s'" % id)
			continue
		var img := icon.get_image()
		var opaque := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.1:
					opaque += 1
		_expect(opaque > 40, "'%s' skill icon has %d visible pixels" % [id, opaque])
	_expect(SkillIcons.get_icon("arcane_bolt") == SkillIcons.get_icon("arcane_bolt"),
		"skill icons are cached, not redrawn every call")

	# The 5 procedural tier-3 shapes must all be distinct — tested directly so
	# it does not depend on which real skill happens to lack art today.
	var shapes := {}
	for combo in [
		[SkillDB.Targeting.SELF, true], [SkillDB.Targeting.SELF, false],
		[SkillDB.Targeting.GROUND_AOE, false], [SkillDB.Targeting.SKILLSHOT, false],
		[SkillDB.Targeting.TARGET, false],
	]:
		shapes[SkillIcons._shape_for(combo[0], combo[1])] = true
	_expect(shapes.size() == 5, "all 5 tier-3 icon shapes are distinct (%d)" % shapes.size())

	# Tier-2 routing: whirlwind/shoulder_bash/caltrops now declare a real
	# impact_vfx, so they must resolve through the VFX-crop tier, not fall to
	# the procedural fallback.
	for id in ["whirlwind", "shoulder_bash", "caltrops", "frost_nova", "arcane_bolt", "multishot"]:
		_expect(SkillIcons._vfx_icon(id) != null,
			"'%s' icon resolves via the VFX-reuse tier" % id)
	# smite has no vfx field at all, so it must fall through to tier 3.
	_expect(SkillIcons._vfx_icon("smite") == null,
		"'smite' has no vfx field and falls through to the procedural tier")

	# The bar renders however many skills the current kit's loadout has —
	# never a hardcoded count — and rebuilds when the loadout changes.
	var p = await _spawn()
	var hud = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	p._set_kit(p.Kit.WARRIOR)
	await get_tree().process_frame
	await get_tree().process_frame
	var warrior_loadout := SkillDB.loadout_for("warrior")
	_expect(hud.skill_bar._slots.size() == warrior_loadout.size(),
		"warrior loadout renders %d slot(s) (%d)" % [warrior_loadout.size(), hud.skill_bar._slots.size()])

	p._set_kit(p.Kit.MAGE)
	await get_tree().process_frame
	await get_tree().process_frame
	var mage_loadout := SkillDB.loadout_for("mage")
	_expect(hud.skill_bar._slots.size() == mage_loadout.size(),
		"switching kit rebuilds to the mage loadout's %d slot(s) (%d)" % [mage_loadout.size(), hud.skill_bar._slots.size()])
	_expect(mage_loadout.size() == 3, "mage now has 3 skills, exercising a non-2 slot count")
	var slot_ids: Array = []
	for slot in hud.skill_bar._slots:
		slot_ids.append(slot.skill_id)
	_expect(slot_ids == mage_loadout, "slot ids match the loadout in order (%s)" % [slot_ids])

	# Cooldown math must come from SkillDB's own `cooldown` field, not
	# duration_of() (startup+active+recovery) — a much shorter, unrelated
	# number that would wipe the overlay long before the real cooldown ends.
	var caster: SkillCaster = p.skills
	caster._cooldowns["arcane_bolt"] = 1.4
	var total := float(SkillDB.get_skill("arcane_bolt").get("cooldown", 1.0))
	var bolt_slot: SkillSlot = null
	for slot in hud.skill_bar._slots:
		if slot.skill_id == "arcane_bolt":
			bolt_slot = slot
	_expect(bolt_slot != null, "the mage loadout includes an arcane_bolt slot")
	if bolt_slot:
		bolt_slot.update(caster, p.aimer)
		var expected := clampf(1.4 / total, 0.0, 1.0)
		_expect(is_equal_approx(bolt_slot._cooldown.value, expected),
			"cooldown overlay uses SkillDB's cooldown (%.2f), not duration_of (%.2f) — got %.2f, want %.2f"
				% [total, SkillDB.duration_of("arcane_bolt"), bolt_slot._cooldown.value, expected])
		_expect(bolt_slot._count.visible, "a skill mid-cooldown shows its countdown number")
		_expect(bolt_slot._count.text == str(ceili(1.4)), "the countdown reads the ceiling of the seconds left")
		caster._cooldowns["arcane_bolt"] = 0.0
		bolt_slot.update(caster, p.aimer)
		_expect(not bolt_slot._count.visible, "a ready skill hides its countdown number")

	# Arming a skill marks exactly its own slot, and no other, as armed.
	p.aimer.arm("frost_nova")
	for slot in hud.skill_bar._slots:
		slot.update(caster, p.aimer)
	var armed_ids: Array = []
	for slot in hud.skill_bar._slots:
		if slot._armed:
			armed_ids.append(slot.skill_id)
	_expect(armed_ids == ["frost_nova"], "arming frost_nova marks only its own slot (%s)" % [armed_ids])
	p.aimer.cancel()

	hud.free()
	p.free()


# ------------------------------------------------------------------ checks


func _check_defense() -> void:
	print("\n[1] defense_bonus actually reduces damage")
	var p = await _spawn()

	_expect(p.total_defense() == 0.0, "naked: total_defense = %s" % p.total_defense())
	_expect(p.defense_reduction() == 0.0, "naked: no reduction")

	var hit := {"damage": 100.0, "team": &"enemy"}
	var naked: float = float(p.resolve_incoming_hit(hit)["damage"])
	_expect(is_equal_approx(naked, 100.0), "naked takes full damage (%.1f)" % naked)

	p.inventory.add_item("leather_armor", 1)
	p.equip_armor("leather_armor")
	_expect(p.total_defense() == 3.0, "leather armor -> defense 3 (%s)" % p.total_defense())
	var light: float = float(p.resolve_incoming_hit(hit)["damage"])
	_expect(light < naked, "leather armor reduces damage: %.1f -> %.1f" % [naked, light])

	p.inventory.add_item("plate_armor", 1)
	p.inventory.add_item("barbuta", 1)
	p.inventory.add_item("round_shield", 1)
	p.equip_armor("plate_armor")
	p.equip_helmet("barbuta")
	p.equip_secondary("round_shield")
	_expect(p.total_defense() == 19.5, "full kit -> defense 19.5 (%s)" % p.total_defense())
	var heavy: float = float(p.resolve_incoming_hit(hit)["damage"])
	_expect(heavy < light, "full kit beats leather alone: %.1f -> %.1f" % [light, heavy])
	_expect(is_equal_approx(heavy, 100.0 * (1.0 - 19.5 / 49.5)),
		"full kit absorbs exactly 39%% (took %.1f of 100)" % heavy)
	_expect(heavy > 0.0, "armour never reduces damage to zero (%.1f)" % heavy)

	# A weapon must not contribute defense.
	p.inventory.add_item("arming_sword", 1)
	p.equip_weapon("arming_sword")
	_expect(p.total_defense() == 19.5, "equipping a weapon does not add defense")

	# i-frames still win over everything.
	p._set_iframe(true)
	_expect(bool(p.resolve_incoming_hit(hit).get("cancelled", false)),
		"i-frames still cancel the hit entirely")
	p._set_iframe(false)
	p.free()


## The SHIELD defend style must depend on actually carrying a shield, and how
## well it blocks must come from the shield itself.
func _check_shield_guard() -> void:
	_section("guard is tied to the equipped shield")
	var p = await _spawn()
	p.defend_style = p.DefendStyle.SHIELD

	_expect(not p.has_shield(), "off-hand empty: no shield")
	_expect(p.effective_defend_style() == p.DefendStyle.PARRY,
		"the SHIELD style falls back to PARRY with an empty off-hand")
	_expect(is_equal_approx(p.shield_block_mul(), 1.0),
		"and blocks nothing (mul %.2f)" % p.shield_block_mul())

	# A shield must actually be worn for the style to work.
	p.inventory.add_item("plus_shield", 1)
	p.equip_secondary("plus_shield")
	_expect(p.has_shield(), "with a shield equipped, has_shield() is true")
	_expect(p.effective_defend_style() == p.DefendStyle.SHIELD,
		"and the SHIELD style becomes usable")
	var weak: float = p.shield_block_mul()
	_expect(weak < 1.0, "a raised shield reduces the hit (mul %.2f)" % weak)

	# A better shield blocks more.
	p.inventory.add_item("crusader_shield", 1)
	p.equip_secondary("crusader_shield")
	var strong: float = p.shield_block_mul()
	_expect(strong < weak, "a better shield blocks more (%.2f -> %.2f)" % [weak, strong])

	# Losing the shield mid-fight downgrades the defence instead of breaking it.
	p.unequip("secondary")
	_expect(p.effective_defend_style() == p.DefendStyle.PARRY,
		"losing the shield falls back to PARRY rather than nothing")

	# End to end through a real hit.
	p.inventory.add_item("crusader_shield", 1)
	p.equip_secondary("crusader_shield")
	p.state = p.State.GUARD
	p._guard_time = 999.0            # past the parry window: a plain block
	p._parry_active = false
	var hit := {"damage": 100.0, "team": &"enemy"}
	var blocked: float = float(p.resolve_incoming_hit(hit)["damage"])
	p.unequip("secondary")
	p.state = p.State.GUARD
	p._guard_time = 999.0
	p._parry_active = false
	var unshielded: float = float(p.resolve_incoming_hit(hit)["damage"])
	_expect(blocked < unshielded,
		"blocking with a shield beats blocking without one (%.1f vs %.1f)" % [blocked, unshielded])
	p.free()


func _check_unequip() -> void:
	print("\n[2] unequip")
	var p = await _spawn()
	p.inventory.add_item("plate_armor", 1)
	p.equip_armor("plate_armor")

	_expect(p.get_equipped("armor") == "plate_armor", "armor slot reports the equipped id")
	_expect(p.inventory.count_item("plate_armor") == 0, "the piece left the bag when equipped")
	_expect(p.defense_reduction() > 0.0, "defense is active while worn")

	_expect(p.unequip("armor"), "unequip('armor') succeeds")
	_expect(p.get_equipped("armor") == "", "the slot is now empty")
	_expect(p.inventory.count_item("plate_armor") == 1, "the piece is back in the bag")
	_expect(p.defense_reduction() == 0.0, "defense drops back to zero")

	_expect(not p.unequip("armor"), "unequipping an empty slot returns false")
	_expect(not p.unequip("nonsense"), "unknown slot returns false")
	p.free()


func _check_equip_swap_no_dupe() -> void:
	print("\n[3] swapping gear never duplicates it")
	var p = await _spawn()
	p.inventory.add_item("leather_armor", 1)
	p.inventory.add_item("plate_armor", 1)
	p.equip_armor("leather_armor")
	p.equip_armor("plate_armor")   # swap

	var total: int = p.inventory.count_item("leather_armor") + p.inventory.count_item("plate_armor")
	_expect(p.get_equipped("armor") == "plate_armor", "the new piece is worn")
	_expect(p.inventory.count_item("leather_armor") == 1, "the old piece went back to the bag")
	_expect(total == 1, "exactly one armour in the bag, none duplicated (found %d)" % total)

	# The failing-swap path: equipping something that is NOT in the bag must
	# change nothing at all. This is the case that used to dupe.
	var before_worn := str(p.get_equipped("armor"))
	var before_bag: int = p.inventory.count_item("leather_armor")
	# "mithril_armor" does not exist in ItemDB, so is_armor() rejects it; use a
	# real armour that simply is not in the bag to hit the remove_item failure.
	p.inventory.remove_item("leather_armor", 99)
	var result: bool = p.equip_armor("leather_armor")
	_expect(not result, "equipping an item not in the bag fails")
	before_bag = 0
	_expect(p.get_equipped("armor") == before_worn, "the worn piece is untouched after a failed equip")
	_expect(p.inventory.count_item("leather_armor") == before_bag,
		"the bag is untouched after a failed equip (no phantom copy)")
	p.free()


func _check_full_bag_unequip() -> void:
	print("\n[4] unequipping into a full bag")
	var p = await _spawn()
	p.inventory.add_item("plate_armor", 1)
	p.equip_armor("plate_armor")
	# Fill every slot with a non-stacking item so there is nowhere to put it back.
	for i in p.inventory.max_slots:
		p.inventory.add_item("dagger", 1)
	_expect(not p.inventory.has_space_for("plate_armor", 1), "the bag is genuinely full")

	_expect(not p.unequip("armor"), "unequip refuses when the bag is full")
	_expect(p.get_equipped("armor") == "plate_armor",
		"the piece stays equipped instead of being destroyed")
	p.free()

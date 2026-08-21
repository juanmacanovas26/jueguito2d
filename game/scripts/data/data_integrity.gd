class_name DataIntegrity
extends RefCounted
## Coherence checks over the static game data (ItemDB, CraftDB).
##
## These catch the class of bug that otherwise only shows up hours into play: a
## recipe whose output was renamed, an equippable with a typo'd type so it can
## never be equipped, a stack size of 0 that makes an item impossible to pick
## up. All of it is const data, so the whole thing is a pure function over the
## tables and costs nothing to run.
##
## Run from tools/validate_data.tscn, and cheaply at boot in debug builds.

## Types that ItemDB.is_* / the equip flow actually understand.
const VALID_TYPES := ["currency", "material", "consumable", "weapon", "armor", "legs", "feet", "arms", "gloves", "shoulders", "wrists", "helmet", "secondary", "misc"]

## Types that go into an equipment slot, and therefore need a visual_state.
const EQUIPPABLE_TYPES := ["weapon", "armor", "legs", "feet", "arms", "gloves", "shoulders", "wrists", "helmet", "secondary"]

## Rarities ItemIcons knows how to colour.
const VALID_RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]


## Returns a list of human-readable problems. Empty means the data is coherent.
static func check() -> Array:
	var problems: Array = []
	problems.append_array(_check_items())
	problems.append_array(_check_recipes())
	return problems


static func _check_items() -> Array:
	var problems: Array = []
	for id in ItemDB.ITEMS:
		var def: Dictionary = ItemDB.ITEMS[id]
		var where := "item '%s'" % id

		if not def.has("name") or str(def["name"]) == "":
			problems.append("%s has no name" % where)

		var type := str(def.get("type", ""))
		if not VALID_TYPES.has(type):
			problems.append("%s has type '%s', which nothing understands (valid: %s)"
				% [where, type, ", ".join(VALID_TYPES)])

		var rarity := str(def.get("rarity", ""))
		if not VALID_RARITIES.has(rarity):
			problems.append("%s has rarity '%s', which has no colour (valid: %s)"
				% [where, rarity, ", ".join(VALID_RARITIES)])

		var stack := int(def.get("stack", 0))
		if stack < 1:
			problems.append("%s has stack %d — it could never be picked up" % [where, stack])
		if EQUIPPABLE_TYPES.has(type) and stack != 1:
			problems.append("%s is equippable but stacks to %d; equipment must be stack 1 or the swap logic double-counts it"
				% [where, stack])

		if int(def.get("value", 0)) < 0:
			problems.append("%s has a negative value" % where)

		if EQUIPPABLE_TYPES.has(type):
			if str(def.get("visual_state", "")) == "":
				problems.append("%s is equippable but has no visual_state, so it can never show art" % where)
		elif def.has("visual_state"):
			problems.append("%s is not equippable but declares a visual_state" % where)

		# A consumable that does nothing is a dead end for the player.
		if type == "consumable":
			var heals := float(def.get("heal", 0.0)) > 0.0
			var restores := float(def.get("restore_mana", 0.0)) > 0.0
			if not heals and not restores:
				problems.append("%s is a consumable that neither heals nor restores mana" % where)

		if not (def.get("color") is Color):
			problems.append("%s has no color, so its icon and loot drop cannot be tinted" % where)
	return problems


static func _check_recipes() -> Array:
	var problems: Array = []
	var seen_ids: Dictionary = {}
	for recipe in CraftDB.RECIPES:
		var rid := str(recipe.get("id", ""))
		var where := "recipe '%s'" % rid

		if rid == "":
			problems.append("a recipe has no id")
		elif seen_ids.has(rid):
			problems.append("%s is defined twice" % where)
		seen_ids[rid] = true

		var out_id := str(recipe.get("output_id", ""))
		if not ItemDB.ITEMS.has(out_id):
			problems.append("%s produces '%s', which is not in ItemDB" % [where, out_id])

		if int(recipe.get("output_amount", 0)) < 1:
			problems.append("%s produces %d items" % [where, int(recipe.get("output_amount", 0))])

		var inputs: Dictionary = recipe.get("inputs", {})
		if inputs.is_empty():
			problems.append("%s has no inputs, so it is free" % where)
		for item_id in inputs:
			if not ItemDB.ITEMS.has(str(item_id)):
				problems.append("%s needs '%s', which is not in ItemDB" % [where, str(item_id)])
			if int(inputs[item_id]) < 1:
				problems.append("%s needs %d of '%s'" % [where, int(inputs[item_id]), str(item_id)])
			if str(item_id) == out_id:
				problems.append("%s consumes its own output" % where)
	return problems

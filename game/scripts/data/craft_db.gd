class_name CraftDB
extends RefCounted

const RECIPES := [
	{
		"id": "arming_sword",
		"name": "Arming Sword",
		"inputs": {"iron_ore": 4, "wood_log": 2},
		"output_id": "arming_sword",
		"output_amount": 1,
	},
	{
		"id": "halberd",
		"name": "Halberd",
		"inputs": {"wood_log": 4, "mana_dust": 2},
		"output_id": "halberd",
		"output_amount": 1,
	},
	{
		"id": "health_potion",
		"name": "Health Potion",
		"inputs": {"health_herb": 2},
		"output_id": "health_potion",
		"output_amount": 1,
	},
	{
		"id": "mana_potion",
		"name": "Mana Potion",
		"inputs": {"mana_dust": 1, "stone_chunk": 1},
		"output_id": "mana_potion",
		"output_amount": 1,
	},
	{
		"id": "dagger",
		"name": "Dagger",
		"inputs": {"stone_chunk": 2, "wood_log": 1},
		"output_id": "dagger",
		"output_amount": 1,
	},
]


static func get_recipes() -> Array:
	return RECIPES


static func get_recipe(id: String) -> Dictionary:
	for r in RECIPES:
		if str(r.get("id", "")) == id:
			return r.duplicate()
	return {}


static func recipe_label(recipe: Dictionary) -> String:
	var parts: Array[String] = []
	var inputs: Dictionary = recipe.get("inputs", {})
	for item_id in inputs:
		parts.append("%d %s" % [int(inputs[item_id]), ItemDB.display_name(str(item_id))])
	var out := "%d %s" % [int(recipe.get("output_amount", 1)), ItemDB.display_name(str(recipe.get("output_id", "")))]
	return "%s  →  %s" % [", ".join(parts), out]

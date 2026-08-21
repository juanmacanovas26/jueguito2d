class_name ItemDB
extends RefCounted

## id -> { name, color, stack, rarity, type, value, [dmg_bonus, spell_bonus, heal] }
##
## attack_anim (weapons only): which attack animation the character plays while
## holding it — LPC draws a sword swing, a spear thrust, a spell cast and a bow
## shot as different animations, and a weapon only has art for its own. Defaults
## to attack_slash. This is what gives the mage and archer kits their identity.
##
## visual_state (armor/helmet/weapon/secondary only): the piece's own key. It is
## the only link between an item and how it looks: LpcEquipment maps it to a
## piece of the bundled Universal LPC library and CharacterVisual composes it
## into the paperdoll. Giving an item an appearance is one line in
## LpcEquipment.PIECES. See art_pipeline/lpc/README.md.
const ITEMS := {
	"gold_coin": {
		"name": "Gold",
		"color": Color(0.95, 0.8, 0.25),
		"stack": 9999,
		"rarity": "common",
		"type": "currency",
		"value": 1,
	},
	"slime_goo": {
		"name": "Slime Goo",
		"color": Color(0.4, 0.85, 0.45),
		"stack": 99,
		"rarity": "common",
		"type": "material",
		"value": 2,
	},
	"wood_log": {
		"name": "Wood Log",
		"color": Color(0.55, 0.4, 0.25),
		"stack": 99,
		"rarity": "common",
		"type": "material",
		"value": 3,
	},
	"stone_chunk": {
		"name": "Stone Chunk",
		"color": Color(0.6, 0.6, 0.65),
		"stack": 99,
		"rarity": "common",
		"type": "material",
		"value": 2,
	},
	"iron_ore": {
		"name": "Iron Ore",
		"color": Color(0.75, 0.7, 0.6),
		"stack": 99,
		"rarity": "uncommon",
		"type": "material",
		"value": 12,
	},
	"wolf_fang": {
		"name": "Wolf Fang",
		"color": Color(0.85, 0.85, 0.9),
		"stack": 99,
		"rarity": "uncommon",
		"type": "material",
		"value": 8,
	},
	"mana_dust": {
		"name": "Mana Dust",
		"color": Color(0.55, 0.55, 1.0),
		"stack": 99,
		"rarity": "uncommon",
		"type": "material",
		"value": 10,
	},
	"health_herb": {
		"name": "Health Herb",
		"color": Color(0.9, 0.35, 0.4),
		"stack": 20,
		"rarity": "common",
		"type": "consumable",
		"value": 5,
		"heal": 35.0,
	},
	"health_potion": {
		"name": "Health Potion",
		"color": Color(0.95, 0.3, 0.35),
		"stack": 20,
		"rarity": "uncommon",
		"type": "consumable",
		"value": 25,
		"heal": 80.0,
	},
	"mana_potion": {
		"name": "Mana Potion",
		"color": Color(0.4, 0.5, 1.0),
		"stack": 20,
		"rarity": "common",
		"type": "consumable",
		"value": 8,
		"restore_mana": 50.0,
	},
	"longsleeve_shirt": {
		"name": "Longsleeve Shirt",
		"color": Color(0.62, 0.5, 0.38),
		"stack": 1,
		"rarity": "common",
		"type": "armor",
		"value": 12,
		"defense_bonus": 1.0,
		"visual_state": "longsleeve_shirt",
	},
	"leather_armor": {
		"name": "Leather Armor",
		"color": Color(0.62, 0.5, 0.38),
		"stack": 1,
		"rarity": "common",
		"type": "armor",
		"value": 30,
		"defense_bonus": 3.0,
		"visual_state": "leather_armor",
	},
	"chainmail": {
		"name": "Chainmail",
		"color": Color(0.62, 0.5, 0.38),
		"stack": 1,
		"rarity": "uncommon",
		"type": "armor",
		"value": 65,
		"defense_bonus": 6.0,
		"visual_state": "chainmail",
	},
	"legion_armor": {
		"name": "Legion Armor",
		"color": Color(0.62, 0.5, 0.38),
		"stack": 1,
		"rarity": "uncommon",
		"type": "armor",
		"value": 85,
		"defense_bonus": 8.0,
		"visual_state": "legion_armor",
	},
	"plate_armor": {
		"name": "Plate Armor",
		"color": Color(0.62, 0.5, 0.38),
		"stack": 1,
		"rarity": "rare",
		"type": "armor",
		"value": 140,
		"defense_bonus": 12.0,
		"visual_state": "plate_armor",
	},
	"shorts": {
		"name": "Shorts",
		"color": Color(0.45, 0.45, 0.52),
		"stack": 1,
		"rarity": "common",
		"type": "legs",
		"value": 6,
		"defense_bonus": 0.5,
		"visual_state": "shorts",
	},
	"hose": {
		"name": "Hose",
		"color": Color(0.45, 0.45, 0.52),
		"stack": 1,
		"rarity": "common",
		"type": "legs",
		"value": 10,
		"defense_bonus": 1.0,
		"visual_state": "hose",
	},
	"pants": {
		"name": "Pants",
		"color": Color(0.45, 0.45, 0.52),
		"stack": 1,
		"rarity": "common",
		"type": "legs",
		"value": 14,
		"defense_bonus": 1.5,
		"visual_state": "pants",
	},
	"pantaloons": {
		"name": "Pantaloons",
		"color": Color(0.45, 0.45, 0.52),
		"stack": 1,
		"rarity": "uncommon",
		"type": "legs",
		"value": 26,
		"defense_bonus": 2.5,
		"visual_state": "pantaloons",
	},
	"plate_leggings": {
		"name": "Plate Leggings",
		"color": Color(0.45, 0.45, 0.52),
		"stack": 1,
		"rarity": "rare",
		"type": "legs",
		"value": 95,
		"defense_bonus": 7.0,
		"visual_state": "plate_leggings",
	},
	"spangenhelm": {
		"name": "Spangenhelm",
		"color": Color(0.72, 0.74, 0.78),
		"stack": 1,
		"rarity": "common",
		"type": "helmet",
		"value": 22,
		"defense_bonus": 2.0,
		"visual_state": "spangenhelm",
	},
	"kettle_helm": {
		"name": "Kettle Helm",
		"color": Color(0.72, 0.74, 0.78),
		"stack": 1,
		"rarity": "common",
		"type": "helmet",
		"value": 28,
		"defense_bonus": 2.5,
		"visual_state": "kettle_helm",
	},
	"bascinet": {
		"name": "Bascinet",
		"color": Color(0.72, 0.74, 0.78),
		"stack": 1,
		"rarity": "uncommon",
		"type": "helmet",
		"value": 45,
		"defense_bonus": 4.0,
		"visual_state": "bascinet",
	},
	"barbuta": {
		"name": "Barbuta",
		"color": Color(0.72, 0.74, 0.78),
		"stack": 1,
		"rarity": "uncommon",
		"type": "helmet",
		"value": 52,
		"defense_bonus": 4.5,
		"visual_state": "barbuta",
	},
	"greathelm": {
		"name": "Greathelm",
		"color": Color(0.72, 0.74, 0.78),
		"stack": 1,
		"rarity": "rare",
		"type": "helmet",
		"value": 90,
		"defense_bonus": 6.5,
		"visual_state": "greathelm",
	},
	"plus_shield": {
		"name": "Plus Shield",
		"color": Color(0.55, 0.42, 0.3),
		"stack": 1,
		"rarity": "common",
		"type": "secondary",
		"value": 18,
		"defense_bonus": 2.0,
		"visual_state": "plus_shield",
	},
	"round_shield": {
		"name": "Engrailed Shield",
		"color": Color(0.55, 0.42, 0.3),
		"stack": 1,
		"rarity": "common",
		"type": "secondary",
		"value": 26,
		"defense_bonus": 3.0,
		"visual_state": "round_shield",
	},
	"scutum_shield": {
		"name": "Scutum",
		"color": Color(0.55, 0.42, 0.3),
		"stack": 1,
		"rarity": "uncommon",
		"type": "secondary",
		"value": 48,
		"defense_bonus": 5.0,
		"visual_state": "scutum_shield",
	},
	"spartan_shield": {
		"name": "Spartan Shield",
		"color": Color(0.55, 0.42, 0.3),
		"stack": 1,
		"rarity": "uncommon",
		"type": "secondary",
		"value": 58,
		"defense_bonus": 6.0,
		"visual_state": "spartan_shield",
	},
	"crusader_shield": {
		"name": "Crusader Shield",
		"color": Color(0.55, 0.42, 0.3),
		"stack": 1,
		"rarity": "rare",
		"type": "secondary",
		"value": 95,
		"defense_bonus": 8.5,
		"visual_state": "crusader_shield",
	},
	"quiver": {
		"name": "Quiver of Arrows",
		"color": Color(0.6, 0.5, 0.35),
		"stack": 1,
		"rarity": "common",
		# Same slot as a shield: an archer with a bow drawn isn't also holding
		# a shield, so the two compete for the off-hand — a real choice.
		"type": "secondary",
		"value": 12,
		"visual_state": "quiver",
		## The flag player.gd's has_arrows() checks.
		"is_ammo": true,
	},
	"basic_boots": {
		"name": "Basic Shoes",
		"color": Color(0.45, 0.34, 0.25),
		"stack": 1,
		"rarity": "common",
		"type": "feet",
		"value": 10,
		"defense_bonus": 0.5,
		"visual_state": "basic_boots",
	},
	"rimmed_boots": {
		"name": "Rimmed Boots",
		"color": Color(0.45, 0.34, 0.25),
		"stack": 1,
		"rarity": "common",
		"type": "feet",
		"value": 16,
		"defense_bonus": 1.0,
		"visual_state": "rimmed_boots",
	},
	"folded_boots": {
		"name": "Folded Boots",
		"color": Color(0.45, 0.34, 0.25),
		"stack": 1,
		"rarity": "uncommon",
		"type": "feet",
		"value": 24,
		"defense_bonus": 1.5,
		"visual_state": "folded_boots",
	},
	"revised_boots": {
		"name": "Traveler Boots",
		"color": Color(0.45, 0.34, 0.25),
		"stack": 1,
		"rarity": "uncommon",
		"type": "feet",
		"value": 30,
		"defense_bonus": 2.0,
		"visual_state": "revised_boots",
	},
	"plate_boots": {
		"name": "Plate Boots",
		"color": Color(0.45, 0.34, 0.25),
		"stack": 1,
		"rarity": "rare",
		"type": "feet",
		"value": 70,
		"defense_bonus": 5.0,
		"visual_state": "plate_boots",
	},
	"plate_bracers": {
		"name": "Plate Bracers",
		"color": Color(0.7, 0.72, 0.76),
		"stack": 1,
		"rarity": "rare",
		"type": "arms",
		"value": 60,
		"defense_bonus": 4.0,
		"visual_state": "plate_bracers",
	},
	"gloves": {
		"name": "Gloves",
		"color": Color(0.5, 0.4, 0.3),
		"stack": 1,
		"rarity": "common",
		"type": "gloves",
		"value": 14,
		"defense_bonus": 1.0,
		"visual_state": "gloves",
	},
	"epaulets": {
		"name": "Epaulets",
		"color": Color(0.68, 0.7, 0.74),
		"stack": 1,
		"rarity": "common",
		"type": "shoulders",
		"value": 18,
		"defense_bonus": 1.5,
		"visual_state": "epaulets",
	},
	"mantle": {
		"name": "Mantle",
		"color": Color(0.68, 0.7, 0.74),
		"stack": 1,
		"rarity": "common",
		"type": "shoulders",
		"value": 22,
		"defense_bonus": 2.0,
		"visual_state": "mantle",
	},
	"legion_pauldrons": {
		"name": "Legion Pauldrons",
		"color": Color(0.68, 0.7, 0.74),
		"stack": 1,
		"rarity": "uncommon",
		"type": "shoulders",
		"value": 44,
		"defense_bonus": 3.5,
		"visual_state": "legion_pauldrons",
	},
	"pauldrons": {
		"name": "Pauldrons",
		"color": Color(0.68, 0.7, 0.74),
		"stack": 1,
		"rarity": "rare",
		"type": "shoulders",
		"value": 80,
		"defense_bonus": 5.5,
		"visual_state": "pauldrons",
	},
	"cuffs": {
		"name": "Cuffs",
		"color": Color(0.6, 0.5, 0.4),
		"stack": 1,
		"rarity": "common",
		"type": "wrists",
		"value": 8,
		"defense_bonus": 0.5,
		"visual_state": "cuffs",
	},
	"lace_cuffs": {
		"name": "Lace Cuffs",
		"color": Color(0.6, 0.5, 0.4),
		"stack": 1,
		"rarity": "common",
		"type": "wrists",
		"value": 10,
		"defense_bonus": 0.5,
		"visual_state": "lace_cuffs",
	},
	"bracers": {
		"name": "Bracers",
		"color": Color(0.6, 0.5, 0.4),
		"stack": 1,
		"rarity": "uncommon",
		"type": "wrists",
		"value": 34,
		"defense_bonus": 2.5,
		"visual_state": "bracers",
	},
	"dagger": {
		"name": "Dagger",
		"color": Color(0.78, 0.8, 0.84),
		"stack": 1,
		"rarity": "common",
		"type": "weapon",
		"value": 14,
		"dmg_bonus": 3.0,
		"attack_anim": "attack_slash",
		"visual_state": "dagger",
	},
	"arming_sword": {
		"name": "Arming Sword",
		"color": Color(0.78, 0.8, 0.84),
		"stack": 1,
		"rarity": "common",
		"type": "weapon",
		"value": 40,
		"dmg_bonus": 7.0,
		"attack_anim": "attack_slash",
		"visual_state": "arming_sword",
	},
	"saber": {
		"name": "Saber",
		"color": Color(0.78, 0.8, 0.84),
		"stack": 1,
		"rarity": "uncommon",
		"type": "weapon",
		"value": 60,
		"dmg_bonus": 9.0,
		"attack_anim": "attack_slash",
		"visual_state": "saber",
	},
	"rapier": {
		"name": "Rapier",
		"color": Color(0.78, 0.8, 0.84),
		"stack": 1,
		"rarity": "uncommon",
		"type": "weapon",
		"value": 66,
		"dmg_bonus": 9.5,
		"attack_anim": "attack_slash",
		"visual_state": "rapier",
	},
	"mace": {
		"name": "Mace",
		"color": Color(0.78, 0.8, 0.84),
		"stack": 1,
		"rarity": "uncommon",
		"type": "weapon",
		"value": 70,
		"dmg_bonus": 10.0,
		"attack_anim": "attack_slash",
		"visual_state": "mace",
	},
	"flail": {
		"name": "Flail",
		"color": Color(0.78, 0.8, 0.84),
		"stack": 1,
		"rarity": "uncommon",
		"type": "weapon",
		"value": 78,
		"dmg_bonus": 11.0,
		"attack_anim": "attack_slash",
		"visual_state": "flail",
	},
	"waraxe": {
		"name": "War Axe",
		"color": Color(0.78, 0.8, 0.84),
		"stack": 1,
		"rarity": "rare",
		"type": "weapon",
		"value": 105,
		"dmg_bonus": 13.0,
		"attack_anim": "attack_slash",
		"visual_state": "waraxe",
	},
	"longsword": {
		"name": "Longsword",
		"color": Color(0.78, 0.8, 0.84),
		"stack": 1,
		"rarity": "rare",
		"type": "weapon",
		"value": 120,
		"dmg_bonus": 14.0,
		"attack_anim": "attack_slash",
		"visual_state": "longsword",
	},
	"scythe": {
		"name": "Scythe",
		"color": Color(0.78, 0.8, 0.84),
		"stack": 1,
		"rarity": "epic",
		"type": "weapon",
		"value": 180,
		"dmg_bonus": 18.0,
		"attack_anim": "attack_slash",
		"visual_state": "scythe",
	},
	"glowsword": {
		"name": "Glowsword",
		"color": Color(0.78, 0.8, 0.84),
		"stack": 1,
		"rarity": "legendary",
		"type": "weapon",
		"value": 400,
		"dmg_bonus": 22.0,
		"attack_anim": "attack_slash",
		"visual_state": "glowsword",
	},
	"spear": {
		"name": "Spear",
		"color": Color(0.78, 0.8, 0.84),
		"stack": 1,
		"rarity": "common",
		"type": "weapon",
		"value": 35,
		"dmg_bonus": 6.0,
		"attack_anim": "attack_thrust",
		"visual_state": "spear",
	},
	"halberd": {
		"name": "Halberd",
		"color": Color(0.78, 0.8, 0.84),
		"stack": 1,
		"rarity": "rare",
		"type": "weapon",
		"value": 130,
		"dmg_bonus": 15.0,
		"attack_anim": "attack_thrust",
		"visual_state": "halberd",
	},
	"simple_staff": {
		"name": "Apprentice Staff",
		"color": Color(0.78, 0.8, 0.84),
		"stack": 1,
		"rarity": "common",
		"type": "weapon",
		"value": 45,
		"dmg_bonus": 4.0,
		"attack_anim": "attack_cast",
		"visual_state": "simple_staff",
	},
	"slingshot": {
		"name": "Slingshot",
		"color": Color(0.78, 0.8, 0.84),
		"stack": 1,
		"rarity": "common",
		"type": "weapon",
		"value": 20,
		"dmg_bonus": 4.0,
		"attack_anim": "attack_shoot",
		"visual_state": "slingshot",
	},
}


static func get_item(id: String) -> Dictionary:
	if ITEMS.has(id):
		return ITEMS[id].duplicate()
	return {
		"name": id,
		"color": Color.WHITE,
		"stack": 99,
		"rarity": "common",
		"type": "misc",
		"value": 1,
	}


static func display_name(id: String) -> String:
	return str(get_item(id).get("name", id))


static func is_weapon(id: String) -> bool:
	return str(get_item(id).get("type", "")) == "weapon"


## Attack animation for the weapon in this slot, or the unarmed default.
static func attack_anim(id: String) -> StringName:
	if id == "":
		return &"attack_slash"
	return StringName(str(get_item(id).get("attack_anim", "attack_slash")))


static func is_consumable(id: String) -> bool:
	return str(get_item(id).get("type", "")) == "consumable"


static func is_armor(id: String) -> bool:
	return str(get_item(id).get("type", "")) == "armor"


static func is_helmet(id: String) -> bool:
	return str(get_item(id).get("type", "")) == "helmet"


static func is_secondary(id: String) -> bool:
	return str(get_item(id).get("type", "")) == "secondary"


static func is_legs(id: String) -> bool:
	return str(get_item(id).get("type", "")) == "legs"


static func is_feet(id: String) -> bool:
	return str(get_item(id).get("type", "")) == "feet"

static func is_arms(id: String) -> bool:
	return str(get_item(id).get("type", "")) == "arms"

static func is_gloves(id: String) -> bool:
	return str(get_item(id).get("type", "")) == "gloves"

static func is_shoulders(id: String) -> bool:
	return str(get_item(id).get("type", "")) == "shoulders"

static func is_wrists(id: String) -> bool:
	return str(get_item(id).get("type", "")) == "wrists"


## Every equippable id, in catalogue order. Used by the debug loadout and tests.
static func equippable_ids() -> Array:
	var out: Array = []
	for id in ITEMS:
		if DataIntegrity.EQUIPPABLE_TYPES.has(str(ITEMS[id].get("type", ""))):
			out.append(id)
	return out

class_name LpcEquipment
extends RefCounted
## Maps an item to the LPC piece that draws it.
##
## The only link between gameplay and how a piece of gear looks: ItemDB gives an
## item a `visual_state` key, and this turns that key into an LPC piece from the
## bundled library. Adding art for an item is one line here plus (if it is not
## bundled yet) its name in art_pipeline/lpc/selection.json.
##
## An item with no mapping simply draws nothing — equipping it still works, it
## just has no appearance yet. That is deliberate: gear must never be blocked on
## art existing.

## ItemDB visual_state -> LPC piece key (see game/assets/lpc/index.json).
const PIECES := {
	"longsleeve_shirt": "torso/Longsleeve",
	"leather_armor": "torso/Leather",
	"chainmail": "torso/Chainmail",
	"legion_armor": "torso/Legion",
	"plate_armor": "torso/Plate",
	"shorts": "legs/Shorts",
	"hose": "legs/Hose",
	"pants": "legs/Pants",
	"pantaloons": "legs/Pantaloons",
	"plate_leggings": "legs/Armour",
	"spangenhelm": "hat/Spangenhelm",
	"kettle_helm": "hat/Kettle helm",
	"bascinet": "hat/Bascinet",
	"barbuta": "hat/Barbuta",
	"greathelm": "hat/Greathelm",
	"plus_shield": "shield/Plus shield",
	"round_shield": "shield/Two engrailed shield",
	"scutum_shield": "shield/Scutum shield",
	"spartan_shield": "shield/Spartan Shield",
	"crusader_shield": "shield/Crusader shield",
	"quiver": "shield/Quiver",
	"basic_boots": "feet/Basic Shoes",
	"rimmed_boots": "feet/Rimmed Boots",
	"folded_boots": "feet/Folded Rim Boots",
	"revised_boots": "feet/Revised Boots",
	"plate_boots": "feet/Armour",
	"plate_bracers": "arms/Armour",
	"gloves": "gloves/Gloves",
	"epaulets": "shoulders/Epaulets",
	"mantle": "shoulders/Mantal",
	"legion_pauldrons": "shoulders/Legion",
	"pauldrons": "shoulders/Pauldrons",
	"cuffs": "wrists/Cuffs",
	"lace_cuffs": "wrists/Lace Cuffs",
	"bracers": "wrists/Bracers",
	"dagger": "weapon/Dagger",
	"arming_sword": "weapon/Arming Sword",
	"saber": "weapon/Saber",
	"rapier": "weapon/Rapier",
	"mace": "weapon/Mace",
	"flail": "weapon/Flail",
	"waraxe": "weapon/Waraxe",
	"longsword": "weapon/Longsword",
	"scythe": "weapon/Scythe",
	"glowsword": "weapon/Glowsword",
	"spear": "weapon/Spear",
	"halberd": "weapon/Halberd",
	"simple_staff": "weapon/Simple staff",
	"slingshot": "weapon/Slingshot",
}

## Fallback appearance when a slot has an item we have no art for. Empty means
## "draw nothing", which is what we want — a wrong-looking piece is worse than
## no piece.
const NO_PIECE := ""

## Pieces that resolve real LPC art (so the strict "every equippable item has
## art" rule and the inventory icon crop both still work) but are deliberately
## never drawn on the paperdoll — a quiver strapped to the back reads as visual
## noise the player did not ask for. CharacterVisual checks this before adding
## a piece to the draw stack; piece_for() itself still resolves normally.
const HIDDEN_ON_BODY := {
	"shield/Quiver": true,
}

static var _warned: Dictionary = {}


## LPC piece key for an item in a slot, or "" when nothing should be drawn.
static func piece_for(_slot: String, visual_state: String) -> String:
	if visual_state == "":
		return NO_PIECE
	var key := str(PIECES.get(visual_state, NO_PIECE))
	if key == NO_PIECE:
		_warn_once(visual_state, "has no LPC piece mapped in LpcEquipment.PIECES")
		return NO_PIECE
	if not LpcLibrary.has_piece(key):
		_warn_once(visual_state, "maps to '%s', which is not in the bundled library — add it to art_pipeline/lpc/selection.json and re-run the importer" % key)
		return NO_PIECE
	return key


## Which visual_states currently have art. Used by the validator.
static func mapped_states() -> Array:
	return PIECES.keys()


## True for a piece that resolves real art but must never be drawn on the body.
static func is_hidden_on_body(piece_key: String) -> bool:
	return HIDDEN_ON_BODY.has(piece_key)


static func _warn_once(visual_state: String, msg: String) -> void:
	if _warned.has(visual_state):
		return
	_warned[visual_state] = true
	push_warning("[LpcEquipment] '%s' %s" % [visual_state, msg])

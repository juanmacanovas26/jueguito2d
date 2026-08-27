class_name BuildCatalog
extends RefCounted
## Single source of truth for what build mode can place: id, category,
## label. hud.gd builds the palette FROM this table at runtime instead of
## hardcoding a GridContainer per category in hud.tscn, so adding a
## placeable — or a whole new category — is a data change here, not a scene
## edit.
##
## Today every category is dev_only: this is still the Fase 2 mapping tool
## (mobs/resources/POIs), not something a player should see. The split
## world_zone.gd's build-mode section describes — this same place->save->
## reload loop becoming a player-facing construction mode (structures,
## decoration) — is meant to happen by adding new categories here with
## dev_only = false, and having whatever player-facing entry point filters
## the palette to non-dev_only categories. No such entry point exists yet;
## this is the extension point for when one does.

## Category id -> {label, dev_only}, in palette display order.
const CATEGORIES := [
	["mob", {"label": "MOBS", "dev_only": true}],
	["resource", {"label": "RECURSOS", "dev_only": true}],
	["poi", {"label": "POIS", "dev_only": true}],
]

## Placeable id -> {category, label}, in palette display order within its
## category. The id is what ZoneBuilder/world_zone.gd's _instantiate_marker()
## and BuildIcons both key off.
const ENTRIES := [
	["mob", {"category": "mob", "label": "Mob"}],
	["tree", {"category": "resource", "label": "Árbol"}],
	["rock", {"category": "resource", "label": "Roca"}],
	["vein", {"category": "resource", "label": "Vena de hierro"}],
	["vendor", {"category": "poi", "label": "POI: Vendor"}],
	["bank", {"category": "poi", "label": "POI: Bank"}],
	["repair", {"category": "poi", "label": "POI: Repair"}],
	["dungeon_entrance", {"category": "poi", "label": "POI: Entrada dungeon"}],
	["mini_boss", {"category": "poi", "label": "POI: Mini-boss"}],
]


static func label_for(id: String) -> String:
	for entry in ENTRIES:
		if str(entry[0]) == id:
			return str(entry[1].get("label", id))
	return id


## Ids belonging to one category, in palette order.
static func ids_in_category(category: String) -> Array[String]:
	var out: Array[String] = []
	for entry in ENTRIES:
		if str(entry[1].get("category", "")) == category:
			out.append(str(entry[0]))
	return out


## Flat list of every placeable id, in the order the whole palette (and the
## 1-9 hotbar) presents them: category order, then entry order within it.
static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for cat in CATEGORIES:
		out.append_array(ids_in_category(str(cat[0])))
	return out

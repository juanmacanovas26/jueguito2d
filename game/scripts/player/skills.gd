class_name Skills
extends Node
## Progression-by-use engine (docs/GDD.md "Progresión y farm" -> Skills).
## Character power is entirely the sum of these points — there is no separate
## character level or XP bar. Each skill rises by being used (see the gain()
## call sites in player.gd, resource_node.gd, chase_mob.gd), with diminishing
## returns as it nears its own cap, and a shared budget across every skill so
## specializing means sacrificing something else (GDD's "cap total de skills
## activas").

signal skill_changed(skill_id: String, points: float, delta: float)

## Per-skill ceiling (GDD: "Niveles 1-100 (soft cap + endgame)").
const SKILL_CAP := 100.0
## Shared ceiling across every skill combined (GDD: "cap total ... orden de
## ~700 pts, número exacto por calibrar" — this is that number, still a
## placeholder to tune once there is more than a handful of skills).
const TOTAL_CAP := 700.0

## Every gain() also feeds a slice of itself into this skill, so max HP (see
## player.gd's _apply_derived_stats) rises from playing in general instead of
## needing its own dedicated grind.
const VITALITY_ID := "vitality"
const VITALITY_SHARE := 0.25

## Display name per skill id. Also doubles as "every skill id the game knows
## about today" for anything that wants to list them (HUD, tools).
const NAMES := {
	"heavy_swords": "Espadas Pesadas",
	"spellcraft": "Hechicería",
	"archery": "Puntería",
	"vitality": "Vitalidad",
	"woodcutting": "Tala",
	"mining": "Minería",
	"blacksmithing": "Herrería",
}

## skill_id -> points (0..SKILL_CAP). An id absent from this dictionary is
## implicitly at 0 — get_points() handles that, nothing else should read
## `points` directly.
@export var points: Dictionary = {}


func get_points(skill_id: String) -> float:
	return float(points.get(skill_id, 0.0))


func total_points() -> float:
	var total := 0.0
	for v in points.values():
		total += float(v)
	return total


## Grants up to `amount` raw uses of `skill_id`, scaled down by that skill's
## own diminishing returns and by whatever's left of the shared TOTAL_CAP
## budget. Returns the points actually granted — 0.0 if the skill or the
## whole budget is already maxed, which callers can use to skip a toast.
func gain(skill_id: String, amount: float) -> float:
	var granted := _gain_raw(skill_id, amount)
	if granted > 0.0 and skill_id != VITALITY_ID:
		_gain_raw(VITALITY_ID, granted * VITALITY_SHARE)
	return granted


func _gain_raw(skill_id: String, amount: float) -> float:
	if amount <= 0.0 or skill_id == "":
		return 0.0
	var current := get_points(skill_id)
	if current >= SKILL_CAP:
		return 0.0
	# Diminishing returns: the first points come fast, the last few before
	# the cap are slow. Floored at 5% so a dedicated grind can still finish
	# it off instead of asymptotically never arriving.
	var efficiency := clampf(1.0 - current / SKILL_CAP, 0.05, 1.0)
	var effective: float = amount * efficiency
	effective = minf(effective, SKILL_CAP - current)
	var budget: float = TOTAL_CAP - total_points()
	effective = minf(effective, maxf(0.0, budget))
	if effective <= 0.0:
		return 0.0
	var new_points := current + effective
	points[skill_id] = new_points
	skill_changed.emit(skill_id, new_points, effective)
	return effective


## For SaveSystem.
func get_snapshot() -> Dictionary:
	return points.duplicate()


## For SaveSystem. Clamps rather than trusting the file blindly, so a
## hand-edited or stale save can't hand a skill negative or over-cap points.
## A save with no "skills" key (old level/xp saves, pre-progression-by-use)
## just starts every skill at 0 — see docs/GDD.md's roadmap note.
func load_snapshot(data: Dictionary) -> void:
	points.clear()
	for skill_id in data:
		var v := clampf(float(data[skill_id]), 0.0, SKILL_CAP)
		if v > 0.0:
			points[str(skill_id)] = v


static func label_for(skill_id: String) -> String:
	return str(NAMES.get(skill_id, skill_id))

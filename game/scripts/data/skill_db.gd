class_name SkillDB
extends RefCounted
## Every skill in the game, as data.
##
## Same shape as ItemDB on purpose: adding a skill is a row here, not code. The
## caster (SkillCaster) reads these fields and knows nothing about any specific
## skill.
##
## TARGETING — three modes, mixed the way a MOBA does it:
##
##   SELF        no target. Buffs, stances, dashes.
##   TARGET      point-and-click, Argentum Online style: the click has to land
##               ON the enemy's hurtbox at that instant. It is NOT a tab-target
##               lock — if they strafe out from under the cursor you miss, and
##               the cast still costs its resource and cooldown. Clicking a
##               moving player IS the aim, which is why movement speed is the
##               counter to it.
##   GROUND_AOE  placed at the cursor with a telegraph and a delay, so it can be
##               walked out of after it is committed.
##   SKILLSHOT   a travelling projectile aimed by the mouse. Dodged by moving.
##
## All three are beaten by movement, just at different moments: TARGET at the
## click, GROUND_AOE during the telegraph, SKILLSHOT during the travel.
##
## TIMING is in seconds, never in animation frames — the animation is scaled to
## fit the window, not the other way round (docs/ARQUITECTURA.md). That is also
## what makes these safe to re-resolve on a server later.
##
##   startup   wind-up; nothing has happened yet, the telegraph is up
##   active    the moment the effect lands
##   recovery  locked out, punishable
##
## COST is spent at cast time, not on hit, so a whiff still costs.

enum Targeting { SELF, TARGET, GROUND_AOE, SKILLSHOT }

const TARGETING_NAMES := {
	"self": Targeting.SELF,
	"target": Targeting.TARGET,
	"ground_aoe": Targeting.GROUND_AOE,
	"skillshot": Targeting.SKILLSHOT,
}

## kit -> the skills it can cast, in slot order (skill_1 .. skill_4).
const LOADOUTS := {
	"warrior": ["shoulder_bash", "whirlwind"],
	"mage": ["frost_nova", "arcane_bolt", "smite"],
	"archer": ["caltrops", "multishot"],
}

const SKILLS := {
	# --- warrior -----------------------------------------------------------
	"shoulder_bash": {
		"name": "Shoulder Bash",
		"targeting": "self",
		"anim": "attack_thrust",
		"startup": 0.10, "active": 0.14, "recovery": 0.26,
		"cooldown": 6.0,
		"stamina_cost": 22.0,
		"damage_mul": 1.4,
		"poise_damage": 30.0,
		"interrupt": true,          # one of the few things that DOES interrupt
		"dash_speed": 520.0,
		## How far the charge actually carries you. The aimer clamps to this and
		## the dash travels TO the aimed point, so the preview never lies about
		## where you end up.
		"cast_range": 150.0,
		"radius": 34.0,
		"color": Color(1.0, 0.75, 0.35),
		## Impact burst at the caster's own position — see VfxLibrary /
		## game/assets/vfx/shoulder_impact.
		"impact_vfx": "shoulder_impact",
	},
	"whirlwind": {
		"name": "Whirlwind",
		"targeting": "self",
		"anim": "attack_slash",
		"startup": 0.14, "active": 0.20, "recovery": 0.30,
		"cooldown": 9.0,
		"stamina_cost": 30.0,
		"damage_mul": 1.1,
		"poise_damage": 12.0,
		"radius": 58.0,
		"color": Color(0.95, 0.6, 0.3),
		## Spinning disc around the caster — see VfxLibrary / game/assets/vfx/whirlwind_spin.
		"impact_vfx": "whirlwind_spin",
	},
	# --- mage --------------------------------------------------------------
	"frost_nova": {
		"name": "Frost Nova",
		"targeting": "ground_aoe",
		"anim": "attack_cast",
		"startup": 0.22, "active": 0.10, "recovery": 0.34,
		"cooldown": 8.0,
		"mana_cost": 26.0,
		"damage_mul": 1.6,
		"poise_damage": 10.0,
		"cast_range": 260.0,
		"radius": 62.0,
		## Extra beat between the telegraph appearing and the hit landing, so it
		## can be walked out of. This is the whole point of a ground AoE.
		"telegraph": 0.45,
		"color": Color(0.45, 0.75, 1.0),
		## Sprite effect dropped where it lands. See VfxLibrary /
		## game/assets/vfx/frost_vortex.
		"impact_vfx": "frost_vortex",
	},
	"arcane_bolt": {
		"name": "Arcane Bolt",
		"targeting": "skillshot",
		"anim": "attack_cast",
		"startup": 0.12, "active": 0.05, "recovery": 0.22,
		"cooldown": 2.0,
		"mana_cost": 12.0,
		"damage_mul": 1.2,
		"poise_damage": 6.0,
		"projectile_speed": 340.0,
		## Short range on purpose — a piercing skillshot that also detonates
		## shouldn't out-range the rest of the kit. ~255px (speed * life).
		"projectile_life": 0.75,
		"radius": 6.0,
		## Warm, near-white tint — bolt_arcane is now cut from the fire-colored
		## row of its sheet (not the desaturated one), so it's already orange
		## and this just keeps the aim preview matching without washing it out.
		"color": Color(1.0, 0.75, 0.45),
		## Sprite the projectile shows in flight — a spinning fireball, to match
		## end_vfx's fire_vortex burst. See VfxLibrary / game/assets/vfx/bolt_arcane.
		"visual_effect": "bolt_arcane",
		"visual_scale": 4.0,
		## Punches through the first enemy instead of stopping on it — pierce=1
		## lets it survive exactly one hit, at full damage (no falloff).
		"pierce": 1,
		"pierce_falloff": 0.0,
		## The small burst (SkillCaster._fire_projectiles turns these into the
		## projectile's end_burst) goes off wherever the flight actually ends:
		## the natural end of its range, OR on a second enemy using up the
		## pierce budget — whichever comes first. Damage is a fraction of the
		## direct hit.
		"end_radius": 30.0,
		"end_damage_mul": 0.35,
		"end_poise_damage": 4.0,
		"end_vfx": "fire_vortex",
	},
	# --- archer ------------------------------------------------------------
	"caltrops": {
		"name": "Caltrops",
		"targeting": "ground_aoe",
		"anim": "attack_shoot",
		"startup": 0.16, "active": 0.08, "recovery": 0.24,
		"cooldown": 10.0,
		"stamina_cost": 20.0,
		"damage_mul": 0.8,
		"poise_damage": 4.0,
		"cast_range": 200.0,
		"radius": 48.0,
		"telegraph": 0.30,
		"color": Color(0.85, 0.8, 0.5),
		## Spike burst where it lands — see VfxLibrary / game/assets/vfx/caltrop_burst.
		"impact_vfx": "caltrop_burst",
	},
	"multishot": {
		"name": "Multishot",
		"targeting": "skillshot",
		"anim": "attack_shoot",
		"startup": 0.18, "active": 0.06, "recovery": 0.28,
		"cooldown": 7.0,
		"stamina_cost": 24.0,
		"damage_mul": 0.9,
		"poise_damage": 4.0,
		"projectile_speed": 380.0,
		"projectile_life": 1.2,
		"projectile_count": 3,
		"spread_deg": 22.0,
		"radius": 6.0,
		# It's arrows, so it costs nothing without a bow to fire them from — see
		# has_bow()/has_arrows() in player.gd, checked before mana/stamina.
		"requires_bow": true,
		# Near-white: the arrow sprite is already colored (wood + steel head),
		# same reasoning as the archer's basic/charged shot in player.gd.
		"color": Color(0.95, 0.95, 0.9),
		"visual_effect": "arrow",
		"visual_scale": 4.6,
	},
	# --- shared ------------------------------------------------------------
	"smite": {
		"name": "Smite",
		"targeting": "target",
		"anim": "attack_cast",
		"startup": 0.20, "active": 0.06, "recovery": 0.28,
		## Not a "did you land it" cooldown — a retry throttle. It applies
		## whether the click hits or misses, so it never gates a real hit
		## behind a long wait, but also can't be spammed every frame trying
		## to land one. See refund_on_miss for the actual cost logic.
		"cooldown": 1.0,
		"mana_cost": 18.0,
		"damage_mul": 1.5,
		"poise_damage": 8.0,
		## 0 = SkillCaster imposes no range cap at all — "the whole screen",
		## by construction: nothing further than the camera shows is clickable.
		"cast_range": 0.0,
		## Pure point-and-click, no telegraph: SkillAimer draws nothing for a
		## cursor_only skill and swaps the OS cursor instead (see arm()) — the
		## cursor itself IS the aim indicator, same idea as an ARPG click-spell.
		"cursor_only": true,
		## The cost is charged like any other cast (see SkillCaster.cast()) but
		## handed straight back if the click lands on nobody — "smite only
		## actually launches if it hits something", without making a miss free
		## to spam (the cooldown above still applies either way).
		"refund_on_miss": true,
		## How forgiving the click is, in pixels around the enemy's centre. Small
		## enough that a moving target can slip out of it — this is the knob that
		## decides how hard point-and-click aiming is.
		"click_slack": 14.0,
		"radius": 10.0,
		"color": Color(1.0, 0.95, 0.6),
	},
}


static func get_skill(id: String) -> Dictionary:
	if SKILLS.has(id):
		return SKILLS[id].duplicate()
	return {}


static func has_skill(id: String) -> bool:
	return SKILLS.has(id)


static func targeting_of(id: String) -> Targeting:
	var key := str(get_skill(id).get("targeting", "self"))
	return TARGETING_NAMES.get(key, Targeting.SELF)


## Total time the caster is locked for. The animation is stretched onto this.
static func duration_of(id: String) -> float:
	var s := get_skill(id)
	return float(s.get("startup", 0.0)) + float(s.get("active", 0.0)) + float(s.get("recovery", 0.0))


static func loadout_for(kit_name: String) -> Array:
	return LOADOUTS.get(kit_name, [])

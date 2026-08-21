class_name SkillAimer
extends Node2D
## The aiming step of a cast: press the skill, see where it reaches and what it
## covers, then click to commit.
##
## Two-step on purpose. A skill that fires the instant you press the key gives
## the player no way to judge range or placement, and with ground AoEs that is
## most of the decision. This is the same flow as a MOBA without quickcast.
##
## Purely presentation — it decides nothing. It reads the skill's own numbers
## and reports the point the player picked; SkillCaster still resolves the cast
## and re-clamps the range itself, so a tampered client cannot cast further by
## lying about the preview (docs/ARQUITECTURA.md).
##
## THE LOOK is deliberately MOBA UI, not world VFX: every indicator here shares
## one fixed cyan (RETICLE_COLOR) for its rings and double-line borders, the
## same way a League indicator stays the same "UI teal" whether the spell is
## fire or ice — that consistency is what reads as UI chrome instead of a
## blob of particles. The skill's own `color` only tints the soft fill, as a
## faint hint of the element underneath. Placement circles draw the area
## itself (a ground summoning-circle ring), not a point reticle capping a
## separate flat fill — the marker IS the boundary.

## Drawn in world space regardless of who owns this node.
const TOP_LEVEL := true

## How far a skillshot preview line is drawn when the skill declares no range.
const DEFAULT_SHOT_RANGE := 320.0

## Fixed targeting-UI cyan shared by every indicator's rings/ticks/border.
const RETICLE_COLOR := Color(0.55, 0.97, 0.94)

## The area marker every placement circle gets — see _draw_aoe_marker().
const AOE_MARKER_TEX := preload("res://assets/ui/indicators/aoe_marker.png")
## Shown next to the marker while the armed skill cannot actually be cast
## right now (e.g. the archer has no bow/arrows) — set by the owner each
## frame (see player.gd's _handle_skill_input), never decided here.
const BLOCKED_TEX := preload("res://assets/ui/indicators/blocked_warning.png")
## Skillshot wedge fill: origin nub -> dashed shaft -> chevron tip, UV-mapped
## onto the tapered wedge polygon so the taper is real art, not a flat color.
const BEAM_TEX := preload("res://assets/ui/indicators/skillshot_beam.png")
## Custom OS cursor for a `cursor_only` skill (smite): no telegraph is drawn
## at all, the cursor itself is the only aim feedback. See arm()/cancel().
const CURSOR_TEX := preload("res://assets/ui/indicators/smite_cursor.png")

var _skill_id: String = ""
var _owner: Node2D = null
var _point: Vector2 = Vector2.ZERO
## True while the armed skill is aimed but cannot be committed — presentation
## only, the owner is the one that knows why (bow/arrows, resources, ...).
var blocked: bool = false


func _ready() -> void:
	top_level = TOP_LEVEL
	z_index = -2
	visible = false


func setup(p_owner: Node2D) -> void:
	_owner = p_owner


func is_aiming() -> bool:
	return _skill_id != ""


func current_skill() -> String:
	return _skill_id


func arm(skill_id: String) -> void:
	_skill_id = skill_id
	visible = true
	if bool(SkillDB.get_skill(skill_id).get("cursor_only", false)):
		Input.set_custom_mouse_cursor(CURSOR_TEX, Input.CURSOR_ARROW, CURSOR_TEX.get_size() * 0.5)
	queue_redraw()


func cancel() -> void:
	if _skill_id != "" and bool(SkillDB.get_skill(_skill_id).get("cursor_only", false)):
		Input.set_custom_mouse_cursor(null)
	_skill_id = ""
	blocked = false
	visible = false
	queue_redraw()


## Where the cast would land right now, already clamped to the skill's range.
## This is what gets handed to SkillCaster when the player clicks.
func aim_point() -> Vector2:
	return _point


func _process(_delta: float) -> void:
	if not is_aiming() or _owner == null:
		return
	var s := SkillDB.get_skill(_skill_id)
	var origin := _owner.global_position
	var cursor := _owner.get_global_mouse_position()
	var max_range := float(s.get("cast_range", 0.0))
	# Clamping here is what makes the preview honest: you cannot aim somewhere
	# the cast would then refuse.
	if max_range > 0.0 and origin.distance_to(cursor) > max_range:
		_point = origin + (cursor - origin).normalized() * max_range
	else:
		_point = cursor
	global_position = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if not is_aiming() or _owner == null:
		return
	var s := SkillDB.get_skill(_skill_id)
	# Pure point-and-click (smite): the custom OS cursor set in arm() IS the
	# indicator. No telegraph, no reticle, nothing drawn here.
	if bool(s.get("cursor_only", false)):
		return
	var origin := _owner.global_position
	var colour: Color = s.get("color", Color(1, 1, 1))
	var max_range := float(s.get("cast_range", 0.0))
	var radius := float(s.get("radius", 0.0))

	match SkillDB.targeting_of(_skill_id):
		SkillDB.Targeting.SELF:
			if float(s.get("dash_speed", 0.0)) > 0.0:
				# A charge: show where it takes you AND what it hits on arrival,
				# because both are decisions the player is making.
				_draw_range(origin, max_range, colour)
				draw_line(origin, _point, Color(RETICLE_COLOR.r, RETICLE_COLOR.g, RETICLE_COLOR.b, 0.5), 2.0)
				_draw_aoe_marker(_point, radius)
			else:
				# Centred on you, but still worth seeing before committing.
				_draw_aoe_marker(origin, radius)

		SkillDB.Targeting.TARGET:
			_draw_range(origin, max_range, colour)
			# The click has to land within this: same area-marker look, just
			# sized to the click's forgiveness instead of a hit radius.
			var slack := maxf(float(s.get("click_slack", 12.0)), 8.0)
			_draw_aoe_marker(_point, slack)
			draw_line(origin, _point, Color(RETICLE_COLOR.r, RETICLE_COLOR.g, RETICLE_COLOR.b, 0.3), 1.0)

		SkillDB.Targeting.GROUND_AOE:
			_draw_range(origin, max_range, colour)
			_draw_aoe_marker(_point, radius)

		SkillDB.Targeting.SKILLSHOT:
			var length := _skillshot_range(s, max_range)
			var dir := (_point - origin).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			_draw_skillshot_beam(origin, origin + dir * length, dir, radius, colour, s)

	_draw_blocked(_point, maxf(radius, 12.0))


## The reach of the skill, so the player can see whether the target is even in
## range before committing. A soft fill across the whole disc reads at a
## glance, and the boundary gets the double-line treatment (one crisp ring
## plus a fainter inner echo) that is the single most recognisable MOBA tell.
## 0 (smite) means SkillCaster imposes no cap at all, so there is nothing
## meaningful to draw a boundary at — skipped on purpose.
func _draw_range(origin: Vector2, max_range: float, colour: Color) -> void:
	if max_range <= 0.0:
		return
	draw_circle(origin, max_range, Color(colour.r, colour.g, colour.b, 0.04))
	draw_arc(origin, max_range, 0.0, TAU, 96,
		Color(RETICLE_COLOR.r, RETICLE_COLOR.g, RETICLE_COLOR.b, 0.5), 2.0)
	draw_arc(origin, max_range - 5.0, 0.0, TAU, 96,
		Color(RETICLE_COLOR.r, RETICLE_COLOR.g, RETICLE_COLOR.b, 0.2), 1.0)


## The area marker every placement circle gets, showing exactly where and how
## big the effect is — a ground summoning-circle look (ring, compass
## crosshair, cardinal ornaments), not a point reticle: this IS the area, so
## it draws the boundary itself rather than capping a separate flat fill.
## Stretched uniformly to the actual radius/slack, so a small TARGET click
## and a large GROUND_AOE placement both read as "this is the area".
func _draw_aoe_marker(center: Vector2, r: float) -> void:
	var size := Vector2.ONE * (r * 2.0)
	draw_texture_rect(AOE_MARKER_TEX, Rect2(center - size * 0.5, size), false,
		Color(RETICLE_COLOR.r, RETICLE_COLOR.g, RETICLE_COLOR.b, 0.9))


## The "can't cast" warning, shown beside the area marker while `blocked` is true.
## Presentation only — the owner decides why (see player.gd).
func _draw_blocked(center: Vector2, r: float) -> void:
	if not blocked:
		return
	var native := BLOCKED_TEX.get_size()
	var size_px := maxf(r * 0.9, 24.0)
	var scale: float = size_px / maxf(native.x, native.y)
	var size := native * scale
	var pos := center + Vector2(size_px * 1.6, -size_px * 1.6) - size * 0.5
	draw_texture_rect(BLOCKED_TEX, Rect2(pos, size), false, Color(1, 1, 1, 0.95))


## How far a skillshot preview should actually reach. Most skillshots have no
## cast_range — their true reach is projectile_speed * projectile_life — so
## falling back to DEFAULT_SHOT_RANGE for those would show a length that has
## nothing to do with where the shot actually stops.
func _skillshot_range(s: Dictionary, max_range: float) -> float:
	if max_range > 0.0:
		return max_range
	var reach := float(s.get("projectile_speed", 0.0)) * float(s.get("projectile_life", 0.0))
	return reach if reach > 0.0 else DEFAULT_SHOT_RANGE


## A skillshot indicator the way a MOBA draws one: a wedge that starts almost
## as a point at the caster and widens toward the far end (never a constant-
## width lane — that reads as a wall, not a shot). The wedge is UV-textured
## with BEAM_TEX (hollow anchor ring, hollow shaft, chevron arrowhead) instead
## of a flat fill, so the taper is real art, not two thin lines — and the same
## area marker used everywhere else caps the point where the shot stops. Drawn
## at well under full opacity: a skillshot preview has to stay translucent
## enough to still see the ground and enemies through it, same as the range
## fill elsewhere in this file. Width is a legibility choice, not the real
## hit radius.
func _draw_skillshot_beam(origin: Vector2, tip: Vector2, dir: Vector2, radius: float,
		colour: Color, s: Dictionary) -> void:
	var half_w := maxf(radius * 2.4, 12.0)
	var near_w := half_w * 0.45
	var perp := Vector2(-dir.y, dir.x)
	var glow := Color(RETICLE_COLOR.r, RETICLE_COLOR.g, RETICLE_COLOR.b, 0.14)

	var p_near_l := origin + perp * near_w
	var p_near_r := origin - perp * near_w
	var p_far_l := tip + perp * half_w
	var p_far_r := tip - perp * half_w
	# Soft glow first, underneath the textured wedge — echoes the rest of the
	# aim UI's layered-edge language without fighting the art's own highlights.
	draw_polyline(PackedVector2Array([p_near_l, p_far_l]), glow, 7.0, true)
	draw_polyline(PackedVector2Array([p_near_r, p_far_r]), glow, 7.0, true)

	var pts := PackedVector2Array([p_near_l, p_far_l, p_far_r, p_near_r])
	# u: 0 at the near (nub/anchor) end -> 1 at the far (chevron/tip) end.
	# v: 0/1 across the wedge's width, matching the "l"/"r" edges above.
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	draw_polygon(pts, PackedColorArray([Color(1, 1, 1, 0.6)]), uvs, BEAM_TEX)

	_draw_aoe_marker(tip, half_w)

	# Spread cone, when the skill fires more than one — kept as faint boundary
	# lines outside the main beam rather than merged into its fill.
	var count := int(s.get("projectile_count", 1))
	var spread := deg_to_rad(float(s.get("spread_deg", 0.0)))
	if count > 1 and spread > 0.0:
		var length := origin.distance_to(tip)
		for edge_ang in [-spread * 0.5, spread * 0.5]:
			draw_line(origin, origin + dir.rotated(edge_ang) * length,
				Color(RETICLE_COLOR.r, RETICLE_COLOR.g, RETICLE_COLOR.b, 0.22), 1.0)

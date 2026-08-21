class_name Projectile
extends Area2D

@export var speed: float = 320.0
@export var lifetime: float = 1.4
@export var damage: float = 10.0
@export var poise_damage: float = 4.0
@export var team: StringName = &"player"
@export var pierce: int = 0
## 0..1 — damage reduced by this fraction per enemy pierced (0.1 = -10% each)
@export var pierce_damage_falloff: float = 0.0

## Frame rate for a looping sprite effect (bolt_arcane's spin). Static effects
## and the plain polygon fallback ignore this.
const VFX_FPS := 20.0

var direction: Vector2 = Vector2.RIGHT
var _alive: float = 0.0
var _hit_ids: Dictionary = {}
var _source: Node = null
var _hit_count: int = 0
var _vfx_frames: Array[Texture2D] = []
var _vfx_sprite: Sprite2D = null
var _vfx_elapsed: float = 0.0
var end_burst: Dictionary = {}


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_apply_layers()


func setup(
	p_dir: Vector2,
	p_team: StringName,
	p_damage: float,
	p_poise: float,
	p_speed: float,
	p_lifetime: float,
	p_source: Node,
	p_color: Color = Color(0.55, 0.75, 1.0, 0.95),
	p_radius: float = 5.0,
	p_pierce: int = 0,
	p_pierce_falloff: float = 0.0,
	## Optional game/assets/vfx/<id> sprite in place of the plain polygon dot,
	## tinted by p_color so charge gradients / kit colors still apply.
	p_visual_effect: String = "",
	## Sprite size relative to p_radius, purely cosmetic — the hitbox stays at
	## p_radius. The source art sits in a padded 64px cell, so 1.0 renders
	## small; each bolt tunes its own so the art actually reads on screen.
	p_visual_scale: float = 1.0,
	## {radius, damage, poise, effect} — if radius > 0, detonated as an AoE hit
	## (with an optional VfxLibrary sprite) at wherever the projectile is when
	## it runs out of lifetime naturally. Not triggered by hitting a wall or by
	## using up its last pierce — only by actually reaching the end of its
	## range, which is what "small splash at the end" means.
	p_end_burst: Dictionary = {}
) -> void:
	direction = p_dir.normalized() if p_dir.length_squared() > 0.0 else Vector2.RIGHT
	team = p_team
	damage = p_damage
	poise_damage = p_poise
	speed = p_speed
	lifetime = p_lifetime
	_source = p_source
	pierce = p_pierce
	pierce_damage_falloff = p_pierce_falloff
	end_burst = p_end_burst
	_hit_count = 0
	rotation = direction.angle()
	_apply_layers()
	_build_visual(p_color, p_radius, p_visual_effect, p_visual_scale)


func _apply_layers() -> void:
	collision_layer = 0
	if team == &"player":
		collision_mask = (1 << 0) | (1 << 2) # world + enemy hurtbox
		collision_layer = 1 << 3
	else:
		collision_mask = (1 << 0) | (1 << 1)
		collision_layer = 1 << 4


func _build_visual(color: Color, radius: float, effect_id: String = "", visual_scale: float = 1.0) -> void:
	var frames: Array[Texture2D] = []
	if effect_id != "":
		frames = VfxLibrary.frames_for(effect_id)
	var poly := get_node_or_null("Body") as Polygon2D

	if frames.is_empty():
		# Plain vector dot — the original look, used whenever no art is set.
		_vfx_frames = []
		if _vfx_sprite:
			_vfx_sprite.visible = false
		if poly == null:
			poly = Polygon2D.new()
			poly.name = "Body"
			add_child(poly)
		poly.visible = true
		var pts: PackedVector2Array = PackedVector2Array()
		var n := 8
		for i in n:
			var a := TAU * float(i) / float(n)
			pts.append(Vector2(cos(a), sin(a)) * radius)
		poly.polygon = pts
		poly.color = color
	else:
		# Sprite art, sized to the same radius the polygon would have used and
		# tinted the same way, so charge gradients / kit colors still apply on
		# top of the (desaturated) source art.
		if poly:
			poly.visible = false
		_vfx_frames = frames
		_vfx_elapsed = 0.0
		if _vfx_sprite == null:
			_vfx_sprite = Sprite2D.new()
			_vfx_sprite.name = "FxSprite"
			_vfx_sprite.centered = true
			add_child(_vfx_sprite)
		_vfx_sprite.visible = true
		_vfx_sprite.modulate = color
		_vfx_sprite.texture = frames[0]
		var native_radius := frames[0].get_size().x * 0.5
		if native_radius > 0.0:
			_vfx_sprite.scale = Vector2.ONE * (radius * visual_scale / native_radius)

	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	var circle := shape_node.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		shape_node.shape = circle
	circle.radius = radius


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_alive += delta
	if _vfx_frames.size() > 1:
		_vfx_elapsed += delta
		_vfx_sprite.texture = _vfx_frames[int(_vfx_elapsed * VFX_FPS) % _vfx_frames.size()]
	if _alive >= lifetime:
		_detonate_end_burst()
		queue_free()


## The small splash a bolt like arcane_bolt drops when its flight is over —
## either it reached the natural end of its range (called from
## `_physics_process`) or it used up its last pierce on a second enemy
## (called from `_on_area_entered`, at that enemy's position). Separate from
## the direct-hit resolution, which already happened by the time this runs.
func _detonate_end_burst() -> void:
	var radius := float(end_burst.get("radius", 0.0))
	if radius <= 0.0:
		return
	var space := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = 0xFFFFFFFF
	# Otherwise the query finds the projectile's own Area2D shape first.
	params.exclude = [get_rid()]
	for hit in space.intersect_shape(params, 32):
		var area = hit.get("collider")
		if area is Hurtbox and area.has_method("apply_hit") and area.team != team:
			area.apply_hit({
				"damage": float(end_burst.get("damage", 0.0)),
				"poise_damage": float(end_burst.get("poise", 0.0)),
				"knockback": 0.0,
				"hit_stun": 0.08,
				"direction": direction,
				"team": team,
				"source": _source,
			})
	var effect_id := str(end_burst.get("effect", ""))
	if effect_id != "":
		SkillImpactFx.spawn(global_position, effect_id, radius)


func _on_area_entered(area: Area2D) -> void:
	if not area.has_method("apply_hit"):
		return
	var id := area.get_instance_id()
	if _hit_ids.has(id):
		return
	_hit_ids[id] = true
	# Damage falls off per already-pierced enemy (archer charged shot)
	var mult := pow(maxf(0.0, 1.0 - pierce_damage_falloff), _hit_count)
	var hit := {
		"damage": damage * mult,
		"poise_damage": poise_damage * mult,
		"knockback": 0.0,
		"hit_stun": 0.08,
		"direction": direction,
		"team": team,
		"source": _source,
	}
	if area.apply_hit(hit):
		_hit_count += 1
		if _hit_count > pierce:
			# Used up its last pierce — detonates right here instead of only at
			# the natural end of its range (arcane_bolt: "pierce one, explode on
			# whatever stops it next").
			_detonate_end_burst()
			queue_free()


func _on_body_entered(body: Node) -> void:
	# Gatherable nodes (trees/rocks) are handled via their hurtbox, not as walls
	if body.is_in_group("gatherable"):
		return
	# Walls / static world
	if body is StaticBody2D or body is TileMap or body is TileMapLayer:
		queue_free()

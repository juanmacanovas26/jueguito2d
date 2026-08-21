extends Node
## Headless check of the LPC paperdoll pipeline. Dev tool, not shipped code.
##
##   Godot_v4.7.1-stable_win64_console.exe --headless --path game \
##       res://tools/validate_visuals.tscn
##
## Exits 0 when everything passes, 1 otherwise.

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const VISUAL_SET := "res://resources/visuals/lpc_male_set.tres"
const ProjectileScene := preload("res://scenes/combat/projectile.tscn")

## Floor for how many checks this suite must run (see _check_ran_enough).
const MIN_CHECKS := 100

var _failures: Array = []
var _checks := 0


func _ready() -> void:
	await _run()


func _run() -> void:
	print("== validate_visuals (LPC) ==")
	_check_index()
	_check_visual_set()
	_check_sheets_resolve()
	_check_directions()
	await _check_player_scene()
	await _check_paperdoll()
	await _check_live_player()
	_check_impact_vfx()
	_check_projectile_vfx()

	_check_ran_enough()
	print("\n-- %d checks, %d failures --" % [_checks, _failures.size()])
	for f in _failures:
		print("FAIL: " + f)
	print("RESULT: " + ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _ok(l: String) -> void:
	_checks += 1
	print("  ok   " + l)


func _fail(l: String) -> void:
	_checks += 1
	_failures.append(l)
	print("  FAIL " + l)


func _expect(cond: bool, l: String) -> void:
	if cond:
		_ok(l)
	else:
		_fail(l)


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



## Game slot -> the LPC category it draws from. Only the two that differ.
func _lpc_slot_for(slot: String) -> String:
	match slot:
		"armor": return "torso"
		"secondary": return "shield"
		"helmet": return "hat"
		_: return slot


# ------------------------------------------------------------------ checks


func _check_index() -> void:
	print("\n[1] Bundled LPC index")
	var ix := LpcLibrary.load_index()
	_expect(not ix.is_empty(), "index.json loads")
	if ix.is_empty():
		return
	_expect(str(ix.get("format", "")) == "lpc-upstream-v1",
		"format is the upstream layout (%s)" % ix.get("format"))
	_expect(ix.get("directions") == ["north", "west", "south", "east"],
		"direction rows are LPC order (%s)" % str(ix.get("directions")))

	# Every slot the character composes must have at least one piece bundled, or
	# that slot can never be filled. Deliberately NOT a hardcoded count: adding
	# art to selection.json must not require editing this test.
	var slots := CharacterVisual.SLOTS.duplicate()
	slots.append_array(["body", "head", "hair"])
	var total := 0
	for slot in slots:
		var lpc_slot := _lpc_slot_for(str(slot))
		var n := LpcLibrary.pieces_in_slot(lpc_slot).size()
		total += n
		_expect(n > 0, "slot '%s' has %d piece(s) bundled" % [slot, n])
	_expect(total == LpcLibrary.piece_keys().size(),
		"every bundled piece belongs to a slot the character composes (%d of %d)"
			% [total, LpcLibrary.piece_keys().size()])


func _check_visual_set() -> void:
	print("\n[2] Visual set matches the art")
	var res = load(VISUAL_SET)
	if not (res is CharacterVisualSet):
		_fail("%s is not a CharacterVisualSet" % VISUAL_SET)
		return
	_ok("loaded %s" % VISUAL_SET)
	_expect(res.frame_size == Vector2i(64, 64), "frame_size is LPC 64x64 (got %s)" % res.frame_size)

	# Frame counts must equal what the body art actually has, per animation.
	var body := "body/Body Color"
	for id in res.animation_ids():
		var anim: CharacterAnimation = res.get_animation(id)
		var on_disk := LpcLibrary.frame_count(body, id)
		_expect(on_disk > 0, "body has art for '%s' (%d frames)" % [id, on_disk])
		_expect(anim.frame_count == on_disk,
			"'%s': set says %d frames, art has %d" % [id, anim.frame_count, on_disk])
		_expect(anim.fps > 0.0, "'%s' has a playback speed" % id)


func _check_sheets_resolve() -> void:
	print("\n[3] Every bundled layer resolves a real texture")
	var anims := ["idle", "walk", "attack_slash", "dash", "death"]
	var missing := 0
	var pieces := 0
	var sizes := {}
	for key in LpcLibrary.piece_keys():
		pieces += 1
		for a in anims:
			for layer in LpcLibrary.layers_for(key, StringName(a)):
				sizes[int(layer.get("frame", 0))] = true
				var tex := LpcLibrary.frame_texture(layer, CharacterFacing.Direction.SOUTH, 0)
				if tex == null:
					missing += 1
					if missing <= 3:
						print("       -> %s / %s : %s" % [key, a, layer.get("sheet")])
	_expect(missing == 0, "%d pieces resolved every layer (%d missing)" % [pieces, missing])
	for s in sizes:
		_expect(s % 64 == 0 and s > 0, "frame size %dpx is a multiple of 64" % s)

	# Worn gear must cover every SHARED animation or it vanishes mid-action.
	# Weapons are the exception: each one only has art for its own kind of
	# attack (a sword slashes, a bow shoots), so they are required to cover the
	# shared set plus at least one attack.
	var shared := ["idle", "walk", "dash", "death"]
	var attacks := ["attack_slash", "attack_thrust", "attack_cast", "attack_shoot"]
	var gaps: Array = []
	for key in LpcLibrary.piece_keys():
		var is_weapon := str(key).begins_with("weapon/")
		for a in shared:
			if LpcLibrary.frame_count(key, StringName(a)) == 0:
				gaps.append("%s/%s" % [key, a])
		if is_weapon:
			var has_attack := false
			for a in attacks:
				if LpcLibrary.frame_count(key, StringName(a)) > 0:
					has_attack = true
			if not has_attack:
				gaps.append("%s: no attack animation at all" % key)
		else:
			for a in attacks:
				if LpcLibrary.frame_count(key, StringName(a)) == 0:
					gaps.append("%s/%s" % [key, a])
	_expect(gaps.is_empty(), "no piece is missing an animation it needs (%d gaps)" % gaps.size())
	for g in gaps.slice(0, 6):
		print("       -> " + g)


func _check_directions() -> void:
	print("\n[4] Four real directions, nothing mirrored")
	var body := "body/Body Color"
	var layers := LpcLibrary.layers_for(body, &"walk")
	_expect(not layers.is_empty(), "body has walk layers")
	if layers.is_empty():
		return
	var l: Dictionary = layers[0]
	_expect(int(l.get("rows", 0)) == 4, "walk has 4 direction rows (got %s)" % l.get("rows"))

	var regions := {}
	for d in [CharacterFacing.Direction.NORTH, CharacterFacing.Direction.WEST,
			CharacterFacing.Direction.SOUTH, CharacterFacing.Direction.EAST]:
		var tex := LpcLibrary.frame_texture(l, d, 0)
		if tex is AtlasTexture:
			regions[CharacterFacing.dir_name(d)] = tex.region
	_expect(regions.size() == 4, "all four directions resolve a region")
	var distinct := {}
	for k in regions:
		distinct[str(regions[k])] = true
	_expect(distinct.size() == 4,
		"each direction reads its OWN row, none shares art (%d distinct)" % distinct.size())

	# East and west must be genuinely different art, not a flip.
	var e: AtlasTexture = LpcLibrary.frame_texture(l, CharacterFacing.Direction.EAST, 0)
	var w: AtlasTexture = LpcLibrary.frame_texture(l, CharacterFacing.Direction.WEST, 0)
	_expect(e != null and w != null and e.region != w.region,
		"EAST and WEST come from different rows (no mirroring needed)")

	# hurt is the one single-row animation; it must not crash on other facings.
	var hl := LpcLibrary.layers_for(body, &"death")
	if not hl.is_empty():
		_expect(int(hl[0].get("rows", 0)) == 1, "death/hurt is single-row, as LPC ships it")
		_expect(LpcLibrary.frame_texture(hl[0], CharacterFacing.Direction.NORTH, 0) != null,
			"asking death for a direction it lacks still returns art")


func _check_player_scene() -> void:
	print("\n[5] Player scene: gameplay geometry independent of the sprite")
	var packed = load(PLAYER_SCENE)
	var player = packed.instantiate()
	add_child(player)
	await get_tree().physics_frame
	_ok("instantiated player.tscn")

	var visual = player.get_node_or_null("CharacterVisual")
	_expect(visual is CharacterVisual, "player has a CharacterVisual")
	if visual is CharacterVisual:
		_expect(visual.visual_set != null, "visual_set is assigned in the scene")
		_expect(LpcLibrary.has_piece(visual.body_piece),
			"body_piece '%s' is bundled" % visual.body_piece)
		_expect(LpcLibrary.has_piece(visual.head_piece),
			"head_piece '%s' is bundled" % visual.head_piece)
		_expect(LpcLibrary.has_piece(visual.hair_piece),
			"hair_piece '%s' is bundled" % visual.hair_piece)

	var body_shape = player.get_node_or_null("CollisionShape2D")
	var hit_shape = player.get_node_or_null("Facing/Hitbox/CollisionShape2D")
	_expect(body_shape != null and body_shape.shape.size == Vector2(18, 26),
		"body collision is still 18x26, not tied to the 64px frame")
	_expect(hit_shape != null and hit_shape.shape.size == Vector2(16, 16),
		"hitbox is still 16x16")
	player.free()


func _check_paperdoll() -> void:
	print("\n[6] Paperdoll composition")
	var visual := CharacterVisual.new()
	visual.visual_set = load(VISUAL_SET)
	add_child(visual)
	await get_tree().process_frame

	visual.set_direction(CharacterFacing.Direction.SOUTH)
	visual.play(&"walk", true)
	var naked := _visible_layers(visual)
	_expect(naked > 0, "the naked character draws %d layers" % naked)

	visual.set_equipment("armor", "leather_armor")
	var armored := _visible_layers(visual)
	_expect(armored > naked, "equipping armour adds layers (%d -> %d)" % [naked, armored])

	visual.set_equipment("weapon", "arming_sword")
	var armed := _visible_layers(visual)
	_expect(armed > armored, "equipping a weapon adds layers (%d -> %d)" % [armored, armed])

	# A weapon splits around the body: some layers behind it, some in front.
	var zs := _layer_zs(visual)
	var body_z := 10
	_expect(zs.min() < body_z and zs.max() > body_z,
		"layers sit both behind and in front of the body (z %d..%d)" % [zs.min(), zs.max()])

	# Swapping gear must show immediately, even on a 2-frame idle that barely ticks.
	visual.play(&"idle", true)
	var before := _layer_textures(visual)
	visual.set_equipment("helmet", "barbuta")
	var after := _layer_textures(visual)
	_expect(before != after, "a gear change repaints immediately, without waiting for a frame tick")

	# Every shipped item now has LPC art (items without it were removed), so
	# this probes the path with a visual_state that was never mapped: a future
	# item must draw nothing rather than guess a piece.
	visual.set_equipment("secondary", "not_mapped_yet")
	_expect(visual.get_equipment_piece("secondary") == "",
		"an unmapped visual_state draws nothing instead of guessing")

	# And the shipped catalogue must be fully covered.
	var unmapped: Array = []
	for id in ItemDB.ITEMS:
		var d: Dictionary = ItemDB.ITEMS[id]
		if not DataIntegrity.EQUIPPABLE_TYPES.has(str(d.get("type", ""))):
			continue
		if LpcEquipment.piece_for(str(d["type"]), str(d.get("visual_state", ""))) == "":
			unmapped.append(id)
	_expect(unmapped.is_empty(),
		"every equippable item has LPC art (%d without)" % unmapped.size())
	for u in unmapped:
		print("       -> " + str(u))

	# The quiver is a deliberate exception: it must still resolve real LPC art
	# (so it isn't flagged as unmapped above, and its inventory icon still
	# crops from something real) but must never add a visible layer — a quiver
	# strapped to the back was decided to be visual noise, unlike a shield.
	visual.set_equipment("secondary", "")
	var no_secondary := _visible_layers(visual)
	visual.set_equipment("secondary", "quiver")
	_expect(visual.get_equipment_piece("secondary") == "shield/Quiver",
		"the quiver still resolves real LPC art")
	_expect(_visible_layers(visual) == no_secondary,
		"  but equipping it adds no visible body layer")
	visual.set_equipment("secondary", "round_shield")
	_expect(_visible_layers(visual) > no_secondary,
		"  unlike a real shield, which does draw")
	visual.set_equipment("secondary", "")

	# Hair must hide under a helmet, or it pokes through the metal.
	visual.set_equipment("helmet", "")
	visual.play(&"walk", true)
	var bare_head := _visible_layers(visual)
	visual.set_equipment("helmet", "barbuta")
	var helmed := _visible_layers(visual)
	_expect(helmed == bare_head, "a helmet replaces the hair layer rather than stacking on it (%d -> %d)" % [bare_head, helmed])
	visual.set_equipment("helmet", "")
	_expect(_visible_layers(visual) == bare_head, "taking the helmet off brings the hair back")

	# The timeline follows the body, per animation.
	for id in ["idle", "walk", "attack_slash", "dash", "death"]:
		visual.play(StringName(id), true)
		_expect(visual.get_frame_count() == LpcLibrary.frame_count(visual.body_piece, StringName(id)),
			"'%s' plays %d frames, matching the body art" % [id, visual.get_frame_count()])

	# Effects survive everything.
	_expect(visual.get_effects_layer() != null and visual.get_effects_layer().z_index == CharacterVisual.EFFECTS_Z,
		"the effects layer sits above every composed layer")
	visual.free()


func _check_live_player() -> void:
	print("\n[7] A live Player driven through every state")
	var player = load(PLAYER_SCENE).instantiate()
	add_child(player)
	await get_tree().physics_frame
	var visual: CharacterVisual = player.get_node("CharacterVisual")

	_expect(visual.get_animation_id() == &"idle",
		"standing still plays idle (got '%s')" % visual.get_animation_id())

	for probe in [["move_right", CharacterFacing.Direction.EAST],
			["move_left", CharacterFacing.Direction.WEST],
			["move_up", CharacterFacing.Direction.NORTH],
			["move_down", CharacterFacing.Direction.SOUTH]]:
		Input.action_press(probe[0])
		await get_tree().physics_frame
		await get_tree().physics_frame
		_expect(visual.get_animation_id() == &"walk" and player.facing_dir == probe[1],
			"%s -> walk facing %s" % [probe[0], CharacterFacing.dir_name(probe[1])])
		_expect(_visible_layers(visual) > 0, "  and something is actually drawn")
		Input.action_release(probe[0])
		await get_tree().physics_frame

	player.state = player.State.ATTACK
	player._attack_startup = 0.10
	player._attack_active = 0.08
	player._attack_recovery = 0.18
	player._update_hero_sprite()
	_expect(visual.get_animation_id() == &"attack_slash", "State.ATTACK with a sword plays 'attack_slash'")

	# Every weapon must drive its own attack animation, and have the art for it.
	for probe in [["arming_sword", &"attack_slash"], ["spear", &"attack_thrust"],
			["simple_staff", &"attack_cast"], ["slingshot", &"attack_shoot"]]:
		if player.inventory.count_item(str(probe[0])) < 1:
			player.inventory.add_item(str(probe[0]), 1)
		_expect(player.equip_weapon(str(probe[0])), "equipped '%s'" % probe[0])
		player.state = player.State.ATTACK
		player._update_hero_sprite()
		_expect(visual.get_animation_id() == probe[1],
			"'%s' attacks with '%s' (got '%s')" % [probe[0], probe[1], visual.get_animation_id()])
		_expect(_visible_layers(visual) > 0, "  and draws layers for it")
		var piece := LpcEquipment.piece_for("weapon", str(probe[0]))
		_expect(LpcLibrary.frame_count(piece, probe[1]) > 0,
			"  and the weapon itself has %s art" % probe[1])

	player.state = player.State.DODGE
	player._dodge_dir = Vector2.LEFT
	player._update_hero_sprite()
	_expect(visual.get_animation_id() == &"dash", "State.DODGE plays 'dash'")

	player.state = player.State.DEAD
	player._update_hero_sprite()
	_expect(visual.get_animation_id() == &"death", "State.DEAD plays 'death'")

	# Equipping must not touch gameplay tuning.
	player.state = player.State.FREE
	var speed_before: float = player.MOVE_SPEED
	player.inventory.add_item("plate_armor", 1)
	_expect(player.equip_armor("plate_armor"), "equip_armor succeeds")
	player._update_hero_sprite()
	_expect(player.MOVE_SPEED == speed_before, "equipping changed no movement tuning")
	player.free()


func _check_impact_vfx() -> void:
	print("\n[8] Skill impact VFX")
	# Every skill that declares an impact_vfx must resolve real frames — a typo
	# in the effect id would otherwise fail silently (VfxLibrary just returns
	# an empty array, it never errors).
	var declared := 0
	for id in SkillDB.SKILLS:
		var s: Dictionary = SkillDB.SKILLS[id]
		var effect_id := str(s.get("impact_vfx", ""))
		if effect_id == "":
			continue
		declared += 1
		var frames := VfxLibrary.frames_for(effect_id)
		_expect(not frames.is_empty(),
			"%s's impact_vfx '%s' resolves at least one frame" % [id, effect_id])
		var first_size: Vector2 = frames[0].get_size() if not frames.is_empty() else Vector2.ZERO
		var consistent := true
		for f in frames:
			if f.get_size() != first_size:
				consistent = false
		_expect(consistent, "  and every frame of '%s' shares one canvas size" % effect_id)
	_expect(declared > 0, "at least one skill declares an impact_vfx")

	# Spawning must not error, and it must respect the requested radius rather
	# than drawing at whatever size the source sheet happened to be.
	var frost := SkillDB.get_skill("frost_nova")
	var radius := float(frost.get("radius", 0.0))
	var before := get_tree().get_node_count()
	SkillImpactFx.spawn(Vector2(40, 40), "frost_vortex", radius)
	await get_tree().process_frame
	_expect(get_tree().get_node_count() > before, "spawning the impact vfx adds a node")


func _check_projectile_vfx() -> void:
	print("\n[9] Projectile VFX")
	# The mage's and archer's basic/charged shots pick their effect straight in
	# player.gd, so they aren't discoverable by scanning SkillDB like impact_vfx
	# is — check the bolt/arrow ids directly instead.
	for effect_id in ["bolt_plain", "bolt_charged", "bolt_arcane", "arrow"]:
		_expect(not VfxLibrary.frames_for(effect_id).is_empty(),
			"'%s' resolves at least one frame" % effect_id)

	var arcane := SkillDB.get_skill("arcane_bolt")
	_expect(str(arcane.get("visual_effect", "")) == "bolt_arcane",
		"arcane_bolt's skillshot uses bolt_arcane")
	var multishot := SkillDB.get_skill("multishot")
	_expect(str(multishot.get("visual_effect", "")) == "arrow",
		"multishot's skillshot uses the arrow sprite")

	# Spawning with an effect id must swap the sprite in and hide the plain dot.
	var proj: Projectile = ProjectileScene.instantiate()
	add_child(proj)
	proj.setup(Vector2.RIGHT, &"player", 5.0, 0.0, 100.0, 1.0, self,
		Color.WHITE, 6.0, 0, 0.0, "bolt_arcane")
	var fx := proj.get_node_or_null("FxSprite") as Sprite2D
	_expect(fx != null and fx.visible, "a projectile with visual_effect shows a sprite")
	var poly := proj.get_node_or_null("Body") as Polygon2D
	_expect(poly != null and not poly.visible, "  and hides the plain polygon dot")
	proj.free()

	# No effect id (mob projectiles) must keep today's plain polygon look.
	var plain: Projectile = ProjectileScene.instantiate()
	add_child(plain)
	plain.setup(Vector2.RIGHT, &"enemy", 5.0, 0.0, 100.0, 1.0, self)
	var plain_poly := plain.get_node_or_null("Body") as Polygon2D
	_expect(plain_poly != null and plain_poly.visible,
		"a projectile with no visual_effect keeps the plain polygon dot")
	plain.free()

	# arcane_bolt's end-of-range burst (pierces the first enemy, small splash
	# where it finally runs out of range — see validate_systems for the actual
	# damage behaviour).
	_expect(not VfxLibrary.frames_for("fire_vortex").is_empty(),
		"'fire_vortex' resolves at least one frame")
	_expect(int(arcane.get("pierce", 0)) >= 1, "arcane_bolt pierces at least one enemy")
	_expect(float(arcane.get("end_radius", 0.0)) > 0.0,
		"arcane_bolt declares an end_radius for its burst")
	_expect(str(arcane.get("end_vfx", "")) == "fire_vortex",
		"  styled with fire_vortex")


# ------------------------------------------------------------------ helpers


func _visible_layers(v: CharacterVisual) -> int:
	var n := 0
	for c in v.get_children():
		if c is Sprite2D and c.visible and c.name != "Effects":
			n += 1
	return n


func _layer_zs(v: CharacterVisual) -> Array:
	var out: Array = []
	for c in v.get_children():
		if c is Sprite2D and c.visible and c.name != "Effects":
			out.append(c.z_index)
	return out


func _layer_textures(v: CharacterVisual) -> Array:
	var out: Array = []
	for c in v.get_children():
		if c is Sprite2D and c.visible and c.name != "Effects":
			out.append(c.texture)
	return out

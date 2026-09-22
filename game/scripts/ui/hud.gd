extends CanvasLayer

@onready var hp_bar: ProgressBar = $Margin/VBox/HpBar
@onready var stamina_bar: ProgressBar = $Margin/VBox/StaminaBar
@onready var mana_bar: ProgressBar = $Margin/VBox/ManaBar
@onready var xp_bar: ProgressBar = $Margin/VBox/XpBar
@onready var hp_text: Label = $Margin/VBox/HpText
@onready var style_text: Label = $Margin/VBox/StyleText
@onready var level_text: Label = $Margin/VBox/LevelText
@onready var help: Label = $Margin/Help
@onready var toast_label: Label = $Toast
@onready var inv_panel: PanelContainer = $InvPanel
@onready var inv_list: ItemList = $InvPanel/Margin/VBox/InvList
@onready var inv_title: Label = $InvPanel/Margin/VBox/InvTitle
@onready var equip_row: GridContainer = $InvPanel/Margin/VBox/EquipRow
@onready var stats_text: Label = $InvPanel/Margin/VBox/StatsText
@onready var craft_panel: PanelContainer = $CraftPanel
@onready var craft_list: ItemList = $CraftPanel/Margin/VBox/CraftList
@onready var craft_title: Label = $CraftPanel/Margin/VBox/CraftTitle
@onready var skill_bar: SkillBar = $SkillBar
@onready var pause_panel: PanelContainer = $PausePanel
@onready var resume_button: Button = $PausePanel/Margin/VBox/ResumeButton
@onready var save_button: Button = $PausePanel/Margin/VBox/SaveButton
@onready var save_quit_button: Button = $PausePanel/Margin/VBox/SaveQuitButton
@onready var quit_button: Button = $PausePanel/Margin/VBox/QuitButton
@onready var build_panel: PanelContainer = $BuildPanel
@onready var build_categories: VBoxContainer = $BuildPanel/Margin/VBox/CategoriesScroll/Categories
@onready var build_selected_label: Label = $BuildPanel/Margin/VBox/SelectedLabel
@onready var discovery_panel: PanelContainer = $DiscoveryPanel
@onready var discovery_choices: VBoxContainer = $DiscoveryPanel/Margin/VBox/Choices
@onready var discovery_dismiss_button: Button = $DiscoveryPanel/Margin/VBox/DismissButton

## Built from BuildCatalog in _ready() — one shared exclusive group for every
## kind button regardless of which category it's in.
var _build_kind_group := ButtonGroup.new()
## id -> its Button, so the 1-9 hotbar can select the same way a click would.
var _build_kind_buttons: Dictionary = {}
## Flat id order, index 0..8 == hotbar keys 1..9 (see BuildCatalog.all_ids()).
var _build_hotbar_ids: Array[String] = []

var _toast_time: float = 0.0
var _inv_open: bool = false
var _craft_open: bool = false
var _paused: bool = false
var _last_inv: Inventory = null
var _inv_ids: Array = []
var _recipe_ids: Array = []
var _player: Node = null


func _ready() -> void:
	Game.player_stats_changed.connect(_on_stats)
	Game.inventory_changed.connect(_on_inv)
	Game.toast_msg.connect(_on_toast)
	Game.discovery_offered.connect(_on_discovery_offered)
	if inv_list:
		inv_list.item_activated.connect(_on_item_activated)
	# Each equipment slot button is named after its slot, so one handler covers
	# all four and adding a slot later needs no code here.
	if equip_row:
		for button in equip_row.get_children():
			if button is Button:
				button.pressed.connect(_on_equip_slot_pressed.bind(button.name))
	if craft_list:
		craft_list.item_activated.connect(_on_craft_activated)
	if resume_button:
		resume_button.pressed.connect(_toggle_pause)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if save_quit_button:
		save_quit_button.pressed.connect(_on_save_and_quit_to_menu)
	if quit_button:
		quit_button.pressed.connect(_on_quit_game)
	_build_palette()
	help.text = "Q Warrior | E Mage | F Archer | LMB tap/hold | RMB guard | G auto-gather | I inv | C craft | B build | ESC pause | F1 hitboxes | F2 gm-mode | T snap / R techo (build)"
	hp_bar.max_value = 100
	stamina_bar.max_value = 100
	if mana_bar:
		mana_bar.max_value = 100
	if xp_bar:
		xp_bar.max_value = 100
		xp_bar.value = 0
	if inv_panel:
		inv_panel.visible = false
	if craft_panel:
		craft_panel.visible = false
		_refresh_craft_list()
	if toast_label:
		toast_label.visible = false
	if pause_panel:
		pause_panel.visible = false
	if build_panel:
		build_panel.visible = false
	if discovery_panel:
		discovery_panel.visible = false
	if discovery_dismiss_button:
		discovery_dismiss_button.pressed.connect(_on_discovery_dismiss)


## Builds the build-mode palette from BuildCatalog: one Label + GridContainer
## per category, one toggle Button per placeable id. Nothing here is
## hardcoded to "mob/tree/rock/..." — adding a category (e.g. a future
## player-facing "structure"/"decoration" build mode) or a new id inside an
## existing one is a BuildCatalog data change, not a scene edit.
func _build_palette() -> void:
	if build_categories == null:
		return
	_build_hotbar_ids = BuildCatalog.all_ids()
	for cat in BuildCatalog.CATEGORIES:
		var category_id := str(cat[0])
		var category_label := str(cat[1].get("label", category_id))
		var ids := BuildCatalog.ids_in_category(category_id)
		if ids.is_empty():
			continue

		var header := Label.new()
		header.add_theme_color_override("font_color", Color(0.75, 0.75, 0.7, 1))
		header.add_theme_font_size_override("font_size", 11)
		header.text = category_label
		build_categories.add_child(header)

		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		build_categories.add_child(grid)

		for id in ids:
			var button := Button.new()
			button.custom_minimum_size = Vector2(40, 40)
			button.toggle_mode = true
			button.button_group = _build_kind_group
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.expand_icon = true
			button.tooltip_text = BuildCatalog.label_for(id)
			grid.add_child(button)
			_build_kind_buttons[id] = button
			# toggled (not pressed): reports the actual new state, which is
			# what a button inside an exclusive ButtonGroup needs — and wire
			# the click before touching the icon, so a future icon-loading
			# problem for one id can't leave every id after it un-clickable
			# (see BuildIcons._load_square()'s note).
			button.toggled.connect(_on_build_kind_toggled.bind(id))
			button.icon = BuildIcons.get_icon(id)

	var first_button: Button = _build_kind_buttons.get(Game.build_selected_kind)
	if first_button:
		first_button.button_pressed = true
	if build_selected_label:
		build_selected_label.text = "Selección: %s" % BuildCatalog.label_for(Game.build_selected_kind)


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0 and toast_label:
			toast_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			# Closing whatever panel/mode is open takes priority over pausing,
			# so ESC never needs two presses to get back to a clean screen.
			if _inv_open:
				_toggle_inventory()
			elif _craft_open:
				_toggle_craft()
			elif discovery_panel and discovery_panel.visible:
				_on_discovery_dismiss()
			elif Game.build_mode:
				_toggle_build_mode()
			else:
				_toggle_pause()
			return
		if _paused:
			return
		if event.keycode == KEY_B:
			_toggle_build_mode()
			return
		# GM mode has to work whether or not build mode is on — it's the
		# fly-around tool FOR mapping a large world in build mode, not just a
		# standalone dev toggle — so it's checked before the build_mode branch
		# below returns early and swallows every other key.
		if event.keycode == KEY_F2:
			Game.gm_mode = not Game.gm_mode
			Game.toast("GM mode ON (float + no damage, middle-click to teleport)" if Game.gm_mode else "GM mode OFF")
			return
		if Game.build_mode:
			# Ctrl+Z undoes the last build action (a whole drag counts as
			# one). Checked before the plain-key branches below so the Z in
			# Ctrl+Z can't also read as a bare hotkey.
			if event.keycode == KEY_Z and event.ctrl_pressed:
				var zone := Game.get_world()
				if zone and zone.has_method("undo_build_action"):
					Game.toast("Deshecho" if zone.undo_build_action() else "Nada para deshacer")
				return
			# Hide the roof to work on what's under it — every real tile
			# editor has a layer toggle, and here the roof covers the whole
			# interior by design, so without this the floor/interior cells
			# are unreachable to look at while editing.
			# G: the explicit roof-generation tool. The wall brush no longer
			# creates roof as a side effect, so this is how a finished
			# building gets covered in one action.
			if event.keycode == KEY_G:
				var zone := Game.get_world()
				if zone and zone.has_method("generate_roof_over_walls"):
					var added: int = zone.generate_roof_over_walls()
					if added > 0:
						Game.toast("Techo generado (%d celdas)" % added)
					elif Game.build_roof_material == "none":
						Game.toast("Techo en 'sin techo' — cambialo con R")
					else:
						Game.toast("Nada que techar")
				return
			if event.keycode == KEY_H:
				var zone := Game.get_world()
				var roof: TileMapLayer = zone.get_node_or_null("Roof") if zone else null
				if roof:
					roof.visible = not roof.visible
					Game.toast("Techo: %s" % ("visible" if roof.visible else "oculto"))
				return
			# Q/E rotate the ghost/piece before placing (same convention as
			# Rust/Valheim's building mode) and 1-9 are a hotbar shortcut for
			# the palette click — both only make sense while build mode is
			# on, and the player's own Q/E (kit swap) is already frozen then
			# (see player.gd's Game.build_mode guard), so there's no clash.
			if event.keycode == KEY_Q:
				Game.build_rotation = wrapf(Game.build_rotation - PI / 4.0, 0.0, TAU)
			elif event.keycode == KEY_E:
				Game.build_rotation = wrapf(Game.build_rotation + PI / 4.0, 0.0, TAU)
			elif event.keycode == KEY_T:
				Game.build_snap_to_grid = not Game.build_snap_to_grid
				Game.toast("Snap a grilla: ON" if Game.build_snap_to_grid else "Snap a grilla: OFF")
			elif event.keycode == KEY_BRACKETLEFT or event.keycode == KEY_BRACKETRIGHT:
				# [ / ] resize the floor brush — the binding every paint and
				# tile editor already uses, so it needs no explaining.
				var step := -1 if event.keycode == KEY_BRACKETLEFT else 1
				Game.build_brush_size = clampi(
					Game.build_brush_size + step, 1, Game.MAX_BRUSH_SIZE)
				# Same setting, two meanings: cells for the grid brushes, a
				# radius in pixels for the free one. Say which, or the number
				# on screen means nothing.
				if PaintLayer.is_paint_id(Game.build_selected_kind):
					Game.toast("Pincel: radio %dpx"
						% int(PaintLayer.radius_for(Game.build_brush_size)))
				else:
					Game.toast("Pincel: %dx%d" % [Game.build_brush_size, Game.build_brush_size])
			elif event.keycode == KEY_R:
				# Three-way rather than a separate on/off key: "no roof" is
				# just another option of the same choice, and it keeps the
				# build-mode control surface small.
				var roof_labels := {"slate": "pizarra", "red": "teja roja", "none": "SIN TECHO"}
				match Game.build_roof_material:
					"slate": Game.build_roof_material = "red"
					"red": Game.build_roof_material = "none"
					_: Game.build_roof_material = "slate"
				Game.toast("Techo: %s" % roof_labels.get(Game.build_roof_material, Game.build_roof_material))
			elif event.keycode == KEY_Y:
				# Same split as R for roof: which SHAPE button is selected in
				# the palette is a separate choice from which material paints
				# it (see Game.build_wall_material / StructureTileset.
				# WALL_MATERIALS).
				var wall_labels := {"stone": "piedra", "brick": "ladrillo", "plain": "lisa", "wood": "madera"}
				match Game.build_wall_material:
					"stone": Game.build_wall_material = "brick"
					"brick": Game.build_wall_material = "plain"
					"plain": Game.build_wall_material = "wood"
					_: Game.build_wall_material = "stone"
				Game.toast("Material pared: %s" % wall_labels.get(Game.build_wall_material, Game.build_wall_material))
			elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
				var idx: int = event.keycode - KEY_1
				if idx < _build_hotbar_ids.size():
					var button: Button = _build_kind_buttons.get(_build_hotbar_ids[idx])
					if button:
						button.button_pressed = true
			# While placing/removing markers, ignore the other panel hotkeys
			# instead of teaching each one to coexist with the build cursor.
			return
		if event.keycode == KEY_F1:
			Game.debug_hitboxes = not Game.debug_hitboxes
		elif event.keycode == KEY_I:
			_toggle_inventory()
		elif event.keycode == KEY_C:
			_toggle_craft()


func _toggle_inventory() -> void:
	_inv_open = not _inv_open
	if inv_panel:
		inv_panel.visible = _inv_open
	if _inv_open:
		if _last_inv == null:
			# Game.inventory_changed may have fired (e.g. player debug-kit
			# items added in _ready) before this HUD finished connecting to
			# it — pull the current inventory directly instead of relying
			# on having caught that first signal.
			var p := _get_player()
			if p and "inventory" in p:
				_last_inv = p.inventory
		if _last_inv:
			_refresh_inv_list(_last_inv)


func _toggle_craft() -> void:
	_craft_open = not _craft_open
	if craft_panel:
		craft_panel.visible = _craft_open
	if _craft_open:
		_refresh_craft_list()


## Game.discovery_offered ("1 de 3", docs/GDD.md): builds one Button per
## candidate id fresh each time (same reason as _build_palette() — the set
## changes call to call) and shows the panel. A discovery that arrives while
## one is already up just replaces its choices; see player.gd's
## Player._offer_discovery() for why that's rare enough not to matter.
func _on_discovery_offered(ability_ids: Array) -> void:
	if discovery_choices == null or discovery_panel == null:
		return
	for child in discovery_choices.get_children():
		child.queue_free()
	for id in ability_ids:
		var sid := str(id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 32)
		button.text = str(SkillDB.get_skill(sid).get("name", sid))
		button.pressed.connect(_on_discovery_choice.bind(sid))
		discovery_choices.add_child(button)
	discovery_panel.visible = true


func _on_discovery_choice(skill_id: String) -> void:
	var p := _get_player()
	if p and p.has_method("learn_ability") and p.learn_ability(skill_id):
		if Game.has_method("toast"):
			Game.toast("Learned: %s" % str(SkillDB.get_skill(skill_id).get("name", skill_id)))
	if discovery_panel:
		discovery_panel.visible = false


func _on_discovery_dismiss() -> void:
	if discovery_panel:
		discovery_panel.visible = false


## HUD's process_mode is ALWAYS (see hud.tscn) specifically so this keeps
## receiving input and can un-pause the tree it just paused.
func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	if pause_panel:
		pause_panel.visible = _paused


## The actual placing/removing happens in world_zone.gd, which reads
## Game.build_mode/build_selected_kind directly — this just flips the flag
## and shows the palette.
func _toggle_build_mode() -> void:
	Game.build_mode = not Game.build_mode
	if build_panel:
		build_panel.visible = Game.build_mode
	if Game.build_mode:
		Game.build_rotation = 0.0
	else:
		# Leaving build mode restores normal combat framing — a zoomed-out
		# view left over from mapping would otherwise carry into combat.
		var player := Game.get_local_player()
		if player and ("camera" in player) and player.camera:
			player.camera.zoom = Vector2(1.0, 1.0)


func _on_build_kind_toggled(is_pressed: bool, kind: String) -> void:
	if not is_pressed:
		return
	Game.build_selected_kind = kind
	if build_selected_label:
		build_selected_label.text = "Selección: %s" % BuildCatalog.label_for(kind)
	# The road art has no one-cell-wide piece, so an auto-road brush always
	# paints at least 2x2 whatever the brush is set to (see
	# RoadAutotiler.brush_size_for()). Say so when that is actually
	# overriding what the user asked for, rather than silently widening the
	# ghost and letting them wonder.
	var effective := RoadAutotiler.brush_size_for(kind, Game.build_brush_size)
	if effective > Game.build_brush_size:
		Game.toast("Camino auto: mínimo %dx%d — los caminos necesitan 2 celdas de ancho"
			% [effective, effective])


func _on_save_pressed() -> void:
	Game.toast("Partida guardada" if SaveSystem.save_game() else "No se pudo guardar")


func _on_save_and_quit_to_menu() -> void:
	SaveSystem.save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_quit_game() -> void:
	get_tree().quit()


func _on_toast(text: String) -> void:
	if toast_label:
		toast_label.text = text
		toast_label.visible = true
		_toast_time = 2.2


func _on_inv(inv: Inventory) -> void:
	_last_inv = inv
	if _inv_open:
		_refresh_inv_list(inv)


func _get_player() -> Node:
	if _player and is_instance_valid(_player):
		return _player
	_player = Game.get_local_player()
	return _player


func _on_item_activated(index: int) -> void:
	if index < 0 or index >= _inv_ids.size():
		return
	var item_id: String = str(_inv_ids[index])
	var p := _get_player()
	if p == null:
		return
	# The bag only ever lists unequipped items; taking gear off is the slot
	# buttons' job (see _on_equip_slot_pressed).
	if ItemDB.is_weapon(item_id):
		p.equip_weapon(item_id)
	elif ItemDB.is_armor(item_id):
		p.equip_armor(item_id)
	elif ItemDB.is_helmet(item_id):
		p.equip_helmet(item_id)
	elif ItemDB.is_legs(item_id):
		p.equip_legs(item_id)
	elif ItemDB.is_feet(item_id):
		p.equip_feet(item_id)
	elif ItemDB.is_arms(item_id):
		p.equip_arms(item_id)
	elif ItemDB.is_gloves(item_id):
		p.equip_gloves(item_id)
	elif ItemDB.is_shoulders(item_id):
		p.equip_shoulders(item_id)
	elif ItemDB.is_wrists(item_id):
		p.equip_wrists(item_id)
	elif ItemDB.is_secondary(item_id):
		p.equip_secondary(item_id)
	elif ItemDB.is_consumable(item_id):
		p.use_consumable(item_id)
	else:
		if Game.has_method("toast"):
			Game.toast("Can't use: %s" % ItemDB.display_name(item_id))
	_refresh_inv_list(_last_inv)


func _on_equip_slot_pressed(slot: String) -> void:
	var p := _get_player()
	if p == null or not p.has_method("unequip"):
		return
	if p.unequip(slot):
		_refresh_inv_list(_last_inv)


## Paints every equipment slot: the equipped item's icon, or a dimmed dash when
## the slot is empty. Driven by the button names, so adding a slot is a scene
## change only.
func _refresh_equip_slots() -> void:
	if equip_row == null:
		return
	var p := _get_player()
	for button in equip_row.get_children():
		if not (button is Button):
			continue
		var slot := str(button.name)
		var item_id := ""
		if p and p.has_method("get_equipped"):
			item_id = str(p.get_equipped(slot))
		if item_id == "":
			button.icon = null
			button.text = "–"
			button.disabled = true
			button.tooltip_text = "%s — empty" % slot.capitalize()
			button.modulate = Color(1, 1, 1, 0.45)
		else:
			button.icon = ItemIcons.get_icon(item_id)
			button.text = ""
			button.disabled = false
			button.tooltip_text = "%s\n%s\nClick to unequip" % [
				ItemDB.display_name(item_id), _item_stat_line(item_id)]
			button.modulate = Color.WHITE


## One-line summary of what an item actually does, for tooltips.
func _item_stat_line(item_id: String) -> String:
	var def := ItemDB.get_item(item_id)
	var bits: Array[String] = []
	for field in [["dmg_bonus", "+%s dmg"], ["spell_bonus", "+%s spell"],
			["defense_bonus", "+%s def"], ["heal", "+%s hp"], ["restore_mana", "+%s mp"]]:
		var v := float(def.get(field[0], 0.0))
		if v != 0.0:
			bits.append((field[1] as String) % str(int(v)))
	bits.append("%s · %d gold" % [str(def.get("rarity", "common")), int(def.get("value", 0))])
	return "  ".join(bits)


func _refresh_inv_list(inv: Inventory) -> void:
	if inv_list == null:
		return
	_refresh_equip_slots()
	inv_list.clear()
	_inv_ids.clear()
	var p := _get_player()
	if inv_title:
		inv_title.text = "Inventory — %d gold" % inv.gold

	# The equipped pieces are shown in the slot row above, not in the bag list.
	if stats_text:
		var reduction := 0.0
		var dmg := 0.0
		if p:
			if p.has_method("defense_reduction"):
				reduction = float(p.defense_reduction())
			if p.has_method("_melee_base_damage") and p.has_method("_weapon_dmg_bonus"):
				dmg = float(p._melee_base_damage()) + float(p._weapon_dmg_bonus())
		stats_text.text = "DMG %d    ARMOR %d%%" % [int(round(dmg)), int(round(reduction * 100.0))]

	for s in inv.get_filled_slots():
		var id := str(s.get("id", ""))
		var amt := int(s.get("amount", 0))
		var name := ItemDB.display_name(id)
		_inv_ids.append(id)
		var label := "%s  x%d" % [name, amt] if amt > 1 else name
		if DataIntegrity.EQUIPPABLE_TYPES.has(str(ItemDB.get_item(id).get("type", ""))):
			label += "   [equip]"
		elif ItemDB.is_consumable(id):
			label += "   [use]"
		var idx := inv_list.add_item(label, ItemIcons.get_icon(id))
		inv_list.set_item_custom_fg_color(idx, ItemIcons.rarity_color(id))
		inv_list.set_item_tooltip(idx, "%s\n%s" % [name, _item_stat_line(id)])


func _refresh_craft_list() -> void:
	if craft_list == null:
		return
	craft_list.clear()
	_recipe_ids.clear()
	for recipe in CraftDB.get_recipes():
		_recipe_ids.append(str(recipe.get("id", "")))
		craft_list.add_item(CraftDB.recipe_label(recipe))


func _on_craft_activated(index: int) -> void:
	if index < 0 or index >= _recipe_ids.size():
		return
	var p := _get_player()
	if p == null:
		return
	var recipe_id := str(_recipe_ids[index])
	if p.has_method("try_craft"):
		p.try_craft(recipe_id)
	if _inv_open and _last_inv:
		_refresh_inv_list(_last_inv)
	_refresh_craft_list()


func _on_stats(
	hp: float,
	max_hp: float,
	stamina: float,
	max_stamina: float,
	mana: float,
	max_mana: float,
	defend_style: String,
	defense_msg: String,
	primary_skill_name: String,
	primary_skill_points: float,
	total_skill_points: float,
	gold: int
) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina
	if mana_bar:
		mana_bar.max_value = max_mana
		mana_bar.value = mana
	# xp_bar/level_text are the old level/XP display, repurposed: the bar now
	# tracks the kit's primary combat skill (0..SKILL_CAP) instead of a level
	# curve — there is no character level any more (docs/GDD.md). A proper
	# multi-skill panel is a Fase B/C UI task, not this pass's scope.
	if xp_bar:
		xp_bar.max_value = Skills.SKILL_CAP
		xp_bar.value = primary_skill_points
	hp_text.text = "HP %.0f/%.0f   ST %.0f/%.0f   MP %.0f/%.0f" % [hp, max_hp, stamina, max_stamina, mana, max_mana]
	if level_text:
		level_text.text = "%s %.1f/%.0f   Total %.0f/%.0f   Gold %d" % [
			primary_skill_name, primary_skill_points, Skills.SKILL_CAP,
			total_skill_points, Skills.TOTAL_CAP, gold
		]
	if style_text:
		var msg := "%s" % defend_style
		if defense_msg != "":
			msg += "  |  %s" % defense_msg
		style_text.text = msg

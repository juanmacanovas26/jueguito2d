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

var _toast_time: float = 0.0
var _inv_open: bool = false
var _craft_open: bool = false
var _last_inv: Inventory = null
var _inv_ids: Array = []
var _recipe_ids: Array = []
var _player: Node = null


func _ready() -> void:
	Game.player_stats_changed.connect(_on_stats)
	Game.inventory_changed.connect(_on_inv)
	Game.toast_msg.connect(_on_toast)
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
	help.text = "Q Warrior | E Mage | F Archer | LMB tap/hold | RMB guard | G auto-gather | I inv | C craft | F1 hitboxes"
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


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0 and toast_label:
			toast_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
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
	level: int,
	xp: int,
	xp_to_next: int,
	gold: int
) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina
	if mana_bar:
		mana_bar.max_value = max_mana
		mana_bar.value = mana
	if xp_bar:
		xp_bar.max_value = maxi(xp_to_next, 1)
		xp_bar.value = xp
	hp_text.text = "HP %.0f/%.0f   ST %.0f/%.0f   MP %.0f/%.0f" % [hp, max_hp, stamina, max_stamina, mana, max_mana]
	if level_text:
		level_text.text = "Lv %d   XP %d/%d   Gold %d" % [level, xp, xp_to_next, gold]
	if style_text:
		var msg := "%s" % defend_style
		if defense_msg != "":
			msg += "  |  %s" % defense_msg
		style_text.text = msg

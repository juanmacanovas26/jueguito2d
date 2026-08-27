extends Control
class_name SkillBar
## Renders whatever the player's known_abilities currently holds — never a
## fixed count, since the open skill network (docs/GDD.md) means a character
## can learn abilities beyond their starting kit's defaults over time.
## Self-sufficient like InvPanel/CraftPanel: hud.gd does not need to know
## this exists.

const SLOT_SCENE := preload("res://scenes/ui/skill_slot.tscn")
const KEY_FALLBACK := {0: "Z", 1: "X", 2: "C", 3: "V"}

@onready var _row: HBoxContainer = $SlotRow

var _player: Node = null
var _slots: Array[SkillSlot] = []
var _current_loadout: Array = []


func _process(_delta: float) -> void:
	var p := _get_player()
	visible = p != null
	if p == null:
		return
	var loadout: Array = p.known_abilities
	if loadout != _current_loadout:
		_rebuild(loadout)
	for slot in _slots:
		slot.update(p.skills, p.aimer)


func _get_player() -> Node:
	if _player and is_instance_valid(_player):
		return _player
	_player = Game.get_local_player()
	return _player


func _rebuild(loadout: Array) -> void:
	for child in _row.get_children():
		child.queue_free()
	_slots.clear()
	for i in loadout.size():
		var inst: SkillSlot = SLOT_SCENE.instantiate()
		_row.add_child(inst)
		inst.setup(str(loadout[i]), _key_label(i))
		_slots.append(inst)
	_current_loadout = loadout.duplicate()


static func _key_label(i: int) -> String:
	var events := InputMap.action_get_events("skill_%d" % (i + 1))
	for e in events:
		if e is InputEventKey:
			var k: InputEventKey = e
			return k.as_text_physical_keycode() if k.physical_keycode != 0 else k.as_text_keycode()
	return str(KEY_FALLBACK.get(i, "?"))

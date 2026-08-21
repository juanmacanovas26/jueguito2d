class_name Inventory
extends Node

signal changed
signal item_added(item_id: String, amount: int)
signal item_removed(item_id: String, amount: int)

@export var max_slots: int = 80

## Array of { id: String, amount: int } or empty {}
var slots: Array = []
var gold: int = 0


func _ready() -> void:
	slots.resize(max_slots)
	for i in max_slots:
		if slots[i] == null:
			slots[i] = {}


func clear() -> void:
	for i in max_slots:
		slots[i] = {}
	gold = 0
	changed.emit()


func add_item(item_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	if item_id == "gold_coin":
		gold += amount
		item_added.emit(item_id, amount)
		changed.emit()
		return amount

	var def := ItemDB.get_item(item_id)
	var max_stack: int = int(def.get("stack", 99))
	var remaining := amount

	# Stack into existing
	for i in max_slots:
		var s: Dictionary = slots[i]
		if s.is_empty():
			continue
		if str(s.get("id", "")) != item_id:
			continue
		var cur: int = int(s.get("amount", 0))
		var space: int = max_stack - cur
		if space <= 0:
			continue
		var put: int = mini(space, remaining)
		s["amount"] = cur + put
		slots[i] = s
		remaining -= put
		if remaining <= 0:
			break

	# Empty slots
	while remaining > 0:
		var empty := _first_empty_slot()
		if empty < 0:
			break
		var put2: int = mini(max_stack, remaining)
		slots[empty] = {"id": item_id, "amount": put2}
		remaining -= put2

	var added := amount - remaining
	if added > 0:
		item_added.emit(item_id, added)
		changed.emit()
	return added


func remove_item(item_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	if item_id == "gold_coin":
		var take: int = mini(gold, amount)
		gold -= take
		if take > 0:
			item_removed.emit(item_id, take)
			changed.emit()
		return take

	var remaining := amount
	for i in range(max_slots - 1, -1, -1):
		var s: Dictionary = slots[i]
		if s.is_empty() or str(s.get("id", "")) != item_id:
			continue
		var cur: int = int(s.get("amount", 0))
		var take2: int = mini(cur, remaining)
		cur -= take2
		remaining -= take2
		if cur <= 0:
			slots[i] = {}
		else:
			s["amount"] = cur
			slots[i] = s
		if remaining <= 0:
			break

	var removed := amount - remaining
	if removed > 0:
		item_removed.emit(item_id, removed)
		changed.emit()
	return removed


func count_item(item_id: String) -> int:
	if item_id == "gold_coin":
		return gold
	var total := 0
	for s in slots:
		if typeof(s) != TYPE_DICTIONARY or s.is_empty():
			continue
		if str(s.get("id", "")) == item_id:
			total += int(s.get("amount", 0))
	return total


func get_filled_slots() -> Array:
	var out: Array = []
	for s in slots:
		if typeof(s) == TYPE_DICTIONARY and not s.is_empty():
			out.append(s)
	return out


func _first_empty_slot() -> int:
	for i in max_slots:
		var s = slots[i]
		if s == null or (typeof(s) == TYPE_DICTIONARY and s.is_empty()):
			return i
	return -1


func has_space_for(item_id: String, amount: int = 1) -> bool:
	if item_id == "gold_coin":
		return true
	var def := ItemDB.get_item(item_id)
	var max_stack: int = int(def.get("stack", 99))
	var space := 0
	for s in slots:
		if typeof(s) != TYPE_DICTIONARY or s.is_empty():
			space += max_stack
		elif str(s.get("id", "")) == item_id:
			space += maxi(0, max_stack - int(s.get("amount", 0)))
		if space >= amount:
			return true
	return space >= amount

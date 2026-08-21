class_name Progress
extends Node

signal xp_changed(level: int, xp: int, xp_to_next: int)
signal leveled_up(level: int)

@export var level: int = 1
@export var xp: int = 0


func xp_to_next_level(lv: int = -1) -> int:
	if lv < 1:
		lv = level
	# Soft curve: 50, 75, 105... 
	return int(40 + lv * 25 + lv * lv * 5)


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	var leveled := false
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		leveled = true
		leveled_up.emit(level)
	xp_changed.emit(level, xp, xp_to_next_level())
	if leveled:
		xp_changed.emit(level, xp, xp_to_next_level())


func get_snapshot() -> Dictionary:
	return {
		"level": level,
		"xp": xp,
		"xp_to_next": xp_to_next_level(),
	}

class_name Health
extends Node

signal died
signal damaged(amount: float, current: float)
signal damaged_by(amount: float, current: float, source: Node)
signal health_changed(current: float, maximum: float)

@export var max_hp: float = 100.0
@export var start_full: bool = true

var hp: float = 100.0
var poise: float = 100.0
@export var max_poise: float = 100.0
@export var poise_regen_per_sec: float = 25.0
@export var poise_regen_delay: float = 0.8

var _poise_timer: float = 0.0
var is_dead: bool = false


func _ready() -> void:
	if start_full:
		hp = max_hp
		poise = max_poise
	health_changed.emit(hp, max_hp)


## Poise regen is simulation, not presentation, so it runs on the fixed physics
## step — see docs/ARQUITECTURA.md. On _process it advanced by the RENDER delta,
## which made how fast poise came back depend on the player's framerate and
## would not survive a server-authoritative rewrite.
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _poise_timer > 0.0:
		_poise_timer -= delta
	elif poise < max_poise:
		poise = minf(max_poise, poise + poise_regen_per_sec * delta)


func take_damage(hit_data: Dictionary) -> void:
	if is_dead:
		return
	var amount: float = float(hit_data.get("damage", 0.0))
	if amount <= 0.0 and not hit_data.get("parried", false):
		# still allow zero-damage blocked events without killing logic
		pass
	hp = maxf(0.0, hp - amount)
	poise = maxf(0.0, poise - float(hit_data.get("poise_damage", 0.0)))
	_poise_timer = poise_regen_delay
	var src: Node = hit_data.get("source", null) as Node
	damaged.emit(amount, hp)
	damaged_by.emit(amount, hp, src)
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		is_dead = true
		died.emit()


func heal(amount: float) -> void:
	if is_dead:
		return
	hp = minf(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)


## Whether poise is currently broken.
##
## DESIGN RULE: this is NOT a stagger trigger. A basic attack must never
## interrupt anyone, no matter how much poise damage it has accumulated —
## interruption comes only from effects that ask for it explicitly (a skill, a
## shoulder bash, a hit tagged `interrupt`).
##
## So poise is a RESISTANCE, not a state: an interrupting effect consults this
## to decide whether it breaks through, and the target being at zero poise on
## its own changes nothing. Wiring this into the normal damage path would
## reintroduce exactly the behaviour we ruled out — see docs/COMBATE.md and the
## regression test in tools/validate_systems.gd.
func is_staggered() -> bool:
	return poise <= 0.0

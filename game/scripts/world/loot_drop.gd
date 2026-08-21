extends Area2D
## Ground loot. Walk near or press interact to pick up.

@export var item_id: String = "slime_goo"
@export var amount: int = 1
@export var magnet_range: float = 28.0
@export var auto_pickup: bool = true

@onready var body: Polygon2D = $Body
@onready var label: Label = $Label

var _bob_t: float = 0.0
var _base_y: float = 0.0
var _base_captured: bool = false
var _picked: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1 << 1 # player layer
	body_entered.connect(_on_body_entered)
	_apply_visual()
	_bob_t = randf() * TAU


func setup(p_id: String, p_amount: int = 1) -> void:
	item_id = p_id
	amount = p_amount
	if is_node_ready():
		_apply_visual()


func _apply_visual() -> void:
	var def := ItemDB.get_item(item_id)
	var col: Color = def.get("color", Color.WHITE)
	if body:
		body.color = col
	if label:
		if item_id == "gold_coin":
			label.text = "%d g" % amount
		else:
			label.text = "%s x%d" % [str(def.get("name", item_id)), amount] if amount > 1 else str(def.get("name", item_id))


func _process(delta: float) -> void:
	if _picked:
		return
	# Capture the drop's real height once its world position is final (set after _ready).
	if not _base_captured:
		_base_y = global_position.y
		_base_captured = true
	_bob_t += delta * 3.0
	global_position.y = _base_y + sin(_bob_t) * 2.0

	if not auto_pickup:
		return
	var p := Game.get_local_player()
	if p == null or not (p is Node2D):
		return
	if global_position.distance_to((p as Node2D).global_position) <= magnet_range:
		try_pickup(p)


func _on_body_entered(body_node: Node) -> void:
	if body_node.is_in_group("player"):
		try_pickup(body_node)


func try_pickup(player: Node) -> bool:
	if _picked:
		return false
	var inv: Inventory = player.get_node_or_null("Inventory") as Inventory
	if inv == null:
		return false
	if not inv.has_space_for(item_id, amount):
		return false
	var added := inv.add_item(item_id, amount)
	if added <= 0:
		return false
	_picked = true
	# toast via Game if present
	if Game.has_method("toast"):
		Game.toast("+%s x%d" % [ItemDB.display_name(item_id), added] if item_id != "gold_coin" else "+%d gold" % added)
	queue_free()
	return true

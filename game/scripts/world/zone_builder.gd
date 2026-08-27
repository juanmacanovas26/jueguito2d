class_name ZoneBuilder
extends RefCounted
## Turns the marker nodes an author placed in a zone's "Markers" group
## (MobSpawnMarker, ResourceNodeMarker, POIMarker) into live entities. Pulled
## out of world_zone.gd so every zone scene shares one builder instead of
## reimplementing spawn logic per zone — the point of Fase 2's mapping tool
## is that a new zone is "drag markers, done", not "write a new _build_*()".
##
## Everything that actually enters the world still goes through normal
## instance()+add_child() here, same as world_zone.gd always did; this class
## only decides WHAT to spawn and WHERE, not how spawning itself works (see
## docs/ARQUITECTURA.md for why that distinction matters for netcode later).

const MobScene := preload("res://scenes/enemy/chase_mob.tscn")
const ResourceNodeScene := preload("res://scenes/world/resource_node.tscn")


## Walks every marker under markers_root, spawns the corresponding runtime
## node into an "Obstacles"/"Mobs" container under zone_root (created if
## missing), and returns the POI markers found — nothing consumes those yet,
## Fase 3 will. When out_spawns is given, marker -> spawned-node pairs are
## recorded into it (Dictionary is passed by reference) so a caller like
## world_zone.gd's build-mode overlay can later find and free the live entity
## a given marker produced — see save_markers_layout()'s note on why that
## mapping must NOT live on the marker itself (Node.set_meta()), which would
## get embedded and serialized the next time the marker is packed to disk.
static func build(markers_root: Node, zone_root: Node, out_spawns: Dictionary = {}) -> Array[POIMarker]:
	var pois: Array[POIMarker] = []
	for child in markers_root.get_children():
		if child is POIMarker:
			pois.append(child)
		else:
			var spawned := build_one(child, zone_root)
			if spawned:
				out_spawns[child] = spawned
	return pois


## Spawns the single live entity a marker describes (mob or gatherable) and
## returns it, or null for a POI (nothing consumes those yet) or an unknown
## node. Used both by build() above and by the runtime build-mode overlay
## (world_zone.gd) so placing a marker while playing gives instant feedback
## instead of waiting for the next zone reload.
static func build_one(marker: Node, zone_root: Node) -> Node:
	if marker is MobSpawnMarker:
		return _build_mob(marker, _ensure_container(zone_root, "Mobs"))
	if marker is ResourceNodeMarker:
		return _build_resource(marker, _ensure_container(zone_root, "Obstacles"))
	return null


static func _ensure_container(parent: Node, name: String) -> Node2D:
	var existing := parent.get_node_or_null(name)
	if existing:
		return existing
	var container := Node2D.new()
	container.name = name
	parent.add_child(container)
	return container


## Every property is set BEFORE add_child() on purpose: add_child() on a node
## already inside the tree runs _ready() synchronously, and chase_mob.gd's
## _ready() bakes max_hp/body_color into health/_base_color right there. Set
## them after add_child() (as an earlier version of this did) and _ready()
## has already read the class defaults — the mob spawns, but silently with
## the wrong stats/tint. Same story for resource_node.gd's visual_type below
## (it decides tree/rock/vein art in _ready()), which is why every gatherable
## used to render as a tree regardless of what was actually placed.
static func _build_mob(marker: MobSpawnMarker, parent: Node) -> Node:
	var mob := MobScene.instantiate()
	mob.max_hp = marker.max_hp
	mob.move_speed = marker.speed
	mob.attack_damage = marker.damage
	mob.skill_gain = marker.skill_gain
	mob.gold_max = marker.gold_max
	if marker.ranged:
		mob.ranged = true
		mob.body_color = marker.body_color
		mob.projectile_damage = marker.projectile_damage
		mob.projectile_speed = marker.projectile_speed
		mob.attack_range = marker.attack_range
		mob.attack_cooldown = marker.attack_cooldown
	parent.add_child(mob)
	# Position is set after add_child(): unlike the stats above, _ready()
	# never reads it, and global_position is only reliable once a node is
	# actually inside the tree with a real parent transform to resolve against.
	mob.global_position = marker.global_position
	return mob


static func _build_resource(marker: ResourceNodeMarker, parent: Node) -> Node:
	var node := ResourceNodeScene.instantiate()
	node.visual_type = marker.visual_type_name()
	if marker.display_name != "":
		node.display_name = marker.display_name
	node.drop_id = marker.drop_id
	node.drop_min = marker.drop_min
	node.drop_max = marker.drop_max
	node.skill_gain = marker.skill_gain
	node.max_hp = marker.max_hp
	node.immortal = marker.immortal
	if marker.kind == ResourceNodeMarker.Kind.VEIN:
		# Matches the hand-tuned vein feel from the old world_zone.gd: bigger,
		# a shorter hit cooldown so auto-farm feels responsive.
		node.visual_radius = 24.0
		node.collision_radius = 20.0
		node.hit_cooldown = 0.7
	parent.add_child(node)
	node.global_position = marker.global_position
	return node

class_name CharacterVisualSet
extends Resource
## The animation standard a character archetype follows: canvas size plus the
## list of animations with their own frame counts and FPS.
##
## Every visual piece that draws onto this character (body, armor, helmet,
## weapon, shield, full-body override) must use this same canvas and the same
## frame indexing, which is what makes overlays line up without any per-piece
## offset data.

## Frame canvas. Not a hitbox — collision shapes are authored in the scene and
## are deliberately much smaller than this.
@export var frame_size: Vector2i = Vector2i(96, 96)

## Deprecated, unused: mirroring is per animation now
## (CharacterAnimation.mirror_west). Kept so older .tres files still load.
@export var mirror_east_for_west: bool = true

## animation id (StringName) -> CharacterAnimation.
## A Dictionary rather than a typed Array so the .tres stays readable and
## lookups are direct.
##
## Whether WEST is mirrored from EAST is decided per animation
## (CharacterAnimation.mirror_west), not here: handed animations such as an
## attack need their own west art while idle/walk/dash/death are happy mirrored.
@export var animations: Dictionary = {}

## Fallback used when something asks for an animation this set does not define.
@export var fallback_animation: StringName = &"idle"


func get_animation(id: StringName) -> CharacterAnimation:
	var anim = animations.get(id)
	if anim is CharacterAnimation:
		return anim
	return null


## The animation to actually play for `id`, falling back to `fallback_animation`
## when `id` is not defined. Returns null only if the set is empty/misconfigured.
func resolve_animation(id: StringName) -> CharacterAnimation:
	var anim := get_animation(id)
	if anim != null:
		return anim
	return get_animation(fallback_animation)


func animation_ids() -> Array:
	return animations.keys()


func frame_count_of(id: StringName) -> int:
	var anim := get_animation(id)
	return anim.frame_count if anim != null else 0

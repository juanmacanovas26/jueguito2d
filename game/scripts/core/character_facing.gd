class_name CharacterFacing
extends RefCounted
## The single source of truth for which way a character is facing.
##
## Deliberately NOT owned by the visual layer: gameplay resolves the Direction
## (it is simulation state — it decides where a dodge goes, where the hitbox
## points) and then hands the already-resolved value to the presentation layer.
## CharacterVisual never derives a direction from a Vector2 on its own, so the
## sprite can never disagree with the simulation.
##
## Four logical directions. The DEFAULT art convention is three sets:
##   SOUTH -> south art
##   NORTH -> north art
##   EAST  -> east art, flip_h = false
##   WEST  -> east art, flip_h = true      <- EAST is the master side
##
## Mirroring west is the default because it halves the art and keeps the
## character consistent. But it cannot express handedness: mirroring a
## right-handed sword swing produces a left-handed one. So mirroring is
## configurable PER ANIMATION (CharacterAnimation.mirror_west) and an animation
## can ship dedicated west art instead.
##
## The constants below are only the default convention. The authoritative
## per-animation answer is CharacterFrameCache.resolve_direction().
## See art_pipeline/GUIDE.md.

enum Direction { SOUTH, NORTH, EAST, WEST }

## Logical direction -> its own name. WEST has a name even though it has no art.
const DIR_NAMES := {
	Direction.SOUTH: "south",
	Direction.NORTH: "north",
	Direction.EAST: "east",
	Direction.WEST: "west",
}

## DEFAULT logical direction -> folder mapping. WEST maps to "east" because it
## is normally rendered mirrored. An animation with dedicated west art overrides
## this — ask CharacterFrameCache.resolve_direction() for the real answer.
const SOURCE_DIR_NAMES := {
	Direction.SOUTH: "south",
	Direction.NORTH: "north",
	Direction.EAST: "east",
	Direction.WEST: "east",
}

## The directions every animation must have art for. Animations that opt out of
## mirroring additionally need "west" — CharacterFrameCache.required_dirs()
## works that out per animation.
const SOURCE_DIRS := ["south", "north", "east"]

## How much one axis has to beat the other before the facing switches. Without
## it the facing flickers right on the diagonal, which used to restart the walk
## animation every frame and read as the character floating in place.
const AXIS_HYSTERESIS := 0.1

## Below this the input is treated as "no meaningful direction" and the previous
## facing is kept.
const MIN_LENGTH := 0.1


## Resolve a movement/aim vector into a logical direction, keeping `previous`
## when the vector is too small or too close to a diagonal to call.
static func from_vector(v: Vector2, previous: Direction) -> Direction:
	if v.length_squared() < MIN_LENGTH * MIN_LENGTH:
		return previous
	var ax := absf(v.x)
	var ay := absf(v.y)
	if ay > ax + AXIS_HYSTERESIS:
		return Direction.NORTH if v.y < 0.0 else Direction.SOUTH
	if ax > ay + AXIS_HYSTERESIS:
		return Direction.EAST if v.x > 0.0 else Direction.WEST
	return previous


static func dir_name(d: Direction) -> String:
	return DIR_NAMES.get(d, "south")


## Which folder on disk to read art from for this direction.
static func source_dir_name(d: Direction) -> String:
	return SOURCE_DIR_NAMES.get(d, "south")


## Whether this direction is rendered by mirroring its source art.
static func is_mirrored(d: Direction) -> bool:
	return d == Direction.WEST


static func to_vector(d: Direction) -> Vector2:
	match d:
		Direction.NORTH:
			return Vector2.UP
		Direction.EAST:
			return Vector2.RIGHT
		Direction.WEST:
			return Vector2.LEFT
		_:
			return Vector2.DOWN

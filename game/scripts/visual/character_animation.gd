class_name CharacterAnimation
extends Resource
## One animation of the character standard: how many frames it has, how fast it
## plays and what happens when it ends.
##
## Frame count and FPS are per animation on purpose — walk is 8 frames while
## attack and dash are 9, and PixelLab exports carry no timing information at
## all, so Godot is the authority on speed. Nothing in the visual system may
## assume a single global frame count.

## What to do once the last frame has been shown.
enum Finish {
	LOOP,             ## restart from frame 0 forever (idle, walk)
	HOLD_LAST,        ## freeze on the last frame (death)
	RETURN_TO_IDLE,   ## play once, then fall back to idle (attack, dash)
}

@export var id: StringName = &"idle"

## Number of frames on disk, i.e. 00.png .. (frame_count-1).png.
@export_range(1, 64, 1) var frame_count: int = 1

## Whether WEST is rendered by mirroring the EAST art (flip_h), or has its own
## dedicated west/ folder drawn unflipped.
##
## PER ANIMATION, not global. Mirroring is the default because it halves the art
## and keeps the character consistent, but it cannot express handedness: a sword
## swung with the right hand becomes a left-handed swing when mirrored. So a
## handed animation — an attack, a weapon-specific move — can opt out and use
## art drawn specifically for west.
##
## Regardless of this flag, a real west/ folder always wins if one exists
## (see CharacterFrameCache.resolve_direction).
@export var mirror_west: bool = true

## NOTE: a direction whose art genuinely has a different number of frames is a
## property of the ART, not of the standard, so it is declared on the
## VisualPiece (see VisualPiece.frame_count_by_direction). This resource always
## describes what the animation SHOULD be.

## Playback speed in frames per second. Purely a presentation value — gameplay
## timings live in player.gd and are never derived from this.
@export_range(0.5, 60.0, 0.5) var fps: float = 8.0

@export var finish: Finish = Finish.LOOP


## Nominal duration of one full pass at the configured FPS. `frames` overrides
## the standard count with what the art actually has, so a direction drawn with
## fewer frames still lasts exactly as long (the playback speed is scaled) and
## gameplay timing is unaffected.
func nominal_duration(frames: int = -1) -> float:
	if fps <= 0.0:
		return 0.0
	var n := frames if frames > 0 else frame_count
	return float(n) / fps


func loops() -> bool:
	return finish == Finish.LOOP

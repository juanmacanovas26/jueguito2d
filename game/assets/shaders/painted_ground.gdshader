shader_type canvas_item;
// Draws a hand-painted patch of ground: a seamless texture repeated across the
// zone, cut out by a coverage mask the build-mode brush paints into (see
// PaintLayer). Nothing here is tile-aware -- that is the whole point, it is the
// one ground layer that does NOT snap to the 32px grid.
//
// The mask is stored at half the world's resolution and sampled LINEAR, so it
// carries smooth coverage rather than hard texels. The crisp edge comes from
// thresholding that coverage per WORLD PIXEL, with a per-pixel jitter on the
// threshold -- which is what keeps the outline jagged and hand-drawn like the
// dirt/grass borders in the Plains art, instead of the smooth vector blob a
// plain alpha fade would give in a pixel-art scene.

uniform sampler2D ground : repeat_enable, filter_nearest;
// Zone size in world pixels; the mask sprite covers exactly this.
uniform vec2 world_size = vec2(2400.0, 1800.0);
uniform float ground_tile_px = 32.0;
// Coverage needed for a pixel to be painted. Higher = the brush bites less.
uniform float threshold : hint_range(0.0, 1.0) = 0.5;
// How far the threshold wanders per pixel. 0 gives a smooth outline, which
// looks wrong next to 32px pixel art; the default is tuned to read as a
// hand-drawn ragged border.
uniform float jitter : hint_range(0.0, 0.6) = 0.22;
// Size of a jitter block, in world pixels. At 1 the noise is per-pixel and
// reads as dithering; the Plains dirt/grass borders are chewed in chunks of
// two or three, so the edge only looks hand-drawn once the noise is too.
uniform float jitter_px : hint_range(1.0, 8.0) = 3.0;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float coverage = texture(TEXTURE, UV).a;
	vec2 world_px = floor(UV * world_size / jitter_px);
	float cut = threshold + (hash12(world_px) - 0.5) * jitter;
	if (coverage <= cut) {
		discard;
	}
	COLOR = texture(ground, UV * world_size / ground_tile_px);
}

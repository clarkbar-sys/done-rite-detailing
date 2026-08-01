// The mud on a panel, drawn as a layer over whatever that panel is painted.
//
// Hung on each panel as `material_overlay` rather than `material_override`, and
// that is the whole reason this can be twenty lines instead of a re-creation of
// every material on the car. An override replaces the panel's material, so a
// wheel — a near-black tyre and a silver rim in one CSG tree — would come back
// as one flat colour and the rim would be gone. An overlay is a second pass over
// the surface with the real material still under it, which is also exactly what
// grime is: the green car is not repainted brown, it has mud on it. So this
// shader only ever says "how much mud, and what colour is it", and washing it
// off is alpha going to zero over paint that was never touched.
//
// The mask is sampled through the same six-plane box projection `BoxProjection`
// paints into — the same face choice and the same atlas, or the water would land
// somewhere other than where it is drawn. That duplication is the price of the
// mask living on the CPU (see `GrimeMap` for why it does), and it is the one
// place in this feature where two files have to agree about arithmetic.
//
// The mud *pattern*, unlike the mask, is triplanar — three planar samples blended
// by the normal, which is what triplanar is good at and what it is safe for. A
// read may blend; a write may not. `BoxProjection`'s class docs have that split
// at length.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

// How much mud is left, in the red channel. Green and blue are the film and the
// water that the sponge and the cloth will work on, and are not read yet.
uniform sampler2D mud_mask : filter_linear, repeat_disable;

// The panel's own bounding box, which is the space the projection measures in.
uniform vec3 box_origin;
uniform vec3 box_size;

uniform vec4 mud_colour : source_color = vec4(0.26, 0.19, 0.12, 1.0);
uniform float mud_roughness : hint_range(0.0, 1.0) = 0.94;

// How coarse the mud pattern is, in cycles per metre.
uniform float pattern_scale : hint_range(0.5, 60.0) = 11.0;

// How far the pattern is allowed to push coverage either side of what the mask
// says. This is the whole difference between "a brown decal is fading out" and
// "mud is coming off in patches" — at zero the wash reads as a soft round
// eraser, and at this default the edge breaks up and the last of it clings in
// speckles.
uniform float pattern_bite : hint_range(0.0, 1.0) = 0.45;

// Lifts the overlay off the surface it is drawn over, in metres. The two passes
// are the same geometry at the same depth, which is a coin-flip per fragment on
// some drivers; a millimetre costs nothing anybody can see and settles it. Not a
// depth-test mode, because the one that would fix it (`LEQUAL`) is not something
// a spatial shader gets to choose in Godot.
uniform float lift : hint_range(0.0, 0.02) = 0.001;

varying vec3 panel_position;
varying vec3 panel_normal;

const float COLUMNS = 3.0;
const float ROWS = 2.0;
const float FLATNESS = 0.0001;

void vertex() {
	// Model space, which is what the projection below and the CPU that paints
	// into the mask both measure in. Taken here rather than in `fragment()`
	// because `VERTEX` is already model space in this stage and is not there.
	panel_position = VERTEX;
	panel_normal = NORMAL;
	VERTEX += NORMAL * lift;
}

// Which face of the box a normal points out of, in `BoxProjection.Face` order:
// +X -X +Y -Y +Z -Z. Kept as the index rather than as three branches returning
// coordinates, so the atlas placement below reads the same as the GDScript.
int face_for(vec3 normal) {
	vec3 size = abs(normal);
	if (size.x >= size.y && size.x >= size.z) {
		return normal.x >= 0.0 ? 0 : 1;
	}
	if (size.y >= size.z) {
		return normal.y >= 0.0 ? 2 : 3;
	}
	return normal.z >= 0.0 ? 4 : 5;
}

// Where a point on a face lands in the whole atlas, as 0..1.
vec2 atlas_uv(vec3 at, int face) {
	vec3 across = clamp((at - box_origin) / max(box_size, vec3(FLATNESS)), 0.0, 1.0);
	vec2 tile = vec2(across.z, across.y);
	if (face == 2 || face == 3) {
		tile = vec2(across.x, across.z);
	} else if (face == 4 || face == 5) {
		tile = vec2(across.x, across.y);
	}
	vec2 cell = vec2(float(face % 3), float(face / 3));
	return (cell + tile) / vec2(COLUMNS, ROWS);
}

float hashed(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise_on(vec2 at) {
	vec2 cell = floor(at);
	vec2 into = fract(at);
	into = into * into * (3.0 - 2.0 * into);
	float a = hashed(cell);
	float b = hashed(cell + vec2(1.0, 0.0));
	float c = hashed(cell + vec2(0.0, 1.0));
	float d = hashed(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, into.x), mix(c, d, into.x), into.y);
}

// The mud pattern: the same noise read on all three coordinate planes and
// blended by which way the surface faces, so nothing stretches on the panels
// that are not axis-aligned and no unwrap is needed to place it.
//
// The weights are raised to a power before normalising, which narrows the band
// where two planes are both contributing — a wide blend reads as a smear across
// every rounded corner of the car.
float triplanar_noise(vec3 at, vec3 normal) {
	vec3 weight = pow(abs(normal), vec3(4.0));
	weight /= max(weight.x + weight.y + weight.z, FLATNESS);
	return noise_on(at.yz) * weight.x + noise_on(at.zx) * weight.y + noise_on(at.xy) * weight.z;
}

void fragment() {
	vec3 facing = normalize(panel_normal);
	float mud = texture(mud_mask, atlas_uv(panel_position, face_for(facing))).r;
	// Two octaves: one that says where the mud is thick and one that gives its
	// edge a grain. More than two is not visible under a blockout's lighting.
	float coarse = triplanar_noise(panel_position * pattern_scale, facing);
	float fine = triplanar_noise(panel_position * pattern_scale * 3.7, facing);
	float pattern = mix(coarse, fine, 0.35);
	ALBEDO = mud_colour.rgb * mix(0.72, 1.24, pattern);
	// The bite is centred on 1.0 so a panel nobody has touched is still fully
	// covered — the pattern breaks the *edge* of the wash up, it does not make
	// a fresh car look half-cleaned.
	ALPHA = clamp(mud * (1.0 + pattern_bite * (pattern - 0.5) * 2.0), 0.0, 1.0);
	ROUGHNESS = mud_roughness;
	METALLIC = 0.0;
}

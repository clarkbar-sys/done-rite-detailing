// What is sitting on a panel, drawn as a layer over whatever that panel is
// painted: mud, then the product a cleaner leaves, then the shine a rag buffs in.
//
// Hung on each panel as `material_overlay` rather than `material_override`, and
// that is the whole reason this can be a hundred lines instead of a re-creation
// of every material on the car. An override replaces the panel's material, so a
// wheel — a near-black tyre and a silver rim in one CSG tree — would come back
// as one flat colour and the rim would be gone. An overlay is a second pass over
// the surface with the real material still under it, which is also exactly what
// grime is: the green car is not repainted brown, it has mud on it. So this
// shader only ever says "what is on the paint, and what does it look like", and
// washing it off is alpha going to zero over paint that was never touched.
//
// The mask is sampled through the same six-plane box projection `BoxProjection`
// paints into — the same face choice and the same atlas, or the water would land
// somewhere other than where it is drawn. That duplication is the price of the
// mask living on the CPU (see `GrimeMap` for why it does), and it is the one
// place in this feature where two files have to agree about arithmetic.
//
// The *patterns*, unlike the mask, are triplanar — three planar samples blended
// by the normal, which is what triplanar is good at and what it is safe for. A
// read may blend; a write may not. `BoxProjection`'s class docs have that split
// at length.
//
// THREE LAYERS, TWO OF WHICH SIT ON THE PAINT AND ONE OF WHICH IS THE PAINT.
// Mud and product are things lying on the surface, which is what an alpha-blended
// overlay is good at: cover the paint, be lit as themselves. Shine is not — it is
// a property of the surface underneath, and there is no way for a second pass to
// reach back and lower the roughness of the first. So it is drawn as what a
// detailer would actually have applied: a coat. A nearly-black, nearly-smooth
// film at low alpha deepens the colour under it and takes a hard specular
// highlight, which is what wax on paint looks like, and it is the only version of
// this that needs no access to the panel's own material — which matters because
// six body panels share one (`Car.paint`), so per-panel gloss cannot live there.
//
// Mud and product never overlap, because `GrimeMap` moves units between buckets
// rather than stacking them, so they are blended by their relative amounts rather
// than composited one over the other. Nothing here needs to know which is on top
// because nothing is ever both.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

// What is on the panel: mud in red, product in green, shine in blue. Bare paint
// is what none of them is — see `GrimeMap` for why that fourth bucket is not
// stored.
uniform sampler2D grime_mask : filter_linear, repeat_disable;

// The panel's own bounding box, which is the space the projection measures in.
uniform vec3 box_origin;
uniform vec3 box_size;

uniform vec4 mud_colour : source_color = vec4(0.26, 0.19, 0.12, 1.0);
uniform float mud_roughness : hint_range(0.0, 1.0) = 0.94;

// What the cleaner for this panel looks like. Set per panel by `Grime.lay_on`
// from `Surface.product_colour`, which is how one channel carries three products:
// white suds on the paint, blue on the glass, green on the tyres. A panel's kind
// never changes, so the colour is a uniform and the mask only has to say how
// much.
uniform vec4 product_colour : source_color = vec4(0.94, 0.95, 0.97, 1.0);

// Wetter than mud but a long way from polished — foam is bright and diffuse, and
// the point of it is that a panel under product is visibly *not* finished yet.
uniform float product_roughness : hint_range(0.0, 1.0) = 0.66;

// How coarse each pattern is, in cycles per metre. The product's is much finer
// than the mud's on purpose: mud reads as patches and lather reads as bubbles,
// and the frequency is most of what makes that difference.
uniform float pattern_scale : hint_range(0.5, 60.0) = 11.0;
uniform float product_scale : hint_range(0.5, 90.0) = 27.0;

// How far a pattern is allowed to push coverage either side of what the mask
// says. This is the whole difference between "a brown decal is fading out" and
// "mud is coming off in patches" — at zero the wash reads as a soft round
// eraser, and at this default the edge breaks up and the last of it clings in
// speckles.
uniform float pattern_bite : hint_range(0.0, 1.0) = 0.45;
uniform float product_bite : hint_range(0.0, 1.0) = 0.38;

// The coat. Near-black rather than black for the reason the tyre proxy is
// (`DetailingTool.catalogue`): a true zero takes no light at all and reads as a
// hole rather than as a surface.
uniform vec4 gloss_colour : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform float gloss_roughness : hint_range(0.0, 1.0) = 0.06;

// How opaque a fully buffed coat is looking straight at it. Deliberately low:
// this darkens the paint it lies over, so a heavy coat turns Alpine White into
// grey and calls it a shine. A fifth deepens the colour the way wax does and
// leaves the paint its own.
uniform float gloss_strength : hint_range(0.0, 1.0) = 0.13;

// THE SHEEN IS WHAT ACTUALLY SELLS THE POLISH, and it is here because the first
// version without it did not.
//
// A dark, smooth coat is physically the right description of wax and it reads as
// almost nothing in this game, for a reason that is about the renderer rather
// than about the shader: gloss is mostly *reflections*, the web build runs in
// Compatibility (STANDARDS.md has why), and there is no reflection probe and no
// environment for a mirror-smooth surface to mirror. So all a low roughness buys
// is a small specular lobe from two omnis and a fill. Measured rather than
// judged by eye: buffing the whole car moved 20% of its pixels by more than
// 12/255 — a real change, and one that reads as "the paint went slightly darker"
// instead of as a reward.
//
// What does not need anything to reflect is Fresnel. Every glossy surface goes
// bright and mirror-like at a grazing angle regardless of what is around it, so
// the coat is faded from `gloss_colour` looking straight at it toward
// `sheen_colour` at the edges. That is the bright rim along the top of a wing
// that says "waxed" in a photograph, and it costs one dot product.
uniform vec4 sheen_colour : source_color = vec4(0.92, 0.95, 1.0, 1.0);

// How much of the way to a full sheen the grazing edge of a buffed panel goes.
uniform float gloss_sheen : hint_range(0.0, 1.0) = 0.9;

// How tightly the sheen hugs the silhouette. Higher is a thinner, harder rim;
// lower spreads it across the panel and starts to read as fog rather than as
// polish.
uniform float sheen_sharpness : hint_range(1.0, 8.0) = 4.0;

// How reflective the coat is against the mud and foam it replaces. Godot's
// default `SPECULAR` is 0.5; the coat sits well above it and the layers that are
// meant to look like dirt sit at it.
uniform float gloss_specular : hint_range(0.0, 1.0) = 0.9;

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

// A pattern: the same noise read on all three coordinate planes and blended by
// which way the surface faces, so nothing stretches on the panels that are not
// axis-aligned and no unwrap is needed to place it.
//
// The weights are raised to a power before normalising, which narrows the band
// where two planes are both contributing — a wide blend reads as a smear across
// every rounded corner of the car.
float triplanar_noise(vec3 at, vec3 normal) {
	vec3 weight = pow(abs(normal), vec3(4.0));
	weight /= max(weight.x + weight.y + weight.z, FLATNESS);
	return noise_on(at.yz) * weight.x + noise_on(at.zx) * weight.y + noise_on(at.xy) * weight.z;
}

// How much of the paint a layer actually hides, given how much of it the mask
// says is there and a pattern to break its edge up with.
//
// The bite is centred on 1.0 so a layer the mask calls full is still fully
// opaque — the pattern breaks the *edge* of a wash up, it does not make a fresh
// car look half-cleaned or a soaped panel look patchy.
float coverage(float amount, float pattern, float bite) {
	return clamp(amount * (1.0 + bite * (pattern - 0.5) * 2.0), 0.0, 1.0);
}

void fragment() {
	vec3 facing = normalize(panel_normal);
	vec3 layers = texture(grime_mask, atlas_uv(panel_position, face_for(facing))).rgb;

	// Two octaves for the mud: one that says where it is thick and one that gives
	// its edge a grain. More than two is not visible under a blockout's lighting.
	float coarse = triplanar_noise(panel_position * pattern_scale, facing);
	float fine = triplanar_noise(panel_position * pattern_scale * 3.7, facing);
	float mud_pattern = mix(coarse, fine, 0.35);
	float suds = triplanar_noise(panel_position * product_scale, facing);

	float mud = coverage(layers.r, mud_pattern, pattern_bite);
	float product = coverage(layers.g, suds, product_bite);
	// Never both on one texel, so this is a weighting rather than a composite —
	// see the file header.
	float dirt = mud + product;
	vec3 dirt_colour = (
		mud_colour.rgb * mix(0.72, 1.24, mud_pattern) * mud
		+ product_colour.rgb * mix(0.80, 1.22, suds) * product
	) / max(dirt, FLATNESS);
	float dirt_roughness = (mud_roughness * mud + product_roughness * product) / max(dirt, FLATNESS);
	dirt = min(dirt, 1.0);

	// The coat only shows through where nothing is lying on top of it, which is
	// also the only place it exists: shine is buffed out of product, and a texel
	// still carrying mud or foam has none.
	float coat = layers.b * (1.0 - dirt);
	// Fresnel, and the whole reason the buff is visible — see `sheen_colour`.
	// `NORMAL` and `VIEW` are both view-space here, so this is 0 looking straight
	// at the surface and 1 along its silhouette.
	float sheen = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), sheen_sharpness);
	float lit = gloss_sheen * sheen;
	float gloss = coat * mix(gloss_strength, 1.0, lit);
	float total = clamp(dirt + gloss, 0.0, 1.0);
	// How much of what this pass draws is dirt rather than coat. Divided by the
	// total rather than used raw because the two are being mixed *within* one
	// alpha — at half coverage and half gloss the fragment is half of each, not
	// half dirt over a full coat.
	float share = dirt / max(total, FLATNESS);

	ALBEDO = mix(mix(gloss_colour.rgb, sheen_colour.rgb, sheen), dirt_colour, share);
	ROUGHNESS = mix(gloss_roughness, dirt_roughness, share);
	SPECULAR = mix(gloss_specular, 0.5, share);
	// Carried as light of its own rather than as albedo alone: the rim has to be
	// there on the shaded side of the car too, and a panel facing away from both
	// omnis would otherwise buff to a dark edge instead of a bright one.
	EMISSION = sheen_colour.rgb * sheen * coat * gloss_sheen;
	ALPHA = total;
	METALLIC = 0.0;
}

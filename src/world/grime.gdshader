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
//
// AND IT IS DRAWN AS AN ARCADE GAME RATHER THAN AS A PHOTOGRAPH, which is four
// changes to the above and none to what any of it means. Coverage is cut into
// bands instead of fading smoothly, each band's leading edge carries a lit line,
// a patch that finishes throws a coloured square, and a buffed surface catches a
// travelling highlight. Every one of them is a way of saying the same thing
// louder: *this bit is further along than that bit*. None of them touches the
// mask, and none of them can disagree with it — the bands reach zero exactly
// where the mask does, and the squares are thrown by the same signal that rings
// the bell.
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
// this darkens the paint it lies over, so a heavy coat turns Viper White into
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

// HOW MANY BANDS THE COVERAGE IS CUT INTO, and the single biggest reason this
// reads as an arcade game.
//
// A smooth alpha ramp is the physically honest description of mud thinning out
// and it is very nearly unreadable in motion: a player cannot tell a panel that
// is a third clean from one that is half clean without stopping to look at it.
// Quantised, the jet carves visible terraces and how far along a panel is can be
// read across the room at a glance. Five is enough to show progress and few
// enough that each step is an event; past about eight it goes back to being a
// gradient.
uniform int coverage_steps : hint_range(2, 16) = 5;

// Each terrace a shade lighter than the one under it, so the bands read as depth
// rather than as posterisation. Thick mud sits dark and the last band before bare
// paint is a dusting. The pattern still does the mottling; this is strata on top
// of it.
uniform float band_relief : hint_range(0.0, 0.6) = 0.2;

// The lit line along the leading edge of each band — the edge the jet is cutting
// along, and the thing that makes washing feel like taking territory rather than
// like rubbing out.
uniform vec4 terrace_colour : source_color = vec4(0.62, 0.92, 1.0, 1.0);

// How bright that line burns.
uniform float terrace_glow : hint_range(0.0, 4.0) = 1.1;

// How wide it is, as a fraction of one band. Wider spreads it until the bands
// stop having edges at all and the whole layer just glows.
uniform float terrace_width : hint_range(0.01, 0.5) = 0.22;

// How much opacity the lit line adds where it fires. It is drawn as *more of the
// layer it is an edge of* rather than as something floating above it, so the
// fragment stays the colour of the thing it outlines — see `fragment()`.
uniform float terrace_lip : hint_range(0.0, 1.0) = 0.45;

// WHICH PATCHES HAVE JUST FINISHED SOMETHING, one pixel each: red is how lit, and
// green is which of the three passes lit it. `PatchFlash` owns it and its class
// docs carry the format.
//
// `hint_default_black` is load-bearing rather than tidy. An unassigned sampler in
// Godot reads white, and white here is every patch of every panel flashing
// permanently at full brightness — so a `Grime` that had not set this, or a
// material built by anything that does not know to, would not degrade quietly.
uniform sampler2D patch_flash : hint_default_black, filter_nearest, repeat_disable;

// What a patch throws when the water finishes it. The rag's is below; the
// cleaner's is the panel's own `product_colour`, which is already here — see
// `flash_tint`.
uniform vec4 wash_flash_colour : source_color = vec4(0.55, 0.90, 1.0, 1.0);

// What a patch throws when the rag finishes it: the end of the job for that
// square, and the only one of the three that is warm.
uniform vec4 buff_flash_colour : source_color = vec4(1.0, 0.86, 0.42, 1.0);

// How hard a flash burns at full brightness.
uniform float flash_glow : hint_range(0.0, 6.0) = 2.6;

// THE TRAVELLING HIGHLIGHT, and the payoff for finishing a panel.
//
// `gloss_strength` above is deliberately low so that wax deepens the paint
// instead of greying it, and the measured result of that honesty was a reward
// that reads as "the paint went slightly darker". The fix is not to raise the
// coat — that argument was had and settled a few lines up. It is to add the one
// thing a polished surface does that a dirty one cannot: catch a moving
// highlight. It costs a `fract` and it only exists where there is shine to catch
// it, so an unfinished panel is exactly as dull as it was.
//
// Measured in world space rather than panel space, which matters: the panels are
// twelve separate CSG trees with their own transforms, so a wave in each one's
// local space would break at every seam instead of crossing the car as one
// sweep.
uniform float sweep_scale : hint_range(0.05, 4.0) = 0.55;

// How fast the highlight travels, in cycles a second.
uniform float sweep_speed : hint_range(0.0, 3.0) = 0.45;

// How much of one cycle the bright band occupies.
uniform float sweep_width : hint_range(0.02, 1.0) = 0.18;

// How fully the sweep lights the coat as it passes. It feeds the same `lit` term
// the Fresnel sheen does, so a sweep and a grazing angle are two reasons for the
// same thing to happen rather than two effects stacking.
uniform float sweep_strength : hint_range(0.0, 1.0) = 0.85;

// Lifts the overlay off the surface it is drawn over, in metres. The two passes
// are the same geometry at the same depth, which is a coin-flip per fragment on
// some drivers; a millimetre costs nothing anybody can see and settles it. Not a
// depth-test mode, because the one that would fix it (`LEQUAL`) is not something
// a spatial shader gets to choose in Godot.
uniform float lift : hint_range(0.0, 0.02) = 0.001;

varying vec3 panel_position;
varying vec3 panel_normal;

// Where this fragment is in the room, which only the sweep wants — see
// `sweep_scale` for why it cannot use `panel_position` like everything else does.
varying vec3 world_position;

const float COLUMNS = 3.0;
const float ROWS = 2.0;
const float FLATNESS = 0.0001;

void vertex() {
	// Model space, which is what the projection below and the CPU that paints
	// into the mask both measure in. Taken here rather than in `fragment()`
	// because `VERTEX` is already model space in this stage and is not there.
	panel_position = VERTEX;
	panel_normal = NORMAL;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
//
// This is what gets *drawn*, and nothing else reads it. In particular `terrace`
// does not: a value with noise in it has band boundaries wherever the noise has
// them, and that is a very different thing from where the wash is — see there.
float coverage(float amount, float pattern, float bite) {
	return clamp(amount * (1.0 + bite * (pattern - 0.5) * 2.0), 0.0, 1.0);
}

// Coverage cut into `coverage_steps` visible bands — see that uniform for why.
//
// `ceil` and not `floor`, and that is not a rounding preference. Flooring snaps
// the last sliver of a layer to nothing, so the paint would look finished while
// the mask still held mud and the ding had not rung — the picture would be lying
// about the one thing the player is waiting for. Ceiling holds any remaining mud
// at one band of coverage and reaches zero exactly when the mask does, which is
// the same instant the bell is struck.
float banded(float amount, float steps) {
	return ceil(amount * steps) / steps;
}

// The lit line along the leading edge of a band.
//
// A band boundary is where `banded`'s ceiling jumped, so the fragments just
// inside one sit near zero in the fractional position that ceiling rounded away
// — that is the whole test, and it costs a `fract`.
//
// [b]Measured on the mask, not on what is drawn, and that is the whole of
// whether this reads as a wash or as a circuit board.[/b] The obvious thing is
// to band the same value the layer is drawn from, so the line lands exactly on
// the visible step. That value is `coverage`'s, and `coverage` has
// `pattern_bite` of triplanar noise in it — so `fract` of it is testing the
// fractional part of a *noise field*, and lighting up where that is near zero
// draws the field's iso-contours. Level sets of smooth 2D noise are closed
// squiggling loops, which is exactly what it looked like: nested cyan
// tracery over every panel the jet had half finished. Worse, the ±45% swing
// spans up to four band boundaries at once, so several contour families stacked
// in the same place — better than half the fragments at a mask of 0.95 lit,
// which is a fill and not a rim.
//
// The mask has none of that. It is flat 1.0 on fresh paint, flat 0.0 on
// finished paint, and in between it is the brush's own falloff — smooth and
// roughly radial — so banding it puts one clean contour per step around the
// spot the water is working, which is the terrace this was always meant to be.
// The line no longer sits exactly on the drawn step, because the drawn one still
// carries the bite; that disagreement is less than one band and invisible.
//
// Both ends are excluded rather than clamped, and neither is optional: at full
// coverage the line would run bumper to bumper, and at none it would outline
// clean paint. Excluding them also means this can never fire where the layer is
// absent, which is what lets the caller add it straight onto that layer's own
// opacity. Note that they are a gate and were never a fix for the above — a mask
// of 0.999 is untouched to look at and speckled just as hard.
float terrace(float amount, float steps, float width) {
	float inside = 1.0 - smoothstep(0.0, width, fract(amount * steps));
	return inside * step(0.001, amount) * step(amount, 0.999);
}

// A band of light crossing the room, as `0..1`. Used for the sweep across buffed
// paint — see `sweep_scale`.
//
// The three axes are summed rather than one being picked, so the wave is a plane
// travelling diagonally and every panel catches it whichever way it faces. A
// single axis would leave the roof or the flanks permanently unlit depending on
// which one was chosen.
float travelling(vec3 at, float scale, float speed, float width) {
	float along = fract((at.x + at.y + at.z) * scale - TIME * speed);
	float across = min(abs(along - 0.5) / max(width * 0.5, FLATNESS), 1.0);
	float band = 1.0 - across;
	return band * band;
}

// Which colour a patch throws, from the stage `PatchFlash` stored in green: 0 for
// the wash, 0.5 for the cleaner, 1 for the rag.
//
// Three colours rather than one because the three passes are the thing the player
// has to keep in order, and a pop that says *which* step just landed teaches that
// order faster than a bell that does not. The middle one is the panel's own
// `product_colour`, which is already a uniform here and is already white on
// paint, blue on glass and green on tyres.
vec3 flash_tint(float stage) {
	if (stage < 0.25) {
		return wash_flash_colour.rgb;
	}
	if (stage < 0.75) {
		return product_colour.rgb;
	}
	return buff_flash_colour.rgb;
}

void fragment() {
	vec3 facing = normalize(panel_normal);
	// One set of atlas coordinates for both maps. The flash is a twelve-by-eight
	// image of the same atlas, sampled nearest, so this lands in the pixel that
	// stands for the patch this fragment belongs to — see `PatchFlash`.
	vec2 mask_uv = atlas_uv(panel_position, face_for(facing));
	vec3 layers = texture(grime_mask, mask_uv).rgb;
	vec2 flash_cell = texture(patch_flash, mask_uv).rg;

	// Two octaves for the mud: one that says where it is thick and one that gives
	// its edge a grain. More than two is not visible under a blockout's lighting.
	float coarse = triplanar_noise(panel_position * pattern_scale, facing);
	float fine = triplanar_noise(panel_position * pattern_scale * 3.7, facing);
	float mud_pattern = mix(coarse, fine, 0.35);
	float suds = triplanar_noise(panel_position * product_scale, facing);

	float steps = float(coverage_steps);
	float mud_raw = coverage(layers.r, mud_pattern, pattern_bite);
	float product_raw = coverage(layers.g, suds, product_bite);
	float mud = banded(mud_raw, steps);
	float product = banded(product_raw, steps);
	// Never both on one texel, so this is a weighting rather than a composite —
	// see the file header.
	float dirt = mud + product;
	// The strata: thin bands lift and thick ones sit down, on top of whatever the
	// noise pattern is already doing to the same colour.
	float mud_relief = 1.0 + band_relief * (1.0 - 2.0 * mud);
	float product_relief = 1.0 + band_relief * (1.0 - 2.0 * product);
	vec3 dirt_colour = (
		mud_colour.rgb * mix(0.72, 1.24, mud_pattern) * mud_relief * mud
		+ product_colour.rgb * mix(0.80, 1.22, suds) * product_relief * product
	) / max(dirt, FLATNESS);
	float dirt_roughness = (mud_roughness * mud + product_roughness * product) / max(dirt, FLATNESS);
	// The lit edge, taken as the brighter of the two layers' rather than their sum:
	// a texel is only ever one of them, so they cannot both be mid-band, and adding
	// would only ever be a way of double-counting the one that is.
	float rim = max(
		terrace(layers.r, steps, terrace_width),
		terrace(layers.g, steps, terrace_width)
	);
	// Folded into the layer's own opacity rather than laid over it. A contour line
	// on mud is *more mud, brighter* — not a separate thing floating above it — so
	// the fragment keeps the colour and the roughness of what it is an edge of, and
	// only the emission below says it is lit. `terrace` cannot fire where the layer
	// is absent, so this can never thicken bare paint.
	dirt = min(dirt + rim * terrace_lip, 1.0);

	// The coat only shows through where nothing is lying on top of it, which is
	// also the only place it exists: shine is buffed out of product, and a texel
	// still carrying mud or foam has none.
	float coat = layers.b * (1.0 - dirt);
	// Fresnel, and the whole reason the buff is visible — see `sheen_colour`.
	// `NORMAL` and `VIEW` are both view-space here, so this is 0 looking straight
	// at the surface and 1 along its silhouette.
	float sheen = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), sheen_sharpness);
	// Two reasons for a coat to be lit, taken as the stronger rather than summed:
	// a grazing angle and a passing sweep are both "this surface is catching the
	// light right now", and a panel that happened to be both would otherwise blow
	// past white. Everything downstream reads `lit` rather than `sheen`, so the
	// sweep gets the albedo, the alpha and the emission for free.
	float sweep = travelling(world_position, sweep_scale, sweep_speed, sweep_width);
	float lit = clamp(max(gloss_sheen * sheen, sweep * sweep_strength), 0.0, 1.0);
	float gloss = coat * mix(gloss_strength, 1.0, lit);
	// A finished patch's pop. It has to carry its own opacity or it would be
	// invisible exactly when it fires: the patch that just came clean has no mud
	// left and no shine yet, so without this the fragment is fully transparent and
	// there is nothing for the emission below to show up on.
	float flash = flash_cell.r;
	vec3 tint = flash_tint(flash_cell.g);
	float total = clamp(dirt + gloss + flash, 0.0, 1.0);
	// How much of what this pass draws is dirt rather than coat. Divided by the
	// total rather than used raw because the two are being mixed *within* one
	// alpha — at half coverage and half gloss the fragment is half of each, not
	// half dirt over a full coat.
	float share = dirt / max(total, FLATNESS);

	vec3 surface = mix(mix(gloss_colour.rgb, sheen_colour.rgb, lit), dirt_colour, share);
	ALBEDO = mix(surface, tint, flash);
	ROUGHNESS = mix(gloss_roughness, dirt_roughness, share);
	SPECULAR = mix(gloss_specular, 0.5, share);
	// Carried as light of its own rather than as albedo alone: the rim has to be
	// there on the shaded side of the car too, and a panel facing away from both
	// omnis would otherwise buff to a dark edge instead of a bright one. The
	// terrace line and the patch flash are here for the same reason and one more —
	// neither is a surface catching light, they are the game telling the player
	// something, and the shaded flank is where that matters most.
	EMISSION = sheen_colour.rgb * lit * coat
		+ terrace_colour.rgb * rim * terrace_glow
		+ tint * flash * flash_glow;
	ALPHA = total;
	METALLIC = 0.0;
}

// The sky over the driveway, painted rather than simulated.
//
// The room had a flat `background_color` before this — one sky blue, edge to
// edge — which is exactly right for a blockout and stops being right the moment
// the camera lifts its eye above the roofline, because a driveway with nothing
// over it reads as a photo studio rather than as outside. What replaces it is
// deliberately the *Bryce* answer and not the physically-based one: a hard
// vertical ramp, a bright band of haze sitting on the horizon, cumulus on a
// flat deck converging into that band, and a sun that is a disc with a halo
// around it. Those four things in that order are what makes a 1994 render
// recognisable from across a room, and all four are cheap.
//
// It is a `sky` shader and not a `ProceduralSkyMaterial` for one reason:
// clouds. The built-in material does the ramp and the sun disc perfectly well —
// it would have been zero lines of GLSL — and has nowhere to put a cloud. It is
// also not a baked panorama, because a panorama is a multi-megabyte binary in a
// repo that is otherwise entirely text, and because every number below would
// stop being a number anybody can change.
//
// WHAT LIGHTS THE ROOM DID NOT CHANGE. `garage.tscn` keeps
// `ambient_light_source = 2` (a tuned colour) and turns the sky's reflections
// off, so this is a backdrop and not a light. That is a decision with a cost
// and the scene file states it at the point where it is made; the short version
// is that the two strip lights and the key were tuned against a flat grey
// ambient, and relighting the whole car was not what "add a sky" was asked to
// do.
//
// NO HALF- OR QUARTER-RES PASS, MEASURED. Godot's sky shaders can render the
// expensive part into a smaller buffer (`render_mode use_quarter_res_pass`) and
// sample it back — which is exactly what the noise below would want. It is not
// used, and the reason is the renderer split in STANDARDS.md "Renderer": the
// web build runs
// `gl_compatibility`, and that renderer does not implement the low-res passes.
//
// Measured, because this is the failure mode that section exists to catch. A
// copy of this shader declaring `use_quarter_res_pass`, writing pure green in
// the quarter-res pass and reading `QUARTER_RES_COLOR` in the full-res one,
// rendered SOLID BLACK under `--rendering-driver opengl3` — no shader error, no
// warning, nothing in the log at all. It compiles and it runs and the buffer it
// reads back is empty, so the clouds would simply not exist in a browser and
// would look perfect on the machine of whoever added them. Forward+ was not
// re-measured here (this container has no Vulkan ICD, so `gl_compatibility` is
// the only renderer it can start), and it does not need to be: one renderer
// silently dropping the pass is already disqualifying.
//
// So it is one full-res pass, which renders the same in both, and the octave
// counts below are picked to afford that.
shader_type sky;

// ---- the ramp ---------------------------------------------------------------

uniform vec3 zenith_colour : source_color = vec3(0.10, 0.32, 0.70);
uniform vec3 horizon_colour : source_color = vec3(0.66, 0.83, 0.93);

// How fast the ramp leaves the horizon. Below 1 the blue starts low and the sky
// reads overcast-bright; above 1 it hangs on to the deep colour almost to the
// skyline, which is the poster look. The horizon band under it is what stops
// that from looking like a gradient with a hard edge.
uniform float zenith_curve : hint_range(0.2, 6.0) = 1.35;

// Below the skyline. The modeled ground runs out about 8 m either side of the
// car, so this is what fills the gap between the last of the grass and the
// horizon — a haze-desaturated green rather than a colour of its own, because
// anything else draws a line exactly where the eye is looking for one.
uniform vec3 ground_colour : source_color = vec3(0.47, 0.53, 0.45);

// The band. Bryce's signature is that the horizon is the *brightest* part of
// the sky, not the palest end of a gradient, and the whole trick is that the
// band is narrow and much brighter than either side of it.
uniform vec3 haze_colour : source_color = vec3(0.93, 0.95, 0.90);
uniform float haze_thickness : hint_range(0.0, 1.0) = 0.58;
uniform float haze_falloff : hint_range(1.0, 64.0) = 20.0;

// ---- the sun ----------------------------------------------------------------

// THE SUN IS THE SKY'S OWN, NOT THE ROOM'S, AND THAT IS MEASURED. A sky shader
// is handed the scene's first [DirectionalLight3D] as `LIGHT0_DIRECTION`,
// pointing at the source, and drawing the disc there is exactly what the
// engine's own `ProceduralSkyMaterial` does. It is wrong here. The driveway's
// only directional is `Key`, and it is a fill raking *upward*: its basis Z —
// printed out of the instantiated scene rather than read off the transform by
// eye — is (-0.574, -0.671, 0.470), so the star it stands for is 42° BELOW the
// horizon. Aim the disc at it and the sky has no sun in it at all. Negate it
// and the sun sits where that light is shining *to*, which is worse, because
// every panel facing the new sun is the one the room lights from behind.
//
// The room's own class docs already say that light is a shadowless fill, so
// this stops asking it to be a star and paints one instead — which is what a
// Bryce sky always was. Nothing in the driveway casts a shadow, so there is no
// second opinion on screen for the painted sun to contradict.
//
// It buys one more thing worth having: the sky now reads no light state at
// all, so there is one less thing that can differ between Forward+ and the web
// build's `gl_compatibility`. If `Key` is ever posed as a real sun with shadows
// turned on, put its direction in here and the two agree again.
//
// The value itself is set in `garage.tscn` and not left at the default below,
// which is the one place this file's "the look lives in the shader" rule is
// broken on purpose: where the sun stands is a fact about that driveway rather
// than about weather, and it is also the only number here a test can read
// without a rendering device. This default is what an unattached copy of the
// shader should look like, nothing more.
uniform vec3 sun_direction = vec3(0.45, 0.56, 0.70);
uniform vec3 sun_colour : source_color = vec3(1.0, 0.97, 0.88);

// How much brighter than white the disc is drawn. Over 1 on purpose: the band
// of haze it has to be seen against is already at 0.93, and a sun the same
// value as the sky behind it is a sticker.
uniform float sun_brightness : hint_range(0.5, 4.0) = 1.7;

// Half-angle of the disc, in radians. The real sun is 0.0047 and looks like a
// pinprick; this is about eight times that, which is the size a painted sun is
// always drawn at and the size the halo needs to sit around convincingly.
uniform float sun_size : hint_range(0.0, 0.3) = 0.038;

// How far the edge of the disc takes to go out. A hard edge crawls and aliases
// as the camera turns; a soft one reads as glare.
uniform float sun_edge : hint_range(0.0, 0.2) = 0.014;

uniform float halo_strength : hint_range(0.0, 4.0) = 0.8;
uniform float halo_tightness : hint_range(1.0, 900.0) = 500.0;

// What the sun does to the cloud it is behind: the bright rim. Kept separate
// from the halo because this one is applied *after* the cloud is composited, so
// it lights the cloud's face rather than being hidden by it.
uniform float silver_lining : hint_range(0.0, 2.0) = 0.5;

// ---- the cumulus ------------------------------------------------------------

uniform vec3 cloud_lit_colour : source_color = vec3(1.0, 0.99, 0.96);
uniform vec3 cloud_shade_colour : source_color = vec3(0.46, 0.52, 0.62);

// How much of the deck is cloud. This is a threshold on the noise and not a
// fraction, so it runs backwards: raise it for a clearer sky.
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.53;

// How long the edge of a cloud takes to fade out. Small is Bryce cumulus with a
// defined outline; large is a smear of fog with no shape to it at all.
uniform float cloud_edge : hint_range(0.005, 0.6) = 0.06;

// How many noise cells fit across the deck at head height. Bigger is smaller,
// more numerous puffs.
uniform float cloud_scale : hint_range(0.1, 12.0) = 2.6;

// How hard the sun-facing side of a puff is lit against its underside. This is
// the single knob that decides between "flat white blobs" and "something with a
// volume to it", and it is worth more than another octave of noise.
uniform float cloud_relief : hint_range(0.0, 6.0) = 4.5;

// How far up-sun the shading compares against, in deck units. Roughly the
// thickness the cloud is pretending to have.
uniform float cloud_depth : hint_range(0.0, 1.0) = 0.30;

// How far the cloud field is dragged through itself before it is read. This is
// the difference between weather and wallpaper: value noise thresholded
// straight gives torn horizontal rags, and warping its input by a second, much
// coarser field of the same noise curls those rags into something with
// shoulders and hollows — the billow a cumulus has. Two extra octaves, and it
// is the best-value pair in the file.
uniform float cloud_billow : hint_range(0.0, 3.0) = 0.8;

// Deck units per second. Nearly still on purpose — a backdrop that visibly
// slides while the player stands at a wheel arch reads as the world moving
// rather than as weather. Set it to 0 for a painted, dead-still sky.
uniform float cloud_drift : hint_range(0.0, 0.5) = 0.006;

// ---- the cirrus -------------------------------------------------------------

// The second, higher deck: streaks rather than puffs, and the reason for it is
// depth. One cloud layer, however good, sits at one apparent distance; two at
// different scales and different drifts is what makes a flat backdrop read as
// having a sky's worth of space in it.
uniform vec3 cirrus_colour : source_color = vec3(1.0, 0.98, 0.97);
uniform float cirrus_amount : hint_range(0.0, 1.0) = 0.34;
uniform float cirrus_coverage : hint_range(0.0, 1.0) = 0.54;
uniform float cirrus_scale : hint_range(0.1, 12.0) = 0.75;

// How far the cirrus noise is stretched along X before it is read. This is the
// whole difference between "small clouds" and "a mare's tail" — the streaks
// have to be drawn out ten to one before they stop looking like weather at the
// wrong altitude.
uniform float cirrus_stretch : hint_range(1.0, 24.0) = 9.0;

// How much of a dome the flat deck is allowed to be. A true plane divides by
// the height of the ray, which goes to zero at the skyline and stretches the
// puffs near it into infinitely long streaks; adding a constant to that divisor
// bends the deck over into a very shallow dome and caps the stretch. Zero is
// the honest plane and looks it — the clouds smear into streaks a third of the
// way up the sky. The number is picked by eye against the two shots the game
// actually uses.
uniform float deck_curve : hint_range(0.01, 1.0) = 0.14;

// Where the decks stop, as a sine of the angle above the skyline. A view ray
// approaching level crosses the deck at an ever greater distance, so the noise
// under it compresses without limit and turns into a shimmering band exactly
// where the haze is brightest. Both decks are faded out across this instead,
// which is also what a real cloudscape does and is the cheaper half of why the
// horizon reads as far away.
const float DECK_FADE_FROM = 0.03;
const float DECK_FADE_TO = 0.16;

// Nothing is divided by less than this.
const float FLATNESS = 0.0001;

// Same value noise as `grime.gdshader`, and deliberately a second copy rather
// than a shared `.gdshaderinc`: these two are the same three lines by
// coincidence — everybody's value noise is — and sharing them would tie the
// shape of the mud to the shape of the weather, so that tuning either one has
// to be argued about in terms of the other.
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

// Octaves of it, each half the amplitude and a bit over twice the frequency.
//
// The 2.03 and the offset are both load-bearing. Doubling exactly lines every
// octave's grid up on the one under it and the result has visible square
// corners in it; the odd ratio and a shove between octaves break that up for
// nothing. The octave count is a caller's argument rather than a constant
// because the three fields below want three different answers, and each one is
// the smallest number that still looked right on screen: four for the cloud
// itself, three for the shading it is compared against, two for the warp. Every
// octave is a full-screen cost in a renderer with no low-res pass to hide in,
// so the fifth has to earn its place at a puff's edge before it is added.
float fbm(vec2 at, int octaves) {
	float sum = 0.0;
	float amplitude = 0.5;
	vec2 walk = at;
	for (int octave = 0; octave < octaves; octave++) {
		sum += noise_on(walk) * amplitude;
		walk = walk * 2.03 + vec2(37.0, 17.0);
		amplitude *= 0.5;
	}
	return sum;
}

// Where a view ray crosses the cloud deck, one unit above the eye — very nearly
// a plane, bent by `deck_curve` above.
//
// A plane and not a sphere, and that is the whole reason the clouds look right:
// on a sphere every puff is the same size wherever you point, which is a
// texture on a dome. Crossed against a plane they foreshorten — big overhead,
// crowding together toward the skyline — which is what a cloud deck actually
// does and what the eye reads as distance.
vec2 deck_at(vec3 eyedir, float scale) {
	return eyedir.xz / (max(eyedir.y, 0.0) + deck_curve) * scale;
}

void sky() {
	float up = clamp(EYEDIR.y, -1.0, 1.0);

	// The ramp, and the ground under it. `pow` on the height rather than on the
	// angle: it puts the fast part of the change near the horizon, where the
	// band is, instead of spreading it evenly over 90°.
	vec3 backdrop = mix(horizon_colour, zenith_colour, pow(max(up, 0.0), 1.0 / zenith_curve));
	if (up < 0.0) {
		backdrop = mix(horizon_colour, ground_colour, pow(-up, 0.55));
	}

	// The band. Symmetrical about the skyline on purpose — haze is what the far
	// ground is seen through as much as the far sky, so cutting it off at zero
	// would draw the hard line this exists to avoid.
	float band = pow(1.0 - abs(up), haze_falloff);
	backdrop = mix(backdrop, haze_colour, band * haze_thickness);

	vec3 sun_dir = normalize(sun_direction);
	vec3 sun_light = sun_colour * sun_brightness;
	float towards = max(dot(EYEDIR, sun_dir), 0.0);

	// Halo first, then the disc, and both of them before the clouds: the sun is
	// behind the weather, and a disc drawn last is a sticker on the front of it.
	backdrop += sun_light * pow(towards, halo_tightness) * halo_strength;
	float from_sun = acos(clamp(dot(EYEDIR, sun_dir), -1.0, 1.0));
	backdrop = mix(backdrop, sun_light, 1.0 - smoothstep(sun_size, sun_size + sun_edge, from_sun));

	// Which way up-sun is, across the deck. Guarded because a sun near the
	// zenith has almost no horizontal direction to normalise, and the shading
	// offset below would come out as a NaN that spreads to the whole sky.
	vec2 up_sun = vec2(0.0, 1.0);
	if (length(sun_dir.xz) > FLATNESS) {
		up_sun = normalize(sun_dir.xz);
	}

	// Both decks stop before the skyline. Squared so the last of it goes out
	// gently — a linear fade leaves a visible seam along the top of the band.
	float deck = smoothstep(DECK_FADE_FROM, DECK_FADE_TO, up);
	deck *= deck;

	vec3 painted = backdrop;
	if (deck > 0.0) {
		vec2 wind = vec2(1.0, 0.35) * TIME * cloud_drift;
		vec2 at = deck_at(EYEDIR, cloud_scale) + wind;

		// The billow: two coarse octaves read as a displacement, and the field
		// sampled through it rather than at the point itself.
		vec2 swirl = vec2(fbm(at + vec2(5.2, 1.3), 2), fbm(at + vec2(9.2, 8.3), 2)) - 0.5;
		vec2 puffed = at + swirl * cloud_billow;

		// The puffs. The threshold is what turns a cloud of noise into clouds:
		// below it there is nothing at all, which is the sky the eye needs
		// between them.
		float density = fbm(puffed, 4);
		float cover = smoothstep(cloud_coverage, cloud_coverage + cloud_edge, density) * deck;

		// The relief. Comparing a puff against the same puff a short way up-sun
		// gives a slope, and a slope is all a shading term is: the face turned
		// toward the sun is where the density is climbing. Three octaves and not
		// four — the finest one is below the size of anything this shades.
		float behind = fbm(puffed - up_sun * cloud_depth, 3);
		float lit = clamp((density - behind) * cloud_relief + 0.5, 0.0, 1.0);
		vec3 body = mix(cloud_shade_colour, cloud_lit_colour, lit);

		// The cirrus, on its own scale, stretched, and drifting faster because
		// it is meant to be higher up and in a different wind.
		vec2 high = deck_at(EYEDIR, cirrus_scale) + wind * 2.3;
		float wisp = fbm(vec2(high.x / cirrus_stretch, high.y), 3);
		float veil = smoothstep(cirrus_coverage, cirrus_coverage + 0.22, wisp) * cirrus_amount * deck;

		painted = mix(painted, cirrus_colour, veil);
		painted = mix(painted, body, cover);
		// And the rim. Applied over the composited cloud, so it brightens the
		// face of whatever is in front of the sun instead of being hidden by
		// it, and scaled by coverage so the clear sky does not get it twice.
		painted += sun_colour * pow(towards, 6.0) * silver_lining * cover;
	}

	COLOR = painted;
}

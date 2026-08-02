## The car, as a CSG blockout: a tub, a greenhouse, four wheels and the panels
## a detailer would actually name, each one a [CSGCombiner3D] of its own.
##
## It replaces a green [BoxMesh] scaled to 1.9 × 1.4 × 4.3 m, and it is still
## not the final asset — the point of constructive solid geometry here is that
## the shape is a dozen numbers in a scene file rather than a mesh somebody has
## to open Blender to change, and that it keeps being that right up until the
## day a real mesh exists. [method CSGShape3D.bake_static_mesh] turns any panel
## below into an [ArrayMesh] the moment that stops being the trade you want.
##
## [b]Why it is panels and not one solid.[/b] Every child below is a separate
## CSG root, which costs the ability to run boolean operations [i]between[/i]
## panels and buys two things that a single combiner cannot give at any price.
##
## The first is that collision is generated per panel. [member
## CSGShape3D.use_collision] only builds a body on the root of a CSG tree, so
## one combiner is one collider for the whole car; twelve roots are twelve
## colliders, and [method PhysicsDirectSpaceState3D.intersect_ray] hands back
## the [CSGCombiner3D] itself as [code]collider[/code]. A tool pointed at the
## bonnet gets [code]"Hood"[/code] back, not "the car" — which is the difference
## between a game that knows you are washing a windscreen and one that knows you
## are touching something. Nothing here consumes that yet; [method panels] is
## how it will, and the grime that is coming needs a surface it can name.
##
## The second is that the boolean it costs was never wanted. The operations that
## shape a car are all [i]within[/i] a panel — the arches cut the tub, the rakes
## cut the greenhouse — because that is what a panel is: the part of the car
## that gets shaped, painted and dirtied as one thing. Panels meet by overlapping
## slightly rather than by sharing a face, which is also what keeps coplanar
## surfaces from fighting for the same pixel.
##
## [b]Where the numbers come from.[/b] Everything is authored about the car's own
## middle: local y=0 is mid-height, ground is y=-0.70, the roof is y=+0.70, and
## +Z is the front. The origin is mid-height and not the floor because the garage
## casts its standoff ray level through [code]%Car[/code]'s own position (see
## [code]src/world/garage.gd[/code]) and looks at that same point — an origin on
## the floor would aim the camera at the tarmac and measure the car's distance
## along its own shadow.
##
## [codeblock]
## overall          4.30 long, 1.90 wide, 1.40 tall   (the box's own size, kept)
## wheelbase        2.70          front axle +1.38, rear axle -1.32
## wheels           r 0.33, 0.22 wide, centres at x ±0.79
## beltline         0.95 above the ground; roof 1.40
## windscreen       33° from horizontal; backlight 46°
## tumblehome       15°, so a 1.66 m greenhouse is 1.44 m across the roof
## mirrors          reach x ±1.04, the only parts wider than the body
## [/codeblock]
##
## [b]The tub is two extrusions, not a stack of boxes.[/b] [code]Body/Profile[/code]
## is the side silhouette — bumpers, sills, the dip under the bonnet, the rise to
## the beltline — extruded the full width of the car, and [code]Body/Plan[/code]
## is the top-down silhouette intersected with it. Two brushes, and the result
## tapers at the nose and the tail and is widest through the doors, which is the
## thing that reads as "car" from across a room. Stacking boxes instead gets a
## wedding cake, and rotating boxes to chamfer each corner takes four brushes to
## do worse.
class_name Car
extends Node3D

## Thirteen paint colours a detailer might actually find parked in the
## driveway — the range you would see on the street, not a hue wheel.
## [method _ready] picks one of these for every car.
##
## Jet Black, Gunmetal and Charcoal were cut from the original sixteen: mud is a
## dark brown ([code]mud_colour[/code] in [code]grime.gdshader[/code]), and on a
## near-black or near-grey panel it sits close enough in both hue and lightness
## that a player cannot tell dirty paint from clean. The remaining colours all sit
## far enough from mud, in hue or in lightness, that the grime reads against them.
const PAINT_COLORS: Array[Color] = [
	Color(0.92, 0.92, 0.90),  # Alpine White
	Color(0.52, 0.53, 0.55),  # Pewter
	Color(0.72, 0.73, 0.75),  # Silver
	Color(0.10, 0.35, 0.16),  # British Racing Green
	Color(0.55, 0.72, 0.35),  # Lime Green
	Color(0.08, 0.20, 0.42),  # Deep Blue
	Color(0.45, 0.62, 0.78),  # Ice Blue
	Color(0.62, 0.05, 0.08),  # Crimson Red
	Color(0.35, 0.05, 0.10),  # Burgundy
	Color(0.90, 0.55, 0.05),  # Tangerine Orange
	Color(0.85, 0.70, 0.10),  # Sunflower Yellow
	Color(0.72, 0.58, 0.35),  # Champagne Gold
	Color(0.45, 0.30, 0.18),  # Bronze
]

## The body's paint. [code]Body/Profile[/code], [code]Body/Plan[/code],
## [code]Hood/Panel[/code], [code]Deck/Panel[/code], [code]Roof/Panel[/code]
## and [code]Cabin/Shell[/code] all point at this same [StandardMaterial3D] in
## the scene file — it is marked local-to-scene there, so every car gets its
## own copy rather than six panels across every car in the game repainting
## together. Setting [member StandardMaterial3D.albedo_color] here is enough
## to repaint the whole body in one write.
@export var paint: StandardMaterial3D


func _ready() -> void:
	paint.albedo_color = PAINT_COLORS.pick_random()


## Every panel of the car: the [CSGShape3D]s that are roots of their own CSG
## tree, which is exactly the set that has a mesh and a collider of its own.
##
## The root test is "my parent is not itself a CSG shape", which is the engine's
## own rule for which shape does the building, rather than a list written down
## here that would go stale the first time somebody adds a panel in the editor.
## The recursion stops at a root on purpose: the brushes underneath are the
## subtractions and intersections that shape it, they are [CSGShape3D]s too, and
## a cutting box parked two metres outside the car is emphatically not a panel.
func panels() -> Array[CSGShape3D]:
	var found: Array[CSGShape3D] = []
	_gather(self, found)
	return found


## What [param panel] is made of, which is what decides the bottle a detailer
## reaches for — see [method Surface.cleaner_for].
##
## [b]Read off a group, not off the panel's name.[/b] [method panels] goes out of
## its way not to carry a list of panel names, because a list written down in a
## script goes stale the first time somebody adds a panel in the editor; answering
## this by matching [code]"Windshield"[/code] and [code]"SideGlass"[/code] would
## put that list back, one function further down. A group is set on the node in
## [code]car.tscn[/code], next to the geometry it describes, so a new window is
## marked as glass in the same place it is given a shape.
##
## [b]Paint is the default and has no group.[/b] Most of the car is bodywork, and
## a panel added without a thought about this gets the sponge — which is right far
## more often than it is wrong, and is wrong in the direction of "my tool did
## nothing" rather than "the glass cleaner works on the doors".
func kind_of(panel: Node) -> Surface.Kind:
	if panel == null:
		return Surface.Kind.BODY
	if panel.is_in_group(Surface.GLASS_GROUP):
		return Surface.Kind.GLASS
	if panel.is_in_group(Surface.WHEEL_GROUP):
		return Surface.Kind.WHEEL
	return Surface.Kind.BODY


## The car's bounding box, in world space, around every panel it actually has.
##
## What the old green box gave callers for free as [method VisualInstance3D.get_aabb],
## and the reason this is a method rather than that: [code]%Car[/code] is now a
## [Node3D] with the geometry hanging off it, so there is no single visual
## instance left to ask. Everything that used to measure clearances against the
## car — the camera's standing distance, the walk, the reach of a held tool —
## goes through here instead.
##
## [b]It is not trustworthy until a frame has passed.[/b] CSG meshes are built
## deferred, so a panel has no [AABB] to give until the build has run — measured,
## and measured again after getting it wrong: a car instanced into an idle tree
## really does report zero, but one instanced alongside a build that is already
## flushing reports part of a car, which is worse than nothing because it looks
## like an answer. Wait a frame. Nothing in the garage reads this during startup
## — the camera is placed off [member Node3D.global_position], which is exact
## immediately — and the tests that do read it wait.
##
## Note that this is wider than the bodywork: the mirrors reach x ±1.04 against
## a body half-width of 0.95, so an axis-aligned box around the car is 2.08 m
## across at the nose as well as at the doors. That is the honest answer for a
## box and the conservative one for anything asking "am I clear of the car" —
## the ray the garage's standoff actually steers by is cast against the colliders
## below, which have the real outline.
func bounds() -> AABB:
	var box: AABB = AABB()
	var found: bool = false
	for panel: CSGShape3D in panels():
		var painted: AABB = panel.global_transform * panel.get_aabb()
		box = painted if not found else box.merge(painted)
		found = true
	return box


## Depth-first for CSG roots, descending through plain [Node3D]s so panels can
## be grouped in the editor, and never through a root into its own brushes.
func _gather(node: Node, found: Array[CSGShape3D]) -> void:
	for child: Node in node.get_children():
		var shape: CSGShape3D = child as CSGShape3D
		if shape != null:
			found.append(shape)
			continue
		_gather(child, found)

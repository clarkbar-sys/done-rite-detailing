## The car: the panels a detailer would name, and the contract every other class
## in the game reads them through. Today they are a CSG blockout — a tub, a
## greenhouse, four wheels and a panel per part, each one a [CSGCombiner3D] of
## its own — and [method panels] deliberately no longer says so, which is what
## the contract section below is about.
##
## It replaces a green [BoxMesh] scaled to 1.9 × 1.4 × 4.3 m, and it is still
## not the final asset — the point of constructive solid geometry here is that
## the shape is a dozen numbers in a scene file rather than a mesh somebody has
## to open Blender to change, and that it keeps being that right up until the
## day a real mesh exists. [method CSGShape3D.bake_static_mesh] turns any panel
## below into an [ArrayMesh] the moment that stops being the trade you want.
##
## [b]What a panel has to be, said without saying CSG.[/b] Everything downstream
## of [method panels] does exactly four things with what it is handed, and those
## four are the whole contract:
##
## [codeblock]
## 1  a local-space AABB       sizes the grime map, and is what bounds() merges
## 2  a material_overlay slot  where the grime shader hangs
## 3  group membership         kind_of(), via Surface.GLASS_GROUP and friends
## 4  the node a ray hands back intersect_ray's `collider`, named in the readout
## [/codeblock]
##
## One node covers all four here only by an accident of the blockout. A
## [CSGShape3D] is a [GeometryInstance3D], which is 1 and 2; with [member
## CSGShape3D.use_collision] it generates its own body, so [method
## PhysicsDirectSpaceState3D.intersect_ray] hands the panel itself back, which is
## 4. Nothing had to be arranged and so the whole chain could be typed
## [CSGShape3D] end to end. A [MeshInstance3D] breaks that: it is 1 and 2 and it
## is not a collider and never will be, so a mesh car cannot answer 4 with the
## node that answers 1 and 2.
##
## [b]So a panel is a root and a skin, and [method panels] hands back the
## root.[/b] The [i]root[/i] is whatever a ray comes back holding — a
## [StaticBody3D] on a mesh car, the [CSGShape3D] itself on this one — and it is
## where the groups go, because 3 and 4 have to be true of the same node or a hit
## cannot be named. The [i]skin[/i] is the [GeometryInstance3D] at or under the
## root that carries 1 and 2, and [method skin_of] is how anything asks for it;
## on this car it answers the panel itself, unchanged.
##
## A mesh car is therefore a [StaticBody3D] parked where each [CSGCombiner3D] is
## today, with the imported mesh and a [CollisionShape3D] under it, carrying the
## same groups under the same names — and no other file has to know.
##
## [b]An accessor pair and not an adapter object.[/b] The tidy-looking
## alternative is a small [RefCounted] holding the two nodes, handed out by
## [method panels] instead of the root. It does not survive contact with what a
## panel is [i]for[/i]: three callers hold a panel that came out of a raycast and
## look it up by identity ([method Grime.map_of], [method Grime.flash_of], the
## attract loop's running order), and a wrapper minted per call never matches
## while a wrapper cached per node is this accessor with a dictionary in front of
## it. A panel is also not a thing this class owns — it is a node somebody
## authored in a scene — and an adapter would be a second lifetime to keep in
## step with it for no gain.
##
## [b]And "wait a frame before you trust the box" is CSG's, not the
## contract's.[/b] A CSG panel has no mesh, and so no [AABB], until the deferred
## build has run; a [MeshInstance3D] answers exactly, on the frame it is
## instanced. That warning is written on [method bounds] and on [method
## Grime.lay_on] as a fact about this blockout, and it comes off with the
## blockout — nothing in the four points above says a panel is late.
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
## [b]And some of it is not a panel at all.[/b] [code]Undercarriage[/code] and
## [code]WheelWells[/code] sit in [constant TRIM_GROUP], which keeps them out of
## [method panels] and so out of the grime, out of the colliders a tool can hit,
## and out of the attract loop's running order. They are there to be looked at and
## for nothing else — a floor pan, an exhaust and two axles under the sills, a
## liner inside each arch — because a car with nothing under it reads as a prop
## the moment the camera drops, and a player who can scrub the inside of a wheel
## arch is being sold work the game has no opinion about finishing.
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

## The group that marks a node as trim: geometry the player can see and can never
## clean.
##
## [b]Why it is here and not in [Surface].[/b] The other two groups this car uses
## — [constant Surface.GLASS_GROUP] and [constant Surface.WHEEL_GROUP] — each name
## a [enum Surface.Kind], which is to say they answer "which bottle treats this".
## Trim answers a question one step earlier, and answers it in a different
## currency: it is not a surface with an awkward cleaner, it is not a surface.
## Filing it beside the other two would leave [Surface] — a class whose first line
## is "what a panel of the car is made of" — holding a constant that means "this
## is not a panel", and would make the file that carries the rules of the job the
## file you open to add a mud flap. So it lives next to [method panels], which is
## the only thing that reads it.
const TRIM_GROUP: String = "trim"

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


## Every panel of the car: the roots a ray can hand back, each one with a skin
## under it — the class docs have the full shape of that.
##
## The test is a property of the node and not a list written down here, which is
## the same argument [method kind_of] makes about reading a group instead of a
## name: a list goes stale the first time somebody adds a panel in the editor. A
## panel is something a ray can be handed back holding — a [CSGShape3D], which
## builds its own body, or a [CollisionObject3D], which is one — [i]and[/i] has a
## [method skin_of] to be measured and painted. Both halves are required, because
## a body with no geometry has no box to size a map from, and geometry with no
## body is a thing no tool can ever land on.
##
## The recursion stops at a panel on purpose: on this car the brushes underneath
## are the subtractions and intersections that shape it, they are [CSGShape3D]s
## too, and a cutting box parked two metres outside the car is emphatically not a
## panel. On a mesh car it is the mesh and the collision shape under the body,
## which are the panel rather than two more of them.
##
## [b]What is deliberately not tested here is [member CSGShape3D.use_collision].[/b]
## It is the flag that actually arms a CSG panel's body, and
## [code]tests/integration/test_garage.gd[/code] asserts it on every panel of the
## real car. Reading it here would make a panel's [i]existence[/i] depend on a
## checkbox: a panel with the box unticked would silently leave the car — no
## grime, no map, no cleaner — instead of failing the test that says a tool must
## be able to hit it. Loud is the right direction for that mistake.
##
## [constant TRIM_GROUP] is the one thing that overrules all of it — see [method
## _gather]. Everything downstream of here takes this list as the whole of the car
## it has to deal with, so a panel left out of it has no grime, no map, no turn in
## the attract loop and no cleaner, which is exactly what trim wants.
func panels() -> Array[Node3D]:
	var found: Array[Node3D] = []
	_gather(self, found)
	return found


## The geometry of [param panel]: the node that carries its [AABB] and its
## [member GeometryInstance3D.material_overlay] — points 1 and 2 of the contract
## in the class docs — or [code]null[/code] for a node that has none.
##
## [b]The panel itself, whenever the panel is geometry.[/b] Every [CSGShape3D] is
## a [GeometryInstance3D], so on this car this is the identity function and the
## blockout satisfies the widened contract without a line of the scene file
## changing. It only has work to do for a panel whose root is a body — a mesh
## car's [StaticBody3D] — where the answer is the [MeshInstance3D] underneath.
##
## Depth-first and first-match, rather than a named child or an exported path.
## A glTF importer decides how deeply it nests the mesh it makes and under what
## name, and a car scene built from one should not have to be rearranged to be
## washable; the shallowest geometry under the root is the one that is there
## whichever shape the import took.
##
## [b]Read it, do not cache it.[/b] It walks a handful of children and it is
## called once per panel when the grime is laid and once per panel per frame at
## most anywhere else. [Grime] keeps the answer beside its maps because it is
## already keeping an array parallel to the panels and not because this is dear.
func skin_of(panel: Node) -> GeometryInstance3D:
	if panel == null:
		return null
	var geometry: GeometryInstance3D = panel as GeometryInstance3D
	if geometry != null:
		return geometry
	for child: Node in panel.get_children():
		var under: GeometryInstance3D = skin_of(child)
		if under != null:
			return under
	return null


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
## [b]It is not trustworthy until a frame has passed — on a CSG car.[/b] CSG
## meshes are built deferred, so a panel has no [AABB] to give until the build has
## run — measured, and measured again after getting it wrong: a car instanced into
## an idle tree really does report zero, but one instanced alongside a build that
## is already flushing reports part of a car, which is worse than nothing because
## it looks like an answer. Wait a frame. Nothing in the garage reads this during
## startup — the camera is placed off [member Node3D.global_position], which is
## exact immediately — and the tests that do read it wait.
##
## That is a fact about the blockout and not about this method. A panel skinned
## with a [MeshInstance3D] has its box the moment it is in the tree, so the wait
## is one of the things that comes off with the CSG.
##
## Note that this is wider than the bodywork: the mirrors reach x ±1.04 against
## a body half-width of 0.95, so an axis-aligned box around the car is 2.08 m
## across at the nose as well as at the doors. That is the honest answer for a
## box and the conservative one for anything asking "am I clear of the car" —
## the ray the garage's standoff actually steers by is cast against the colliders
## below, which have the real outline.
## Measured off the skin and moved by the skin's own transform, not the root's.
## They are the same node on this car and they are not on a mesh one, where the
## importer is free to leave the mesh sitting at an offset inside its body — and
## an [AABB] read from one node and placed by another is the kind of wrong that
## looks right until somebody moves a wheel.
func bounds() -> AABB:
	var box: AABB = AABB()
	var found: bool = false
	for panel: Node3D in panels():
		var skin: GeometryInstance3D = skin_of(panel)
		var painted: AABB = skin.global_transform * skin.get_aabb()
		box = painted if not found else box.merge(painted)
		found = true
	return box


## Depth-first for panels, descending through anything that is not one so they can
## be grouped in the editor, and never through a panel into what it is made of.
##
## [b]Trim is skipped whole.[/b] A node in [constant TRIM_GROUP] is neither
## collected nor descended into, so marking one combiner covers every brush under
## it and marking a plain [Node3D] covers everything it holds — one group on one
## node rather than the same group repeated across nine cylinders, which is the
## version somebody forgets half of.
##
## The exclusion is here and not in [method kind_of] because it is not a kind. A
## trim node that reached [method Grime.lay_on] would be handed a map and an
## overlay and would be washable from that moment on, whatever [method kind_of]
## said about it; the only way for a thing to have no cleaner is for it never to
## have been a panel.
func _gather(node: Node, found: Array[Node3D]) -> void:
	for child: Node in node.get_children():
		if child.is_in_group(TRIM_GROUP):
			continue
		var part: Node3D = child as Node3D
		if part != null and _is_a_part(part) and skin_of(part) != null:
			found.append(part)
			continue
		_gather(child, found)


## Whether [param node] is the kind of thing a ray comes back holding — point 4 of
## the contract in the class docs, which is the half of "is this a panel" that is
## about physics rather than about geometry.
##
## Two cases and no third, because the engine has two ways of putting a node in
## the physics world. A [CSGShape3D] generates a body of its own from its brushes
## and is handed back as itself; a [CollisionObject3D] — a [StaticBody3D] on a
## mesh car — [i]is[/i] the body. Anything else a ray meets belongs to one of
## those two, and asking about the parts underneath would collect a panel twice.
func _is_a_part(node: Node3D) -> bool:
	return node is CSGShape3D or node is CollisionObject3D

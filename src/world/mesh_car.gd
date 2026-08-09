## The car as a real model: one of the ten styles baked out of the car pack into
## [code]assets/models/cars/[/code], wrapped part by part into the panels the rest
## of the game already knows how to wash.
##
## [b]It is a [Car] and it adds nothing to the contract.[/b] [method Car.panels],
## [method Car.skin_of], [method Car.kind_of] and [method Car.bounds] are
## inherited unchanged and are the whole of what the garage, the grime and the
## tools consume — [Car]'s class docs are where the four points of that contract
## are argued, and the paragraph in them that begins "A mesh car is therefore a
## [StaticBody3D] parked where each [CSGCombiner3D] stood" is a description of
## this file. So this class is not a second kind of car; it is the same car with
## its geometry arriving from a [code].glb[/code] instead of from a scene file,
## and everything it does happens before the first frame the rest of the game
## sees.
##
## Subclassing rather than sharing a base, because there is nothing to share: the
## four methods above are already about "a root a ray can hand back, with a skin
## under it" and neither of them mentions CSG. A common base would be [Car] with
## the word [code]Car[/code] taken off it and two files where there is one. It
## also kept [code]#139[/code] — swapping this into the driveway — down to which
## scene [code]%Car[/code] instances, because [code]src/world/garage.gd[/code]
## types that reference [Car] and this is one. The one thing it did cost the room
## is that the ten styles are ten heights, so where the car sits on the tarmac had
## to stop being a number in a scene file — see [code]Garage._park_the_car[/code].
##
## [b]What the pack hands over.[/b] [code]scripts/build-car-pack.py[/code] bakes
## each style into exactly seven [MeshInstance3D]s under one [Node3D] — [code]Body[/code],
## [code]Glass[/code], [code]Optics[/code] and [code]Wheel1[/code]..[code]Wheel4[/code]
## — in metres, +Z forward, origin at mid-height, tyres resting on the bottom of
## the box, and the body's albedo baked to greyscale so the game supplies the
## colour. That script asserts every one of those properties on the way out, which
## is why this one can rely on the names below rather than searching for a car
## inside whatever an artist exported.
##
## [b]Each part becomes a body with the mesh inside it.[/b] A [MeshInstance3D] is
## geometry and never a collider, so a ray would come back holding nothing at all
## — point 4 of the contract — and the panel would be invisible to every tool. So
## each part is reparented under a [StaticBody3D] of its own, named after the part,
## with a [CollisionShape3D] beside it. The [i]body[/i] carries the part's
## transform and the group; the mesh sits at identity inside it and is what
## [method Car.skin_of] answers with.
##
## [b]The colliders are trimeshes, generated at load.[/b] [method Mesh.create_trimesh_shape]
## turns a part's own triangles into a [ConcavePolygonShape3D], so the thing a tool
## hits is the thing the player can see — down to the wheel arches and the gap
## between a tyre and its sill. Measured on this hardware: 7,122 triangles
## for the whole sedan in 2.8 ms, 7,951 for the SUV in 3.4 ms. That is one frame's
## worth of work, once, for the one car a game has, which is why it is not baked
## into ten [code].tres[/code] files sitting beside the [code].glb[/code]s: those
## would be ten more resources to regenerate every time the pack is rebuilt, and
## the first time somebody forgot, the car would be washed through the collider of
## a car that no longer exists.
##
## A convex hull would be cheaper still and is the wrong shape by a mile: it is a
## shrink-wrap, so the arches fill in, the greenhouse fuses to the roof, and a jet
## aimed between the wheel and the sill lands on paint that is not there. Concave
## is what "the tool hits what you can see" costs, and a static body pays it once.
##
## [b]Both sides of every face are solid[/b] ([member ConcavePolygonShape3D.backface_collision]).
## Every part of this pack is a shell with no thickness — the glass is a single
## sheet the artist ships with culling disabled, and the panels are no thicker —
## so a triangle wound the other way lets an aimed ray pass straight through the
## thing it was fired at and come back holding whatever is behind it, or nothing at
## all. Measured, firing square at 2,783 sampled faces across all ten styles from a
## hand's width out: with backface collision off, 171 of those rays come back empty;
## with it on, 7 do. The wheels are the worst of it — 21 of 65 sampled faces of a
## pickup's tyre are invisible to a ray from outside without this, which is a tool
## finding the tarmac through a wheel arch. Nothing in this game casts a ray from
## inside a car, so every extra hit it allows is a hit that was wanted.
##
## [b]The groups are read off the part names, and that is not the same mistake
## [method Car.kind_of] warns about.[/b] That warning is against a script naming
## panels that are authored somewhere else — a list that goes stale the first time
## somebody adds a window in the editor. There is no editor here: a glTF has no way
## to carry a Godot group, so a name is the only thing the file can hand over, and
## the names are generated by a script that asserts them. What is written down
## below is therefore the pack's contract rather than a copy of a scene file.
##
## [constant GLASS_PARTS] holds two names, and the second is the decision from
## [code]#134[/code]: the head- and tail-lights are lenses, a detailer does them
## with the blue bottle and the rag, and giving them their own kind would be a
## fourth cleaner nobody asked for. [constant WHEEL_PART] is a prefix rather than
## four names because the pack numbers them and nothing here cares which corner is
## which. Everything else — which is [code]Body[/code] — is paint by
## [method Car.kind_of]'s own defaulting, which is the answer for the panel that is
## most of the car.
##
## [b]And nothing is trim.[/b] [constant Car.TRIM_GROUP] exists for geometry that
## is there to be looked at and can never be cleaned, which on the blockout is the
## floor pan and the arch liners. This pack has neither: it is an outside-only
## shell, everything in it is bodywork, glass or rubber, and the one part that
## looks like a candidate — the SUV's body-coloured hub caps — is not one. It is a
## second surface on the wheel mesh sharing the body material, so it arrives inside
## the wheel panel, gets tinted with the paint and is washed with the tyre.
##
## [b]The paint is the pack's own material with a colour put on it.[/b] The body's
## albedo map is baked greyscale precisely so [member StandardMaterial3D.albedo_color]
## can tint it, exactly as [member Car.paint] documents for the blockout — but the
## material carries a packed metallic-roughness map alongside it
## ([code]<style>_1.png[/code]), so a [StandardMaterial3D] authored in a scene file
## here would either lose that or copy it by hand for ten styles. Instead the
## imported material is duplicated and [member Car.paint] is pointed at the copy:
## every map the pack baked survives, and the copy is per instance, which is what
## [code]resource_local_to_scene[/code] buys the blockout. Two cars in one room
## repaint separately; the textures are shared references and are not copied.
##
## [b]And the colour is driven past itself on the way on[/b], because that greyscale
## map averages 0.653 over the bodywork rather than 1.0 — so a tint left at face
## value arrives at about two thirds of the colour it names.
## [constant MAP_COMPENSATION] is what makes up for it, and carries the argument for
## why it makes up for most of that rather than all of it.
##
## [b]The glass is repainted outright[/b], because the pack's is near-black at 68%
## alpha and this game decided otherwise in [code]#58[/code]: a light bluish-green,
## the same numbers [code]tests/fixtures/blockout_car.tscn[/code] gives the blockout's windows.
## Opaque, and that is the deliberate half — these bodies are shells with no
## interior, so a see-through windscreen shows the inside of the far door. Culling
## stays off, which is the pack's own setting for a shell with no thickness.
class_name MeshCar
extends Car

## Where the ten styles live, one [code].glb[/code] each.
const PACK_DIR: String = "res://assets/models/cars/"

## The ten body styles, which are the file names in [constant PACK_DIR] without
## their extension. One of them is picked for every car — see [member style].
const STYLES: Array[String] = [
	"compact",
	"coupe",
	"hatchback",
	"minivan",
	"offroad",
	"pickup",
	"sedan",
	"sport",
	"suv",
	"wagon",
]

## The part that is painted, and the material every other part is compared against
## to find out whether it is painted too — see [method _repaint].
const BODY_PART: String = "Body"

## The windows: the one part that is repainted rather than left as the pack shipped
## it — see [member glass].
const GLASS_PART: String = "Glass"

## The parts a detailer reaches for the blue bottle for: the windows, and the
## lamp lenses along with them (decision on [code]#134[/code]).
##
## The lenses are in the [i]group[/i] and keep their own material: they are glass
## to the rules of the job and a red tail-light to look at, and those are different
## questions.
const GLASS_PARTS: Array[String] = [GLASS_PART, "Optics"]

## What a wheel's part name starts with. The pack numbers them
## [code]Wheel1[/code]..[code]Wheel4[/code], front-left, front-right, rear-left,
## rear-right.
const WHEEL_PART: String = "Wheel"

## How far past its own value a colour from [constant Car.PAINT_COLORS] is
## driven, to make up for the greyscale map it is multiplied into.
##
## [b]The map is not neutral, which is the whole reason this exists.[/b] The
## pack bakes the body albedo to greyscale so the game can tint it — see the
## class docs — but greyscale is not white: measured over the bodywork of the
## sedan at the showcase angle, it multiplies the paint by 0.653. So a colour
## lands at about two thirds of the value it names, and the palette
## [constant Car.PAINT_COLORS] carefully picks is not the palette that reaches
## the screen, and the loss is proportional — it squashes the top of the range
## (Viper White, and Header Orange's red channel, both authored at 0.92, same
## as Alpine White was before #170) rather than the bottom (Viper Black,
## deliberately lifted off zero for exactly this — see the class docs).
##
## [b]And it is 1.25 rather than the 1.53 that would cancel the map outright.[/b]
## 1.53 does land Viper White back on its authored lightness, and it does it
## by blowing 49% of its bodywork to flat 255 — unchanged by #170, since the
## colour itself did not move. The bay's [Environment] sets no tonemap —
## linear, exposure 1.0 — so anything over 1.0 hard-clips, and what the
## greyscale map has quietly been doing all along is keeping the brightest
## panels underneath that ceiling. Take the darkening away without putting a
## highlight rolloff in its place and the light half of the palette stops
## being too dark and starts being blown out, which is the worse of the two:
## a dark car is still a car, and a bonnet at flat white has no shape on it
## at all.
##
## So this is the most lift there is before that starts. Measured on Viper
## White, at the same angle, counting body pixels at 254/255 or above: 1.15,
## 1.20 and 1.25 clip nothing whatsoever, and 1.30 puts 28.7% of its body at
## the ceiling. It buys [code]L* 35.0 → 43.9[/code] on that panel, which is a
## little over half the deficit, and it costs the room nothing — the tarmac,
## the grass and the sky move by 0.2/255, which is bounce.
##
## [b]The other half needs a tonemap and is deliberately not here.[/b] A filmic
## or ACES curve has the rolloff this wants and would let the paint come all the
## way back; it also lifts every other surface in the room by about 44/255, which
## is a relight — and [code]src/world/garage.tscn[/code] argues at length that a
## relight is its own change, with every value in it to be found again.
##
## [b]On [MeshCar] and not on [Car][/b], because it is a fact about the pack's
## map. The blockout has no texture under its paint, so a colour put on it
## arrives at full value and compensating it would simply overexpose it.
const MAP_COMPENSATION: float = 1.25

## Which body style this car is, or [code]""[/code] to have one picked at random —
## after [method Node._ready] it always names the style that was picked.
##
## The same shape as the paint it sits beside: [method Car._ready] picks one of
## [constant Car.PAINT_COLORS] and leaves the answer in [member Car.paint] where a
## test can read it. This is that, plus a way in — a car is one thing out of ten
## and a test that wants the pickup should not have to instantiate cars until one
## turns up. Set it before the node enters the tree; after that it is a readout.
##
## [b]An export and not a seeded generator.[/b] Seeding [method @GlobalScope.randi]
## would make every random thing in the game move together, and what a test
## actually wants is not "the same car every run" but "this car" — so the door is
## the value itself. Nothing else about the pick is worth reproducing: it is one
## draw from ten, taken once.
##
## [b]Empty is what "nobody chose" means, and it is no longer the same thing as
## "at random".[/b] [code]#142[/code] pinned this to the sedan in
## [code]src/world/mesh_car.tscn[/code] so a playtest got the same car twice;
## [code]#143[/code] took the pin out and gave the choice to the player instead,
## which is [CarChoice] and the arrows on the menu. So an empty style now asks
## that class what the player picked, and only falls back to a draw from
## [constant STYLES] when nobody has picked yet — which is true for the one car
## that is parked before any screen has offered a choice. What this export means
## is unchanged: a car this is set on is that car, and the whole of what a caller
## has to do is set it before the node enters the tree.
@export var style: String = ""

## What the windows are made of — see the class docs for why the pack's own near-
## black glass is not used. Lives in [code]src/world/mesh_car.tscn[/code] beside
## the script, the way every other look-and-feel number in this project lives in a
## scene file.
##
## Not local-to-scene, unlike [member Car.paint]: glass is the same colour on every
## car in the world, and one shared material across all of them is one less copy.
@export var glass: StandardMaterial3D


func _ready() -> void:
	if style.is_empty():
		style = CarChoice.for_the_next_car(STYLES)
	_build(style)
	# The paint colour is [Car]'s to pick and this class deliberately does not
	# repeat it — but it can only be picked once there is a material to put it on,
	# which is what `_build` above has just made. A car whose model failed to load
	# has no paint and would take `super()` down with it, which is a crash instead
	# of the empty car the error above already reported.
	if paint == null:
		return
	super()
	# After `super()` and not instead of it: which colour a car is remains [Car]'s
	# to pick, and what this adds is only that the pack's map is on the way between
	# that colour and the screen. Repainting a car by hand — which is what the menu
	# does through [method restyle] — goes through [method compensated] for the same
	# reason.
	paint.albedo_color = compensated(paint.albedo_color)


## [param colour] driven up by [constant MAP_COMPENSATION], which is what it takes
## to arrive on the paint looking like itself.
##
## Static, and public, so the sum can be asserted without standing a car up in a
## tree — and so the one other place that puts a colour on this material
## ([method restyle]) can say out loud that it is not applying it twice.
##
## The alpha is left alone: this is an exposure on the tint, and a paint job that
## quietly became more opaque than it was asked to be would be a bug in a
## different subject.
static func compensated(colour: Color) -> Color:
	return Color(
		colour.r * MAP_COMPENSATION,
		colour.g * MAP_COMPENSATION,
		colour.b * MAP_COMPENSATION,
		colour.a,
	)


## Throws this car away and parks [param style_name] in its place, on a car that
## is already standing in a room.
##
## [b]The one thing [member style] cannot do.[/b] That export is read once, in
## [method Node._ready], which is the right contract for the car a game is played
## with — it is chosen before the bay exists and never changes while somebody is
## washing it. The menu is the exception and the reason this exists: the bay
## behind it is a showroom, the arrows are a way to look at the other nine, and a
## picker whose label says "Pickup" over a sedan is a picker that reads as broken.
## The room drives this rather than a screen — see [method Garage.show_style],
## which is also what re-sits the new car on the tarmac and puts fresh mud on it.
##
## [b]Removed and then freed, in that order, which is the whole of why this is
## safe.[/b] [method Node.queue_free] is deferred, so panels freed alone would
## still be children for the rest of the frame — and [method Car.panels] would
## answer with fourteen of them, [method Car.bounds] would report a box around two
## cars at once, and both old colliders and new would be in the physics space for
## a tick. Removing first is immediate on all three counts. It is the same pairing
## and the same argument [code]src/main/main.gd[/code] makes for swapping a
## screen.
##
## [b]The paint carries over and the model does not.[/b] [method _build] hands
## back a fresh copy of the pack's greyscale livery, so a car rebuilt without this
## would come out unpainted — and re-rolling [constant Car.PAINT_COLORS] instead
## would mean the colour changed every time somebody pressed an arrow, which turns
## "look at the other nine" into a slot machine. What a player is comparing is the
## shape, so the shape is the only thing that moves.
##
## The colour it carries across has already been through [method compensated] —
## it is read back off the material this is about to replace — so it is emphatically
## not put through it again. A second pass would brighten the car by a quarter per
## press of the arrow, which is a slot machine of a different kind.
func restyle(style_name: String) -> void:
	if style_name == style:
		return
	var colour: Color = Color.WHITE if paint == null else paint.albedo_color
	for panel: Node in get_children():
		remove_child(panel)
		panel.queue_free()
	style = style_name
	_build(style)
	# A style with no model behind it has already been reported by `_build`, and
	# what is standing here now is a car with no panels rather than a crash — the
	# same failure mode `_ready` leaves behind, reached the same way.
	if paint == null:
		return
	paint.albedo_color = colour


## Builds the panels of [param style_name] under this node: seven parts, each one
## a [StaticBody3D] with the pack's mesh and a collider of its own inside it.
##
## The imported scene is a temporary. Its parts are moved out of it rather than
## copied — a [MeshInstance3D] is a node holding a reference to a [Mesh], and the
## mesh is a shared resource either way — and the empty root is thrown away, so
## nothing is left in the tree between this car and its panels.
func _build(style_name: String) -> void:
	var packed: PackedScene = load(PACK_DIR + style_name + ".glb") as PackedScene
	if packed == null:
		push_error("MeshCar: no model for style '%s' in %s" % [style_name, PACK_DIR])
		return
	var pack: Node3D = packed.instantiate() as Node3D
	var livery: StandardMaterial3D = _livery_of(pack)
	if livery == null:
		push_error("MeshCar: %s has no %s to paint" % [style_name, BODY_PART])
		pack.free()
		return
	paint = livery.duplicate() as StandardMaterial3D
	for part: Node in pack.get_children():
		var mesh: MeshInstance3D = part as MeshInstance3D
		if mesh == null:
			continue
		_wrap(mesh, pack, livery)
	pack.free()


## The material the body of [param pack] is painted in, or [code]null[/code] for a
## model with no body in it.
##
## Wanted twice over: it is what [member Car.paint] is copied from, and it is what
## [method _repaint] compares every other surface against — the SUV's hub caps are
## the same material on a different mesh, and that is how they are found.
func _livery_of(pack: Node3D) -> StandardMaterial3D:
	var body: MeshInstance3D = pack.get_node_or_null(NodePath(BODY_PART)) as MeshInstance3D
	if body == null or body.mesh == null or body.mesh.get_surface_count() == 0:
		return null
	return body.mesh.surface_get_material(0) as StandardMaterial3D


## Moves one part of [param pack] under a [StaticBody3D] of its own and hangs that
## on the car.
##
## The transform goes on the body and the mesh is left at identity inside it. Both
## are allowed by the contract — [method Car.bounds] and [Grime] measure the skin
## and move it by the skin's own transform, exactly so an importer's offsets cannot
## matter — but a wheel whose body sits on the axle is the arrangement that reads
## correctly in the editor and puts the collider where the geometry is without a
## second transform to keep in step.
##
## [param livery] is the body material, and every surface painted in it becomes
## [member Car.paint] — see [method _repaint].
func _wrap(mesh: MeshInstance3D, pack: Node3D, livery: StandardMaterial3D) -> void:
	if mesh.mesh == null:
		return
	var part: String = String(mesh.name)
	var panel: StaticBody3D = StaticBody3D.new()
	panel.name = part
	# Renamed before it is reparented, so the body can take the part's own name:
	# the panel is what a raycast hands back and what the readout says out loud,
	# and "Body" is a better answer than "Body2".
	mesh.name = "%sMesh" % part
	var pose: Transform3D = pack.transform * mesh.transform
	pack.remove_child(mesh)
	# The imported scene is about to be freed and the mesh is not going with it.
	# An owner that is not an ancestor is what `add_child` warns about — "will make
	# owner 'sedan' inconsistent" — seven times per car, in a project whose smoke
	# test reads the log.
	mesh.owner = null
	mesh.transform = Transform3D.IDENTITY
	panel.transform = pose
	panel.add_child(mesh)
	panel.add_child(_collider_for(mesh, part))
	_repaint(mesh, part, livery)
	var group: String = _group_for(part)
	if not group.is_empty():
		panel.add_to_group(group)
	add_child(panel)


## The collider for [param mesh] — its own triangles, solid from both sides. The
## class docs have the argument for both halves of that.
func _collider_for(mesh: MeshInstance3D, part: String) -> CollisionShape3D:
	var shape: ConcavePolygonShape3D = mesh.mesh.create_trimesh_shape()
	shape.backface_collision = true
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "%sShape" % part
	collider.shape = shape
	return collider


## Puts this car's own [member Car.paint] over every surface of [param mesh] that
## the pack painted in [param livery], and this game's glass over the windows.
##
## Per surface and by material identity, rather than "the body mesh gets the
## paint". The SUV's wheels carry a second surface using the body material for the
## hub caps, and comparing materials is what tints those with the car instead of
## leaving four grey discs on a red truck. Everything the comparison misses — the
## tyre, the lamp lenses — is left exactly as the pack shipped it, which is the
## right default for a part whose texture is the point of it.
##
## An override and not a write into the mesh: a [Mesh] is a shared resource, so
## painting into it would repaint every car of this style ever loaded, including
## the ones already parked.
func _repaint(mesh: MeshInstance3D, part: String, livery: StandardMaterial3D) -> void:
	for surface: int in range(mesh.mesh.get_surface_count()):
		if mesh.mesh.surface_get_material(surface) == livery:
			mesh.set_surface_override_material(surface, paint)
			continue
		if part == GLASS_PART and glass != null:
			mesh.set_surface_override_material(surface, glass)


## The group [param part] belongs in, or [code]""[/code] for the parts that are
## paint — which is the default and has no group of its own. See the class docs
## for why this is a rule about names here and is not one on the blockout.
func _group_for(part: String) -> String:
	if GLASS_PARTS.has(part):
		return Surface.GLASS_GROUP
	if part.begins_with(WHEEL_PART):
		return Surface.WHEEL_GROUP
	return ""

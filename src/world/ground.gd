## The ground the car is parked on: a modeled driveway, the lawn either side of
## it, and the banks that close the place in — one imported mesh, stood on the
## room's own floor.
##
## [b]It replaces three scaled boxes and a wood of rolled primitives.[/b] The
## driveway used to be a unit [BoxMesh] 4.4 m across, the grass two more either
## side of it, and the tree line fourteen cylinders-and-spheres planted from
## fixed seeds around the edge of the lawn. All of that was a blockout in the
## same sense the car's was — the shapes and their sizes were the design
## decision, and none of it should have been waiting on an artist. This is the
## artist arriving: [i]Sunken Driveway Parking Spot[/i], a concrete pad let into
## a grass field that rises away from it on every side.
## [code]assets/models/driveway/ATTRIBUTION.txt[/code] carries the credit, the
## menu carries the copy of it a player can read, and #114 is where the swap was
## argued.
##
## [b]This scene exists because the model's origin is not the room's.[/b] The
## glTF is authored Z-up, about a point 0.403 m below its own concrete, with the
## pad's footprint 0.125 m to one side of that point and 0.247 m along it.
## Godot's importer fixes the first of those and none of the rest, so something
## has to hold the one transform that turns the model's metres into a floor —
## and putting it here rather than in [code]src/world/garage.tscn[/code] is what
## lets the room go back to holding a single node called [code]Ground[/code],
## standing at the origin, the way it held three boxes standing at theirs. The
## numbers are in [code]src/world/ground.tscn[/code] beside the model they are
## about.
##
## [b]The scale is a fifth over the model's own metres, and it is the camera that
## asks for it.[/b] The showcase circuit sweeps a 5.6 m disc around the car
## ([member Garage.orbit_radius]), and the model at 1:1 reaches 5.04 m either
## side of the concrete — 0.56 m short, so the eye would spend part of every lap
## past the edge of the world it is looking into. At 1.25 the outer edge stands
## 6.30 m out, which is the old lawn's fence again with 0.7 m to spare, and the
## same quarter puts the walk's own standoff — 2.55 m from the middle of the car
## — on concrete rather than out over the kerb, because the pad goes from 2.35 m
## half-width to 2.94 m. What it costs is that a kerbstone is a fifth larger
## than the person who modeled it meant, at ten metres, in a game about the paint
## on a car. [code]tests/integration/test_ground.gd[/code] does the sum against
## [Garage]'s own radius rather than trusting the 6.30 written here.
##
## [b]Nothing out here has a collider, and that is the same decision the trees
## were held to.[/b] The room casts a ray for the camera's standoff and another
## for the aim mark, and both are asking a question about the [Car]. Ground with
## a body would let a finger on the horizon mark a bank of grass, and would give
## the walk something to hug that is not the paint. The import brings none in —
## no node in the model carries the [code]-col[/code] suffix that would generate
## one — and a test says so rather than leaving it to the next person to
## re-import with a box ticked.
##
## [b]What it is for, beyond being drawn.[/b] Two questions the rest of the room
## used to answer by reading a box's scale off the scene file: how high the drive
## is ([method drive]), which is where a car of any height gets sat, and how far
## the modeled ground reaches ([method extent]), which is the fence the camera
## and everything held in front of it stay inside. Both are measured off the
## meshes themselves, so ground that is re-placed or re-scaled moves them
## together and nothing has to remember to follow.
class_name Ground
extends Node3D

## Which mesh in the imported model is the concrete a car can be parked on.
##
## An [code]@export[/code] because the name is the model's rather than ours: the
## importer derives it from the glTF node, and a name this project did not choose
## belongs in the scene file next to the model it came with, where re-importing a
## differently-named pad is one line to fix instead of a script to open.
@export var concrete: NodePath


## Where the top of the drive is and how much of it there is, as a box in world
## space — the concrete itself, not the field it is let into.
##
## [b]This is the room's floor, measured rather than declared.[/b] Every car in
## the pack is authored about its own mid-height and the ten are 1.04 m to 1.77 m
## tall, so [method Garage._park_the_car] has to lift each one by half of itself
## onto something; that something is [code]drive().end.y[/code], which this scene
## puts at zero and would go on reporting truthfully if it did not. The width and
## depth are here for the same reason — a car parked on ground it overhangs is a
## thing a test can notice before a player does.
##
## An empty box if [member concrete] names nothing, which is the honest answer to
## having no measurement and the one that makes a caller's arithmetic obviously
## wrong rather than quietly wrong.
func drive() -> AABB:
	var slab: VisualInstance3D = get_node_or_null(concrete) as VisualInstance3D
	if slab == null:
		return AABB()
	return slab.global_transform * slab.get_aabb()


## Every mesh the ground is made of, merged into one box in world space: the
## drive, the lawn and the banks together.
##
## What the fences are read off. The camera circles inside it, the walk stays
## inside it, and a held tool's corners stay inside it — see
## [code]tests/integration/test_garage.gd[/code] and its neighbours, which used
## to read the same number off the right-hand grass box's scale.
func extent() -> AABB:
	var pieces: Array[AABB] = []
	_gather(self, pieces)
	if pieces.is_empty():
		return AABB()
	var whole: AABB = pieces[0]
	for piece: AABB in pieces:
		whole = whole.merge(piece)
	return whole


## Adds the world-space box of every [VisualInstance3D] under [param branch] to
## [param into], depth first.
func _gather(branch: Node, into: Array[AABB]) -> void:
	for child: Node in branch.get_children():
		var visual: VisualInstance3D = child as VisualInstance3D
		if visual != null:
			into.append(visual.global_transform * visual.get_aabb())
		_gather(child, into)

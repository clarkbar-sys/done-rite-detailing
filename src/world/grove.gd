## The trees around the edge of the lawn: a brown cylinder with a pile of green
## spheres on top of it, fourteen of them, in the same places every time the
## level loads.
##
## [b]It is the ground's argument, one step further.[/b] The driveway and the
## grass are unit boxes scaled into place because the shapes and their sizes are
## the design decision and none of it should be waiting on an artist — see
## [code]src/world/garage.gd[/code]. A tree is the same bet with one extra move:
## the primitives are rolled from a seed rather than typed into a scene file, so
## eight trees are eight different trees instead of one tree instanced eight
## times. What each roll produces is [TreeShape]; where they stand is
## [GrovePlan]; this is the part that turns both into nodes.
##
## [b]Fixed seeds, so the driveway is a place.[/b] [constant TreeShape.SEEDS] is
## seven frozen numbers and [constant ROW_SEEDS] is six more, which is the
## difference between a level that is generated and a level that is [i]built[/i]:
## a player closing the tab and coming back finds the same tree by the same
## corner, and a screenshot still matches the game. Nothing here calls
## [method Object.new] on a clock or on [method randi].
##
## [b]Six rows, which is the boundary of the grass with the driveway left out.[/b]
## The lawn is two strips either side of the drive, so what a fence would follow
## is each strip's long outer side and the two short ends that close it — the
## fourth side is the tarmac the car is parked on, and a tree there would be a
## tree in the middle of the job. [constant TreeShape.SEEDS] wraps across the
## fourteen, so every shape is planted exactly twice and the turn [GrovePlan]
## gives each one is what keeps the pair from reading as a copy.
##
## [b]They are drawn and nothing else.[/b] Every mesh here is a plain
## [MeshInstance3D] with no collider, deliberately: the room casts rays for the
## camera's standoff and for the aim mark, and both of them are asking a question
## about the [Car]. A tree with a body would let a finger on the horizon mark a
## trunk, and would give the walk something to hug that is not the paint.
##
## [b]And the camera cannot get into them.[/b] [member keep_clear] is the disc in
## the middle of the driveway no tree may stand in: the circle the title screen
## sweeps ([member Garage.orbit_radius], which is also the furthest the walk's
## standoff may ever stand off the car), plus [constant TreeShape.MAX_REACH] for
## the crown, plus [constant MARGIN]. The sum is done against the garage's own
## numbers in [code]tests/integration/test_grove.gd[/code] rather than written
## down here as one that could quietly stop being true.
##
## [i]Which is the number the lawn is sized around.[/i] The grass runs out to
## 7.8 m so that a row down [member edge_x] clears that disc along its whole
## length and can be planted end to end — an earlier, narrower lawn put the
## forbidden middle across most of both long sides and left the trees huddled at
## the corners. The short ends still cross it, at the corner nearest the car, and
## there the row simply starts further out: [GrovePlan] takes the hole out of
## whatever run it is given, so neither case is special-cased here.
##
## [b]The look lives in the scene file.[/b] The two meshes and the shades of bark
## and leaf are [code]@export[/code]s carried by
## [code]src/world/grove.tscn[/code], the way the car's paint is carried by
## [code]tests/fixtures/blockout_car.tscn[/code] — so the wood can be recoloured, or the
## spheres given more segments, without opening a script.
class_name Grove
extends Node3D

## What each tree's trunk child is called, so a test can reach the bark rather
## than counting children.
const TRUNK: String = "Trunk"

## A spacing seed per row, in planting order: the two long sides, then the four
## ends. Six numbers rather than one, because a single seed would deal every row
## the same wobble and the lawn would come out mirrored about both axes — which
## is exactly the regularity the wobble exists to break.
const ROW_SEEDS: Array[int] = [2029, 4177, 5261, 6301, 7333, 8419]

## The two directions everything out here comes in pairs of: -1 is the left of
## the drive or the near end of the lawn, +1 the right or the far end.
const SIDES: Array[int] = [-1, 1]

## How far short of the corner an end row stops, in metres, so that the last tree
## down a long side and the outermost tree across an end are not planted in each
## other. Measured rather than picked: at 1.2 the closest a pair from two
## different rows can come is 1.3 m, and a crown reaches 1.0.
const CORNER_GAP: float = 1.2

## How much clear air is kept between the camera's own circle and the nearest
## leaf, in metres, on top of the crown's reach.
##
## Six tenths, and the number comes from the hand rather than from taste: the
## longest thing the player holds finishes half a metre in front of the lens (see
## [code]src/world/garage.gd[/code] on why the viewmodel has no camera of its
## own), so at this margin even a wand pointed straight out of the frame cannot
## push into a tree. The lens itself is a good deal further off than that,
## because the camera looks inward at the car and the tree it passes closest to
## is always the one behind it.
const MARGIN: float = 0.6

## The unit trunk: a cylinder 1 m tall standing on the origin, 1 m across at the
## base. Scaled per tree, so one mesh serves the whole wood.
@export var trunk_mesh: Mesh

## The unit leaf blob: a sphere of radius 1 on the origin, scaled per sphere.
## Few enough segments to read as blocked-out rather than as a ball bearing.
@export var leaf_mesh: Mesh

## The shades of bark, dealt one per tree. More than one because a row of
## identical trunks is the thing rolling the shapes was meant to avoid.
@export var bark: Array[StandardMaterial3D] = []

## The shades of leaf, dealt one per sphere — so a single crown carries two or
## three greens and reads as depth rather than as a solid lump.
@export var leaves: Array[StandardMaterial3D] = []

## How many trees go down each long side of the lawn. Five over 12.8 m is a tree
## every two and a half metres, which is boundary planting rather than a hedge:
## the crowns are two metres across, so they read as separate trees with grass
## between them.
@export var trees_per_edge: int = 5

## How many trees go across each short end of the lawn. One, because the disc
## the camera sweeps eats the half of that run nearest the drive and what is
## left is under three metres of it.
@export var trees_per_end: int = 1

## How far out from the middle of the driveway each long row stands, in metres.
## Just inside the outer edge of the grass, so a trunk is on the lawn and the
## crown overhangs the edge of the modeled ground rather than floating over it.
@export var edge_x: float = 7.5

## How far down the lawn a tree may stand, in metres either way — where the long
## rows stop, and the line the two end rows are planted along. Slightly inside
## the ends of the grass, for the same reason as [member edge_x].
@export var z_limit: float = 6.4

## Where an end row starts, in metres out from the middle of the driveway: just
## clear of the tarmac. How much of it is actually planted is another matter —
## the corner nearest the car is inside [member keep_clear], and [GrovePlan]
## takes that out.
@export var inner_x: float = 2.6

## The disc in the middle of the driveway no trunk may stand in, as a radius in
## metres from the car. See the class docs: 5.6 of camera, 1.0 of crown and
## [constant MARGIN] of air, and a test does that sum against the room rather
## than trusting the 7.2 written here.
@export var keep_clear: float = 7.2


func _ready() -> void:
	plant()


## Stands the whole wood up: the six rows, the shapes, the meshes.
##
## Public and separate from [method _ready] so a test can replant after changing
## a count or an edge, which is the only way to check a layout rule holds for
## more than the one arrangement that ships.
func plant() -> void:
	for grown: Node in get_children():
		remove_child(grown)
		grown.queue_free()
	var variants: Array[TreeShape] = TreeShape.variants()
	if variants.is_empty():
		return
	var stands: Array[Transform3D] = []
	var row: int = 0
	for side: int in SIDES:
		stands.append_array(_down_the_side(side, row))
		row += 1
	for side: int in SIDES:
		for end: int in SIDES:
			stands.append_array(_across_the_end(side, end, row))
			row += 1
	for tree: int in stands.size():
		_raise(variants[tree % variants.size()], stands[tree], tree)


## Every tree in the wood, in the order they were planted — both long sides
## first, then the four ends.
func trees() -> Array[Node3D]:
	var standing: Array[Node3D] = []
	for grown: Node in get_children():
		var tree: Node3D = grown as Node3D
		if tree != null:
			standing.append(tree)
	return standing


## The long row down one side of the drive: [param side] is -1 for the left-hand
## strip of grass and +1 for the right.
func _down_the_side(side: int, row: int) -> Array[Transform3D]:
	return GrovePlan.down_the_edge(
		float(side) * edge_x, z_limit, trees_per_edge, keep_clear, ROW_SEEDS[row]
	)


## The short row across one end of one strip of grass, running out from the
## tarmac toward the corner and stopping [constant CORNER_GAP] short of it.
func _across_the_end(side: int, end: int, row: int) -> Array[Transform3D]:
	var across: float = float(end) * z_limit
	return GrovePlan.along(
		Vector3(float(side) * inner_x, 0.0, across),
		Vector3(float(side) * (edge_x - CORNER_GAP), 0.0, across),
		trees_per_end,
		keep_clear,
		ROW_SEEDS[row]
	)


## One tree: the trunk, then a [MeshInstance3D] per sphere of the crown.
##
## [param index] only picks the shades. It is deliberately not part of the shape
## — two trees planted from the same seed are the same tree, and the thing that
## keeps them from looking like it is the turn [GrovePlan] gave each of them.
func _raise(shape: TreeShape, stand: Transform3D, index: int) -> void:
	var tree: Node3D = Node3D.new()
	tree.name = "Tree%d" % index
	tree.transform = stand
	var trunk: MeshInstance3D = MeshInstance3D.new()
	trunk.name = TRUNK
	trunk.mesh = trunk_mesh
	trunk.material_override = _shade(bark, index)
	trunk.position = Vector3(0.0, shape.trunk_height * 0.5, 0.0)
	trunk.scale = Vector3(shape.trunk_radius, shape.trunk_height, shape.trunk_radius)
	tree.add_child(trunk)
	for blob: int in shape.crown.size():
		var sphere: Vector4 = shape.crown[blob]
		var leaf: MeshInstance3D = MeshInstance3D.new()
		leaf.name = "Leaf%d" % blob
		leaf.mesh = leaf_mesh
		leaf.material_override = _shade(leaves, index + blob)
		leaf.position = Vector3(sphere.x, sphere.y, sphere.z)
		leaf.scale = Vector3.ONE * sphere.w
		tree.add_child(leaf)
	add_child(tree)


## The [param of]th shade out of [param shades], wrapping — and nothing at all
## when the scene has not been given any, which draws the default grey instead of
## dividing by zero.
func _shade(shades: Array[StandardMaterial3D], of: int) -> StandardMaterial3D:
	if shades.is_empty():
		return null
	return shades[of % shades.size()]

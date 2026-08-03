## The trees along the edge of the lawn: a brown cylinder with a pile of green
## spheres on top of it, seven of them, in the same places every time the level
## loads.
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
## seven frozen numbers and [constant PLAN_LEFT] / [constant PLAN_RIGHT] are two
## more, which is the difference between a level that is generated and a level
## that is [i]built[/i]: a player closing the tab and coming back finds the same
## tree by the same corner, and a screenshot still matches the game. Nothing here
## calls [method Object.new] on a clock or on [method randi].
##
## [b]Two rows, one for each strip of grass[/b], because the lawn is two strips
## with a driveway down the middle. The count is split between them with the odd
## tree going left, so the default seven is four and three rather than a
## symmetry the eye would catch.
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
## [i]That leaves the lawn with a hole in the middle of it[/i], which is why the
## rows come out as a pair of trees at each corner rather than an even line —
## [GrovePlan] deals them into the two stretches that are left. It is also the
## thing to notice first if the driveway is ever made bigger: widen the grass and
## the same rule spreads the same trees out.
##
## [b]The look lives in the scene file.[/b] The two meshes and the shades of bark
## and leaf are [code]@export[/code]s carried by
## [code]src/world/grove.tscn[/code], the way the car's paint is carried by
## [code]src/world/car.tscn[/code] — so the wood can be recoloured, or the
## spheres given more segments, without opening a script.
class_name Grove
extends Node3D

## What each tree's trunk child is called, so a test can reach the bark rather
## than counting children.
const TRUNK: String = "Trunk"

## The seed the left-hand row's spacing is dealt from, and the right-hand row's.
## Two numbers rather than one, because a single seed would deal both rows the
## same wobble and the two sides would mirror each other down the drive.
const PLAN_LEFT: int = 2029

## See [constant PLAN_LEFT].
const PLAN_RIGHT: int = 4177

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

## How many trees to plant. Seven by default, which is one of each of
## [constant TreeShape.SEEDS]; ask for more and the shapes start repeating.
@export var count: int = 7

## How far out from the middle of the driveway each row stands, in metres. Just
## inside the outer edge of the grass, so a trunk is on the lawn and the crown
## overhangs the edge of the modeled ground rather than floating over it.
@export var edge_x: float = 5.9

## How far down the lawn a tree may stand, in metres either way. Slightly inside
## the ends of the grass, for the same reason as [member edge_x].
@export var z_limit: float = 6.4

## The disc in the middle of the driveway no trunk may stand in, as a radius in
## metres from the car. See the class docs: 5.6 of camera, 1.0 of crown and
## [constant MARGIN] of air, and a test does that sum against the room rather
## than trusting the 7.2 written here.
@export var keep_clear: float = 7.2


func _ready() -> void:
	plant()


## Stands the whole wood up: the rows, the shapes, the meshes.
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
	var left: int = (count + 1) / 2
	var stands: Array[Transform3D] = GrovePlan.down_the_edge(
		-edge_x, z_limit, left, keep_clear, PLAN_LEFT
	)
	stands.append_array(
		GrovePlan.down_the_edge(edge_x, z_limit, count - left, keep_clear, PLAN_RIGHT)
	)
	for tree: int in stands.size():
		_raise(variants[tree % variants.size()], stands[tree], tree)


## Every tree in the wood, in the order they were planted — the left-hand row
## first, then the right.
func trees() -> Array[Node3D]:
	var standing: Array[Node3D] = []
	for grown: Node in get_children():
		var tree: Node3D = grown as Node3D
		if tree != null:
			standing.append(tree)
	return standing


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

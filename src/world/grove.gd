## The trees around the driveway: a brown cylinder with a pile of green spheres
## on top of it, nine of them, in the same places every time the level loads.
##
## [b]It is the wood the blockout carried, replanted on the modeled ground.[/b]
## There were fourteen of these standing around a lawn made of two scaled boxes
## until #114 swapped the boxes for a real mesh. They could not be kept where
## they stood — the old lawn ran to 7.8 m and the model reaches 6.30, and they
## were planted at [code]y = 0[/code] on grass that now rises to 1.17 m — so
## #152 took them out and said the arithmetic was in the history. This is that
## arithmetic, redone against the ground that is actually there. What each roll
## produces is [TreeShape]; where they stand is [GrovePlan]; how high the grass
## is under each one is [method Ground.settle]; this is the part that turns all
## three into nodes.
##
## [b]Fixed seeds, so the driveway is a place.[/b] [constant TreeShape.SEEDS] is
## seven frozen numbers and [constant ROW_SEEDS] is three more, which is the
## difference between a level that is generated and a level that is [i]built[/i]:
## a player closing the tab and coming back finds the same tree by the same
## corner, and a screenshot still matches the game. Nothing here calls
## [method Object.new] on a clock or on [method randi].
##
## [b]Three rows, because the lawn has three sides.[/b] The model is a sunken pad
## with grass wrapping it on three sides and the fourth left open — that fourth
## is the end the car drives in from, and it is open in the mesh itself, which is
## what makes the place read as a driveway rather than as a walled yard. So
## there is a row down each long bank and one across the lawn at the closed end,
## and the mouth is left the way the artist left it. Planting it shut would be
## the one change here a player would actually notice as wrong.
##
## [b]The middle of each long row is bare, and that is the model's size.[/b] The
## camera sweeps a 5.6 m disc and the banks stand 5.8 m out, so the whole middle
## of both sides is inside the circle the eye travels on — see [member
## keep_clear]. [GrovePlan] takes that hole out of whatever run it is given, so
## each side comes out as a tree near either corner and clear grass between them,
## and the back row — nine metres out, past the disc entirely — gets planted end
## to end. Nothing here special-cases either case.
##
## [i]Which is why there are nine and not fourteen.[/i] The old count was what
## the old lawn had room for. This is what this one has, and the honest way to
## get the other number back is a bigger model rather than a tree beside the car.
##
## [b]They are drawn and nothing else.[/b] Every mesh here is a plain
## [MeshInstance3D] with no collider, deliberately: the room casts rays for the
## camera's standoff and for the aim mark, and both of them are asking a question
## about the [Car]. A tree with a body would let a finger on the horizon mark a
## trunk, and would give the walk something to hug that is not the paint. It is
## the same promise [Ground] is held to, and [code]tests/integration/[/code] has
## a test apiece saying so.
##
## [b]It stands beside the ground and not under it.[/b] [method Ground.extent] is
## the fence five test files read the room's size off, and it is the merged box
## of every mesh below whatever node it is called on — so a wood parented into
## the ground would quietly add its crowns to the room's own extent and move a
## fence nobody meant to move. The grove is therefore a sibling in
## [code]src/world/garage.tscn[/code] and finds the ground by an exported path,
## the same way [Ground] finds its own concrete.
##
## [b]The look lives in the scene file.[/b] The two meshes and the shades of bark
## and leaf are [code]@export[/code]s carried by
## [code]src/world/grove.tscn[/code], the way the car's paint is carried by
## [code]tests/fixtures/blockout_car.tscn[/code] — so the wood can be recoloured,
## or the spheres given more segments, without opening a script.
class_name Grove
extends Node3D

## What each tree's trunk child is called, so a test can reach the bark rather
## than counting children.
const TRUNK: String = "Trunk"

## A spacing seed per row, in planting order: the two long sides, then the back.
## Three numbers rather than one, because a single seed would deal every row the
## same wobble and the two sides would come out mirror images of each other —
## which is exactly the regularity the wobble exists to break.
const ROW_SEEDS: Array[int] = [2029, 4177, 5261]

## The two directions the long sides come in: -1 is the bank left of the drive,
## +1 the bank right of it.
const SIDES: Array[int] = [-1, 1]

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

## The ground the trees are stood on, which is asked how high the grass is under
## each one ([method Ground.settle]).
##
## An [code]@export[/code] and not a [code]%Ground[/code] lookup because this is
## a scene of its own: a unique name resolves against the scene that owns the
## node asking, and the node asking here is owned by [code]grove.tscn[/code]
## rather than by the room. The path is written in
## [code]src/world/garage.tscn[/code], where both nodes are visible at once.
@export var ground: NodePath

## How many trees go down each long bank. Two, one either side of the hole the
## camera's disc eats out of the middle — see the class docs. The stretch left at
## each end is under three metres and a crown is two across, so a second tree in
## either of them would be planted in the first one.
@export var trees_per_side: int = 2

## How many trees go across the lawn at the closed end. Five over ten metres is
## a tree every two metres, which is boundary planting rather than a hedge: the
## crowns are two metres across, so they just touch and read as a tree line with
## daylight through it.
@export var trees_across_back: int = 5

## How far out from the middle of the drive each long row stands, in metres.
##
## Measured off the model: the bank climbs out of the kerb at about 3.8 m and
## crests between 5.2 and 6.0 depending where along it you stand, and the mesh
## ends at 6.30. At 5.8 the trunk is on the crest and the crown overhangs the
## outer edge rather than floating past it, which is where a boundary tree
## actually stands.
@export var side_x: float = 5.8

## How far down the drive a long row runs, in metres — from [member back_z]'s
## lawn at the closed end to just short of the open mouth.
##
## Not symmetric, because the ground is not: the mesh runs from 7.13 m at the
## mouth to 10.47 at the closed end, so the near stop is the model's own edge
## less a crown and the far stop is where the back lawn starts and the back row
## takes over.
@export var side_z: Vector2 = Vector2(-7.2, 6.4)

## How far down the drive the back row stands, in metres — out on the lawn that
## closes the far end, past the apron the drive runs out onto at -7.5.
@export var back_z: float = -9.2

## How far the back row reaches either side of the middle, in metres. Stopping
## short of [member side_x] so the tree at each end of it and the tree at the
## bottom of each long row are not planted in each other.
@export var back_x: float = 5.0

## The disc in the middle of the driveway no trunk may stand in, as a radius in
## metres from the car: 5.6 of camera, 1.0 of crown and [constant MARGIN] of air.
## A test does that sum against the room's own orbit rather than trusting the 7.2
## written here.
@export var keep_clear: float = 7.2


func _ready() -> void:
	plant()


## Stands the whole wood up: the three rows, the shapes, the ground under them,
## the meshes.
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
	for side: int in SIDES:
		stands.append_array(_down_the_side(side))
	stands.append_array(_across_the_back())
	# The ground is asked once for the whole wood rather than once per tree: it
	# has no collider to query, so every answer costs a walk of the mesh and the
	# walk is the same walk. Ground.settle() has the measurement.
	var spots: PackedVector3Array = PackedVector3Array()
	for stand: Transform3D in stands:
		spots.append(stand.origin)
	var grass: PackedFloat32Array = _settle(spots)
	for tree: int in stands.size():
		# A tree with no ground under it is not planted at all. The lawn's outer
		# edge is a hard edge with sky past it and the mouth of the drive is open,
		# so this is a real answer rather than a defensive one — and a gap in the
		# row is the visible version of a row that has wandered off the model.
		if is_nan(grass[tree]):
			continue
		var stand: Transform3D = stands[tree]
		stand.origin.y = grass[tree]
		_raise(variants[tree % variants.size()], stand, tree)


## Every tree in the wood, in the order they were planted — the two long sides
## first, then the back.
func trees() -> Array[Node3D]:
	var standing: Array[Node3D] = []
	for grown: Node in get_children():
		var tree: Node3D = grown as Node3D
		if tree != null:
			standing.append(tree)
	return standing


## How high the grass is under each of [param spots], or NAN throughout when
## [member ground] names nothing.
##
## A wood with no ground to stand on plants no trees, which is the same answer
## [Ground] gives a caller that asks a scene with no concrete in it where the
## floor is: an empty measurement rather than a plausible wrong one. It is worth
## a branch of its own because the alternative — building a spare [Ground] to ask
## — would be a [Node] nobody ever frees.
func _settle(spots: PackedVector3Array) -> PackedFloat32Array:
	var lawn: Ground = get_node_or_null(ground) as Ground
	if lawn != null:
		return lawn.settle(spots)
	var nothing: PackedFloat32Array = PackedFloat32Array()
	nothing.resize(spots.size())
	nothing.fill(NAN)
	return nothing


## The long row down one bank: [param side] is -1 for the bank left of the drive
## and +1 for the one right of it.
func _down_the_side(side: int) -> Array[Transform3D]:
	var edge: float = float(side) * side_x
	return GrovePlan.along(
		Vector3(edge, 0.0, side_z.x),
		Vector3(edge, 0.0, side_z.y),
		trees_per_side,
		keep_clear,
		ROW_SEEDS[maxi(side, 0)]
	)


## The row across the lawn that closes the far end of the drive, running the
## width of it rather than down its length — the one row the camera's disc does
## not reach, and so the one that gets planted end to end.
func _across_the_back() -> Array[Transform3D]:
	return GrovePlan.along(
		Vector3(-back_x, 0.0, back_z),
		Vector3(back_x, 0.0, back_z),
		trees_across_back,
		keep_clear,
		ROW_SEEDS[2]
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

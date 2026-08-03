## What the aim looks like: the crosshair on the paint, the water the power wash
## throws at it, and the product the two bottles spray at it. One object, because
## they are one decision.
##
## [b]Why these three are a thing rather than three things.[/b] They are mutually
## exclusive answers to a single question — [i]where is my tool pointed, and what
## is it doing there[/i] — and the rule for choosing between them is a few lines
## that have to be read together. Left in [Garage] they were three fields, three
## constructions, three accessors and a branch, spread through a file whose actual
## subject is a camera and a raycast; and every new tool that draws something would
## have added a fourth of each. Here it is one node with one entry point, and the
## next tool that wants a sight of its own is a change to [method sight] and to
## nothing else.
##
## [b]It draws; it does not decide anything about the game.[/b] What tool is held,
## where the mark is, which way the paint faces and how wide each tool reaches are
## all handed in. Nothing here casts a ray, reads the belt, or touches the grime —
## so a sight that is wrong is wrong about drawing, and the trigger it is drawn
## alongside ([method Garage._spend_the_trigger]) keeps working when it is.
##
## [b]A [Node3D] rather than a [RefCounted][/b], because two of its three parts are
## particle emitters and the third is a mesh, all of which have to be in the tree
## to be anything at all. Its own transform is never touched: the children are
## placed in world coordinates by the calls below, and this node is a place to keep
## them together rather than a frame to read them in.
##
## [b]A sibling of the car, not a child of it[/b] — the same placement [AimMarker]
## has always had, for the same reason: it is UI that happens to be drawn in world
## space, and hanging it inside the car would put it in the way of everything that
## walks the car's children looking for panels ([method Car.panels]).
class_name ToolSight
extends Node3D

## What the three children are called, so a test can reach them by name rather
## than by counting.
const CROSSHAIR: String = "AimMarker"
const WATER: String = "WashJet"
const PRODUCT: String = "SprayMist"

var _wash_radius: float
var _scrub_radius: float
var _marker: AimMarker = null
var _jet: WashJet = null
var _mist: SprayMist = null


## Built with how wide each of the two sprays lands: [param wash_radius] for the
## power wash and [param scrub_radius] for the bottles.
##
## Handed in rather than read from anywhere, because they are the room's numbers —
## they are the patches [method Garage._spend_the_trigger] is about to work on, and
## the whole point of drawing them at these sizes is that the picture and the work
## are the same size. A sight that had its own opinion about how wide a jet is
## would be a second answer to that.
func _init(wash_radius: float, scrub_radius: float) -> void:
	_wash_radius = wash_radius
	_scrub_radius = scrub_radius


func _ready() -> void:
	_marker = AimMarker.new()
	_marker.name = CROSSHAIR
	add_child(_marker)
	_jet = WashJet.new()
	_jet.name = WATER
	add_child(_jet)
	_mist = SprayMist.new()
	_mist.name = PRODUCT
	add_child(_mist)


## The crosshair on the paint. Public because where the aim landed is a fact the
## rest of the game reads — the panel readout, the wand's alignment, every test
## that asks where the mark actually went — and it goes on being made whichever
## sight is showing.
func marker() -> AimMarker:
	return _marker


## The power wash's water.
func wash_jet() -> WashJet:
	return _jet


## What the two bottles spray.
func spray_mist() -> SprayMist:
	return _mist


## Draws the aim: a mark at [param surface] on a panel facing [param outward],
## with [param held] in the player's hands and [param nozzle] its business end —
## or [code]null[/code] for a tool that has none.
##
## [b]The mark is made first and always[/b], whichever sight is showing. It is what
## the panel readout names, what the wand lines itself up with, and what the trigger
## spends water on, so everything below only decides what is drawn on top of it.
##
## [b]The water and the product both leave the nozzle rather than the eye.[/b] The
## tool has already been aimed or carried into place by the time this runs
## ([WandCarry], [ReachCarry]), so emitting from the thing the player can see
## emitting is both the honest picture and the one that converges on the mark while
## the tool is still moving. It matters most for the bottles, which are hovering a
## few inches off the panel: product appearing anywhere but at the can would read
## as coming from nowhere.
##
## [b]One nozzle argument for two effects[/b], because the tool in hand can only be
## one of them. A caller that had to work out which end belonged to which effect
## would be making this decision a second time, somewhere it could disagree.
##
## [b]The crosshair comes off for the water and stays on for the product.[/b] A red
## disc under a patch of water is a second answer to a question the jet has already
## answered better; a can hovering over the paint is answering a different question
## and leaves "exactly which spot" to the ring.
##
## [param debug] takes both effects away and leaves the bare crosshair under every
## tool — see [member Garage.debug_tools], which is where that switch lives and
## what it is for.
func sight(
	surface: Vector3, outward: Vector3, held: DetailingTool.Id, nozzle: Marker3D, debug: bool
) -> void:
	_marker.mark(surface, outward)
	var washing: bool = not debug and held == DetailingTool.Id.POWER_WASH
	_marker.draw_crosshair(not washing)
	if washing and nozzle != null:
		_jet.spray(nozzle.global_position, surface, _wash_radius)
	else:
		_jet.stow()
	# The power wash is excluded by name and everything else by not having a nozzle
	# — so the day another tool grows one, it sprays without this line being touched.
	if debug or nozzle == null or held == DetailingTool.Id.POWER_WASH:
		_mist.stow()
	else:
		_mist.spray(nozzle.global_position, surface, _scrub_radius, Surface.product_from(held))


## Takes the finger off both effects, and leaves the mark alone.
##
## Two halves of a release that happen at different times: the water and the mist
## stop the instant the finger lifts, whether or not the panel under it changed,
## while the crosshair comes off through [method AimMarker.unmark] only once the
## room has noticed there is nothing marked any more.
##
## Stopping rather than hiding, in both cases: whatever is already in the air
## finishes its flight and lands, which is the one thing about letting go that a
## solid cone of geometry got wrong for free.
func hold_fire() -> void:
	_jet.stow()
	_mist.stow()

## What the aim looks like: the water the power wash throws at the spot, the product
## the two bottles spray at it, the suds the sponge squeezes out around itself, and
## the crosshair that all three replaced. One object, because they are one decision.
##
## [b]Why these four are a thing rather than four things.[/b] They are mutually
## exclusive answers to a single question — [i]where is my tool pointed, and what
## is it doing there[/i] — and the rule for choosing between them is a few lines
## that have to be read together. Left in [Garage] they were three fields, three
## constructions, three accessors and a branch, spread through a file whose actual
## subject is a camera and a raycast; and every new tool that draws something would
## have added a fourth of each. That prediction has since been collected on: the
## sponge's foam is the fourth, and adding it was a change to [method sight] and
## to nothing else.
##
## [b]It draws; it does not decide anything about the game.[/b] What tool is held,
## where the mark is, which way the paint faces and how wide each tool reaches are
## all handed in. Nothing here casts a ray, reads the belt, or touches the grime —
## so a sight that is wrong is wrong about drawing, and the trigger it is drawn
## alongside ([method Garage._spend_the_trigger]) keeps working when it is.
##
## [b]A [Node3D] rather than a [RefCounted][/b], because three of its four parts
## are particle emitters and the fourth is a mesh, all of which have to be in the
## tree to be anything at all. Its own transform is never touched: the children are
## placed in world coordinates by the calls below, and this node is a place to keep
## them together rather than a frame to read them in.
##
## [b]A sibling of the car, not a child of it[/b] — the same placement [AimMarker]
## has always had, for the same reason: it is UI that happens to be drawn in world
## space, and hanging it inside the car would put it in the way of everything that
## walks the car's children looking for panels ([method Car.panels]).
class_name ToolSight
extends Node3D

## What the four children are called, so a test can reach them by name rather
## than by counting.
const CROSSHAIR: String = "AimMarker"
const WATER: String = "WashJet"
const PRODUCT: String = "SprayMist"
const FOAM: String = "SpongeSuds"

var _wash_radius: float
var _scrub_radius: float
var _marker: AimMarker = null
var _jet: WashJet = null
var _mist: SprayMist = null
var _suds: SpongeSuds = null


## Built with how wide each tool lands: [param wash_radius] for the power wash and
## [param scrub_radius] for the three cleaners — the two bottles spray it and the
## sponge's foam creeps out to it.
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
	_suds = SpongeSuds.new()
	_suds.name = FOAM
	add_child(_suds)


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


## What the sponge squeezes out.
func sponge_suds() -> SpongeSuds:
	return _suds


## Draws the aim: a mark at [param surface] on a panel facing [param outward],
## with [param held] in the player's hands and [param nozzle] its business end —
## or [code]null[/code] for a tool that has none.
##
## [b]The whole tool rather than its id[/b], because the sponge's foam is drawn
## around the sponge: the ring it comes out on is the rim of
## [member DetailingTool.extent], which is the same "the picture is the size of the
## thing" the two radii above are for. Handing in the id and reaching back into
## [method DetailingTool.catalogue] for the size would be a second copy of which
## tool is held, in the one place it could disagree with the first.
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
## [b]The crosshair is not drawn during play at all.[/b] It answers "where is my
## tool pointed", and it was the only answer in the game when it was written. It is
## no longer any of them: the wash throws water at the spot, the two bottles hover
## over it and spray product at it, and the sponge and the rag are put down on it —
## with the sponge's foam creeping out around itself, and the ring sitting mostly
## underneath the sponge in any case. Every tool now shows the player where it is
## working by working there, so a red disc under one of them is a fifth answer
## nobody needs.
##
## What comes off is the drawing and not the aim. [method AimMarker.mark] is called
## first and always, above, and [method AimMarker.marked_point] goes on answering
## for the panel readout, the wand's alignment, [ReachCarry] and the trigger — the
## two are separate calls precisely so this can be a change to what is drawn and to
## nothing else.
##
## [param debug] takes all three effects away and puts the bare crosshair back under
## every tool — see [member Garage.debug_tools], which is where that switch lives
## and what it is for. It is now the only way to see the ring, which is most of what
## makes it worth having: where the aim resolved with nothing drawn on top is the
## question worth asking when an effect and the mud disagree.
func sight(
	surface: Vector3, outward: Vector3, held: DetailingTool, nozzle: Marker3D, debug: bool
) -> void:
	_marker.mark(surface, outward)
	_marker.draw_crosshair(debug)
	var washing: bool = not debug and held.id == DetailingTool.Id.POWER_WASH
	if washing and nozzle != null:
		_jet.spray(nozzle.global_position, surface, _wash_radius)
	else:
		_jet.stow()
	# The power wash is excluded by name and everything else by not having a nozzle
	# — so the day another tool grows one, it sprays without this line being touched.
	if debug or nozzle == null or held.id == DetailingTool.Id.POWER_WASH:
		_mist.stow()
	else:
		_mist.spray(nozzle.global_position, surface, _scrub_radius, Surface.product_from(held.id))
	# The sponge by name, and not "the tools with no nozzle": the rag has none
	# either and buffs a dry panel, which is the one job on the belt that must not
	# put anything back on the paint.
	if debug or held.id != DetailingTool.Id.SPONGE:
		_suds.stow()
	else:
		_suds.squeeze(
			surface, outward, _footprint(held), _scrub_radius, Surface.product_from(held.id)
		)


## Takes the finger off all three effects, and leaves the mark alone.
##
## Two halves of a release that happen at different times: the water, the mist and
## the foam stop the instant the finger lifts, whether or not the panel under it
## changed, while the crosshair comes off through [method AimMarker.unmark] only
## once the room has noticed there is nothing marked any more.
##
## Stopping rather than hiding, in every case: whatever is already in the air
## finishes its flight and lands, which is the one thing about letting go that a
## solid cone of geometry got wrong for free.
func hold_fire() -> void:
	_jet.stow()
	_mist.stow()
	_suds.stow()


## How wide [param tool] lies on the paint, as a radius in metres — the ring the
## foam is squeezed out on.
##
## The mean of the two half-widths of the face rather than either of them or the
## diagonal between them. A sponge is a stretched box ([method
## DetailingTool.catalogue] says why) and a ring is round, so there is no answer
## that traces its outline exactly: the half-length is a ring the long edges sit
## inside, the half-width is one they poke out of, and the average is the one whose
## foam looks squeezed out from under all four.
##
## [b]Read here rather than stored on the tool[/b], for [method
## ViewModel._carry_for]'s reason: it is arithmetic on extents, done where the
## extents are in scope, by the thing that needs the answer. The catalogue is data
## the roll-up icons read too, and an icon squeezes nothing.
func _footprint(tool: DetailingTool) -> float:
	return (tool.extent.x + tool.extent.z) * 0.25

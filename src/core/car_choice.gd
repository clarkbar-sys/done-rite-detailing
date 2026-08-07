## Which of the ten cars the player asked for, and the names they are offered
## under.
##
## [b]A static class rather than an autoload[/b], for the reason [Sound] is one
## and [BuildInfo] before it: [code]godot --check-only[/code] — what
## [code]make check[/code] gates on — resolves global class names but not
## autoload names, so a call routed through an autoload would silently drop out
## of the type check. And a static field is exactly the shape this needs. Every
## screen is freed the moment the player leaves it (see
## [code]src/main/main.gd[/code]), so the pick has to survive a screen swap with
## nothing left behind to free — which is word for word why the mute flag lives
## the same way.
##
## [b]What it replaces is a line in a scene file.[/b] [code]#142[/code] pinned
## [member MeshCar.style] to the sedan so a playtest got the same car twice, at
## the cost of nine models nobody could reach without opening
## [code]src/world/mesh_car.tscn[/code]. The pin is gone and this is what stands
## in its place: the bay still parks the same car twice in a row, because the
## player said so rather than because a scene file did, and the other nine are a
## press away.
##
## [b]Empty means nobody has been asked yet[/b], which is true exactly once per
## run — the title card is up before any screen has offered a choice. That is
## what [method for_the_next_car] is for, and it is the branch that keeps
## [method MeshCar._ready]'s random draw alive rather than replacing it: a game
## nobody has chosen a car in still gets one of the ten, and the menu then
## remembers whichever one turned up (see
## [code]src/screens/main_menu.gd[/code]). So the first car a player sees is the
## first car they are offered, and every screen after that agrees with the
## arrows.
##
## Node-free, like everything in [code]src/core/[/code] — the list of styles it
## is asked about arrives as an argument rather than being reached for, which is
## also what keeps this file from having to know that [MeshCar] exists.
class_name CarChoice
extends RefCounted

## What each style in the pack is called on screen.
##
## A table rather than [method String.capitalize] because four of the ten come
## out wrong under it: [code]suv[/code] becomes "Suv", [code]offroad[/code]
## becomes "Offroad", and [code]sport[/code] and [code]coupe[/code] are the
## shape of the car rather than its name. The file names are the pack's and are
## not going to change to suit a label, so the translation lives here — which is
## also the one place a second language would ever need to reach.
const NAMES: Dictionary[String, String] = {
	"compact": "Compact",
	"coupe": "Coupe",
	"hatchback": "Hatchback",
	"minivan": "Minivan",
	"offroad": "Off-Roader",
	"pickup": "Pickup",
	"sedan": "Sedan",
	"sport": "Sports Car",
	"suv": "SUV",
	"wagon": "Wagon",
}

## The style the player has asked for, or [code]""[/code] if nobody has asked.
##
## Read through [method for_the_next_car] rather than directly, because the
## empty case has an answer and it is not the empty string.
static var chosen: String = ""


## Remembers [param style] as the car the player wants.
##
## A function and not a bare assignment at the call site for [method Sound.set_muted]'s
## reason: what "choose" means is allowed to grow — the obvious next thing being
## writing it somewhere that survives closing the tab — and every screen that
## sets it is already calling this.
static func choose(style: String) -> void:
	chosen = style


## Puts the choice back to "nobody has been asked", which is where a run starts.
##
## Here for the suites: the pick is process-wide by design, so a test that sets
## one and leaves it would hand it to whichever suite runs next — the same trap
## [code]tests/integration/test_main_menu.gd[/code] already puts
## [member Sound.muted] back for.
static func forget() -> void:
	chosen = ""


## The style the next car should be built as: the player's, or one of
## [param styles] at random if there is no player's yet.
##
## [b]The draw stays a draw.[/b] A game whose first screen is a title card has
## had nobody to ask, and the answer there is the same answer it has always been
## — one of the ten, taken once. What this adds is only that the answer can have
## been decided already.
##
## [b]And the draw sticks, which is the half worth reading twice.[/b] The car in
## the bay is built fresh on every screen — the title card, the menu and the game
## each instance their own [code]src/world/garage.tscn[/code] — so a draw taken
## per car is a car that changes shape as you press Start, in a room
## [code]src/screens/main_menu.gd[/code] describes as "the room it has been
## showing them". Drawing once and remembering it is what makes that sentence
## true, and it costs nothing: this is still one draw from ten, taken once, and
## it is still the first thing the menu offers to change.
static func for_the_next_car(styles: Array[String]) -> String:
	if chosen.is_empty() and not styles.is_empty():
		chosen = str(styles.pick_random())
	return chosen


## The style [param by] places along [param styles] from [param style], wrapping
## at both ends.
##
## [b]It wraps because there are ten of them and no order to speak of.[/b] The
## list is alphabetical — it is the pack's file names — so "the last one" is the
## wagon for no reason a player could learn, and an arrow that greys out at an
## arbitrary end of an arbitrary order is a control that looks broken. Ten is
## also few enough that a full circuit is five presses at worst.
##
## A style that is not in the list starts from the beginning, which is what a
## call with a car nobody recognises should do rather than fail.
static func stepped(style: String, by: int, styles: Array[String]) -> String:
	if styles.is_empty():
		return style
	var at: int = styles.find(style)
	if at < 0:
		return styles[0]
	return styles[posmod(at + by, styles.size())]


## What [param style] is called on screen — see [constant NAMES].
##
## Falls back to [method String.capitalize] for a style with no entry, which is
## a car the pack grew and this table did not. A readable guess beats an empty
## label, and [code]tests/unit/test_car_choice.gd[/code] holds the ten that are
## actually shipped to the table rather than to the fallback.
static func label_for(style: String) -> String:
	if NAMES.has(style):
		return NAMES[style]
	return style.capitalize()

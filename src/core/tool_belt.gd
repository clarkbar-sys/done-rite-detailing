## What the player is carrying, and which one is in their hands.
##
## The belt is the single source of truth for "what am I holding". The roll-up
## asks it to change; the viewmodel listens for the answer. Neither of them
## talks to the other, so either can be replaced — a radial menu, a real pair of
## hands — without the other noticing.
##
## [b]There is no empty-handed state.[/b] You start holding the power wash and
## you always hold something, which means the viewmodel never has to render
## nothing and no caller has to null-check [method equipped]. If bare hands turn
## out to be a real state later — mid-swap, or while climbing — it is a change
## to this class and nowhere else.
##
## A [RefCounted] and not a [Node], and emphatically not an autoload: this is
## the Node-free tier from STANDARDS.md "Coverage" (R3), so every rule below is
## a unit test rather than a running game. Autoload is ruled out project-wide
## anyway — [code]--check-only[/code] does not resolve autoload names, so
## anything reached through one drops straight out of the type gate.
class_name ToolBelt
extends RefCounted

## Emitted when the tool in the player's hands changes, and only then —
## re-equipping what is already held is silent. Listeners can therefore treat
## this as "swap now" rather than having to compare against what they last saw.
signal equipped_changed(tool: DetailingTool)

var _tools: Array[DetailingTool] = []
var _equipped_index: int = 0


func _init() -> void:
	_tools = DetailingTool.catalogue()


## Every tool on the belt, in the order the roll-up draws them and the number
## keys select them.
##
## Returns the belt's own array rather than a copy. GDScript arrays are
## references, so a caller could mutate this — the alternative is a defensive
## duplicate on every UI rebuild to guard against a bug nobody has written yet,
## and the belt is five hardcoded tools, not user data.
func tools() -> Array[DetailingTool]:
	return _tools


## How many tools the belt carries. The roll-up sizes itself from this and the
## number keys stop at it, so neither has to count the enum for itself.
func size() -> int:
	return _tools.size()


## The tool currently in the player's hands. Never null — see the class docs.
func equipped() -> DetailingTool:
	return _tools[_equipped_index]


## Where [method equipped] sits in [method tools], for a roll-up that needs to
## know which of its icons to mark rather than which tool it is.
func equipped_index() -> int:
	return _equipped_index


## Puts [param id] in the player's hands.
##
## Returns whether this changed anything, so a caller can tell "I switched" from
## "you already had that" without listening for the signal it may not receive.
## Both are success — asking for the tool you are holding is not an error, and
## the roll-up closes either way.
##
## An unrecognised id is refused outright and leaves the belt exactly as it was.
## Returning `false` rather than pushing an error: the id comes from a UI button
## or a keypress, and the failure mode that matters is a half-equipped belt, not
## a missing log line.
func equip(id: DetailingTool.Id) -> bool:
	var index: int = index_of(id)
	if index < 0:
		return false
	return equip_at(index)


## Puts the tool at [param index] in the player's hands, by position on the belt
## rather than by identity — what a number key and a roll-up button both
## actually have.
##
## Out of range is refused the same way [method equip] refuses an unknown id:
## `1`–`5` on a four-tool belt is a thing that will happen, and it should do
## nothing rather than wrap around to a tool the player didn't ask for.
func equip_at(index: int) -> bool:
	if index < 0 or index >= _tools.size():
		return false
	if index == _equipped_index:
		return false
	_equipped_index = index
	equipped_changed.emit(equipped())
	return true


## Where [param id] sits on the belt, or `-1` if it isn't on it.
##
## Searched rather than assumed equal to the enum's own value: they happen to
## match today because [method DetailingTool.catalogue] builds them in
## declaration order, and the day someone reorders the belt for feel, this keeps
## telling the truth instead of quietly pointing at the wrong tool.
func index_of(id: DetailingTool.Id) -> int:
	for index: int in _tools.size():
		if _tools[index].id == id:
			return index
	return -1

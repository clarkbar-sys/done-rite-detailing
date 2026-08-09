## Three letters, the way a cabinet asks for them: a wheel of characters, a
## cursor sitting on one of them, and no keyboard required.
##
## [b]Why the entry is a model and not a widget.[/b] What a player is doing at a
## high-score prompt is editing three characters with four verbs — up, down,
## along, back — and every one of those is a rule rather than a picture: the
## wheel wraps at both ends, the cursor wraps at both ends, and a letter the
## alphabet does not have cannot be spelled at all. Those rules are worth a unit
## test and a [Label] is not, so they live here and
## [code]src/screens/job_done.gd[/code] only draws what this says. The same split
## [ToolBelt] makes against [ToolBeltHud], and [CameraOrbit] against [MotionPad].
##
## [b]Thirty-six characters and no blank.[/b] A cabinet's wheel usually ends in a
## space, a rubout and an "END", and all three exist because the hardware had one
## joystick and one button to say four things with. This has buttons, so the
## blank buys nothing and costs the one thing a three-letter table cannot afford:
## [code]"J  "[/code] and [code]"J"[/code] and [code]"J "[/code] are three
## different rows that look like the same player. Every set of initials this
## produces is exactly [constant LENGTH] characters out of [constant ALPHABET],
## which is what makes two of them comparable by looking at them.
##
## [b]It wraps in both directions for the reason the car arrows do[/b] — see
## [method CarChoice.stepped]. There is no natural last letter, so an end that
## stopped would be a control that looks broken; and thirty-six is few enough
## that the long way round is never more than eighteen presses, while the short
## way is never more than eighteen either.
##
## Node-free, like everything in [code]src/core/[/code].
class_name Initials
extends RefCounted

## How many characters a set of initials is. Three, because that is what an
## arcade board has always asked for and because it is the most a player will
## dial in with two buttons before they stop enjoying it.
const LENGTH: int = 3

## Every character the wheel can land on, in the order it turns.
##
## Letters before digits because that is the order a player expects to find them
## in, and because A is where the wheel rests — see [constant FILL]. No
## punctuation, no space: the class docs have why.
const ALPHABET: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

## What an unset character is. The first entry of [constant ALPHABET], which is
## also where the wheel starts, so a player who dials nothing at all still
## submits something spellable rather than a blank.
const FILL: String = "A"

## What a player who has touched nothing hands in: [constant FILL] repeated
## [constant LENGTH] times.
##
## Written out rather than computed because a [code]const[/code] has to be a
## constant expression and [method String.repeat] is a call. The pair is asserted
## against each other in [code]tests/unit/test_initials.gd[/code], so the two
## cannot drift.
const DEFAULT: String = "AAA"

## Nothing in the alphabet, as [method index_of] reports it.
const NOWHERE: int = -1

## Which character of [constant ALPHABET] each of the [constant LENGTH] slots is
## showing, and which slot the cursor is on.
var _letters: PackedInt32Array = PackedInt32Array()
var _at: int = 0


## Starts the wheel on [param spelling], which is put through [method sanitised]
## first — so a saved set of initials, a partial one, or nothing at all are all
## somewhere valid to start from.
##
## The parameter is not called `text` because [method text] is, and GDScript
## treats a parameter shadowing a method in the same class as an error here — the
## same footnote [method Scoring.multiplier_for] carries.
func _init(spelling: String = DEFAULT) -> void:
	var start: String = sanitised(spelling)
	for index: int in LENGTH:
		_letters.append(ALPHABET.find(start[index]))


## [param spelling] as a set of initials: upper-cased, anything the wheel cannot
## spell dropped, then cut or padded to exactly [constant LENGTH] characters.
##
## [b]It is total, and that is the point of it.[/b] Everything that can put a
## name in front of this — a player dialling one in, a save file somebody edited,
## a save file that got mangled — hands over text nobody has checked, and the one
## answer this must never give is a row on the board that is not three characters
## wide. Dropping rather than substituting keeps what the player did mean:
## [code]"Jo-Sh"[/code] is [code]"JOS"[/code], not [code]"JO-"[/code].
##
## Not called `text` for [method _init]'s reason.
static func sanitised(spelling: String) -> String:
	var kept: String = ""
	for character: String in spelling.to_upper():
		if kept.length() >= LENGTH:
			break
		if ALPHABET.contains(character):
			kept += character
	while kept.length() < LENGTH:
		kept += FILL
	return kept


## Where [param character] sits on the wheel, or [constant NOWHERE] for anything
## that is not one single character the wheel has.
##
## The length check is not redundant: [method String.find] would happily match
## [code]"ABC"[/code] at position 0 and report a character that is really three.
static func index_of(character: String) -> int:
	if character.length() != 1:
		return NOWHERE
	return ALPHABET.find(character.to_upper())


## Turns the wheel [param by] places under the cursor, wrapping at both ends.
func step(by: int) -> void:
	_letters[_at] = posmod(_letters[_at] + by, ALPHABET.length())


## Moves the cursor one place along, wrapping back to the first slot from the
## last.
##
## [b]Wrapping is what makes a mistake fixable with the buttons on screen.[/b]
## Three slots and a cursor that stopped at the end would mean a player who got
## the first letter wrong has no way back to it without a fourth control; with
## the wrap, "along" twice more is "back one" and there is nothing to explain.
func advance() -> void:
	_at = posmod(_at + 1, LENGTH)


## Moves the cursor one place back, wrapping to the last slot from the first.
func back() -> void:
	_at = posmod(_at - 1, LENGTH)


## Puts [param character] in the slot under the cursor and moves along, and says
## whether it took.
##
## What a keyboard does, as opposed to what the buttons do: typing a letter is
## "this one, and I am ready for the next" in a single action, which is the whole
## reason somebody reaches for the keys instead of the wheel. Anything the wheel
## cannot spell changes nothing and reports [code]false[/code], so the caller can
## leave the event for whoever else wants it.
func type(character: String) -> bool:
	var found: int = index_of(character)
	if found == NOWHERE:
		return false
	_letters[_at] = found
	advance()
	return true


## Which slot the cursor is on, from zero.
func at() -> int:
	return _at


## The character in slot [param index], or [code]""[/code] for a slot that does
## not exist — which is a caller counting wrong rather than a player doing
## anything, and is worth an empty label instead of a crash.
func letter(index: int) -> String:
	if index < 0 or index >= LENGTH:
		return ""
	return ALPHABET[_letters[index]]


## The three characters as they stand: what goes on the board.
func text() -> String:
	var spelled: String = ""
	for index: int in _letters:
		spelled += ALPHABET[index]
	return spelled

## Print the tutorial-take shot list — the frame size every take is framed for,
## and every take there is with how long it runs.
##
## [b]Why this exists.[/b] [code]scripts/capture-footage.sh[/code] has to know
## three things before it can record anything: how big to open the window, which
## takes to loop over, and how long each one should turn out. All three are
## already stated once, in [constant TutorialFraming.FRAME] and
## [method TutorialTake.catalogue] — and a shell script cannot read a GDScript
## constant. So it asks the game instead of keeping a second copy: the day a
## sixth take lands in the catalogue, [code]make footage[/code] records it
## without anybody remembering to edit a bash array.
##
## [b]Usage[/b] — headless, no rendering context needed, about a second:
## [codeblock]
## .godot-sdk/bin/godot --headless --path . --script res://scripts/shot-list.gd
## [/codeblock]
## Output is tab-separated lines, mixed in with whatever the engine prints on
## boot, so the caller greps for the two prefixes rather than reading stdout
## whole:
## [codeblock]
## frame	720	1280
## take	water	7500
## take	sponge	10500
## [/codeblock]
##
## [b]Milliseconds, not seconds.[/b] The consumer is bash, which has no floating
## point, and the one arithmetic it does with this number is "how many frames
## should that be at 60 fps" — an integer answer from an integer input. Printing
## [code]7.5[/code] and making a shell script parse it would put a decimal point
## in the one place in this pipeline that cannot handle one.
##
## It lives in [code]scripts/[/code] and not [code]src/[/code] for
## [code]pck-top-ten.gd[/code]'s reason: it is not game code, R1 in
## [code]scripts/check-test-map.sh[/code] only walks [code]src/[/code], and it
## has no business being reached by a [code]tests/[/code] script. It is still
## type-checked and linted, because [code]make check[/code] and
## [code]make lint[/code] walk every [code].gd[/code] in the tree.
extends SceneTree

## What a line naming the capture window starts with.
const FRAME_TAG: String = "frame"

## What a line naming one take starts with.
const TAKE_TAG: String = "take"

## Milliseconds in a second — [method TutorialTake.seconds] answers in seconds
## and this prints milliseconds, for the reason the class docs give.
const PER_SECOND: float = 1000.0


func _initialize() -> void:
	print("%s\t%d\t%d" % [FRAME_TAG, TutorialFraming.FRAME.x, TutorialFraming.FRAME.y])
	for take_id: String in TutorialTake.catalogue():
		var take: TutorialTake = TutorialTake.named(take_id)
		if take == null:
			# Unreachable while the catalogue and the table in
			# `TutorialTake.named` agree, which is exactly why it is worth
			# saying out loud: the harness would otherwise record four takes
			# instead of five and exit 0.
			printerr("shot-list: the catalogue names '%s', which named() will not build" % take_id)
			quit(1)
			return
		print("%s\t%s\t%d" % [TAKE_TAG, take_id, roundi(take.seconds() * PER_SECOND)])
	quit(0)

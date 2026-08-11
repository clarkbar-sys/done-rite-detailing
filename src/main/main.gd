## The entry scene: it owns the [GameStateMachine] and is the only thing in the
## project that puts a screen on screen.
##
## Everything it does happens in one direction. A [GameScreen] asks for the next
## [GameState], the machine makes that state current, and this reacts by
## swapping the scene under [code]%ScreenHost[/code] for the one the state
## names. Screens never load or free each other, so adding one is a state, a
## scene, and nothing else.
##
## It also prints the project name and build identity on boot — the line
## `make smoke` and the CI jobs read to confirm the artifact they just built
## really starts.
extends Control

var _states: GameStateMachine = GameStateMachine.new()

@onready var _host: Control = %ScreenHost

## The one thing in the game that makes a noise, and it hangs off the host rather
## than off a screen on purpose: a screen is freed the moment it asks for the
## next state, and a bell rung by the title screen has to still be ringing after
## Start has swapped it away. [Chime] has the whole argument.
@onready var _bell: Chime = %Bell

## The music, hanging off the host for the same reason the [Chime] does and with
## a sharper edge on it: the title screen asks for a three-second fade as it
## hands over, and [method _on_state_changed] frees that screen on the very next
## line. [Bandstand] has the argument.
@onready var _music: Bandstand = %Music


func _ready() -> void:
	var project_name: String = str(ProjectSettings.get_setting("application/config/name"))
	print("%s %s" % [project_name, BuildInfo.describe()])
	# Loaded here, before the title screen — the first of the three screens
	# that read [member Sound.muted] to draw their own toggle — is ever
	# instanced. Routed through [method Sound.set_muted] rather than assigned
	# to [member Sound.muted] directly so the bus is silenced (or not) to match
	# from the very first frame, not just the flag.
	Sound.set_muted(Settings.read_settings(Settings.SETTINGS_PATH)[Settings.KEY_MUTED])
	_states.changed.connect(_on_state_changed)
	_states.enter(_boot_state())


## Which state the game opens in: the title card, or — when the command line asked
## for one — a tutorial take.
##
## [b]The one branch in the boot sequence, and it is on an argument nobody who is
## playing the game will ever pass.[/b] [constant TutorialTake.ARG] after the
## [code]--[/code] names a take ([code]--take=sponge[/code]), which is how the
## capture harness behind [code]#175[/code] says "film the sponge clip and quit".
## Reading it here rather than inside the screen is the same split every other
## screen already lives under: this file is the only thing that decides what is on
## screen, and a screen that chose whether to exist would be the first exception.
##
## [b]A name no take has is a mistake worth failing on.[/b] The alternative — fall
## through to the title screen — would hand the harness a video of a title card and
## a zero exit code, which is the one outcome nobody could debug from the artifact.
## So it is printed, with the catalogue, and the process ends non-zero.
##
## The car is pinned on the way past for [constant TutorialTake.CAR_STYLE]'s reason,
## and through [method CarChoice.choose] because that is the door the menu already
## uses: the bay reads the choice when it parks a car, which is a frame from now.
func _boot_state() -> GameState:
	var asked: String = TutorialTake.asked_for(OS.get_cmdline_user_args())
	if asked.is_empty():
		return TitleScreenGameState.new()
	if TutorialTake.named(asked) == null:
		printerr(
			(
				"no tutorial take called '%s' — try one of: %s"
				% [asked, ", ".join(TutorialTake.catalogue())]
			)
		)
		get_tree().quit(1)
		return TitleScreenGameState.new()
	CarChoice.choose(TutorialTake.CAR_STYLE)
	return TutorialTakeGameState.new()


## Replaces whatever is on screen with the scene [param state] names.
##
## `remove_child` *and* `queue_free`: freeing alone is deferred, so the outgoing
## screen would still be a child — and still drawn over the incoming one — for
## the rest of the frame. Removing it first is also what makes this safe to call
## from the outgoing screen's own signal, which is exactly how every transition
## gets here.
func _on_state_changed(state: GameState) -> void:
	for child: Node in _host.get_children():
		_host.remove_child(child)
		child.queue_free()
	var screen: GameScreen = _screen_for(state)
	if screen == null:
		return
	screen.transition_requested.connect(_states.enter)
	screen.bell_requested.connect(_bell.ring)
	screen.music_requested.connect(_music.start)
	screen.music_stop_requested.connect(_music.fade_out)
	_host.add_child(screen)


## Instantiates [param state]'s scene, or [code]null[/code] if it can't be one.
##
## Both failures are a mis-wired state rather than anything a player can cause,
## so they're loud: `push_error` fails `make smoke`, which is the gate that
## should catch them. The instance is freed on the second one — a failed cast
## still leaves a node with nothing referencing it.
func _screen_for(state: GameState) -> GameScreen:
	var packed: PackedScene = load(state.scene_path) as PackedScene
	if packed == null:
		push_error("state %s: no scene at %s" % [state.id, state.scene_path])
		return null
	var root: Node = packed.instantiate()
	var screen: GameScreen = root as GameScreen
	if screen == null:
		push_error("state %s: %s does not extend GameScreen" % [state.id, state.scene_path])
		root.queue_free()
	return screen

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


func _ready() -> void:
	var project_name: String = str(ProjectSettings.get_setting("application/config/name"))
	print("%s %s" % [project_name, BuildInfo.describe()])
	_states.changed.connect(_on_state_changed)
	_states.enter(TitleScreenGameState.new())


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

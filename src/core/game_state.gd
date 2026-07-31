## One mode the game can be in — what fills the screen, and what the player can
## do while it's there.
##
## A state is plain data: an id and the scene that presents it. It does not load
## that scene, instantiate it or know it's on screen; [code]src/main/main.gd[/code]
## is the only thing that swaps scenes, and [GameStateMachine] is the only thing
## that decides which state is current.
##
## That split is what keeps the whole flow testable without a [SceneTree] — the
## Node-free tier rule from STANDARDS.md "Coverage" (R3) — and it means a new
## state costs one small subclass plus one scene, with nothing to register.
class_name GameState
extends RefCounted

## Stable, human-readable identifier, e.g. [code]"title_screen"[/code]. Used in
## logs and assertions; never shown to the player.
var id: String = ""

## [code]res://[/code] path of the scene this state presents. A path and not a
## [PackedScene] on purpose: loading is the host's job, so constructing a state
## stays free and a unit test can check the wiring without touching the disk.
var scene_path: String = ""


## Subclasses call this with their own constants — see [TitleScreenGameState].
func _init(state_id: String, state_scene_path: String) -> void:
	id = state_id
	scene_path = state_scene_path

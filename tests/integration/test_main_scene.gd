## Integration test for the entry scene.
##
## Lives under tests/integration/ rather than tests/unit/ because it needs a
## real scene tree: `main.gd` fills its labels in `_ready()`, which only runs
## once the node is inside the tree. Nothing here can be asserted by loading a
## script in isolation.
##
## This overlaps `make smoke` on purpose but is not the same gate. Smoke boots
## the whole project and fails on any logged error — it proves the game starts.
## This proves the scene put the right *text* on screen, which a clean boot
## says nothing about.
extends GutTest

const MAIN_SCENE: String = "res://src/main/main.tscn"

var _main: Control = null


func before_each() -> void:
	var packed: PackedScene = load(MAIN_SCENE)
	assert_not_null(packed, "could not load %s" % MAIN_SCENE)
	if packed == null:
		return
	# GUT's helpers are untyped, so their return is a Variant and assigning it
	# straight to `_main` is an `unsafe_cast` error under this project's
	# warning levels. Instantiate into a typed local, then hand that to
	# add_child_autofree — which frees the scene even if a test below fails,
	# so a leak isn't reported against whichever test runs next.
	var instance: Node = packed.instantiate()
	_main = instance as Control
	add_child_autofree(_main)
	# `_ready()` fires synchronously inside add_child, so this frame is only
	# here to let layout settle before the labels are read. Deliberately
	# wait_process_frames and not wait_frames: GUT 9.7.1 still accepts the
	# latter but logs it as deprecated, and a suite that prints deprecation
	# noise on every green run trains people to stop reading the output.
	await wait_process_frames(1)


func test_the_scene_instantiates_as_a_control() -> void:
	assert_not_null(_main, "the entry scene must instantiate")


func test_title_shows_the_project_name() -> void:
	var title: Label = _main.get_node("%Title") as Label
	assert_eq(title.text, str(ProjectSettings.get_setting("application/config/name")))


func test_build_label_shows_the_build_identity() -> void:
	# The on-screen build line and the stdout line CI greps must agree; if this
	# drifts, the "I can see which commit this build is" promise quietly dies.
	var build: Label = _main.get_node("%Build") as Label
	assert_eq(build.text, BuildInfo.describe())

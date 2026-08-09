## Unit tests for [SoundToggle]'s picture: the speaker outline, and the mark
## that says whether the game is muted.
##
## Under tests/unit/ despite [SoundToggle] being a [Button]: what is checked
## here is [method SoundToggle.glyph], a static table of points that needs no
## [SceneTree] to read — the same split
## [code]tests/integration/test_tool_belt_hud.gd[/code] makes for
## [method ToolBeltHud.ToolIcon.sprite]. Whether the picture actually reaches a
## button on screen is [code]tests/integration/test_sound_toggle.gd[/code]'s
## half of the job.
extends GutTest


func test_both_states_draw_something() -> void:
	for muted: bool in [false, true]:
		var paths: Array[PackedVector2Array] = SoundToggle.glyph(muted)
		assert_gt(paths.size(), 0, "muted=%s has no picture at all" % muted)
		for path: PackedVector2Array in paths:
			assert_gt(path.size(), 1, "muted=%s has a stroke with nothing to stroke" % muted)


func test_both_states_stay_on_the_grid() -> void:
	# The bug a stroke table develops silently: a point past the grid draws
	# outside the plate and looks like a rendering glitch rather than a typo.
	for muted: bool in [false, true]:
		for path: PackedVector2Array in SoundToggle.glyph(muted):
			for point: Vector2 in path:
				assert_between(point.x, 0.0, ToolBeltHud.GLYPH_GRID, "muted=%s off grid" % muted)
				assert_between(point.y, 0.0, ToolBeltHud.GLYPH_GRID, "muted=%s off grid" % muted)


func test_the_speaker_itself_is_the_same_shape_in_both_states() -> void:
	# What changes between the two states is what is drawn beside the speaker,
	# not the speaker: the same outline has to read as "a speaker" whichever way
	# the toggle currently faces.
	assert_eq(SoundToggle.glyph(false)[0], SoundToggle.glyph(true)[0])


func test_the_two_states_draw_different_pictures() -> void:
	assert_ne(str(SoundToggle.glyph(false)), str(SoundToggle.glyph(true)))

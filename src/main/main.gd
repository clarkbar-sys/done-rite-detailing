## Day-0 title screen: the smallest thing that proves the engine, the project
## settings, the scene tree and the exported binary all actually work.
##
## It renders the project name and the build identity from [BuildInfo], and the
## same line goes to stdout — which is what `make smoke` and the CI jobs read to
## confirm the artifact they just built really boots.
extends Control

@onready var _title: Label = %Title
@onready var _build: Label = %Build


func _ready() -> void:
	var name_setting: String = str(ProjectSettings.get_setting("application/config/name"))
	_title.text = name_setting
	_build.text = BuildInfo.describe()
	print("%s %s" % [name_setting, BuildInfo.describe()])

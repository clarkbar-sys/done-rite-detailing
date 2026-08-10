## Unit tests for [code]web/build_profile.json[/code] — the list of engine
## features compiled out of the custom web export template.
##
## Under tests/unit/ for the reason [code]test_web_shell.gd[/code] is: the
## thing under test is a file on disk, and every claim below is made by reading
## it. It pairs with no [code]src/[/code] script because it guards the space
## between two things that have no other connection — what the profile turns
## off, and what the game turns out to use.
##
## [b]Why a test and not a comment.[/b] A disabled module is not a compile
## error and not an export error. [code]RegEx.new()[/code] in a build without
## [code]module_regex_enabled[/code] type-checks, exports, publishes, and then
## fails on the line that runs it — in a browser, which nothing in CI opens.
## The profile is therefore only as safe as something that reads it against
## [code]src/[/code], which is what [method test_no_src_script_uses_a_disabled_module]
## does. It is the one gate standing between "we cut 3 MB" and "the settings
## screen is blank on the published link".
##
## What these tests do not do is measure anything. Whether the template is
## smaller is [code]ci-godot.yml[/code]'s bundle budget; whether it still looks
## right is a browser and a judgement, exactly as it is for the loading screen.
extends GutTest

## The profile itself. SCons reads this path through
## [code]scripts/build-web-template.sh[/code]; if it moves, that moves too.
const PROFILE_PATH: String = "res://web/build_profile.json"

## Where the game's own scripts and scenes live. Scanned, rather than the whole
## project, because that is exactly the set that reaches the pack:
## [code]tests/[/code] and [code]addons/gut/[/code] are excluded from both
## presets, and the one [code]RegEx[/code] in this repository is in
## [code]tests/unit/test_patch_flash.gd[/code] — which is why the scan has to
## be this narrow to be honest, and why it must not quietly widen later.
const SCANNED_DIR: String = "res://src"

## Classes each disabled module is what provides. Not exhaustive per module —
## exhaustive in the direction that matters, which is the names a script in
## this project could plausibly reach for. A module with no scriptable class at
## all (the texture compressors, the image-format loaders, meshoptimizer,
## msdfgen) is absent on purpose: there is nothing for a scan to find, and
## listing it with an empty array would suggest otherwise.
const CLASSES_BY_OPTION: Dictionary = {
	"disable_physics_2d":
	[
		"Area2D",
		"CharacterBody2D",
		"CollisionObject2D",
		"CollisionPolygon2D",
		"CollisionShape2D",
		"PhysicsBody2D",
		"PhysicsDirectSpaceState2D",
		"PhysicsServer2D",
		"RayCast2D",
		"RigidBody2D",
		"ShapeCast2D",
		"StaticBody2D",
	],
	"disable_navigation_2d": ["NavigationAgent2D", "NavigationPolygon", "NavigationServer2D"],
	"disable_navigation_3d":
	["NavigationAgent3D", "NavigationMesh", "NavigationRegion3D", "NavigationServer3D"],
	"disable_xr":
	["XRAnchor3D", "XRCamera3D", "XRController3D", "XRInterface", "XROrigin3D", "XRServer"],
	"minizip": ["ZIPPacker", "ZIPReader"],
	"module_camera_enabled": ["CameraFeed", "CameraServer"],
	"module_enet_enabled": ["ENetConnection", "ENetMultiplayerPeer", "ENetPacketPeer"],
	"module_fbx_enabled": ["FBXDocument", "FBXState"],
	"module_gltf_enabled": ["GLTFDocument", "GLTFNode", "GLTFState"],
	"module_gridmap_enabled": ["GridMap"],
	"module_interactive_music_enabled":
	["AudioStreamInteractive", "AudioStreamPlaylist", "AudioStreamSynchronized"],
	"module_jsonrpc_enabled": ["JSONRPC"],
	"module_mbedtls_enabled":
	["Crypto", "CryptoKey", "HMACContext", "StreamPeerTLS", "TLSOptions", "X509Certificate"],
	"module_mobile_vr_enabled": ["MobileVRInterface"],
	"module_mp3_enabled": ["AudioStreamMP3"],
	"module_multiplayer_enabled":
	["MultiplayerSpawner", "MultiplayerSynchronizer", "SceneMultiplayer", "SceneReplicationConfig"],
	"module_regex_enabled": ["RegEx", "RegExMatch"],
	"module_theora_enabled": ["VideoStreamPlayer", "VideoStreamTheora"],
	"module_upnp_enabled": ["UPNP", "UPNPDevice"],
	"module_visual_shader_enabled": ["VisualShader", "VisualShaderNode"],
	"module_vorbis_enabled": ["AudioStreamOggVorbis", "OggPacketSequence"],
	"module_webrtc_enabled": ["WebRTCDataChannel", "WebRTCMultiplayerPeer", "WebRTCPeerConnection"],
	"module_websocket_enabled": ["WebSocketMultiplayerPeer", "WebSocketPeer"],
	"module_webxr_enabled": ["WebXRInterface"],
	"module_zip_enabled": ["ZIPPacker", "ZIPReader"],
}

## The modules the game demonstrably needs, and the class that proves it. This
## is the same scan read backwards, and it is here because the interesting
## mistake is not only "cut something used" — it is "cut something used, and
## have the scan not cover it because nobody added the module to the table
## above". Each entry is asserted to be *absent* from the disabled list, so
## adding [code]module_csg_enabled[/code] to the profile fails here by name.
const MUST_STAY_ENABLED: Dictionary = {
	"module_csg_enabled": "CSGCombiner3D",
	"module_godot_physics_3d_enabled": "PhysicsDirectSpaceState3D",
	"module_noise_enabled": "FastNoiseLite",
}

var _profile: Dictionary = {}
var _disabled: Dictionary = {}
var _sources: Dictionary = {}


func before_all() -> void:
	var text: String = FileAccess.get_file_as_string(PROFILE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_profile = parsed
		var options: Variant = _profile.get("disabled_build_options", {})
		if options is Dictionary:
			_disabled = options
	_collect_sources(SCANNED_DIR)


## Reads every script and scene under [param dir] into [member _sources], keyed
## by path. Recursive, and it follows nothing outside [constant SCANNED_DIR].
##
## Scenes as well as scripts because a node type can enter the game without any
## script naming it — [code]mesh_car.tscn[/code] carries a
## [code]StaticBody3D[/code] that no [code].gd[/code] file mentions, and a
## [code].tscn[/code] stores that type as plain text.
func _collect_sources(dir: String) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		_collect_sources("%s/%s" % [dir, sub])
	for file: String in DirAccess.get_files_at(dir):
		if not (file.ends_with(".gd") or file.ends_with(".tscn")):
			continue
		var path: String = "%s/%s" % [dir, file]
		_sources[path] = FileAccess.get_file_as_string(path)


func test_the_profile_is_a_build_profile_scons_will_read() -> void:
	assert_false(_profile.is_empty(), "%s must parse as a JSON object" % PROFILE_PATH)
	var kind: String = str(_profile.get("type", ""))
	assert_eq(kind, "build_profile", 'SConstruct only honours a file whose "type" is build_profile')
	assert_false(
		_disabled.is_empty(), "%s must disable something to be worth having" % PROFILE_PATH
	)


## Every entry has a reason, and every reason has an entry.
##
## The engine ignores [code]_why[/code] entirely — SConstruct reads
## [code]disabled_classes[/code] and [code]disabled_build_options[/code] and
## nothing else — so it is only real if something enforces it. This is that
## something. An option added without a line saying what it costs is how a
## profile turns into folklore.
func test_every_disabled_option_says_why() -> void:
	var why: Variant = _profile.get("_why", {})
	assert_true(why is Dictionary, "%s must carry a _why object" % PROFILE_PATH)
	if not (why is Dictionary):
		return
	var reasons: Dictionary = why
	for option: String in _disabled.keys():
		var reason: String = str(reasons.get(option, ""))
		assert_false(
			reason.is_empty(), "%s disables %s without saying why" % [PROFILE_PATH, option]
		)
	for option: String in reasons.keys():
		assert_true(
			_disabled.has(option),
			"%s explains %s, which it no longer disables" % [PROFILE_PATH, option]
		)


## The gate this file exists for.
##
## A hit here means the published web build would fail at runtime on the line
## that names the class, and only there — so the failure this reports is the
## one nothing else in the project can.
func test_no_src_script_uses_a_disabled_module() -> void:
	for option: String in CLASSES_BY_OPTION.keys():
		if not _disabled.has(option):
			continue
		var provided: Array = CLASSES_BY_OPTION[option]
		for provided_class: String in provided:
			for path: String in _sources.keys():
				var source: String = _sources[path]
				assert_false(
					_names_class(source, provided_class),
					(
						(
							"%s uses %s, but %s turns it off for the web build — "
							+ "the export would succeed and the game would fail in a browser"
						)
						% [path, provided_class, PROFILE_PATH]
					)
				)


## The same rule from the other side: what the scan cannot be allowed to lose.
func test_the_modules_the_game_needs_stay_enabled() -> void:
	for option: String in MUST_STAY_ENABLED.keys():
		assert_false(
			_disabled.has(option),
			"%s disables %s, and src/ uses %s" % [PROFILE_PATH, option, MUST_STAY_ENABLED[option]]
		)


## True when [param text] names [param subject] as a whole word.
##
## Whole-word because the substring test is wrong in both directions here:
## [code]Camera3D[/code] is not [code]CameraServer[/code], and a scene storing
## [code]type="StaticBody3D"[/code] has no spaces around the name.
func _names_class(text: String, subject: String) -> bool:
	var from: int = 0
	while true:
		var at: int = text.find(subject, from)
		if at == -1:
			return false
		var before: String = text.substr(at - 1, 1) if at > 0 else ""
		var after: String = text.substr(at + subject.length(), 1)
		if not _is_identifier_char(before) and not _is_identifier_char(after):
			return true
		from = at + subject.length()
	return false


func _is_identifier_char(character: String) -> bool:
	if character.is_empty():
		return false
	var code: int = character.unicode_at(0)
	var is_letter: bool = (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
	var is_digit: bool = code >= 48 and code <= 57
	return is_letter or is_digit or character == "_"

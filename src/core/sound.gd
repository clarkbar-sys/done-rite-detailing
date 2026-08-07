## Whether the game is making any noise, and the one place every screen
## reaches to flip it.
##
## [b]One bus, one flag.[/b] [code]project.godot[/code] defines no bus layout of
## its own, so [Bandstand], [Chime] and [ToolRacket] all reach the speakers
## through the engine's own "Master" bus. Muting that one bus silences the
## theme, the counter chime and every tool at once, which is what a single
## on/off switch is supposed to mean — three separate volumes would be three
## things that could drift out of step with each other and with whatever a
## button on screen claims is true.
##
## [b]A static class rather than an autoload[/b], for the reason [BuildInfo] is
## one: [code]godot --check-only[/code] — what [code]make check[/code] gates on
## — resolves global class names but not autoload names, so a call routed
## through an autoload would silently drop out of the type check. A static
## field also happens to be exactly what this needs: every screen that offers
## the toggle is freed the moment the player leaves it (see
## [code]src/main/main.gd[/code]), and whether the game is muted has to survive
## that swap with nothing left behind to free.
class_name Sound
extends RefCounted

## The bus every sound in the game mixes through. Named rather than written as
## the index the engine happens to give it — a name says what is being muted,
## an index only says where.
const BUS_NAME: String = "Master"

## Whether the game is currently silenced.
static var muted: bool = false


## Silences or restores [constant BUS_NAME], and remembers which for the next
## screen that asks.
static func set_muted(value: bool) -> void:
	muted = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS_NAME), muted)


## Flips [member muted] and applies it. What every on/off button in the game
## calls.
static func toggle() -> void:
	set_muted(not muted)

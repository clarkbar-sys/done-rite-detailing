## The game: the same garage the title screen was showing off, seen from inside
## it — standing beside the car at head height instead of circling it.
##
## The whole difference between this screen and the title card is two exports on
## the [Garage] instance in this scene's file: the orbit is off and
## [member Garage.first_person] is on. That is on purpose and it is the pattern
## worth keeping — the room is one scene, and a screen configures it rather than
## reaching into it. Nothing in this script touches the world.
##
## Deliberately a script with no code rather than no script at all — an empty
## seam left for the code this screen will eventually need. Everything the
## player will eventually do here (walk up to the car, start a job) lands in this
## file, and having it already means the first one touches nothing else.
##
## The eye is parked, and that is a decision rather than an omission: walking and
## looking around bring a character body, collision against the room's sealed
## walls, and touch controls with them, and none of those belong in the change
## that put a tool in the player's hands.
##
## There is no way back to the title screen on purpose. A Back button is a
## decision about how the game is paused and what that does to a job in
## progress, and inventing an answer now — before there is a job to interrupt
## — would be guessing at it. Reloading is the way out until then.
extends GameScreen

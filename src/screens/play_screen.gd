## The game: the same garage the menu was showing off, with the menu gone and
## the camera parked.
##
## Deliberately a script with no code rather than no script at all — the same
## seam [code]src/screens/main_menu.gd[/code] was until the menu grew a button.
## Everything the player will eventually do here (walk up to the car, pick up a
## tool, start a job) lands in this file, and having it already means the first
## one touches nothing else.
##
## There is no way back to the menu on purpose. A Back button is a decision
## about how the game is paused and what that does to a job in progress, and
## inventing an answer now — before there is a job to interrupt — would be
## guessing at it. Reloading is the way out until then.
extends GameScreen

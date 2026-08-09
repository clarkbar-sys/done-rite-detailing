# Proposal: replace the motion pad with a center-to-edge thumb walk

**Issue:** [#179](https://github.com/clarkbar-sys/done-rite-detailing/issues/179)
**Status:** proposed — investigation deliverable, not an implementation
**Recommendation: GO, with two conditions** (see [Go / no-go](#go--no-go)).

The idea under investigation: delete the motion pad and make movement part of
the aiming thumb. Thumb near the middle of the glass aims and works the tool as
today; thumb dragged out toward a screen edge lowers the tool and becomes a
walk vector; drag back in and the tool comes back up. One continuous thumb,
no dedicated pad.

The game ships to a browser on phones and tablets, held both ways up, so every
distance in this proposal is worked twice — once for the narrowest portrait
phone and once for landscape — and the boundary mechanic is chosen specifically
to survive both.

---

## The chosen boundary mechanic

**A center-anchored elliptical band, in normalized screen coordinates, with
hysteresis — and a veto: the gesture can never become a walk while the aim is
landing on the car.**

Concretely, for a pointer at screen position `p`, measured from the screen's
center with half-width `hw` and half-height `hh` in design pixels:

```
rho = sqrt( (p.x / hw)^2 + (p.y / hh)^2 )      # 0 at center, 1 at the corners' ellipse
```

| Threshold | Value | Meaning |
| --------- | ----- | ------- |
| `WALK_ENTER` | `rho >= 0.70` | an aim becomes a walk (tool lowers) — *unless the aim is on a panel* |
| `WALK_EXIT`  | `rho <= 0.55` | a walk becomes an aim again (tool re-raises) |
| `FULL_SPEED` | `rho >= 0.95` | walk strength reaches 1.0; rescaled from `WALK_ENTER` the way `ThumbStick.input_from` rescales from its dead zone, so the first millimetre past the boundary asks for almost nothing |

Walk direction is the unit vector from screen center to the finger, with Y
flipped into input space exactly as `ThumbStick` does: `turn = x`, `lift = -y`.
Left/right orbits the car, up/down raises and lowers the eye, diagonals do both
— the same two axes in `-1..1` the pad reports today, so nothing downstream of
the screen changes.

### Why each of the three candidate mechanics won or lost

**Fixed pixel radius — rejected.** A radius in design pixels is a different
fraction of the screen in portrait and landscape (`window/stretch/aspect` is
`expand`, so the viewport really does change shape under a running game — the
same fact `_thumb_lift()` in `src/screens/play_screen.gd` re-reads its scale
every press for). A circle that leaves a comfortable walk band on a landscape
tablet clips the entire width of a portrait phone.

**Leaving the car's projected screen bounds — rejected.** It sounds like the
honest boundary ("off the car = walking") and it has two disqualifying
problems. First, it creates a feedback loop: walking moves the camera, which
moves the car's projected bounds, which moves the boundary under a stationary
thumb — the state can flap with no input change. Second, it is jittery by
construction: the standoff (`src/core/standoff.gd`) is a servo that eases the
radius asymptotically and never fully stops, so the boundary never fully stops
either. It is also the hardest of the three to unit test, since it needs a
camera, a car and a projection where the others need two floats.

**Normalized ellipse with hysteresis — chosen.** It is the "fixed radius" idea
with the orientation problem removed: the boundary is a scaled copy of the
screen's own shape, so "70% of the way to the edge" means the same thing held
either way up. It is pure arithmetic on the touch position — node-free, unit
testable, the STANDARDS.md "Coverage" (R3) tier, same as `ThumbStick` and
`ThumbLift`. And the numbers work out on the worst screen (below).

### The veto is what prevents accidental walks mid-scrub

The hard case the issue names: scrubbing a door panel with long strokes, where
a stroke can genuinely cross `rho = 0.70`. The band alone cannot tell "long
scrub" from "leaving for a walk" — but the room already can. The garage
resolves the lifted aim point to a panel every tick (that answer already drives
`Garage.aimed` and the panel readout, and `AimHold` keeps the held case cheap),
so the rule is:

> **While the aim resolves to a panel, the state machine may not leave AIM,
> whatever `rho` says.**

A scrub across the paint can never become a walk, at any stroke length, in
either orientation. The walk can only start where the paint has run out — and a
thumb that has slid off the end of the bumper heading for the screen edge is a
thumb whose likeliest next intent *is* "carry on around the car", which is
exactly what it now does. If that read is wrong, the hysteresis makes recovery
a small pull back toward center, and the tool re-raises on the way (see the
state diagram).

The veto reuses the per-tick answer the room is already paying for; it adds no
physics queries. In WALK the screen calls `Garage.release_aim()`, so a walking
thumb pays *zero* casts — cheaper than today's parked press, which pays a
(cached) miss.

### The distances, checked on both orientations

Thresholds are fractions, but thumbs are physical, so the fractions were sized
against the narrowest target screen (`TouchTarget.NARROWEST_SCREEN_PX` = 375
reference px) and checked on the axis each orientation is worst on:

- **Portrait phone, horizontal axis (the worst case).** Half-width 187 ref px.
  Analog travel from `WALK_ENTER` to `FULL_SPEED` is `0.25 × 187 ≈ 47 ref px ≈
  12 mm` — almost exactly the motion pad's full middle-to-rim travel today
  ("about 13 mm of thumb on the narrowest screen", `MotionPad._relayout`). The
  hysteresis band is `0.15 × 187 ≈ 28 ref px ≈ 7 mm`, an order of magnitude
  above the 1–2 mm centroid wander a resting thumb produces (`ThumbStick.
  DEAD_FRACTION` has that measurement), so the state cannot flap from jitter.
- **Landscape phone, vertical axis.** Half-height ≈ 187 ref px on the same
  device rotated — identical numbers by symmetry. The other axis is generous in
  both orientations.
- **Tablets** are strictly easier: more screen on both axes, same fractions.

One asymmetry worth writing down: the band is tested against **the finger**,
not the lifted aim point. `ThumbLift` moves the aim ~80 ref px up the glass
(easing to zero at the top edge); testing the lifted point would make the top
boundary behave differently from the bottom one for no reason a player could
see. The finger is the gesture; the lift stays what it is today — a fact about
where the *aim* lands.

Portrait needs one more note. `LensFit` narrows the lens on tall screens so the
car keeps filling most of the frame's width — which means in portrait the car's
flanks reach close to `rho = 0.70` horizontally. That is why the veto, not the
band, carries the scrub-protection load in portrait, and why the band cannot be
pushed much further out than 0.70 without the walk zone vanishing on the axis
that needs it most.

---

## State diagram

```mermaid
stateDiagram-v2
    [*] --> IDLE

    IDLE --> AIM  : touch down, rho < WALK_ENTER\n(Garage.aim_at, tool raises)
    IDLE --> WALK : touch down, rho >= WALK_ENTER\n(tool never raises; steer from center-to-finger vector)

    AIM --> AIM   : drag (Garage.aim_at per tick, scrub/spray as today)
    AIM --> WALK  : rho >= WALK_ENTER AND aim not on a panel\n(Garage.release_aim once; tool lowers via ToolAim servo)
    AIM --> IDLE  : release (Garage.release_aim; tool lowers)

    WALK --> WALK : drag (steer(turn, lift) per frame; analog, full at rho 0.95)
    WALK --> AIM  : rho <= WALK_EXIT\n(Garage.aim_at resumes; tool re-raises)
    WALK --> IDLE : release (steer(0,0))

    AIM --> IDLE  : focus lost / screen resized or rotated
    WALK --> IDLE : focus lost / screen resized or rotated
```

Rules the diagram encodes:

- **First finger wins**, exactly the existing `_finger` convention in
  `play_screen.gd` and `MotionPad`: the finger that starts the gesture owns it
  until it lifts; other fingers are ignored (v1 — see Risks for the two-thumb
  follow-up). The emulated mouse (`InputEvent.DEVICE_ID_EMULATION`) is dropped
  on sight at the same two places it is today.
- **Focus-out and resize cancel to IDLE.** WALK is a held flag, and the pad has
  already paid for this lesson twice: a tab switched away never sends its
  release (`MotionPad._notification`), and a rotation moves the boundary out
  from under a held thumb (`MotionPad._relayout` lets go on resize). The new
  state machine adopts both, and gains the screen's aim a focus-out release it
  quietly lacks today.
- **Walk speed is analog with a soft start.** Strength rescales from the
  boundary (`(rho - 0.70) / (0.95 - 0.70)`, clamped) the way the stick rescales
  from its dead zone, so "nudge round the wing" survives the pad's deletion.

### Does the tool auto-raise when walking stops? (issue question 4)

Neither of the issue's two options, because the state machine dissolves the
question: a walk only "stops" by the thumb coming back inside `WALK_EXIT`
(which re-aims, and `ToolAim`'s existing raise servo animates the tool back up
— `raise_amount` was built for exactly this shape of transition) or by release
(which lowers the tool, as release always has — "holding is firing and letting
go is not"). There is no reachable state where walking has stopped, the finger
is down, and the tool is ambiguous.

---

## Coexistence with the existing pieces (issue question 2)

The audit, file by file. The striking result is how little moves — the seams
this codebase keeps bragging about get cashed in a third time:

| Piece | Fate |
| ----- | ---- |
| `src/core/orbit_drive.gd`, `camera_orbit.gd`, `standoff.gd` | **Untouched.** OrbitDrive has only ever taken two numbers in `-1..1`; arrows → stick → gesture is the same seam paying out again. |
| `src/core/tool_aim.gd`, `aim_hold.gd` | **Untouched.** `aim_at`/`release_aim` remain the only two calls; AimHold keeps held misses cheap in AIM and is simply dropped in WALK. |
| `src/core/thumb_lift.gd` | **Untouched.** Still applied to the aim point in AIM; explicitly *not* consulted for the boundary test. |
| `src/core/touch_target.gd` | **Untouched.** Supplies the reference-px reasoning the thresholds above were sized with. |
| `src/core/thumb_stick.gd` | **Deleted with the pad and its tests** — the pad is its only caller (`OrbitDrive` names it only in a doc comment, which gets reworded) — after its rescale-from-threshold idiom is lifted into the new class. |
| `src/ui/motion_pad.gd` + `.tscn` | **Deleted.** ~500 lines, and the bottom-right corner comes back to the picture of the garage. Its focus-out and resize lessons migrate to the screen. |
| `src/core/thumb_walk.gd` *(new)* | Node-free class owning `rho`, the hysteresis, the veto input, and the strength rescale — a unit test, like the class it replaces. |
| `src/screens/play_screen.gd` | The real diff: `_gui_input`'s finger tracking grows the AIM/WALK state, and `_process` swaps `_pad.turn()/_pad.lift()` for the walk vector. Keyboard summing unchanged. |

### Desktop — mouse and keys (issue question 3)

**The mouse does not get the gesture.** A mouse aims only, as today (no lift,
no boundary): a cursor near the frame edge is a precise, deliberate aim, and
turning it into a walk would make painting the top of a windscreen a trap.
Desktop movement stays on the keys — `_process` already sums
`Input.get_axis(camera_left/right/up/down)` with the touch input and clamps in
`OrbitDrive`, and none of that changes. Every keyboard test in
`tests/integration/test_play_screen_walk.gd` passes unmodified; the InputMap
actions in `project.godot` are untouched. The play screen's existing
mouse/touch split (`MOUSE_FINGER` vs. touch indices) is precisely the hook that
makes "touch gets the gesture, mouse doesn't" one branch rather than a
heuristic.

---

## Risks, honestly

1. **Walking while spraying is lost in v1.** Today a thumb on the pad and a
   finger on the car work simultaneously; the unified gesture is one thumb
   doing one thing at a time — that is its premise ("stop tool, walk"). If
   playtesting misses it, the fix is cheap and additive: while one finger
   WALKs, let a second finger down inside the aim zone AIM (the two trackers
   already exist separately). Deliberately not in v1 — it doubles the state
   space before the base gesture has proven itself.
2. **Discoverability.** The pad is visible furniture; a gesture is invisible.
   Mitigations: the four chevrons the pad draws today become transient edge
   hints while a finger is down (drawn from the same direction constants), and
   `src/screens/how_to_play.gd` gets a line. The tool visibly lowering as the
   thumb crosses the band is itself the best affordance — it is the mechanic
   explaining itself, the way the stick's knob explains the dead zone.
3. **Center anchoring vs. resting thumbs, especially tablets.** The pad lives
   where a corner thumb rests; a center-to-edge drag asks the thumb to visit
   mid-screen. Two things soften this: a *fresh* touch already past
   `WALK_ENTER` walks immediately (no center-out drag required — a press near
   an edge just walks), and on tablets the aiming finger is typically an index
   finger with free reach anyway. Whether this feels right is prototype
   condition #1 below — it cannot be settled on paper.
4. **Near-miss presses now walk if parked far out.** Today a thumb in the sky
   beside the car aims at nothing (the classic `AimHold` miss); past the band
   it will now walk. Inside the band it still aims at nothing. This reads as
   intent honored rather than regression — a press toward the edge that hits
   no paint is a fair request to move — but it is a behavior change to watch in
   the prototype.

---

## Test plan

- **Unit** (`tests/unit/test_thumb_walk.gd`): the norm on asymmetric screens,
  both threshold crossings, the hysteresis (a point between EXIT and ENTER
  keeps whichever state it had), the veto, strength 0 at the boundary and 1 at
  `FULL_SPEED`, the Y flip, degenerate half-extents asking for nothing.
- **Integration** (reshaping `test_play_screen_walk.gd`; `test_motion_pad.gd`
  retires with the pad): a drag from center past the band walks the eye; the
  same drag in a portrait-shaped window walks too (the orientation is the test);
  a drag that stays on the car's panels never walks however far it travels
  (the veto, end to end); pulling back inside `WALK_EXIT` re-raises the tool
  (`raise_amount` climbing); release stops the walk dead; every existing
  keyboard test unchanged.

---

## Go / no-go

**GO** — the mechanic is sound, the boundary has a portrait-proof answer, and
the architecture makes the change small and mostly subtractive (one new
node-free class; one screen touched; ~500 lines of pad deleted; nothing below
the two-numbers seam moves). The freed corner and the one-thumb flow are what
a phone-first game wants.

Two conditions before the implementation issue is cut:

1. **A feel prototype on a narrow portrait phone and a landscape tablet** must
   validate the 0.70/0.55/0.95 numbers and the center-anchored reach (risk #3).
   The thresholds are exports on the screen for exactly this tuning pass.
2. **#178 lands first and independently.** The speed scalars live in
   `OrbitDrive`'s exports, below the seam — every tuning won there carries into
   this gesture untouched, and if this proposal dies in prototype, the pad is
   still faster.

Implementation gets its own issue after sign-off, per #179.

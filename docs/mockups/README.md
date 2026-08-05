# Mockups

Pictures of screens that do not exist yet, kept next to the issue that proposes
them so the argument in the issue has something to point at.

Nothing in this folder is loaded by the game. These are `.png` files rendered
outside the engine; the screens they describe are built in `src/screens/` in the
normal way when the issue is picked up. If a mockup and the shipped screen ever
disagree, the shipped screen is right and the mockup is history.

## What is here

| File | Screen | Issue |
| --- | --- | --- |
| `main-menu.png` | The menu Start leads to: the title lockup, **Play**, **How to Play** | [#91](https://github.com/clarkbar-sys/done-rite-detailing/issues/91) |
| `how-to-play.png` | One screen of rules, back to the menu bottom-left, into the game bottom-right | [#91](https://github.com/clarkbar-sys/done-rite-detailing/issues/91) |

## How they were made, and why that matters

Both are the real game underneath. The v1.10.0 web build was run in a browser,
driven the way a player drives it — Start, walk, roll the belt out, hold the jet
on the bonnet — and screenshotted; the proposed buttons and panels were then
drawn over those frames in HTML using the numbers from
[`src/core/brand.gd`](../../src/core/brand.gd): `#e21b23` for a pill, `#141418`
behind a card, a 30px corner, half the height for a pill's radius. The logo is
`assets/brand/done-rite-logo.png`, not a redraw of it.

So the parts of these pictures that already exist — the bay, the truck, the
stick, the belt, the score, the lockup — are photographs rather than drawings,
and the only invented pixels are the ones the issue is asking for. A mockup that
guessed at the palette would be proposing a second brand by accident.

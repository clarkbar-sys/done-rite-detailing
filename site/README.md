# `site/` — the detailing business's page

This is the front door. What GitHub Pages serves at the repo root is this
folder; the game is published underneath it at `play/`.

```
https://clarkbar-sys.github.io/done-rite-detailing/        <- site/index.html
https://clarkbar-sys.github.io/done-rite-detailing/play/   <- the web bundle
```

The assembly is four lines in `.github/workflows/ci-godot.yml` (`Assemble the
published site`, in both `build-web` and `pages`), so a PR preview shows the
same arrangement `main` publishes rather than a bare game.

## Why the site lives in a game repo

It used to live on Netlify, at a generated address, hand-maintained, with no
link between it and the game in either direction. Issue #75 proposed a large
version of fixing that — a shared palette gate, the game at `/play` on a real
domain, the tools renamed after the service menu — and that was cut down to
this: **take the site as it is, serve it from where the game already is, and
put one badge on it.**

So the rule for this folder is *as it is*. This is a copy of the page that was
already live, with one `<a class="play-badge">` and its CSS added. It is not a
rewrite, a framework, or a build step, and the next person to touch it should
keep it that way — one file, inline CSS, no dependencies, no toolchain.

## `.gdignore`

Godot's exporter uses `export_filter="all_resources"`, which packs every
imported resource in the project. Without `.gdignore` the two JPGs here become
textures in `index.pck` — 430 KB added to what a player downloads, to ship a
web page's images inside a game. `.gdignore` keeps the engine's filesystem scan
out of this folder entirely, so nothing here is imported and nothing here is
packed.

It does not hide the folder from `FileAccess`, which is how
`tests/unit/test_site_page.gd` still reads `index.html` and asserts the badge's
wiring.

## The badge, and the two rules it follows

- **It is a link, never an embed.** No `<iframe>`, no `prefetch`, no script.
  The game is ~40 MB; a visitor who came for a phone number must not pay for it
  existing. Pressing the badge is the only thing that fetches the build.
- **It never covers the phone number.** On a desktop the topbar's red
  `Call 330-780-4778` button sits in the top-right corner, so the badge hangs
  *below* the 74 px header rather than in it, at `z-index: 49` — under that
  bar, not over it.
- **On a phone it is not floating at all — it is in the bar.** That corner is
  free at this width: the Call button is `display: none` (the bottom
  `.mobile-bar` carries Call and Text) and the nav links went at 900 px, so
  what the desktop rule had to dodge is empty black header. `position: static`
  makes the badge a flex item of `.nav`, beside the brand, which is what fixes
  the problem it had while floating — being fixed, it sat over some band of
  the page at every scroll position, and at full width it clipped the hero's
  eyebrow. It shrinks to icon + "Play", keeps its 48 px height, and the brand
  gets `min-width: 0` so a narrow phone wraps the tagline rather than pushing
  the badge off the edge. The bob goes with the float: a pill bouncing inside
  a 66 px bar reads as broken rather than as an invitation.

Both are asserted in `tests/unit/test_site_page.gd`, and neither is something a
type check or an export could have failed on — same reasoning as
`web/shell.html` and its test.

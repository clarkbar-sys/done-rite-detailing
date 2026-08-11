# Tutorial narration

One section per take — see `src/core/tutorial_take.gd` (issue #221) for the
authoritative catalogue: `water`, `sponge`, `glass`, `rag`, `full`. Headings
below are those take names exactly, so `scripts/narrate.sh` can turn each
section straight into `build/narration/<take-name>.wav` and the capture
harness can pair footage and voiceover by name alone.

There is deliberately no `rinse` take. The mask has three buckets and water
only ever moves mud, so a second water pass over an already-foamed panel
moves nothing — it would film several seconds of a wand pointed at a panel
that does not change. `glass` — the blue bottle on the windows — stands in
that slot instead; it's the beat that shows the belt actually mattering
(sponge is body-only, glass wants its own bottle).

Keep every section to one or two short sentences. The acceptance bar (issue
#175) is a player who understands wash → cleaner → buff without reading
paragraphs, not a transcript of the how-to-play screen — that screen already
exists and says more than this needs to.

## water

Grab the power washer, hold it on the paint. That's the wash pass — it only lifts mud.

## sponge

Bare paint takes product, and the sponge is for the body panels. Work it into the suds the water left.

## glass

Glass wants its own bottle. Grab the blue cleaner for the windows, not the sponge.

## rag

Wipe the product off with the drying rag. That's the shine, and the only way a panel counts as finished.

## full

Wash off the mud, lay down the right product, buff it to a shine — one panel, start to finish. That's the whole job.

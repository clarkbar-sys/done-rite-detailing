#!/usr/bin/env python3
"""Re-livery the baked tyre bottle into the window cleaner's blue one.

    scripts/build-window-cleaner.py            # assets/... -> assets/...
    scripts/build-window-cleaner.py --help     # the two path overrides, for testing

Input is assets/models/cleaning_spray/tire_cleaner.glb, which
scripts/build-tire-cleaner.py bakes out of the Sketchfab download of "Kitchen
Spray" by Jesus Osco (CC-BY 4.0). Output is
assets/models/cleaning_spray/window_cleaner.glb — the bottle the game puts in
the player's hand for DetailingTool.Id.WINDOW_CLEANER.

WHY THE INPUT IS THE BAKE AND NOT THE DOWNLOAD
-----------------------------------------------
The two bottles are the same object in two liveries, so the only honest place to
fork them is after the flattening, the UV pruning and the 256px resample the
other script argues for at length — repeating that work here would be a second
copy of those decisions, free to drift from the first. tire_cleaner.glb is
committed, is byte-for-byte reproducible from the download, and is the exact
mesh this one has to match, so it is a better input than the 8 MiB scene both of
them come from. The licence rides along with it: this is a derivative of a
derivative, ATTRIBUTION.txt covers both files, and this script asserts that it
still does before it will write anything.

Geometry, UVs, materials, samplers and every other texture are copied across
untouched. The only two things that change are the bottle's albedo map and the
`asset.generator` string that says which script wrote the file, and `verify`
below re-reads both files afterwards and requires exactly that.

WHAT IT COSTS, SINCE IT IS NOT NOTHING
---------------------------------------
The window bottle used to be a 2,352-vertex cylinder out of
src-models/cleaning_spray/window_cleaner.blend and is now this 5,982-vertex
sprayer. So it costs 0.70 MiB of repository — the geometry is duplicated, and
only one of the fourteen textures differs — and about 18 ms of the bay's load,
because ToolModel rebuilds every vertex of every model it fits. Both numbers are
written down here and in src/world/tool_model.gd rather than left to be
discovered later. The alternative — one asset drawn twice with a tint over it —
would tint the printed label along with the plastic, which is exactly what this
recolour exists to avoid.

Those two numbers were 37,286 vertices and 2.0 MiB until the tyre bottle's bake
grew a mesh simplifier. Nothing in this script changed for that: it copies
whatever geometry arrives across untouched and asserts that it did, so the
simplifier landed here as a smaller input and a smaller output and not as a
line of code. That is the whole point of forking the two liveries after the
bake rather than before it.

The .blend stays where it is. src-models/ is read-only (see its AGENTS.md) and
is the one place the untouched sources live, whether or not the game currently
bakes anything out of one.

WHAT "TURN THE GREY PART BLUE" MEANS, PIXEL BY PIXEL
-----------------------------------------------------
The bottle's albedo is a moulded grey plastic body with a printed label on the
front — one 256x256 map holding both, so "the grey part" has to be found in the
texture rather than selected on the model. Two tests, and a pixel has to pass
both:

  * it is grey. Chroma — the spread between a pixel's brightest and dimmest
    channel — of at most GREY_CHROMA. The label is saturated print (its blues,
    reds and yellows all sit far above that) and the plastic is a true neutral;
  * it is plastic-bright. Value inside PLASTIC_BAND. This is what keeps the
    label's own neutrals: the white sunburst behind the wordmark and the
    photographed kitchen counter along the top are grey by the first test and
    would go a lurid cyan without the second, and the black beyond the UV
    islands is grey too.

Measured on the current bake, that selects 34,235 of 65,536 pixels — every
island of plastic, and nothing inside the label — with a mean value of 124.1,
which is PLASTIC_GREY. Both numbers are re-asserted at run time, so a re-bake
whose texture no longer looks like this one fails here instead of shipping a
bottle that is blue in patches.

The selected pixels are then scaled per channel by BLUE / PLASTIC_GREY rather
than replaced with BLUE. Replacing them would flatten the moulding: the plastic
is not one grey but a narrow spread of them, and that spread is the only shading
the body has. Scaling keeps it — the plastic's own mid-grey lands exactly on
BLUE and everything lighter or darker stays lighter or darker by the same ratio.

BLUE is the catalogue's own Color(0.16, 0.66, 0.92) for this tool, in bytes.
That is the colour the roll-up already draws the window cleaner's icon in, so
the icon in the corner and the bottle in the hand are one number rather than two
that agree until somebody edits one — which is the argument DetailingTool's
class docs make about the proxy, made here about the texture.

Re-running is safe and produces byte-identical files: nothing here reads the
clock, iterates a set, or depends on dict ordering the interpreter chose.

Only Pillow is imported beyond the standard library, and only to recolour PNG.
The glTF itself is read and written with struct + json, the same way
scripts/build-tire-cleaner.py does it and for the same reason — a GLB is a
12-byte header and two length-prefixed chunks. The container helpers below are a
deliberate copy of that script's rather than a shared import, on the same
grounds: `scripts/` is a directory of programs, not a package.
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
from io import BytesIO
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover - environment problem, not a code path
    sys.exit("Pillow is required: pip install pillow")

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "assets/models/cleaning_spray/tire_cleaner.glb"
OUT = REPO / "assets/models/cleaning_spray/window_cleaner.glb"
ATTRIBUTION = "ATTRIBUTION.txt"

# What scripts/build-tire-cleaner.py stamps into the file it writes. Asserted so
# this script cannot be pointed at some other .glb and quietly recolour whatever
# grey it finds in it.
SOURCE_GENERATOR = "done-rite-detailing scripts/build-tire-cleaner.py"
GENERATOR = "done-rite-detailing scripts/build-window-cleaner.py"

# The image the recolour applies to, by the name the bake gave it. The other
# thirteen images in the file — the two caps, the neck, the nozzle and the
# trigger, and the bottle's own normal and ORM maps — are copied byte for byte,
# which is the point: a bottle whose shading changed with its colour would not be
# the same bottle in a different livery.
BOTTLE_ALBEDO = "bottle_albedo"

# DetailingTool.catalogue()'s Color(0.16, 0.66, 0.92) for the window cleaner, as
# 8-bit sRGB. See the docstring for why the texture takes its colour from the
# same place the roll-up icon does.
BLUE = (41, 168, 235)

# The plastic's own mid-grey, which is what BLUE replaces exactly. Everything
# else grey is scaled by the same ratio and so keeps its distance from it.
PLASTIC_GREY = 124

# How far a pixel's channels may spread apart and still count as grey.
GREY_CHROMA = 20

# The value range the moulded plastic occupies, inclusive. Outside it are the
# label's own neutrals and the black beyond the UV islands — see the docstring.
PLASTIC_BAND = (96, 176)

# What the two tests above must select, re-measured on every run. The share is
# generous either side of the 0.522 the current bake gives; the mean is tight,
# because it is the number BLUE is calibrated against and a drift in it would
# quietly shift the whole bottle off the icon's blue.
MIN_SELECTED_SHARE = 0.40
MAX_SELECTED_SHARE = 0.65
GREY_TOLERANCE = 2.0

# No accessor is decoded here — only the container and the images are read — so
# this script needs the file magic, the two chunk magics and the 4-byte
# alignment, and none of glTF's component types.
JSON_CHUNK, BINARY_CHUNK = 0x4E4F534A, 0x004E4942
GLB_MAGIC = 0x46546C67


# --------------------------------------------------------------------------
# GLB container
# --------------------------------------------------------------------------


def read_glb(path: Path) -> tuple[dict, bytes]:
    """Split a .glb into its JSON chunk and its binary chunk."""
    raw = path.read_bytes()
    magic, version, total = struct.unpack_from("<III", raw, 0)
    if magic != GLB_MAGIC or version != 2:
        raise ValueError(f"{path} is not a glTF 2.0 binary file")
    offset, chunks = 12, {}
    while offset < total:
        size, kind = struct.unpack_from("<II", raw, offset)
        chunks[kind] = raw[offset + 8 : offset + 8 + size]
        offset += 8 + size + (-size % 4)
    return json.loads(chunks[JSON_CHUNK].decode("utf-8")), chunks.get(BINARY_CHUNK, b"")


def write_glb(path: Path, gltf: dict, binary: bytes) -> None:
    """Write a .glb. Keys are sorted and separators fixed so the bytes are stable."""
    text = json.dumps(gltf, sort_keys=True, separators=(",", ":")).encode("utf-8")
    text += b" " * (-len(text) % 4)
    blob = binary + b"\0" * (-len(binary) % 4)
    total = 12 + 8 + len(text) + (8 + len(blob) if blob else 0)
    out = bytearray()
    out += struct.pack("<III", GLB_MAGIC, 2, total)
    out += struct.pack("<II", len(text), JSON_CHUNK) + text
    if blob:
        out += struct.pack("<II", len(blob), BINARY_CHUNK) + blob
    path.write_bytes(bytes(out))


# --------------------------------------------------------------------------
# The recolour
# --------------------------------------------------------------------------


def is_plastic(pixel: tuple[int, int, int]) -> bool:
    """Whether `pixel` is a piece of the bottle's moulded grey — see the docstring."""
    low, high = PLASTIC_BAND
    return max(pixel) - min(pixel) <= GREY_CHROMA and low <= max(pixel) <= high


def pixels_of(png: bytes) -> tuple[bytes, tuple[int, int]]:
    """`png` as flat RGB bytes, three to a pixel, plus the size it came at."""
    image = Image.open(BytesIO(png)).convert("RGB")
    return image.tobytes(), image.size


def blued(png: bytes) -> tuple[bytes, int, float]:
    """`png` with its grey plastic scaled onto BLUE, plus what that selected.

    The count and the mean come back alongside the bytes rather than being
    printed from in here, so `main` can both report them and assert them: a
    recolour that silently selected a tenth of the pixels it used to is the
    failure this whole script is most exposed to.
    """
    raw, size = pixels_of(png)
    out = bytearray(raw)
    selected = 0
    total = 0.0
    for at in range(0, len(raw), 3):
        pixel = (raw[at], raw[at + 1], raw[at + 2])
        if not is_plastic(pixel):
            continue
        selected += 1
        total += sum(pixel) / 3.0
        for channel in range(3):
            out[at + channel] = min(255, round(pixel[channel] * BLUE[channel] / PLASTIC_GREY))
    written = BytesIO()
    Image.frombytes("RGB", size, bytes(out)).save(written, format="PNG", optimize=True)
    return written.getvalue(), selected, total / selected if selected else 0.0


# --------------------------------------------------------------------------
# Rebuilding the file
# --------------------------------------------------------------------------


def check_source(gltf: dict) -> int:
    """Assert the input is the tyre bottle's bake, and return the bottle image's index.

    Every claim this script makes about its input is checked here rather than
    relied on further down, because the failure it prevents is silent: a file
    with no grey plastic in it recolours to itself, and a bottle that arrived
    without its trigger would ship looking exactly like one that did.
    """
    if gltf["asset"].get("generator") != SOURCE_GENERATOR:
        raise AssertionError(f"the source was not written by {SOURCE_GENERATOR}")
    if len(gltf["nodes"]) != 1 or "matrix" in gltf["nodes"][0]:
        raise AssertionError("the source must be a single mesh node at the origin")
    if len(gltf["meshes"]) != 1:
        raise AssertionError("the source must hold exactly one mesh")
    names = [image.get("name") for image in gltf["images"]]
    if names.count(BOTTLE_ALBEDO) != 1:
        raise AssertionError(f"the source holds {names.count(BOTTLE_ALBEDO)} images named {BOTTLE_ALBEDO}")
    return names.index(BOTTLE_ALBEDO)


def rebuilt(gltf: dict, binary: bytes, image_index: int, png: bytes) -> tuple[dict, bytes]:
    """The source glTF with image `image_index`'s bytes replaced by `png`.

    The buffer is repacked rather than patched in place: the recoloured PNG is
    not the same length as the one it replaces, so every view after it moves.
    Repacking in the order the views are already in keeps the output's layout
    the source's, which makes the two files diffable as well as deterministic.
    """
    out = json.loads(json.dumps(gltf))
    out["asset"]["generator"] = GENERATOR
    replaced = out["images"][image_index]["bufferView"]
    blob = bytearray()
    for index, view in enumerate(out["bufferViews"]):
        start = view["byteOffset"]
        payload = png if index == replaced else binary[start : start + view["byteLength"]]
        blob += b"\0" * (-len(blob) % 4)
        view["byteOffset"] = len(blob)
        view["byteLength"] = len(payload)
        blob += payload
    out["buffers"] = [{"byteLength": len(blob) + (-len(blob) % 4)}]
    return out, bytes(blob)


def verify(path: Path, source: Path) -> None:
    """Re-parse both files and require them to differ in exactly one thing.

    Writing the file is not proving it, and the proof that matters here is
    negative: the window bottle has to be the tyre bottle everywhere except in
    the one image, or the two tools have stopped being the same object.
    """
    made, made_bin = read_glb(path)
    was, was_bin = read_glb(source)
    for key in ("accessors", "meshes", "materials", "textures", "images", "samplers", "nodes", "scenes"):
        if made[key] != was[key]:
            raise AssertionError(f"the recolour changed {key}, which it must not")
    index = check_source(was)
    if len(made["bufferViews"]) != len(was["bufferViews"]):
        raise AssertionError("the recolour added or dropped a bufferView")
    for at, (mine, theirs) in enumerate(zip(made["bufferViews"], was["bufferViews"])):
        ours = made_bin[mine["byteOffset"] : mine["byteOffset"] + mine["byteLength"]]
        original = was_bin[theirs["byteOffset"] : theirs["byteOffset"] + theirs["byteLength"]]
        if at == made["images"][index]["bufferView"]:
            if ours == original:
                raise AssertionError("the bottle's albedo came out unchanged")
        elif ours != original:
            raise AssertionError(f"bufferView {at} changed, and only the bottle's albedo may")
    raw, _ = pixels_of(_view(made, made_bin, index))
    if any(is_plastic((raw[at], raw[at + 1], raw[at + 2])) for at in range(0, len(raw), 3)):
        raise AssertionError("the output still holds grey plastic — the recolour missed some")


def _view(gltf: dict, binary: bytes, image_index: int) -> bytes:
    view = gltf["bufferViews"][gltf["images"][image_index]["bufferView"]]
    return binary[view["byteOffset"] : view["byteOffset"] + view["byteLength"]]


def check_attribution(folder: Path, name: str) -> None:
    """Require the CC-BY notice beside the asset to name the file being written.

    scripts/build-tire-cleaner.py writes that file, and it names both
    derivatives; this is what stops the two scripts drifting apart in the one
    direction that costs more than a re-run — an asset in the repo whose licence
    condition is discharged nowhere.
    """
    notice = folder / ATTRIBUTION
    if not notice.is_file():
        raise AssertionError(f"{notice} is missing — run scripts/build-tire-cleaner.py first")
    if name not in notice.read_text(encoding="utf-8"):
        raise AssertionError(f"{notice} does not credit {name}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Re-livery the tyre bottle as the window cleaner.")
    parser.add_argument("--src", type=Path, default=SRC, help="the baked tyre bottle (read only)")
    parser.add_argument("--out", type=Path, default=OUT, help="output .glb")
    args = parser.parse_args()

    gltf, binary = read_glb(args.src)
    index = check_source(gltf)
    source_png = _view(gltf, binary, index)
    png, selected, mean = blued(source_png)

    width, height = pixels_of(source_png)[1]
    share = selected / (width * height)
    if not MIN_SELECTED_SHARE <= share <= MAX_SELECTED_SHARE:
        raise AssertionError(f"the recolour selected {share:.1%} of the map, expected about 52%")
    if abs(mean - PLASTIC_GREY) > GREY_TOLERANCE:
        raise AssertionError(f"the selected plastic averages {mean:.1f}, expected about {PLASTIC_GREY}")

    out_gltf, blob = rebuilt(gltf, binary, index, png)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    # Before the write rather than after it: a licence notice that does not cover
    # the asset is the one failure that must not leave the asset behind anyway.
    check_attribution(args.out.parent, args.out.name)
    write_glb(args.out, out_gltf, blob)
    verify(args.out, args.src)

    print(f"{args.src.name}: {args.src.stat().st_size / 1024:.0f} KiB in")
    print(f"  recoloured {BOTTLE_ALBEDO}, {selected} px ({share:.1%} of the map), mean grey {mean:.1f}")
    print(f"  to         rgb{BLUE}, the catalogue's window-cleaner blue")
    print(f"  copied     {len(gltf['images']) - 1} other textures and every surface untouched")
    print(f"{args.out.name}: {args.out.stat().st_size / 1024:.0f} KiB out")
    return 0


if __name__ == "__main__":
    sys.exit(main())

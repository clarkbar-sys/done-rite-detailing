#!/usr/bin/env python3
"""Bake the tyre & engine cleaner's bottle out of the Kitchen Spray source model.

    scripts/build-tire-cleaner.py            # src-models/... -> assets/models/
    scripts/build-tire-cleaner.py --help     # the two path overrides, for testing

Input is src-models/cleaning_spray/kitchen_spray.glb, the Sketchfab download of
"Kitchen Spray" by Jesus Osco (CC-BY 4.0). src-models/ is READ-ONLY (see its
AGENTS.md): this script only ever opens it for reading, and it is the one place
the untouched download lives.

Output is assets/models/cleaning_spray/tire_cleaner.glb — the bottle the game
puts in the player's hand for DetailingTool.Id.TIRE_ENGINE_CLEANER — plus
ATTRIBUTION.txt carrying the CC-BY notice the licence requires.

WHY THERE IS A BAKE AT ALL, AND NOT JUST A COPY
------------------------------------------------
The download is a 8.0 MiB scene of six separately-parented meshes carrying
fourteen 1024x1024 textures and four UV sets. The game wants one mesh, because
[ToolModel] lifts "the first MeshInstance3D at or under the root" out of the
imported scene and fits it into the catalogue's extent — a six-mesh model would
put the bottle in your hand and leave its neck, nozzle, trigger and both caps
behind. So the bake:

  * flattens the six parts into ONE mesh with one primitive per material, which
    is what ToolModel's contract has always asked an asset for. Node transforms
    are composed and baked into the vertices, so the output node is identity;
  * keeps POSITION, NORMAL and TEXCOORD_0 and drops the rest. TEXCOORD_1..3 are
    Sketchfab's extra UV sets and nothing samples them; TANGENT is regenerated
    at import (meshes/ensure_tangents in the .import sidecar), so shipping it
    twice is 480 KiB of nothing;
  * resamples every texture to 256x256. The bottle is 0.30 m tall in the corner
    of the frame and never fills more than about a fifth of the screen height,
    so a 1024 map is roughly four times the texels that can ever be seen;
  * simplifies each part down to a share of the whole bottle's TRIANGLE_BUDGET —
    68,096 triangles in, 8,496 out. That is the long section below;
  * narrows indices to 16-bit where the primitive fits, which every one of them
    does (the largest is now 2,072 vertices, and was 11,923 before the
    simplifier).

The bottle is NOT re-proportioned to the catalogue's extent, and that is the
one distortion this script deliberately leaves in place. The source bottle is
100 x 269 x 80 mm and DetailingTool gives the tool a 110 x 300 x 110 mm box, so
ToolModel's fit stretches it about 26% deeper than it is wide. The extent is
hand-tuned game feel — it is what the roll-up icon is drawn from, what the
sight radius averages and what ReachCarry stands the nozzle off the paint by —
and moving those numbers to flatter a mesh would change how the game plays for
a cosmetic swap. A rounder bottle is the cheaper of the two prices.

Re-running is safe and produces byte-identical files: nothing here reads the
clock, iterates a set, or depends on dict ordering the interpreter chose.


WHY THE MESH IS SIMPLIFIED, AND WHAT THE BUDGET IS WORTH (measured)
--------------------------------------------------------------------
This script used to say the artist's 68,096 triangles were deliberately left
alone, on the grounds that a hand-rolled simplifier is a quality risk. What was
missing from that trade was the size of the other half of it. Measured, on the
pinned Godot, by importing the same .glb with the sidecar's two mesh switches
flipped in turn:

    tire_cleaner.glb -> .godot/imported/....scn      bytes
      generate_lods + create_shadow_meshes (shipping)  1,938,697
      generate_lods only                               1,133,323
      create_shadow_meshes only                        1,275,000
      neither                                            796,877

So the LOD chain and the shadow mesh are two thirds of the file, and turning
them off — which is what the issue that opened this asked about first — still
leaves 0.78 MiB of bare mesh, twice what the whole scene was allowed to cost.
The bloat is not the import settings. It is 68,096 triangles on a bottle held in
the corner of the frame, and the only lever that moves all three numbers at once
is the triangle count.

TRIANGLE_BUDGET is 8,500 because the imported scene costs about 28.5 bytes a
triangle at those settings (1,938,697 / 68,096) and the bottle was asked to fit
in 0.4 MB. What it actually buys, re-measured on the files this script now
writes, with the pack read by scripts/list-pck.py:

    imported .scn, each bottle    1,938,697 -> 253,739 bytes   (-86.9%)
    both bottles in index.pck     3,878,067 ->   507,464 bytes
    .glb in this repository       2,094,068 ->   734,660 bytes
    ToolModel build, each bottle  33 ms -> 18 ms    (see src/world/tool_model.gd)

3.37 MB off a 35.6 MB pack, for two props held in the corner of the frame, which
is what the load-time epic this belongs to is spending.


HOW IT IS SIMPLIFIED, AND WHY IT KEEPS THE ARTIST'S UVs EXACTLY
-----------------------------------------------------------------
Garland & Heckbert's quadric error metric over half-edge collapses, in about two
hundred lines below, standard library only. Blender is not in this repo's
toolchain and adding it for one asset would put a 400 MB dependency behind a
file that has to rebuild in CI; the rest of scripts/ manipulates glTF with json
and struct, and this is the same idea carried one step further.

The one place it deliberately departs from the textbook is where the survivor
lands. Textbook QEM puts it wherever the summed quadric is smallest, which is a
new point in space with no texture coordinate of its own — so the UV has to be
interpolated, and an interpolated UV on a bottle wearing a printed label is how
a decimator smears a wordmark. Here a collapse always lands on one of the two
vertices it joins. Nothing is ever moved and nothing is ever invented: the
output's POSITION, NORMAL and TEXCOORD_0 are all bit-for-bit the artist's, and
the whole of what this script decides is which vertices stop being drawn.

That costs a little accuracy per collapse and it is bought back by having six
times as many collapses to choose from. Measured on the result — every one of
the 37,286 source vertices, to the nearest point on the simplified surface:

    Bottle   worst 0.476 mm   mean 0.050 mm
    Neck     worst 0.002 mm   mean 0.000 mm
    Nozzle   worst 0.080 mm   mean 0.007 mm
    Top_1    worst 0.346 mm   mean 0.049 mm
    Top_2    worst 0.304 mm   mean 0.058 mm
    Trigger  worst 0.460 mm   mean 0.071 mm

Half a millimetre, worst case, on a 269 mm bottle that is about a fifth of the
screen's height — a fifth of a pixel at 720p. The overall box is 101 x 269 x 80
mm before and after, and the bottle's own height moves by 0.04 mm.


AND WHAT THE QUADRIC CANNOT SEE
---------------------------------
A quadric measures distance from planes. It is therefore blind to three things
that would each ruin this asset in a way no size measurement would notice, and
each of them is refused explicitly in `Decimator.collapse`:

  * a UV seam is one ridge of the surface authored twice, once per side. Welding
    by position is what lets the simplifier see the surface at all — otherwise
    every seam reads as two open borders and nothing near one can move — and the
    duplicates then have to be carried through each collapse as "wedges", with a
    map derived from the two triangles the collapse deletes. If that map does not
    reach every wedge, or would land two of them on one, the seam is being
    pinched and the collapse is refused;
  * the texture can be folded even when the surface is not. Two vertices whose
    UVs happen to be nearly collinear make a triangle that samples a line of the
    map across a patch of bottle — measured, before this was guarded, the nozzle
    had triangles spreading a millionth of the texture per square metre where the
    artist's sparsest spreads 191. So a collapse is refused if it would leave any
    triangle thinner than UV_DENSITY_SLACK of the sparsest triangle *that part*
    already had, which is a floor read off the artist's own layout rather than a
    number invented here;
  * a triangle can be turned inside out at no quadric cost at all, because a
    plane does not care which side you are on. FLIP_LIMIT refuses that, and
    SLIVER_AREA refuses the degenerate triangle it shades into.

The two caps are also the only parts with an open border — 280 edges and 128 —
and BORDER_PENALTY holds those rims about a hundred times harder than the flat
beside them, because faces alone say nothing about an edge with nothing on the
other side of it.


RUNNING THIS WITHOUT THE DOWNLOAD
-----------------------------------
`--src` accepts either the Sketchfab download or a previous full-resolution run
of this script, told apart by the generator string the output carries. The second
route exists because the download is not in this repository — src-models/ holds
the two .blend files this asset used to be made from, and the 8.0 MiB .glb has
always had to be fetched — so a checkout that wants to change how the bottle is
baked would otherwise have nothing to bake from.

On that route the flattening, the UV pruning and the resample have already
happened, so the parts are read straight off the six primitives and the textures
are passed through byte for byte rather than resampled to the size they already
are. What is asserted is what makes the route honest: the same six parts in the
same order, every map already TEXTURE_PX square, and the geometry still at the
artist's full FULL_TRIANGLES. That last one is what stops an already-simplified
bottle being fed back in and simplified a second time.

Only Pillow is imported beyond the standard library, and only to resample PNG.
The glTF itself is read and written with struct + json, the same way
scripts/build-car-pack.py does it and for the same reason — a GLB is a 12-byte
header and two length-prefixed chunks. The container helpers below are a
deliberate copy of that script's rather than a shared import: the two bakes
have nothing else in common, and `scripts/` is a directory of programs, not a
package.


WHAT THE SOURCE SCENE ACTUALLY LOOKS LIKE (measured, not assumed)
------------------------------------------------------------------
Everything below was read out of the file and is re-asserted at run time, so a
re-download that differs fails loudly instead of baking quiet nonsense.

Sketchfab_model -> root -> GLTF_SceneRootNode -> Empty_6, and the two matrices
on that chain are -90 and +90 degrees about X: they cancel exactly, so mesh
space is already the Y-up metres the game wants. Composed anyway rather than
skipped, and then asserted to be a rigid transform, because a re-export that
stops cancelling must not silently lay the bottle on its side.

Under Empty_6 sit six one-primitive parts, each with its own material and its
own texture set: Bottle (22,144 tris), Neck (20,480), Nozzle (8,704),
Top_1 (7,488), Top_2 (3,712) and Trigger (5,568). Two of them carry a node
translation of about 0.1 mm; the rest are identity.

The bottle stands on y = 0 and reaches y = 0.269, which is a real 27 cm trigger
sprayer — the download is already in metres. The trigger and nozzle face -X,
which is the direction ViewModel._held_pose leans this tool (30 degrees about
+Z tips its top towards -X), so the business end swings up and left into frame
exactly as that table intends. Nothing here rotates the model.
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
from heapq import heappop, heappush
from io import BytesIO
from math import sqrt
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover - environment problem, not a code path
    sys.exit("Pillow is required: pip install pillow")

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "src-models/cleaning_spray/kitchen_spray.glb"
OUT = REPO / "assets/models/cleaning_spray/tire_cleaner.glb"

# The six parts, in the order the source lists them, keyed by material name.
# A dict rather than a set: the value is what the extracted texture sidecars are
# named after, so it is also the one place the on-disk file names are decided.
PARTS = {
    "Bottle": "bottle",
    "Neck": "neck",
    "Nozzle": "nozzle",
    "Top_1": "cap",
    "Top_2": "collar",
    "Trigger": "trigger",
}

# Square, because every source map is. See the docstring for the texel-density
# arithmetic behind the number.
TEXTURE_PX = 256

# What the artist's six parts add up to before anything is collapsed. Asserted
# on the re-bake route (see `parts_of_bake`) so an already-simplified bottle
# cannot be fed back in and simplified a second time.
FULL_TRIANGLES = 68096

# How many triangles the whole bottle is allowed to leave the bake with, shared
# out between the six parts in proportion to what each arrived with. See the
# docstring for the measurements behind the number: the imported `.scn` costs
# about 28.5 bytes a triangle, so this is the budget that buys a 0.24 MB scene
# where the artist's mesh cost 1.94 MB.
TRIANGLE_BUDGET = 8500

# How near two POSITIONs have to be to be the same corner of the surface, in
# metres. A micron rather than a tolerance anybody has to tune: the source's UV
# seams are exact duplicates — measured, welding at this quantum takes the
# bottle's 11,923 vertices to 11,074, which is exactly the 22,144-triangle closed
# surface Euler says is under them — so nothing here is deciding what "near"
# means, it is only undoing the duplication a UV seam is.
WELD_QUANTUM = 1e-6

# What an open border edge is worth next to a face when the quadrics are built.
# The two caps are the only parts that have a border — 280 edges on the cap and
# 128 on the collar, and none anywhere else — and it is the rim you look straight
# down on, so it is held about a hundred times harder than the flat beside it.
BORDER_PENALTY = 100.0

# How far a triangle's normal may swing during a collapse before the collapse is
# refused. A fifth, which is about 78 degrees: a fold reads as a black facet on a
# smooth-shaded bottle long before it reads as geometry.
FLIP_LIMIT = 0.2

# The smallest triangle a collapse may leave behind — the length of the cross
# product rather than the area, so twice it. Below this the triangle has no
# normal worth carrying and the collapse is refused instead.
SLIVER_AREA = 1e-12

# How much thinner than the artist's own thinnest triangle a collapse may leave
# the texture spread, as a share. Half, and the *artist's* thinnest rather than a
# number chosen here, because the floor that matters is a property of the
# authored UV layout and not of this script — see the docstring's "AND WHAT THE
# QUADRIC CANNOT SEE". A collapse is refused if it would leave any triangle
# mapping fewer than this share of the UV area per square metre that the sparsest
# triangle of the same part already managed.
UV_DENSITY_SLACK = 0.5

# The bottle, measured off the source and asserted on the way through. A
# re-export that lands outside this is not the same object and the fit into
# DetailingTool.extent would silently change shape.
EXPECTED_SIZE_M = (0.1006, 0.2690, 0.0800)
SIZE_TOLERANCE_M = 0.01

# glTF's component type ids, and the two buffer targets.
COMPONENT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
COMPONENT_COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER = 34962, 34963
UNSIGNED_SHORT, UNSIGNED_INT = 5123, 5125
SHORT_INDEX_LIMIT = 65536

GENERATOR = "done-rite-detailing scripts/build-tire-cleaner.py"

# How far a composed node matrix may drift from rigid before this script stops
# believing it can carry normals with a plain rotate. Generous next to the 2e-16
# the cancelling root matrices actually leave behind.
RIGID_TOLERANCE = 1e-6


# --------------------------------------------------------------------------
# GLB container
# --------------------------------------------------------------------------


def read_glb(path: Path) -> tuple[dict, bytes]:
    """Split a .glb into its JSON chunk and its binary chunk."""
    raw = path.read_bytes()
    magic, version, total = struct.unpack_from("<III", raw, 0)
    if magic != 0x46546C67 or version != 2:
        raise ValueError(f"{path} is not a glTF 2.0 binary file")
    offset, chunks = 12, {}
    while offset < total:
        size, kind = struct.unpack_from("<II", raw, offset)
        chunks[kind] = raw[offset + 8 : offset + 8 + size]
        offset += 8 + size + (-size % 4)
    return json.loads(chunks[0x4E4F534A].decode("utf-8")), chunks.get(0x004E4942, b"")


def write_glb(path: Path, gltf: dict, binary: bytes) -> None:
    """Write a .glb. Keys are sorted and separators fixed so the bytes are stable."""
    text = json.dumps(gltf, sort_keys=True, separators=(",", ":")).encode("utf-8")
    text += b" " * (-len(text) % 4)
    blob = binary + b"\0" * (-len(binary) % 4)
    total = 12 + 8 + len(text) + (8 + len(blob) if blob else 0)
    out = bytearray()
    out += struct.pack("<III", 0x46546C67, 2, total)
    out += struct.pack("<II", len(text), 0x4E4F534A) + text
    if blob:
        out += struct.pack("<II", len(blob), 0x004E4942) + blob
    path.write_bytes(bytes(out))


class Source:
    """The downloaded scene, with the accessor plumbing hidden."""

    def __init__(self, path: Path) -> None:
        self.gltf, self.bin = read_glb(path)
        self.nodes = self.gltf["nodes"]
        self.meshes = self.gltf["meshes"]
        self.materials = self.gltf["materials"]

    def accessor(self, index: int) -> list[tuple]:
        acc = self.gltf["accessors"][index]
        fmt, size = COMPONENT[acc["componentType"]]
        count = COMPONENT_COUNT[acc["type"]]
        view = self.gltf["bufferViews"][acc["bufferView"]]
        base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        stride = view.get("byteStride") or count * size
        unpack = struct.Struct("<" + fmt * count).unpack_from
        return [unpack(self.bin, base + i * stride) for i in range(acc["count"])]

    def image_bytes(self, index: int) -> bytes:
        image = self.gltf["images"][index]
        view = self.gltf["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        return self.bin[start : start + view["byteLength"]]


# --------------------------------------------------------------------------
# Small 3D helpers. The whole scene is one rigid transform, so a general 4x4
# library would be dead weight.
# --------------------------------------------------------------------------


def node_matrix(node: dict) -> list[float]:
    """A node's local transform as a column-major 4x4, TRS composed if needed."""
    if "matrix" in node:
        return list(node["matrix"])
    out = [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0]
    scale = node.get("scale", [1.0, 1.0, 1.0])
    if "rotation" in node:
        x, y, z, w = node["rotation"]
        rot = [
            1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w),
            2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w),
            2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y),
        ]  # fmt: skip
        for col in range(3):
            for row in range(3):
                out[col * 4 + row] = rot[col * 3 + row] * scale[col]
    else:
        for col in range(3):
            out[col * 4 + col] = scale[col]
    out[12], out[13], out[14] = node.get("translation", [0.0, 0.0, 0.0])
    return out


def mat_mul(a: list[float], b: list[float]) -> list[float]:
    out = [0.0] * 16
    for col in range(4):
        for row in range(4):
            out[col * 4 + row] = sum(a[k * 4 + row] * b[col * 4 + k] for k in range(4))
    return out


def apply(m: list[float], v: tuple) -> tuple[float, float, float]:
    return (
        m[0] * v[0] + m[4] * v[1] + m[8] * v[2] + m[12],
        m[1] * v[0] + m[5] * v[1] + m[9] * v[2] + m[13],
        m[2] * v[0] + m[6] * v[1] + m[10] * v[2] + m[14],
    )


def rotate(m: list[float], v: tuple) -> tuple[float, float, float]:
    return (
        m[0] * v[0] + m[4] * v[1] + m[8] * v[2],
        m[1] * v[0] + m[5] * v[1] + m[9] * v[2],
        m[2] * v[0] + m[6] * v[1] + m[10] * v[2],
    )


def assert_rigid(matrix: list[float], where: str) -> None:
    """Fail unless the 3x3 part is orthonormal, so `rotate` is enough for normals.

    A normal carried through a *scaled* transform with a plain rotate no longer
    stands off its own surface — the same arithmetic ToolModel's inverse
    transpose exists for. Nothing in this scene scales, and this is what says so
    out loud instead of assuming it.
    """
    columns = [(matrix[i * 4], matrix[i * 4 + 1], matrix[i * 4 + 2]) for i in range(3)]
    for i, first in enumerate(columns):
        for j, second in enumerate(columns[i:], start=i):
            product = sum(a * b for a, b in zip(first, second))
            if abs(product - (1.0 if i == j else 0.0)) > RIGID_TOLERANCE:
                raise AssertionError(f"{where}: node transform is not rigid ({product:g})")


# --------------------------------------------------------------------------
# The simplifier
#
# Garland & Heckbert's quadric error metric, over half-edge collapses, with the
# survivor placed on one of the two vertices rather than at the quadric's own
# minimum. See the module docstring for why that restriction is the whole point
# and not a corner cut: a vertex that never moves keeps the artist's UV.
# --------------------------------------------------------------------------


def welded(positions: list[tuple]) -> tuple[list[int], list[tuple]]:
    """Group `positions` by coincidence: a weld id per vertex, and one point each.

    A UV seam is one ridge of the surface authored twice, once for each side's
    texture coordinate, and a simplifier that could not see that would treat the
    seam as two open borders and refuse to touch either. So topology is decided
    here on position alone, and the duplicates ride along as this module's
    "wedges" — see `Decimator.collapse`, which is where they are kept honest.
    """
    seen: dict[tuple[int, int, int], int] = {}
    weld: list[int] = []
    points: list[tuple] = []
    for point in positions:
        key = (
            round(point[0] / WELD_QUANTUM),
            round(point[1] / WELD_QUANTUM),
            round(point[2] / WELD_QUANTUM),
        )
        at = seen.get(key)
        if at is None:
            at = len(points)
            seen[key] = at
            points.append(point)
        weld.append(at)
    return weld, points


def plane_of(first: tuple, second: tuple, third: tuple) -> tuple[tuple | None, float]:
    """The unit plane through three points, and twice the area of their triangle.

    `(None, 0.0)` for a degenerate triangle, which has no plane to speak of and
    would contribute nothing to a quadric anyway.
    """
    along = (second[0] - first[0], second[1] - first[1], second[2] - first[2])
    across = (third[0] - first[0], third[1] - first[1], third[2] - first[2])
    normal = (
        along[1] * across[2] - along[2] * across[1],
        along[2] * across[0] - along[0] * across[2],
        along[0] * across[1] - along[1] * across[0],
    )
    length = sqrt(normal[0] ** 2 + normal[1] ** 2 + normal[2] ** 2)
    if length <= 0.0:
        return None, 0.0
    unit = (normal[0] / length, normal[1] / length, normal[2] / length)
    offset = -(unit[0] * first[0] + unit[1] * first[1] + unit[2] * first[2])
    return (unit[0], unit[1], unit[2], offset), length


def quadric_of(plane: tuple, weight: float) -> list[float]:
    """`weight` times the outer product of `plane` with itself, upper triangle only.

    Ten numbers rather than sixteen because the matrix is symmetric, in the order
    a², ab, ac, ad, b², bc, bd, c², cd, d² — which is the order `error_at` reads
    them back in and the only place that order is written down.
    """
    a, b, c, d = plane
    return [
        weight * a * a,
        weight * a * b,
        weight * a * c,
        weight * a * d,
        weight * b * b,
        weight * b * c,
        weight * b * d,
        weight * c * c,
        weight * c * d,
        weight * d * d,
    ]


def add_quadric(into: list[float], block: list[float]) -> None:
    for at in range(10):
        into[at] += block[at]


def error_at(quadric: list[float], point: tuple) -> float:
    """What `point` costs against `quadric` — the sum of squared plane distances."""
    x, y, z = point[0], point[1], point[2]
    return (
        quadric[0] * x * x
        + 2.0 * quadric[1] * x * y
        + 2.0 * quadric[2] * x * z
        + 2.0 * quadric[3] * x
        + quadric[4] * y * y
        + 2.0 * quadric[5] * y * z
        + 2.0 * quadric[6] * y
        + quadric[7] * z * z
        + 2.0 * quadric[8] * z
        + quadric[9]
    )


class Decimator:
    """One primitive's triangles, collapsed down to a triangle budget.

    Built from the flattened part — positions already in the game's own metres
    and the index buffer that draws them — and run once. What comes back is a
    new index buffer over the *same* vertices: every surviving corner keeps the
    exact POSITION, NORMAL and TEXCOORD_0 the artist gave it, because the only
    thing this class ever does is decide which vertices stop being referenced.

    That is the restriction the whole design turns on. The textbook collapse puts
    the survivor wherever the summed quadric is smallest, which is a new point
    with no UV of its own — and inventing one on a bottle wrapped in a printed
    label is how a decimator smears a wordmark. Collapsing onto an endpoint costs
    a little accuracy per collapse and buys exactness everywhere else: nothing is
    interpolated, so nothing can be interpolated wrongly.
    """

    def __init__(self, positions: list[tuple], uvs: list[tuple], indices: list[int]) -> None:
        self.uvs = uvs
        self.weld, self.at = welded(positions)
        # A triangle is carried twice over: once in weld ids, which is the
        # surface's own topology, and once in the vertex ids the file draws with,
        # which is what a UV seam splits. Every collapse has to keep both true.
        self.corners: list[list[int]] = []
        self.wedges: list[list[int]] = []
        for base in range(0, len(indices), 3):
            drawn = indices[base : base + 3]
            weld = [self.weld[at] for at in drawn]
            if weld[0] == weld[1] or weld[1] == weld[2] or weld[2] == weld[0]:
                continue
            self.corners.append(weld)
            self.wedges.append(list(drawn))
        self.alive = bytearray(b"\1" * len(self.corners))
        self.triangles = len(self.corners)
        self.faces: list[set[int]] = [set() for _ in self.at]
        for face, weld in enumerate(self.corners):
            for vertex in weld:
                self.faces[vertex].add(face)
        self.gone = bytearray(len(self.at))
        # A version per vertex, bumped whenever its quadric changes, so a stale
        # entry left in the heap by an earlier collapse is recognised and dropped
        # instead of being re-costed. Cheaper than finding and deleting it.
        self.stamp = [0] * len(self.at)
        self.border: set[int] = set()
        self.quadrics = self._quadrics()
        self.floor = UV_DENSITY_SLACK * self._thinnest()

    def _thinnest(self) -> float:
        """The least UV area per square metre any triangle of this part is drawn at.

        The floor `collapse` holds the texture to, read off the artist's own
        layout. Some parts are mapped far more sparsely than others — measured on
        this bottle, the body's sparsest triangle spreads 0.59 UV units² over a
        square metre and the nozzle's spreads 191 — so a single number written
        here would be six different amounts of nothing.
        """
        thinnest = float("inf")
        for face, wedge in enumerate(self.wedges):
            _, twice_area = plane_of(*(self.at[vertex] for vertex in self.corners[face]))
            if twice_area <= 0.0:
                continue
            thinnest = min(thinnest, self._uv_area(wedge) / twice_area)
        return 0.0 if thinnest == float("inf") else thinnest

    def _uv_area(self, wedge: list[int]) -> float:
        """Twice the area a triangle's three corners cover in texture space."""
        first, second, third = (self.uvs[at] for at in wedge)
        return abs(
            (second[0] - first[0]) * (third[1] - first[1])
            - (third[0] - first[0]) * (second[1] - first[1])
        )

    # -- setting up -------------------------------------------------------

    def _quadrics(self) -> list[list[float]]:
        """A quadric per weld vertex: its faces' planes, and its borders' walls.

        Faces are weighted by area, which is what makes the metric a measure of
        volume swept rather than of planes counted — a vertex in a dense patch of
        small triangles is not thereby more important than one holding a big
        flat. Borders get a second plane standing square to the surface along the
        open edge, weighted by [constant BORDER_PENALTY]: without it the two caps
        would be simplified from the rim inwards, because an open edge is the one
        place the faces alone say nothing.
        """
        quadrics: list[list[float]] = [[0.0] * 10 for _ in self.at]
        edges: dict[tuple[int, int], list[int]] = {}
        for face, weld in enumerate(self.corners):
            plane, twice_area = plane_of(*(self.at[vertex] for vertex in weld))
            if plane is not None:
                block = quadric_of(plane, twice_area)
                for vertex in weld:
                    add_quadric(quadrics[vertex], block)
            for corner in range(3):
                first, second = weld[corner], weld[(corner + 1) % 3]
                edges.setdefault((min(first, second), max(first, second)), []).append(face)
        for (first, second), faces in edges.items():
            if len(faces) != 1:
                continue
            self.border.add(first)
            self.border.add(second)
            plane, _ = plane_of(*(self.at[vertex] for vertex in self.corners[faces[0]]))
            if plane is None:
                continue
            here, there = self.at[first], self.at[second]
            along = (there[0] - here[0], there[1] - here[1], there[2] - here[2])
            wall, length = plane_of(here, there, (here[0] + plane[0], here[1] + plane[1], here[2] + plane[2]))
            if wall is None:
                continue
            weight = BORDER_PENALTY * (along[0] ** 2 + along[1] ** 2 + along[2] ** 2)
            block = quadric_of(wall, weight)
            add_quadric(quadrics[first], block)
            add_quadric(quadrics[second], block)
        return quadrics

    # -- running ----------------------------------------------------------

    def run(self, budget: int) -> list[int]:
        """Collapse until `budget` triangles are left, and return the index buffer.

        Cheapest first, out of a heap, which is the ordinary shape of this
        algorithm: a collapse changes what its neighbours cost, so the queue is
        re-offered around the survivor rather than rebuilt. A collapse that turns
        out to be illegal by the time it reaches the top is dropped rather than
        retried — its edge is offered again the next time either end moves, and
        an edge no legal collapse ever reaches is exactly one that should stay.
        """
        heap: list[tuple[float, int, int, int, int]] = []
        offered: set[tuple[int, int]] = set()
        for weld in self.corners:
            for corner in range(3):
                first, second = weld[corner], weld[(corner + 1) % 3]
                key = (min(first, second), max(first, second))
                if key in offered:
                    continue
                offered.add(key)
                self._offer(heap, first, second)
                self._offer(heap, second, first)
        while self.triangles > budget and heap:
            _, source, target, was_source, was_target = heappop(heap)
            if self.gone[source] or self.gone[target]:
                continue
            if self.stamp[source] != was_source or self.stamp[target] != was_target:
                continue
            if not self.collapse(source, target):
                continue
            self.stamp[target] += 1
            for face in list(self.faces[target]):
                for vertex in self.corners[face]:
                    if vertex != target:
                        self._offer(heap, vertex, target)
                        self._offer(heap, target, vertex)
        return self.indices()

    def _offer(self, heap: list, source: int, target: int) -> None:
        """Queue "remove `source`, keep `target`" at what that would cost."""
        summed = list(self.quadrics[source])
        add_quadric(summed, self.quadrics[target])
        cost = error_at(summed, self.at[target])
        heappush(heap, (cost, source, target, self.stamp[source], self.stamp[target]))

    def collapse(self, source: int, target: int) -> bool:
        """Remove `source` onto `target` if that is legal, and say whether it was.

        Five things have to hold, and each of them is a way a simplifier can
        quietly ruin an asset rather than crash:

          * **the seam has to survive.** `source` may be a UV seam vertex, which
            is two drawn vertices at one point. The two triangles either side of
            the collapsed edge say which of `target`'s drawn vertices each of
            them becomes; if that map does not reach every one of `source`'s
            wedges, or if two of them would land on one, the seam is being
            pinched and the collapse is refused. That is what stops a body vertex
            being pulled across the label's edge;
          * **an open border stays a border.** A vertex on the caps' rim may only
            be collapsed along the rim, never inwards, or the rim gains a notch;
          * **the link condition**, which is the standard test that a collapse
            leaves a surface rather than a pinched non-manifold seam: the
            vertices that neighbour both ends must be exactly the ones opposite
            the edge being collapsed;
          * **no triangle may fold**, which the quadric alone does not prevent —
            it measures distance from planes and is happily satisfied by a
            triangle turned inside out on one of them;
          * **no triangle may have its texturing pulled flat**, which the quadric
            cannot see at all: three corners that happen to be nearly collinear
            in UV draw a line of the map across a patch of bottle. `self.floor`
            is what that is measured against.
        """
        around = [face for face in self.faces[source] if self.alive[face]]
        shared = [face for face in around if target in self.corners[face]]
        if not shared or len(shared) > 2:
            return False
        if source in self.border and len(shared) != 1:
            return False
        # The wedge map, read off the triangles the collapse deletes.
        becomes: dict[int, int] = {}
        for face in shared:
            weld = self.corners[face]
            leaving = self.wedges[face][weld.index(source)]
            staying = self.wedges[face][weld.index(target)]
            if becomes.setdefault(leaving, staying) != staying:
                return False
        if len(set(becomes.values())) != len(becomes):
            return False
        for face in around:
            if self.wedges[face][self.corners[face].index(source)] not in becomes:
                return False
        # The link condition.
        mine = {vertex for face in around for vertex in self.corners[face]} - {source}
        theirs = {
            vertex for face in self.faces[target] if self.alive[face] for vertex in self.corners[face]
        } - {target}
        opposite = {vertex for face in shared for vertex in self.corners[face]} - {source, target}
        if mine & theirs != opposite:
            return False
        # The fold test, and the texture's own.
        landing = self.at[target]
        for face in around:
            if face in shared:
                continue
            weld = self.corners[face]
            was = [self.at[vertex] for vertex in weld]
            now = [landing if vertex == source else self.at[vertex] for vertex in weld]
            before, _ = plane_of(*was)
            after, now_area = plane_of(*now)
            if after is None or now_area < SLIVER_AREA:
                return False
            if before is not None:
                turned = before[0] * after[0] + before[1] * after[1] + before[2] * after[2]
                if turned < FLIP_LIMIT:
                    return False
            corner = weld.index(source)
            moved = list(self.wedges[face])
            moved[corner] = becomes[moved[corner]]
            if self._uv_area(moved) < self.floor * now_area:
                return False
        # Legal. Do it.
        for face in shared:
            self.alive[face] = 0
            self.triangles -= 1
            for vertex in self.corners[face]:
                self.faces[vertex].discard(face)
        for face in around:
            if not self.alive[face]:
                continue
            corner = self.corners[face].index(source)
            self.corners[face][corner] = target
            self.wedges[face][corner] = becomes[self.wedges[face][corner]]
            self.faces[target].add(face)
        self.faces[source].clear()
        self.gone[source] = 1
        add_quadric(self.quadrics[target], self.quadrics[source])
        return True

    def indices(self) -> list[int]:
        """What is left, as a flat index buffer over the vertices we were given."""
        drawn: list[int] = []
        for face, wedge in enumerate(self.wedges):
            if self.alive[face]:
                drawn += wedge
        return drawn


def compacted(
    positions: list[tuple], normals: list[tuple], uvs: list[tuple], indices: list[int]
) -> tuple[list[tuple], list[tuple], list[tuple], list[int]]:
    """The three attribute arrays with the vertices nothing draws any more dropped.

    In the order the index buffer first reaches them rather than in the source's
    own order, which is free here and is the ordering a vertex cache prefers.
    """
    seen: dict[int, int] = {}
    drawn: list[int] = []
    for at in indices:
        moved = seen.get(at)
        if moved is None:
            moved = len(seen)
            seen[at] = moved
        drawn.append(moved)
    kept = sorted(seen, key=lambda at: seen[at])
    return (
        [positions[at] for at in kept],
        [normals[at] for at in kept],
        [uvs[at] for at in kept],
        drawn,
    )


def budgets(counts: list[int], total_budget: int) -> list[int]:
    """`total_budget` triangles shared out in proportion to what each part has.

    Proportional rather than per-part hand tuning, because the artist already
    decided where this model's detail belongs — the body and the neck are two
    thirds of it — and a table of six numbers here would be a second opinion
    about that, drifting from the first the day the source is re-exported.
    """
    total = sum(counts)
    return [max(1, round(count * total_budget / total)) for count in counts]


# --------------------------------------------------------------------------
# Reading the source scene
# --------------------------------------------------------------------------


IDENTITY = [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0]


def parts_of(src: Source) -> list[tuple[str, dict, list[float]]]:
    """Every mesh in the download as (material name, primitive, world matrix).

    Walked from the scene roots so the ancestors' matrices are composed rather
    than ignored, and returned in the order the walk finds them — which is the
    source's own node order, and is therefore stable across runs.
    """
    found: list[tuple[str, dict, list[float]]] = []

    def walk(index: int, parent: list[float]) -> None:
        node = src.nodes[index]
        matrix = mat_mul(parent, node_matrix(node))
        if "mesh" in node:
            primitives = src.meshes[node["mesh"]]["primitives"]
            if len(primitives) != 1:
                raise AssertionError(f"{node.get('name')}: expected one primitive per part")
            assert_rigid(matrix, node.get("name", f"node {index}"))
            found.append((src.materials[primitives[0]["material"]]["name"], primitives[0], matrix))
        for child in node.get("children", []):
            walk(child, matrix)

    for root in src.gltf["scenes"][src.gltf.get("scene", 0)]["nodes"]:
        walk(root, IDENTITY)

    names = [name for name, _, _ in found]
    if names != list(PARTS):
        raise AssertionError(f"source parts are {names}, expected {list(PARTS)}")
    return found


def parts_of_bake(src: Source) -> list[tuple[str, dict, list[float]]]:
    """The same six parts, read back out of this script's own full-res output.

    See the docstring's "RUNNING THIS WITHOUT THE DOWNLOAD" for why that is a
    supported input. The flattening has already happened, so every matrix here is
    the identity and every primitive is a part — but the two things that make a
    re-bake meaningful rather than convenient are asserted rather than hoped for:
    the parts are the same six in the same order, and the geometry is still the
    artist's full resolution. That second check is what stops an already-simplified
    bottle being fed back in and simplified again, which would compound silently.
    """
    if len(src.gltf["nodes"]) != 1 or len(src.gltf["meshes"]) != 1:
        raise AssertionError("a re-bake source must be one node holding one mesh")
    found = [
        (src.materials[prim["material"]]["name"], prim, IDENTITY)
        for prim in src.gltf["meshes"][0]["primitives"]
    ]
    names = [name for name, _, _ in found]
    if names != list(PARTS):
        raise AssertionError(f"source parts are {names}, expected {list(PARTS)}")
    triangles = sum(src.gltf["accessors"][prim["indices"]]["count"] for _, prim, _ in found) // 3
    if triangles != FULL_TRIANGLES:
        raise AssertionError(
            f"the re-bake source holds {triangles} triangles, not the artist's {FULL_TRIANGLES}"
        )
    return found


def is_rebake(src: Source) -> bool:
    """Whether this source is a previous run of this script rather than the download."""
    return src.gltf["asset"].get("generator") == GENERATOR


def parts_in(src: Source) -> list[tuple[str, dict, list[float]]]:
    """The six parts of whichever of the two supported inputs `src` turned out to be."""
    return parts_of_bake(src) if is_rebake(src) else parts_of(src)


def attribution_of(src: Source) -> str:
    """The CC-BY line, composed from the credit Sketchfab wrote into the file.

    Read out of `asset.extras` rather than typed in here, because a credit
    somebody retyped is a credit that can be wrong — and this one is a licence
    condition, not a courtesy.
    """
    extras = src.gltf["asset"].get("extras", {})
    for key in ("title", "author", "license", "source"):
        if not extras.get(key):
            raise AssertionError(f"the source carries no {key} to credit")
    return (
        f'tire_cleaner.glb and window_cleaner.glb are processed derivatives of "{extras["title"]}"\n'
        f'({extras["source"]}) by {extras["author"]},\n'
        f'licensed under {extras["license"]}.\n'
        f"See scripts/build-tire-cleaner.py for what the processing does, and\n"
        f"scripts/build-window-cleaner.py for the recolour that makes the second\n"
        f"one out of the first.\n"
        f"\n"
        f"Every other model in this folder is the project's own.\n"
    )


# --------------------------------------------------------------------------
# Writing the output
# --------------------------------------------------------------------------


def resampled(png: bytes, size: int) -> bytes:
    """A source texture at `size` square, PNG in and PNG out.

    Lanczos down, and the alpha channel dropped when it is fully opaque — which
    every map in this source is, and carrying a fourth constant channel through
    to the GPU would cost a third of the texture memory for nothing.
    """
    image = Image.open(BytesIO(png))
    if image.mode == "RGBA" and image.getextrema()[3][0] == 255:
        image = image.convert("RGB")
    elif image.mode not in ("RGB", "RGBA"):
        image = image.convert("RGB")
    image = image.resize((size, size), Image.LANCZOS)
    out = BytesIO()
    image.save(out, format="PNG", optimize=True)
    return out.getvalue()


class Builder:
    """Accumulates the output glTF: buffer, accessors, materials, one mesh."""

    def __init__(self, src: Source, rebake: bool = False) -> None:
        self.src = src
        self.rebake = rebake
        self.blob = bytearray()
        self.views: list[dict] = []
        self.accessors: list[dict] = []
        self.materials: list[dict] = []
        self.textures: list[dict] = []
        self.images: list[dict] = []
        self._image_map: dict[int, int] = {}
        self.texture_bytes = 0

    # -- binary -----------------------------------------------------------

    def _view(self, payload: bytes, target: int | None = None, stride: int | None = None) -> int:
        self.blob += b"\0" * (-len(self.blob) % 4)
        view = {"buffer": 0, "byteOffset": len(self.blob), "byteLength": len(payload)}
        if target is not None:
            view["target"] = target
        if stride is not None:
            view["byteStride"] = stride
        self.blob += payload
        self.views.append(view)
        return len(self.views) - 1

    def add_vec3(self, values: list[tuple], with_bounds: bool) -> int:
        payload = b"".join(struct.pack("<fff", *v) for v in values)
        accessor = {
            "bufferView": self._view(payload, ARRAY_BUFFER, 12),
            "componentType": 5126,
            "count": len(values),
            "type": "VEC3",
        }
        if with_bounds:
            accessor["min"] = [min(v[i] for v in values) for i in range(3)]
            accessor["max"] = [max(v[i] for v in values) for i in range(3)]
        self.accessors.append(accessor)
        return len(self.accessors) - 1

    def add_vec2(self, values: list[tuple]) -> int:
        payload = b"".join(struct.pack("<ff", *v) for v in values)
        self.accessors.append(
            {
                "bufferView": self._view(payload, ARRAY_BUFFER, 8),
                "componentType": 5126,
                "count": len(values),
                "type": "VEC2",
            }
        )
        return len(self.accessors) - 1

    def add_indices(self, values: list[int], vertices: int) -> int:
        """Triangle indices, 16-bit when the primitive's vertices fit in 16 bits."""
        narrow = vertices < SHORT_INDEX_LIMIT
        payload = b"".join(struct.pack("<H" if narrow else "<I", v) for v in values)
        self.accessors.append(
            {
                "bufferView": self._view(payload, ELEMENT_ARRAY_BUFFER),
                "componentType": UNSIGNED_SHORT if narrow else UNSIGNED_INT,
                "count": len(values),
                "type": "SCALAR",
            }
        )
        return len(self.accessors) - 1

    # -- materials --------------------------------------------------------

    def _image(self, source_index: int, name: str) -> int:
        """One resampled texture, named so Godot's extracted sidecar is readable.

        The .glb.import sidecar extracts embedded images to <stem>_<name>.png
        beside the model, so these names are the file names in the repo. The
        source leaves every image unnamed, which would land them on disk as
        tire_cleaner_image_0.png and friends.
        """
        if source_index not in self._image_map:
            png = self.src.image_bytes(source_index)
            if self.rebake:
                # A re-bake's maps came out of this same function on the run that
                # wrote them, so they are already TEXTURE_PX and already opaque
                # RGB. Passed through byte for byte rather than resampled to the
                # size they are: that is what makes the two input routes agree on
                # the textures exactly, instead of agreeing on a re-encode of
                # them. Asserted, because "already the right size" is the whole
                # of the argument.
                width, height = Image.open(BytesIO(png)).size
                if (width, height) != (TEXTURE_PX, TEXTURE_PX):
                    raise AssertionError(f"{name}: a re-bake's map is {width}x{height}")
            else:
                png = resampled(png, TEXTURE_PX)
            self.texture_bytes += len(png)
            self.images.append({"bufferView": self._view(png), "mimeType": "image/png", "name": name})
            self._image_map[source_index] = len(self.images) - 1
        return self._image_map[source_index]

    def _texture(self, source_texture: int, name: str) -> int:
        texture = self.src.gltf["textures"][source_texture]
        entry = {"sampler": 0, "source": self._image(texture["source"], name)}
        for index, existing in enumerate(self.textures):
            if existing == entry:
                return index
        self.textures.append(entry)
        return len(self.textures) - 1

    def material(self, source_material: int, part: str) -> int:
        """Copy a source material across, resampling every texture it references.

        Copied rather than rebuilt: doubleSided, the metallic factor and the
        normal-map scale are all authored, and none of it is ours to reinvent.
        """
        material = json.loads(json.dumps(self.src.materials[source_material]))
        pbr = material.get("pbrMetallicRoughness", {})
        for slot, suffix in (("baseColorTexture", "albedo"), ("metallicRoughnessTexture", "orm")):
            if slot in pbr:
                pbr[slot] = {**pbr[slot], "index": self._texture(pbr[slot]["index"], f"{part}_{suffix}")}
        for slot, suffix in (("normalTexture", "normal"), ("emissiveTexture", "emissive")):
            if slot in material:
                material[slot] = {
                    **material[slot],
                    "index": self._texture(material[slot]["index"], f"{part}_{suffix}"),
                }
        self.materials.append(material)
        return len(self.materials) - 1


def build(src: Source) -> tuple[bytes, dict, dict]:
    """Flatten the six parts into one mesh, simplify each, return (blob, gltf, stats)."""
    parts = parts_in(src)
    builder = Builder(src, rebake=is_rebake(src))
    allowed = budgets(
        [src.gltf["accessors"][prim["indices"]]["count"] // 3 for _, prim, _ in parts],
        TRIANGLE_BUDGET,
    )
    primitives = []
    triangles = 0
    vertices = 0
    per_part: list[tuple[str, int, int]] = []
    for (name, prim, matrix), budget in zip(parts, allowed):
        attributes = prim["attributes"]
        positions = [apply(matrix, v) for v in src.accessor(attributes["POSITION"])]
        normals = [rotate(matrix, n) for n in src.accessor(attributes["NORMAL"])]
        uvs = src.accessor(attributes["TEXCOORD_0"])
        indices = [drawn[0] for drawn in src.accessor(prim["indices"])]
        was = len(indices) // 3
        positions, normals, uvs, indices = compacted(
            positions, normals, uvs, Decimator(positions, uvs, indices).run(budget)
        )
        per_part.append((name, was, len(indices) // 3))
        primitives.append(
            {
                "attributes": {
                    "POSITION": builder.add_vec3(positions, True),
                    "NORMAL": builder.add_vec3(normals, False),
                    "TEXCOORD_0": builder.add_vec2(uvs),
                },
                "indices": builder.add_indices(indices, len(positions)),
                "material": builder.material(prim["material"], PARTS[name]),
                "mode": prim.get("mode", 4),
            }
        )
        triangles += len(indices) // 3
        vertices += len(positions)

    gltf = {
        "asset": {"version": "2.0", "generator": GENERATOR, "extras": src.gltf["asset"].get("extras", {})},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        # One node, one mesh: exactly what ToolModel._first_mesh goes looking for.
        "nodes": [{"name": "Bottle", "mesh": 0}],
        "meshes": [{"name": "Bottle", "primitives": primitives}],
        "materials": builder.materials,
        "textures": builder.textures,
        "images": builder.images,
        "samplers": [src.gltf["samplers"][0]],
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.blob) + (-len(builder.blob) % 4)}],
    }
    stats = {
        "triangles": triangles,
        "vertices": vertices,
        "texture_bytes": builder.texture_bytes,
        "parts": per_part,
        "was": sum(before for _, before, _ in per_part),
    }
    return bytes(builder.blob), gltf, stats


# --------------------------------------------------------------------------


def verify(path: Path) -> tuple[list[float], list[float]]:
    """Re-parse the output and measure it, because writing it is not proving it."""
    gltf, _ = read_glb(path)
    if len(gltf["nodes"]) != 1 or "matrix" in gltf["nodes"][0]:
        raise AssertionError("the output must be a single mesh node at the origin")
    if len(gltf["meshes"]) != 1 or len(gltf["meshes"][0]["primitives"]) != len(PARTS):
        raise AssertionError(f"the output must be one mesh of {len(PARTS)} primitives")
    low = [float("inf")] * 3
    high = [float("-inf")] * 3
    triangles = 0
    for prim in gltf["meshes"][0]["primitives"]:
        accessor = gltf["accessors"][prim["attributes"]["POSITION"]]
        triangles += gltf["accessors"][prim["indices"]]["count"] // 3
        for axis in range(3):
            low[axis] = min(low[axis], accessor["min"][axis])
            high[axis] = max(high[axis], accessor["max"][axis])
    # One triangle of slack a part, because the budget is shared out by rounding
    # and six roundings can each go up. Asserted at all because the budget is the
    # whole point of the simplifier: a run that quietly stopped collapsing would
    # otherwise only show up as a 1.9 MB scene four commands later.
    if triangles > TRIANGLE_BUDGET + len(PARTS):
        raise AssertionError(f"the output holds {triangles} triangles, over the {TRIANGLE_BUDGET} budget")
    for axis, expected in enumerate(EXPECTED_SIZE_M):
        measured = high[axis] - low[axis]
        if abs(measured - expected) > SIZE_TOLERANCE_M:
            raise AssertionError(f"axis {axis} measured {measured:.4f} m, expected about {expected} m")
    if abs(low[1]) > SIZE_TOLERANCE_M:
        raise AssertionError(f"the bottle should stand on y = 0, not y = {low[1]:.4f}")
    return low, high


def main() -> int:
    parser = argparse.ArgumentParser(description="Bake the tyre cleaner's bottle from the source model.")
    parser.add_argument("--src", type=Path, default=SRC, help="source .glb (read only)")
    parser.add_argument("--out", type=Path, default=OUT, help="output .glb")
    args = parser.parse_args()

    src = Source(args.src)
    blob, gltf, stats = build(src)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    write_glb(args.out, gltf, blob)
    (args.out.parent / "ATTRIBUTION.txt").write_text(attribution_of(src), encoding="utf-8")
    low, high = verify(args.out)

    size = [high[axis] - low[axis] for axis in range(3)]
    print(f"{args.src.name}: {args.src.stat().st_size / 1024:.0f} KiB in")
    print(f"  parts      {len(PARTS)} -> 1 mesh of {len(PARTS)} primitives")
    for name, before, after in stats["parts"]:
        print(f"    {name:<8} {before:>6} -> {after:>5} triangles")
    print(
        f"  geometry   {stats['was']} -> {stats['triangles']} triangles"
        f" ({stats['triangles'] / stats['was']:.1%}), {stats['vertices']} vertices"
    )
    print(f"  textures   {len(gltf['images'])} at {TEXTURE_PX}px, {stats['texture_bytes'] / 1024:.0f} KiB")
    print(f"  bounds     {size[0] * 1000:.0f} x {size[1] * 1000:.0f} x {size[2] * 1000:.0f} mm, base at y = {low[1]:.4f}")
    print(f"{args.out.name}: {args.out.stat().st_size / 1024:.0f} KiB out")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Bake the ten cars of the generic passenger car pack into per-style .glb assets.

    scripts/build-car-pack.py            # src-models/... -> assets/models/cars/
    scripts/build-car-pack.py --help     # the two path overrides, for testing

Input is src-models/generic_passenger_car_pack/generic_passenger_car_pack.glb,
a Sketchfab FBX conversion holding all ten body styles, their forty wheels and
one display plinth in a single scene. src-models/ is READ-ONLY (see its
AGENTS.md): this script only ever opens it for reading.

Output is ten self-contained .glb files under assets/models/cars/ — one per
style — plus ATTRIBUTION.txt carrying the pack's CC-BY notice. Each output is
normalised so the game can treat every car identically:

  * seven nodes, named Body, Glass, Optics, Wheel1..Wheel4, and nothing else.
    Body, Glass and Optics are baked flat at the origin; the wheels keep a
    transform so their node origin stays on the axle, and they are numbered
    front-left, front-right, rear-left, rear-right;
  * +Z is the car's front, +Y is up, +X is therefore the car's left, the origin
    sits at mid-height, and the tyres rest on y = -height/2;
  * real-world metres, scaled from the sedan reference (4.3 x 1.9 x 1.4 m);
  * the Body base colour is baked to greyscale so the game tints the paint via
    albedo_color (decision 2 on #134). Glass, Optics and Wheel materials and
    textures pass through byte-for-byte.

Re-running is safe and produces byte-identical files: nothing here reads the
clock, iterates a set, or depends on dict ordering the interpreter chose.

Only Pillow is imported beyond the standard library, and only to decode and
re-encode PNG. The glTF itself is read and written with struct + json, because
a GLB is a 12-byte header and two length-prefixed chunks and a dependency for
that would cost more than it saves.


WHAT THE SOURCE SCENE ACTUALLY LOOKS LIKE (measured, not assumed)
-----------------------------------------------------------------
Everything below was read out of the file and is re-verified by assertions at
run time, so a re-exported pack fails loudly instead of producing quiet
nonsense.

Sketchfab_model -> *.fbx -> RootNode, and the two ancestors above RootNode
compose to a *uniform scale with identity rotation* (0.0009). So RootNode space
is already Y-up world space, and since we derive our own scale from measured
bounds we can ignore the ancestors entirely — after asserting they really are
scale-only.

Under RootNode sit 10 `<Style> Body` nodes, 40 `Wheel_*` nodes and one
`Cylinder001` plinth (discarded). Each body node has exactly three mesh
children: `_Body_0` (the painted shell), `_Glass_0` (untextured, alphaMode
BLEND) and `_Optics_0` (head- and tail-lights).

THE NAMES LIE, THE MATERIALS DON'T. Node names are duplicated across styles —
there are two separate `Wheel_E` sets (Pickup and SUV), two `Wheel_A` sets
(Sedan and Wagon) and a `Wheel_G001` that appears twice. Wheels are therefore
grouped by the material index of their wheel primitive, which is unique per
style (one of them is spelled "Wheek"; the typo is fixed on output). That
yields exactly ten groups of exactly four. Each group is then handed to the
nearest body node, which is unambiguous by a factor of twelve: the furthest
group centroid sits 443 units from its own body and 4365 from the next
nearest.

The SUV's wheels carry a second primitive using the SUV *body* material — a
body-coloured hub cap. It is kept on the wheel, and it shares the greyscale
body material, so a tinted SUV gets tinted hub caps for free.


THE CAR'S FRAME COMES FROM THE WHEELS, NOT FROM THE BODY NODE
-------------------------------------------------------------
Nine of the ten body nodes carry the same rotation as their wheels, so their
local axes are the car's axes. The Coupe does not: its body node rotation is
identity while its wheels are yawed 108 degrees, which means the coupe *mesh*
is authored yawed inside its own local space. Measuring its axis-aligned box in
body-local space reports a 4.73 x 2.82 m car — the bounding box of a car
standing at an angle, not a car.

So the frame is taken from the wheel nodes instead, which are consistent for
all ten styles: wheel local X is the axle (the mesh is thin along it), local Y
is longitudinal and local Z is up. All four wheels of a group share one
rotation, and their centres form a rectangle in that frame — both are asserted.
With the frame from the wheels the coupe measures 4.25 x 1.89 x 1.28 m, which
is a coupe.


WHICH END IS THE FRONT: ASK THE TAIL-LIGHTS
--------------------------------------------
There is no reliable geometric tell. Cabin position works for a sedan and
fails for a minivan; overhang lengths disagree with each other; and the
"bright" lamp lenses are useless because reversing lights are clear too — on
the Compact the white-lens centroid is at the *back*.

Red lenses are not ambiguous. Every optics vertex is sampled against the shared
optics atlas and weighted by its redness (R - max(G, B)); the weighted mean
longitudinal position of that red mass is the rear of the car. Across all ten
styles it lands 14% to 42% of the car's length behind centre — never near the
middle, never on the wrong side — and the answer was confirmed by rendering
orthographic side views of all ten. The script asserts a 5% margin.


SCALE: ONE FACTOR FOR THE WHOLE PACK, FITTED ON THE SEDAN
----------------------------------------------------------
The FBX conversion's units mean nothing (its root scale is a bare 0.0009), so
scale is derived from measured bounds against the reference sedan, 4.3 long x
1.9 wide x 1.4 m tall.

The three axes disagree slightly — 4.3/L, 1.9/W and 1.4/H differ by 6% — so the
factor is their geometric mean, which fits all three within 4% rather than
nailing one and letting the others drift.

That single factor is then applied to *every* style, deliberately. Fitting each
style to its own class target independently would erase the pack's internal
proportions: the artist modelled the compact smaller than the pickup, and
per-style scaling would flatten them towards each other, so the compact would
pull up next to the pickup at nearly the same size. The measured result of one
shared factor is a 3.26 m compact and a 5.19 m pickup, and every style lands
inside the per-class plausibility band asserted in PLAUSIBLE_LENGTH_M below —
that band is the gate, not the scale rule.

A pleasing coincidence, printed but never used: the factor fitted this way,
0.00089073, lands 0.23% from the 0.00088868 the FBX conversion happens to carry
on its root node. The pack really was modelled in metres. That is a cross-check
after the fact, not a source — a re-export with a different root scale should
change nothing here.


GREYSCALE BODY: DIVIDE OUT THE PAINT, KEEP THE SHADING
-------------------------------------------------------
The source liveries are saturated colours (cyan, blue, yellow, red, ...). A
straight luminance conversion would turn the blue car nearly black and the
yellow car nearly white, because luminance weights blue at 0.07 and green at
0.72 — the *paint colour* would survive as brightness, which is exactly what
must not happen when the game is going to supply the colour.

So the map is normalised: linear luminance divided by the luminance of the
style's own paint, which leaves shading, panel lines, dirt and decals and
removes the hue. Values above the paint plateau (baked highlights, chrome) are
not clipped but run into a smooth rational shoulder with matching slope, so
they compress into the top of the range instead of flattening to white.

Finding "the luminance of the paint" is the whole trick, and a percentile does
not do it. The paint is isolated by chroma — pixels with saturation above 0.25
— and the reference is the top of the *dominant cluster* of a 64-bin histogram
of those pixels, grown upward while neighbouring bins hold 20% of the peak.
The SUV forced this: its livery is already greyscale, so the chroma mask finds
nothing and the fallback mask (everything non-black) includes a white grille
and a bright lamp housing. Its body plateau sits at 8-bit 28..31 while the 90th
percentile of that mask is 129 — a percentile normalised the SUV four stops too
dark. The modal cluster puts it at 32, level with the other nine.

The plateau is placed at sRGB 0.85 rather than at white so a white tint reads
as white-ish paint while leaving headroom for the baked highlights above it. A
black tint reads black at any plateau; a light tint is the one that needs the
room.

The arithmetic runs through lookup tables — three 256-entry sRGB->linear tables
for the luminance sum, one 65k-entry table for shoulder + re-encode — so the
per-pixel work is four list indexings and two adds, and a 1024x1024 texture
bakes in well under a second without numpy (which this environment lacks).
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import sys
from io import BytesIO
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover - environment problem, not a code path
    sys.exit("Pillow is required: pip install pillow")

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "src-models/generic_passenger_car_pack/generic_passenger_car_pack.glb"
LICENSE_TXT = SRC.with_suffix(".txt")
OUT = REPO / "assets/models/cars"

# The sedan is the ruler. Everything else is measured against it.
SEDAN_REFERENCE_M = (4.3, 1.9, 1.4)  # length, width, height
REFERENCE_STYLE = "sedan"

# A gate, not a target: one shared scale factor is applied to every style (see
# the module docstring), and this is what proves the result stays sane. Bands
# are deliberately wide — they catch a scale that is wrong by a factor, not a
# car that is 200 mm short of its real-world twin.
PLAUSIBLE_LENGTH_M = {
    "compact": (2.8, 4.2),
    "coupe": (3.8, 5.0),
    "hatchback": (3.5, 4.6),
    "minivan": (4.2, 5.4),
    "offroad": (3.6, 5.0),
    "pickup": (4.8, 6.2),
    "sedan": (4.0, 5.2),
    "sport": (3.6, 4.8),
    "suv": (4.2, 5.4),
    "wagon": (4.2, 5.2),
}

# Greyscale bake tuning. See the docstring for why each of these is what it is.
PLATEAU_SRGB = 0.85  # where the paint lands, leaving room for highlights
SATURATION_MIN = 0.25  # (max-min)/max above this counts as "paint"
HISTOGRAM_BINS = 64  # over sRGB-encoded luminance
CLUSTER_SKIRT = 0.20  # grow the peak while neighbours hold this much of it
HISTOGRAM_STRIDE = 4  # every 4th pixel: 262k samples is plenty, and exact

# Front detection: the red mass must sit this far behind centre, as a fraction
# of the car's length, before we believe it.
FRONT_MARGIN = 0.05

# glTF component types we expect to meet in this file.
COMPONENT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
COMPONENT_COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER = 34962, 34963

GENERATOR = "done-rite-detailing scripts/build-car-pack.py"


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
        offset += 8 + size
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
    """The source pack, with the accessor plumbing hidden."""

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

    def image_bytes(self, index: int) -> tuple[bytes, str]:
        image = self.gltf["images"][index]
        view = self.gltf["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        return self.bin[start : start + view["byteLength"]], image["mimeType"]


# --------------------------------------------------------------------------
# Small 3D helpers. Everything in this file is a rigid transform plus one
# uniform scale, so a general 4x4 library would be dead weight.
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


def column(m: list[float], i: int) -> tuple[float, float, float]:
    return (m[i * 4], m[i * 4 + 1], m[i * 4 + 2])


def cross(a: tuple, b: tuple) -> tuple[float, float, float]:
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a: tuple, b: tuple) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def quaternion_of(basis: list[tuple]) -> list[float]:
    """(x, y, z, w) for an orthonormal, right-handed basis given as three columns.

    The four-branch form, not the naive one: the naive `w = sqrt(1+trace)/2`
    divides by w and blows up at a 180 degree rotation, which the yawed styles
    in this pack get close to.
    """
    (m00, m10, m20), (m01, m11, m21), (m02, m12, m22) = basis
    trace = m00 + m11 + m22
    if trace > 0:
        s = math.sqrt(trace + 1.0) * 2
        q = [(m21 - m12) / s, (m02 - m20) / s, (m10 - m01) / s, 0.25 * s]
    elif m00 > m11 and m00 > m22:
        s = math.sqrt(1.0 + m00 - m11 - m22) * 2
        q = [0.25 * s, (m01 + m10) / s, (m02 + m20) / s, (m21 - m12) / s]
    elif m11 > m22:
        s = math.sqrt(1.0 + m11 - m00 - m22) * 2
        q = [(m01 + m10) / s, 0.25 * s, (m12 + m21) / s, (m02 - m20) / s]
    else:
        s = math.sqrt(1.0 + m22 - m00 - m11) * 2
        q = [(m02 + m20) / s, (m12 + m21) / s, 0.25 * s, (m10 - m01) / s]
    norm = math.sqrt(sum(c * c for c in q))
    return [c / norm for c in q]


# --------------------------------------------------------------------------
# Reading the source scene
# --------------------------------------------------------------------------


def style_key(node_name: str) -> str:
    """"minivan body" -> "minivan", "SUV Body" -> "suv"."""
    return node_name.rsplit(" ", 1)[0].strip().lower()


def find_root(src: Source) -> tuple[dict, float]:
    """Return the node holding the cars, and assert its ancestors only scale.

    The two ancestors above RootNode are Sketchfab's axis fixes; composed they
    are a uniform scale with identity rotation, which is what lets the rest of
    this script treat RootNode space as Y-up world space. If a re-export ever
    changes that, this is where it stops.
    """
    scene = src.gltf["scenes"][src.gltf.get("scene", 0)]
    if len(scene["nodes"]) != 1:
        raise AssertionError(f"expected a single scene root, found {len(scene['nodes'])}")
    chain, node = [], scene["nodes"][0]
    combined = [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0]
    while True:
        entry = src.nodes[node]
        combined = mat_mul(combined, node_matrix(entry))
        chain.append(entry.get("name", "?"))
        children = entry.get("children", [])
        if len(children) != 1:
            break
        node = children[0]
    root = src.nodes[node]
    scales = [math.sqrt(dot(column(combined, i), column(combined, i))) for i in range(3)]
    for i in range(3):
        axis = [c / scales[i] for c in column(combined, i)]
        expected = [1.0 if j == i else 0.0 for j in range(3)]
        if max(abs(a - e) for a, e in zip(axis, expected)) > 1e-4:
            raise AssertionError(f"scene root {'/'.join(chain)} rotates; this script assumes scale only")
    if max(scales) - min(scales) > 1e-6 * max(scales):
        raise AssertionError(f"scene root scale is not uniform: {scales}")
    return root, scales[0]


def collect(src: Source, root: dict) -> tuple[dict[str, int], dict[int, list[int]]]:
    """Split RootNode's children into body nodes and wheel groups.

    Wheels are keyed by the material of their wheel primitive because the node
    names are not unique — see the module docstring.
    """
    bodies: dict[str, int] = {}
    groups: dict[int, list[int]] = {}
    for index in root["children"]:
        node = src.nodes[index]
        name = node.get("name", "")
        if name.lower().endswith("body"):
            key = style_key(name)
            if key in bodies:
                raise AssertionError(f"two body nodes claim style {key!r}")
            bodies[key] = index
        elif name.startswith("Wheel_"):
            wheel_materials = {
                prim["material"]
                for child in node.get("children", [])
                for prim in src.meshes[src.nodes[child]["mesh"]]["primitives"]
                if src.materials[prim["material"]]["name"].startswith("Whee")
            }
            if len(wheel_materials) != 1:
                raise AssertionError(f"{name} has {len(wheel_materials)} wheel materials, expected 1")
            groups.setdefault(wheel_materials.pop(), []).append(index)
    if len(bodies) != 10:
        raise AssertionError(f"expected 10 body styles, found {sorted(bodies)}")
    for material, wheels in sorted(groups.items()):
        if len(wheels) != 4:
            raise AssertionError(f"wheel material {material} has {len(wheels)} wheels, expected 4")
    return bodies, groups


def assign_wheels(src: Source, bodies: dict[str, int], groups: dict[int, list[int]]) -> dict[str, list[int]]:
    """Hand each wheel group to its nearest body node, and prove it isn't close."""
    origins = {key: apply(node_matrix(src.nodes[i]), (0, 0, 0)) for key, i in bodies.items()}
    owned: dict[str, list[int]] = {}
    for material, wheels in sorted(groups.items()):
        centre = tuple(sum(apply(node_matrix(src.nodes[w]), (0, 0, 0))[axis] for w in wheels) / 4 for axis in range(3))
        ranked = sorted(bodies, key=lambda key: sum((centre[a] - origins[key][a]) ** 2 for a in range(3)))
        near = math.dist(centre, origins[ranked[0]])
        rival = math.dist(centre, origins[ranked[1]])
        if rival < near * 4:
            raise AssertionError(f"wheel material {material} is ambiguous: {near:.0f} vs {rival:.0f}")
        if ranked[0] in owned:
            raise AssertionError(f"{ranked[0]} was handed two wheel groups")
        owned[ranked[0]] = sorted(wheels)
    if sorted(owned) != sorted(bodies):
        raise AssertionError("some style ended up without wheels")
    return owned


def body_parts(src: Source, body_index: int) -> dict[str, int]:
    """The three mesh children of a body node, keyed Body / Glass / Optics."""
    parts: dict[str, int] = {}
    for child in src.nodes[body_index].get("children", []):
        node = src.nodes[child]
        kind = node["name"].rsplit("_", 2)[-2]
        if kind not in ("Body", "Glass", "Optics"):
            raise AssertionError(f"unexpected body child {node['name']!r}")
        parts[kind] = node["mesh"]
    if sorted(parts) != ["Body", "Glass", "Optics"]:
        raise AssertionError(f"body node {body_index} has parts {sorted(parts)}")
    return parts


# --------------------------------------------------------------------------
# The normalised frame
# --------------------------------------------------------------------------


class Style:
    """One car: its frame, its measured size, and the meshes that make it up."""

    def __init__(self, src: Source, key: str, body_index: int, wheels: list[int], optics_sampler) -> None:
        self.key = key
        self.src = src
        self.body_index = body_index
        self.body_matrix = node_matrix(src.nodes[body_index])
        self.parts = body_parts(src, body_index)
        self.wheel_matrices = [node_matrix(src.nodes[w]) for w in wheels]
        self.wheel_meshes = [[src.nodes[c]["mesh"] for c in src.nodes[w].get("children", [])] for w in wheels]
        self._derive_frame()
        self._derive_bounds(optics_sampler)

    # -- frame ------------------------------------------------------------

    def _derive_frame(self) -> None:
        """Lateral / longitudinal / up axes, taken from the wheels (see docstring)."""
        first = self.wheel_matrices[0]
        for other in self.wheel_matrices[1:]:
            if max(abs(a - b) for a, b in zip(first[:11], other[:11])) > 1e-3:
                raise AssertionError(f"{self.key}: its four wheels disagree about which way the car points")
        self.lateral, self.longitudinal, self.up = (column(first, i) for i in range(3))
        if max(abs(a - b) for a, b in zip(self.up, (0.0, 1.0, 0.0))) > 1e-4:
            raise AssertionError(f"{self.key}: wheel up axis is {self.up}, expected +Y")

        # The four wheel centres must form a rectangle in that frame: two
        # distinct longitudinal values (the axles) and two lateral (the track).
        # This is the cross-check that the node rotation really is the car's
        # frame and not some inherited orientation that happens to look sane.
        centres = [apply(m, (0, 0, 0)) for m in self.wheel_matrices]
        lat = sorted(dot(c, self.lateral) for c in centres)
        lon = sorted(dot(c, self.longitudinal) for c in centres)
        self.track = (lat[2] + lat[3]) / 2 - (lat[0] + lat[1]) / 2
        self.wheelbase = (lon[2] + lon[3]) / 2 - (lon[0] + lon[1]) / 2
        if lat[1] - lat[0] > 0.05 * self.track or lat[3] - lat[2] > 0.05 * self.track:
            raise AssertionError(f"{self.key}: wheel centres are not a rectangle across the track")
        if lon[1] - lon[0] > 0.05 * self.wheelbase or lon[3] - lon[2] > 0.05 * self.wheelbase:
            raise AssertionError(f"{self.key}: wheel centres are not a rectangle along the wheelbase")
        if self.wheelbase <= self.track:
            raise AssertionError(f"{self.key}: wheelbase {self.wheelbase:.0f} <= track {self.track:.0f}")

    def _world_vertices(self):
        """Every vertex of the car, in RootNode space, as (matrix, positions)."""
        for mesh in self.parts.values():
            for prim in self.src.meshes[mesh]["primitives"]:
                yield self.body_matrix, self.src.accessor(prim["attributes"]["POSITION"])
        for matrix, meshes in zip(self.wheel_matrices, self.wheel_meshes):
            for mesh in meshes:
                for prim in self.src.meshes[mesh]["primitives"]:
                    yield matrix, self.src.accessor(prim["attributes"]["POSITION"])

    def _derive_bounds(self, optics_sampler) -> None:
        """Measure the car in its own frame, then decide which end is the front."""
        low = [math.inf] * 3
        high = [-math.inf] * 3
        for matrix, positions in self._world_vertices():
            for vertex in positions:
                world = apply(matrix, vertex)
                for axis, basis in enumerate((self.lateral, self.up, self.longitudinal)):
                    value = dot(world, basis)
                    low[axis] = min(low[axis], value)
                    high[axis] = max(high[axis], value)
        self.width, self.height, self.length = (high[i] - low[i] for i in range(3))
        centre = [(low[i] + high[i]) / 2 for i in range(3)]

        # Where is the red? Weighted mean longitudinal position of the
        # tail-light lenses; that end is the back.
        weight = 0.0
        moment = 0.0
        for prim in self.src.meshes[self.parts["Optics"]]["primitives"]:
            positions = self.src.accessor(prim["attributes"]["POSITION"])
            uvs = self.src.accessor(prim["attributes"]["TEXCOORD_0"])
            for vertex, uv in zip(positions, uvs):
                redness = optics_sampler(prim["material"], uv)
                if redness > 0.0:
                    weight += redness
                    moment += redness * dot(apply(self.body_matrix, vertex), self.longitudinal)
        if weight < 1.0:
            raise AssertionError(f"{self.key}: no red lenses found; cannot tell front from back")
        offset = (moment / weight - centre[2]) / self.length
        if abs(offset) < FRONT_MARGIN:
            raise AssertionError(f"{self.key}: tail-light mass sits {offset:.1%} off centre, too close to call")
        self.front_sign = -1.0 if offset > 0 else 1.0

        # +Z forward, +Y up, +X = Y x Z so the basis stays right-handed. With
        # the source's lateral x longitudinal = up, that works out to
        # axis_x = -front_sign * lateral, which is why the measured centre's
        # first component flips with the same sign as its third.
        self.axis_z = tuple(self.front_sign * c for c in self.longitudinal)
        self.axis_y = self.up
        self.axis_x = cross(self.axis_y, self.axis_z)
        self.centre = (-self.front_sign * centre[0], centre[1], self.front_sign * centre[2])

    def to_frame(self, world: tuple) -> tuple[float, float, float]:
        return (dot(world, self.axis_x), dot(world, self.axis_y), dot(world, self.axis_z))


def optics_sampler_factory(src: Source):
    """Sample a material's base colour texture at a UV and return its redness."""
    cache: dict[int, tuple] = {}

    def sampler(material_index: int, uv: tuple) -> float:
        material = src.materials[material_index]
        texture = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if texture is None:
            return 0.0
        source_index = src.gltf["textures"][texture["index"]]["source"]
        if source_index not in cache:
            data, _ = src.image_bytes(source_index)
            image = Image.open(BytesIO(data)).convert("RGB")
            # The image itself is kept: a pixel access object outlives its
            # Image only by luck.
            cache[source_index] = (image, image.load(), image.size)
        _, pixels, (width, height) = cache[source_index]
        # Nearest sample, UVs wrapped: the atlas has no seams worth filtering.
        x = int((uv[0] % 1.0) * (width - 1))
        y = int((uv[1] % 1.0) * (height - 1))
        red, green, blue = pixels[x, y]
        return max(0.0, (red - max(green, blue)) / 255.0)

    return sampler


# --------------------------------------------------------------------------
# Greyscale bake
# --------------------------------------------------------------------------


def srgb_to_linear(value: float) -> float:
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def linear_to_srgb(value: float) -> float:
    value = min(1.0, max(0.0, value))
    return 12.92 * value if value <= 0.0031308 else 1.055 * value ** (1 / 2.4) - 0.055


def bake_greyscale(png: bytes) -> tuple[bytes, float]:
    """Turn a coloured livery into a tintable greyscale albedo. See the docstring."""
    image = Image.open(BytesIO(png)).convert("RGB")
    width, height = image.size
    red, green, blue = (channel.tobytes() for channel in image.split())

    linear = [srgb_to_linear(i / 255.0) for i in range(256)]
    # Scaled so the three tables sum to at most 65535 for white.
    weight_r = [0.2126 * linear[i] * 65535.0 for i in range(256)]
    weight_g = [0.7152 * linear[i] * 65535.0 for i in range(256)]
    weight_b = [0.0722 * linear[i] * 65535.0 for i in range(256)]
    luminance = [int(weight_r[r] + weight_g[g] + weight_b[b]) for r, g, b in zip(red, green, blue)]

    bin_of = [min(HISTOGRAM_BINS - 1, int(linear_to_srgb(y / 65535.0) * HISTOGRAM_BINS)) for y in range(65536)]

    def histogram(require_chroma: bool) -> tuple[list[int], int]:
        bins = [0] * HISTOGRAM_BINS
        counted = 0
        for i in range(0, len(luminance), HISTOGRAM_STRIDE):
            top = max(red[i], green[i], blue[i])
            if top <= 16:  # unwrapped background, not part of the car
                continue
            if require_chroma and (top - min(red[i], green[i], blue[i])) / top <= SATURATION_MIN:
                continue
            bins[bin_of[luminance[i]]] += 1
            counted += 1
        return bins, counted

    bins, counted = histogram(True)
    samples = len(luminance) // HISTOGRAM_STRIDE
    if counted < samples // 100:
        # An already-greyscale livery (the SUV): nothing to key on but darkness.
        bins, counted = histogram(False)
    if counted == 0:
        raise AssertionError("body texture is entirely background")

    peak = max(range(HISTOGRAM_BINS), key=lambda i: bins[i])
    skirt = bins[peak] * CLUSTER_SKIRT
    top_bin = peak
    while top_bin + 1 < HISTOGRAM_BINS and bins[top_bin + 1] >= skirt:
        top_bin += 1
    paint = srgb_to_linear((top_bin + 1) / HISTOGRAM_BINS)

    # x = luminance / paint. Below the plateau it is a straight multiply; above
    # it, a rational shoulder with matching slope that approaches 1 but never
    # reaches it, so highlights compress instead of clipping flat.
    plateau = srgb_to_linear(PLATEAU_SRGB)
    head = 1.0 - plateau
    encode = bytearray(65536)
    for y in range(65536):
        x = (y / 65535.0) / paint
        shaped = plateau * min(x, 1.0) + head - (head * head) / (head + plateau * max(x - 1.0, 0.0))
        encode[y] = min(255, max(0, int(round(linear_to_srgb(shaped) * 255))))

    grey = Image.frombytes("L", (width, height), bytes(map(encode.__getitem__, luminance)))
    buffer = BytesIO()
    grey.save(buffer, "PNG", optimize=True)
    return buffer.getvalue(), paint


# --------------------------------------------------------------------------
# Writing one style
# --------------------------------------------------------------------------


class Builder:
    """Accumulates one output glTF: buffers, accessors, materials, meshes."""

    def __init__(self, src: Source) -> None:
        self.src = src
        self.blob = bytearray()
        self.views: list[dict] = []
        self.accessors: list[dict] = []
        self.materials: list[dict] = []
        self.textures: list[dict] = []
        self.images: list[dict] = []
        self.meshes: list[dict] = []
        self.nodes: list[dict] = []
        self._material_map: dict[int, int] = {}
        self._image_map: dict[int, int] = {}
        self._body_png: bytes | None = None
        self._body_source: int | None = None

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

    def add_indices(self, values: list[tuple]) -> int:
        payload = b"".join(struct.pack("<I", v[0]) for v in values)
        self.accessors.append(
            {
                "bufferView": self._view(payload, ELEMENT_ARRAY_BUFFER),
                "componentType": 5125,
                "count": len(values),
                "type": "SCALAR",
            }
        )
        return len(self.accessors) - 1

    # -- materials --------------------------------------------------------

    def set_body_texture(self, source_index: int, png: bytes) -> None:
        """Substitute the greyscale bake for this source image."""
        self._body_source = source_index
        self._body_png = png

    def _image(self, source_index: int) -> int:
        if source_index not in self._image_map:
            if source_index == self._body_source:
                data, mime = self._body_png, "image/png"
            else:
                data, mime = self.src.image_bytes(source_index)
            self.images.append({"bufferView": self._view(data), "mimeType": mime})
            self._image_map[source_index] = len(self.images) - 1
        return self._image_map[source_index]

    def _texture(self, source_texture: int) -> int:
        texture = self.src.gltf["textures"][source_texture]
        entry = {"source": self._image(texture["source"])}
        if "sampler" in texture:
            entry["sampler"] = 0
        for index, existing in enumerate(self.textures):
            if existing == entry:
                return index
        self.textures.append(entry)
        return len(self.textures) - 1

    def material(self, source_material: int, name: str) -> int:
        """Copy a source material across, remapping every texture reference.

        Copied rather than rebuilt: alphaMode BLEND on the glass, doubleSided
        on some optics, the per-style glass alpha — all of that is authored,
        and none of it is ours to reinvent. Only the name is normalised, which
        is how the "Wheek" typo stops travelling.
        """
        if source_material in self._material_map:
            return self._material_map[source_material]
        material = json.loads(json.dumps(self.src.materials[source_material]))
        material["name"] = name
        pbr = material.get("pbrMetallicRoughness", {})
        for slot in ("baseColorTexture", "metallicRoughnessTexture"):
            if slot in pbr:
                pbr[slot] = {**pbr[slot], "index": self._texture(pbr[slot]["index"])}
        for slot in ("normalTexture", "occlusionTexture", "emissiveTexture"):
            if slot in material:
                material[slot] = {**material[slot], "index": self._texture(material[slot]["index"])}
        self.materials.append(material)
        self._material_map[source_material] = len(self.materials) - 1
        return len(self.materials) - 1

    # -- meshes -----------------------------------------------------------

    def add_mesh(self, name: str, primitives: list[dict]) -> int:
        self.meshes.append({"name": name, "primitives": primitives})
        return len(self.meshes) - 1


def transform_mesh(
    builder: Builder,
    src: Source,
    mesh_index: int,
    position_of,
    normal_of,
    material_name,
) -> list[dict]:
    """Rewrite one source mesh's primitives into the builder, transformed."""
    primitives = []
    for prim in src.meshes[mesh_index]["primitives"]:
        attributes = prim["attributes"]
        positions = [position_of(v) for v in src.accessor(attributes["POSITION"])]
        normals = [normal_of(v) for v in src.accessor(attributes["NORMAL"])]
        uvs = src.accessor(attributes["TEXCOORD_0"])
        primitives.append(
            {
                "attributes": {
                    "POSITION": builder.add_vec3(positions, True),
                    "NORMAL": builder.add_vec3(normals, False),
                    "TEXCOORD_0": builder.add_vec2(uvs),
                },
                "indices": builder.add_indices(src.accessor(prim["indices"])),
                "material": builder.material(prim["material"], material_name(prim["material"])),
                "mode": prim.get("mode", 4),
            }
        )
    return primitives


def canonical_material_name(src: Source, material_index: int) -> str:
    """Body_5 -> Body, Wheek -> Wheel, Glass_2 -> Glass."""
    name = src.materials[material_index]["name"].rsplit("_", 1)
    base = name[0] if len(name) == 2 and name[1].isdigit() else src.materials[material_index]["name"]
    return "Wheel" if base == "Wheek" else base


def build_style(src: Source, style: Style, scale: float) -> tuple[bytes, dict, dict]:
    """Emit one normalised .glb for one body style."""
    builder = Builder(src)

    # The greyscale livery replaces the body's base colour image everywhere it
    # is referenced — including the SUV's body-coloured hub caps.
    body_material = src.meshes[style.parts["Body"]]["primitives"][0]["material"]
    body_texture = src.materials[body_material]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    body_image = src.gltf["textures"][body_texture]["source"]
    png, paint = bake_greyscale(src.image_bytes(body_image)[0])
    builder.set_body_texture(body_image, png)

    def name_of(material_index: int) -> str:
        return canonical_material_name(src, material_index)

    def place(matrix):
        """Vertex and normal mappings that take a mesh into the normalised frame."""
        return (
            lambda v: tuple(scale * (c - o) for c, o in zip(style.to_frame(apply(matrix, v)), style.centre)),
            lambda n: style.to_frame(rotate(matrix, n)),
        )

    nodes = []
    for kind in ("Body", "Glass", "Optics"):
        position_of, normal_of = place(style.body_matrix)
        primitives = transform_mesh(builder, src, style.parts[kind], position_of, normal_of, name_of)
        nodes.append({"name": kind, "mesh": builder.add_mesh(kind, primitives)})

    # Wheels keep a node transform instead of being baked flat: the node origin
    # stays on the axle and its local X stays the spin axis, so downstream scene
    # work can turn or steer a wheel without hunting for its centre. Only the
    # uniform scale is baked into the vertices, which leaves the node rigid.
    placed = []
    for matrix, meshes in zip(style.wheel_matrices, style.wheel_meshes):
        basis = [style.to_frame(column(matrix, i)) for i in range(3)]
        centre = style.to_frame(apply(matrix, (0, 0, 0)))
        translation = [scale * (c - o) for c, o in zip(centre, style.centre)]
        placed.append((translation, basis, meshes))
    # Wheel1..Wheel4 are front-left, front-right, rear-left, rear-right. +Z is
    # the front and +X is the car's left (right-handed, Y up, Z forward), so
    # that is descending Z then descending X.
    #
    # Split into axles FIRST and sort inside each. A single sort on (-z, -x)
    # looks equivalent and isn't: the sedan's two front wheels sit 16 source
    # units apart along Z, so the Z comparison decides the pair and the X
    # tie-break never runs — the sedan came out right-left at the front and
    # left-right at the back.
    placed.sort(key=lambda item: -item[0][2])
    axles = (placed[:2], placed[2:])
    gap = axles[0][0][0][2] - axles[1][0][0][2]
    for axle in axles:
        if abs(axle[0][0][2] - axle[1][0][2]) > 0.1 * gap:
            raise AssertionError(f"{style.key}: an axle's two wheels are not level along Z")
        axle.sort(key=lambda item: -item[0][0])
    placed = axles[0] + axles[1]
    for number, (translation, basis, meshes) in enumerate(placed, start=1):
        name = f"Wheel{number}"
        primitives = []
        for mesh in meshes:
            primitives += transform_mesh(
                builder, src, mesh, lambda v: tuple(scale * c for c in v), lambda n: n, name_of
            )
        nodes.append(
            {
                "name": name,
                "mesh": builder.add_mesh(name, primitives),
                "translation": translation,
                "rotation": quaternion_of(basis),
            }
        )

    gltf = {
        "asset": {
            "version": "2.0",
            "generator": GENERATOR,
            "extras": dict(src.gltf["asset"].get("extras", {})),
        },
        "scene": 0,
        "scenes": [{"name": style.key, "nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": builder.meshes,
        "materials": builder.materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.blob) + (-len(builder.blob) % 4)}],
    }
    if builder.textures:
        gltf["textures"] = builder.textures
        gltf["images"] = builder.images
        gltf["samplers"] = [dict(src.gltf["samplers"][0])]

    stats = {
        "length": style.length * scale,
        "width": style.width * scale,
        "height": style.height * scale,
        "wheelbase": style.wheelbase * scale,
        "track": style.track * scale,
        "paint": paint,
    }
    return bytes(builder.blob), gltf, stats


# --------------------------------------------------------------------------


def verify(path: Path, expected_nodes: list[str]) -> tuple[list[float], list[float], dict[str, float]]:
    """Re-parse an output and measure it, because writing it is not proving it.

    The bounds come from the accessors' own min/max, walked as box corners
    through each node's transform. That is exact rather than conservative here:
    every wheel node's rotation only permutes and flips axes, because the car's
    frame was derived from that very rotation.
    """
    gltf, _ = read_glb(path)
    names = [node["name"] for node in gltf["nodes"]]
    if names != expected_nodes:
        raise AssertionError(f"{path.name}: nodes are {names}, expected {expected_nodes}")
    low = [math.inf] * 3
    high = [-math.inf] * 3
    floor: dict[str, float] = {}
    for node in gltf["nodes"]:
        matrix = node_matrix(node)
        for prim in gltf["meshes"][node["mesh"]]["primitives"]:
            accessor = gltf["accessors"][prim["attributes"]["POSITION"]]
            for corner in range(8):
                point = tuple(accessor["min" if corner >> axis & 1 else "max"][axis] for axis in range(3))
                world = apply(matrix, point)
                floor[node["name"]] = min(floor.get(node["name"], math.inf), world[1])
                for axis in range(3):
                    low[axis] = min(low[axis], world[axis])
                    high[axis] = max(high[axis], world[axis])
    return low, high, floor


def main() -> int:
    parser = argparse.ArgumentParser(description="Bake per-style car assets from the source pack.")
    parser.add_argument("--src", type=Path, default=SRC, help="source .glb (read only)")
    parser.add_argument("--out", type=Path, default=OUT, help="output directory")
    args = parser.parse_args()

    src = Source(args.src)
    if len(src.gltf.get("samplers", [])) != 1:
        raise AssertionError("expected exactly one sampler; outputs reference sampler 0")
    root, root_scale = find_root(src)
    bodies, groups = collect(src, root)
    owned = assign_wheels(src, bodies, groups)
    sampler = optics_sampler_factory(src)

    styles = {key: Style(src, key, bodies[key], owned[key], sampler) for key in sorted(bodies)}
    if REFERENCE_STYLE not in styles:
        raise AssertionError(f"no {REFERENCE_STYLE} to scale against")

    # One factor for the whole pack, fitted on the sedan across all three axes.
    reference = styles[REFERENCE_STYLE]
    measured = (reference.length, reference.width, reference.height)
    ratios = [target / actual for target, actual in zip(SEDAN_REFERENCE_M, measured)]
    scale = math.exp(sum(math.log(r) for r in ratios) / 3)

    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "ATTRIBUTION.txt").write_bytes(LICENSE_TXT.read_bytes())

    expected_nodes = ["Body", "Glass", "Optics", "Wheel1", "Wheel2", "Wheel3", "Wheel4"]
    print(f"source root scale {root_scale:g} (ignored); pack scale {scale:.6g} units->m")
    print(f"sedan fit: length {ratios[0]:.6g}  width {ratios[1]:.6g}  height {ratios[2]:.6g}")
    print(f"{'style':10s} {'length':>7s} {'width':>7s} {'height':>7s} {'wheelbase':>9s} {'track':>6s} {'clear':>6s} {'paint':>7s}  size")
    for key, style in styles.items():
        blob, gltf, stats = build_style(src, style, scale)
        path = args.out / f"{key}.glb"
        write_glb(path, gltf, blob)
        low, high = PLAUSIBLE_LENGTH_M[key]
        if not low <= stats["length"] <= high:
            raise AssertionError(f"{key}: {stats['length']:.2f} m is outside the plausible band {low}-{high} m")
        low, high, floor = verify(path, expected_nodes)
        want = (stats["width"], stats["height"], stats["length"])
        for axis in range(3):
            got = high[axis] - low[axis]
            if abs(got - want[axis]) > 1e-3:
                raise AssertionError(f"{key}: axis {axis} measured {got:.4f} m on re-read, expected {want[axis]:.4f} m")
            # Centred on the origin, which is what "origin at mid-height" reduces to.
            if abs(low[axis] + high[axis]) > 1e-3:
                raise AssertionError(f"{key}: axis {axis} is off centre ({low[axis]:.4f} .. {high[axis]:.4f})")
        # The tyres, and only the tyres, define y = -height/2. Nothing in the
        # source guaranteed this — the sport car's ground clearance is 76 mm and
        # its two axles carry different wheel radii — so it is measured.
        tyres = [floor[f"Wheel{i}"] for i in range(1, 5)]
        if max(tyres) - min(tyres) > 5e-3:
            raise AssertionError(f"{key}: the four tyres do not share a floor ({tyres})")
        if abs(min(tyres) - low[1]) > 1e-3:
            raise AssertionError(f"{key}: tyres rest at {min(tyres):.4f} but the car reaches {low[1]:.4f}")
        clearance = min(floor[part] for part in ("Body", "Glass", "Optics")) - low[1]
        if clearance <= 0.0:
            raise AssertionError(f"{key}: the body hangs through the floor ({clearance:.4f} m)")
        stats["clearance"] = clearance
        print(
            f"{key:10s} {stats['length']:7.3f} {stats['width']:7.3f} {stats['height']:7.3f} "
            f"{stats['wheelbase']:9.3f} {stats['track']:6.3f} {stats['clearance']:6.3f} {stats['paint']:7.4f}  "
            f"{path.stat().st_size / 1024:.0f} KiB"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())

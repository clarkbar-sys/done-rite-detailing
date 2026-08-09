#!/usr/bin/env python3
"""Build the power wash wand — the tool DetailingTool.Id.POWER_WASH puts in the hand.

    scripts/build-pressure-washer.py          # -> assets/models/pressure_washer/
    scripts/build-pressure-washer.py --help   # the one path override, for testing

Output is assets/models/pressure_washer/pressure_washer.glb: one mesh, four
primitives, one 128x128 atlas and 348 triangles. There is no input. Every
other model in this repository is baked out of a download under src-models/;
this one is drawn here, in code, and the reasons are below.

WHY THIS ONE IS GENERATED AND NOT DOWNLOADED
---------------------------------------------
Two, and the second is the one that matters.

The first is that what shipped was a flamethrower. `homemade_flamethrower.glb`
was a Sketchfab download of exactly that, a pipe with a gas bottle strapped
across it, standing in for a pressure washer because it was the closest thing
going — and the joke wore through. Nothing about it says "water".

The second is that the nozzle has to be somewhere in particular, and a download
can only be there by luck. ViewModel hangs the `Muzzle` marker off
ToolCarry.nozzle(), which is the top of the catalogue's extent box *on the box's
own axis* — (0, extent.y / 2, 0) — and ToolSight fires WashJet from that marker.
ToolModel fits a mesh into that box by its bounding box, so the marker lands on
the model's tip only if the model's tip is the topmost point of its own box AND
sits on its X and Z centre. The flamethrower's did not: measured off the fitted
mesh, its barrel tip came out 46 mm off the box's axis in X and 121 mm in Z,
because the box was sized by a gas bottle hanging off one side. So the water
left a point in mid-air below the nozzle — which is what issue #162 reported,
and it was not a bug in the jet at all.

A model drawn to order can hold that invariant exactly, and this one does:

    the topmost point of this mesh is the centre of the nozzle's end face,
    it is at x = 0 and z = 0, and the mesh's bounding box is symmetric about
    both of those axes, so the fit and the centring cannot move it off them.

`verify()` re-reads the written file and refuses to leave it on disk if that
stops being true, and tests/integration/test_tool_model.gd asserts the same
property from the game's side, off the fitted mesh.

That invariant is also what makes the silhouette what it is. A pistol-gripped
trigger gun cannot satisfy it: a grip hangs 90 mm below the lance axis and
nothing balances it above, so the box's centre sits below the barrel and the
tip is off-axis by half the grip. So this is an inline wand — a lance with a
moulded grip section around it, a trigger and guard under the body and a safety
catch over it — which is a real shape (it is what a turbo lance or a soft-wash
wand looks like), is the shape the game's own primitive was for two years, and
puts the two things that set the depth of the box, the guard and the catch, an
equal 30 mm either side of the axis. They are the only two parts that reach
z = +/-DEPTH_HALF, and they are written as that constant rather than as numbers
that happen to match.

AUTHORED AT THE SIZE THE GAME HOLDS IT
---------------------------------------
The other three models arrive at whatever scale their artist saved and ToolModel
throws it away — see that class on why it reads the mesh's own box. This one is
drawn at exactly DetailingTool's extent for the power wash, 42 x 550 x 60 mm, so
the fit works out as the identity and the centring as zero. Nothing about
ToolModel changes for that, and nothing depends on it: re-scale this file and
the tool in the hand does not move. What it buys is that the numbers below are
the numbers you can measure on screen, and that the one place the model and the
catalogue have to agree — the length that puts the nozzle at the marker — is
agreement between two literals rather than the outcome of a division.

THE ATLAS
----------
One 128x128 image, four 64x64 cells, and four materials that all sample it and
differ in their metallic and roughness factors. Cheaper than four textures and
it keeps the "every modelled surface wears a texture" contract that
tests/integration/test_tool_model.gd holds every tool to — a wand painted with
four baseColorFactors would be a coloured cylinder with extra steps.

What is in the cells is what a flat colour cannot do: the steel is brushed
along the lance because its streaks are drawn down the cell and the tube's V
runs along its own axis; the grip's ribs are rings around it for the same
reason, read the other way; the polymer is speckled and the accent is graded.
Everything is drawn from a deterministic integer hash, so a re-run produces the
file byte for byte.

Only the standard library is used — zlib and struct write the PNG, struct and
json write the GLB, the same way scripts/build-car-pack.py does it. Pillow is
not imported because there is no image to resample: this one is drawn a pixel at
a time and there are 16,384 of them.
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import sys
import zlib
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets/models/pressure_washer/pressure_washer.glb"

GENERATOR = "done-rite-detailing scripts/build-pressure-washer.py"

# The box the tool occupies in the player's hands, in metres, and the whole
# reason this file is drawn at game scale — see the docstring. It is
# DetailingTool.catalogue()'s extent for Id.POWER_WASH and the two must agree:
# `verify()` measures the written mesh against it, and a change here without the
# matching change there puts the nozzle marker off the end of the wand.
WIDTH, LENGTH, DEPTH = 0.042, 0.550, 0.060
HALF_WIDTH, HALF_LENGTH, HALF_DEPTH = WIDTH / 2, LENGTH / 2, DEPTH / 2

# How many sides every round part is drawn with. Twelve, and not for the
# triangle count: a 12-gon has vertices at 0, 90, 180 and 270 degrees, so its
# extreme in X and its extreme in Z are both exactly its radius. An odd count, or
# one not divisible by four, would put the widest point of the grip between two
# vertices and the mesh's box would come out a fraction under the radius it was
# drawn at — which the catalogue would then be describing incorrectly.
SIDES = 12

# Where the two ends of the wand are. The nozzle's end face is the top of the
# box and the hose swivel is the bottom of it, so these are the two numbers that
# make the mesh exactly LENGTH long.
TIP_Y = HALF_LENGTH
BUTT_Y = -HALF_LENGTH

# How wide the end face of the nozzle is allowed to be, in metres, for `verify()`
# to still call it a nozzle. A shade over WashJet.NOZZLE's centimetre-wide hole,
# doubled for a diameter: what is being ruled out is a model whose topmost face
# is a bottle's shoulder or a strap's buckle sitting square on the axis, which
# would satisfy the centring check and still not be somewhere water comes from.
NOZZLE_WIDE = 0.025

# The four cells of the atlas, as (column, row) in a 2x2 grid.
STEEL, POLYMER, RUBBER, ACCENT = "steel", "polymer", "rubber", "accent"
CELLS = {STEEL: (0, 0), POLYMER: (1, 0), RUBBER: (0, 1), ACCENT: (1, 1)}

# Half the atlas, in pixels, and how far inside its own cell a UV is allowed to
# get. The inset is two texels at the size below: enough that a mip of the atlas
# cannot bleed the orange accent onto the steel, and small enough to be invisible
# on a part 9 mm across.
CELL_PX = 64
INSET = 2.0 / CELL_PX

# What the four cells are made of: a base colour and how it is broken up. See the
# docstring — the pattern is chosen so that it lands the right way round on the
# part that wears it once the UVs below run V along each part's own long axis.
PALETTE = {
    STEEL: (158, 166, 178),
    POLYMER: (30, 32, 37),
    RUBBER: (20, 21, 24),
    ACCENT: (214, 100, 18),
}

# How the four materials answer light. The steel is the catalogue's own metal —
# see DetailingTool.catalogue(), where the power wash is the one tool on the belt
# with a metallic finish — and the other three are what they say they are.
FINISH = {
    STEEL: (0.90, 0.28),
    POLYMER: (0.0, 0.55),
    RUBBER: (0.0, 0.92),
    ACCENT: (0.05, 0.42),
}

# glTF's component types and the two buffer targets, spelled out rather than
# imported: this file writes them and never reads anybody else's.
FLOAT, UNSIGNED_SHORT = 5126, 5123
ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER = 34962, 34963


# --------------------------------------------------------------------------
# The atlas
# --------------------------------------------------------------------------


def noise(x: int, y: int, salt: int) -> int:
    """A repeatable -128..127 out of a pixel and a salt.

    An integer hash rather than `random`, so that a re-run of this script — on
    another machine, another Python — writes the same bytes. The constants are
    the usual odd multipliers; nothing about the pattern needs them to be these
    ones, only for them to be the same ones every time.
    """
    h = (x * 374761393 + y * 668265263 + salt * 2246822519) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFF) - 128


def shade(base: tuple[int, int, int], by: float) -> tuple[int, int, int]:
    """[param base] lightened or darkened by [param by] in -1..1, clamped."""
    return tuple(max(0, min(255, int(round(channel + channel * by)))) for channel in base)


def cell_pixels(kind: str) -> list[list[tuple[int, int, int]]]:
    """One 64x64 cell, drawn.

    Four patterns, and each is chosen for the part it ends up on rather than for
    how it looks flat: streaks down the cell become brushing along the lance,
    bands across it become ribs around the grip.
    """
    base = PALETTE[kind]
    rows = []
    for y in range(CELL_PX):
        row = []
        for x in range(CELL_PX):
            if kind == STEEL:
                # Brushed: a per-column bias that runs the whole height of the
                # cell, plus a little per-pixel grain so it is not a barcode.
                by = noise(x, 0, 11) / 900.0 + noise(x, y, 12) / 4000.0
            elif kind == POLYMER:
                by = noise(x, y, 21) / 700.0
            elif kind == RUBBER:
                # Ribs: a band every eight texels, with the moulding's own
                # roughness on top so the bands are not perfect.
                rib = 0.22 if (y % 8) < 3 else -0.10
                by = rib + noise(x, y, 31) / 900.0
            else:
                # Graded, so a moulded plastic part catches the light along its
                # length instead of reading as a sticker.
                by = 0.18 - 0.36 * (y / (CELL_PX - 1)) + noise(x, y, 41) / 2000.0
            row.append(shade(base, by))
        rows.append(row)
    return rows


def atlas_png() -> bytes:
    """The whole atlas as PNG bytes: 2x2 cells, laid out by CELLS."""
    size = CELL_PX * 2
    pixels = [[(0, 0, 0)] * size for _ in range(size)]
    for kind, (column, row) in CELLS.items():
        drawn = cell_pixels(kind)
        for y in range(CELL_PX):
            for x in range(CELL_PX):
                pixels[row * CELL_PX + y][column * CELL_PX + x] = drawn[y][x]
    raw = bytearray()
    for row in pixels:
        raw.append(0)  # filter type 0: this image is small and compresses fine
        for red, green, blue in row:
            raw += bytes((red, green, blue))

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + kind
            + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
        )

    header = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def in_cell(kind: str, u: float, v: float) -> tuple[float, float]:
    """A part's own 0..1 surface coordinate, placed inside [param kind]'s cell."""
    column, row = CELLS[kind]
    inside = INSET + (1.0 - 2.0 * INSET) * min(max(u, 0.0), 1.0)
    down = INSET + (1.0 - 2.0 * INSET) * min(max(v, 0.0), 1.0)
    return ((column + inside) / 2.0, (row + down) / 2.0)


# --------------------------------------------------------------------------
# The mesh
# --------------------------------------------------------------------------


def minus(a: tuple, b: tuple) -> tuple[float, float, float]:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a: tuple, b: tuple) -> tuple[float, float, float]:
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a: tuple, b: tuple) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def unit(v: tuple) -> tuple[float, float, float]:
    length = math.sqrt(dot(v, v))
    if length == 0.0:
        raise ValueError("a zero-length normal — two vertices of a face are the same point")
    return (v[0] / length, v[1] / length, v[2] / length)


class Part:
    """One material's worth of geometry, accumulated face by face.

    Vertices are never shared between faces. This is a 350-triangle model whose
    largest surface is 9 mm across on screen, so the few hundred duplicated
    positions cost nothing worth the bookkeeping — and it means a face carries
    its own normals and its own UVs without any of the seam-splitting a shared
    array would need where the cylinders wrap.
    """

    def __init__(self) -> None:
        self.positions: list[tuple[float, float, float]] = []
        self.normals: list[tuple[float, float, float]] = []
        self.uvs: list[tuple[float, float]] = []
        self.indices: list[int] = []

    def face(self, corners: list[tuple], normals: list[tuple], uvs: list[tuple]) -> None:
        """One polygon — three corners or four — wound so that its front side is
        the one its normals face.

        The winding is worked out here rather than by hand at each call: the
        geometric normal of the corners as given is compared with the normals the
        caller supplied, and the order is reversed if they disagree. glTF's front
        face is the counter-clockwise one, so getting this wrong on any of the
        hundred-odd faces below would leave a hole in the wand that is only
        visible from one side.
        """
        facing = (
            sum(normal[0] for normal in normals),
            sum(normal[1] for normal in normals),
            sum(normal[2] for normal in normals),
        )
        wound = cross(minus(corners[1], corners[0]), minus(corners[2], corners[0]))
        order = list(range(len(corners)))
        if dot(wound, facing) <= 0.0:
            order.reverse()
        first = len(self.positions)
        for at in order:
            self.positions.append(corners[at])
            self.normals.append(unit(normals[at]))
            self.uvs.append(uvs[at])
        self.indices += [first, first + 1, first + 2]
        if len(corners) == 4:
            self.indices += [first, first + 2, first + 3]


class Wand:
    """The parts of the wand, one accumulator per material."""

    def __init__(self) -> None:
        self.parts: dict[str, Part] = {kind: Part() for kind in CELLS}

    # -- primitives ---------------------------------------------------------

    def tube(
        self,
        kind: str,
        bottom_y: float,
        top_y: float,
        bottom_r: float,
        top_r: float,
        cap_bottom: bool = True,
        cap_top: bool = True,
    ) -> None:
        """A round section of the wand, from [param bottom_y] to [param top_y].

        Smooth around and flat across the caps, which is what makes a 12-sided
        prism read as a pipe. Every round part of a pressure washer is one of
        these: the lance, the nozzle, the grip section and the hose swivel.
        """
        part = self.parts[kind]
        rise, spread = top_y - bottom_y, top_r - bottom_r
        ring = []
        for step in range(SIDES + 1):
            angle = 2.0 * math.pi * step / SIDES
            across, along = math.cos(angle), math.sin(angle)
            # See the docstring on the taper: the side's normal leans by however
            # much the radius changes over the run, which is what keeps a cone's
            # lighting off a cylinder's.
            ring.append((across, along, unit((across * rise, -spread, along * rise))))
        for step in range(SIDES):
            near, far = ring[step], ring[step + 1]
            corners = [
                (near[0] * bottom_r, bottom_y, near[1] * bottom_r),
                (far[0] * bottom_r, bottom_y, far[1] * bottom_r),
                (far[0] * top_r, top_y, far[1] * top_r),
                (near[0] * top_r, top_y, near[1] * top_r),
            ]
            left, right = step / SIDES, (step + 1) / SIDES
            uvs = [
                in_cell(kind, left, 0.0),
                in_cell(kind, right, 0.0),
                in_cell(kind, right, 1.0),
                in_cell(kind, left, 1.0),
            ]
            self.face(kind, corners, [near[2], far[2], far[2], near[2]], uvs)
        for capped, y, radius, up in ((cap_top, top_y, top_r, 1.0), (cap_bottom, bottom_y, bottom_r, -1.0)):
            if not capped or radius <= 0.0:
                continue
            normal = (0.0, up, 0.0)
            for step in range(SIDES):
                near, far = ring[step], ring[step + 1]
                # A fan from the axis, and the one place a face here is a
                # triangle rather than a quad. Its UVs are the disc drawn into
                # the middle of the cell, so the end of the nozzle wears the same
                # brushing as the tube it is the end of.
                corners = [
                    (0.0, y, 0.0),
                    (near[0] * radius, y, near[1] * radius),
                    (far[0] * radius, y, far[1] * radius),
                ]
                uvs = [
                    in_cell(kind, 0.5, 0.5),
                    in_cell(kind, 0.5 + 0.5 * near[0], 0.5 + 0.5 * near[1]),
                    in_cell(kind, 0.5 + 0.5 * far[0], 0.5 + 0.5 * far[1]),
                ]
                part.face(corners, [normal] * 3, uvs)

    def block(
        self,
        kind: str,
        x: tuple[float, float],
        y: tuple[float, float],
        z: tuple[float, float],
    ) -> None:
        """A box, given as its three spans. The trigger, its guard and the catch."""
        low = (x[0], y[0], z[0])
        high = (x[1], y[1], z[1])
        for axis in range(3):
            for side in (0, 1):
                normal = [0.0, 0.0, 0.0]
                normal[axis] = -1.0 if side == 0 else 1.0
                fixed = low[axis] if side == 0 else high[axis]
                first, second = (axis + 1) % 3, (axis + 2) % 3
                corners = []
                for u, v in ((0, 0), (1, 0), (1, 1), (0, 1)):
                    corner = [0.0, 0.0, 0.0]
                    corner[axis] = fixed
                    corner[first] = high[first] if u else low[first]
                    corner[second] = high[second] if v else low[second]
                    corners.append(tuple(corner))
                uvs = [in_cell(kind, u, v) for u, v in ((0, 0), (1, 0), (1, 1), (0, 1))]
                self.face(kind, corners, [tuple(normal)] * 4, uvs)

    def face(self, kind: str, corners: list[tuple], normals: list[tuple], uvs: list[tuple]) -> None:
        self.parts[kind].face(corners, normals, uvs)


def draw() -> Wand:
    """The wand itself, bottom to top.

    Read down the Y axis and this is the tool: a hose swivel at the butt, a
    moulded grip the hand closes around, the body with its trigger under it and
    its safety catch over it, the lance, and the nozzle at the top. The two
    numbers every part is placed against are HALF_LENGTH — the ends — and
    HALF_DEPTH, which only the guard and the catch are allowed to reach.
    """
    wand = Wand()

    # The hose end. Wide and blunt on purpose as well as truthfully: it is the
    # half of "the wand is thinnest where the water leaves" that the game
    # measures rather than the artist's word for it — see
    # tests/integration/test_tool_model.gd.
    wand.tube(STEEL, BUTT_Y, BUTT_Y + 0.035, 0.017, 0.018)
    wand.tube(STEEL, BUTT_Y + 0.035, -0.152, 0.0125, 0.0125, cap_bottom=False)

    # The grip: the widest thing on the wand, and what sets the box's width. A
    # 12-gon of this radius has a vertex at 0 and at 180 degrees, so the box is
    # exactly WIDTH across (see SIDES). Capped at both ends rather than sleeved
    # over the body — every part below meets its neighbour end to end, so there
    # is no ring of daylight anywhere down the wand.
    wand.tube(RUBBER, -0.152, -0.070, HALF_WIDTH, HALF_WIDTH)
    # The body above it, a shade narrower so the grip reads as a separate part
    # rather than as a stripe painted on one.
    wand.tube(POLYMER, -0.070, -0.010, 0.019, 0.019, cap_bottom=False)

    # The trigger, and the guard around it: a bar under the trigger on two short
    # struts up into the body. The bar's underside is the deepest point of the
    # whole model.
    wand.block(ACCENT, (-0.009, 0.009), (-0.122, -0.062), (-0.025, -0.017))
    wand.block(POLYMER, (-0.010, 0.010), (-0.135, -0.050), (-HALF_DEPTH, -0.026))
    wand.block(POLYMER, (-0.010, 0.010), (-0.060, -0.050), (-HALF_DEPTH, -0.010))
    wand.block(POLYMER, (-0.010, 0.010), (-0.135, -0.125), (-HALF_DEPTH, -0.010))
    # The safety catch over the body, which is the other one — the same 30 mm on
    # the other side of the axis, which is what makes the box symmetric about it
    # and the nozzle marker land on the nozzle. See the module docstring.
    wand.block(ACCENT, (-0.009, 0.009), (-0.060, -0.030), (0.019, HALF_DEPTH))

    # The lance, out of the body and up to the nozzle.
    wand.tube(STEEL, -0.020, 0.180, 0.0088, 0.0088, cap_bottom=False)
    # The quick-connect coupler: the one part of a pressure washer that is always
    # a colour, because the colour is what says which fan angle is fitted.
    wand.tube(ACCENT, 0.176, 0.210, 0.0125, 0.0125)
    # And the nozzle, tapering to the end face the water leaves. Its top is
    # TIP_Y, on the axis, and everything in this file is arranged so that no
    # other vertex is higher and nothing pulls the box's centre off it.
    wand.tube(STEEL, 0.206, TIP_Y, 0.0075, 0.0058, cap_bottom=False)
    return wand


# --------------------------------------------------------------------------
# GLB container
# --------------------------------------------------------------------------


class Builder:
    """Accessors, buffer views and the blob they point into."""

    def __init__(self) -> None:
        self.blob = bytearray()
        self.views: list[dict] = []
        self.accessors: list[dict] = []

    def _view(self, payload: bytes, target: int) -> int:
        while len(self.blob) % 4:
            self.blob.append(0)
        self.views.append(
            {"buffer": 0, "byteOffset": len(self.blob), "byteLength": len(payload), "target": target}
        )
        self.blob += payload
        return len(self.views) - 1

    def vectors(self, values: list[tuple], kind: str, bounded: bool) -> int:
        """A VEC2 or VEC3 float accessor. `bounded` writes the min/max glTF wants
        on POSITION — and which `verify()` then reads the mesh's box back out of."""
        wide = len(values[0])
        payload = b"".join(struct.pack("<" + "f" * wide, *value) for value in values)
        accessor = {
            "bufferView": self._view(payload, ARRAY_BUFFER),
            "componentType": FLOAT,
            "count": len(values),
            "type": kind,
        }
        if bounded:
            accessor["min"] = [min(value[axis] for value in values) for axis in range(wide)]
            accessor["max"] = [max(value[axis] for value in values) for axis in range(wide)]
        self.accessors.append(accessor)
        return len(self.accessors) - 1

    def indices(self, values: list[int]) -> int:
        """A 16-bit index accessor. Every part here is a few hundred vertices, so
        the narrow form always fits — asserted rather than assumed."""
        if max(values) >= 65536:
            raise AssertionError("a part outgrew 16-bit indices")
        payload = struct.pack("<" + "H" * len(values), *values)
        self.accessors.append(
            {
                "bufferView": self._view(payload, ELEMENT_ARRAY_BUFFER),
                "componentType": UNSIGNED_SHORT,
                "count": len(values),
                "type": "SCALAR",
            }
        )
        return len(self.accessors) - 1

    def image(self, png: bytes) -> int:
        return self._view(png, ARRAY_BUFFER)


def write_glb(path: Path, gltf: dict, binary: bytes) -> None:
    """Write a .glb. Keys are sorted and separators fixed so the bytes are stable."""
    text = json.dumps(gltf, sort_keys=True, separators=(",", ":")).encode("utf-8")
    text += b" " * (-len(text) % 4)
    blob = binary + b"\0" * (-len(binary) % 4)
    total = 12 + 8 + len(text) + (8 + len(blob) if blob else 0)
    out = bytearray()
    out += struct.pack("<III", 0x46546C67, 2, total)
    out += struct.pack("<II", len(text), 0x4E4F534A) + text
    out += struct.pack("<II", len(blob), 0x004E4942) + blob
    path.write_bytes(bytes(out))


def read_glb(path: Path) -> tuple[dict, bytes]:
    """Split a .glb back into its JSON chunk and its binary chunk."""
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


def assemble(wand: Wand) -> tuple[bytes, dict, dict]:
    """Everything above, as one mesh of one primitive per material."""
    builder = Builder()
    png = atlas_png()
    image = builder.image(png)
    primitives, materials, triangles, vertices = [], [], 0, 0
    # Sorted, not dict order, so the primitives come out in the same order on any
    # interpreter — the file is meant to be byte-identical between runs.
    for kind in sorted(CELLS):
        part = wand.parts[kind]
        if not part.positions:
            raise AssertionError(f"nothing was drawn in {kind}")
        metallic, roughness = FINISH[kind]
        materials.append(
            {
                "name": f"wand_{kind}",
                "pbrMetallicRoughness": {
                    "baseColorTexture": {"index": 0},
                    "metallicFactor": metallic,
                    "roughnessFactor": roughness,
                },
            }
        )
        primitives.append(
            {
                "attributes": {
                    "POSITION": builder.vectors(part.positions, "VEC3", True),
                    "NORMAL": builder.vectors(part.normals, "VEC3", False),
                    "TEXCOORD_0": builder.vectors(part.uvs, "VEC2", False),
                },
                "indices": builder.indices(part.indices),
                "material": len(materials) - 1,
                "mode": 4,
            }
        )
        triangles += len(part.indices) // 3
        vertices += len(part.positions)
    gltf = {
        "asset": {"version": "2.0", "generator": GENERATOR},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        # One node, one mesh: exactly what ToolModel._first_mesh goes looking for.
        "nodes": [{"name": "PressureWasher", "mesh": 0}],
        "meshes": [{"name": "PressureWasher", "primitives": primitives}],
        "materials": materials,
        "textures": [{"sampler": 0, "source": 0}],
        "images": [{"bufferView": image, "mimeType": "image/png", "name": "atlas"}],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 33071, "wrapT": 33071}],
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.blob) + (-len(builder.blob) % 4)}],
    }
    stats = {"triangles": triangles, "vertices": vertices, "texture_bytes": len(png)}
    return bytes(builder.blob), gltf, stats


ATTRIBUTION = """\
pressure_washer.glb is first-party work: it is drawn, not downloaded. Nothing in
this directory is borrowed and no attribution is owed for it — the file is here,
in the same shape every other model directory has one, so that "where did this
come from" has an answer beside the asset rather than only in a commit message.

It is generated by scripts/build-pressure-washer.py and is reproducible from it:
re-running that script writes this .glb byte for byte, including the 128x128
atlas embedded in it. There is no source model under src-models/ to keep in step
with, and the geometry is described where it is built.

It replaced "homemade flamethrower" by excellenthe (CC-BY 4.0), which stood in
for a pressure washer until issue #162. That download is no longer in the
repository and the game no longer uses it, so its credit has come off the main
menu with it.
"""


# --------------------------------------------------------------------------


def verify(path: Path) -> tuple[list[float], list[float]]:
    """Re-parse the output and measure it, because writing it is not proving it."""
    gltf, blob = read_glb(path)
    if len(gltf["nodes"]) != 1 or "matrix" in gltf["nodes"][0]:
        raise AssertionError("the output must be a single mesh node at the origin")
    if len(gltf["meshes"]) != 1:
        raise AssertionError("the output must be one mesh — ToolModel takes the first it finds")

    low = [float("inf")] * 3
    high = [float("-inf")] * 3
    top: list[tuple[float, float, float]] = []
    for primitive in gltf["meshes"][0]["primitives"]:
        accessor = gltf["accessors"][primitive["attributes"]["POSITION"]]
        for axis in range(3):
            low[axis] = min(low[axis], accessor["min"][axis])
            high[axis] = max(high[axis], accessor["max"][axis])
    size = [high[axis] - low[axis] for axis in range(3)]
    for axis, expected in enumerate((WIDTH, LENGTH, DEPTH)):
        if abs(size[axis] - expected) > 1e-9:
            raise AssertionError(f"axis {axis} measured {size[axis]:.4f} m, drawn for {expected} m")

    # The invariant the whole file exists for, measured off the written vertices:
    # the topmost thing on this mesh is the nozzle's end face, it is a small
    # round hole, and it is centred on the box's own axis — so ViewModel's Muzzle
    # marker, which is (0, extent.y / 2, 0) and knows nothing about this model,
    # lands in the middle of it.
    for primitive in gltf["meshes"][0]["primitives"]:
        accessor = gltf["accessors"][primitive["attributes"]["POSITION"]]
        view = gltf["bufferViews"][accessor["bufferView"]]
        base = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        for at in range(accessor["count"]):
            vertex = struct.unpack_from("<fff", blob, base + at * 12)
            if vertex[1] > high[1] - 1e-6:
                top.append(vertex)
    if not top:
        raise AssertionError("no vertex reaches the top of the box")
    for axis in (0, 2):
        centre = (low[axis] + high[axis]) / 2.0
        end = [vertex[axis] for vertex in top]
        if abs((min(end) + max(end)) / 2.0 - centre) > 1e-6:
            raise AssertionError(
                "the nozzle's end face is off the box's axis on %s — the water would leave "
                "from beside it, which is issue #162" % "xyz"[axis]
            )
        if max(end) - min(end) > NOZZLE_WIDE:
            raise AssertionError(
                "the top of the mesh is %.3f m across on %s, which is not a nozzle"
                % (max(end) - min(end), "xyz"[axis])
            )
    return low, high


def main() -> int:
    parser = argparse.ArgumentParser(description="Draw the power wash wand.")
    parser.add_argument("--out", type=Path, default=OUT, help="output .glb")
    args = parser.parse_args()

    blob, gltf, stats = assemble(draw())
    args.out.parent.mkdir(parents=True, exist_ok=True)
    write_glb(args.out, gltf, blob)
    (args.out.parent / "ATTRIBUTION.txt").write_text(ATTRIBUTION, encoding="utf-8")
    low, high = verify(args.out)

    size = [high[axis] - low[axis] for axis in range(3)]
    print(f"{args.out.name}: {args.out.stat().st_size / 1024:.0f} KiB")
    print(f"  geometry   {stats['triangles']} triangles, {stats['vertices']} vertices")
    print(f"  parts      {len(gltf['materials'])} materials, 1 mesh, 1 node")
    print(f"  atlas      {CELL_PX * 2}x{CELL_PX * 2}, {stats['texture_bytes'] / 1024:.1f} KiB")
    print(f"  bounds     {size[0] * 1000:.0f} x {size[1] * 1000:.0f} x {size[2] * 1000:.0f} mm")
    print(f"  nozzle     ({0.0:.3f}, {high[1]:.3f}, {0.0:.3f}) — on the box's axis, at its top")
    return 0


if __name__ == "__main__":
    sys.exit(main())

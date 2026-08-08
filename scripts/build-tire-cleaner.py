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
  * narrows indices to 16-bit where the primitive fits, which every one of them
    does (the largest is 11,923 vertices).

Geometry is otherwise the artist's, untouched: 68,096 triangles, which is
deliberately NOT decimated here. There is no mesh simplifier in this repo's
toolchain and a hand-rolled one is a quality risk on a smooth-shaded model with
UV seams; the tri count is printed at the end of a run so the number stays
visible rather than becoming a surprise.

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
from io import BytesIO
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
# Reading the source scene
# --------------------------------------------------------------------------


def parts_of(src: Source) -> list[tuple[str, int, list[float]]]:
    """Every mesh in the scene as (material name, mesh index, world matrix).

    Walked from the scene roots so the ancestors' matrices are composed rather
    than ignored, and returned in the order the walk finds them — which is the
    source's own node order, and is therefore stable across runs.
    """
    found: list[tuple[str, int, list[float]]] = []

    def walk(index: int, parent: list[float]) -> None:
        node = src.nodes[index]
        matrix = mat_mul(parent, node_matrix(node))
        if "mesh" in node:
            primitives = src.meshes[node["mesh"]]["primitives"]
            if len(primitives) != 1:
                raise AssertionError(f"{node.get('name')}: expected one primitive per part")
            assert_rigid(matrix, node.get("name", f"node {index}"))
            found.append((src.materials[primitives[0]["material"]]["name"], node["mesh"], matrix))
        for child in node.get("children", []):
            walk(child, matrix)

    identity = [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0]
    for root in src.gltf["scenes"][src.gltf.get("scene", 0)]["nodes"]:
        walk(root, identity)

    names = [name for name, _, _ in found]
    if names != list(PARTS):
        raise AssertionError(f"source parts are {names}, expected {list(PARTS)}")
    return found


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
        f'tire_cleaner.glb is a processed derivative of "{extras["title"]}"\n'
        f'({extras["source"]}) by {extras["author"]},\n'
        f'licensed under {extras["license"]}.\n'
        f"See scripts/build-tire-cleaner.py for what the processing does.\n"
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

    def __init__(self, src: Source) -> None:
        self.src = src
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

    def add_indices(self, values: list[tuple], vertices: int) -> int:
        """Triangle indices, 16-bit when the primitive's vertices fit in 16 bits."""
        narrow = vertices < SHORT_INDEX_LIMIT
        payload = b"".join(struct.pack("<H" if narrow else "<I", v[0]) for v in values)
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
            png = resampled(self.src.image_bytes(source_index), TEXTURE_PX)
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
    """Flatten the six parts into one mesh and return (blob, gltf, stats)."""
    builder = Builder(src)
    primitives = []
    triangles = 0
    vertices = 0
    for name, mesh_index, matrix in parts_of(src):
        prim = src.meshes[mesh_index]["primitives"][0]
        attributes = prim["attributes"]
        positions = [apply(matrix, v) for v in src.accessor(attributes["POSITION"])]
        normals = [rotate(matrix, n) for n in src.accessor(attributes["NORMAL"])]
        uvs = src.accessor(attributes["TEXCOORD_0"])
        indices = src.accessor(prim["indices"])
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
    stats = {"triangles": triangles, "vertices": vertices, "texture_bytes": builder.texture_bytes}
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
    for prim in gltf["meshes"][0]["primitives"]:
        accessor = gltf["accessors"][prim["attributes"]["POSITION"]]
        for axis in range(3):
            low[axis] = min(low[axis], accessor["min"][axis])
            high[axis] = max(high[axis], accessor["max"][axis])
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
    print(f"  geometry   {stats['triangles']} triangles, {stats['vertices']} vertices")
    print(f"  textures   {len(gltf['images'])} at {TEXTURE_PX}px, {stats['texture_bytes'] / 1024:.0f} KiB")
    print(f"  bounds     {size[0] * 1000:.0f} x {size[1] * 1000:.0f} x {size[2] * 1000:.0f} mm, base at y = {low[1]:.4f}")
    print(f"{args.out.name}: {args.out.stat().st_size / 1024:.0f} KiB out")
    return 0


if __name__ == "__main__":
    sys.exit(main())

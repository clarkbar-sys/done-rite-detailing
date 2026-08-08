#!/usr/bin/env python3
"""Bake the wash sponge out of the Sponge source model.

    scripts/build-sponge.py                  # src-models/... -> assets/models/
    scripts/build-sponge.py --help           # the two path overrides, for testing

Input is src-models/sponge/sponge.glb, the Sketchfab download of "Sponge" by
Aullwen (CC-BY 4.0). src-models/ is READ-ONLY (see its AGENTS.md): this script
only ever opens it for reading, and it is the one place the untouched download
lives.

Output is assets/models/sponge/sponge.glb — the sponge the game puts in the
player's hand for DetailingTool.Id.SPONGE — plus ATTRIBUTION.txt carrying the
CC-BY notice the licence requires.

WHY THERE IS A BAKE AT ALL, AND NOT JUST A COPY
------------------------------------------------
The download is a 1.5 MiB scene whose mesh is 276 triangles and whose textures
are two 1024x1024 maps — 97% of the file is a normal map. It is also parented
four nodes deep under Sketchfab's exporter chain, which carries a 1.63 scale and
two rotations. So the bake:

  * flattens that chain into ONE mesh node at the origin, with the composed
    transform baked into the vertices. [ToolModel] lifts "the first
    MeshInstance3D at or under the root" out of the imported scene, so the
    hierarchy buys the game nothing and the scale on it is thrown away by the
    fit regardless — see that class on why it reads the mesh's own box;
  * keeps POSITION, NORMAL and TEXCOORD_0 and drops the rest. TEXCOORD_1 is a
    byte-for-byte copy of TEXCOORD_0 in this file (asserted below, not assumed)
    and nothing samples it; TANGENT is regenerated at import
    (meshes/ensure_tangents in the .import sidecar), so shipping it is 3.5 KiB
    of nothing;
  * resamples both textures to 512x512 — see TEXTURE_PX for why this model gets
    twice the tyre bottle's;
  * narrows indices to 16-bit, which 224 vertices comfortably are.

Geometry is the artist's, untouched: 276 triangles, which is the whole reason
the normal map matters. The mesh is a bevelled box and nothing else — there is
not one pore or torn crumb in it, they are all in that map, and a sponge whose
map has been flattened away is a yellow brick.

The sponge is NOT re-proportioned to the catalogue's extent, and that is the one
distortion this script deliberately leaves in place. The source sponge is
163 x 41 x 109 mm and DetailingTool gives the tool a 240 x 100 x 170 mm box, so
ToolModel's fit stretches it about 67% thicker, relative to its width, than it
was modelled. The extent is hand-tuned game feel — it is what the roll-up icon
is drawn from, what ViewModel._held_pose's "the broad 24x17 cm face, not the
10 cm edge" is about, and what ReachCarry stands the sponge off the paint by
(extent.y * 0.5) — and moving those numbers to flatter a mesh would change how
the game plays for a cosmetic swap. A chunkier sponge is the cheaper of the two
prices, and a sponge is a squishy rectangle to begin with.

WHICH WAY UP IT COMES OUT MATTERS, AND IS ASSERTED
---------------------------------------------------
ToolModel's fit is axis-by-axis: the mesh's own X goes into extent.x, its Y into
extent.y and its Z into extent.z. The catalogue's box is 240 wide, 100 thick,
170 deep and the pose leans it palm-up to show the broad face, so the sponge's
thin axis has to be the one that lands in Y. The composed transform above
happens to do exactly that — the exporter's two rotations swap the source's Y
and Z — and `verify` re-measures it out of the written file rather than trusting
that. A re-download that stops being true would otherwise hand the player a
sponge standing on its edge, correctly sized, with nothing else in the repo able
to notice.

Re-running is safe and produces byte-identical files: nothing here reads the
clock, iterates a set, or depends on dict ordering the interpreter chose.

Only Pillow is imported beyond the standard library, and only to resample PNG.
The glTF itself is read and written with struct + json, the same way
scripts/build-car-pack.py and scripts/build-tire-cleaner.py do it, and the
container helpers below are a deliberate copy of theirs rather than a shared
import: the three bakes have nothing else in common, and `scripts/` is a
directory of programs, not a package.
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
SRC = REPO / "src-models/sponge/sponge.glb"
OUT = REPO / "assets/models/sponge/sponge.glb"

# Square, because both source maps are.
#
# Twice the tyre bottle's 256, and measured rather than inherited. The viewmodel
# anchor sits 0.45 m in front of a 75-degree lens (src/world/garage.tscn), which
# makes the frame about 0.69 m tall where the tool is held; the sponge's broad
# face is 0.24 m across, so it covers roughly a third of the frame — it is the
# largest thing on the belt on screen, where the bottle is a tenth of that in
# area. And it is 276 triangles: the bottles carry their shape in 68k triangles
# of geometry and use their maps for colour, while every pore on this one is in a
# map stretched over six broad faces and the bevel around them, 90 distinct face
# normals in the whole model. The price of 512 is 357 KiB of PNG against 88 KiB
# at 256, and the finished asset is still a sixth of the tyre bottle's 2.0 MiB.
TEXTURE_PX = 512

# The sponge, measured off the source and asserted on the way through. A
# re-export that lands outside this is not the same object and the fit into
# DetailingTool.extent would silently change shape.
EXPECTED_SIZE_M = (0.1628, 0.0407, 0.1088)
SIZE_TOLERANCE_M = 0.005

# glTF's component type ids, and the two buffer targets.
COMPONENT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
COMPONENT_COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER = 34962, 34963
UNSIGNED_SHORT, UNSIGNED_INT = 5123, 5125
SHORT_INDEX_LIMIT = 65536

GENERATOR = "done-rite-detailing scripts/build-sponge.py"

# How far the composed node matrix's three columns may differ in length before
# this script stops believing it can carry normals with a rotate-and-normalise.
# The chain here is a single uniform 1.6279 scale under two rotations, so the
# columns match to about 1e-16; a non-uniform scale would need the inverse
# transpose ToolModel does, and is refused rather than approximated.
UNIFORM_TOLERANCE = 1e-6


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
# Small 3D helpers. The whole scene is one transform, so a general 4x4 library
# would be dead weight.
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
    """`v` turned by the 3x3 of `m` and re-normalised — a direction, not a point.

    Correct for normals only because `assert_uniform` has already refused
    anything but a uniform scale: a uniform scale changes a normal's length and
    nothing else, so normalising is the whole of the correction. Under a
    non-uniform one it would need the inverse transpose, which is the arithmetic
    ToolModel does when it fits this mesh into the catalogue's box.
    """
    turned = (
        m[0] * v[0] + m[4] * v[1] + m[8] * v[2],
        m[1] * v[0] + m[5] * v[1] + m[9] * v[2],
        m[2] * v[0] + m[6] * v[1] + m[10] * v[2],
    )
    length = sum(c * c for c in turned) ** 0.5
    if length == 0.0:
        raise AssertionError("a normal turned into nothing at all")
    return (turned[0] / length, turned[1] / length, turned[2] / length)


def assert_uniform(matrix: list[float], where: str) -> float:
    """Fail unless the 3x3 part is a rotation times one scale; return that scale."""
    lengths = [
        sum(matrix[i * 4 + row] ** 2 for row in range(3)) ** 0.5 for i in range(3)
    ]
    for length in lengths:
        if abs(length - lengths[0]) > UNIFORM_TOLERANCE:
            raise AssertionError(f"{where}: node transform is not a uniform scale ({lengths})")
    for i in range(3):
        for j in range(i + 1, 3):
            product = sum(matrix[i * 4 + row] * matrix[j * 4 + row] for row in range(3))
            if abs(product) > UNIFORM_TOLERANCE * lengths[0] * lengths[0]:
                raise AssertionError(f"{where}: node transform shears ({product:g})")
    return lengths[0]


# --------------------------------------------------------------------------
# Reading the source scene
# --------------------------------------------------------------------------


def the_part(src: Source) -> tuple[int, list[float]]:
    """The scene's one mesh as (mesh index, world matrix).

    Walked from the scene roots so the exporter's four-node chain is composed
    rather than ignored, and asserted to be exactly one mesh of one primitive —
    which is what ToolModel._first_mesh is entitled to assume of an asset, and
    what a re-download growing a second part must fail on rather than silently
    lose.
    """
    found: list[tuple[int, list[float]]] = []

    def walk(index: int, parent: list[float]) -> None:
        node = src.nodes[index]
        matrix = mat_mul(parent, node_matrix(node))
        if "mesh" in node:
            primitives = src.meshes[node["mesh"]]["primitives"]
            if len(primitives) != 1:
                raise AssertionError(f"{node.get('name')}: expected one primitive")
            assert_uniform(matrix, node.get("name", f"node {index}"))
            found.append((node["mesh"], matrix))
        for child in node.get("children", []):
            walk(child, matrix)

    identity = [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0]
    for root in src.gltf["scenes"][src.gltf.get("scene", 0)]["nodes"]:
        walk(root, identity)

    if len(found) != 1:
        raise AssertionError(f"the source has {len(found)} meshes, expected exactly one")
    return found[0]


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
        f'sponge.glb is a processed derivative of "{extras["title"]}"\n'
        f'({extras["source"]}) by {extras["author"]},\n'
        f'licensed under {extras["license"]}.\n'
        f"See scripts/build-sponge.py for what the processing does.\n"
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
    """Accumulates the output glTF: buffer, accessors, the one material."""

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
        beside the model, so these names are half of the file names in the repo:
        "albedo" here is assets/models/sponge/sponge_albedo.png on disk. The
        source leaves every image unnamed, which would land them there as
        sponge_image_0.png and friends.
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

    def material(self, source_material: int) -> int:
        """Copy the source material across, resampling every texture it references.

        Copied rather than rebuilt: doubleSided, the metallic factor and the
        normal-map scale are all authored, and none of it is ours to reinvent.
        """
        material = json.loads(json.dumps(self.src.materials[source_material]))
        pbr = material.get("pbrMetallicRoughness", {})
        for slot, suffix in (("baseColorTexture", "albedo"), ("metallicRoughnessTexture", "orm")):
            if slot in pbr:
                pbr[slot] = {**pbr[slot], "index": self._texture(pbr[slot]["index"], suffix)}
        for slot, suffix in (("normalTexture", "normal"), ("emissiveTexture", "emissive")):
            if slot in material:
                material[slot] = {
                    **material[slot],
                    "index": self._texture(material[slot]["index"], suffix),
                }
        self.materials.append(material)
        return len(self.materials) - 1


def build(src: Source) -> tuple[bytes, dict, dict]:
    """Flatten the source chain into one mesh node and return (blob, gltf, stats)."""
    builder = Builder(src)
    mesh_index, matrix = the_part(src)
    scale = assert_uniform(matrix, "the composed chain")
    prim = src.meshes[mesh_index]["primitives"][0]
    attributes = prim["attributes"]
    positions = [apply(matrix, v) for v in src.accessor(attributes["POSITION"])]
    normals = [rotate(matrix, n) for n in src.accessor(attributes["NORMAL"])]
    uvs = src.accessor(attributes["TEXCOORD_0"])
    # Dropped rather than merged, and said out loud: the docstring claims the
    # second UV set is a copy, and a re-export where it stops being one is a
    # material sampling coordinates this bake threw away.
    if "TEXCOORD_1" in attributes and src.accessor(attributes["TEXCOORD_1"]) != uvs:
        raise AssertionError("TEXCOORD_1 is not a copy of TEXCOORD_0 and would be lost")
    indices = src.accessor(prim["indices"])

    primitive = {
        "attributes": {
            "POSITION": builder.add_vec3(positions, True),
            "NORMAL": builder.add_vec3(normals, False),
            "TEXCOORD_0": builder.add_vec2(uvs),
        },
        "indices": builder.add_indices(indices, len(positions)),
        "material": builder.material(prim["material"]),
        "mode": prim.get("mode", 4),
    }
    gltf = {
        "asset": {"version": "2.0", "generator": GENERATOR, "extras": src.gltf["asset"].get("extras", {})},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        # One node, one mesh: exactly what ToolModel._first_mesh goes looking for.
        "nodes": [{"name": "Sponge", "mesh": 0}],
        "meshes": [{"name": "Sponge", "primitives": [primitive]}],
        "materials": builder.materials,
        "textures": builder.textures,
        "images": builder.images,
        "samplers": [src.gltf["samplers"][0]],
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.blob) + (-len(builder.blob) % 4)}],
    }
    stats = {
        "triangles": len(indices) // 3,
        "vertices": len(positions),
        "texture_bytes": builder.texture_bytes,
        "scale": scale,
    }
    return bytes(builder.blob), gltf, stats


# --------------------------------------------------------------------------


def verify(path: Path) -> tuple[list[float], list[float]]:
    """Re-parse the output and measure it, because writing it is not proving it."""
    gltf, _ = read_glb(path)
    if len(gltf["nodes"]) != 1 or "matrix" in gltf["nodes"][0]:
        raise AssertionError("the output must be a single mesh node at the origin")
    if len(gltf["meshes"]) != 1 or len(gltf["meshes"][0]["primitives"]) != 1:
        raise AssertionError("the output must be one mesh of one primitive")
    accessor = gltf["accessors"][gltf["meshes"][0]["primitives"][0]["attributes"]["POSITION"]]
    low, high = list(accessor["min"]), list(accessor["max"])
    size = [high[axis] - low[axis] for axis in range(3)]
    for axis, expected in enumerate(EXPECTED_SIZE_M):
        if abs(size[axis] - expected) > SIZE_TOLERANCE_M:
            raise AssertionError(f"axis {axis} measured {size[axis]:.4f} m, expected about {expected} m")
    # The one thing about orientation the game cannot check for itself — see the
    # docstring. ToolModel maps this mesh's Y onto DetailingTool.extent.y, which
    # is the 10 cm the pose calls "the edge".
    if size[1] != min(size):
        raise AssertionError(f"the thin axis must be Y, not {size.index(min(size))}")
    return low, high


def main() -> int:
    parser = argparse.ArgumentParser(description="Bake the wash sponge from the source model.")
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
    print(f"  chain      flattened at scale {stats['scale']:.4f} -> 1 node, 1 mesh, 1 primitive")
    print(f"  geometry   {stats['triangles']} triangles, {stats['vertices']} vertices")
    print(f"  textures   {len(gltf['images'])} at {TEXTURE_PX}px, {stats['texture_bytes'] / 1024:.0f} KiB")
    print(f"  bounds     {size[0] * 1000:.0f} x {size[1] * 1000:.0f} x {size[2] * 1000:.0f} mm")
    print(f"{args.out.name}: {args.out.stat().st_size / 1024:.0f} KiB out")
    return 0


if __name__ == "__main__":
    sys.exit(main())

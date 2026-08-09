#!/usr/bin/env python3
"""List what is actually inside an exported .pck, and what is in there twice.

    scripts/list-pack.py build/web/index.pck              # biggest 40 entries
    scripts/list-pack.py build/web/index.pck --all        # every entry
    scripts/list-pack.py build/web/index.pck --match ctex # only matching paths

This exists because the export filter is a promise and the pack is the fact.
The Makefile already carries one story of the two disagreeing — the web export
packing its own icons back into itself, found by reading the pack — and #203 is
another: 16.2 MB of a 35.6 MB pack turned out to be ten byte-identical copies of
one headlight texture, which no amount of reading export_presets.cfg would have
shown. So this reads the container.

The DUPLICATE CONTENT section is the part worth running: entries are grouped by
the MD5 the pack itself stores for them, so "the same picture shipped N times"
is a line of output rather than an archaeology session.


WHY THIS PARSES BYTES INSTEAD OF ASKING GODOT
----------------------------------------------
`ProjectSettings.load_resource_pack()` plus a `DirAccess` walk is the obvious
alternative and it cannot answer this question: mounting a pack inside a
project merges it with that project's own res://, so what comes back is the
union and there is no way to ask which side a path came from. Doing it honestly
would mean a second throwaway Godot project whose only job is to be empty. The
container is a header and a table, so it is read directly instead.

THE CATCH, SAID PLAINLY: this knows one layout, the one Godot 4.7.1 writes
(pack format version 4), and it refuses to guess at any other. That is
deliberate — a pack reader that limps on after the format moved would report
wrong sizes with total confidence. The toolchain is pinned by
scripts/fetch-godot.sh, so "the format changed" and "the pin moved" are the same
event, and this failing loudly is the reminder to come and look.

WHAT MAKES THE PARSE TRUSTWORTHY: every entry carries the MD5 of its own bytes,
and this checks all of them against the slice it thinks the entry occupies. A
layout misread by even one byte fails that check on the first file rather than
producing a plausible-looking table of nonsense.


THE LAYOUT (Godot 4.7.1, measured on an actual export)
-------------------------------------------------------
Header, little-endian throughout:

    0   'GDPC'
    4   pack format version           4
    8   Godot major / minor / patch   three uint32
    20  pack flags                    uint32
    24  file base                     uint64, where the file data starts
    32  directory offset              uint64, where the table below starts
    40  reserved                      sixteen uint32, all zero

Directory, at that offset:

    uint32 entry count, then per entry
        uint32 path length, then that many bytes of path, NUL-padded
        uint64 offset (from the file base), uint64 size
        16 bytes of MD5, uint32 entry flags

Paths arrive without their `res://` prefix; it is put back on for the listing
because that is how every other tool in this repo spells them.
"""

from __future__ import annotations

import argparse
import hashlib
import struct
import sys
from pathlib import Path

MAGIC = b"GDPC"
SUPPORTED_FORMAT = 4
HEADER = struct.Struct("<4sIIIIIQQ")  # through the directory offset
RESERVED_LONGS = 16


def read_pack(path: Path) -> tuple[list[tuple[str, int, bytes]], dict]:
    """Return (path, size, md5) for every entry, plus the header fields."""
    raw = path.read_bytes()
    magic, version, major, minor, patch, flags, file_base, directory = HEADER.unpack_from(raw, 0)
    if magic != MAGIC:
        raise SystemExit(f"{path} does not start with {MAGIC.decode()}; it is not a Godot pack")
    if version != SUPPORTED_FORMAT:
        raise SystemExit(
            f"{path} is pack format version {version}; this script only knows version "
            f"{SUPPORTED_FORMAT} (see the docstring — do not guess, come and look)"
        )
    reserved = struct.unpack_from(f"<{RESERVED_LONGS}I", raw, HEADER.size)
    if any(reserved):
        raise SystemExit(f"{path}: reserved header words are not zero {reserved}")

    entries: list[tuple[str, int, bytes]] = []
    cursor = directory
    (count,) = struct.unpack_from("<I", raw, cursor)
    cursor += 4
    for _ in range(count):
        (length,) = struct.unpack_from("<I", raw, cursor)
        cursor += 4
        name = raw[cursor : cursor + length].rstrip(b"\0").decode("utf-8")
        cursor += length
        offset, size = struct.unpack_from("<QQ", raw, cursor)
        cursor += 16
        digest = raw[cursor : cursor + 16]
        cursor += 16 + 4  # the entry's own flags, which nothing here reads
        start = file_base + offset
        # The parse is only as good as this line: a layout read one byte wrong
        # produces entries that look fine and hash to nothing.
        actual = hashlib.md5(raw[start : start + size]).digest()
        if actual != digest:
            raise SystemExit(f"{path}: {name} does not match the MD5 the pack stores for it")
        entries.append((f"res://{name}", size, digest))
    header = {"godot": f"{major}.{minor}.{patch}", "flags": flags, "bytes": len(raw), "entries": count}
    return entries, header


def format_header(path: Path, header: dict) -> str:
    return (
        f"{path}: {header['bytes']:,} bytes, {header['entries']} entries, "
        f"Godot {header['godot']}, pack flags {header['flags']}"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="List the contents of an exported Godot .pck.")
    parser.add_argument("pack", type=Path, help="the .pck to read")
    parser.add_argument("--match", default="", help="only entries whose path contains this")
    parser.add_argument("--all", action="store_true", help="list every entry, not just the biggest")
    parser.add_argument("--top", type=int, default=40, help="how many entries to list without --all")
    args = parser.parse_args()

    entries, header = read_pack(args.pack)
    print(format_header(args.pack, header))

    shown = [entry for entry in entries if args.match in entry[0]]
    if args.match:
        print(f"{len(shown)} entries matching {args.match!r}, {sum(e[1] for e in shown):,} bytes")
    ranked = sorted(shown, key=lambda entry: (-entry[1], entry[0]))
    listed = ranked if args.all else ranked[: args.top]
    for name, size, _ in listed:
        print(f"{size:12,}  {name}")
    if len(listed) < len(ranked):
        print(f"... and {len(ranked) - len(listed)} smaller (use --all)")

    groups: dict[bytes, list[tuple[str, int]]] = {}
    for name, size, digest in shown:
        groups.setdefault(digest, []).append((name, size))
    repeated = [members for members in groups.values() if len(members) > 1]
    # Worst first, where worst is what deduplicating would give back: one
    # entry's size times the number of copies past the first.
    repeated.sort(key=lambda members: -members[0][1] * (len(members) - 1))

    print()
    if not repeated:
        print("DUPLICATE CONTENT: none — no two entries hold the same bytes")
        return 0
    wasted = sum(members[0][1] * (len(members) - 1) for members in repeated)
    print(f"DUPLICATE CONTENT: {len(repeated)} groups, {wasted:,} bytes in the copies after the first")
    for members in repeated:
        names = ", ".join(sorted(name for name, _ in members))
        print(f"{members[0][1]:12,} x{len(members)}  {names}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

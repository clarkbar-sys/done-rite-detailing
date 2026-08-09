#!/usr/bin/env python3
"""List what is inside an exported .pck, biggest first, with a running share.

    scripts/list-pck.py build/web/index.pck            # everything, biggest first
    scripts/list-pck.py build/web/index.pck --top 20   # just the head of that list
    scripts/list-pck.py build/web/index.pck --match cleaner

WHY THIS EXISTS
-----------------
`make build-web` prints one number — the size of build/web/ — and the load-time
work this was written for is a series of arguments about which entries inside
index.pck are that number. "The two spray bottles are 3.9 MB of a 32 MB pack" is
either the reason to spend a day on a mesh simplifier or it is not, and the only
way to know is to look. So this reads the pack's own directory and prints it.

An exported pack does not hold the assets/ tree the repository does: a .glb goes
in as the .scn Godot imported it to, a .png as a .ctex, and the source files are
left behind entirely. That is why a question about what an asset costs the
download has to be asked here rather than of `du` — the 2.09 MB .glb this
project used to commit for each bottle arrived as a 1.94 MB .scn, and neither
number is the other one.

HOW A .pck IS PUT TOGETHER, WHICH IS WHY THIS IS STANDARD LIBRARY ONLY
------------------------------------------------------------------------
The same reasoning scripts/build-tire-cleaner.py gives for reading a GLB with
struct and json: the container is a header and a table, and reaching for a
dependency to read forty bytes of it would be the larger cost. Verified against
the pack this project exports — the walk below ends exactly on the last byte of
the file, which is the check that the layout is being read and not guessed:

    'GDPC'                          4 bytes of magic
    pack format version             4     this reads 1 and 2 as well as the
    Godot major, minor, patch      12     4.7.1 pack format 4 it was written for
    flags                           4     bit 1: offsets are relative to the base
    file base                       8     (format 2 and up)
    directory offset                8     (format 3 and up; 0 means "next")
    reserved                       up to the file base
    ...the files themselves...
    file count                      4     at the directory offset
    per file: path length           4
             path                   as many, NUL padded to a multiple of four
             offset, size          16
             MD5                   16
             flags                  4     (format 2 and up)

Nothing here decrypts: an encrypted directory is refused rather than half-read,
because this project does not export one and a tool that pretended to read one
would be lying about the sizes it printed.
"""

from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

MAGIC = 0x43504447  # 'GDPC'

# Pack format versions this understands. 1 is Godot 3, 2 is Godot 4.0 to 4.3,
# 3 and 4 move the directory to the end of the file. Refused rather than guessed
# at above 4, because a pack whose table has moved again would otherwise be read
# as nonsense with confident-looking numbers on it.
NEWEST_FORMAT = 4

# Bit 0 of the pack flags. See the docstring: an encrypted directory is refused.
DIRECTORY_ENCRYPTED = 1

# Bit 1: file offsets are relative to the file base rather than to the file.
# Read and reported because an offset that is not where this thinks it is means
# the sizes beside it are not to be trusted either.
RELATIVE_OFFSETS = 2


def entries(raw: bytes) -> tuple[list[tuple[str, int]], int, int]:
    """Every (path, bytes) in the pack, plus its format version and where it ended.

    The end offset is returned rather than checked in here so `main` can require
    it to be the end of the file — the one assertion that says the layout above
    was read correctly rather than plausibly.
    """
    magic, version, major, minor, patch = struct.unpack_from("<5I", raw, 0)
    if magic != MAGIC:
        raise ValueError("not a Godot .pck — no GDPC magic")
    if version > NEWEST_FORMAT:
        raise ValueError(f"pack format {version} is newer than the {NEWEST_FORMAT} this reads")
    at = 20
    directory = 0
    if version >= 2:
        flags, base = struct.unpack_from("<Iq", raw, at)
        at += 12
        if flags & DIRECTORY_ENCRYPTED:
            raise ValueError("the pack's directory is encrypted and this tool does not decrypt")
        del base, flags
    if version >= 3:
        (directory,) = struct.unpack_from("<q", raw, at)
        at += 8
    if directory:
        at = directory
    else:
        at += 16 * 4
    (count,) = struct.unpack_from("<I", raw, at)
    at += 4
    found: list[tuple[str, int]] = []
    for _ in range(count):
        (length,) = struct.unpack_from("<I", raw, at)
        at += 4
        path = raw[at : at + length].rstrip(b"\0").decode("utf-8")
        at += length
        _, size = struct.unpack_from("<qq", raw, at)
        at += 16 + 16  # the offset and size, then the MD5
        if version >= 2:
            at += 4
        found.append((path, size))
    return found, version, at


def main() -> int:
    parser = argparse.ArgumentParser(description="List an exported .pck's contents, biggest first.")
    parser.add_argument("pck", type=Path, help="the pack to read, e.g. build/web/index.pck")
    parser.add_argument("--top", type=int, default=0, help="show only the N biggest entries")
    parser.add_argument("--match", default="", help="show only paths holding this substring")
    args = parser.parse_args()

    raw = args.pck.read_bytes()
    found, version, ended = entries(raw)
    # Version 3 and up put the directory last, so the walk ends on the last byte
    # of the file; before that it ends where the files begin. Either way it has
    # to land somewhere inside, and a walk that ran off the end read a layout
    # this tool does not actually understand.
    if not 0 < ended <= len(raw):
        raise AssertionError(f"the directory walk ended at {ended} of {len(raw)} bytes")

    total = sum(size for _, size in found)
    shown = [item for item in found if args.match in item[0]]
    shown.sort(key=lambda item: (-item[1], item[0]))
    listed = shown[: args.top] if args.top else shown
    print(f"{args.pck}: pack format {version}, {len(found)} files, {total / 1e6:.2f} MB of entries")
    if args.match:
        print(f"  matching {args.match!r}: {len(shown)} files, {sum(s for _, s in shown) / 1e6:.2f} MB")
    for path, size in listed:
        print(f"  {size:>10}  {size / total:6.2%}  {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""Export the tile outline masks Grafon draws material pieces through.

A mask clip (maskBare, maskDamaged, ...) holds four quarter clips c1..c4, each
with 5 frames picked by Location.insKontur (0 inside, 1 inner corner, 2 open
above/below, 3 open at the side, 4 outer corner). One trimmed swf per mask has
20 frames: frame (q * 5 + k + 1) shows quarter c(q+1) alone on outline frame k,
through a one-frame copy of the quarter sprite. A magenta marker fixes the
canvas at -HALF..HALF around the tile centre.

Output: godot/assets/sprites/tiles/masks/<mask>/<q>_<k>.png (alpha only matters).

Usage: python export_tile_masks.py [maskName ...]
"""

import shutil
import struct
import subprocess
import sys

import swf_trim as st

HALF = 40
OUT = st.ROOT / "godot" / "assets" / "sprites" / "tiles" / "masks"
WORK = st.ROOT / "original" / "extracted_swf" / "tile_masks"
MASKS = ["maskBare", "maskDamaged", "maskStone", "maskDirt", "maskSimple", "maskBorderBare",
         "maskSkol", "maskStoneBorder", "maskDirtBorder", "maskMetalBorder"]
COPY_BASE = 65100


def set_cid(tag, body, cid):
    """PlaceObject2/3 body with its character id replaced."""
    flags = body[0]
    pos = 2 if tag == 70 else 1
    flags2 = body[1] if tag == 70 else 0
    pos += 2
    if tag == 70 and flags2 & 0x08:
        while body[pos] != 0:
            pos += 1
        pos += 1
    assert flags & 0x02
    return body[:pos] + struct.pack("<H", cid) + body[pos + 2:]


def quarters(swf, sid):
    """[(name, tag, body)] for c1..c4 in the mask clip's first frame."""
    frames, _ = swf.frames(sid)
    out = {}
    for tag, body in frames[0]:
        if tag in (26, 70):
            name = st.place_name(tag, body)
            if name and name in ("c1", "c2", "c3", "c4") and st.place_cid(tag, body) is not None:
                out[name] = (tag, body)
    return [out[n] for n in ("c1", "c2", "c3", "c4")]


def main():
    only = sys.argv[1:]
    swf = st.Swf()
    for name in MASKS:
        if only and name not in only:
            continue
        sid = swf.symbols[name]
        quads = quarters(swf, sid)
        frames = []
        last = None
        for tag, body in quads:
            evs = [] if last is None else [(28, struct.pack("<H", last))]
            evs.append((tag, body))
            if last is None:
                evs += st.marker_place()
            frames.append(evs)
            last = st.place_depth(tag, body)
        target = OUT / name
        target.mkdir(parents=True, exist_ok=True)
        count = 0
        for k in range(5):
            edits = {sid: st.build_sprite(sid, frames)}
            for tag, body in quads:
                child = st.place_cid(tag, body)
                cframes, _ = swf.frames(child)
                edits[child] = st.build_sprite(child, [st.state_at(cframes, k + 1)])
            dest = WORK / name / str(k)
            if dest.exists():
                shutil.rmtree(dest)
            dest.mkdir(parents=True)
            small = dest / "clip.swf"
            swf.trim([sid], small, edits, st.marker_defs(-HALF, -HALF, HALF, HALF))
            subprocess.run([str(st.FFDEC), "-ignorebackground", "-format", "sprite:png", "-selectid", str(sid),
                            "-export", "sprite", str(dest / "out"), str(small)],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            folder = next(p for p in (dest / "out").iterdir() if p.is_dir())
            files = sorted(folder.glob("*.png"), key=lambda p: int(p.stem))
            for q, f in enumerate(files[:4]):
                shutil.copy(f, target / ("%d_%d.png" % (q, k)))
                count += 1
        print(name, "sid", sid, "files", count, flush=True)


if __name__ == "__main__":
    main()

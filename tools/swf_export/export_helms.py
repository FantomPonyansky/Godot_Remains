"""Export morda (273) armour frames as the pony "helm" part.

morda stops on the armour label (Obj.setArmor). Each label frame swaps the helm
depth, adds layers and may drop or replace the hair. Only depths that differ
from frame 1 are kept, so the part draws over the head baked into the body
clips. Writes parts/helm/N.png (N = label frame - 1), anchors.json and
labels.json {label: {"frame": N, "hair": bool}}.
"""

import json
import re
import shutil
import struct
import subprocess

import swf_trim as st

MORDA = 273
WORK = st.ROOT / "original" / "extracted_swf" / "body_export" / "helm"
OUT = st.ROOT / "godot" / "assets" / "sprites" / "pony" / "parts" / "helm"
SKIP_NAMES = {"eye", "magic", "horn", "konec"}
# The frame-1 face characters (199, 235) are baked into the body clips.
BASE_FACE = {199, 235}


def is_move(t, b):
    return t != 4 and bool(b[0] & 0x01)


def history(frames, frame):
    """Per depth after frames 1..frame: the tags since its last fresh place.
    A replace (move + character) without a matrix keeps the earlier one, so
    the fresh place stays in front of it."""
    live = {}
    for evs in frames[:frame]:
        for t, b in evs:
            if t in (5, 28):
                live.pop(st.place_depth(t, b), None)
            elif t in st.PLACE:
                d = st.place_depth(t, b)
                if not is_move(t, b):
                    live[d] = [(t, b)]
                elif d in live:
                    live[d].append((t, b))
    return live


def char_of(evs):
    cid = None
    for t, b in evs:
        c = st.place_cid(t, b)
        if c is not None:
            cid = c
    return cid


def ffdec(args):
    subprocess.run([str(st.FFDEC)] + args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    swf = st.Swf()
    frames, labels = swf.frames(MORDA)
    base = history(frames, 1)
    hair_depth = st.depths_named(frames, {"hair"}).get("hair")
    out_frames, info = [], {}
    placed = set()
    for label, frame in sorted(labels.items(), key=lambda kv: kv[1]):
        live = history(frames, frame)
        # Sprite frames are incremental: clear the previous label's layers.
        keep = [(28, struct.pack("<H", d)) for d in sorted(placed)]
        placed = set()
        for d in sorted(live):
            evs = live[d]
            names = {st.place_name(t, b) for t, b in evs}
            if names & SKIP_NAMES or char_of(evs) in BASE_FACE:
                continue
            if d in base and char_of(base[d]) == char_of(evs):
                continue
            keep += evs
            placed.add(d)
        hair = hair_depth in live and char_of(live[hair_depth]) == char_of(base.get(hair_depth, []))
        out_frames.append(keep)
        info[label] = {"frame": frame - 1, "hair": hair}
    edits = {MORDA: st.build_sprite(MORDA, out_frames)}
    keep_s, _ = swf.needed([MORDA])
    for s in keep_s:
        if s == MORDA:
            continue
        sub, _ = swf.frames(s)
        if len(sub) > 1:
            edits[s] = st.build_sprite(s, [[(t, b) for t, b in sub[0] if t not in (12, 43)]])
    if WORK.exists():
        shutil.rmtree(WORK)
    WORK.mkdir(parents=True)
    small = WORK / "helm.swf"
    swf.trim([MORDA], small, edits)
    ffdec(["-ignorebackground", "-format", "sprite:png", "-selectid", str(MORDA), "-export", "sprite", str(WORK / "png"), str(small)])
    ffdec(["-format", "sprite:svg", "-select", "%d:1" % MORDA, "-selectid", str(MORDA), "-export", "sprite", str(WORK / "svg"), str(small)])
    folder = next(p for p in (WORK / "png").iterdir() if p.is_dir())
    files = sorted(folder.glob("*.png"), key=lambda p: int(p.stem))
    text = next((WORK / "svg").rglob("1.svg")).read_text(encoding="utf-8", errors="replace")
    nums = [float(x) for x in re.search(r'<g transform="matrix\(([^)]+)\)"', text).group(1).split(",")]
    anchor = [round(nums[4], 2), round(nums[5], 2)]
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    for i, src in enumerate(files, 1):
        (OUT / ("%d.png" % i)).write_bytes(src.read_bytes())
    (OUT / "anchors.json").write_text(json.dumps([anchor for _ in files]), encoding="utf-8")
    (OUT / "labels.json").write_text(json.dumps(info, indent=1), encoding="utf-8")
    shutil.rmtree(WORK)
    print("helm frames", len(files), "anchor", anchor, info)


if __name__ == "__main__":
    main()

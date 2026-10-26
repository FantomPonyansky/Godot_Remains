"""Export GUI.imp (the important-item window) for gui/imp: the background
(imp without txt, title, ico and the lmb hint) and the ico frames the
items.xml mess ids reach (impMess falls back to frame 1 for the rest).

FFDec never opens pfe.swf: swf_trim copies one sprite into a small SWF.
FFDec's bounds are kept and the SVG matrix gives the origin, as in
export_body_clips.py. anchors.json holds that origin per png.

Usage: python export_imp_mess.py
"""

import json
import re
import shutil
import subprocess

import swf_trim as st

IMP = 4649
ICO = 1112
OUT = st.ROOT / "godot" / "assets" / "ui" / "imp"
WORK = st.ROOT / "original" / "extracted_swf" / "imp_export"
LABELS = ["stat_tw", "stat_aj", "stat_fl", "stat_rr", "stat_pp", "stat_rd", "amul_al", "blackbook", "kogit", "sphera"]
SKIP_NAMES = {"txt", "title", "ico", "lmb"}


def ffdec(args):
    subprocess.run([str(st.FFDEC)] + args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def render(swf, sid, tags, name):
    dest = WORK / name
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    small = dest / "clip.swf"
    swf.trim([sid], small, {sid: st.build_sprite(sid, [tags])})
    ffdec(["-ignorebackground", "-format", "sprite:png", "-selectid", str(sid), "-export", "sprite", str(dest / "png"), str(small)])
    ffdec(["-format", "sprite:svg", "-selectid", str(sid), "-export", "sprite", str(dest / "svg"), str(small)])
    png = next((dest / "png").rglob("1.png"))
    text = next((dest / "svg").rglob("1.svg")).read_text(encoding="utf-8", errors="replace")
    m = re.search(r'<g transform="matrix\(([^)]+)\)"', text)
    nums = [float(x) for x in m.group(1).split(",")] if m else [1, 0, 0, 1, 0, 0]
    OUT.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(png, OUT / (name + ".png"))
    shutil.rmtree(dest)
    return [round(nums[4], 2), round(nums[5], 2)]


def standalone(frames, frame):
    """display_at for one frame, with replace-places (move + character, no
    matrix) turned into fresh places carrying the matrix they inherit."""
    last_matrix = {}
    for evs in frames[:frame]:
        for t, b in evs:
            if t == 26 and b[0] & 0x04:
                pos = 3 + (2 if b[0] & 0x02 else 0)
                last_matrix[st.place_depth(t, b)] = b[pos:pos + st._matrix_len(b, pos)]
    out = []
    for t, b in st.display_at(frames, frame):
        if t == 26 and b[0] & 0x03 == 0x03 and not b[0] & 0x04 and st.place_depth(t, b) in last_matrix:
            flags = (b[0] & ~0x01) | 0x04
            b = bytes([flags]) + b[1:5] + last_matrix[st.place_depth(t, b)] + b[5:]
        elif t == 26 and b[0] & 0x01:
            b = bytes([b[0] & ~0x01]) + b[1:]
        out.append((t, b))
    return out


def main():
    swf = st.Swf()
    anchors = {}
    frames, _ = swf.frames(IMP)
    drop = set(st.depths_named(frames, SKIP_NAMES).values())
    tags = [(t, b) for t, b in st.display_at(frames, 1) if st.place_depth(t, b) not in drop]
    anchors["back"] = render(swf, IMP, tags, "back")
    ico_frames, labels = swf.frames(ICO)
    for name, frame in [("ico_1", 1)] + [("ico_" + l, labels[l]) for l in LABELS if l in labels]:
        anchors[name] = render(swf, ICO, standalone(ico_frames, frame), name)
        print(name, frame, anchors[name], flush=True)
    (OUT / "anchors.json").write_text(json.dumps(anchors, indent=1), encoding="utf-8")
    print("back", anchors["back"])


if __name__ == "__main__":
    main()

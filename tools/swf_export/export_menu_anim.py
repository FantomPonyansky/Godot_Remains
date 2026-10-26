"""Main-menu animated parts (Displ.as): visMainMenu.pipka and .groza pieces, one by one.

Each job renders one sprite (optionally keeping only some of its first-frame
children) inside a fixed box with the swf_trim origin marker, into
_menu_anim_tmp/<name>/<frame>.png plus jobs.json. godot/tools/pack_menu_anim.gd
then crops them into godot/assets/ui/menu/anim/ with a manifest.

python export_menu_anim.py
"""
import json
import shutil
import subprocess

import swf_trim as st
from export_story_art import longest_in

WORK = st.ROOT / "original" / "extracted_swf" / "_menu_anim_tmp"

# name: (sprite id, keep child cids or None, box x0, y0, x1, y1)
JOBS = {
    "mane": (469, {437}, 0, 0, 240, 300),
    "ear": (469, {455}, 0, 0, 240, 300),
    "eye": (432, None, -40, -40, 40, 40),
    "displ1": (435, None, 0, 0, 240, 300),
    "displ2": (452, None, 0, 0, 240, 300),
    "horn": (449, {439}, -60, -60, 60, 60),
    "horn_glow": (445, {441}, -112, -112, 112, 112),
    "krug": (444, None, -102, -102, 102, 102),
    "horn_spark": (448, None, -16, -16, 16, 16),
    "pistol": (468, {458, 460}, -50, -70, 50, 70),
    "pistol_glow": (463, {462}, -112, -112, 112, 112),
    "pistol_glow2": (466, {465}, -112, -112, 112, 112),
    "pistol_spark": (467, None, -16, -16, 16, 16),
    "groza_sky": (413, None, -195, -124, 195, 124),
    "tuchi": (416, None, -2, -2, 802, 546),
    "moln": (421, None, -180, -180, 180, 180),
    "volna": (396, None, -400, -400, 400, 400),
    "wav": (394, None, -200, -200, 200, 200),
    "serost": (398, None, -400, -400, 400, 400),
}


def main():
    swf = st.Swf()
    if WORK.exists():
        shutil.rmtree(WORK)
    WORK.mkdir(parents=True)
    out = {}
    for name, (sid, keep, x0, y0, x1, y1) in JOBS.items():
        frames, _labels = swf.frames(sid)
        n = len(frames)
        if n == 1:
            n = longest_in(swf, frames[0])
        frames = [[(t, b) for t, b in evs if t != 43] for evs in frames]
        if keep is not None:
            frames[0] = [(t, b) for t, b in frames[0] if t not in st.PLACE or st.place_cid(t, b) in keep]
        frames[0] = frames[0] + st.marker_place()
        while len(frames) < n:
            frames.append([])
        dest = WORK / name
        dest.mkdir()
        small = dest / "clip.swf"
        swf.trim([sid], small, {sid: st.build_sprite(sid, frames)}, st.marker_defs(x0, y0, x1, y1))
        subprocess.run([str(st.FFDEC), "-ignorebackground", "-format", "sprite:png", "-selectid", str(sid),
                        "-export", "sprite", str(dest / "out"), str(small)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        small.unlink()
        folder = next(p for p in (dest / "out").iterdir() if p.is_dir())
        files = [str(f) for f in sorted(folder.glob("*.png"), key=lambda p: int(p.stem))][:n]
        out[name] = {"origin": [-x0, -y0], "files": files}
        print(name, sid, "frames", n, "files", len(files), flush=True)
    (WORK / "jobs.json").write_text(json.dumps(out, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()

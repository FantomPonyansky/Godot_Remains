"""Export the trap visuals (vistriglaser, vistrigplate, vistrigcans, vistrigridge,
visdamshot, visdamgren, visdamexpl1, vismtrap): every root frame of each symbol.

FFDec never opens pfe.swf. swf_trim copies one symbol and what it needs into a
small SWF with a magenta origin marker on frame 1, and FFDec renders that.
godot/tools/pack_traps.gd packs trap_vis/jobs.json into sheets.

Usage: python export_traps.py [id ...]
"""

import json
import shutil
import subprocess
import sys
from pathlib import Path

import swf_trim as st

WORK = Path(__file__).resolve().parents[2] / "original" / "extracted_swf" / "trap_vis"
TRAPS = ["triglaser", "trigplate", "trigcans", "trigridge", "damshot", "damgren", "damexpl1", "mtrap"]
## parts.xml blind / stun, the player's status parts (Effect.secEffect, Unit.actions).
PARTS = {"fx_blind": "visualBlind", "fx_stun": "visualStun"}
HALF = 200


def render(swf, sid, dest):
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    subprocess.check_call([str(st.FFDEC), "-ignorebackground", "-format", "sprite:png", "-selectid", str(sid),
                           "-export", "sprite", str(dest), str(swf)], stdout=subprocess.DEVNULL)
    folders = [p for p in dest.iterdir() if p.is_dir() and p.name.split("_")[1] == str(sid)]
    return sorted(folders[0].glob("*.png"), key=lambda p: int(p.stem))


def main():
    only = sys.argv[1:]
    sw = st.Swf()
    WORK.mkdir(parents=True, exist_ok=True)
    jobs_path = WORK / "jobs.json"
    jobs = json.loads(jobs_path.read_text(encoding="utf-8")) if jobs_path.exists() else {}
    names = {tid: "vis" + tid for tid in TRAPS}
    names.update(PARTS)
    for tid, symbol in names.items():
        if only and tid not in only:
            continue
        sid = sw.symbols[symbol]
        frames, labels = sw.frames(sid)
        frames[0] = frames[0] + st.marker_place()
        swf = WORK / ("%s.swf" % tid)
        sw.trim([sid], swf, {sid: st.build_sprite(sid, frames)}, st.marker_defs(-HALF, -HALF, HALF, HALF))
        files = render(swf, sid, WORK / tid)
        jobs[tid] = {"origin": [HALF, HALF], "labels": labels,
                     "clips": {"all": {"files": [str(f) for f in files[:len(frames)]], "loop": False}}}
        print("trap", tid, "sid", sid, "frames", len(frames), "labels", labels, flush=True)
        jobs_path.write_text(json.dumps(jobs, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()

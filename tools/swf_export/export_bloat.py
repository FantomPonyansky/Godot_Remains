"""Export the looping visuals of bloatsprites (visualBloat0..10) and the nest (visualBloatEmitter).

Both are one-frame wrappers whose nested clip loops by itself in Flash: the 3-frame
`osn` wing flap of a bloat, the breathing 55-frame cluster of the nest. Same method as
export_fx.py: swf_trim copies one symbol into a small SWF, FFDec renders only that.
Jobs are merged into unit_vis/jobs.json (keys bloat0..bloat10, ebloat) for
godot/tools/pack_units.gd. "sym" asks the packer for a cell symmetric about the origin
so a mirrored sprite stays on the body.

Usage: python export_bloat.py [bloat0 ... ebloat]
"""

import json
import sys

import swf_trim as st
from export_fx import HALF, WORK, render
from export_story_art import longest_in

JOBS = {"bloat%d" % i: "visualBloat%d" % i for i in range(11)}
JOBS["ebloat"] = "visualBloatEmitter"


def main():
    only = sys.argv[1:]
    swf = st.Swf()
    jobs_path = WORK / "jobs.json"
    jobs = json.loads(jobs_path.read_text(encoding="utf-8")) if jobs_path.exists() else {}
    for key, symbol in JOBS.items():
        if only and key not in only:
            continue
        sid = swf.symbols.get(symbol)
        if sid is None:
            print("missing symbol", symbol, flush=True)
            continue
        frames, _labels = swf.frames(sid)
        n = longest_in(swf, frames[0]) if len(frames) == 1 else len(frames)
        frames = [[(t, b) for t, b in evs if t != 43] for evs in frames]
        frames[0] = frames[0] + st.marker_place()
        while len(frames) < n:
            frames.append([])
        files = render(swf, sid, frames, WORK / key, HALF)[:n]
        clips = {"stay": {"files": files, "loop": True}}
        if key != "ebloat":
            clips["fly"] = {"files": files, "loop": True}
        jobs[key] = {"origin": [HALF, HALF], "sheet": key, "sym": True, "clips": clips, "parts": {}}
        print(key, "sid", sid, "frames", n, "files", len(files), flush=True)
        jobs_path.write_text(json.dumps(jobs, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()

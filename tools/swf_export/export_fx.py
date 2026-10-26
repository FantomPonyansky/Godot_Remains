"""Export parts.xml particle visuals (Emitter vis=...) the vclass exporter did not cover.

FFDec never opens pfe.swf: swf_trim copies one symbol and its dependencies into a
small SWF with a magenta origin marker on frame 1, and FFDec renders that.
Jobs are merged into unit_vis/jobs.json as fx_<id>, so
godot/tools/pack_units.gd packs them into sheets/units like the other fx_ parts.

Usage: python export_fx.py [fx_id ...]
"""

import json
import shutil
import subprocess
import sys

import swf_trim as st
from export_story_art import longest_in

WORK = st.ROOT / "original" / "extracted_swf" / "unit_vis"
HALF = 300
WIDE = {"radioblast": 900, "blast": 500}

FX = {
    "gas": "visualGas", "pinkgas": "visualPinkGas", "steam": "visualSteam", "bubble": "visualBubble",
    "gold_spark": "gold_spark", "redray": "visualRedRay", "magsymbol": "visualMagSymbol",
    "plaexpl": "visualPlaExpl", "impexpl": "visualImpExpl", "iceexpl": "visualIceExpl",
    "sparkleexpl": "visualSparkleExpl", "acidexpl": "visualAcidExpl", "snow": "visualSnow",
    "die_spark": "die_spark", "zzz": "visualZzz", "radioblast": "visualRadioblast",
    "throw": "visualThrow", "unlock": "flUnlock", "plakap": "PlasmaKap", "sign1": "visualSign1",
    "bum": "visualBum", "buma": "visualBumAcid", "pole2": "visualPole2", "discharge": "visualDischarge",
    # visualPlayer children: shit (magic shield) and cryst (crystal shield, no class name).
    "shit": "visShit", "cryst": 3687, "inh": 3631, "slow": "visualSlow",
    "shmatok": "visualShmatok", "bloat_kap": "bloat_kap",
    "mwall": "vismwall", "gwalltile": "tileGwall", "gwall": "visualGwall", "blast": "visualBlast",
}


def render(swf, sid, frames, dest, half):
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    small = dest / "clip.swf"
    swf.trim([sid], small, {sid: st.build_sprite(sid, frames)}, st.marker_defs(-half, -half, half, half))
    subprocess.run([str(st.FFDEC), "-ignorebackground", "-format", "sprite:png", "-selectid", str(sid),
                    "-export", "sprite", str(dest / "out"), str(small)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    folder = next(p for p in (dest / "out").iterdir() if p.is_dir())
    small.unlink()
    return [str(f) for f in sorted(folder.glob("*.png"), key=lambda p: int(p.stem))]


def main():
    only = sys.argv[1:]
    swf = st.Swf()
    jobs_path = WORK / "jobs.json"
    jobs = json.loads(jobs_path.read_text(encoding="utf-8")) if jobs_path.exists() else {}
    for fid, symbol in FX.items():
        key = "fx_" + fid
        if only and key not in only:
            continue
        sid = symbol if isinstance(symbol, int) else swf.symbols.get(symbol)
        if sid is None:
            print("missing symbol", symbol, flush=True)
            continue
        frames, _labels = swf.frames(sid)
        n = len(frames)
        if n == 1:
            n = longest_in(swf, frames[0])
        frames = [[(t, b) for t, b in evs if t != 43] for evs in frames]
        frames[0] = frames[0] + st.marker_place()
        while len(frames) < n:
            frames.append([])
        half = WIDE.get(fid, HALF)
        files = render(swf, sid, frames, WORK / key, half)
        jobs[key] = {"origin": [half, half], "sheet": key,
                     "clips": {"stay": {"files": files[:n], "loop": False}}, "parts": {}}
        print(key, "sid", sid, "frames", n, "files", len(files), flush=True)
        jobs_path.write_text(json.dumps(jobs, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()

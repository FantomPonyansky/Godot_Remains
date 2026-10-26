"""World-object art the port drew as placeholders: Box / door vis<id> clips and
the missing backs.xml back_<id>_t|l|e clips from texture1.swf (Grafon numbObj /
numbBack), plus Bonus visualBonus and Trap vistrap<id>(2) from pfe.swf.

swf_trim copies only the wanted symbols into a small SWF with a magenta origin
marker on frame 1 of each; FFDec renders that, never pfe.swf or texture1.swf.
godot/tools/pack_objects.gd crops the frames and writes the offsets.

Usage: python export_objects.py, then pack_objects.gd, then python export_objects.py finish
"""

import json
import shutil
import subprocess
import sys
import zlib
from pathlib import Path

import swf_trim as st

WORK = Path(__file__).resolve().parents[2] / "original" / "extracted_swf" / "objects"
TEXTURE1 = st.ROOT / "original" / "swf" / "texture1.swf"

## Box (tip box) and door ids whose vis<id> the port had no art for.
BOXES = ["robocell", "couch", "radbarrel", "radbigbarrel", "work", "aaa", "barst", "bed", "brspr", "camp",
         "longtable", "moln1", "niche1", "reactor", "smotr", "table1", "table2", "table4", "tomb", "generat",
         "himlab", "p_luna", "stand", "stove", "table3", "vault", "wmap",
         "door_st1", "door_st2", "doorboss", "doorout", "doorprob", "exit",
         "inbasedoor", "indoor1", "indoor2", "indoor3", "indoor4", "inencldoor", "instdoor",
         "pcloud1", "tcloud1", "alarm", "detonator", "dsph", "elpanel", "knop1", "knop2", "knop3", "knop4"]
DOORS = ["alib1", "alib2", "basedoor", "encldoor", "enclpole", "stdoor"]
## backs.xml ids (own clip names) missing from backs.json.
BACKS = ["bio", "vpipes", "metal", "vpipe", "vpipel", "vpiper", "barf", "illum", "bannerl", "vitrina",
         "minst", "stbanner", "opora", "h109", "bar", "qgraff", "snar", "orudie"]
PFE = {"bonus_xp": "visualBonus", "trap_spikes": "vistrapspikes", "trap_spikes2": "vistrapspikes2",
       "trap_fspikes": "vistrapfspikes", "trap_fspikes2": "vistrapfspikes2"}
HALF = 1100


def _fws(src, dest):
    raw = src.read_bytes()
    if raw[:3] == b"FWS":
        return src
    assert raw[:3] == b"CWS"
    dest.write_bytes(b"FWS" + raw[3:8] + zlib.decompress(raw[8:]))
    return dest


def _batch(sw, jobs, name, out):
    """jobs: {key: symbol}. Renders every root frame of each symbol."""
    sids, edits = {}, {}
    for key, symbol in jobs.items():
        sid = sw.symbols[symbol]
        frames, labels = sw.frames(sid)
        frames[0] = frames[0] + st.marker_place()
        edits[sid] = st.build_sprite(sid, frames)
        sids[key] = (sid, symbol, len(frames), labels)
    small = WORK / ("%s.swf" % name)
    sw.trim([s[0] for s in sids.values()], small, edits, st.marker_defs(-HALF, -HALF, -HALF + 3, -HALF + 3))
    png = WORK / name
    if png.exists():
        shutil.rmtree(png)
    png.mkdir(parents=True)
    subprocess.check_call([str(st.FFDEC), "-ignorebackground", "-format", "sprite:png", "-zoom", "1",
                           "-select", ",".join(str(s[0]) for s in sids.values()), "-export", "sprite", str(png), str(small)],
                          stdout=subprocess.DEVNULL)
    for key, (sid, symbol, count, labels) in sids.items():
        folder = [p for p in png.iterdir() if p.is_dir() and p.name.split("_")[1] == str(sid)][0]
        files = sorted(folder.glob("*.png"), key=lambda p: int(p.stem))[:count]
        out[key] = {"symbol": symbol, "half": HALF, "labels": labels, "files": [str(f) for f in files]}
        print(key, symbol, "sid", sid, "frames", count, "labels", labels, flush=True)


def finish():
    """After pack_objects.gd: objects/manifest.json, and the backs.xml kinds added to backs.json."""
    import xml.etree.ElementTree as ET
    out = json.loads((WORK / "out.json").read_text(encoding="utf-8"))
    sprites = st.ROOT / "godot" / "assets" / "sprites"
    manifest = {}
    for key, e in out.items():
        if key.startswith("back_"):
            continue
        manifest[key[4:] if key.startswith("obj_") else key] = {
            "ox": e["ox"], "oy": e["oy"], "w": e["w"], "h": e["h"], "frames": e["frames"], "labels": e["labels"]}
    (sprites / "objects" / "manifest.json").write_text(json.dumps(manifest, indent=1, sort_keys=True), encoding="utf-8")
    backs_path = st.ROOT / "godot" / "assets" / "data" / "backs.json"
    backs = json.loads(backs_path.read_text(encoding="utf-8"))
    kinds = backs["kinds"]
    xml = ET.parse(st.ROOT / "original" / "reference" / "Remains-Source2" / "Modules" / "core" / "AllData" / "backs.xml").getroot()
    for node in xml.iter("back"):
        bid = node.get("id")
        if bid in kinds:
            continue
        clip = node.get("tid") or bid
        parts = {}
        for part in "tle":
            key = "back_%s_%s" % (clip, part)
            folder = sprites / "backs" / key
            if key in out:
                e = out[key]
                parts[part] = [{"path": "res://assets/sprites/backs/%s/%d.png" % (key, i + 1), "ox": e["ox"], "oy": e["oy"]}
                               for i in range(e["frames"])]
            elif folder.exists() and clip != bid:
                for k2, other in kinds.items():
                    if other.get("tid") == clip and other.get(part):
                        parts[part] = other[part]
                        break
        if not parts:
            continue
        kinds[bid] = {"x2": float(node.get("x2", 1)), "y2": float(node.get("y2", 1)), "s": int(node.get("s", 0)),
                      "alpha": float(node.get("alpha", 1)), "blend": node.get("blend", ""), "mirr": node.get("mirr", ""),
                      "fr": int(node.get("fr", 0)), "lon": int(node.get("lon", 0)), "loff": int(node.get("loff", 0)),
                      "er": node.get("er") == "1", "tid": node.get("tid", ""),
                      "t": parts.get("t", []), "l": parts.get("l", []), "e": parts.get("e", [])}
        print("back kind", bid)
    backs_path.write_text(json.dumps(backs, separators=(",", ":"), ensure_ascii=False), encoding="utf-8")


def main():
    if sys.argv[1:] == ["finish"]:
        finish()
        return
    WORK.mkdir(parents=True, exist_ok=True)
    tex = st.Swf(_fws(TEXTURE1, WORK / "texture1.fws"))
    out = {}
    _batch(tex, {"obj_" + i: "vis" + i for i in BOXES + DOORS}, "t1_objs", out)
    backs = {}
    for i in BACKS:
        for part in "tle":
            if "back_%s_%s" % (i, part) in tex.symbols:
                backs["back_%s_%s" % (i, part)] = "back_%s_%s" % (i, part)
    _batch(tex, backs, "t1_backs", out)
    _batch(st.Swf(), PFE, "pfe_objs", out)
    (WORK / "jobs.json").write_text(json.dumps(out, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()

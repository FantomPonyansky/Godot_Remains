"""Wall debris parts (parts.xml kusok / kusoch / schep / steklo ...): one PNG per
frame of each visual, plus debris.json with the frame count and the anchor
(pixels from a PNG's top-left to the symbol origin).

swf_trim writes a small SWF with only these symbols; FFDec renders that.
Never runs -export sprite on pfe.swf.
"""

import json
import subprocess

import swf_trim as st
from export_sats import _bounds

NAMES = {
    "kusok": "visualKusok", "kusokB": "visualKusokB", "kusokD": "visualKusokD",
    "steklo": "visualSteklo", "kusoch": "visualKusoch", "kusochB": "visualKusochB",
    "schep": "visualSchep", "schepoch": "visualSchepoch",
}
WORK = st.ROOT / "original" / "extracted_swf" / "debris"
DEST = st.ROOT / "godot" / "assets" / "sprites" / "debris"


def main():
    swf = st.Swf()
    ids = {k: swf.symbols[v] for k, v in NAMES.items()}
    WORK.mkdir(parents=True, exist_ok=True)
    small = WORK / "debris.swf"
    swf.trim(list(ids.values()), small)
    png = WORK / "png"
    if png.exists():
        for child in sorted(png.rglob("*"), reverse=True):
            child.unlink() if child.is_file() else child.rmdir()
    png.mkdir(parents=True, exist_ok=True)
    sel = ",".join(str(v) for v in ids.values())
    subprocess.check_call([str(st.FFDEC), "-ignorebackground", "-format", "sprite:png", "-select", sel,
                           "-export", "sprite", str(png), str(small)], stdout=subprocess.DEVNULL)
    DEST.mkdir(parents=True, exist_ok=True)
    table = {}
    for key, sid in ids.items():
        folder = [p for p in png.glob("DefineSprite_%d*" % sid) if p.name.split("_")[1] == str(sid)][0]
        files = sorted(folder.glob("*.png"), key=lambda p: int(p.stem))
        for i, f in enumerate(files):
            (DEST / ("%s_%d.png" % (key, i))).write_bytes(f.read_bytes())
        box = _bounds(swf, sid)
        table[key] = {"frames": len(files), "anchor": [round(-box[0], 2), round(-box[1], 2)] if box else [0, 0]}
    (DEST / "debris.json").write_text(json.dumps(table, indent=1), encoding="utf-8")
    print(json.dumps(table, indent=1))


if __name__ == "__main__":
    main()

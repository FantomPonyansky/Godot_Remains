"""visualGUI.portCel (sprite 4459): the spell_port target marker, frames
1 charging / 2 ready / 3 blocked. One PNG per frame plus port_cel.json with
the anchor (pixels from a PNG's top-left to the symbol origin).

swf_trim writes a small SWF with only this symbol; FFDec renders that.
Never runs -export sprite on pfe.swf.
"""

import json
import subprocess

import swf_trim as st
from export_sats import _bounds

PORT_CEL = 4459
WORK = st.ROOT / "original" / "extracted_swf" / "portcel"
DEST = st.ROOT / "godot" / "assets" / "sprites" / "gui"


def main():
    swf = st.Swf()
    WORK.mkdir(parents=True, exist_ok=True)
    small = WORK / "portcel.swf"
    swf.trim([PORT_CEL], small)
    png = WORK / "png"
    if png.exists():
        for child in sorted(png.rglob("*"), reverse=True):
            child.unlink() if child.is_file() else child.rmdir()
    png.mkdir(parents=True, exist_ok=True)
    subprocess.check_call([str(st.FFDEC), "-ignorebackground", "-format", "sprite:png", "-select", str(PORT_CEL),
                           "-export", "sprite", str(png), str(small)], stdout=subprocess.DEVNULL)
    DEST.mkdir(parents=True, exist_ok=True)
    folder = [p for p in png.glob("DefineSprite_%d*" % PORT_CEL) if p.name.split("_")[1] == str(PORT_CEL)][0]
    files = sorted(folder.glob("*.png"), key=lambda p: int(p.stem))
    for i, f in enumerate(files):
        (DEST / ("port_cel_%d.png" % (i + 1))).write_bytes(f.read_bytes())
    box = _bounds(swf, PORT_CEL)
    table = {"frames": len(files), "anchor": [round(-box[0], 2), round(-box[1], 2)] if box else [0, 0]}
    (DEST / "port_cel.json").write_text(json.dumps(table, indent=1), encoding="utf-8")
    print(json.dumps(table))


if __name__ == "__main__":
    main()

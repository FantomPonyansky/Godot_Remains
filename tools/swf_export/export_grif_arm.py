"""visualGrifArm1-5 (UnitMerc.arm) into godot/assets/sprites/units/grif_arm/<n>.png + arm.json.

arm.json {n: {"anchor": [x, y], "emit": [x, y]}}: anchor is the registration point inside the
png (from FFDec's svg transform), emit the claw point in the clip's own space.
"""
import json
import re
import shutil
import subprocess
from pathlib import Path

import swf_trim as st

ARMS = {1: 2245, 2: 2237, 3: 2229, 4: 2221, 5: 2214}
WORK = Path(__file__).resolve().parents[2] / "tmp" / "_grif_arm_tmp"
OUT = Path(__file__).resolve().parents[2] / "godot" / "assets" / "sprites" / "units" / "grif_arm"


def sbits(b, n):
    v = b.ub(n)
    return v - (1 << n) if n and v & (1 << (n - 1)) else v


def translate(body, tag):
    flags = body[0]
    pos = (2 if tag == 70 else 1) + 2
    if tag == 70 and body[1] & 0x08:
        pos = body.index(0, pos) + 1
    if flags & 0x02:
        pos += 2
    if not flags & 0x04:
        return 0.0, 0.0
    b = st._Bits(body, pos)
    if b.ub(1):
        n = b.ub(5)
        b.ub(n * 2)
    if b.ub(1):
        n = b.ub(5)
        b.ub(n * 2)
    n = b.ub(5)
    return sbits(b, n) / 20.0, sbits(b, n) / 20.0


def emit_of(swf, sid):
    frames, _ = swf.frames(sid)
    for tag, body in frames[0]:
        if tag in st.PLACE and st.place_name(tag, body) == "emit":
            return translate(body, tag)
    return 0.0, 0.0


def ffdec(args):
    subprocess.run([str(st.FFDEC)] + args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    swf = st.Swf()
    if WORK.exists():
        shutil.rmtree(WORK)
    WORK.mkdir(parents=True)
    small = WORK / "arm.swf"
    swf.trim(list(ARMS.values()), small)
    sel = ",".join("%d:1" % sid for sid in ARMS.values())
    ffdec(["-ignorebackground", "-format", "sprite:png", "-select", sel, "-export", "sprite", str(WORK / "png"), str(small)])
    ffdec(["-format", "sprite:svg", "-select", sel, "-export", "sprite", str(WORK / "svg"), str(small)])
    OUT.mkdir(parents=True, exist_ok=True)
    meta = {}
    for n, sid in ARMS.items():
        png = next((WORK / "png").glob("DefineSprite_%d*/1.png" % sid))
        svg = next((WORK / "svg").glob("DefineSprite_%d*/1.svg" % sid)).read_text(encoding="utf-8")
        m = re.search(r'matrix\(1\.0, 0\.0, 0\.0, 1\.0, ([-\d.]+), ([-\d.]+)\)', svg)
        anchor = [float(m.group(1)), float(m.group(2))] if m else [0.0, 0.0]
        (OUT / ("%d.png" % n)).write_bytes(png.read_bytes())
        ex, ey = emit_of(swf, sid)
        meta[str(n)] = {"anchor": [round(anchor[0], 2), round(anchor[1], 2)], "emit": [round(ex, 2), round(ey, 2)]}
    (OUT / "arm.json").write_text(json.dumps(meta), encoding="utf-8")
    shutil.rmtree(WORK)
    print(meta)


if __name__ == "__main__":
    main()

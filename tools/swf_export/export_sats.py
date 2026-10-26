"""SATS art: the screen frame (visualGUI.sats), the AP bar (visualGUI.odBar
bar / bar2 / mask) and the satsCel / satsUnCel / satsRadius stubs.

swf_trim writes a small SWF with only these symbols; FFDec renders that.
Never runs -export sprite on pfe.swf. sats.json records each PNG's
registration point (pixels from the PNG's top-left to the symbol origin)
and, for the bar parts, where odBar places them.
"""

import json
import struct
import subprocess
from pathlib import Path

import swf_trim as st

NAMES = {"frame": 4362, "bar2": 4364, "bar": 4369, "mask": 4367,
         "cel": "satsCel", "uncel": "satsUnCel", "radius": "satsRadius"}
OD_BAR = 4371
WORK = st.ROOT / "original" / "extracted_swf" / "sats"
DEST = st.ROOT / "godot" / "assets" / "sprites" / "sats"


def _matrix(buf, pos):
    b = st._Bits(buf, pos)

    def sb(n):
        v = b.ub(n)
        return v - (1 << n) if n and v >> (n - 1) else v

    sx = sy = 1.0
    r0 = r1 = 0.0
    if b.ub(1):
        n = b.ub(5)
        sx, sy = sb(n) / 65536.0, sb(n) / 65536.0
    if b.ub(1):
        n = b.ub(5)
        r0, r1 = sb(n) / 65536.0, sb(n) / 65536.0
    n = b.ub(5)
    tx, ty = sb(n) / 20.0, sb(n) / 20.0
    return (sx, r0, r1, sy, tx, ty)


def _place_matrix(tag, body):
    flags = body[0]
    pos = (2 if tag == 70 else 1) + 2
    if tag == 70 and body[1] & 0x08:
        pos = body.index(0, pos) + 1
    if flags & 0x02:
        pos += 2
    if flags & 0x04:
        return _matrix(body, pos)
    return (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)


def _shape_rect(swf, cid):
    for tag, body in swf.top:
        if tag in (2, 22, 32, 83) and struct.unpack_from("<H", body, 0)[0] == cid:
            b = st._Bits(body, 2)
            n = b.ub(5)

            def sb():
                v = b.ub(n)
                return v - (1 << n) if v >> (n - 1) else v

            x0, x1, y0, y1 = sb(), sb(), sb(), sb()
            return [x0 / 20.0, y0 / 20.0, x1 / 20.0, y1 / 20.0]
    return None


def _bounds(swf, cid):
    if cid not in swf.sprites:
        return _shape_rect(swf, cid)
    box = None
    for tag, body in swf.sprite_tags(cid):
        if tag not in st.PLACE:
            continue
        child = st.place_cid(tag, body)
        if child is None:
            continue
        r = _bounds(swf, child)
        if r is None:
            continue
        a, b, c, d, tx, ty = _place_matrix(tag, body)
        xs, ys = [], []
        for x, y in ((r[0], r[1]), (r[2], r[1]), (r[0], r[3]), (r[2], r[3])):
            xs.append(a * x + c * y + tx)
            ys.append(b * x + d * y + ty)
        r = [min(xs), min(ys), max(xs), max(ys)]
        box = r if box is None else [min(box[0], r[0]), min(box[1], r[1]), max(box[2], r[2]), max(box[3], r[3])]
    return box


def main():
    swf = st.Swf()
    ids = {k: (v if isinstance(v, int) else swf.symbols[v]) for k, v in NAMES.items()}
    WORK.mkdir(parents=True, exist_ok=True)
    small = WORK / "sats.swf"
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
        first = sorted(folder.glob("*.png"), key=lambda p: int(p.stem))[0]
        (DEST / ("%s.png" % key)).write_bytes(first.read_bytes())
        box = _bounds(swf, sid)
        table[key] = {"anchor": [round(-box[0], 2), round(-box[1], 2)] if box else [0, 0], "box": box}
    for tag, body in swf.sprite_tags(OD_BAR):
        if tag in st.PLACE and st.place_name(tag, body):
            m = _place_matrix(tag, body)
            table.setdefault("od_bar", {})[st.place_name(tag, body)] = {"at": [m[4], m[5]], "scale": [m[0], m[3]]}
    (DEST / "sats.json").write_text(json.dumps(table, indent=1), encoding="utf-8")
    print(json.dumps(table, indent=1))


if __name__ == "__main__":
    main()

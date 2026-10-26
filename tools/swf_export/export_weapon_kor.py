"""Kor-only sheets for the held-weapon clips that have a 'kor' child.

UnitPon.weaponLevit puts teleFilter on vis.kor when it exists, so the glow
must come from that layer alone. Each kor clip is copied with every
PlaceObject / RemoveObject on a non-kor depth dropped, rendered from a small
trimmed SWF, and pasted into a sheet laid out exactly like the full clip's
sheet (same cell, pad, cols and map). Never runs -export sprite on pfe.swf.
"""

import json
import struct
import subprocess

import export_weapons as ew
import export_weapon_frames as ewf

WORK = ew.WORK / "kor"
SHEETS = ew.OUT / "sheets"
SEARCH = 4


def depth_of(code, buf, start):
    if code == 26:
        return struct.unpack_from("<H", buf, start + 1)[0]
    if code == 70:
        return struct.unpack_from("<H", buf, start + 2)[0]
    if code == 28:
        return struct.unpack_from("<H", buf, start)[0]
    if code == 5:
        return struct.unpack_from("<H", buf, start + 2)[0]
    return None


def kor_only(mod, chars, sid):
    frames, _labels = mod.walk_sprite(chars, sid)
    keep = {ev[1] for evs in frames for ev in evs if ev[0] == "place" and ev[6] == "kor"}
    body = chars[sid][1]
    out = bytearray(body[:4])
    pos = 4
    while pos < len(body):
        code, start, end = mod.read_tag_at(body, pos)
        depth = depth_of(code, body, start)
        if depth is None or depth in keep:
            out += body[pos:end]
        pos = end
        if code == 0:
            break
    head = struct.pack("<HI", (39 << 6) | 0x3F, len(out))
    return (39, bytes(out), head + bytes(out))


def frames_of(folder):
    files = sorted(folder.glob("*.png"), key=lambda p: int(p.stem))
    return [ewf.read_png(f) for f in files]


def best_shift(full, kor):
    """Offset of the kor render inside the full render (FFDec crops each to its own bounds)."""
    fw, fh, frows = full
    kw, kh, krows = kor
    guess_x = 0
    guess_y = 0
    best = None
    for dy in range(-SEARCH, fh - kh + SEARCH + 1):
        for dx in range(-SEARCH, fw - kw + SEARCH + 1):
            err = 0
            hits = 0
            for y in range(0, kh, 2):
                fy = y + dy
                for x in range(0, kw, 2):
                    a = krows[y][x * 4 + 3]
                    if a < 250:
                        continue
                    fx = x + dx
                    if fx < 0 or fy < 0 or fx >= fw or fy >= fh:
                        err += 255 * 3
                        continue
                    hits += 1
                    for c in range(3):
                        err += abs(krows[y][x * 4 + c] - frows[fy][fx * 4 + c])
            score = err / max(hits, 1)
            if best is None or score < best[0]:
                best = (score, dx, dy)
    return best[1], best[2]


def main():
    mod = ew.load_mod()
    _data, _tags, chars, extras = mod.load()
    symbols = ew.load_symbols()
    manifest = json.loads((ew.OUT / "manifest.json").read_text(encoding="utf-8"))
    clips = manifest["clips"]
    names = [n for n, rec in clips.items() if rec.get("kor") and n in symbols]
    WORK.mkdir(parents=True, exist_ok=True)
    patched = dict(chars)
    ids = set()
    for name in names:
        sid = symbols[name]
        patched[sid] = kor_only(mod, chars, sid)
        dep, _b = mod.deps_of(patched, sid)
        ids |= set(dep)
    swf = WORK / "kor.swf"
    mod.write_swf(patched, extras, ids, swf)
    dest = WORK / "png"
    if dest.exists():
        for child in sorted(dest.rglob("*"), reverse=True):
            child.unlink() if child.is_file() else child.rmdir()
    dest.mkdir(parents=True, exist_ok=True)
    sel = ",".join(str(symbols[n]) for n in names)
    subprocess.check_call([str(ew.FFDEC), "-ignorebackground", "-format", "sprite:png", "-select", sel,
                           "-export", "sprite", str(dest), str(swf)], stdout=subprocess.DEVNULL)
    full_dir = ewf.WORK / "png"
    for name in names:
        sid = symbols[name]
        rec = clips[name]
        kfold = [p for p in dest.glob("DefineSprite_%d*" % sid) if p.name.split("_")[1] == str(sid)][0]
        ffold = [p for p in full_dir.glob("DefineSprite_%d*" % sid) if p.name.split("_")[1] == str(sid)][0]
        kor = frames_of(kfold)
        full = frames_of(ffold)
        dx, dy = best_shift(full[0], kor[0])
        cw, ch = rec["cell"]
        pad = rec["pad"]
        cols = rec["cols"]
        cell_map = rec["map"]
        cells = max(cell_map) + 1
        nrows = (cells + cols - 1) // cols
        sheet = [bytearray(cols * cw * 4) for _ in range(nrows * ch)]
        done = set()
        for frame, cell in enumerate(cell_map):
            if cell in done or frame >= len(kor):
                continue
            done.add(cell)
            kw, kh, krows = kor[frame]
            ox = (cell % cols) * cw + pad + dx
            oy = (cell // cols) * ch + pad + dy
            for y in range(kh):
                ty = oy + y
                if ty < (cell // cols) * ch or ty >= (cell // cols + 1) * ch:
                    continue
                for x in range(kw):
                    tx = ox + x
                    if tx < (cell % cols) * cw or tx >= (cell % cols + 1) * cw:
                        continue
                    sheet[ty][tx * 4:tx * 4 + 4] = krows[y][x * 4:x * 4 + 4]
        ewf.write_png(SHEETS / ("%s_kor.png" % name), cols * cw, nrows * ch, sheet)
        rec["kor_sheet"] = "sheets/%s_kor.png" % name
        print(name, len(kor), "frames", "shift", dx, dy, flush=True)
    (ew.OUT / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")


if __name__ == "__main__":
    main()

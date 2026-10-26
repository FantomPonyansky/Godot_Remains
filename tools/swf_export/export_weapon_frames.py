"""Export every timeline frame of the held-weapon vis clips (plus visVzz,
visualGilza and the impact flare clips) into one padded sheet per clip.

Builds on export_weapons.py: a trimmed SWF holds only the wanted symbols,
FFDec renders that small file, and frame scripts come from a narrow
-selectclass script export. Never runs -export sprite on pfe.swf.
"""

import hashlib
import json
import math
import re
import struct
import subprocess
import zlib
from pathlib import Path

import export_weapons as ew

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / "original" / "extracted_swf" / "weapon_vis" / "frames"
OUT = ew.OUT
SHEETS = OUT / "sheets"
PAD = 8
EXTRA = ["visVzz", "visualGilza", "flSpark", "flSparkl", "flLaser", "flLaser2",
         "flPlasma", "flPlasma2", "visualFlare", "visualIceFlare", "visualTeleFlare",
         "flPlevok", "flDray", "visualBum", "visualBumNecro", "visualFlame", "visualEclipse"]
ORIG = ROOT / "original" / "reference" / "Remains-Source2" / "Modules" / "core" / "AllData" / "weapons.json"


def read_png(path):
    data = path.read_bytes()
    pos = 8
    idat = b""
    plte = None
    trns = None
    while pos < len(data):
        n = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + n]
        if kind == b"IHDR":
            w, h, depth, ctype, _c, _f, interlace = struct.unpack(">IIBBBBB", body)
        elif kind == b"PLTE":
            plte = body
        elif kind == b"tRNS":
            trns = body
        elif kind == b"IDAT":
            idat += body
        pos += 12 + n
    assert depth == 8 and interlace == 0, (path, depth, interlace)
    bpp = {6: 4, 2: 3, 3: 1, 0: 1, 4: 2}[ctype]
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows = []
    prev = bytearray(stride)
    i = 0
    for _y in range(h):
        f = raw[i]
        line = bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + b) & 255
            elif f == 3:
                line[x] = (line[x] + ((a + b) >> 1)) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        rows.append(line)
        prev = line
    out = []
    for line in rows:
        px = bytearray(w * 4)
        for x in range(w):
            if ctype == 6:
                px[x * 4:x * 4 + 4] = line[x * 4:x * 4 + 4]
            elif ctype == 2:
                px[x * 4:x * 4 + 3] = line[x * 3:x * 3 + 3]
                px[x * 4 + 3] = 255
            elif ctype == 3:
                k = line[x]
                px[x * 4:x * 4 + 3] = plte[k * 3:k * 3 + 3]
                px[x * 4 + 3] = trns[k] if trns and k < len(trns) else 255
            elif ctype == 0:
                px[x * 4:x * 4 + 3] = bytes([line[x]] * 3)
                px[x * 4 + 3] = 255
            else:
                px[x * 4:x * 4 + 3] = bytes([line[x * 2]] * 3)
                px[x * 4 + 3] = line[x * 2 + 1]
        out.append(px)
    return w, h, out


def write_png(path, w, h, rows):
    raw = b"".join(b"\x00" + bytes(r) for r in rows)

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def frame_places(mod, chars, sid):
    """Per frame: emit position and whether a 'kor' instance is on stage."""
    frames, _labels = mod.walk_sprite(chars, sid)
    depths = {}
    emits = []
    kor = False
    for evs in frames:
        for ev in evs:
            if ev[0] == "remove":
                depths.pop(ev[1], None)
                continue
            if ev[0] != "place":
                continue
            depth, matrix, name = ev[1], ev[3], ev[6]
            prev = depths.get(depth)
            depths[depth] = [matrix if matrix else (prev[0] if prev else None), name if name else (prev[1] if prev else "")]
        found = None
        for matrix, name in depths.values():
            if name == "kor":
                kor = True
            if name == "emit" and matrix:
                found = [round(matrix[4] / 20.0, 2), round(matrix[5] / 20.0, 2)]
        emits.append(found)
    return emits, kor


def parse_scripts(folder):
    out = {}
    for path in folder.rglob("*.as"):
        text = path.read_text(encoding="utf-8", errors="replace")
        m = re.search(r"addFrameScript\(([^;]*)\);", text)
        if not m:
            continue
        args = [a.strip() for a in m.group(1).split(",")]
        table = {}
        for i in range(0, len(args) - 1, 2):
            frame = int(args[i]) + 1
            fn = args[i + 1].replace("this.", "")
            body = re.search(r"function %s\(\)[^{]*\{(.*?)\n      \}" % re.escape(fn), text, re.S)
            src = body.group(1) if body else ""
            act = None
            g = re.search(r"gotoAndStop\(([^)]*)\)", src)
            p = re.search(r"gotoAndPlay\(([^)]*)\)", src)
            if g:
                act = ["stop", g.group(1).strip().strip('"')]
            elif p:
                act = ["play", p.group(1).strip().strip('"')]
            elif "stop()" in src:
                act = ["stop", None]
            if act:
                table[str(frame)] = act
        out[path.stem] = table
    return out


def main():
    mod = ew.load_mod()
    _data, _tags, chars, extras = mod.load()
    symbols = ew.load_symbols()
    manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
    clips = manifest["clips"]
    names = list(clips.keys()) + [n for n in EXTRA if n in symbols]
    info = {}
    for name in names:
        frames, labels = mod.walk_sprite(chars, symbols[name])
        info[name] = {"frames": len(frames), "labels": labels}
    WORK.mkdir(parents=True, exist_ok=True)
    ids = set()
    for name in names:
        dep, _b = mod.deps_of(chars, symbols[name])
        ids |= set(dep)
    swf = WORK / "frames.swf"
    mod.write_swf(chars, extras, ids, swf)
    dest = WORK / "png"
    if dest.exists():
        for child in sorted(dest.rglob("*"), reverse=True):
            child.unlink() if child.is_file() else child.rmdir()
    dest.mkdir(parents=True, exist_ok=True)
    sel = ",".join(str(symbols[n]) for n in names)
    subprocess.check_call([str(ew.FFDEC), "-ignorebackground", "-format", "sprite:png", "-select", sel,
                           "-export", "sprite", str(dest), str(swf)], stdout=subprocess.DEVNULL)
    animated = [n for n in names if info[n]["frames"] > 1]
    script_dir = WORK / "as"
    if not script_dir.exists():
        subprocess.check_call([str(ew.FFDEC), "-selectclass", ",".join(animated), "-export", "script",
                               str(script_dir), str(ROOT / "original" / "swf" / "pfe.swf")], stdout=subprocess.DEVNULL)
    scripts = parse_scripts(script_dir)
    SHEETS.mkdir(parents=True, exist_ok=True)
    for old in SHEETS.glob("*.png"):
        old.unlink()
    extra_out = {}
    for name in names:
        sid = symbols[name]
        folder = dest / ("DefineSprite_%d_%s" % (sid, name))
        if not folder.exists():
            matches = [p for p in dest.glob("DefineSprite_%d*" % sid) if p.name.split("_")[1] == str(sid)]
            folder = matches[0]
        files = sorted(folder.glob("*.png"), key=lambda p: int(p.stem))
        uniq = []
        seen = {}
        cell_of = []
        size = None
        for f in files:
            key = hashlib.md5(f.read_bytes()).hexdigest()
            if key not in seen:
                w, h, rows = read_png(f)
                size = size or (w, h)
                assert (w, h) == size, (name, f, (w, h), size)
                seen[key] = len(uniq)
                uniq.append(rows)
            cell_of.append(seen[key])
        w, h = size
        cw, ch = w + PAD * 2, h + PAD * 2
        cols = max(1, min(len(uniq), 4096 // cw))
        nrows = int(math.ceil(len(uniq) / float(cols)))
        sheet = [bytearray(cols * cw * 4) for _ in range(nrows * ch)]
        for i, rows in enumerate(uniq):
            ox = (i % cols) * cw + PAD
            oy = (i // cols) * ch + PAD
            for y in range(h):
                sheet[oy + y][ox * 4:(ox + w) * 4] = rows[y]
        write_png(SHEETS / ("%s.png" % name), cols * cw, nrows * ch, sheet)
        rect = ew.shape_rect(mod, chars, sid)
        anchor = [round(-rect[0] / 20.0, 2), round(-rect[2] / 20.0, 2)] if rect else [0, 0]
        emits, kor = frame_places(mod, chars, sid)
        entry = clips.get(name) or {"anchor": anchor, "png": [w, h]}
        entry["sheet"] = "sheets/%s.png" % name
        entry["cell"] = [cw, ch]
        entry["pad"] = PAD
        entry["cols"] = cols
        entry["map"] = cell_of
        entry["labels"] = info[name]["labels"]
        entry["script"] = scripts.get(name, {})
        if kor:
            entry["kor"] = True
        distinct = {json.dumps(e) for e in emits if e}
        if len(distinct) > 1:
            entry["emit_frames"] = emits
        if name in clips:
            clips[name] = entry
        else:
            extra_out[name] = entry
        print(name, len(files), "frames", len(uniq), "unique", flush=True)
    manifest["fx_clips"] = extra_out
    manifest["fx"] = build_fx(manifest["ids"])
    (OUT / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")


def build_fx(ids):
    """Presentation fields from the original weapons.json that the port catalog lacks."""
    orig = json.loads(ORIG.read_text(encoding="utf-8"))
    keep = {
        "phis_recoil": "recoil", "phis_drot2": "drot2", "phis_massa": "massa", "vis_shell": "shell",
        "vis_flare": "flare", "vis_vbul": "visbul", "snd_reload": "snd_reload", "snd_prep": "snd_prep",
        "snd_t1": "snd_t1", "snd_t2": "snd_t2", "mtip": "mtip", "vis_lasm": "lasm", "char_pow": "pow",
        "char_combo": "combo", "crack": "crack", "vis_shine": "shine", "vis_tipdec": "tipdec", "tip": "tip",
        "snd_shoot": "snd_shoot", "char_knock": "knock", "snd_hit": "snd_hit",
    }
    out = {}
    for wid, row in orig.items():
        if wid not in ids and row.get("tip") in ("internal", "magic"):
            continue
        rec = {short: row[k] for k, short in keep.items() if k in row}
        if "flare" not in rec and "visbul" in rec:
            rec["flare"] = rec["visbul"]
        out[wid] = rec
    return out


if __name__ == "__main__":
    main()

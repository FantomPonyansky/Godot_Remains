"""Wall hole and scorch decals drawn by Grafon.dyrka / Grafon.tileDie.

Same route as export_weapon_frames.py: a trimmed SWF holds only these
symbols, FFDec renders that small file. Each clip becomes one horizontal
strip of its distinct frames in godot/assets/sprites/decals, and decals.json
records the cell size and the registration point inside a cell.
Never runs -export sprite on pfe.swf.
"""

import hashlib
import json
import subprocess

import export_weapons as ew
import export_weapon_frames as ewf

NAMES = ["bullet_metal", "bullet_tre", "bullet_dyr", "punch_tre", "expl_tre", "metal_tre",
         "bullet_wood", "fire_soft", "laser_tre", "plasma_soft", "plasma_dyr", "plasma_tre",
         "bluplasma_tre", "pinkplasma_tre", "cryo_soft", "plaexpl_tre",
         "block_dyr", "block_tre", "block_bur", "block_plav", "block_pla"]
WORK = ewf.ROOT / "original" / "extracted_swf" / "decals"
DEST = ewf.ROOT / "godot" / "assets" / "sprites" / "decals"


def main():
    mod = ew.load_mod()
    _data, _tags, chars, extras = mod.load()
    symbols = ew.load_symbols()
    names = [n for n in NAMES if n in symbols]
    ids = set()
    for name in names:
        dep, _b = mod.deps_of(chars, symbols[name])
        ids |= set(dep)
    WORK.mkdir(parents=True, exist_ok=True)
    swf = WORK / "decals.swf"
    mod.write_swf(chars, extras, ids, swf)
    png = WORK / "png"
    if png.exists():
        for child in sorted(png.rglob("*"), reverse=True):
            child.unlink() if child.is_file() else child.rmdir()
    png.mkdir(parents=True, exist_ok=True)
    sel = ",".join(str(symbols[n]) for n in names)
    subprocess.check_call([str(ew.FFDEC), "-ignorebackground", "-format", "sprite:png", "-select", sel,
                           "-export", "sprite", str(png), str(swf)], stdout=subprocess.DEVNULL)
    DEST.mkdir(parents=True, exist_ok=True)
    table = {}
    for name in names:
        sid = symbols[name]
        folder = [p for p in png.glob("DefineSprite_%d*" % sid) if p.name.split("_")[1] == str(sid)][0]
        files = sorted(folder.glob("*.png"), key=lambda p: int(p.stem))
        uniq = []
        seen = set()
        size = None
        for f in files:
            key = hashlib.md5(f.read_bytes()).hexdigest()
            if key in seen:
                continue
            seen.add(key)
            w, h, rows = ewf.read_png(f)
            size = size or (w, h)
            assert (w, h) == size, (name, f)
            uniq.append(rows)
        w, h = size
        strip = [bytearray(w * len(uniq) * 4) for _ in range(h)]
        for i, rows in enumerate(uniq):
            for y in range(h):
                strip[y][i * w * 4:(i + 1) * w * 4] = rows[y]
        ewf.write_png(DEST / ("%s.png" % name), w * len(uniq), h, strip)
        rect = ew.shape_rect(mod, chars, sid)
        anchor = [round(-rect[0] / 20.0, 2), round(-rect[2] / 20.0, 2)] if rect else [w / 2.0, h / 2.0]
        table[name] = {"cell": [w, h], "frames": len(uniq), "anchor": anchor}
        print(name, len(files), "frames", len(uniq), "unique", (w, h), anchor, flush=True)
    (DEST / "decals.json").write_text(json.dumps(table, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()

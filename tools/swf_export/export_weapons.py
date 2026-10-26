"""Export frame 1 of each held-weapon vis clip into a trimmed SWF.

Does not run FFDec -export sprite on pfe.swf. The parser copies the known
vis symbols and their shapes, then FFDec renders that small file.
"""

import json
import marshal
import struct
import subprocess
import types
from pathlib import Path

PYC = (Path(__file__).resolve().parents[2] / r"tools\__pycache__\_export_polz.cpython-39.pyc")
FFDEC = (Path(__file__).resolve().parents[2] / r"tools\ffdec\ffdec-cli.exe")
SYMBOLS = (Path(__file__).resolve().parents[2] / r"original\tile_extract\sym_pfe\symbols.csv")
WEAPONS_JSON = (Path(__file__).resolve().parents[2] / r"godot\assets\data\weapons.json")
WEAPONS_XML = (Path(__file__).resolve().parents[2] / r"original\reference\Remains-Source2\Modules\core\AllData\weapons.xml")
WORK = (Path(__file__).resolve().parents[2] / r"original\extracted_swf\weapon_vis")
OUT = (Path(__file__).resolve().parents[2] / r"godot\assets\sprites\weapons\held")
SKIP_KIND = {"magic", "internal", "spell"}


def load_mod():
    code = marshal.loads(PYC.read_bytes()[16:])
    mod = types.ModuleType("ep")
    exec(code, mod.__dict__)
    return mod


def load_symbols():
    names = {}
    for line in SYMBOLS.read_text(encoding="utf-8").splitlines():
        if ";" not in line:
            continue
        sid, raw = line.split(";", 1)
        name = raw.strip().strip('"')
        if name:
            names[name] = int(sid)
    return names


def load_overrides():
    # vis vweap= on a weapon replaces vis{id}.
    text = WEAPONS_XML.read_text(encoding="utf-8", errors="replace")
    overrides = {}
    current = ""
    for line in text.splitlines():
        if "<weapon " in line and "id='" in line:
            current = line.split("id='", 1)[1].split("'", 1)[0]
        if current and "vweap='" in line:
            overrides[current] = line.split("vweap='", 1)[1].split("'", 1)[0]
    return overrides


def clip_name(weapon_id, overrides):
    if weapon_id in overrides:
        return overrides[weapon_id]
    if "^" in weapon_id:
        base, suffix = weapon_id.split("^", 1)
        return "vis%s_%s" % (base, suffix)
    return "vis" + weapon_id


def resolve(weapon_id, overrides, symbols):
    primary = clip_name(weapon_id, overrides)
    if primary in symbols:
        return primary
    base = weapon_id.split("^", 1)[0]
    fallback = "vis" + base
    if fallback in symbols:
        return fallback
    if "visp10mm" in symbols:
        return "visp10mm"
    return ""


def shape_rect(mod, chars, cid, stack=None):
    stack = set() if stack is None else stack
    if cid in stack or cid not in chars:
        return None
    stack = set(stack)
    stack.add(cid)
    tag = chars[cid][0]
    if tag != 39:
        rect = mod.char_bounds(chars, cid, "local", set())
        if not isinstance(rect, tuple) or len(rect) != 4:
            return None
        return rect
    frames, _labels = mod.walk_sprite(chars, cid)
    acc = None
    depths = {}
    for evs in frames:
        for ev in evs:
            if ev[0] == "remove":
                depths.pop(ev[1], None)
                continue
            if ev[0] != "place":
                continue
            depth, pcid, matrix, name = ev[1], ev[2], ev[3], ev[6]
            if pcid:
                prev = depths.get(depth)
                depths[depth] = [
                    pcid,
                    matrix if matrix else (prev[1] if prev else None),
                    name if name else (prev[2] if prev else ""),
                ]
            elif depth in depths:
                if matrix:
                    depths[depth][1] = matrix
                if name:
                    depths[depth][2] = name
        for _depth, (pcid, matrix, name) in depths.items():
            if name == "emit" or not matrix:
                continue
            sub = shape_rect(mod, chars, pcid, stack)
            if not sub:
                continue
            a, b, c, d, tx, ty = matrix
            pts = []
            for x in (sub[0], sub[1]):
                for y in (sub[2], sub[3]):
                    pts.append((a * x + c * y + tx, b * x + d * y + ty))
            box = (
                min(p[0] for p in pts),
                max(p[0] for p in pts),
                min(p[1] for p in pts),
                max(p[1] for p in pts),
            )
            if acc is None:
                acc = box
            else:
                acc = (
                    min(acc[0], box[0]),
                    max(acc[1], box[1]),
                    min(acc[2], box[2]),
                    max(acc[3], box[3]),
                )
    return acc


def emit_of(mod, chars, sid):
    frames, _labels = mod.walk_sprite(chars, sid)
    depths = {}
    found = None
    for evs in frames:
        for ev in evs:
            if ev[0] == "remove":
                depths.pop(ev[1], None)
                continue
            if ev[0] != "place":
                continue
            depth, matrix, name = ev[1], ev[3], ev[6]
            if name:
                prev = depths.get(depth)
                depths[depth] = [matrix if matrix else (prev[0] if prev else None), name]
            elif depth in depths and matrix:
                depths[depth][0] = matrix
        for matrix, name in depths.values():
            if name == "emit" and matrix:
                found = (matrix[4] / 20.0, matrix[5] / 20.0)
    return found


def png_size(path):
    data = path.read_bytes()
    return struct.unpack(">II", data[16:24])


def main():
    mod = load_mod()
    _data, _tags, chars, extras = mod.load()
    symbols = load_symbols()
    overrides = load_overrides()
    catalog = json.loads(WEAPONS_JSON.read_text(encoding="utf-8"))
    wanted = {}
    for row in catalog["weapons"]:
        kind = row.get("kind", "")
        if kind in SKIP_KIND or row.get("spell"):
            continue
        wid = row["id"]
        name = resolve(wid, overrides, symbols)
        if name:
            wanted[wid] = name
    by_symbol = {}
    for wid, name in wanted.items():
        by_symbol.setdefault(name, symbols[name])
    print("weapons", len(wanted), "clips", len(by_symbol), flush=True)
    ids = set()
    for sid in by_symbol.values():
        dep, _bitmaps = mod.deps_of(chars, sid)
        ids |= set(dep)
    print("chars", len(ids), flush=True)
    WORK.mkdir(parents=True, exist_ok=True)
    swf_path = WORK / "weapons.swf"
    mod.write_swf(chars, extras, ids, swf_path)
    print("swf", swf_path.stat().st_size, flush=True)
    select = ",".join("%d:1" % sid for sid in by_symbol.values())
    dest = WORK / "png"
    if dest.exists():
        for child in dest.rglob("*"):
            if child.is_file():
                child.unlink()
    dest.mkdir(parents=True, exist_ok=True)
    subprocess.check_call(
        [
            str(FFDEC),
            "-ignorebackground",
            "-format",
            "sprite:png",
            "-select",
            select,
            "-export",
            "sprite",
            str(dest),
            str(swf_path),
        ]
    )
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.png"):
        old.unlink()
    manifest = {}
    missing = []
    for name, sid in by_symbol.items():
        folder = dest / ("DefineSprite_%d_%s" % (sid, name))
        if not folder.exists():
            matches = list(dest.glob("DefineSprite_%d*" % sid))
            folder = matches[0] if matches else folder
        png = folder / "1.png"
        if not png.exists():
            missing.append(name)
            continue
        target = OUT / ("%s.png" % name)
        target.write_bytes(png.read_bytes())
        rect = shape_rect(mod, chars, sid)
        if rect:
            anchor = [round(-rect[0] / 20.0, 2), round(-rect[2] / 20.0, 2)]
        else:
            anchor = [0, 0]
        emit = emit_of(mod, chars, sid)
        entry = {"anchor": anchor, "file": "%s.png" % name}
        if emit:
            entry["emit"] = [round(emit[0], 2), round(emit[1], 2)]
        manifest[name] = entry
        width, height = png_size(target)
        entry["png"] = [width, height]
    for wid, name in wanted.items():
        if name not in manifest:
            continue
        manifest.setdefault("ids", {})[wid] = name
    # ids stored separately so clip records stay the art.
    id_map = manifest.pop("ids", {})
    payload = {"clips": manifest, "ids": id_map}
    (OUT / "manifest.json").write_text(json.dumps(payload), encoding="utf-8")
    print("wrote", len(manifest), "missing", missing, flush=True)


if __name__ == "__main__":
    main()

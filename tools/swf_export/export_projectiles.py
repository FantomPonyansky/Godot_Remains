"""Export projectile symbols used by weapons.json into a trimmed SWF.

Does not run FFDec -export sprite on pfe.swf. Known visbul / visualBullet /
thrown-weapon ids are copied out, then FFDec renders that small file.
"""
import json
import marshal
import shutil
import struct
import subprocess
import types
from pathlib import Path

PYC = (Path(__file__).resolve().parents[2] / r"tools\__pycache__\_export_polz.cpython-39.pyc")
FFDEC = (Path(__file__).resolve().parents[2] / r"tools\ffdec\ffdec-cli.exe")
SYMBOLS = (Path(__file__).resolve().parents[2] / r"original\tile_extract\sym_pfe\symbols.csv")
WEAPONS = (Path(__file__).resolve().parents[2] / r"original\reference\Remains-Source2\Modules\core\AllData\weapons.json")
SOUND_ROOT = (Path(__file__).resolve().parents[2] / r"original\reference\Remains-Source2\Modules\core\sound")
WORK = (Path(__file__).resolve().parents[2] / r"original\extracted_swf\projectile_vis")
OUT = (Path(__file__).resolve().parents[2] / r"godot\assets\sprites\projectiles")
SFX = (Path(__file__).resolve().parents[2] / r"godot\assets\sfx")
MANIFEST = OUT / "manifest.json"


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


def box_of(raw):
    if isinstance(raw, (list, tuple)) and len(raw) == 4 and all(isinstance(v, (int, float)) for v in raw):
        return tuple(float(v) for v in raw)
    return None


def transform_box(sub, matrix):
    a, b, c, d, tx, ty = matrix
    pts = []
    for x in (sub[0], sub[1]):
        for y in (sub[2], sub[3]):
            pts.append((a * x + c * y + tx, b * x + d * y + ty))
    return (
        min(p[0] for p in pts),
        max(p[0] for p in pts),
        min(p[1] for p in pts),
        max(p[1] for p in pts),
    )


def union(acc, box):
    if box is None:
        return acc
    if acc is None:
        return box
    return (
        min(acc[0], box[0]),
        max(acc[1], box[1]),
        min(acc[2], box[2]),
        max(acc[3], box[3]),
    )


def local_bounds(mod, chars, cid, stack=None):
    stack = set() if stack is None else stack
    if cid in stack or cid not in chars:
        return None
    direct = box_of(mod.char_bounds(chars, cid, "local", set()))
    if direct is not None:
        return direct
    stack = set(stack)
    stack.add(cid)
    tag = chars[cid][0]
    if tag != 39:
        return None
    frames, _labels = mod.walk_sprite(chars, cid)
    depths = {}
    acc = None
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
        for pcid, matrix, _name in depths.values():
            sub = local_bounds(mod, chars, pcid, stack)
            if not sub:
                continue
            if not matrix:
                matrix = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
            acc = union(acc, transform_box(sub, matrix))
    return acc


def frame_info(mod, chars, sid):
    frames, _labels = mod.walk_sprite(chars, sid)
    depths = {}
    boxes = []
    beam = False
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
        acc = None
        for pcid, matrix, name in depths.values():
            if name == "laser":
                beam = True
            sub = local_bounds(mod, chars, pcid)
            if not sub:
                continue
            if not matrix:
                matrix = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
            acc = union(acc, transform_box(sub, matrix))
        boxes.append(acc)
    return boxes, beam


def weapon_symbol(wid, data, symbols):
    tip = data.get("tip") or ""
    if tip == "melee":
        return ""
    if tip == "explosives":
        override = data.get("vis_vweap") or ""
        if override and override in symbols:
            return override
        if "^" in wid:
            base, suffix = wid.split("^", 1)
            variant = "vis%s_%s" % (base, suffix)
            if variant in symbols:
                return variant
            if ("vis" + base) in symbols:
                return "vis" + base
        plain = "vis" + wid
        if plain in symbols:
            return plain
        return "visualBullet" if "visualBullet" in symbols else ""
    vbul = data.get("vis_vbul") or ""
    if vbul:
        name = "visbul" + vbul
        if name in symbols:
            return name
    return "visualBullet" if "visualBullet" in symbols else ""


def find_sound(name):
    if not name:
        return None
    for folder in ("weapons", "misc", "unit"):
        path = SOUND_ROOT / folder / ("%s.mp3" % name)
        if path.exists():
            return path
    return None


def main():
    mod = load_mod()
    _data, _tags, chars, extras = mod.load()
    symbols = load_symbols()
    raw = json.loads(WEAPONS.read_text(encoding="utf-8"))
    weapons = {}
    wanted = {}
    sounds = set()
    for wid, data in raw.items():
        snd = data.get("snd_shoot") or ""
        if snd:
            sounds.add(snd)
        symbol = weapon_symbol(wid, data, symbols)
        if not symbol:
            continue
        tip = data.get("tip") or ""
        spring = int(data["vis_spring"]) if "vis_spring" in data else 1
        anim = bool(data.get("vis_bulanim")) or tip == "explosives"
        blend = "mix" if tip == "explosives" or data.get("vis_phisbul") else "add"
        weapons[wid] = {
            "symbol": symbol,
            "spring": spring,
            "anim": anim,
            "blend": blend,
            "sound": snd,
            "volume": 1.0,
        }
        wanted[symbol] = symbols[symbol]
    print("firing weapons", len(weapons), "arts", len(wanted), flush=True)
    ids = set()
    for sid in wanted.values():
        dep, _bitmaps = mod.deps_of(chars, sid)
        ids |= set(dep)
        ids.add(sid)
    print("chars", len(ids), flush=True)
    WORK.mkdir(parents=True, exist_ok=True)
    swf_path = WORK / "projectiles.swf"
    mod.write_swf(chars, extras, ids, swf_path)
    print("swf", swf_path.stat().st_size, flush=True)
    select = ",".join(str(sid) for sid in wanted.values())
    dest = WORK / "png"
    if dest.exists():
        shutil.rmtree(dest)
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
    if OUT.exists():
        for old in OUT.glob("*.png"):
            old.unlink()
    OUT.mkdir(parents=True, exist_ok=True)
    symbol_meta = {}
    missing = []
    for name, sid in sorted(wanted.items()):
        folder = dest / ("DefineSprite_%d_%s" % (sid, name))
        if not folder.exists():
            matches = list(dest.glob("DefineSprite_%d*" % sid))
            folder = matches[0] if matches else folder
        boxes, beam = frame_info(mod, chars, sid)
        frames = []
        for index, box in enumerate(boxes):
            src = folder / ("%d.png" % (index + 1))
            if box is None or not src.exists():
                continue
            file_name = "%s_%d.png" % (name, index + 1)
            (OUT / file_name).write_bytes(src.read_bytes())
            frames.append({
                "file": file_name,
                "anchor": [round(-box[0] / 20.0, 2), round(-box[2] / 20.0, 2)],
            })
        if not frames:
            missing.append(name)
            continue
        symbol_meta[name] = {"beam": beam, "frames": frames}
    copied = []
    missing_snd = []
    SFX.mkdir(parents=True, exist_ok=True)
    for name in sorted(sounds):
        src = find_sound(name)
        if src is None:
            missing_snd.append(name)
            continue
        shutil.copy2(src, SFX / src.name)
        copied.append(src.name)
    payload = {"symbols": symbol_meta, "weapons": weapons}
    MANIFEST.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    print("arts", len(symbol_meta), "missing", missing, flush=True)
    print("sounds", len(copied), "missing", missing_snd, flush=True)


if __name__ == "__main__":
    main()

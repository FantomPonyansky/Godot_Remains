"""Export one player body clip at a time from a trimmed SWF.

Does not open pfe.swf with FFDec. The parser pulls one sprite and its
dependencies, pip and wing depths are removed, nested clips stay on their
unlabeled first frame, then FFDec renders that one sprite.
"""

import json
import marshal
import re
import struct
import subprocess
import types
from pathlib import Path

PYC = (Path(__file__).resolve().parents[2] / r"tools\__pycache__\_export_polz.cpython-39.pyc")
FFDEC = (Path(__file__).resolve().parents[2] / r"tools\ffdec\ffdec-cli.exe")
WORK = (Path(__file__).resolve().parents[2] / r"original\extracted_swf\body_export")
OUT = (Path(__file__).resolve().parents[2] / r"godot\assets\sprites\pony")

CLIPS = {
    "stay": 3651,
    "trot": 3652,
    "trot_up": 3653,
    "trot_down": 3654,
    "run": 3655,
    "polz": 3656,
    "walk": 3657,
    "jump": 3658,
    "climb": 3660,
    "levit": 3674,
    "punch": 3664,
    "kick": 3665,
    "pinok": 3673,
    "free1": 3675,
    "free2": 3676,
    "free3": 3677,
    "roll": 3678,
}

DROP_NAMES = {"pip1", "pip2", "lwing", "rwing", "mane", "tail"}
# Forelock, eye, and horn glow live inside the shared muzzle sprite.
NESTED_DROP = {273: {"hair", "eye", "magic"}}


def load_mod():
    import swf_parse
    return swf_parse


def read_tag(buf, pos):
    code_len = struct.unpack_from("<H", buf, pos)[0]
    pos += 2
    tag = code_len >> 6
    length = code_len & 0x3F
    if length == 0x3F:
        length = struct.unpack_from("<I", buf, pos)[0]
        pos += 4
    return tag, pos, pos + length


def place_depth(tag, payload):
    if tag == 26 and len(payload) >= 3:
        return struct.unpack_from("<H", payload, 1)[0]
    if tag == 70 and len(payload) >= 4:
        return struct.unpack_from("<H", payload, 2)[0]
    if tag in (4, 5) and len(payload) >= 4:
        return struct.unpack_from("<H", payload, 2)[0]
    if tag == 28 and len(payload) >= 2:
        return struct.unpack_from("<H", payload, 0)[0]
    return None


def drop_depths(mod, chars, sid, names):
    frames, _labels = mod.walk_sprite(chars, sid)
    found = set()
    for evs in frames:
        for ev in evs:
            if ev[0] != "place":
                continue
            _kind, depth, _cid, _matrix, _flags, _flags2, name = ev
            if name in names:
                found.add(depth)
    return found


def strip_sprite(raw, root, drops):
    pos = 8
    nbits = raw[pos] >> 3
    pos += (5 + nbits * 4 + 7) // 8
    pos += 4
    out = bytearray(raw[:pos])
    while pos < len(raw) - 2:
        tag, start, end = read_tag(raw, pos)
        if tag == 0:
            out += raw[pos:end]
            break
        if tag != 39:
            out += raw[pos:end]
            pos = end
            continue
        sid, fc = struct.unpack_from("<HH", raw, start)
        payload = raw[start:end]
        inner = payload[4:]
        ip = 0
        kept = bytearray()
        shown = 0
        while ip < len(inner):
            itag, ts, te = read_tag(inner, ip)
            chunk = inner[ip:te]
            depth = place_depth(itag, inner[ts:te])
            skip = itag in (4, 5, 26, 28, 70) and depth in drops.get(sid, ())
            if not skip:
                if sid != root and fc > 1 and itag == 1:
                    shown += 1
                    if shown >= 1:
                        kept += chunk
                        if itag != 0:
                            kept += struct.pack("<H", 0)
                        break
                else:
                    kept += chunk
            if itag == 0:
                break
            ip = te
        if sid != root and fc > 1:
            new_payload = struct.pack("<HH", sid, 1) + kept
        else:
            new_payload = payload[:4] + kept
        code_len = (39 << 6) | 0x3F
        out += struct.pack("<HI", code_len, len(new_payload)) + new_payload
        pos = end
    struct.pack_into("<I", out, 4, len(out))
    return out


def export_sprite(swf, sid, dest):
    dest.mkdir(parents=True, exist_ok=True)
    subprocess.check_call(
        [
            str(FFDEC),
            "-ignorebackground",
            "-format",
            "sprite:png",
            "-selectid",
            str(sid),
            "-export",
            "sprite",
            str(dest),
            str(swf),
        ],
        stdout=subprocess.DEVNULL,
    )


def leg_tracks(mod, chars, sid):
    frames, labels = mod.walk_sprite(chars, sid)
    depths = {}
    names = {}
    mats = {}
    rows = []
    for evs in frames:
        for ev in evs:
            if ev[0] == "remove":
                depths.pop(ev[1], None)
                continue
            _kind, depth, cid, matrix, _flags, _flags2, name = ev
            if cid:
                depths[depth] = cid
            if name:
                names[depth] = name
            if matrix:
                mats[depth] = matrix
        row = {}
        for key, want in (("fr", "frleg3"), ("fl", "flleg3"), ("mane", "mane"), ("head", "head"), ("tail", "tail")):
            for depth, nm in names.items():
                if nm == want and depth in mats and depth in depths:
                    a, b, c, d, tx, ty = mats[depth]
                    row[key] = [a, b, c, d, tx / 20.0, ty / 20.0]
                    break
        rows.append(row)
    return {"labels": labels, "frames": rows}


def pngs_of(dest, sid):
    folder = dest / ("DefineSprite_%d" % sid)
    if not folder.exists():
        folders = [p for p in dest.iterdir() if p.is_dir()]
        folder = folders[0] if folders else folder
    files = sorted(folder.glob("*.png"), key=lambda p: int(p.stem) if p.stem.isdigit() else 0)
    return files


def svg_anchor(swf, sid):
    dest = WORK / ("svg_" + str(sid))
    if dest.exists():
        for child in dest.rglob("*"):
            if child.is_file():
                child.unlink()
    dest.mkdir(parents=True, exist_ok=True)
    subprocess.check_call(
        [
            str(FFDEC),
            "-format",
            "sprite:svg",
            "-select",
            "%d:1" % sid,
            "-selectid",
            str(sid),
            "-export",
            "sprite",
            str(dest),
            str(swf),
        ],
        stdout=subprocess.DEVNULL,
    )
    svg = next(dest.rglob("1.svg"))
    text = svg.read_text(encoding="utf-8", errors="replace")
    match = re.search(r'<g transform="matrix\(([^)]+)\)"', text)
    nums = [float(part) for part in match.group(1).split(",")]
    return [round(nums[4], 2), round(nums[5], 2)]


def copy_frames(files, clip):
    dest = OUT / "clips" / clip
    dest.mkdir(parents=True, exist_ok=True)
    for old in dest.glob("*.png"):
        old.unlink()
    for i, src in enumerate(files, 1):
        target = dest / ("%d.png" % i)
        target.write_bytes(src.read_bytes())
    return len(files)


def main():
    only = None
    import sys
    if len(sys.argv) > 1:
        only = sys.argv[1:]
    mod = load_mod()
    _data, _tags, chars, extras = mod.load()
    WORK.mkdir(parents=True, exist_ok=True)
    summary = {}
    for name, sid in CLIPS.items():
        if only and name not in only:
            continue
        print("export", name, sid, flush=True)
        ids, _extra = mod.deps_of(chars, sid)
        swf_path = WORK / ("%s.swf" % name)
        mod.write_swf(chars, extras, ids, swf_path)
        drops = {sid: drop_depths(mod, chars, sid, DROP_NAMES)}
        for nested, names in NESTED_DROP.items():
            if nested in ids:
                drops[nested] = drop_depths(mod, chars, nested, names)
        print("  drop", {k: sorted(v) for k, v in drops.items()}, flush=True)
        raw = strip_sprite(swf_path.read_bytes(), sid, drops)
        swf_path.write_bytes(raw)
        dest = WORK / name
        if dest.exists():
            for child in dest.rglob("*"):
                if child.is_file():
                    child.unlink()
        export_sprite(swf_path, sid, dest)
        files = pngs_of(dest, sid)
        count = copy_frames(files, name)
        tracks = leg_tracks(mod, chars, sid)
        clip_dir = OUT / "clips" / name
        clip_dir.joinpath("tracks.json").write_text(json.dumps(tracks), encoding="utf-8")
        anchor = svg_anchor(swf_path, sid)
        clip_dir.joinpath("anchor.json").write_text(json.dumps(anchor), encoding="utf-8")
        summary[name] = {"frames": count, "anchor": anchor}
        print("  frames", count, "anchor", anchor, flush=True)
    print("SUMMARY", summary)


if __name__ == "__main__":
    main()

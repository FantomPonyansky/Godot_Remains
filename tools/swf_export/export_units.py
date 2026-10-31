"""Export vclass unit visuals (visualTurret1, visualDron2, ...) into one
aligned sheet per unit under godot/assets/sprites/units.

Never opens pfe.swf with FFDec. The parser copies one visual and its
dependencies into a trimmed SWF. For each clip the trimmed file is rewritten:
the body clip (osn) keeps only the display list of one labeled frame, the
root gets as many frames as that state's animation, and named parts the
game drives separately (turret guns, sentinel arm) are removed. FFDec then
renders that one small sprite. Every clip of a unit is pasted into cells
that share the root origin, so the sheet anchor is the unit's feet/center.

Usage: python export_units.py [unit ...]
"""

import hashlib
import json
import math
import shutil
import struct
import subprocess
import sys
from pathlib import Path

import export_weapons as ew
import export_weapon_frames as ewf

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / "original" / "extracted_swf" / "unit_vis"
OUT = ROOT / "godot" / "assets" / "sprites" / "units"
MANIFEST = OUT / "manifest.json"
PAD = 2
MAX_W = 4096

# clip: (osn frame number or label, frame count override or None, loop)
# "root" clips render the visual's own timeline.
# parts: separately rendered sprites, path of instance names from the root,
#   with the frame of each parent on the way ({name: frame}).
UNITS = {
    "turret0": {"sym": "visualTurret0", "drop": ["puha"],
                "clips": {"stay": [1, 1, False], "hide": [2, 5, False], "hidden": [6, 1, False], "open": [7, 6, False]},
                "parts": {"puha": {"path": ["osn", "puha"], "frames": "each"}}},
    "turret1": {"sym": "visualTurret1", "drop": ["puha"], "clips": {"stay": [1, 1, False]},
                "parts": {"puha": {"path": ["osn", "puha"], "frames": "each"}}},
    "turret2": {"sym": "visualTurret2", "drop": ["puha"], "clips": {"stay": [1, 1, False]},
                "parts": {"puha": {"path": ["osn", "puha"], "frames": "each"}}},
    "turret3": {"sym": "visualTurret3", "drop": ["puha"], "clips": {"stay": [1, 1, False]},
                "parts": {"puha": {"path": ["osn", "puha"], "frames": "each"}}},
    "turret4": {"sym": "visualTurret4", "drop": ["puha"], "clips": {"stay": [1, 1, False]},
                "parts": {"puha": {"path": ["osn", "puha"], "frames": "each"}}},
    "turret5": {"sym": "visualTurret5", "drop": ["puha"], "clips": {"stay": [1, 1, False]},
                "parts": {"puha": {"path": ["osn", "puha"], "frames": "each"}}},
    "dron1": {"sym": "visualDron1", "clips": {"stay": [1, None, True]}},
    "dron2": {"sym": "visualDron2", "clips": {"stay": [1, None, True]}},
    "dron3": {"sym": "visualDron3", "clips": {"stay": [1, None, True]}},
    "bossdron": {"sym": "visualMegaDron", "clips": {"stay": [1, None, True]}},
    "bloodwing": {"sym": "visualBloodwing", "clips": {"stay": ["stay", None, True], "fly": ["fly", None, True], "attack": ["attack", None, False], "die": ["die", None, False]}},
    "bloodwing2": {"sym": "visualBloodwing2", "clips": {"stay": ["stay", None, True], "fly": ["fly", None, True], "attack": ["attack", None, False], "die": ["die", None, False]}},
    "fish1": {"sym": "visualFish1", "clips": {"stay": ["stay", None, True], "plav": ["plav", None, True], "run": ["run", None, True], "attack": ["attack", None, False], "die": ["die", None, False]}},
    "fish2": {"sym": "visualFish2", "clips": {"stay": ["stay", None, True], "plav": ["plav", None, True], "run": ["run", None, True], "attack": ["attack", None, False], "die": ["die", None, False]}},
    "fish3": {"sym": "visualFish3", "clips": {"stay": ["stay", None, True], "plav": ["plav", None, True], "run": ["run", None, True], "attack": ["attack", None, False], "die": ["die", None, False]}},
    "slime": {"sym": "visualSlime", "clips": {"stay": ["root", None, True]}},
    "pinkslime": {"sym": "visualPinkSlime", "clips": {"stay": ["root", None, True]}},
    "cryoslime": {"sym": "visualCryoSlime", "clips": {"stay": ["root", None, True]}},
    "roller": {"sym": "visualRoller", "clips": {"stay": [1, None, True], "walk": [2, None, True]}},
    "roller2": {"sym": "visualRoller2", "clips": {"stay": [1, None, True], "walk": [2, None, True]}},
    "msp": {"sym": "visualMsp", "clips": {"stay": ["stay", None, True], "wake": ["wake", None, False], "walk": ["walk", None, True], "jump": ["jump", None, False]}},
    "vortex": {"sym": "visualVortex", "clips": {"stay": [1, None, True], "attack": [2, None, True], "die": [3, None, False]}},
    "spritebot": {"sym": "visualSpriteBot", "clips": {"stay": [1, None, True], "zlo": [2, None, False]}},
    "sentinel": {"sym": "visualSentinel", "clips": {"stay": ["stay", None, True], "jump": ["jump", None, True], "die": ["die", None, False]}},
    "robobrain": {"sym": "visualRobobrain", "clips": {"stay": ["stay", None, True], "walk": ["walk", None, True], "die": ["die", None, False]}},
    "eant": {"sym": "visualAntEmitter", "clips": {"stay": ["root", None, True]}},
    "bossultra": {"sym": "visualUltraSentinel", "clips": {"stay": [1, None, True]}},
    "bossraider": {"sym": "visualRaiderBoss", "clips": {k: [k, None, k not in ("jump", "punch", "kick", "die")] for k in
                   ["stay", "trot", "run", "bac", "jump", "laz", "plav", "punch", "kick", "die", "derg"]}},
    "bossraider2": {"sym": "visualRaiderBoss2", "clips": {k: [k, None, k not in ("jump", "punch", "kick", "die")] for k in
                    ["stay", "trot", "run", "bac", "jump", "laz", "plav", "punch", "kick", "die", "derg"]}},
    "destr1": {"sym": "visualStolp", "clips": {"stay": [1, None, True], "die": [2, None, True]}},
    "shield": {"sym": "visShit", "clips": {"stay": ["root", None, True]}},
    "shield3": {"sym": "visShit3", "clips": {"stay": ["rootframe", 1, False], "break": ["root", None, False]}},
    "bossnecr": {"sym": "visualNecrBoss", "clips": {k: [k, None, k not in ("jump", "punch", "kick", "die", "cast")] for k in
                 ["stay", "trot", "run", "cast", "jump", "laz", "plav", "punch", "kick", "die", "derg", "walk"]}},
    **{m: {"sym": "vis" + m, "clips": {"stay": ["rootframe", 1, False], "armed": ["rootframe", 2, False],
                                        "f3": ["rootframe", 3, False], "f4": ["rootframe", 4, False], "f5": ["rootframe", 5, False]}}
       for m in ("mine", "hmine", "plamine", "impmine", "zebmine", "balemine")},
    "transmitter": {"sym": "visualTransmitter", "clips": {"stay": [1, None, True], "wall": [2, None, True]}},
    "scythe": {"sym": "visualScythe", "clips": {"stay": ["rootframe", 1, False]}},
    "ttur": {"sym": "visualTTurret", "drop": ["korp", "pole"], "clips": {"stay": [1, 1, False]},
             "parts": {"korp": {"path": ["osn", "korp"], "frames": "each"}, "pole": {"path": ["osn", "pole"], "frames": "each"}}},
    # parts.xml particle visuals the units emit (Emitter vis=...).
    **{"fx_" + k: {"sym": s, "clips": {"stay": ["root", None, False]}} for k, s in {
        "metal": "visualMetal", "pole": "visualPole", "black": "visualBlack", "miniexpl": "visualMiniexpl",
        "baleblast": "visualBaleblast", "bloodblast": "visualBloodblast", "bloodblast2": "visualBloodblast2",
        "necrblast": "visualNecrblast", "necrblast2": "visualNecrblast2", "necrblast3": "visualNecrblast3",
        "teleport": "visualTele", "quake": "visualQuake", "necronoise": "visualNecroNoise", "vsos": "visualVsos",
        "green_spark": "green_spark", "blue_spark": "blue_spark", "orange_spark": "orange_spark",
        "moln": "ThunderHeadMoln",
    }.items()},
}


def read_tag(buf, pos):
    code_len = struct.unpack_from("<H", buf, pos)[0]
    pos += 2
    tag = code_len >> 6
    length = code_len & 0x3F
    if length == 0x3F:
        length = struct.unpack_from("<I", buf, pos)[0]
        pos += 4
    return tag, pos, pos + length


def pack_tag(tag, body):
    return struct.pack("<HI", (tag << 6) | 0x3F, len(body)) + body


PLACE_TAGS = (4, 5, 26, 28, 70)


def place_info(tag, body):
    """depth, character id (or None), name (or None)."""
    if tag == 26 or tag == 70:
        flags = body[0]
        pos = 2 if tag == 70 else 1
        if tag == 70:
            flags2 = body[1]
        depth = struct.unpack_from("<H", body, pos)[0]
        pos += 2
        if tag == 70 and (flags2 & 0x08 or flags2 & 0x10):
            # class name present; we never see those in unit visuals
            pass
        cid = None
        if flags & 0x02:
            cid = struct.unpack_from("<H", body, pos)[0]
        return depth, cid
    if tag == 28 or tag == 5:
        return struct.unpack_from("<H", body, 0 if tag == 28 else 2)[0], None
    if tag == 4:
        cid, depth = struct.unpack_from("<HH", body, 0)
        return depth, cid
    return None, None


def inner_tags(body):
    out = []
    pos = 4
    while pos < len(body):
        tag, start, end = read_tag(body, pos)
        out.append((tag, body[start:end]))
        pos = end
        if tag == 0:
            break
    return out


def split_frames(tags):
    frames = [[]]
    for tag, body in tags:
        if tag == 1:
            frames.append([])
        elif tag == 0:
            break
        else:
            frames[-1].append((tag, body))
    if not frames[-1]:
        frames.pop()
    return frames


def state_at(tags, frame, drop_depths):
    """Display-list tags of frames 1..frame, as one frame."""
    frames = split_frames(tags)
    keep = []
    for evs in frames[:frame]:
        for tag, body in evs:
            if tag in PLACE_TAGS:
                depth, _cid = place_info(tag, body)
                if depth in drop_depths:
                    continue
                keep.append((tag, body))
    return keep


def build_sprite(sid, tags, nframes):
    body = struct.pack("<HH", sid, nframes)
    for tag, payload in tags:
        body += pack_tag(tag, payload)
    for _ in range(nframes):
        body += pack_tag(1, b"")
    body += struct.pack("<H", 0)
    return body


def rewrite_swf(raw, edits):
    pos = 8
    nbits = raw[pos] >> 3
    pos += (5 + nbits * 4 + 7) // 8
    pos += 4
    out = bytearray(raw[:pos])
    while pos < len(raw):
        tag, start, end = read_tag(raw, pos)
        if tag == 39:
            sid = struct.unpack_from("<H", raw, start)[0]
            if sid in edits:
                out += pack_tag(39, edits[sid])
                pos = end
                continue
        out += raw[pos:end]
        pos = end
        if tag == 0:
            break
    struct.pack_into("<I", out, 4, len(out))
    return bytes(out)


def sprite_body(raw, sid):
    pos = 8
    nbits = raw[pos] >> 3
    pos += (5 + nbits * 4 + 7) // 8
    pos += 4
    while pos < len(raw):
        tag, start, end = read_tag(raw, pos)
        if tag == 39 and struct.unpack_from("<H", raw, start)[0] == sid:
            return raw[start:end]
        if tag == 0:
            break
        pos = end
    raise KeyError(sid)


def named_depths(mod, chars, sid, names):
    frames, _labels = mod.walk_sprite(chars, sid)
    found = {}
    for evs in frames:
        for ev in evs:
            if ev[0] == "place" and ev[6] in names:
                found[ev[6]] = ev[1]
    return found


def child_at(mod, chars, sid, name, frame):
    """cid and matrix of instance `name` on `frame` of sprite sid."""
    frames, _labels = mod.walk_sprite(chars, sid)
    depths = {}
    for i, evs in enumerate(frames, 1):
        for ev in evs:
            if ev[0] == "remove":
                depths.pop(ev[1], None)
                continue
            if ev[0] != "place":
                continue
            _k, depth, cid, matrix, _f, _f2, nm = ev
            prev = depths.get(depth, [None, None, ""])
            depths[depth] = [cid or prev[0], matrix or prev[1], nm or prev[2]]
        if i == frame:
            break
    for cid, matrix, nm in depths.values():
        if nm == name:
            return cid, matrix or (1, 0, 0, 1, 0, 0)
    return None, None


def longest_child(mod, chars, sid, frame):
    """Longest nested animation on the display list of frame."""
    frames, _labels = mod.walk_sprite(chars, sid)
    depths = {}
    for i, evs in enumerate(frames, 1):
        for ev in evs:
            if ev[0] == "remove":
                depths.pop(ev[1], None)
            elif ev[0] == "place" and ev[2]:
                depths[ev[1]] = ev[2]
        if i == frame:
            break
    best = 1
    for cid in depths.values():
        if chars.get(cid, (0,))[0] == 39:
            n = len(mod.walk_sprite(chars, cid)[0])
            best = max(best, nested_len(mod, chars, cid, n))
    return best


def nested_len(mod, chars, sid, n):
    if n > 1:
        return n
    frames, _labels = mod.walk_sprite(chars, sid)
    best = 1
    for evs in frames:
        for ev in evs:
            if ev[0] == "place" and ev[2] and chars.get(ev[2], (0,))[0] == 39:
                best = max(best, nested_len(mod, chars, ev[2], len(mod.walk_sprite(chars, ev[2])[0])))
    return best


def mul(m1, m2):
    a1, b1, c1, d1, x1, y1 = m1
    a2, b2, c2, d2, x2, y2 = m2
    return (a1 * a2 + c1 * b2, b1 * a2 + d1 * b2, a1 * c2 + c1 * d2, b1 * c2 + d1 * d2,
            a1 * x2 + c1 * y2 + x1, b1 * x2 + d1 * y2 + y1)


def render(swf, sid, dest):
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    subprocess.check_call([str(ew.FFDEC), "-ignorebackground", "-format", "sprite:png", "-selectid", str(sid),
                           "-export", "sprite", str(dest), str(swf)], stdout=subprocess.DEVNULL)
    folders = [p for p in dest.iterdir() if p.is_dir() and p.name.split("_")[1] == str(sid)]
    files = sorted(folders[0].glob("*.png"), key=lambda p: int(p.stem))
    return files


MARKER_ID = 65000
MARKER_DEPTH = 16000


class Bits:
    def __init__(self):
        self.bits = []

    def ub(self, value, n):
        for i in range(n - 1, -1, -1):
            self.bits.append((value >> i) & 1)

    def sb(self, value, n):
        self.ub(value & ((1 << n) - 1), n)

    def data(self):
        out = bytearray()
        bits = self.bits + [0] * (-len(self.bits) % 8)
        for i in range(0, len(bits), 8):
            byte = 0
            for b in bits[i:i + 8]:
                byte = (byte << 1) | b
            out.append(byte)
        return bytes(out)


def sbits(*values):
    n = 1
    for v in values:
        while not (-(1 << (n - 1)) <= v < (1 << (n - 1))):
            n += 1
    return n


def rect_shape(cid, x0, y0, x1, y1, rgba):
    """DefineShape3: one solid rectangle, coordinates in pixels."""
    tx0, ty0, tx1, ty1 = int(x0 * 20), int(y0 * 20), int(x1 * 20), int(y1 * 20)
    rect = Bits()
    nb = sbits(tx0, tx1, ty0, ty1)
    rect.ub(nb, 5)
    for v in (tx0, tx1, ty0, ty1):
        rect.sb(v, nb)
    body = struct.pack("<H", cid) + rect.data()
    body += bytes([1, 0x00]) + bytes(rgba)
    body += bytes([0])
    s = Bits()
    s.ub(1, 4)
    s.ub(0, 4)
    s.ub(0, 1)
    s.ub(0, 1)
    s.ub(0, 1)
    s.ub(1, 1)
    s.ub(0, 1)
    s.ub(1, 1)
    mb = sbits(tx0, ty0)
    s.ub(mb, 5)
    s.sb(tx0, mb)
    s.sb(ty0, mb)
    s.ub(1, 1)
    w, h = tx1 - tx0, ty1 - ty0
    eb = sbits(w, -w, h, -h)
    for vert, delta in ((False, w), (True, h), (False, -w), (True, -h)):
        s.ub(1, 1)
        s.ub(1, 1)
        s.ub(eb - 2, 4)
        s.ub(0, 1)
        s.ub(1 if vert else 0, 1)
        s.sb(delta, eb)
    s.ub(0, 6)
    body += s.data()
    return pack_tag(32, body)


def marker_shape(half):
    """A transparent box that fixes the canvas, and an opaque magenta 3px
    square at its top-left corner whose pixel position gives the origin."""
    box = rect_shape(MARKER_ID, -half, -half, half, half, (0, 0, 0, 0))
    dot = rect_shape(MARKER_ID + 1, -half, -half, -half + 3, -half + 3, (255, 0, 255, 255))
    return box + dot

def marker_place():
    return [(26, struct.pack("<BHH", 0x02, MARKER_DEPTH, MARKER_ID)),
            (26, struct.pack("<BHH", 0x02, MARKER_DEPTH + 1, MARKER_ID + 1))]


def add_marker(raw, half):
    """Insert the marker shape before the first DefineSprite."""
    pos = 8
    nbits = raw[pos] >> 3
    pos += (5 + nbits * 4 + 7) // 8
    pos += 4
    while pos < len(raw):
        tag, _start, end = read_tag(raw, pos)
        if tag == 39:
            break
        pos = end
    out = raw[:pos] + marker_shape(half) + raw[pos:]
    out = bytearray(out)
    struct.pack_into("<I", out, 4, len(out))
    return bytes(out)


def with_marker(tags, frames_out=None):
    """Sprite tags with the marker placed on frame 1. frames_out pads the frame count."""
    frames = split_frames(tags)
    if not frames:
        frames = [[]]
    frames[0] = frames[0] + marker_place()
    if frames_out:
        while len(frames) < frames_out:
            frames.append([])
        frames = frames[:frames_out]
    return frames


def build_frames(sid, frames):
    body = struct.pack("<HH", sid, len(frames))
    for evs in frames:
        for tag, payload in evs:
            body += pack_tag(tag, payload)
        body += pack_tag(1, b"")
    body += struct.pack("<H", 0)
    return body


def unit_half(mod, chars, sid):
    rect = ew.shape_rect(mod, chars, sid)
    if not rect:
        return 200
    far = max(abs(v) for v in rect) / 20.0
    return int(math.ceil(far * 1.25 + 20))


def export_unit(mod, chars, extras, symbols, unit, spec):
    sid = symbols[spec["sym"]]
    work = WORK / unit
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    ids, _b = mod.deps_of(chars, sid)
    base_swf = work / "base.swf"
    mod.SWF_PATH = ROOT / "original" / "swf" / "pfe.swf"
    mod.write_swf(chars, extras, ids, base_swf)
    half = spec.get("half") or unit_half(mod, chars, sid)
    raw = add_marker(base_swf.read_bytes(), half)
    root_frames, _rl = mod.walk_sprite(chars, sid)
    osn_cid, _m = child_at(mod, chars, sid, "osn", 1)
    labels = mod.walk_sprite(chars, osn_cid)[1] if osn_cid else {}
    drop = spec.get("drop", [])
    root_tags = inner_tags(sprite_body(raw, sid))
    root_drop = set(named_depths(mod, chars, sid, drop).values())
    clips = {}
    for clip, (where, count, loop) in spec["clips"].items():
        edits = {}
        if where == "root":
            n = count or len(root_frames)
            edits[sid] = build_frames(sid, with_marker(root_tags, n))
        elif where == "rootframe":
            n = 1
            edits[sid] = build_frames(sid, [state_at(root_tags, count, set()) + marker_place()])
        else:
            frame = labels[where] if isinstance(where, str) else where
            osn_tags = inner_tags(sprite_body(raw, osn_cid))
            drop_d = set(named_depths(mod, chars, osn_cid, drop).values())
            edits[osn_cid] = build_sprite(osn_cid, state_at(osn_tags, frame, drop_d), 1)
            n = count or longest_child(mod, chars, osn_cid, frame)
            first = state_at(root_tags, 1, root_drop) + marker_place()
            edits[sid] = build_frames(sid, [first] + [[] for _ in range(n - 1)])
        swf = work / ("%s.swf" % clip)
        swf.write_bytes(rewrite_swf(raw, edits))
        files = render(swf, sid, work / clip)
        clips[clip] = {"files": [str(f) for f in files[:n]], "loop": loop}
        if where not in ("root", "rootframe"):
            # osn holds this frame (1-based); the clip's frames are its children playing.
            clips[clip]["osn"] = frame
    parts = {}
    for pname, pspec in spec.get("parts", {}).items():
        m = (1, 0, 0, 1, 0, 0)
        cur = sid
        for nm in pspec["path"]:
            cid, pm = child_at(mod, chars, cur, nm, 1)
            m = mul(m, pm)
            cur = cid
        ptags = inner_tags(sprite_body(raw, cur))
        swf = work / ("part_%s.swf" % pname)
        swf.write_bytes(rewrite_swf(raw, {cur: build_frames(cur, with_marker(ptags))}))
        files = render(swf, cur, work / ("part_" + pname))
        parts[pname] = {"files": [str(f) for f in files], "origin": [half, half],
                        "pivot": [round(m[4] / 20.0, 2), round(m[5] / 20.0, 2)],
                        "rot": [round(m[0], 4), round(m[1], 4), round(m[2], 4), round(m[3], 4)]}
    return {"origin": [half, half], "clips": clips, "parts": parts}


def main():
    only = sys.argv[1:]
    mod = ew.load_mod()
    _data, _tags, chars, extras = mod.load()
    symbols = ew.load_symbols()
    jobs_path = WORK / "jobs.json"
    jobs = json.loads(jobs_path.read_text(encoding="utf-8")) if jobs_path.exists() else {}
    for unit, spec in UNITS.items():
        if only and unit not in only:
            continue
        print("unit", unit, flush=True)
        jobs[unit] = export_unit(mod, chars, extras, symbols, unit, spec)
        jobs[unit]["sheet"] = unit
        print("  ", {k: len(v["files"]) for k, v in jobs[unit]["clips"].items()}, "half", jobs[unit]["origin"][0], flush=True)
        WORK.mkdir(parents=True, exist_ok=True)
        jobs_path.write_text(json.dumps(jobs, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()

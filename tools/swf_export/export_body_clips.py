"""Export player body clips (osn labels) with swf_trim, the way export_bodies.py did.

FFDec never opens pfe.swf: swf_trim copies the clip and its dependencies into a
small SWF. Pip, wing, mane and tail depths are removed, the forelock, eye and
horn glow are removed from the muzzle sprite, and every nested clip holds its
first frame. Writes clips/<name>/N.png, anchor.json and tracks.json.

Usage: python export_body_clips.py [name ...]   (--check compares stay tracks)
"""

import json
import re
import shutil
import subprocess
import sys

import swf_trim as st

WORK = st.ROOT / "original" / "extracted_swf" / "body_export"
OUT = st.ROOT / "godot" / "assets" / "sprites" / "pony" / "clips"

CLIPS = {
    "die": 3666,
    "dieali": 3667,
    "res": 3669,
    "lurk1": 3670,
    "lurk2": 3671,
    "lurk3": 3672,
}
DROP_NAMES = {"pip1", "pip2", "lwing", "rwing", "mane", "tail"}
NESTED_DROP = {273: {"hair", "eye", "magic"}}
TRACKS = (("fr", "frleg3"), ("fl", "flleg3"), ("mane", "mane"), ("head", "head"), ("tail", "tail"))


class Bits:
    def __init__(self, buf, pos):
        self.buf, self.bit = buf, pos * 8

    def ub(self, n):
        v = 0
        for _ in range(n):
            v = (v << 1) | ((self.buf[self.bit >> 3] >> (7 - (self.bit & 7))) & 1)
            self.bit += 1
        return v

    def sb(self, n):
        v = self.ub(n)
        return v - (1 << n) if n and v & (1 << (n - 1)) else v


def place_matrix(tag, body):
    """[a, b, c, d, tx, ty] of a PlaceObject2/3 (a, d scale; b, c skew; twips), or None."""
    if tag == 4:
        return None
    flags = body[0]
    flags2 = body[1] if tag == 70 else 0
    pos = (2 if tag == 70 else 1) + 2
    if tag == 70 and flags2 & 0x08:
        while body[pos] != 0:
            pos += 1
        pos += 1
    if flags & 0x02:
        pos += 2
    if not flags & 0x04:
        return None
    b = Bits(body, pos)
    sx = sy = 1.0
    r0 = r1 = 0.0
    if b.ub(1):
        n = b.ub(5)
        sx, sy = b.sb(n) / 65536.0, b.sb(n) / 65536.0
    if b.ub(1):
        n = b.ub(5)
        r0, r1 = b.sb(n) / 65536.0, b.sb(n) / 65536.0
    n = b.ub(5)
    tx, ty = b.sb(n), b.sb(n)
    return [sx, r0, r1, sy, tx, ty]


def tracks_of(swf, sid):
    frames, labels = swf.frames(sid)
    cids, names, mats, rows = {}, {}, {}, []
    for evs in frames:
        for t, b in evs:
            if t in (5, 28):
                cids.pop(st.place_depth(t, b), None)
                continue
            if t not in st.PLACE:
                continue
            d = st.place_depth(t, b)
            cid = st.place_cid(t, b)
            if cid:
                cids[d] = cid
            nm = st.place_name(t, b)
            if nm:
                names[d] = nm
            m = place_matrix(t, b)
            if m:
                mats[d] = m
        row = {}
        for key, want in TRACKS:
            for d, nm in names.items():
                if nm == want and d in mats and d in cids:
                    a, b2, c, dd, tx, ty = mats[d]
                    row[key] = [a, b2, c, dd, tx / 20.0, ty / 20.0]
                    break
        rows.append(row)
    return {"labels": labels, "frames": rows}


def no_depths(evs, drops):
    return [(t, b) for t, b in evs if t == 1 or not (t in st.PLACE + (5, 28) and st.place_depth(t, b) in drops)]


def edits_for(swf, sid, upper=False):
    root_frames, _ = swf.frames(sid)
    drops = set(st.depths_named(root_frames, DROP_NAMES).values())
    if upper:
        # Only what UnitPlayer draws over pip2 (the far-leg PipBuck when facing left).
        pip2 = st.depths_named(root_frames, {"pip2"}).get("pip2")
        if pip2 is None:
            return None
        for evs in root_frames:
            for t, b in evs:
                if t in st.PLACE + (5, 28) and st.place_depth(t, b) <= pip2:
                    drops.add(st.place_depth(t, b))
    edits = {sid: st.build_sprite(sid, [no_depths(evs, drops) for evs in root_frames])}
    keep_s, _ = swf.needed([sid])
    for s in keep_s:
        if s == sid:
            continue
        frames, _ = swf.frames(s)
        nested = set()
        if s in NESTED_DROP:
            nested = set(st.depths_named(frames, NESTED_DROP[s]).values())
        if len(frames) > 1 or nested:
            first = [(t, b) for t, b in frames[0] if t != 43] if frames else []
            edits[s] = st.build_sprite(s, [no_depths(first, nested)])
    return edits


def ffdec(args):
    subprocess.run([str(st.FFDEC)] + args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


HD_ZOOM = 3


def export_hd(swf, name, sid):
    """clips/<name>/hd/N.png: the same frames at HD_ZOOM, for the menu previews."""
    dest = WORK / (name + "_hd")
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    small = dest / "clip.swf"
    swf.trim([sid], small, edits_for(swf, sid))
    ffdec(["-zoom", str(HD_ZOOM), "-ignorebackground", "-format", "sprite:png", "-selectid", str(sid), "-export", "sprite", str(dest / "png"), str(small)])
    folder = next(p for p in (dest / "png").iterdir() if p.is_dir())
    files = sorted(folder.glob("*.png"), key=lambda p: int(p.stem))
    out = OUT / name / "hd"
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    for i, src in enumerate(files, 1):
        (out / ("%d.png" % i)).write_bytes(src.read_bytes())
    shutil.rmtree(dest)
    print(name, "hd", len(files), flush=True)


HD_PARTS = {"pip": 513}


def export_hd_part(swf, name, sid):
    """parts/<name>/hd/N.png at HD_ZOOM; the 1x anchors.json still applies (times HD_ZOOM)."""
    dest = WORK / (name + "_hdpart")
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    small = dest / "part.swf"
    swf.trim([sid], small)
    ffdec(["-zoom", str(HD_ZOOM), "-ignorebackground", "-format", "sprite:png", "-selectid", str(sid), "-export", "sprite", str(dest / "png"), str(small)])
    folder = next(p for p in (dest / "png").iterdir() if p.is_dir())
    files = sorted(folder.glob("*.png"), key=lambda p: int(p.stem))
    out = OUT.parent / "parts" / name / "hd"
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    for i, src in enumerate(files, 1):
        (out / ("%d.png" % i)).write_bytes(src.read_bytes())
    shutil.rmtree(dest)
    print("part", name, "hd", len(files), flush=True)


def export(swf, name, sid):
    dest = WORK / name
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    small = dest / "clip.swf"
    swf.trim([sid], small, edits_for(swf, sid))
    ffdec(["-ignorebackground", "-format", "sprite:png", "-selectid", str(sid), "-export", "sprite", str(dest / "png"), str(small)])
    ffdec(["-format", "sprite:svg", "-select", "%d:1" % sid, "-selectid", str(sid), "-export", "sprite", str(dest / "svg"), str(small)])
    folder = next(p for p in (dest / "png").iterdir() if p.is_dir())
    files = sorted(folder.glob("*.png"), key=lambda p: int(p.stem))
    text = next((dest / "svg").rglob("1.svg")).read_text(encoding="utf-8", errors="replace")
    nums = [float(x) for x in re.search(r'<g transform="matrix\(([^)]+)\)"', text).group(1).split(",")]
    anchor = [round(nums[4], 2), round(nums[5], 2)]
    clip_dir = OUT / name
    if clip_dir.exists():
        for old in clip_dir.glob("*.png"):
            old.unlink()
    clip_dir.mkdir(parents=True, exist_ok=True)
    for i, src in enumerate(files, 1):
        (clip_dir / ("%d.png" % i)).write_bytes(src.read_bytes())
    clip_dir.joinpath("tracks.json").write_text(json.dumps(tracks_of(swf, sid)), encoding="utf-8")
    clip_dir.joinpath("anchor.json").write_text(json.dumps(anchor), encoding="utf-8")
    shutil.rmtree(dest)
    print(name, sid, "frames", len(files), "anchor", anchor, flush=True)


ALL_CLIPS = {
    "stay": 3651, "trot": 3652, "trot_up": 3653, "trot_down": 3654, "run": 3655, "polz": 3656,
    "walk": 3657, "jump": 3658, "sitjump": 3659, "laz": 3660, "plav": 3661, "punch": 3664,
    "kick": 3665, "die": 3666, "dieali": 3667, "derg": 3668, "res": 3669, "lurk1": 3670,
    "lurk2": 3671, "lurk3": 3672, "pinok": 3673, "levit": 3674, "free1": 3675, "free2": 3676,
    "free3": 3677, "roll": 3678,
}


def export_upper(swf, name, sid):
    """clips/<name>/upper/N.png: the body layers above pip2, with their own anchor.json."""
    edits = edits_for(swf, sid, upper=True)
    if edits is None:
        print(name, "no pip2", flush=True)
        return
    dest = WORK / (name + "_upper")
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    small = dest / "clip.swf"
    swf.trim([sid], small, edits)
    ffdec(["-ignorebackground", "-format", "sprite:png", "-selectid", str(sid), "-export", "sprite", str(dest / "png"), str(small)])
    ffdec(["-format", "sprite:svg", "-select", "%d:1" % sid, "-selectid", str(sid), "-export", "sprite", str(dest / "svg"), str(small)])
    folder = next(p for p in (dest / "png").iterdir() if p.is_dir())
    files = sorted(folder.glob("*.png"), key=lambda p: int(p.stem))
    text = next((dest / "svg").rglob("1.svg")).read_text(encoding="utf-8", errors="replace")
    nums = [float(x) for x in re.search(r'<g transform="matrix\(([^)]+)\)"', text).group(1).split(",")]
    out = OUT / name / "upper"
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    for i, src in enumerate(files, 1):
        (out / ("%d.png" % i)).write_bytes(src.read_bytes())
    out.joinpath("anchor.json").write_text(json.dumps([round(nums[4], 2), round(nums[5], 2)]), encoding="utf-8")
    shutil.rmtree(dest)
    print(name, "upper", len(files), flush=True)


def check(swf):
    old = json.loads((OUT / "stay" / "tracks.json").read_text(encoding="utf-8"))
    new = tracks_of(swf, 3651)
    bad = 0
    for i, (a, b) in enumerate(zip(old["frames"], new["frames"])):
        for k in set(a) | set(b):
            va, vb = a.get(k), b.get(k)
            if va is None or vb is None or any(abs(x - y) > 1e-3 for x, y in zip(va, vb)):
                bad += 1
                if bad < 5:
                    print("diff frame", i + 1, k, va, vb)
    print("stay frames", len(old["frames"]), len(new["frames"]), "diffs", bad)


def main():
    swf = st.Swf()
    args = sys.argv[1:]
    if args == ["--check"]:
        check(swf)
        return
    if args and args[0] == "--hd":
        WORK.mkdir(parents=True, exist_ok=True)
        for name in args[1:] or ["stay", "free1", "free2", "free3", "pip"]:
            if name in HD_PARTS:
                export_hd_part(swf, name, HD_PARTS[name])
            else:
                export_hd(swf, name, ALL_CLIPS[name])
        return
    if args and args[0] == "--upper":
        WORK.mkdir(parents=True, exist_ok=True)
        for name, sid in ALL_CLIPS.items():
            if args[1:] and name not in args[1:]:
                continue
            export_upper(swf, name, sid)
        return
    WORK.mkdir(parents=True, exist_ok=True)
    for name, sid in CLIPS.items():
        if args and name not in args:
            continue
        export(swf, name, sid)


if __name__ == "__main__":
    main()

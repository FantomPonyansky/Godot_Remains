"""NPC visuals (UnitNPC / UnitCaptive / UnitPonPon / visNPCIco) and the
visualScene cutscenes (World.showScene) from pfe.swf.

Every render goes through swf_trim: FFDec only ever opens a small trimmed
SWF with one edited symbol. Raw frames land in story_art/<job>/<clip>/ and
jobs.json describes them; story_art/packer (a tiny Godot project) crops
and packs them into godot/assets/sprites/npcs and .../scenes.

Usage: python export_story_art.py [job ...]
"""

import json
import shutil
import subprocess
import sys
from pathlib import Path

import swf_trim as st

WORK = st.ROOT / "original" / "extracted_swf" / "story_art"
HALF = 260
MAX_NESTED = 120
STAGE = (1280, 800)

NPC_VIS = [
    "Calam", "CalamEncl", "Velvet", "Steel", "Mainframe", "Comm", "Askari", "SpriteBot",
    "Mentor", "Mentor2", "Sc1", "Sc2", "Sc3", "Sc4", "Vendor", "VendorBar", "VendorArmor",
    "VendorWeapon", "VendorExpl", "Doctor", "VendorMech", "VendorMage", "VendorCook",
    "VendorZebr", "VendorSR", "VendorMaps", "Autodoc", "Patient", "Zeb1", "Zeb2", "Zeb3",
    "Zeb4", "Train", "TrainArmor",
]


def nested_len(swf, cid, seen=None):
    seen = set() if seen is None else seen
    if cid not in swf.sprites or cid in seen:
        return 1
    seen = seen | {cid}
    frames, _l = swf.frames(cid)
    best = len(frames)
    if best > 1:
        return best
    for evs in frames:
        for t, b in evs:
            if t in st.PLACE:
                c = st.place_cid(t, b)
                if c is not None:
                    best = max(best, nested_len(swf, c, seen))
    return best


def longest_in(swf, tags):
    best = 1
    for t, b in tags:
        if t in st.PLACE:
            c = st.place_cid(t, b)
            if c is not None:
                best = max(best, nested_len(swf, c))
    return min(best, MAX_NESTED)


def strip_labels(evs):
    return [(t, b) for t, b in evs if t != 43]


def child_named(swf, sid, name):
    frames, _l = swf.frames(sid)
    for t, b in frames[0] if frames else []:
        if t in st.PLACE and st.place_name(t, b) == name:
            return st.place_cid(t, b), st.place_depth(t, b)
    return None, None


def render(swf, root, edits, dest, box, zoom=None):
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    small = swf.trim([root], dest / "clip.swf", edits, st.marker_defs(*box))
    args = [str(st.FFDEC), "-ignorebackground", "-format", "sprite:png"]
    if zoom:
        args += ["-zoom", str(zoom)]
    args += ["-selectid", str(root), "-export", "sprite", str(dest / "out"), str(small)]
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    folder = next(p for p in (dest / "out").iterdir() if p.is_dir())
    files = sorted(folder.glob("*.png"), key=lambda p: int(p.stem))
    (dest / "clip.swf").unlink()
    return [str(f) for f in files]


def root_with(swf, root, first, n):
    return st.build_sprite(root, [first + st.marker_place()] + [[] for _ in range(n - 1)])


def npc_job(swf, vis):
    root = swf.symbols["visual" + vis]
    rframes, _rl = swf.frames(root)
    first = st.state_at(rframes, 1)
    osn, _d = child_named(swf, root, "osn")
    box = (-HALF, -HALF, HALF, HALF)
    clips = {}
    work = WORK / vis.lower()
    if osn is not None and osn in swf.sprites:
        of, labels = swf.frames(osn)
        marks = sorted(set(labels.values()) | {len(of) + 1})
        stay = labels.get("stay", 1)
        state = st.state_at(of, stay)
        n = longest_in(swf, state)
        # A pony body (stay/sit/down/up labels) holds its stay frame.
        body, _bd = child_named(swf, osn, "body")
        if body in swf.sprites and "sit" in swf.frames(body)[1]:
            n = 1
        edits = {osn: st.build_sprite(osn, [state]), root: root_with(swf, root, first, n)}
        clips["stay"] = {"files": render(swf, root, edits, work / "stay", box), "loop": True}
        for name in ("move1", "move2", "fly"):
            if name not in labels:
                continue
            start = labels[name]
            end = next(m for m in marks if m > start) - 1
            if name == "fly" or end == start:
                state = st.state_at(of, start)
                n = longest_in(swf, state)
                edits = {osn: st.build_sprite(osn, [state]), root: root_with(swf, root, first, n)}
            else:
                body = [st.state_at(of, start)] + [strip_labels(e) for e in of[start:end]]
                edits = {osn: st.build_sprite(osn, body), root: root_with(swf, root, first, len(body))}
            clips[name] = {"files": render(swf, root, edits, work / name, box), "loop": name == "fly"}
        if not labels and len(of) >= 2:
            state = st.state_at(of, 2)
            edits = {osn: st.build_sprite(osn, [state]), root: root_with(swf, root, first, 1)}
            clips["eyes"] = {"files": render(swf, root, edits, work / "eyes", box), "loop": False}
    else:
        n = longest_in(swf, first)
        edits = {root: root_with(swf, root, first, n)}
        clips["stay"] = {"files": render(swf, root, edits, work / "stay", box), "loop": True}
    return {"kind": "sheet", "key": vis.lower(), "clips": clips}


def captive_jobs(swf):
    """UnitCaptive: osn.pon frame tr (1..27) and osn.cage frame sr+1 are set
    at runtime, so the pony is its own sheet and the body is one sheet per sr."""
    root = swf.symbols["visualCaptive"]
    rframes, _rl = swf.frames(root)
    first = st.state_at(rframes, 1)
    osn, _d = child_named(swf, root, "osn")
    of, labels = swf.frames(osn)
    depths = st.depths_named(of, {"pon", "cage"})
    cage, _cd = child_named(swf, osn, "cage")
    pon, _pd = child_named(swf, osn, "pon")
    moves = st.depth_moves(of, depths["pon"])
    if moves:
        print("  captive pon moves on frames", moves[:10])
    box = (-HALF, -HALF, HALF, HALF)
    cf, _cl = swf.frames(cage)
    jobs = []
    open_at, opened_at = labels["open"], labels["opened"]
    for sr in range(len(cf)):
        cage_edit = st.build_sprite(cage, [st.state_at(cf, sr + 1)])
        clips = {}
        work = WORK / ("captive_s%d" % sr)
        drop = {depths["pon"]}
        for name, start, end in (("closed", 1, 1), ("open", open_at, opened_at - 1), ("opened", opened_at, opened_at)):
            body = [st.state_at(of, start, drop)] + [[(t, b) for t, b in strip_labels(e) if not (t in st.PLACE + (5, 28) and st.place_depth(t, b) in drop)] for e in of[start:end]]
            edits = {cage: cage_edit, osn: st.build_sprite(osn, body), root: root_with(swf, root, first, len(body))}
            clips[name] = {"files": render(swf, root, edits, work / name, box), "loop": False}
        jobs.append({"kind": "sheet", "key": "captive_s%d" % sr, "clips": clips})
    pf, _pl = swf.frames(pon)
    still = st.build_sprite(pon, [st.state_at(pf, 1)])
    others = {st.place_depth(t, b) for e in of for t, b in e if t in st.PLACE + (5, 28)} - {depths["pon"]}
    path = {}
    for name, start, end in (("closed", 1, 1), ("open", open_at, opened_at - 1), ("opened", opened_at, opened_at)):
        body = [st.state_at(of, start, others)] + [[(t, b) for t, b in strip_labels(e) if not (t in st.PLACE + (5, 28) and st.place_depth(t, b) in others)] for e in of[start:end]]
        edits = {pon: still, osn: st.build_sprite(osn, body), root: root_with(swf, root, first, len(body))}
        path[name] = {"files": render(swf, root, edits, WORK / "captive_ponpath" / name, box), "loop": False}
    jobs.append({"kind": "path", "key": "captive_ponpath", "clips": path, "box": list(box)})
    keep = [(t, b) for t, b in of[0] if t in st.PLACE and st.place_depth(t, b) == depths["pon"]]
    edits = {osn: st.build_sprite(osn, [keep]), root: root_with(swf, root, first, len(pf))}
    files = render(swf, root, edits, WORK / "captive_pon" / "pon", box)
    jobs.append({"kind": "sheet", "key": "captive_pon", "clips": {"pon": {"files": files, "loop": False}}})
    proot = swf.symbols["visualPonPon"]
    pfirst = st.state_at(swf.frames(proot)[0], 1)
    files = render(swf, proot, {proot: root_with(swf, proot, pfirst, len(pf))}, WORK / "ponpon" / "pon", box)
    jobs.append({"kind": "sheet", "key": "ponpon", "clips": {"pon": {"files": files, "loop": False}}})
    return jobs


def ico_job(swf):
    root = swf.symbols["visNPCIco"]
    rf, _rl = swf.frames(root)
    body = [rf[0] + st.marker_place()] + [strip_labels(e) for e in rf[1:]]
    files = render(swf, root, {root: st.build_sprite(root, body)}, WORK / "npcico" / "ico", (-100, -100, 100, 100))
    return {"kind": "sheet", "key": "npcico", "clips": {"ico": {"files": files, "loop": False}}}


def scene_jobs(swf, only=()):
    root = swf.symbols["visualScene"]
    rf, labels = swf.frames(root)
    jobs = []
    for label, frame in sorted(labels.items(), key=lambda kv: kv[1]):
        if only and label not in only:
            continue
        state = st.display_at(rf, frame)
        sc = [st.place_cid(t, b) for t, b in state if t in st.PLACE and st.place_name(t, b) == "sc" and st.place_cid(t, b) is not None][-1]
        n = len(swf.frames(sc)[0])
        edits = {root: root_with(swf, root, state, n)}
        print("  scene", label, n, "frames", flush=True)
        done = sorted((WORK / "scene_" / label).glob("out/*/*.png"), key=lambda p: int(p.stem))
        if len(done) == n:
            files = [str(f) for f in done]
        else:
            files = render(swf, root, edits, WORK / "scene_" / label, (0, 0) + STAGE)
        jobs.append({"kind": "frames", "key": label, "files": files, "stage": list(STAGE)})
        yield jobs[-1]


def main():
    only = set(sys.argv[1:])
    swf = st.Swf()
    jobs_path = WORK / "jobs.json"
    WORK.mkdir(parents=True, exist_ok=True)
    jobs = json.loads(jobs_path.read_text(encoding="utf-8")) if jobs_path.exists() else {}

    def put(job):
        jobs[job["key"]] = job
        jobs_path.write_text(json.dumps(jobs, indent=1), encoding="utf-8")

    for vis in NPC_VIS:
        if only and vis.lower() not in only and "npcs" not in only:
            continue
        print("npc", vis, flush=True)
        put(npc_job(swf, vis))
    if not only or "captive" in only:
        print("captive", flush=True)
        for job in captive_jobs(swf):
            put(job)
    if not only or "npcico" in only:
        put(ico_job(swf))
    if not only or "scenes" in only or only & {"thunder1", "thunder2", "thunder3", "endgame", "gameover"}:
        for job in scene_jobs(swf, () if not only or "scenes" in only else only):
            put(job)


if __name__ == "__main__":
    main()

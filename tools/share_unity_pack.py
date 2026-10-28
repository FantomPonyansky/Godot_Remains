"""Build an asset pack for Remains: Unity (github Hemito/Remains-Unity) from this port.

Output: build/share_remains_unity/ (gitignored). Layout mirrors their Resources folder:
  Resources/Original/Units/<id>/<sheet>.png + artwork.json  (AtlasActorArtwork as a TextAsset)
  Resources/Original/Audio/Port/<name>.(mp3|wav) + Resources/Content/port-audio.json
  Resources/Original/Music/Port/<name>.mp3
  Resources/Content/item-text.<lang>.json                    (ItemTextCatalog schema)
  Text/text_<lang>.xml, Data/*.json, Weapons/, Docs/KNOWLEDGE_BASE.md, README.md
"""
import hashlib
import json
import os
import re
import stat
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "godot" / "assets"
OUT = ROOT / "build" / "share_remains_unity"
RES = OUT / "Resources"
FPS = 30.0
PPU = 50.0
POSE = {"stay": "idle", "trot": "walk", "die": "down", "laz": "climb"}
WPOS_FAMILY = {"raider": None, "slaver": None, "zebra": "zebra", "ranger": "ranger", "encl": "encl"}


def load(rel):
    return json.loads((ASSETS / rel).read_text(encoding="utf-8"))


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def pose_names(clips):
    names = {}
    pony = "trot" in clips
    for name in clips:
        out = POSE.get(name, name)
        if name == "walk" and pony:
            out = "walk_slow"
        names[name] = out
    return names


def wpos_rows(unit_id, spec, wpos, units_meta):
    fam = spec.get("family", "")
    if fam not in WPOS_FAMILY:
        return None
    key = WPOS_FAMILY[fam]
    if key is None:
        sex = units_meta.get(unit_id, {}).get("sex", "m")
        key = "raider_w" if sex == "w" else "raider_m"
    return wpos.get(key)


def actor_artwork(unit_id, spec, wpos, units_meta):
    cw, ch = spec["cell"]
    aw, ah = spec["atlas"]
    ox, oy = spec.get("offset", [0.0, 0.0])
    rows = ah // ch
    names = pose_names(spec.get("clips", {}))
    sockets = wpos_rows(unit_id, spec, wpos, units_meta)
    clips, skipped = [], []
    for name, c in spec.get("clips", {}).items():
        row = int(c.get("y", 0))
        if row >= rows:
            skipped.append(name)
            continue
        first = int(c.get("ff", 0))
        count = int(c.get("len", 1))
        clip = {
            "pose": names[name],
            "row": row,
            "count": count,
            "framesPerSecond": FPS,
            "loop": bool(c.get("rep", 0)),
            "loopStartFrame": int(c.get("rf", 0)),
            "verticalFrames": [],
            "weaponSockets": [],
            "original": {"name": name, "firstFrame": first, **{k: v for k, v in c.items() if k not in ("y", "len", "rep", "rf")}},
        }
        if sockets and row < len(sockets):
            pts = sockets[row][first:first + count]
            clip["weaponSockets"] = [{"x": float(p[0]), "y": float(p[1])} for p in pts]
            clip["original"]["weaponRotation"] = [p[2] for p in pts]
        clips.append(clip)
    art = {
        "resource": "Original/Units/%s/%s" % (unit_id, Path(spec["texture"]).stem),
        "width": aw,
        "height": ah,
        "cellWidth": cw,
        "cellHeight": ch,
        "pixelsPerUnit": PPU,
        "pivotX": round(0.5 - ox / cw, 6),
        "pivotY": round(1.0 - (ch / 2.0 - oy) / ch, 6),
        "facesLeft": unit_id == "necros",
        "clips": clips,
    }
    return art, skipped


def export_units():
    units = load("data/enemies.json")["units"]
    w = load("data/unit_wpos.json")
    report = []
    for uid, spec in sorted(units.items()):
        if not spec.get("clip_sheets") or not spec.get("texture"):
            continue
        src = ASSETS / "sprites" / "sheets" / spec["texture"]
        if not src.exists():
            report.append("%s: missing %s" % (uid, src.name))
            continue
        dest = RES / "Original" / "Units" / uid
        dest.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dest / src.name)
        art, skipped = actor_artwork(uid, spec, w["wpos"], w["units"])
        art["source"] = {"port_texture": spec["texture"], "sha256": sha(src), "extra_sheets": spec["clip_sheets"][1:]}
        (dest / "artwork.json").write_text(json.dumps(art, ensure_ascii=False, indent=1), encoding="utf-8")
        if skipped:
            report.append("%s: clips on other sheets skipped: %s" % (uid, ", ".join(skipped)))
    return report


def export_audio():
    entries = []
    for sub, kind in (("sfx", "sfx"), ("music", "music")):
        src_dir = ASSETS / sub
        dest = RES / "Original" / ("Audio" if kind == "sfx" else "Music") / "Port"
        dest.mkdir(parents=True, exist_ok=True)
        for p in sorted(src_dir.rglob("*")):
            if p.suffix.lower() not in (".mp3", ".wav"):
                continue
            rel = p.relative_to(src_dir)
            target = dest / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(p, target)
            entries.append({"id": rel.with_suffix("").as_posix(), "kind": kind,
                            "clip": "Original/%s/Port/%s" % ("Audio" if kind == "sfx" else "Music", rel.with_suffix("").as_posix())})
    content = RES / "Content"
    content.mkdir(parents=True, exist_ok=True)
    (content / "port-audio.json").write_text(json.dumps({"schema": 1, "entries": entries}, ensure_ascii=False, indent=1), encoding="utf-8")
    shutil.copyfile(ASSETS / "data" / "music.json", content / "port-music-map.json")
    return len(entries)


def export_text():
    text_dir = OUT / "Text"
    text_dir.mkdir(parents=True, exist_ok=True)
    langs = []
    for p in sorted((ROOT / "original" / "text").glob("text_*.xml")):
        port = ASSETS / "data" / p.name
        src = port if port.exists() else p
        shutil.copyfile(src, text_dir / p.name)
        lang = p.stem.split("_", 1)[1]
        items = []
        raw = src.read_text(encoding="utf-8-sig")
        try:
            root = ET.fromstring(raw)
        except ET.ParseError:
            try:
                root = ET.fromstring(re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", re.sub(r"&(?!#?\w+;)", "&amp;", raw)))
            except ET.ParseError as e:
                langs.append("%s (xml error %s, skipped)" % (lang, e))
                continue
        for el in root:
            if el.tag not in ("item", "weapon", "armor", "ammo", "spell", "perk", "skill"):
                continue
            name = el.findtext("n") or ""
            info = el.findtext("info") or ""
            if name:
                items.append({"id": "%s.%s" % (el.tag, el.get("id")), "name": name.strip(), "description": info.strip()})
        (RES / "Content" / ("item-text.%s.json" % lang)).write_text(
            json.dumps({"schema": 1, "items": items}, ensure_ascii=False, indent=1), encoding="utf-8")
        langs.append("%s (%d)" % (lang, len(items)))
    shutil.copyfile(ROOT / "original" / "text" / "lang.xml", text_dir / "lang.xml")
    return langs


def export_misc():
    data = OUT / "Data"
    data.mkdir(parents=True, exist_ok=True)
    for p in (ASSETS / "data").glob("*.json"):
        shutil.copyfile(p, data / p.name)
    weapons = OUT / "Weapons"
    if weapons.exists():
        shutil.rmtree(weapons)
    shutil.copytree(ASSETS / "sprites" / "weapons", weapons, ignore=shutil.ignore_patterns("*.import"))
    docs = OUT / "Docs"
    docs.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / "docs" / "KNOWLEDGE_BASE.md", docs / "KNOWLEDGE_BASE.md")
    shutil.copyfile(ROOT / "tools" / "share_unity_pack_README.md", OUT / "README.md")


def _force(func, path, _exc):
    os.chmod(path, stat.S_IWRITE)
    func(path)


def main():
    if OUT.exists():
        shutil.rmtree(OUT, onerror=_force)
    report = export_units()
    n_audio = export_audio()
    langs = export_text()
    export_misc()
    (OUT / "units_report.txt").write_text("\n".join(report) + "\n", encoding="utf-8")
    print("units:", len(list((RES / "Original" / "Units").iterdir())), "audio:", n_audio, "text:", ", ".join(langs))
    print("\n".join(report[:15]))


if __name__ == "__main__":
    main()

"""Copy OTHER's converted Flash rigs into godot/assets/rigs/.

Usage: python tools/import_rig.py bloat0 bloat1 ... [--other PATH]

Per unit it copies art/rigs/<u>/ (part PNGs + png_metadata.json), data/rigs/<u>/
(index, hierarchy, symbols) and scenes/rigs/<u>.tscn + <u>_anims.tres + <u>_anims/,
plus the colour-transform shaders and their includes once. res:// paths are
rewritten to our layout, the rig script becomes scripts/rig/rig_view.gd, and
OTHER's uids are stripped so Godot assigns ours. .import / .uid files are skipped.
"""
import argparse
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DST = ROOT / "godot" / "assets" / "rigs"
DEFAULT_OTHER = Path.home() / "Downloads" / "foe-remains-godot-master" / "foe-remains-godot-master" / "Godot_project"

REWRITES = [
    ("res://art/rigs/", "res://assets/rigs/art/"),
    ("res://data/rigs/", "res://assets/rigs/data/"),
    ("res://scenes/rigs/", "res://assets/rigs/scenes/"),
    ("res://shaders/", "res://assets/rigs/shaders/"),
    ("res://scripts/entity/rig_base.gd", "res://scripts/rig/rig_view.gd"),
]
# Units whose Flash visual places another unit's body at another scale
# (visualBloat7..9 place visualBloat10's osn at 0.6 / 0.9 / 1.3 instead of 1.75).
ALIASES = {
    "bloat7": ("bloat10", 0.6),
    "bloat8": ("bloat10", 0.9),
    "bloat9": ("bloat10", 1.3),
}
OSN_SCALE_RE = re.compile(r'(\[node name="osn"[^\]]*\]\n(?:position = [^\n]*\n)?)scale = Vector2\([^)]*\)\n')
UID_RE = re.compile(r' uid="uid://[a-z0-9]+"')
INCLUDE_RE = re.compile(r'#include "res://shaders/([^"]+)"')
SHADER_RE = re.compile(r'path="res://shaders/([^"]+)"')


FX_SCRIPT_RE = re.compile(r'\[ext_resource type="Script" path="res://scripts/entity/rig_art_fx\.gd" id="([^"]+)"\]\n')


def rewrite(text: str) -> str:
    text = UID_RE.sub("", text)
    # art_fx keeps its metadata (filters, mirrors) for RigView; OTHER's script is not ours.
    m = FX_SCRIPT_RE.search(text)
    if m:
        text = FX_SCRIPT_RE.sub("", text)
        text = text.replace(f'script = ExtResource("{m.group(1)}")\n', "")
    for a, b in REWRITES:
        text = text.replace(a, b)
    return text


def copy_text(src: Path, dst: Path) -> str:
    text = src.read_text(encoding="utf-8")
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(rewrite(text).replace("\r\n", "\n").encode("utf-8"))
    return text


def copy_tree(src: Path, dst: Path) -> int:
    n = 0
    for f in src.rglob("*"):
        if f.is_dir() or f.suffix in (".import", ".uid"):
            continue
        out = dst / f.relative_to(src)
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(f, out)
        n += 1
    return n


def copy_shader(other: Path, name: str, done: set) -> None:
    if name in done:
        return
    done.add(name)
    text = copy_text(other / "shaders" / name, DST / "shaders" / name)
    for inc in INCLUDE_RE.findall(text):
        copy_shader(other, inc, done)


def import_alias(unit: str) -> None:
    base, scale = ALIASES[unit]
    src = DST / "scenes" / f"{base}.tscn"
    text = src.read_text(encoding="utf-8")
    text, n = OSN_SCALE_RE.subn(lambda m: m.group(1) + f"scale = Vector2({scale}, {scale})\n", text)
    if n != 1:
        raise SystemExit(f"{unit}: no osn scale in {src}")
    name = base[0].upper() + base[1:]
    text = text.replace(f'[node name="{name}"', f'[node name="{unit[0].upper() + unit[1:]}"', 1)
    (DST / "scenes" / f"{unit}.tscn").write_bytes(text.encode("utf-8"))
    print(f"{unit}: {base} at scale {scale}")


def import_unit(other: Path, unit: str, shaders: set) -> None:
    if unit in ALIASES:
        if not (DST / "scenes" / f"{ALIASES[unit][0]}.tscn").exists():
            import_unit(other, ALIASES[unit][0], shaders)
        import_alias(unit)
        return
    art = copy_tree(other / "art" / "rigs" / unit, DST / "art" / unit)
    data = copy_tree(other / "data" / "rigs" / unit, DST / "data" / unit)
    scenes = other / "scenes" / "rigs"
    tscn = copy_text(scenes / f"{unit}.tscn", DST / "scenes" / f"{unit}.tscn")
    copy_text(scenes / f"{unit}_anims.tres", DST / "scenes" / f"{unit}_anims.tres")
    clips = 0
    for f in sorted((scenes / f"{unit}_anims").glob("*.tres")):
        copy_text(f, DST / "scenes" / f"{unit}_anims" / f.name)
        clips += 1
    for name in SHADER_RE.findall(tscn):
        copy_shader(other, name, shaders)
    print(f"{unit}: {art} art, {data} data, {clips} clips")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("units", nargs="+")
    ap.add_argument("--other", type=Path, default=DEFAULT_OTHER)
    args = ap.parse_args()
    shaders: set = set()
    for unit in args.units:
        import_unit(args.other, unit, shaders)


if __name__ == "__main__":
    main()

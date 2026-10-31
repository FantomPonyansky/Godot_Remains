"""Copy OTHER's player rig (LittlePip) and its runtime into the port.

Usage: python tools/import_player_rig.py [--other PATH]

Copies art/player/ and data/player_rig/ to godot/assets/rigs/player/{art,data}/,
scenes/player_rig.tscn + player_rig_anims(.tres, /) to godot/assets/rigs/player/,
the runtime (rig_base.gd, player_rig.gd, vis_base.gd, rig_art_fx.gd) to
godot/scripts/rig/other/, and the colour-transform shaders the scene names to
godot/assets/rigs/shaders/. res:// paths are rewritten, OTHER's uids stripped,
.import / .uid files skipped. OTHER classes the runtime names but the port lacks
(ColorTr, EntityEffects, FilterStack, FlashFilter, VisSnapshot) are stubs in
scripts/rig/other/stubs.gd, written by hand, not by this tool.
"""
import argparse
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = ROOT / "godot"
RIG = GODOT / "assets" / "rigs" / "player"
SCRIPTS = GODOT / "scripts" / "rig" / "other"
SHADERS = GODOT / "assets" / "rigs" / "shaders"
DEFAULT_OTHER = Path.home() / "Downloads" / "foe-remains-godot-master" / "foe-remains-godot-master" / "Godot_project"
RUNTIME = ["rig_base.gd", "player_rig.gd", "vis_base.gd", "rig_art_fx.gd"]

REWRITES = [
    ("res://art/player/", "res://assets/rigs/player/art/"),
    ("res://data/player_rig/", "res://assets/rigs/player/data/"),
    ("res://scenes/player_rig_anims", "res://assets/rigs/player/player_rig_anims"),
    ("res://scenes/player_rig.tscn", "res://assets/rigs/player/player_rig.tscn"),
    ("res://scripts/entity/rig_base.gd", "res://scripts/rig/other/rig_base.gd"),
    ("res://scripts/entity/player_rig.gd", "res://scripts/rig/other/player_rig.gd"),
    ("res://scripts/entity/vis_base.gd", "res://scripts/rig/other/vis_base.gd"),
    ("res://scripts/entity/rig_art_fx.gd", "res://scripts/rig/other/rig_art_fx.gd"),
    ("res://shaders/", "res://assets/rigs/shaders/"),
]
UID_RE = re.compile(r' uid="uid://[a-z0-9]+"')
INCLUDE_RE = re.compile(r'#include "res://shaders/([^"]+)"')
SHADER_RE = re.compile(r'res://shaders/([A-Za-z0-9_]+\.gdshader(?:inc)?)')


def rewrite(text: str) -> str:
    text = UID_RE.sub("", text)
    for a, b in REWRITES:
        text = text.replace(a, b)
    return text


def copy_text(src: Path, dst: Path) -> str:
    text = src.read_text(encoding="utf-8")
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(rewrite(text).replace("\r\n", "\n").encode("utf-8"))
    return text


def copy_tree(src: Path, dst: Path, text_suffixes=()) -> int:
    n = 0
    for f in src.rglob("*"):
        if f.is_dir() or f.suffix in (".import", ".uid"):
            continue
        out = dst / f.relative_to(src)
        if f.suffix in text_suffixes:
            copy_text(f, out)
        else:
            out.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(f, out)
        n += 1
    return n


def copy_shader(other: Path, name: str, done: set) -> None:
    if name in done:
        return
    done.add(name)
    text = copy_text(other / "shaders" / name, SHADERS / name)
    for inc in INCLUDE_RE.findall(text):
        copy_shader(other, inc, done)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--other", type=Path, default=DEFAULT_OTHER)
    args = ap.parse_args()
    o = args.other
    art = copy_tree(o / "art" / "player", RIG / "art")
    data = copy_tree(o / "data" / "player_rig", RIG / "data")
    texts = [copy_text(o / "scenes" / "player_rig.tscn", RIG / "player_rig.tscn"),
             copy_text(o / "scenes" / "player_rig_anims.tres", RIG / "player_rig_anims.tres")]
    clips = copy_tree(o / "scenes" / "player_rig_anims", RIG / "player_rig_anims", (".tres",))
    for name in RUNTIME:
        texts.append(copy_text(o / "scripts" / "entity" / name, SCRIPTS / name))
    shaders: set = set()
    for t in texts:
        for name in SHADER_RE.findall(t):
            copy_shader(o, name, shaders)
    print(f"player rig: {art} art, {data} data, {clips} clips, {len(shaders)} shaders")


if __name__ == "__main__":
    main()

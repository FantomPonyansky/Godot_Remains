"""Main-menu window art from visMainMenu (559) into godot/assets/ui/menu/art/<id>[_<frame>].png.

495 dialog fon, 498 slot row, 506 dialog button, 524 difficulty tile (2 frames), 546 checkbox (2 frames),
491 scroll bar, 474 menu-button glow, 399/401 language button and its hover, 486 link icons, 517 name box.
"""
import shutil
import subprocess
from pathlib import Path

import swf_trim as st

SHAPES = [495, 506, 474, 399, 401, 486, 517]
SPRITES = [498, 524, 546, 491]
WORK = Path(__file__).resolve().parents[2] / "tmp" / "_menu_art_tmp"
OUT = Path(__file__).resolve().parents[2] / "godot" / "assets" / "ui" / "menu" / "art"


def ffdec(args):
    subprocess.run([str(st.FFDEC)] + args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    swf = st.Swf()
    if WORK.exists():
        shutil.rmtree(WORK)
    WORK.mkdir(parents=True)
    small = WORK / "menu.swf"
    swf.trim(SPRITES + SHAPES, small)
    ids = ",".join(str(i) for i in SHAPES)
    ffdec(["-format", "shape:png", "-selectid", ids, "-export", "shape", str(WORK / "shape"), str(small)])
    ids = ",".join(str(i) for i in SPRITES)
    ffdec(["-ignorebackground", "-format", "sprite:png", "-selectid", ids, "-export", "sprite", str(WORK / "sprite"), str(small)])
    OUT.mkdir(parents=True, exist_ok=True)
    for png in (WORK / "shape").rglob("*.png"):
        (OUT / ("%s.png" % png.stem)).write_bytes(png.read_bytes())
    for folder in (WORK / "sprite").iterdir():
        sid = folder.name.split("_")[-1]
        files = sorted(folder.glob("*.png"), key=lambda p: int(p.stem))
        for i, png in enumerate(files, 1):
            name = sid if len(files) == 1 else "%s_%d" % (sid, i)
            (OUT / ("%s.png" % name)).write_bytes(png.read_bytes())
    shutil.rmtree(WORK)
    for p in sorted(OUT.glob("*.png")):
        print(p.name)


if __name__ == "__main__":
    main()

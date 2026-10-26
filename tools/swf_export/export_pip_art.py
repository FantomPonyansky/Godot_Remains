"""PipBuck chrome from visPipBuck (1155) and visPipInv (1113) into godot/assets/ui/pip/<id>[_<frame>].png.

1158 visPipHelp box, 1131 fon, 838 page frame, 1144 butHelp, 1150 toptext box, 1153 pr panel,
1139 / 1142 page button off / on (1143 frames 1-2),
506 (via 1004) / 1007-1010 subpage tab frames 1-5 (1011).
"""
import shutil
import subprocess
from pathlib import Path

import swf_trim as st

SHAPES = [1158, 1131, 838, 1144, 1150, 1153, 1139, 1142, 506, 1007, 1008, 1009, 1010]
SPRITES = []
WORK = Path(__file__).resolve().parents[2] / "tmp" / "_pip_art_tmp"
OUT = Path(__file__).resolve().parents[2] / "godot" / "assets" / "ui" / "pip"


def ffdec(args):
    subprocess.run([str(st.FFDEC)] + args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    swf = st.Swf()
    if WORK.exists():
        shutil.rmtree(WORK)
    WORK.mkdir(parents=True)
    small = WORK / "pip.swf"
    swf.trim(SPRITES + SHAPES, small)
    ids = ",".join(str(i) for i in SHAPES)
    ffdec(["-format", "shape:png", "-selectid", ids, "-export", "shape", str(WORK / "shape"), str(small)])
    OUT.mkdir(parents=True, exist_ok=True)
    for png in (WORK / "shape").rglob("*.png"):
        (OUT / ("%s.png" % png.stem)).write_bytes(png.read_bytes())
    shutil.rmtree(WORK)
    for p in sorted(OUT.glob("*.png")):
        print(p.name)


if __name__ == "__main__":
    main()

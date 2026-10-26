"""PipBuck/trol (item category icons, one labelled frame per tip) and
PipBuck/butCatFon (the filter button plate, frame 1 off / 2 on) for the
PipBuck filter buttons (PipPage.setCats) and inventory rows.

swf_trim writes a small SWF with only these symbols; FFDec renders that.
Never runs -export sprite on pfe.swf.
"""

import json
import shutil
import subprocess

import swf_trim as st

WORK = st.ROOT / "original" / "extracted_swf" / "trol"
DEST = st.ROOT / "godot" / "assets" / "ui" / "trol"
TROL_LABELS = {"w1", "armor1", "compa", "valuables"}


def _find(swf):
    trol = None
    for sid in swf.sprites:
        _frames, labels = swf.frames(sid)
        if TROL_LABELS <= set(labels):
            trol = sid
            break
    fon = None
    for sid in swf.sprites:
        names = {}
        for tag, body in swf.sprite_tags(sid):
            if tag in st.PLACE and st.place_name(tag, body):
                names[st.place_name(tag, body)] = st.place_cid(tag, body)
        if names.get("ico") == trol and "fon" in names:
            fon = names["fon"]
            break
    return trol, fon


def main():
    swf = st.Swf()
    trol, fon = _find(swf)
    print("trol", trol, "fon", fon)
    WORK.mkdir(parents=True, exist_ok=True)
    small = WORK / "trol.swf"
    swf.trim([trol, fon], small)
    png = WORK / "png"
    if png.exists():
        shutil.rmtree(png)
    png.mkdir(parents=True)
    subprocess.check_call([str(st.FFDEC), "-ignorebackground", "-format", "sprite:png", "-zoom", "2",
                           "-select", "%d,%d" % (trol, fon), "-export", "sprite", str(png), str(small)],
                          stdout=subprocess.DEVNULL)
    DEST.mkdir(parents=True, exist_ok=True)
    _frames, labels = swf.frames(trol)

    def frame_png(sid, n):
        folder = [p for p in png.glob("DefineSprite_%d*" % sid) if p.name.split("_")[1] == str(sid)][0]
        return folder / ("%d.png" % n)

    out = {}
    for label, n in sorted(labels.items(), key=lambda kv: kv[1]):
        src = frame_png(trol, n)
        if src.exists():
            shutil.copy(src, DEST / ("%s.png" % label))
            out[label] = n
    shutil.copy(frame_png(trol, 1), DEST / "_all.png")
    shutil.copy(frame_png(fon, 1), DEST / "_fon1.png")
    shutil.copy(frame_png(fon, 2), DEST / "_fon2.png")
    print(json.dumps(out))


if __name__ == "__main__":
    main()

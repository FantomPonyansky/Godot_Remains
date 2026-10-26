"""Print the display tree of unit vclass symbols: per frame, the placed
children with instance names and their own frame counts / labels."""
import sys
import export_weapons as ew

NAMES = sys.argv[1:]


def kind_of(mod, chars, cid):
    try:
        f2, l2 = mod.walk_sprite(chars, cid)
        return "spr%d%s" % (len(f2), (" " + str(l2)) if l2 else "")
    except Exception:
        return "shape"


def tree(mod, chars, sid, indent, depth_left):
    frames, labels = mod.walk_sprite(chars, sid)
    inv = {v: k for k, v in labels.items()}
    stage = {}
    last = None
    for i, evs in enumerate(frames, 1):
        for ev in evs:
            if ev[0] == "remove":
                stage.pop(ev[1], None)
                continue
            if ev[0] != "place":
                continue
            _k, depth, cid, _m, _f, _f2, name = ev
            prev = stage.get(depth, (None, ""))
            stage[depth] = (cid or prev[0], name or prev[1])
        sig = tuple(sorted(stage.items()))
        if sig == last:
            continue
        last = sig
        items = []
        for depth, (cid, name) in sorted(stage.items()):
            items.append("%s#%s(%s)" % (name or "_", cid, kind_of(mod, chars, cid)))
        print("%sf%d%s: %s" % (indent, i, (" [" + inv[i] + "]") if i in inv else "", "  ".join(items)))
    if depth_left <= 0:
        return
    seen = set()
    for evs in frames:
        for ev in evs:
            if ev[0] == "place" and ev[6] and ev[2] and ev[2] not in seen:
                seen.add(ev[2])
                k = kind_of(mod, chars, ev[2])
                if k != "shape" and not k.startswith("spr1 ") and k != "spr1":
                    print("%s  >> %s #%d" % (indent, ev[6], ev[2]))
                    tree(mod, chars, ev[2], indent + "    ", depth_left - 1)


def main():
    mod = ew.load_mod()
    _data, _tags, chars, _extras = mod.load()
    symbols = ew.load_symbols()
    for name in NAMES:
        sid = symbols.get(name) if not name.isdigit() else int(name)
        print("==", name, sid)
        tree(mod, chars, sid, "  ", 3)


if __name__ == "__main__":
    main()

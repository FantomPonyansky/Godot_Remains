"""Print the visMainMenu (559) layout: named children with pixel matrices, shape bounds, text fields.

python dump_menu_layout.py [sid] [depth]
"""
import struct
import sys

import swf_trim as st


def sbits(b, n):
    v = b.ub(n)
    return v - (1 << n) if n and v & (1 << (n - 1)) else v


def rect(buf, pos):
    b = st._Bits(buf, pos)
    n = b.ub(5)
    x0, x1, y0, y1 = (sbits(b, n) / 20 for _ in range(4))
    return (x0, y0, x1, y1), (b.bit + 7) // 8


def matrix(buf, pos):
    b = st._Bits(buf, pos)
    sx = sy = 1.0
    r0 = r1 = 0.0
    if b.ub(1):
        n = b.ub(5)
        sx, sy = sbits(b, n) / 65536, sbits(b, n) / 65536
    if b.ub(1):
        n = b.ub(5)
        r0, r1 = sbits(b, n) / 65536, sbits(b, n) / 65536
    n = b.ub(5)
    tx, ty = sbits(b, n) / 20, sbits(b, n) / 20
    return (sx, r0, r1, sy, tx, ty)


def place_matrix(tag, body):
    if tag == 4:
        return matrix(body, 4)
    flags = body[0]
    pos = (2 if tag == 70 else 1) + 2
    if tag == 70 and body[1] & 0x08:
        pos = body.index(0, pos) + 1
    if flags & 0x02:
        pos += 2
    if flags & 0x04:
        return matrix(body, pos)
    return None


def defs(swf):
    shapes, texts = {}, {}
    for tag, body in swf.top:
        cid = struct.unpack_from("<H", body, 0)[0] if len(body) >= 2 else None
        if tag in (2, 22, 32, 83):
            shapes[cid] = rect(body, 2)[0]
        elif tag == 37:
            r, pos = rect(body, 2)
            f1, f2 = body[pos], body[pos + 1]
            pos += 2
            info = {"rect": r}
            if f1 & 0x01:
                info["font"] = struct.unpack_from("<H", body, pos)[0]
                pos += 2
            if f2 & 0x80:
                pos = body.index(0, pos) + 1
            if f1 & 0x01 or f2 & 0x80:
                info["size"] = struct.unpack_from("<H", body, pos)[0] / 20
                pos += 2
            if f1 & 0x04:
                info["color"] = "%02x%02x%02x%02x" % tuple(body[pos:pos + 4])
                pos += 4
            if f1 & 0x02:
                pos += 2
            if f2 & 0x20:
                al, lm, rm, ind, lead = struct.unpack_from("<BHHHh", body, pos)
                info["align"] = al
                pos += 9
            end = body.index(0, pos)
            pos = end + 1
            if f1 & 0x80:
                info["text"] = body[pos:body.index(0, pos)].decode("utf-8", "replace")[:60]
            texts[cid] = info
    return shapes, texts


def mul(a, b):
    sx, r0, r1, sy, tx, ty = a
    bsx, br0, br1, bsy, btx, bty = b
    return (sx * bsx + r1 * br0, r0 * bsx + sy * br0, sx * br1 + r1 * bsy, r0 * br1 + sy * bsy,
            sx * btx + r1 * bty + tx, r0 * btx + sy * bty + ty)


def walk(swf, shapes, texts, sid, world, depth, indent, limit):
    frames, labels = swf.frames(sid)
    for t, b in frames[0]:
        if t not in st.PLACE:
            continue
        cid = st.place_cid(t, b)
        m = place_matrix(t, b) or (1, 0, 0, 1, 0, 0)
        w = mul(world, m)
        name = st.place_name(t, b) or ""
        kind = "spr" if cid in swf.sprites else "shp" if cid in shapes else "txt" if cid in texts else "?"
        extra = ""
        if cid in shapes:
            x0, y0, x1, y1 = shapes[cid]
            extra = "bounds %.1f,%.1f %.1fx%.1f" % (x0, y0, x1 - x0, y1 - y0)
        elif cid in texts:
            extra = str(texts[cid])
        elif cid in swf.sprites:
            extra = "frames %d" % len(swf.frames(cid)[0])
        print("%s%s %s %d at %.1f,%.1f scale %.2f,%.2f %s" % (
            "  " * indent, name or "-", kind, cid, w[4], w[5], w[0], w[3], extra))
        if cid in swf.sprites and indent < limit:
            walk(swf, shapes, texts, cid, w, depth, indent + 1, limit)


def main():
    sid = int(sys.argv[1]) if len(sys.argv) > 1 else 559
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 2
    swf = st.Swf()
    shapes, texts = defs(swf)
    walk(swf, shapes, texts, sid, (1, 0, 0, 1, 0, 0), 0, 0, limit)


if __name__ == "__main__":
    main()

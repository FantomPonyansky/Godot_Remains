"""pfe.swf dictionary access for the swf_export tools (`export_weapons.load_mod()`).

Rebuilt 2026-10-29 from how the tools call it; the lost original only survived as
tools/__pycache__/_export_polz.cpython-39.pyc. API:

    SWF_PATH                         swf read by load()
    load() -> (data, tags, chars, extras)
        chars {cid: (tag code, body, whole tag bytes)} for every defining tag
    walk_sprite(chars, sid) -> (frames, labels)
        frames [[event, ...] per frame]; labels {name: 1-based frame}
        ("place", depth, cid|None, matrix|None, flags, flags2, name|None)
        ("remove", depth)
        matrix (a, b, c, d, tx, ty): x' = a x + c y + tx, y' = b x + d y + ty, t in twips
    deps_of(chars, sid) -> (ids, bitmaps): sprites and buttons sid needs, and the
        characters they place (bitmaps is empty: write_swf keeps the whole dictionary)
    write_swf(chars, extras, ids, path): header, the dictionary (shapes, bitmaps, fonts,
        texts), the sprites and buttons in ids (bodies from chars, so patched ones go in),
        one empty root frame. FFDec renders a symbol from that file.
    char_bounds(chars, cid, space, seen) -> (xmin, xmax, ymin, ymax) twips of a shape,
        morph shape or text, else None
    read_tag_at(buf, pos) -> (code, start, end)
"""

import struct
from pathlib import Path

import swf_trim as st

SWF_PATH = st.PFE

# Tags whose body starts with the character id they define.
DEFINE = {2, 22, 32, 83, 6, 21, 35, 90, 20, 36, 39, 10, 48, 75, 91, 11, 33, 37, 7, 34,
          46, 84, 14, 60, 87}
SHAPES = {2, 22, 32, 83}
MORPHS = {46, 84}
TEXTS = {11, 33, 37}


def read_tag_at(buf, pos):
    return st.read_tag(buf, pos)


def load():
    swf = st.Swf(Path(SWF_PATH))
    chars = {}
    for code, body in swf.top:
        if code in DEFINE and len(body) >= 2:
            cid = struct.unpack_from("<H", body, 0)[0]
            chars[cid] = (code, body, st.pack_tag(code, body))
    extras = {"head": swf.head, "top": swf.top}
    return swf.raw, swf.top, chars, extras


class _Bits:
    def __init__(self, buf, pos):
        self.buf, self.bit = buf, pos * 8

    def ub(self, n):
        v = 0
        for _ in range(n):
            v = (v << 1) | ((self.buf[self.bit >> 3] >> (7 - (self.bit & 7))) & 1)
            self.bit += 1
        return v

    def sb(self, n):
        if n == 0:
            return 0
        v = self.ub(n)
        return v - (1 << n) if v & (1 << (n - 1)) else v

    def fixed(self, n):
        return self.sb(n) / 65536.0

    def end(self):
        return (self.bit + 7) // 8


def _matrix(buf, pos):
    b = _Bits(buf, pos)
    a = d = 1.0
    sk0 = sk1 = 0.0
    if b.ub(1):
        n = b.ub(5)
        a, d = b.fixed(n), b.fixed(n)
    if b.ub(1):
        n = b.ub(5)
        sk0, sk1 = b.fixed(n), b.fixed(n)
    n = b.ub(5)
    tx, ty = b.sb(n), b.sb(n)
    return (a, sk0, sk1, d, tx, ty), b.end()


def _rect(buf, pos):
    b = _Bits(buf, pos)
    n = b.ub(5)
    return (b.sb(n), b.sb(n), b.sb(n), b.sb(n)), b.end()


def _place(code, body):
    if code == 4:
        cid, depth = struct.unpack_from("<HH", body, 0)
        m, _end = _matrix(body, 4)
        return ("place", depth, cid, m, 0x02 | 0x04, 0, None)
    flags = body[0]
    flags2 = body[1] if code == 70 else 0
    pos = 2 if code == 70 else 1
    depth = struct.unpack_from("<H", body, pos)[0]
    pos += 2
    if code == 70 and flags2 & 0x08:
        pos = body.index(0, pos) + 1
    cid = None
    if flags & 0x02:
        cid = struct.unpack_from("<H", body, pos)[0]
        pos += 2
    matrix = None
    if flags & 0x04:
        matrix, pos = _matrix(body, pos)
    if flags & 0x08:
        pos += st._cxform_len(body, pos)
    if flags & 0x10:
        pos += 2
    name = None
    if flags & 0x20:
        end = body.index(0, pos)
        name = body[pos:end].decode("utf-8", "replace")
    return ("place", depth, cid, matrix, flags, flags2, name)


def walk_sprite(chars, sid):
    body = chars[sid][1]
    frames, labels = [[]], {}
    for code, b in st.tags_of(body, 4):
        if code == 1:
            frames.append([])
        elif code == 0:
            break
        elif code in (4, 26, 70):
            frames[-1].append(_place(code, b))
        elif code == 5:
            frames[-1].append(("remove", struct.unpack_from("<H", b, 2)[0]))
        elif code == 28:
            frames[-1].append(("remove", struct.unpack_from("<H", b, 0)[0]))
        elif code == 43:
            labels[b[:b.index(0)].decode("utf-8", "replace")] = len(frames)
    if not frames[-1]:
        frames.pop()
    return frames, labels


def _button_children(code, body):
    pos = 2 if code == 7 else 5
    out = []
    while pos < len(body) and body[pos] != 0:
        flags = body[pos]
        out.append(struct.unpack_from("<H", body, pos + 1)[0])
        pos += 5
        pos += st._matrix_len(body, pos)
        if code == 34:
            pos += st._cxform_len(body, pos)
            if flags & 0x10:
                raise ValueError("button filters")
            if flags & 0x20:
                pos += 1
    return out


def deps_of(chars, sid):
    ids, stack = set(), [sid]
    while stack:
        cid = stack.pop()
        if cid in ids or cid not in chars:
            continue
        ids.add(cid)
        code, body = chars[cid][0], chars[cid][1]
        if code == 39:
            for c, b in st.tags_of(body, 4):
                if c in (4, 26, 70):
                    child = _place(c, b)[2]
                    if child is not None:
                        stack.append(child)
        elif code in (7, 34):
            stack.extend(_button_children(code, body))
    return ids, []


def write_swf(chars, extras, ids, path):
    out = bytearray(extras["head"])
    for code, body in extras["top"]:
        if code in st.DROP_TOP:
            continue
        if code in (39, 7, 34):
            cid = struct.unpack_from("<H", body, 0)[0]
            if cid not in ids:
                continue
            body = chars.get(cid, (code, body))[1]
            if code == 39:
                nframes = struct.unpack_from("<H", body, 2)[0]
                inner = [(t, b) for t, b in st.tags_of(body, 4) if t not in st.SOUND_IN_SPRITE and t != 0]
                body = struct.pack("<HH", cid, nframes) + b"".join(st.pack_tag(t, b) for t, b in inner) \
                    + struct.pack("<H", 0)
        out += st.pack_tag(code, body)
    out += st.pack_tag(1, b"") + struct.pack("<H", 0)
    struct.pack_into("<I", out, 4, len(out))
    Path(path).write_bytes(bytes(out))
    return path


def char_bounds(chars, cid, space="local", seen=None):
    if cid not in chars:
        return None
    code, body = chars[cid][0], chars[cid][1]
    if code in SHAPES or code in MORPHS or code in TEXTS:
        return _rect(body, 2)[0]
    return None

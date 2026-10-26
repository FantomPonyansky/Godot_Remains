"""Standalone SWF trimmer for single-symbol exports from pfe.swf.

FFDec walks the whole pfe.swf timeline when it renders from it, so it is
never pointed at pfe.swf. trim() writes a small SWF with the dictionary
(shapes, bitmaps, fonts, texts), only the sprites one symbol needs, and an
empty root timeline; FFDec renders that symbol from the trimmed file.
"""

import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PFE = ROOT / "original" / "swf" / "pfe.swf"
FFDEC = ROOT / "tools" / "ffdec" / "ffdec-cli.exe"

PLACE = (4, 26, 70)
DROP_TOP = {1, 4, 5, 26, 28, 70, 12, 43, 56, 59, 72, 76, 82, 86, 15, 89, 18, 19, 45, 0}
SOUND_IN_SPRITE = {15, 89, 18, 19, 45, 12}


def read_tag(buf, pos):
    code_len = struct.unpack_from("<H", buf, pos)[0]
    pos += 2
    tag, length = code_len >> 6, code_len & 0x3F
    if length == 0x3F:
        length = struct.unpack_from("<I", buf, pos)[0]
        pos += 4
    return tag, pos, pos + length


def pack_tag(tag, body):
    return struct.pack("<HI", (tag << 6) | 0x3F, len(body)) + body


def header_end(raw):
    nbits = raw[8] >> 3
    return 8 + (5 + nbits * 4 + 7) // 8 + 4


def tags_of(raw, pos, end=None):
    end = len(raw) if end is None else end
    out = []
    while pos < end:
        tag, start, stop = read_tag(raw, pos)
        out.append((tag, raw[start:stop]))
        pos = stop
        if tag == 0:
            break
    return out


def place_cid(tag, body):
    if tag == 4:
        return struct.unpack_from("<H", body, 0)[0]
    flags = body[0]
    pos = 2 if tag == 70 else 1
    flags2 = body[1] if tag == 70 else 0
    pos += 2
    if tag == 70 and flags2 & 0x08:
        while body[pos] != 0:
            pos += 1
        pos += 1
    if flags & 0x02:
        return struct.unpack_from("<H", body, pos)[0]
    return None


def place_name(tag, body):
    """Instance name of a PlaceObject2/3, or None."""
    if tag == 4:
        return None
    flags = body[0]
    flags2 = body[1] if tag == 70 else 0
    pos = (2 if tag == 70 else 1) + 2
    if tag == 70 and flags2 & 0x08:
        while body[pos] != 0:
            pos += 1
        pos += 1
    if flags & 0x02:
        pos += 2
    if flags & 0x04:
        pos += _matrix_len(body, pos)
    if flags & 0x08:
        pos += _cxform_len(body, pos)
    if flags & 0x10:
        pos += 2
    if flags & 0x20:
        end = body.index(0, pos)
        return body[pos:end].decode("utf-8", "replace")
    return None


class _Bits:
    def __init__(self, buf, pos):
        self.buf, self.bit = buf, pos * 8

    def ub(self, n):
        v = 0
        for _ in range(n):
            v = (v << 1) | ((self.buf[self.bit >> 3] >> (7 - (self.bit & 7))) & 1)
            self.bit += 1
        return v


def _matrix_len(buf, pos):
    b = _Bits(buf, pos)
    if b.ub(1):
        n = b.ub(5)
        b.ub(n * 2)
    if b.ub(1):
        n = b.ub(5)
        b.ub(n * 2)
    n = b.ub(5)
    b.ub(n * 2)
    return (b.bit + 7) // 8 - pos


def _cxform_len(buf, pos):
    b = _Bits(buf, pos)
    add, mult = b.ub(1), b.ub(1)
    n = b.ub(4)
    b.ub(n * 4 * (add + mult))
    return (b.bit + 7) // 8 - pos


class Swf:
    def __init__(self, path=PFE):
        self.raw = path.read_bytes()
        assert self.raw[:3] == b"FWS", "compressed swf not supported"
        self.head = self.raw[:header_end(self.raw)]
        self.top = tags_of(self.raw, len(self.head))
        self.sprites = {}
        self.symbols = {}
        self.buttons = {}
        for tag, body in self.top:
            if tag == 39:
                self.sprites[struct.unpack_from("<H", body, 0)[0]] = body
            elif tag in (7, 34):
                self.buttons[struct.unpack_from("<H", body, 0)[0]] = (tag, body)
            elif tag == 76:
                n = struct.unpack_from("<H", body, 0)[0]
                pos = 2
                for _ in range(n):
                    cid = struct.unpack_from("<H", body, pos)[0]
                    end = body.index(0, pos + 2)
                    self.symbols[body[pos + 2:end].decode("utf-8", "replace")] = cid
                    pos = end + 1

    def sprite_tags(self, sid):
        return tags_of(self.sprites[sid], 4)

    def frames(self, sid):
        """[[tags of frame 1], ...] and {label: frame number}."""
        frames, labels = [[]], {}
        for tag, body in self.sprite_tags(sid):
            if tag == 1:
                frames.append([])
            elif tag == 0:
                break
            else:
                if tag == 43:
                    labels[body[:body.index(0)].decode("utf-8", "replace")] = len(frames)
                frames[-1].append((tag, body))
        if not frames[-1]:
            frames.pop()
        return frames, labels

    def children(self, sid):
        out = []
        for tag, body in self.sprite_tags(sid):
            if tag in PLACE:
                cid = place_cid(tag, body)
                if cid is not None:
                    out.append(cid)
        return out

    def button_children(self, bid):
        tag, body = self.buttons[bid]
        pos = 2 if tag == 7 else 5
        out = []
        while pos < len(body) and body[pos] != 0:
            flags = body[pos]
            out.append(struct.unpack_from("<H", body, pos + 1)[0])
            pos += 5
            pos += _matrix_len(body, pos)
            if tag == 34:
                pos += _cxform_len(body, pos)
                if flags & 0x10:
                    raise ValueError("button filters")
                if flags & 0x20:
                    pos += 1
        return out

    def needed(self, roots):
        keep_s, keep_b, stack = set(), set(), list(roots)
        while stack:
            cid = stack.pop()
            if cid in self.sprites and cid not in keep_s:
                keep_s.add(cid)
                stack.extend(self.children(cid))
            elif cid in self.buttons and cid not in keep_b:
                keep_b.add(cid)
                stack.extend(self.button_children(cid))
        return keep_s, keep_b

    def trim(self, roots, dest, edits=None, extra_defs=b""):
        """Trimmed swf with sprites for roots; edits {sid: new DefineSprite body}.
        extra_defs (whole tags) go before the first sprite."""
        edits = edits or {}
        keep_s, keep_b = self.needed(roots)
        for sid, body in edits.items():
            keep_s.add(sid)
            for tag, b in tags_of(body, 4):
                if tag in PLACE:
                    cid = place_cid(tag, b)
                    if cid is not None:
                        more_s, more_b = self.needed([cid])
                        keep_s |= more_s
                        keep_b |= more_b
        out = bytearray(self.head)
        for tag, body in self.top:
            if tag in DROP_TOP:
                continue
            if tag == 39:
                if extra_defs:
                    out += extra_defs
                    extra_defs = b""
                sid = struct.unpack_from("<H", body, 0)[0]
                if sid not in keep_s:
                    continue
                body = edits.get(sid, body)
                inner = [(t, b) for t, b in tags_of(body, 4) if t not in SOUND_IN_SPRITE]
                nframes = struct.unpack_from("<H", body, 2)[0]
                body = struct.pack("<HH", sid, nframes) + b"".join(pack_tag(t, b) for t, b in inner if t != 0) + struct.pack("<H", 0)
            elif tag in (7, 34) and struct.unpack_from("<H", body, 0)[0] not in keep_b:
                continue
            out += pack_tag(tag, body)
        out += pack_tag(1, b"") + struct.pack("<H", 0)
        struct.pack_into("<I", out, 4, len(out))
        Path(dest).write_bytes(bytes(out))
        return dest


class _BitWriter:
    def __init__(self):
        self.bits = []

    def ub(self, value, n):
        for i in range(n - 1, -1, -1):
            self.bits.append((value >> i) & 1)

    def sb(self, value, n):
        self.ub(value & ((1 << n) - 1), n)

    def data(self):
        bits = self.bits + [0] * (-len(self.bits) % 8)
        out = bytearray()
        for i in range(0, len(bits), 8):
            byte = 0
            for b in bits[i:i + 8]:
                byte = (byte << 1) | b
            out.append(byte)
        return bytes(out)


def _sbits(*values):
    n = 1
    for v in values:
        while not (-(1 << (n - 1)) <= v < (1 << (n - 1))):
            n += 1
    return n


def rect_shape(cid, x0, y0, x1, y1, rgba):
    """DefineShape3 tag: one solid rectangle, pixel coordinates."""
    tx0, ty0, tx1, ty1 = int(x0 * 20), int(y0 * 20), int(x1 * 20), int(y1 * 20)
    rect = _BitWriter()
    nb = _sbits(tx0, tx1, ty0, ty1)
    rect.ub(nb, 5)
    for v in (tx0, tx1, ty0, ty1):
        rect.sb(v, nb)
    body = struct.pack("<H", cid) + rect.data() + bytes([1, 0x00]) + bytes(rgba) + bytes([0])
    s = _BitWriter()
    s.ub(1, 4)
    s.ub(0, 4)
    for bit in (0, 0, 0, 1, 0, 1):
        s.ub(bit, 1)
    mb = _sbits(tx0, ty0)
    s.ub(mb, 5)
    s.sb(tx0, mb)
    s.sb(ty0, mb)
    s.ub(1, 1)
    w, h = tx1 - tx0, ty1 - ty0
    eb = _sbits(w, -w, h, -h)
    for vert, delta in ((False, w), (True, h), (False, -w), (True, -h)):
        s.ub(1, 1)
        s.ub(1, 1)
        s.ub(eb - 2, 4)
        s.ub(0, 1)
        s.ub(1 if vert else 0, 1)
        s.sb(delta, eb)
    s.ub(0, 6)
    return pack_tag(32, body + s.data())


MARKER_ID = 65000
MARKER_DEPTH = 16000


def marker_defs(x0, y0, x1, y1):
    """A transparent box fixing the canvas and an opaque magenta 3px dot at
    its top-left corner; the dot's pixel gives the canvas origin."""
    return (rect_shape(MARKER_ID, x0, y0, x1, y1, (0, 0, 0, 0))
            + rect_shape(MARKER_ID + 1, x0, y0, x0 + 3, y0 + 3, (255, 0, 255, 255)))


def marker_place():
    return [(26, struct.pack("<BHH", 0x02, MARKER_DEPTH, MARKER_ID)),
            (26, struct.pack("<BHH", 0x02, MARKER_DEPTH + 1, MARKER_ID + 1))]


def place_depth(tag, body):
    if tag == 4:
        return struct.unpack_from("<H", body, 2)[0]
    if tag == 5:
        return struct.unpack_from("<H", body, 2)[0]
    if tag == 28:
        return struct.unpack_from("<H", body, 0)[0]
    return struct.unpack_from("<H", body, 2 if tag == 70 else 1)[0]


def build_sprite(sid, frames):
    body = struct.pack("<HH", sid, len(frames))
    for evs in frames:
        for tag, payload in evs:
            body += pack_tag(tag, payload)
        body += pack_tag(1, b"")
    return body + struct.pack("<H", 0)


def state_at(frames, frame, drop_depths=()):
    """Display list after frames 1..frame, as tags for one frame (no labels)."""
    keep = []
    for evs in frames[:frame]:
        keep += [(t, b) for t, b in evs if t in PLACE + (5, 28) and place_depth(t, b) not in drop_depths]
    return keep


def display_at(frames, frame):
    """The live display list after frames 1..frame: per depth, the last place
    with a character and the moves after it; removed depths are gone."""
    live = {}
    for evs in frames[:frame]:
        for t, b in evs:
            if t in (5, 28):
                live.pop(place_depth(t, b), None)
            elif t in PLACE:
                d = place_depth(t, b)
                if place_cid(t, b) is not None:
                    live[d] = [(t, b)]
                elif d in live:
                    live[d].append((t, b))
    return [tb for d in sorted(live) for tb in live[d]]


def depths_named(frames, names):
    out = {}
    for evs in frames:
        for t, b in evs:
            if t in PLACE and place_name(t, b) in names:
                out[place_name(t, b)] = place_depth(t, b)
    return out


def depth_moves(frames, depth):
    """Frames after the first that place or move depth."""
    return [i for i, evs in enumerate(frames[1:], 2) for t, b in evs if t in PLACE and place_depth(t, b) == depth]

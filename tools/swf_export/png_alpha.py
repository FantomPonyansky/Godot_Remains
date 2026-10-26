"""Print a PNG's alpha as ASCII (no PIL). Usage: python png_alpha.py file.png [step]"""

import struct
import sys
import zlib


def read(path):
    raw = open(path, "rb").read()
    pos, data, w, h, ctype = 8, b"", 0, 0, 0
    while pos < len(raw):
        n = struct.unpack(">I", raw[pos:pos + 4])[0]
        kind = raw[pos + 4:pos + 8]
        body = raw[pos + 8:pos + 8 + n]
        if kind == b"IHDR":
            w, h, _depth, ctype = struct.unpack(">IIBB", body[:10])
        elif kind == b"IDAT":
            data += body
        pos += 12 + n
    bpp = {6: 4, 2: 3, 0: 1, 4: 2}[ctype]
    px = zlib.decompress(data)
    rows, prev, i = [], bytearray(w * bpp), 0
    for _ in range(h):
        f = px[i]
        line = bytearray(px[i + 1:i + 1 + w * bpp])
        i += 1 + w * bpp
        for x in range(len(line)):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + b) & 255
            elif f == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(line)
        prev = line
    return w, h, bpp, rows


if __name__ == "__main__":
    w, h, bpp, rows = read(sys.argv[1])
    step = int(sys.argv[2]) if len(sys.argv) > 2 else 2
    print(w, h)
    for y in range(0, h, step):
        print("".join(" .:#"[min(3, rows[y][x * bpp + bpp - 1] // 64)] if bpp == 4 else "?" for x in range(0, w, step)))

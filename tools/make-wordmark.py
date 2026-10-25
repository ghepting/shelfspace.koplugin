#!/usr/bin/env python3
"""Draws the ShelfSpace wordmark as one SVG path, from a TrueType font, with no dependencies.

KOReader's SVG renderer ignores <text>, so the name under the logo has to be outlines. This reads the
glyphs of KOReader's own Noto Sans Bold (SIL Open Font License) and prints the path data used by
shelfspace.koplugin/shelfspace/icons.lua, scaled to a given width on the 195-unit icon canvas.

usage: make-wordmark.py <NotoSans-Bold.ttf> [text] [width] [baseline y] [centre x]
"""
import struct
import sys

font_path = sys.argv[1]
text = sys.argv[2] if len(sys.argv) > 2 else "ShelfSpace"
target_w = float(sys.argv[3]) if len(sys.argv) > 3 else 104
baseline = float(sys.argv[4]) if len(sys.argv) > 4 else 162
centre_x = float(sys.argv[5]) if len(sys.argv) > 5 else 95.6

data = open(font_path, "rb").read()
u16 = lambda o: struct.unpack(">H", data[o:o + 2])[0]
i16 = lambda o: struct.unpack(">h", data[o:o + 2])[0]
u32 = lambda o: struct.unpack(">I", data[o:o + 4])[0]

tables = {}
for i in range(u16(4)):
    o = 12 + 16 * i
    tables[data[o:o + 4].decode()] = u32(o + 8)

upem = u16(tables["head"] + 18)
loca_long = i16(tables["head"] + 50)
n_hmetrics = u16(tables["hhea"] + 34)


def glyph_for(ch):
    cmap = tables["cmap"]
    for i in range(u16(cmap + 2)):
        sub = cmap + u32(cmap + 4 + 8 * i + 4)
        if u16(sub) == 4:
            segs = u16(sub + 6) // 2
            ends, starts = sub + 14, sub + 16 + 2 * segs
            deltas, ranges = starts + 2 * segs, starts + 4 * segs
            for s in range(segs):
                if u16(starts + 2 * s) <= ord(ch) <= u16(ends + 2 * s):
                    ro = u16(ranges + 2 * s)
                    if ro == 0:
                        return (ord(ch) + i16(deltas + 2 * s)) & 0xFFFF
                    g = u16(ranges + 2 * s + ro + 2 * (ord(ch) - u16(starts + 2 * s)))
                    return (g + i16(deltas + 2 * s)) & 0xFFFF if g else 0
    raise SystemExit("no glyph for " + ch)


def advance(g):
    return u16(tables["hmtx"] + 4 * min(g, n_hmetrics - 1))


def outline(g):
    loca = tables["loca"]
    a, b = ((u32(loca + 4 * g), u32(loca + 4 * g + 4)) if loca_long else (2 * u16(loca + 2 * g), 2 * u16(loca + 2 * g + 2)))
    if a == b:
        return []
    o = tables["glyf"] + a
    n = i16(o)
    if n < 0:
        raise SystemExit("composite glyph: not needed for this wordmark")
    ends = [u16(o + 10 + 2 * i) for i in range(n)]
    o += 10 + 2 * n
    o += 2 + u16(o)
    npts = ends[-1] + 1
    flags = []
    while len(flags) < npts:
        f = data[o]; o += 1
        flags.append(f)
        if f & 8:
            flags.extend([f] * data[o]); o += 1
    def coords(short, same):
        nonlocal o
        out, v = [], 0
        for f in flags:
            if f & short:
                d = data[o]; o += 1
                v += d if f & same else -d
            elif not f & same:
                v += i16(o); o += 2
            out.append(v)
        return out
    xs = coords(2, 16)
    ys = coords(4, 32)
    contours, start = [], 0
    for e in ends:
        contours.append([(xs[i], ys[i], bool(flags[i] & 1)) for i in range(start, e + 1)])
        start = e + 1
    return contours


advances = [advance(glyph_for(c)) for c in text]
scale = target_w / sum(advances)
x0 = centre_x - target_w / 2
parts, pen = [], 0
fmt = lambda v: ("%.1f" % v).rstrip("0").rstrip(".")
for ch in text:
    g = glyph_for(ch)
    X = lambda x: x0 + (pen + x) * scale
    Y = lambda y: baseline - y * scale
    for pts in outline(g):
        # Normalise so the contour starts on an on-curve point; implied points sit between two off-curve ones.
        full = []
        for i, (x, y, on) in enumerate(pts):
            nx, ny, non = pts[(i + 1) % len(pts)]
            full.append((x, y, on))
            if not on and not non:
                full.append(((x + nx) / 2, (y + ny) / 2, True))
        k = next(i for i, p in enumerate(full) if p[2])
        full = full[k:] + full[:k]
        d = ["M%s %s" % (fmt(X(full[0][0])), fmt(Y(full[0][1])))]
        i = 1
        while i <= len(full):
            x, y, on = full[i % len(full)]
            if on:
                d.append("L%s %s" % (fmt(X(x)), fmt(Y(y))))
                i += 1
            else:
                cx, cy = x, y
                ex, ey, _ = full[(i + 1) % len(full)]
                d.append("Q%s %s %s %s" % (fmt(X(cx)), fmt(Y(cy)), fmt(X(ex)), fmt(Y(ey))))
                i += 2
        parts.append("".join(d) + "Z")
    pen += advance(g)
print("".join(parts))

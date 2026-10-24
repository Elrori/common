#!/usr/bin/env python3
"""Extract a real netlist from a KiCad 7 .kicad_sch by geometry.

KiCad only stores symbol placements, pin offsets inside the library symbol and
wire polylines; connectivity is implied by coincident coordinates. This script
rebuilds that: absolute pin positions -> union-find over wire endpoints ->
nets named after any label that lands on them.
"""
import math
import re
import sys


def tokenise(text):
    """Very small s-expression reader."""
    tok = re.compile(r'\(|\)|"(?:[^"\\]|\\.)*"|[^\s()]+')
    stack = [[]]
    for m in tok.finditer(text):
        t = m.group(0)
        if t == "(":
            stack.append([])
        elif t == ")":
            top = stack.pop()
            stack[-1].append(top)
        elif t.startswith('"'):
            stack[-1].append(t[1:-1].replace('\\"', '"'))
        else:
            stack[-1].append(t)
    return stack[0]


def child(node, key):
    for c in node:
        if isinstance(c, list) and c and c[0] == key:
            return c
    return None


def children(node, key):
    return [c for c in node if isinstance(c, list) and c and c[0] == key]


def lib_pins(lib_symbol):
    """{pin_number: (dx, dy)} in symbol coordinates."""
    out = {}
    for unit in children(lib_symbol, "symbol"):
        for pin in children(unit, "pin"):
            at = child(pin, "at")
            num = child(pin, "number")
            if at and num:
                out[num[1]] = (float(at[1]), float(at[2]))
    return out


def rotate(px, py, deg):
    r = math.radians(deg)
    c, s = math.cos(r), math.sin(r)
    return px * c + py * s, -px * s + py * c


class DSU:
    def __init__(self):
        self.p = {}

    def find(self, a):
        self.p.setdefault(a, a)
        while self.p[a] != a:
            self.p[a] = self.p[self.p[a]]
            a = self.p[a]
        return a

    def union(self, a, b):
        self.p[self.find(a)] = self.find(b)


def main(path):
    root = tokenise(open(path, encoding="utf-8", errors="ignore").read())
    top = root[0]
    libs = {}
    libsec = child(top, "lib_symbols")
    if libsec:
        for s in children(libsec, "symbol"):
            libs[s[1]] = lib_pins(s)

    dsu = DSU()
    pin_at = []       # (ref, pin, x, y)
    for sym in children(top, "symbol"):
        lid = child(sym, "lib_id")
        at = child(sym, "at")
        if not lid or not at:
            continue
        x, y, deg = float(at[1]), float(at[2]), float(at[3]) if len(at) > 3 else 0.0
        mirror = child(sym, "mirror")
        ref = val = "?"
        for p in children(sym, "property"):
            if p[1] == "Reference":
                ref = p[2]
            elif p[1] == "Value":
                val = p[2]
        pins = libs.get(lid[1], {})
        for num, (dx, dy) in pins.items():
            mx, my = dx, dy
            if mirror and "y" in mirror:
                mx = -mx
            rx, ry = rotate(mx, my, deg)
            ax, ay = round(x + rx, 3), round(y - ry, 3)
            pin_at.append((ref, val, num, ax, ay))
            dsu.find((ax, ay))

    # wires: connect the two ends of every segment, and every joint
    for w in children(top, "wire"):
        pts = child(w, "pts")
        if not pts:
            continue
        xy = [(round(float(p[1]), 3), round(float(p[2]), 3))
              for p in children(pts, "xy")]
        for a, b in zip(xy, xy[1:]):
            dsu.union(a, b)

    # labels attach names to the point they sit on
    names = {}
    for kind in ("label", "global_label", "hierarchical_label"):
        for lb in children(top, kind):
            at = child(lb, "at")
            if not at:
                continue
            p = (round(float(at[1]), 3), round(float(at[2]), 3))
            names.setdefault(dsu.find(p), lb[1])

    nets = {}
    for ref, val, num, ax, ay in pin_at:
        nets.setdefault(dsu.find((ax, ay)), []).append(f"{ref}.{num}")
    for root_id, members in sorted(nets.items(), key=lambda kv: -len(kv[1])):
        if len(members) < 2:
            continue
        print(f"{names.get(root_id, 'N$' + str(abs(hash(root_id)) % 1000)):<18} "
              f"{len(members):2d}  {' '.join(sorted(members))}")

    print("\n--- parts ---")
    seen = {}
    for ref, val, num, ax, ay in pin_at:
        seen.setdefault(ref, val)
    for ref, val in sorted(seen.items()):
        if val != "?":
            print(f"  {ref:<7} {val}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else
         r"C:\Users\Administrator\OneDrive\doc\work\mix\ad9226-ext\kicad0.2\ad9226-ext.kicad_sch")

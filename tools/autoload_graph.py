"""Autoload dependency graph from godot/project.godot and the autoload scripts.

Prints each autoload's references to other autoloads (comments ignored) and
the cycles (strongly connected sets). Exits 1 on any cycle other than the
Rng, Run, WorldState hub. --write refreshes the Depends on /
Depended by / cycle part of each line in docs/AUTOLOADS.md.
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.join(ROOT, "godot")
DOC = os.path.join(ROOT, "docs", "AUTOLOADS.md")
ALLOWED = ["Rng", "Run", "WorldState"]


def autoloads():
    txt = io.open(os.path.join(GODOT, "project.godot"), encoding="utf-8").read()
    blk = txt.split("[autoload]")[1].split("\n[")[0]
    out = {}
    for line in blk.splitlines():
        m = re.match(r'(\w+)="\*?res://(.+)"', line.strip())
        if m:
            out[m.group(1)] = m.group(2)
    return out


def graph(al):
    deps = {}
    for n, p in al.items():
        path = os.path.join(GODOT, p)
        if not p.endswith(".gd") or not os.path.exists(path):
            continue
        lines = io.open(path, encoding="utf-8").read().splitlines()
        src = "\n".join(l.split("#")[0] for l in lines)
        deps[n] = sorted(
            o for o in al
            if o != n and re.search(r"(?<![\w.])%s\b|/root/%s\b" % (o, o), src)
        )
    return deps


def cycles(deps):
    idx, low, st, on, comp_of, c = {}, {}, [], set(), {}, [0]
    sys.setrecursionlimit(10000)

    def visit(v):
        idx[v] = low[v] = c[0]
        c[0] += 1
        st.append(v)
        on.add(v)
        for w in deps.get(v, []):
            if w not in deps:
                continue
            if w not in idx:
                visit(w)
                low[v] = min(low[v], low[w])
            elif w in on:
                low[v] = min(low[v], idx[w])
        if low[v] == idx[v]:
            comp = []
            while True:
                w = st.pop()
                on.discard(w)
                comp.append(w)
                if w == v:
                    break
            if len(comp) > 1:
                for w in comp:
                    comp_of[w] = sorted(comp)

    for v in deps:
        if v not in idx:
            visit(v)
    return comp_of


def write_doc(deps, comp_of):
    rdeps = {n: sorted(m for m in deps if n in deps[m]) for n in deps}
    lines = io.open(DOC, encoding="utf-8").read().split("\n")
    out = []
    for l in lines:
        m = re.match(r"- \*\*(\w+)\*\* — (.*?Phase [^.]*\.) ", l)
        if m and m.group(1) in deps:
            n = m.group(1)
            tail = ""
            if n in comp_of:
                same = [x for x in deps[n] if x in comp_of[n]]
                tail = " **In a cycle via %s.**" % ", ".join(same)
            l = "- **%s** — %s Depends on %s. Depended by %s.%s" % (
                n, m.group(2), ", ".join(deps[n]) or "—", ", ".join(rdeps[n]) or "—", tail)
        out.append(l)
    io.open(DOC, "w", encoding="utf-8", newline="\n").write("\n".join(out))


def main():
    deps = graph(autoloads())
    comp_of = cycles(deps)
    for n in deps:
        print("%s: %s" % (n, ", ".join(deps[n])))
    seen = []
    for comp in comp_of.values():
        if comp not in seen:
            seen.append(comp)
    print("CYCLES %d: %s" % (len(seen), " | ".join(", ".join(c) for c in seen)))
    if "--write" in sys.argv:
        write_doc(deps, comp_of)
    if [c for c in seen if c != sorted(ALLOWED)]:
        sys.exit(1)


if __name__ == "__main__":
    main()

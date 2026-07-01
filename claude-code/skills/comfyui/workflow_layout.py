#!/usr/bin/env python3
"""
Workflow layout: auto-arrange a ComfyUI (litegraph UI-format) node graph so nodes NEVER overlap, the flow
reads left-to-right by dependency depth, parallel branches stack vertically (left-aligned per column), and a
node with a shared input/output sits in the MIDDLE of what it connects to. Plus a code-only inspector so
layout is verified from the JSON coordinates, never from a screenshot (cheap, deterministic, no tokens spent
looking at the canvas, and clients hit the same wall reading a canvas).

Rules implemented (a layered / Sugiyama layout with barycenter coordinate assignment):
  - Columns by dependency depth: sources on the left, each node one column right of its deepest input.
    Next column clears the WIDEST node in the current one, so a wide node never overlaps the column to its
    right. Nodes in a column share the same x (left-aligned).
  - Within a column, nodes keep a vertical gap >= node height, so two nodes can never overlap.
  - Coordinate assignment centers every node on the nodes it connects to: a single input that fans out to N
    nodes sits at their vertical middle (not at the top); a sink fed by N nodes sits at their middle; a node
    sits aligned with its one neighbour. Then each column is de-overlapped, preserving order.
  - Node sizes are estimated from real widget / slot counts AND from whether the node renders a big image
    preview (PreviewImage, LoadImage, etc. are ~230px taller than their widgets imply). Auto-layout writes
    the estimated size back so the canvas and the layout agree.

Usage:
  from workflow_layout import auto_layout, inspect
  wf = auto_layout(wf)                        # same dict, new pos/size, no overlaps
  print(inspect(wf)["summary"])               # overlaps / crossings / bounds, all from coordinates

CLI:
  python workflow_layout.py graph.json                 # inspect only
  python workflow_layout.py graph.json --apply          # auto-layout in place
  python workflow_layout.py graph.json --apply --out fixed.json
"""
import json
import sys

# litegraph-approximate metrics (px). Estimates are deliberately GENEROUS: if a node renders SHORTER than the
# estimate the only cost is empty space, but if it renders TALLER than the estimate it overlaps the node below.
# The extra headroom also covers widgets added by a node's own JS at runtime (e.g. the OCIO swap button), which
# are not in widgets_values and so are invisible to this estimator.
TITLE_H = 36
SLOT_H = 24          # per i/o row (rows = max(inputs, outputs))
WIDGET_H = 30        # per widget row
PAD_H = 28           # base padding + headroom for a possible runtime-added button row
H_GAP = 120          # horizontal gap between columns
V_GAP = 70           # vertical gap between stacked nodes
DEFAULT_W = 250
# nodes that render a large image / preview area, far taller than their widget count implies
IMAGE_PREVIEW_TYPES = {
    "PreviewImage", "SaveImage", "LoadImage", "PreviewAny", "MaskPreview", "Preview3D", "Load3D",
    "SaveAnimatedWEBP", "VHS_VideoCombine", "ImageCompare", "SaveImageWebsocket", "SaveVideo", "PreviewVideo",
}
IMAGE_PREVIEW_H = 260


def _pos(node):
    p = node.get("pos", [0, 0])
    if isinstance(p, dict):
        return [float(p.get("0", 0)), float(p.get("1", 0))]
    return [float(p[0]), float(p[1])]


def est_size(node):
    """Estimate (w, h) the node renders at in ComfyUI, from its slots, widgets, and image-preview area."""
    n_in = len(node.get("inputs", []) or [])
    n_out = len(node.get("outputs", []) or [])
    n_widg = len(node.get("widgets_values", []) or [])
    rows = max(n_in, n_out)
    h = TITLE_H + rows * SLOT_H + n_widg * WIDGET_H + PAD_H
    if node.get("type") in IMAGE_PREVIEW_TYPES:
        h += IMAGE_PREVIEW_H
    sz = node.get("size")
    if isinstance(sz, dict):
        sz = [sz.get("0"), sz.get("1")]
    w = DEFAULT_W
    if sz and sz[0]:
        w = max(w, float(sz[0]))
    if sz and sz[1]:
        h = max(h, float(sz[1]))
    return [round(w), round(h)]


def _edges(wf):
    """(src_id, dst_id) per link. litegraph link: [lid, src, sslot, dst, dslot, type]."""
    out = []
    for lk in wf.get("links", []) or []:
        if isinstance(lk, list) and len(lk) >= 5:
            out.append((lk[1], lk[3]))
        elif isinstance(lk, dict):
            out.append((lk.get("origin_id"), lk.get("target_id")))
    return out


# --------------------------------------------------------------------------- inspector (code-only)

def inspect(wf):
    nodes = {n["id"]: n for n in wf.get("nodes", [])}
    box = {}
    for nid, n in nodes.items():
        x, y = _pos(n)
        w, h = est_size(n)  # real render footprint, not the optimistic declared size
        box[nid] = (x, y, x + float(w), y + float(h))

    ids = list(box)
    overlaps = []
    for i in range(len(ids)):
        ax0, ay0, ax1, ay1 = box[ids[i]]
        for j in range(i + 1, len(ids)):
            bx0, by0, bx1, by1 = box[ids[j]]
            ox = min(ax1, bx1) - max(ax0, bx0)
            oy = min(ay1, by1) - max(ay0, by0)
            if ox > 0 and oy > 0:
                overlaps.append((ids[i], ids[j], round(ox * oy)))

    def seg(a, b):
        ax0, ay0, ax1, ay1 = box[a]
        bx0, by0, bx1, by1 = box[b]
        return (ax1, (ay0 + ay1) / 2), (bx0, (by0 + by1) / 2)

    def ccw(p, q, r):
        return (r[1] - p[1]) * (q[0] - p[0]) > (q[1] - p[1]) * (r[0] - p[0])

    def crosses(s1, s2):
        a, b = s1; c, d = s2
        return ccw(a, c, d) != ccw(b, c, d) and ccw(a, b, c) != ccw(a, b, d)

    edges = [(s, t) for s, t in _edges(wf) if s in box and t in box]
    segs = [seg(s, t) for s, t in edges]
    crossings = 0
    for i in range(len(segs)):
        for j in range(i + 1, len(segs)):
            if edges[i][0] in edges[j] or edges[i][1] in edges[j]:
                continue
            if crosses(segs[i], segs[j]):
                crossings += 1

    xs = [b[0] for b in box.values()] + [b[2] for b in box.values()]
    ys = [b[1] for b in box.values()] + [b[3] for b in box.values()]
    bounds = [min(xs), min(ys), max(xs), max(ys)] if box else [0, 0, 0, 0]
    summary = (f"nodes={len(nodes)} edges={len(edges)} overlaps={len(overlaps)} "
               f"crossings={crossings} bounds={[round(v) for v in bounds]}")
    return {"summary": summary, "overlaps": overlaps, "crossings": crossings,
            "bounds": bounds, "n_nodes": len(nodes), "n_edges": len(edges)}


# --------------------------------------------------------------------------- auto layout (layered)

def auto_layout(wf, origin=(40, 40)):
    nodes = {n["id"]: n for n in wf.get("nodes", [])}
    if not nodes:
        return wf
    edges = [(s, t) for s, t in _edges(wf) if s in nodes and t in nodes]
    succ = {nid: [] for nid in nodes}
    pred = {nid: [] for nid in nodes}
    for s, t in edges:
        succ[s].append(t)
        pred[t].append(s)

    # 1. longest-path layering (rank = column)
    rank = {}

    def depth(nid, seen):
        if nid in rank:
            return rank[nid]
        if nid in seen:
            return 0
        seen = seen | {nid}
        r = 0 if not pred[nid] else 1 + max(depth(p, seen) for p in pred[nid])
        rank[nid] = r
        return r

    for nid in nodes:
        depth(nid, set())

    order = {}
    for nid, r in rank.items():
        order.setdefault(r, []).append(nid)
    for r in order:
        order[r].sort()

    # 2. ordering within a layer: barycenter passes to reduce crossings
    pil = {nid: i for r in order for i, nid in enumerate(order[r])}
    for _ in range(4):
        for r in sorted(order):
            if r > 0:
                order[r].sort(key=lambda n: (sum(pil[p] for p in pred[n]) / len(pred[n]) if pred[n] else pil[n]))
                for i, nid in enumerate(order[r]):
                    pil[nid] = i
        for r in sorted(order, reverse=True):
            order[r].sort(key=lambda n: (sum(pil[s] for s in succ[n]) / len(succ[n]) if succ[n] else pil[n]))
            for i, nid in enumerate(order[r]):
                pil[nid] = i

    # 3. sizes, then x by column width (next column clears the widest node in this one)
    for n in nodes.values():
        n["size"] = est_size(n)
    H = {nid: nodes[nid]["size"][1] for nid in nodes}

    ox, oy = origin
    col_x = {}
    x = ox
    for r in sorted(order):
        col_x[r] = x
        x += max((nodes[nid]["size"][0] for nid in order[r]), default=DEFAULT_W) + H_GAP

    # 4. y: stack each column, then center each node on its neighbours (shared input/output -> middle),
    #    de-overlapping each column on every pass. A few passes converge.
    ypos = {}
    for r in sorted(order):
        y = oy
        for nid in order[r]:
            ypos[nid] = y
            y += H[nid] + V_GAP

    def ctr(nid):
        return ypos[nid] + H[nid] / 2.0

    def place(col, desired):
        """Lay a column out as a non-overlapping stack, then shift the whole block so its centroid matches the
        mean desired center (centers a shared input/output on what it connects to; no downward drift)."""
        col = sorted(col, key=lambda n: desired.get(n, ypos[n]))
        tmp = {}
        y = 0.0
        for nid in col:
            tmp[nid] = y
            y += H[nid] + V_GAP
        cur = sum(tmp[n] + H[n] / 2.0 for n in col) / len(col)
        des = sum(desired.get(n, ctr(n)) for n in col) / len(col)
        sh = des - cur
        for nid in col:
            ypos[nid] = tmp[nid] + sh
        return col

    cols = sorted(order)
    for _ in range(10):
        for r in cols:  # forward: center each node on its predecessors
            desired = {n: sum(ctr(p) for p in pred[n]) / len(pred[n]) for n in order[r] if pred[n]}
            order[r] = place(order[r], desired)
        for r in reversed(cols):  # backward: center each node on its successors
            desired = {n: sum(ctr(s) for s in succ[n]) / len(succ[n]) for n in order[r] if succ[n]}
            order[r] = place(order[r], desired)

    if ypos:
        shift = oy - min(ypos.values())
        for nid in ypos:
            ypos[nid] += shift

    for nid, n in nodes.items():
        n["pos"] = [round(col_x[rank[nid]]), round(ypos[nid])]
    return wf


def fit_group(wf, title="", color="#335159", pad=45, title_h=46):
    """Add ONE backdrop group that FULLY encloses every node (padding all round + a title bar above). The rule
    for a backdrop: it must cover all the nodes of the functional unit it labels, edge to edge, none sticking
    out. Call after auto_layout. (For a graph with several functional units, group them separately upstream.)"""
    nodes = wf.get("nodes", [])
    if not nodes:
        return wf
    x0 = y0 = float("inf")
    x1 = y1 = float("-inf")
    for n in nodes:
        x, y = _pos(n)
        w, h = est_size(n)
        x0 = min(x0, x); y0 = min(y0, y); x1 = max(x1, x + w); y1 = max(y1, y + h)
    bounding = [round(x0 - pad), round(y0 - pad - title_h),
                round((x1 - x0) + 2 * pad), round((y1 - y0) + 2 * pad + title_h)]
    wf["groups"] = [{"title": title, "bounding": bounding, "color": color, "font_size": 24}]
    return wf


def _load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(0)
    path = args[0]
    wf = _load(path)
    apply = "--apply" in args
    out = path
    if "--out" in args:
        out = args[args.index("--out") + 1]
    before = inspect(wf)
    print("BEFORE:", before["summary"])
    if before["overlaps"]:
        print("  overlapping pairs (id,id,area):", before["overlaps"][:12])
    if apply:
        wf = auto_layout(wf)
        after = inspect(wf)
        print("AFTER :", after["summary"])
        if after["overlaps"]:
            print("  STILL overlapping:", after["overlaps"][:12])
        with open(out, "w", encoding="utf-8") as f:
            json.dump(wf, f, indent=2)
        print("wrote:", out)

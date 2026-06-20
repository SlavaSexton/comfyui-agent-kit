#!/usr/bin/env python3
"""Fetch a shared ComfyHub workflow (comfy.org/workflows/<hash>) as plain JSON.

ComfyHub serves every shared workflow's graph at a predictable URL derived from its hash:
    https://comfy.org/workflows/download/<hash>.json

Usage:
    python fetch_workflow.py <hash> [outdir]
    # e.g. python fetch_workflow.py 7dca0438edf4 ./workflows

The <hash> is the id in the share URL, e.g. comfy.org/workflows/<hash>-<hash>/ -> use <hash>.
Note: cloud.comfy.org/?share=<hash> links are Comfy Cloud only and are NOT downloadable this way;
open them in Comfy Cloud and export from the canvas instead.
"""
import os
import sys
import urllib.request

BASE = "https://comfy.org/workflows/download/{h}.json?filename={h}"


def fetch(h, outdir="."):
    h = h.strip().split("-")[0]                      # accept "<hash>-<hash>" form
    url = BASE.format(h=h)
    req = urllib.request.Request(url, headers={"User-Agent": "comfyui-agent-kit"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    os.makedirs(outdir, exist_ok=True)
    dst = os.path.join(outdir, f"{h}.json")
    with open(dst, "wb") as f:
        f.write(data)
    return dst


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        raise SystemExit(2)
    out = fetch(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else ".")
    print("saved:", out, f"({os.path.getsize(out)} bytes)")

#!/usr/bin/env python3
"""Minimal ComfyUI client (stdlib only, no extra deps).

Loads an API-format workflow JSON, applies overrides, queues it via the local ComfyUI HTTP API,
waits for completion by polling /history, and downloads the output images / videos.

ComfyUI Desktop serves the API at http://127.0.0.1:8188 by default.

Override keys are "<nodeId>.<inputName>", e.g. to set the positive prompt and seed:
  run("wf_api.json", {"6.text": "a cinematic dragon, dark studio", "3.seed": 12345}, outdir="assets")

To get a workflow JSON: in ComfyUI enable Dev mode (Settings -> "Enable Dev mode Options"),
build the graph, then "Save (API Format)". That file is what this client runs.
"""
import json
import os
import time
import uuid
import urllib.request
import urllib.parse

HOST = os.environ.get("COMFY_HOST", "127.0.0.1:8188")


def _get(path):
    with urllib.request.urlopen(f"http://{HOST}{path}", timeout=15) as r:
        return json.load(r)


def _post(path, payload):
    req = urllib.request.Request(
        f"http://{HOST}{path}",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def alive():
    """True if the ComfyUI API answers."""
    try:
        _get("/system_stats")
        return True
    except Exception:
        return False


def apply_overrides(workflow, overrides):
    """overrides: {"<nodeId>.<inputName>": value}. Mutates and returns the workflow dict."""
    for k, v in (overrides or {}).items():
        node_id, _, field = k.partition(".")
        node = workflow.get(node_id)
        if node is None:
            raise KeyError(f"node {node_id} not in workflow")
        node.setdefault("inputs", {})[field] = v
    return workflow


def queue(workflow, client_id=None):
    """Queue a workflow (prompt graph dict). Returns prompt_id."""
    cid = client_id or str(uuid.uuid4())
    res = _post("/prompt", {"prompt": workflow, "client_id": cid})
    return res["prompt_id"]


def wait(prompt_id, timeout=600, poll=2.0):
    """Poll /history until the prompt finishes. Returns its history record."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        hist = _get(f"/history/{prompt_id}")
        rec = hist.get(prompt_id)
        if rec and rec.get("outputs"):
            return rec
        time.sleep(poll)
    raise TimeoutError(f"comfy prompt {prompt_id} did not finish in {timeout}s")


def download_outputs(history_rec, outdir):
    """Save all output images/gifs/videos from a history record into outdir. Returns saved paths."""
    os.makedirs(outdir, exist_ok=True)
    saved = []
    for _node, out in (history_rec.get("outputs") or {}).items():
        for key in ("images", "gifs", "videos"):
            for item in out.get(key, []):
                q = urllib.parse.urlencode({
                    "filename": item["filename"],
                    "subfolder": item.get("subfolder", ""),
                    "type": item.get("type", "output"),
                })
                with urllib.request.urlopen(f"http://{HOST}/view?{q}", timeout=120) as r:
                    data = r.read()
                dst = os.path.join(outdir, item["filename"])
                with open(dst, "wb") as f:
                    f.write(data)
                saved.append(dst)
    return saved


def run(workflow_path, overrides=None, outdir=".", timeout=600):
    """Load an API-format workflow JSON, apply overrides, run it, save outputs. Returns saved paths."""
    with open(workflow_path, "r", encoding="utf-8") as f:
        wf = json.load(f)
    apply_overrides(wf, overrides)
    pid = queue(wf)
    rec = wait(pid, timeout=timeout)
    return download_outputs(rec, outdir)


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("workflow")
    ap.add_argument("--set", action="append", default=[], help='override "nodeId.input=value"')
    ap.add_argument("--outdir", default=".")
    ap.add_argument("--timeout", type=int, default=600)
    a = ap.parse_args()
    ov = {}
    for s in a.set:
        k, _, v = s.partition("=")
        if v.lstrip("-").isdigit():
            v = int(v)
        ov[k] = v
    print("alive:", alive())
    print("saved:", run(a.workflow, ov, a.outdir, a.timeout))

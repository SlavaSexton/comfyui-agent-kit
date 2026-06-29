"""Assemble the Claude Code plugin's bundled skill from the canonical sources.

The plugin (`claude-code/`) is a SELF-CONTAINED Claude Code distribution of the same skill the
multi-agent installer wires. So that `/plugin install comfyui` ships the full kit, the plugin needs the
skill files physically present under `claude-code/skills/comfyui/`. This script copies them from the
single source of truth (`shared/comfyui/` + `docs/`) so the bundle never drifts by hand.

RUN IT before cutting a release whenever SKILL.md / MODELS.md / a routed doc changed:
    python tools/build_plugin.py
The plugin's `.mcp.json` / manifests are config, not generated, so they are NOT touched here.
"""
import os, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
DST = os.path.join(ROOT, "claude-code", "skills", "comfyui")

# (source path relative to repo root) -> filename in the plugin skill dir.
# The plugin lays docs flat next to SKILL.md, matching the installed-skill layout (SKILL.md routes to
# "next to this file ... or docs/X.md", so flat resolves).
FILES = {
    "shared/comfyui/SKILL.md": "SKILL.md",
    "shared/comfyui/MODELS.md": "MODELS.md",
    "shared/comfyui/comfy_client.py": "comfy_client.py",
    "docs/MODEL_INDEX.md": "MODEL_INDEX.md",
    "docs/ADVANCED.md": "ADVANCED.md",
    "docs/KIJAI.md": "KIJAI.md",
    "docs/KNOWN_ISSUES.md": "KNOWN_ISSUES.md",
    "docs/LTX2_TRAINING.md": "LTX2_TRAINING.md",
    "docs/TASKS.md": "TASKS.md",
}

os.makedirs(DST, exist_ok=True)
copied = []
for src_rel, name in FILES.items():
    src = os.path.join(ROOT, src_rel)
    if not os.path.exists(src):
        print(f"  MISSING source, skipped: {src_rel}")
        continue
    shutil.copyfile(src, os.path.join(DST, name))
    copied.append(name)

print(f"built claude-code/skills/comfyui/ : {len(copied)} files -> {', '.join(copied)}")

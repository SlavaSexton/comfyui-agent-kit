#!/usr/bin/env bash
# Gemini CLI adapter. Ships an extension at ~/.gemini/extensions/comfyui bundling the MCP + GEMINI.md context.
# Assumes shared/install_shared.sh already ran.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; REPO_ROOT="$(cd "$HERE/../.." && pwd)"; SHARED="$REPO_ROOT/shared/comfyui"
EXT="$HOME/.gemini/extensions/comfyui"
ok(){ echo "  [ok] $*"; }; warn(){ echo "  [!]  $*"; }; have(){ command -v "$1" >/dev/null 2>&1; }

echo; echo "[gemini] adapter"
have gemini || { warn "gemini CLI not found; install Gemini CLI first"; exit 1; }
mkdir -p "$EXT"

# GEMINI.md = SKILL.md body with YAML frontmatter stripped
{ printf '# ComfyUI media generation (always-on context for Gemini CLI)\n\nUse this whenever a task involves generating images, video, or audio with ComfyUI, or building/running a workflow. The per-model prompting reference is MODELS.md next to this file.\n\n'
  awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; next} n>=2{print}' "$SHARED/SKILL.md"
} > "$EXT/GEMINI.md"
cp "$SHARED/MODELS.md" "$EXT/MODELS.md"
cp "$SHARED/comfy_client.py" "$EXT/comfy_client.py"
ok "GEMINI.md + MODELS.md + client -> $EXT"

cat > "$EXT/gemini-extension.json" <<'JSON'
{
  "name": "comfyui",
  "version": "1.0.0",
  "description": "Drive a local ComfyUI for image, video, and audio generation. By AI VFX NEWS.",
  "contextFileName": "GEMINI.md",
  "mcpServers": {
    "comfyui": {
      "command": "comfyui-mcp",
      "args": [],
      "cwd": "${extensionPath}"
    }
  }
}
JSON
ok "gemini-extension.json written"
echo "[gemini] done. Restart gemini so the extension + MCP load (/extensions list to confirm)."

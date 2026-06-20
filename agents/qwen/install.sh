#!/usr/bin/env bash
# Qwen Code adapter (Gemini-CLI fork). Extension at ~/.qwen/extensions/comfyui, manifest qwen-extension.json,
# context QWEN.md. Assumes shared/install_shared.sh already ran.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; REPO_ROOT="$(cd "$HERE/../.." && pwd)"; SHARED="$REPO_ROOT/shared/comfyui"
EXT="$HOME/.qwen/extensions/comfyui"
ok(){ echo "  [ok] $*"; }; warn(){ echo "  [!]  $*"; }; have(){ command -v "$1" >/dev/null 2>&1; }

echo; echo "[qwen] adapter"
have qwen || { warn "qwen CLI not found; install Qwen Code first"; exit 1; }
mkdir -p "$EXT"

{ printf '# ComfyUI media generation (always-on context for Qwen Code)\n\nUse this whenever a task involves generating images, video, or audio with ComfyUI, or building/running a workflow. The per-model prompting reference is MODELS.md next to this file.\n\n'
  awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; next} n>=2{print}' "$SHARED/SKILL.md"
} > "$EXT/QWEN.md"
cp "$SHARED/MODELS.md" "$EXT/MODELS.md"
cp "$SHARED/comfy_client.py" "$EXT/comfy_client.py"
ok "QWEN.md + MODELS.md + client -> $EXT"

cat > "$EXT/qwen-extension.json" <<'JSON'
{
  "name": "comfyui",
  "version": "1.0.0",
  "description": "Drive a local ComfyUI for image, video, and audio generation. By AI VFX NEWS.",
  "contextFileName": "QWEN.md",
  "mcpServers": {
    "comfyui": {
      "command": "comfyui-mcp",
      "args": [],
      "cwd": "${extensionPath}"
    }
  }
}
JSON
ok "qwen-extension.json written"
echo "[qwen] done. Restart qwen so the extension + MCP load."

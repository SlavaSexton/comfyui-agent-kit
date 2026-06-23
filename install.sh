#!/usr/bin/env bash
# ComfyUI-Agent-Kit installer. Runs shared setup once, then installs the comfyui skill + MCP for each selected
# agent (claude, codex, gemini, qwen). Idempotent.
#   ./install.sh [--agents claude,gemini] [--comfyui-path PATH] [--templates-dir PATH] [--skip-templates] [--skip-nodes]
set -euo pipefail
AGENTS="auto"; COMFYUI_PATH=""; TEMPLATES_DIR="$HOME/comfyui-agent-kit-data/workflow_templates"; ST=""; SN=""
while [ $# -gt 0 ]; do case "$1" in
  --agents) AGENTS="$2"; shift 2;;
  --comfyui-path) COMFYUI_PATH="$2"; shift 2;;
  --templates-dir) TEMPLATES_DIR="$2"; shift 2;;
  --skip-templates) ST="--skip-templates"; shift;;
  --skip-nodes) SN="--skip-nodes"; shift;;
  *) echo "unknown arg: $1"; exit 1;; esac; done
ROOT="$(cd "$(dirname "$0")" && pwd)"
have(){ command -v "$1" >/dev/null 2>&1; }

echo; echo "=== ComfyUI-Agent-Kit installer ==="

# 1. shared machine setup
args=(--templates-dir "$TEMPLATES_DIR"); [ -n "$COMFYUI_PATH" ] && args+=(--comfyui-path "$COMFYUI_PATH")
[ -n "$ST" ] && args+=("$ST"); [ -n "$SN" ] && args+=("$SN")
bash "$ROOT/shared/install_shared.sh" "${args[@]}"

# 2. pick agents
known="claude codex gemini qwen"; sel=""
if [ "$AGENTS" = "auto" ]; then for a in $known; do have "$a" && sel="$sel $a"; done
else for a in $(echo "$AGENTS" | tr ',' ' '); do case " $known " in *" $a "*) sel="$sel $a";; esac; done; fi
sel="$(echo "$sel" | xargs)"
if [ -z "$sel" ]; then echo; echo "No target agent CLIs on PATH. Install one of: $known, then re-run (or pass --agents)."; exit 0; fi
echo; echo "Installing for: $sel"

# 3. run each adapter
for a in $sel; do
  if [ "$a" = "claude" ]; then bash "$ROOT/agents/claude/install.sh" --templates-dir "$TEMPLATES_DIR" || echo "  [!] claude adapter failed"
  else bash "$ROOT/agents/$a/install.sh" || echo "  [!] $a adapter failed"; fi
done

echo; echo "=== Done. Next steps ==="
echo "  1. Start ComfyUI. Confirm http://127.0.0.1:8188 answers."
echo "  2. Restart the agent CLI(s) so the skill/extension + MCP load."
echo "  3. Run the BOOTSTRAP once (docs/BOOTSTRAP.md): detect GPUs/VRAM/RAM/disk + paths."
echo "  Note: GLM (z.ai) runs through Claude Code, so the 'claude' adapter already covers it."

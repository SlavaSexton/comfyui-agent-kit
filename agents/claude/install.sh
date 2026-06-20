#!/usr/bin/env bash
# Claude Code adapter: install the comfyui skill, register the MCP, append the auto-activation block.
# Assumes shared/install_shared.sh already ran. GLM via Claude Code reuses this adapter (~/.claude/skills).
set -euo pipefail
TEMPLATES_DIR="$HOME/comfyui-agent-kit-data/workflow_templates"
while [ $# -gt 0 ]; do case "$1" in --templates-dir) TEMPLATES_DIR="$2"; shift 2;; *) shift;; esac; done
HERE="$(cd "$(dirname "$0")" && pwd)"; REPO_ROOT="$(cd "$HERE/../.." && pwd)"; SHARED="$REPO_ROOT/shared/comfyui"
SKILLS="$HOME/.claude/skills"; CLAUDE_MD="$HOME/.claude/CLAUDE.md"
ok(){ echo "  [ok] $*"; }; warn(){ echo "  [!]  $*"; }; have(){ command -v "$1" >/dev/null 2>&1; }

echo; echo "[claude] adapter"
have claude || { warn "claude CLI not found; install Claude Code first"; exit 1; }

mkdir -p "$SKILLS/comfyui/workflows"
cp "$SHARED/SKILL.md" "$SKILLS/comfyui/SKILL.md"
cp "$SHARED/MODELS.md" "$SKILLS/comfyui/MODELS.md"
cp "$SHARED/comfy_client.py" "$SKILLS/comfyui/comfy_client.py"
ok "comfyui skill -> $SKILLS/comfyui"

tmp="$(mktemp -d)"; git clone --depth 1 https://github.com/jtydhr88/comfyui-custom-node-skills.git "$tmp" >/dev/null 2>&1
src="$tmp/plugins/comfyui-custom-nodes/skills"
if [ -d "$src" ]; then for d in "$src"/*/; do dst="$SKILLS/$(basename "$d")"; rm -rf "$dst"; cp -R "$d" "$dst"; done; ok "node-building skills installed"; else warn "node skills not found"; fi
rm -rf "$tmp"

if claude mcp get comfyui >/dev/null 2>&1; then ok "MCP 'comfyui' already registered"
else claude mcp add comfyui --scope user -- comfyui-mcp && ok "MCP registered" || warn "register manually: claude mcp add comfyui --scope user -- comfyui-mcp"; fi

marker="### ComfyUI media generation (auto-activation)"
if [ -f "$CLAUDE_MD" ] && grep -qF "$marker" "$CLAUDE_MD"; then ok "activation block present"
else mkdir -p "$(dirname "$CLAUDE_MD")"; sed "s|__TEMPLATES_DIR__|$TEMPLATES_DIR|g" "$HERE/claude_md_activation.md" >> "$CLAUDE_MD"; ok "activation block appended"; fi

echo "[claude] done. Start ComfyUI, then run the BOOTSTRAP once (docs/BOOTSTRAP.md)."

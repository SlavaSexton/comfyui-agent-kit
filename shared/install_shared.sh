#!/usr/bin/env bash
# Shared, agent-independent machine setup: MCP driver package, workflow templates, optional in-graph Claude nodes.
# Run once; the per-agent adapters wire the skill + register the MCP.
set -euo pipefail
COMFYUI_PATH=""; TEMPLATES_DIR="$HOME/comfyui-agent-kit-data/workflow_templates"; SKIP_TEMPLATES=0; SKIP_NODES=0
while [ $# -gt 0 ]; do case "$1" in
  --comfyui-path) COMFYUI_PATH="$2"; shift 2;;
  --templates-dir) TEMPLATES_DIR="$2"; shift 2;;
  --skip-templates) SKIP_TEMPLATES=1; shift;;
  --skip-nodes) SKIP_NODES=1; shift;;
  *) echo "unknown arg: $1"; exit 1;; esac; done
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ok(){ echo "  [ok] $*"; }; warn(){ echo "  [!]  $*"; }; have(){ command -v "$1" >/dev/null 2>&1; }

echo; echo "[shared] machine-level setup"
for c in node npm git python3; do have "$c" && ok "$c" || { warn "$c MISSING"; exit 1; }; done

npm install -g comfyui-mcp >/dev/null 2>&1; ok "comfyui-mcp installed globally"

if [ "$SKIP_NODES" -eq 1 ]; then warn "skipping in-graph Claude nodes"
elif [ -n "$COMFYUI_PATH" ] && [ -d "$COMFYUI_PATH/custom_nodes" ]; then
  cn="$COMFYUI_PATH/custom_nodes"
  while IFS='|' read -r name url; do
    if [ -d "$cn/$name" ]; then ok "$name present"; else git clone --depth 1 "$url" "$cn/$name" >/dev/null 2>&1 && ok "$name cloned" || warn "failed: $name"; fi
  done <<'EOF'
anthropic-claude|https://github.com/alexmunteanu/comfyui-anthropic-claude.git
comfyui_claude_prompt_generator|https://github.com/PauldeLavallaz/comfyui_claude_prompt_generator.git
EOF
  warn "Restart ComfyUI to load the nodes; they may need: pip install 'anthropic>=0.40.0'"
else warn "no --comfyui-path: install Claude nodes via ComfyUI Manager (search 'anthropic claude')"; fi

if [ "$SKIP_TEMPLATES" -eq 1 ]; then warn "skipping templates"
elif [ -d "$TEMPLATES_DIR/.git" ]; then ok "templates already at $TEMPLATES_DIR (git pull to update)"
else
  mkdir -p "$(dirname "$TEMPLATES_DIR")"
  git clone --filter=blob:none --no-checkout https://github.com/Comfy-Org/workflow_templates.git "$TEMPLATES_DIR" >/dev/null 2>&1
  git -C "$TEMPLATES_DIR" sparse-checkout set templates blueprints >/dev/null 2>&1
  git -C "$TEMPLATES_DIR" checkout >/dev/null 2>&1
  if [ -f "$TEMPLATES_DIR/templates/index.json" ]; then
    python3 "$REPO_ROOT/shared/tools/gen_quick_index.py" "$TEMPLATES_DIR/templates"; ok "templates cloned + index built -> $TEMPLATES_DIR"
  else warn "template clone incomplete"; fi
fi
echo "[shared] done. Templates: $TEMPLATES_DIR"

# The four layers

The kit is a stack. Each layer is independent; together they let Claude drive ComfyUI end to end and show its
work in the owner's canvas.

## Layer 1: Knowledge + client (the skill)

`~/.claude/skills/comfyui/SKILL.md` + `comfy_client.py`.

The skill is the operating manual: workflow JSON formats (GUI vs API), how to parameterize a graph, the
template flow, multi-GPU placement, the GUI bridge, VRAM gotchas, the restart gotcha, and the per-task
procedure. `comfy_client.py` is a zero-dependency (stdlib) HTTP client: `alive`, `run`, `queue`, `wait`,
`download_outputs`, `apply_overrides`. Override host with the `COMFY_HOST` env var. This layer works even with
nothing else installed.

## Layer 2: MCP driver

`comfyui-mcp` (npm, by artokun, MIT) registered as a Claude Code MCP server. Gives ~90 structured tools:
`health_check`, `generate_image` / `generate_audio`, `create_workflow` / `modify_workflow` /
`validate_workflow`, `get_object_info` / `get_node_info`, `download_model` / `search_models`, queue control,
`clear_vram`, logs, and more. When these tools are present, prefer them over hand-POSTing `/prompt`; they
validate graphs and surface errors. Falls back to Layer 1's client if the MCP is unavailable.

Caveat: do NOT use the MCP's `restart_comfyui` against a Comfy Desktop (Electron) install, it kills the server
and cannot relaunch it. See the gotcha in SKILL.md.

## Layer 3: In-graph Claude nodes

Claude as a node INSIDE a workflow, for prompt enrichment and vision QA. Three options, see NODES.md:
`AnthropicClaudeNode` (your key, 40+ model-specific templates), `ClaudeNode` (official, Comfy.org credits),
`ClaudeCustomPrompt` (simple). Only needed when a graph must enrich prompts WITHOUT Claude in the loop (an
unattended pipeline). When you are driving, write the prompt yourself.

## Layer 4: Node-building skills

`~/.claude/skills/comfyui-node-*` (by jtydhr88 / Terry Jia): nine skills covering the ComfyUI V3 custom-node
API, basics, inputs, outputs, datatypes, advanced, lifecycle, frontend, migration, packaging. Pull these only
when the task is to write or modify a custom node, not for ordinary generation.

## Supporting asset: the template library

The official `Comfy-Org/workflow_templates` repo, sparse-cloned locally (~900MB). It is the source of truth for
how to do any task in ComfyUI: 500+ templates + reusable subgraph blueprints. `tools/gen_quick_index.py` builds
`templates/_quick_index.json` so Claude can match a request to a template fast. Update with `git pull` + rerun
the generator.

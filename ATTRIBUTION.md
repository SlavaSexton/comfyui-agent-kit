# Attribution

This kit's original files (the `comfyui` skill, `comfy_client.py`, the installers, `gen_quick_index.py`, the
docs, and the activation snippet) are MIT-licensed, see `LICENSE`.

The installer **fetches** the following third-party components from their own repositories at install time.
They are NOT redistributed in this repo; each keeps its own license. Credit to their authors:

| Component | Author / Org | Source | License |
|-----------|--------------|--------|---------|
| `comfyui-mcp` (MCP driver, Layer 2) | artokun | https://github.com/artokun/comfyui-mcp | MIT |
| `anthropic-claude` per-model prompt templates (research input for `MODELS.md`) | alexmunteanu | https://github.com/alexmunteanu/comfyui-anthropic-claude | see repo |
| `comfyui-custom-node-skills` (node-building skills, Layer 4) | jtydhr88 (Terry Jia) | https://github.com/jtydhr88/comfyui-custom-node-skills | see repo |
| `workflow_templates` (template library) | Comfy-Org | https://github.com/Comfy-Org/workflow_templates | see repo |
| `anthropic-claude` (`AnthropicClaudeNode`, Layer 3) | alexmunteanu | https://github.com/alexmunteanu/comfyui-anthropic-claude | see repo |
| `comfyui_claude_prompt_generator` (`ClaudeCustomPrompt`, Layer 3) | PauldeLavallaz | https://github.com/PauldeLavallaz/comfyui_claude_prompt_generator | see repo |
| `ClaudeNode` (official partner node) | Comfy-Org | ships with ComfyUI | see ComfyUI |
| ComfyUI itself | Comfy-Org | https://github.com/comfyanonymous/ComfyUI | GPL-3.0 |

If you redistribute a build that bundles any of these, comply with that component's license. The kit keeps them
as fetch-at-install precisely so this repo stays clean and license-clear.

## MODELS.md provenance

`skills/comfyui/MODELS.md` is original writing by this kit, distilled from official sources: each model maker's
documentation and model cards, the ComfyUI tutorials at docs.comfy.org, and the per-model prompt templates from
the `anthropic-claude` node (credited above). Its own "Sources and provenance" section lists the makers. Model
specs change over time, so each entry links its official source for re-verification.

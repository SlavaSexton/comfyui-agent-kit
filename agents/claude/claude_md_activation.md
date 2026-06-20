
### ComfyUI media generation (auto-activation)
Keywords: "comfyui", "comfy", "generate image", "generate photo", "generate video", "generate audio",
"render image", "hero image", "z-image", "ideogram", "flux", "ltx", "wan", "image2video", "text2image",
"text2video", "comfy workflow", "run workflow", "upscale", "make art with", "media for the article/post",
"local diffusion", "local image/video generation"
-> Skill: comfyui (always pull before working with ComfyUI: the API client + comfy_client.py, workflow JSON
   format, the template library, model patterns, multi-GPU placement, the MCP driver, in-graph Claude nodes,
   the GUI bridge, and VRAM coordination).

ComfyUI driver layers, all installed by the kit:
- MCP tools `mcp__comfyui__*` (Layer 2) — prefer these to operate ComfyUI directly.
- `comfyui-node-*` skills (Layer 4) — pull only when writing/modifying a custom node.
- Workflow templates (source of truth): __TEMPLATES_DIR__/templates (index: _quick_index.json).
- GUI bridge to show graphs to the user: <ComfyUI>/user/default/workflows/.

On a new machine, run the BOOTSTRAP once (the kit's docs/BOOTSTRAP.md): detect paths/GPUs/models via the
MCP health_check and fill the machine block in the comfyui skill before generating.

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

## Optional components (you install these yourself for specific features)

These are NOT fetched by the installer and NOT redistributed here. The kit documents how to use them and
recommends them for specific capabilities (multi-shot video, restoration, upscaling); you install them yourself
when you want those features. Credit and licenses:

| Component | Author / Org | Source | License |
|-----------|--------------|--------|---------|
| `ComfyUI-PromptRelay` (Prompt Relay nodes, LTX-2.3 / Wan) | kijai | https://github.com/kijai/ComfyUI-PromptRelay | no license file |
| `ComfyUI-SUPIR` (SUPIR restore nodes) | kijai / XPixel Group | https://github.com/kijai/ComfyUI-SUPIR | NON-COMMERCIAL (XPixel) |
| `WhatDreamsCost-ComfyUI` (LTX Director 2.0) | WhatDreamsCost | https://github.com/WhatDreamsCost/WhatDreamsCost-ComfyUI | GPL-3.0 |
| Real-ESRGAN (upscale models) | Xintao Wang / BasicSR | https://github.com/xinntao/Real-ESRGAN | BSD-3-Clause |
| KJNodes (LTX-2.3 NAG / GGUF / chunk-FF / multi-guide) | kijai | https://github.com/kijai/ComfyUI-KJNodes | see repo |
| ComfyUI-CacheDiT (LTX-2 inference caching) | Jasonzzt | https://github.com/Jasonzzt/ComfyUI-CacheDiT | see repo |
| ComfyUI-MelBandRoFormer (audio stem separation) | community | Comfy Registry: ComfyUI-MelBandRoFormer | see repo |
| ComfyUI-Frame-Interpolation (FILM / RIFE) | Fannovel16 | https://github.com/Fannovel16/ComfyUI-Frame-Interpolation | see repo |
| comfyui-inpaint-cropandstitch (Flux.2 masked inpaint) | community | Comfy Registry: comfyui-inpaint-cropandstitch | see repo |
| GAP LTX 2.3 Motion (lipsync / storyboard) | GeekatplayStudio | https://github.com/GeekatplayStudio/LTX-2-3-LipSync | MIT |
| ComfyUI-Flux2Klein-Enhancer (Flux.2 Klein identity-transfer suite) | capitan01R | https://github.com/capitan01R/ComfyUI-Flux2Klein-Enhancer | PolyForm Noncommercial 1.0.0 |

The research method **Prompt Relay** (Gordon Chen, Ziqi Huang, Ziwei Liu; S-Lab, NTU; arXiv 2604.10030) and the
model weights it leans on (alibaba-pai Z-Image ControlNet, Apache-2.0; Lightricks LTX-2.3 and the gated HDR
IC-LoRA, license:other) are credited inline at each `MODELS.md` entry's `Source:` line. **SUPIR is
non-commercial**: do not use it in a commercial pipeline. The **ComfyUI-Flux2Klein-Enhancer** suite (capitan01R) is
**PolyForm Noncommercial 1.0.0**: free for personal, research, and nonprofit use; commercial use needs a separate
license from the author.

## MODELS.md provenance

`skills/comfyui/MODELS.md` is original writing by this kit, distilled from official sources: each model maker's
documentation and model cards, the ComfyUI tutorials at docs.comfy.org, and the per-model prompt templates from
the `anthropic-claude` node (credited above). Its own "Sources and provenance" section lists the makers. Model
specs change over time, so each entry links its official source for re-verification.

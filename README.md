<div align="center">

<img src="docs/assets/cover.png" width="840" alt="ComfyUI Skill for Claude Code, by AI VFX NEWS">

# comfyui-claude-kit

**The signature ComfyUI skill for Claude Code, by [AI VFX NEWS](https://t.me/AI_VFX_NEWS).**

Make Claude Code drive a local **ComfyUI** at full power, generate images, video, and audio, build and run
workflows, and **show the graph live in your own ComfyUI canvas**, then hand the whole setup to someone else
with one command.

![License: MIT](https://img.shields.io/badge/License-MIT-FFD27D.svg)
![ComfyUI](https://img.shields.io/badge/ComfyUI-driven-5BAEE3.svg)
![Claude Code](https://img.shields.io/badge/Claude_Code-skill-9aa3b2.svg)
![Platforms](https://img.shields.io/badge/Windows_·_Linux_·_macOS-supported-9aa3b2.svg)

</div>

---

This is the portable, machine-independent version of a working ComfyUI + Claude setup. Clone it, run the
installer, and your Claude Code gets the same stack, wired to *your* hardware.

## The four-layer stack

<div align="center">

<img src="docs/assets/architecture.png" width="880" alt="The four-layer stack: knowledge + client, MCP driver, in-graph Claude nodes, node-building skills, plus the template library and GUI bridge">

</div>

| Layer | What | Installed as |
|------:|------|--------------|
| 1 | **Knowledge + client** the operating manual and a zero-dependency HTTP client | `~/.claude/skills/comfyui/` |
| 2 | **MCP driver** ~90 structured tools so Claude operates ComfyUI directly | `comfyui-mcp` (npm) + MCP registration |
| 3 | **In-graph Claude nodes** Claude as a step inside a workflow (prompt enrichment, vision QA) | ComfyUI `custom_nodes` |
| 4 | **Node-building skills** for writing/modifying custom nodes (V3 API) | `~/.claude/skills/comfyui-node-*` |
| + | **Template library** the official 500+ workflow templates, the source of truth | sparse git clone + quick index |

Plus a **GUI bridge**: Claude writes graphs to `<ComfyUI>/user/default/workflows/`, you open them in the
built-in Workflows sidebar and tweak them. No extra "agent panel" node required.

See [docs/LAYERS.md](docs/LAYERS.md) for each layer in detail.

## The template library is the source of truth

The kit clones the official [Comfy-Org/workflow_templates](https://github.com/Comfy-Org/workflow_templates) and
builds a compact lookup index so Claude can match any request to the right template. 534 templates span every
task, image, video, 3D, audio, utilities:

<div align="center">

<img src="docs/assets/templates_by_category.png" width="760" alt="Workflow templates by category: 136 image, 129 video, 107 use cases, 67 utility, 33 3D, 29 audio, and more">

</div>

## Prerequisites

- [Claude Code](https://claude.com/claude-code) CLI (`claude` on PATH)
- [Node.js](https://nodejs.org) (`node` + `npm`)
- [git](https://git-scm.com), [Python 3](https://python.org)
- A local **ComfyUI** install (Desktop or source), [comfy.org](https://www.comfy.org/)

## Install

Windows (PowerShell):

```powershell
git clone https://github.com/SlavaSexton/comfyui-claude-kit.git
cd comfyui-claude-kit
./install.ps1 -ComfyUIPath "E:\path\to\ComfyUI"   # -ComfyUIPath is optional
```

Linux / macOS:

```bash
git clone https://github.com/SlavaSexton/comfyui-claude-kit.git
cd comfyui-claude-kit
./install.sh --comfyui-path /path/to/ComfyUI       # --comfyui-path is optional
```

The installer is **idempotent**, re-run it any time. Flags: `-SkipTemplates` / `--skip-templates` (skip the
~900MB template clone), `-SkipNodes` / `--skip-nodes` (skip the in-graph Claude nodes). If you omit the ComfyUI
path, it prints ComfyUI Manager instructions for the nodes instead of cloning them.

## First run on a new machine

After install, start ComfyUI, then in a Claude Code session tell Claude to run the **bootstrap** once
([docs/BOOTSTRAP.md](docs/BOOTSTRAP.md)): it detects your GPUs, paths, and installed models via the MCP
`health_check` and fills the machine-specific block in the skill, then does a smoke-test generation. After that,
just ask for media, the skill auto-activates on ComfyUI keywords.

## Optional: in-graph Claude key

Only needed if you want a workflow to enrich prompts **without** Claude in the loop (e.g. an unattended pipeline):

```powershell
setx CLAUDE_API_KEY "sk-ant-..."   # then restart ComfyUI
```

See [docs/NODES.md](docs/NODES.md). When you are driving, Claude writes prompts directly, better and free.

## Layout

```
comfyui-claude-kit/
├── install.ps1 / install.sh         one-command wiring (idempotent)
├── skills/comfyui/                  SKILL.md + comfy_client.py  (Layer 1, ours)
├── tools/gen_quick_index.py         rebuild the template lookup index
├── snippets/claude_md_activation.md auto-activation block appended to CLAUDE.md
├── docs/BOOTSTRAP.md                run once on a new machine
├── docs/LAYERS.md                   the four layers explained
├── docs/NODES.md                    the three Claude nodes, billing + purpose
├── ATTRIBUTION.md                   credits for fetched third-party pieces
└── LICENSE                          MIT (this kit's original files)
```

## What is and isn't in this repo

In the repo (original work, MIT): the skill, the client, the installer, the index generator, the docs, the
generated visuals. Fetched at install time from their own sources (not redistributed here): the `comfyui-mcp`
package, the node-building skills, the workflow templates, and the in-graph Claude nodes.

## Credits and thanks

This kit stands on excellent open-source work. It is a thin wiring layer over these projects, and the heavy
lifting is theirs. Huge thanks to:

- **[ComfyUI](https://github.com/comfyanonymous/ComfyUI)** by comfyanonymous / Comfy-Org, the engine everything
  runs on.
- **[comfyui-mcp](https://github.com/artokun/comfyui-mcp)** by [artokun](https://github.com/artokun), the MCP
  driver (Layer 2) that lets Claude operate ComfyUI with structured tools.
- **[comfyui-custom-node-skills](https://github.com/jtydhr88/comfyui-custom-node-skills)** by
  [jtydhr88 / Terry Jia](https://github.com/jtydhr88), the node-building skills (Layer 4).
- **[workflow_templates](https://github.com/Comfy-Org/workflow_templates)** by Comfy-Org, the template library
  that is the source of truth.
- **[comfyui-anthropic-claude](https://github.com/alexmunteanu/comfyui-anthropic-claude)** by
  [alexmunteanu](https://github.com/alexmunteanu) and
  **[comfyui_claude_prompt_generator](https://github.com/PauldeLavallaz/comfyui_claude_prompt_generator)** by
  [PauldeLavallaz](https://github.com/PauldeLavallaz), the in-graph Claude nodes (Layer 3).

Full per-component licensing is in [ATTRIBUTION.md](ATTRIBUTION.md). If anything here misattributes your work,
open an issue and it will be fixed.

## License

MIT, see [LICENSE](LICENSE). Third-party components keep their own licenses.

<div align="center">

Made by **[AI VFX NEWS](https://t.me/AI_VFX_NEWS)**

</div>

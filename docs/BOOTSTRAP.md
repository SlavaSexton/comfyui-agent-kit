# BOOTSTRAP: run once on a new machine

After `install.ps1` / `install.sh` finishes and ComfyUI is running, have Claude do this ONE time. It detects
the real machine and rewrites the placeholder "Your machine" block in `~/.claude/skills/comfyui/SKILL.md` so
every later ComfyUI task starts from accurate facts instead of the kit author's example.

## What Claude should do

1. **Confirm the API is up.** MCP `health_check`, or `comfy_client.alive()` + `GET /system_stats`. If down,
   ask the owner to start ComfyUI (Desktop: open the app; source: run its launcher).

2. **Detect GPUs, VRAM, and RAM.** From `health_check` / `/system_stats`: how many CUDA devices, model, VRAM
   each (free + total), and system RAM (free + total). Record per-card VRAM, it drives model-variant choice.

2b. **Detect free disk on the model drive.** Find the drive that holds the model root (step 3) and record its
   free space (`df -h "<model root>"`). This gates whether a multi-GB model download can fit. Together with VRAM,
   this is what the "Pick a model variant that fits THIS machine" section in SKILL.md uses to recommend or refuse
   a download.

3. **Detect the ComfyUI paths.** From the MCP environment / startup log: the core ComfyUI path, the user dir,
   the `extra_model_paths` / shared models dir, and the GUI workflows folder `<ComfyUI>/user/default/workflows/`.
   Confirm that folder is writable (it is the bridge for showing graphs to the owner).

4. **Detect installed models.** Query live, do not assume:
   - `GET /object_info/UNETLoader` and `/object_info/CheckpointLoaderSimple` (diffusion / checkpoints)
   - `/object_info/CLIPLoader`, `/object_info/DualCLIPLoader` (text encoders)
   - `/object_info/VAELoader` (VAEs)
   - note which image / video / audio models are present, and which are missing for the owner's use case.

5. **Detect the Claude nodes (Layer 3).** MCP `list_installed_nodes` filtered by "claude". Record which of
   `AnthropicClaudeNode` / `ClaudeNode` / `ClaudeCustomPrompt` exist (see NODES.md). Note whether
   `CLAUDE_API_KEY` is set (only needed for autonomous in-graph enrichment).

6. **Locate the template clone.** Default `~/comfyui-claude-kit-data/workflow_templates`; confirm
   `templates/_quick_index.json` exists. If missing, run `tools/gen_quick_index.py <templates dir>`.

7. **Rewrite the machine block.** Replace the "## Your machine" placeholders in `SKILL.md` with the detected
   values (GPUs, paths, models, templates dir, workflows folder). Remove the "Example from the kit author"
   note once filled.

8. **Smoke test.** Build or load one small template (e.g. a turbo text-to-image), run it via the MCP or
   `comfy_client.run(...)`, download the output, and VIEW it. Confirm the full path works end to end before
   declaring the kit ready.

## Done when

- `SKILL.md`'s machine block reflects this machine,
- a test generation produced a file you actually viewed,
- and (if the owner wants graphs shown) you wrote one GUI-format workflow to the bridge folder and confirmed it
  opens cleanly in the Workflows sidebar.

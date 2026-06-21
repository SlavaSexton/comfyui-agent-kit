# Updating: staying current with ComfyUI

New models and workflows appear constantly. The kit stays current by polling the **machine-readable** sources,
not LinkedIn (auth-gated, anti-scraping, against ToS; the same announcements are on the blog RSS below).

## Sources we watch

- **Comfy-Org/workflow_templates** (the cloned template library), the canonical "what's new" feed. Every new
  model / workflow Comfy ships lands here first. `git pull` + regenerate the quick index, and you have the new
  templates instantly.
- **blog.comfy.org/feed**: RSS of announcements (day-0 model support, "wrapped" recaps, releases). Verified
  working (`https://blog.comfy.org/feed`).
- *(optional)* GitHub release feeds for ComfyUI core and node packs: `<repo>/releases.atom`.

## One command to check

```
python shared/tools/check_updates.py [templates_dir]
```

It pulls the template clone, regenerates the quick index, **diffs** for NEW models + NEW templates, and prints the
recent blog posts. Run it any time to see what changed. Stdlib only.

## The update loop (how to refresh the repo's knowledge)

1. Run `check_updates.py`. It lists NEW models (now in templates, no recipe yet) and recent blog posts.
2. For each genuinely new GENERATIVE model, research its OFFICIAL prompting (maker docs / model card /
   docs.comfy.org) and add a recipe to `shared/comfyui/MODELS.md` in the same format. Update `docs/MODEL_INDEX.md`
   and the coverage counts. (New utility/upscaler -> the Enhancement section instead.)
3. Regenerate the coverage chart if the counts changed.
4. Sync `MODELS.md` / `SKILL.md` to the installed skill(s) and commit + push. Content edits do NOT need an
   installer re-run, the agents read the skill files live; only a brand-new MCP/agent needs its adapter re-run.

The agent can do steps 1-2 itself on request: *"check for new ComfyUI models and add recipes for any new ones."*

## Automating it (optional)

Run the check on a schedule so new models surface without thinking about it:

- **Windows (Task Scheduler):**
  ```
  schtasks /create /tn "comfyui-kit-update" /sc weekly /d MON /st 09:00 ^
    /tr "python <repo>\shared\tools\check_updates.py"
  ```
- **Linux/macOS (cron):**
  ```
  0 9 * * 1 python <repo>/shared/tools/check_updates.py >> ~/comfyui-kit-update.log 2>&1
  ```

The schedule refreshes the template library and logs new models weekly. Turning a "new model" into a committed
recipe stays a human/agent step (it needs research + judgement) on purpose: auto-committing unreviewed recipes
would break the kit's rule of official sources and no invented specs.

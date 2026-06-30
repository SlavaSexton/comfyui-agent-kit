# Samplers

The sampling family: the nodes that actually denoise a latent, plus the modular pieces the custom-sampling
path breaks that job into (a sampler algorithm, a sigma schedule, a guider, a noise source). The all-in-one
`KSampler` and `KSamplerAdvanced` hide all of that behind widgets; the `SamplerCustom` / `SamplerCustomAdvanced`
pair exposes it as separate typed ports so you can swap one piece without touching the rest. Most of these live
in core ComfyUI's `comfy_extras.nodes_custom_sampler` module; a few schedulers are model-specific and ship in
their model's extras module. I/O below is **confirmed via get_node_info: 2026-06-30** (ComfyUI 0.25.1) from the
provided pull; the semantics, placement, and gotchas are the curated layer. `KSampler` already has a full entry
in `core.md`, so it gets a one-line pointer here, not a duplicate.

Any input typed `COMBO[...]` of model or file names is one machine's installed files and is described as "a
dropdown of installed <thing> files", never hardcoded. The `sampler_name` and `scheduler` combos are different:
their values are built-in algorithm identifiers in ComfyUI's code (the same on every install), so a few
representative ones are named the way `core.md` does for `KSampler`.

One naming trap worth stating up front: the menu category `model/sampling/guiders` holds two unrelated shapes.
The `BasicGuider` / `CFGGuider` / `DualCFGGuider` nodes output a `GUIDER` for `SamplerCustomAdvanced`.
`VideoLinearCFGGuidance` sits in the same menu category but outputs a patched `MODEL`, not a `GUIDER`; it is a
model patch, not a guider for the custom-sampling path. Read the output type, not the menu folder.

## The custom-sampling graph (how the modular pieces wire)

```
RandomNoise            ──NOISE────▶ SamplerCustomAdvanced.noise
BasicGuider / CFGGuider ─GUIDER───▶ SamplerCustomAdvanced.guider
KSamplerSelect          ─SAMPLER──▶ SamplerCustomAdvanced.sampler
BasicScheduler          ─SIGMAS───▶ SamplerCustomAdvanced.sigmas
EmptyLatentImage        ─LATENT───▶ SamplerCustomAdvanced.latent_image
SamplerCustomAdvanced   ─LATENT───▶ VAEDecode.samples
```

That is the same job `KSampler` does in one node, split into five inputs you can each swap. `SamplerCustom` is
the middle ground: it takes a `SAMPLER` and `SIGMAS` like the advanced node, but keeps `cfg` / `positive` /
`negative` / `noise_seed` as widgets instead of a `GUIDER` and a `NOISE`.

---

### SamplerCustomAdvanced  (display: "SamplerCustomAdvanced")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_custom_sampler`) | **category:** `model/sampling/custom_sampling` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** the fully modular denoiser. Run a sampling pass where the noise source, the guidance, the sampler algorithm, and the sigma schedule are all separate input nodes you wire in.
- **inputs:**
  - `noise` (`NOISE`) - the initial noise source. From `RandomNoise` (seeded) or `DisableNoise` (zero noise, for a continuation pass that should not re-noise).
  - `guider` (`GUIDER`) - what steers the denoise. From `BasicGuider` (no CFG), `CFGGuider` (standard pos/neg CFG), `DualCFGGuider`, or any node that outputs `GUIDER`. This carries the model and the conditioning, so there are no separate `model` / `positive` / `negative` ports here.
  - `sampler` (`SAMPLER`) - the algorithm. From `KSamplerSelect`, `SamplerLCM`, or another sampler-builder node.
  - `sigmas` (`SIGMAS`) - the noise schedule (the per-step sigma values). From `BasicScheduler` or a model-specific scheduler.
  - `latent_image` (`LATENT`) - the latent to denoise. `EmptyLatentImage` for txt2img, a `VAEEncode` output for img2img (paired with a partial-denoise sigma schedule).
- **outputs:**
  - `output` (`LATENT`) - the denoised latent; feeds `VAEDecode.samples`.
  - `denoised_output` (`LATENT`) - the model's predicted clean latent (the x0 estimate). Useful for previews or for chaining a second pass; for a normal finished image use `output`.
- **how it works:** assembles the four typed pieces into one sampling loop and runs it. The guider already holds the model and conditioning, the sampler holds the algorithm, the sigmas hold the schedule, and the noise holds the starting point, so this node only orchestrates them.
- **strengths:** swap any single piece (try a different scheduler, a CFG-free guider, a continuation with `DisableNoise`) without rebuilding the rest. The standard sampler for Flux and most modern guider-based workflows. Exposes both the final and the x0-predicted latent.
- **bugs / lags + fixes:** none known in the node. Mismatched pieces fail at wiring time (wrong type) rather than silently, which is the point of the typed ports.
- **anti-patterns:** feeding a `MODEL` where a `GUIDER` is expected (the output of `VideoLinearCFGGuidance` is a `MODEL`, not a `GUIDER`, so it does not go here; patch the model, then build a guider from it). Sigmas whose length does not match the intended step count. Using `DisableNoise` for a from-scratch txt2img (you need real noise to denoise from).
- **placement:** the engine of a custom-sampling graph, fed by a noise node, a guider, a sampler-select, a scheduler, and a latent; feeds `VAEDecode`. The advanced sibling of `KSampler`.

### SamplerCustom  (display: "SamplerCustom")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_custom_sampler`) | **category:** `model/sampling/custom_sampling` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** a halfway sampler: take a `SAMPLER` and `SIGMAS` as inputs (so you can pick the algorithm and schedule node-side), but keep CFG and conditioning as widgets instead of building a separate guider.
- **inputs:**
  - `model` (`MODEL`) - the diffusion model.
  - `add_noise` (`BOOLEAN`, default True) - whether to add initial noise. False for a continuation pass on an already-noised latent.
  - `noise_seed` (`INT`, default 0) - the noise seed (`control_after_generate` randomizes per run).
  - `cfg` (`FLOAT`, default 8.0) - Classifier-Free Guidance scale. Same caveat as `KSampler`: distilled / turbo / lightning / LCM models want cfg near 1, not 8.
  - `positive` / `negative` (`CONDITIONING`) - the prompt conditioning.
  - `sampler` (`SAMPLER`) - the algorithm, from `KSamplerSelect` or a sampler-builder.
  - `sigmas` (`SIGMAS`) - the schedule, from a scheduler node.
  - `latent_image` (`LATENT`) - the latent to denoise.
- **outputs:**
  - `output` (`LATENT`) - the denoised latent; feeds `VAEDecode.samples`.
  - `denoised_output` (`LATENT`) - the x0 prediction (clean-latent estimate), as on `SamplerCustomAdvanced`.
- **how it works:** builds a standard CFG guider internally from `model` + `cfg` + `positive` + `negative`, then runs the supplied `sampler` over the supplied `sigmas` from the seeded noise. It is `SamplerCustomAdvanced` with the guider and noise folded back into widgets.
- **strengths:** lets you choose sampler and scheduler as nodes (which `KSampler` cannot) while keeping the familiar cfg/pos/neg widgets, so it is a lighter step up from `KSampler` than the fully modular node.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** reach for `SamplerCustomAdvanced` instead when you need a non-CFG guider (Flux's `BasicGuider`, perp-neg, dual-CFG); this node only builds an ordinary CFG guider. High `cfg` on a distilled / turbo model burns the image, same as `KSampler`.
- **placement:** between conditioning + a sampler-select + a scheduler + a latent, and `VAEDecode`. The middle option between `KSampler` and `SamplerCustomAdvanced`.

### KSamplerSelect  (display: "KSamplerSelect")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_custom_sampler`) | **category:** `model/sampling/samplers` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** pick a sampler algorithm by name and hand it out as a `SAMPLER` object for the custom-sampling nodes.
- **inputs:**
  - `sampler_name` (`COMBO`) - a dropdown of the built-in sampler algorithms (the same identifiers `KSampler` lists in its `sampler_name` widget: `euler`, `euler_ancestral`, `dpmpp_2m`, `dpmpp_2m_sde`, `dpmpp_3m_sde`, `lcm`, `ddim`, `uni_pc`, `res_multistep`, and others). These are code-level names, identical on every install, not files on disk.
- **outputs:**
  - `SAMPLER` (`SAMPLER`) - the chosen algorithm; feeds `SamplerCustom.sampler` or `SamplerCustomAdvanced.sampler`.
- **how it works:** maps the selected name to ComfyUI's sampler implementation and returns it as a `SAMPLER` object with default per-sampler settings. It only names the algorithm; the schedule comes from a separate scheduler node.
- **strengths:** the simplest way to put a stock sampler into the custom-sampling path; one widget, one output.
- **bugs / lags + fixes:** none known. Some sampler names that look paired with a feature (the `_cfg_pp` variants, the `_gpu` variants) behave correctly only in the contexts that support them; pick the plain variant if unsure.
- **anti-patterns:** for samplers that need their own tunable parameters (LCM's per-step noise) use the dedicated builder (`SamplerLCM`) instead of selecting `lcm` here, so you get the extra knobs. This node alone does nothing until its `SAMPLER` is wired into a custom-sampling node.
- **placement:** a leaf feeding `SamplerCustom` / `SamplerCustomAdvanced`. Sits parallel to the scheduler and the guider, not in series.

### BasicScheduler  (display: "BasicScheduler")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_custom_sampler`) | **category:** `model/sampling/schedulers` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** produce the per-step sigma schedule for the custom-sampling path, using the model's own sigma range and one of the standard scheduler curves.
- **inputs:**
  - `model` (`MODEL`) - the diffusion model; the scheduler reads its sigma range so the schedule matches the model.
  - `scheduler` (`COMBO`) - the curve: `simple`, `karras`, `sgm_uniform`, `exponential`, `beta`, `normal`, `ddim_uniform`, `linear_quadratic`, `kl_optimal` (the same set `KSampler` exposes in its `scheduler` widget).
  - `steps` (`INT`, default 20) - number of sigma steps; sets the length of the schedule.
  - `denoise` (`FLOAT`, default 1.0) - 1.0 for a full txt2img schedule; below 1.0 trims the schedule to the high-noise end for img2img (keeps input structure), the same role `denoise` plays on `KSampler`.
- **outputs:**
  - `SIGMAS` (`SIGMAS`) - the schedule; feeds `SamplerCustom.sigmas` or `SamplerCustomAdvanced.sigmas`, or a `SplitSigmas` to cut it.
- **how it works:** asks the model for its sigma boundaries, builds the chosen curve across `steps`, and (if `denoise` < 1) keeps only the portion needed for a partial denoise. The model input is what makes the schedule model-correct.
- **strengths:** the default scheduler for the custom-sampling path; mirrors `KSampler`'s scheduler choices but as a separate node you can branch, split, or reuse.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** for model families with their own scheduler (SD-Turbo, LTX-Video, Flux-2) the dedicated node bakes in the right shift / sigma behavior; use it instead of forcing this generic one. A `steps` here that disagrees with a step count assumed elsewhere gives a mismatched schedule.
- **placement:** a leaf on the sigma line into the custom sampler. Fed by the same `MODEL` as the guider; feeds the sampler node (optionally through `SplitSigmas`).

### BasicGuider  (display: "Basic Guider")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_custom_sampler`) | **category:** `model/sampling/guiders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** wrap a model and a single conditioning into a `GUIDER` with no CFG, for models that are guidance-distilled (Flux dev / schnell) and do not use a separate negative prompt.
- **inputs:**
  - `model` (`MODEL`) - the diffusion model.
  - `conditioning` (`CONDITIONING`) - the single (positive) conditioning. There is no negative input; this guider does not do classifier-free guidance.
- **outputs:**
  - `GUIDER` (`GUIDER`) - feeds `SamplerCustomAdvanced.guider`.
- **how it works:** packages the model with one conditioning and runs the model once per step with no unconditional pass, so there is no CFG scale to set.
- **strengths:** the correct guider for Flux and other guidance-distilled models, where guidance is carried on the conditioning (Flux's `guidance` value lives on its text-encode node) rather than applied as CFG. One conditioning pass per step, so it is cheaper than a CFG guider.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** using it for ordinary SD1.5 / SDXL where you do want a negative prompt and CFG; there `CFGGuider` is correct. Expecting a negative prompt to do anything here (there is no negative input). Setting Flux's strength here (it is set on the Flux text-encode node, not on this guider).
- **placement:** on the guider line into `SamplerCustomAdvanced`, fed by a `MODEL` and one `CLIPTextEncode`-style conditioning. The Flux-path counterpart to `CFGGuider`.

### CFGGuider  (display: "CFG Guider")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_custom_sampler`) | **category:** `model/sampling/guiders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** the standard classifier-free-guidance guider: model + positive + negative + cfg, packaged as a `GUIDER` for `SamplerCustomAdvanced`.
- **inputs:**
  - `model` (`MODEL`) - the diffusion model.
  - `positive` (`CONDITIONING`) - attributes to include.
  - `negative` (`CONDITIONING`) - attributes to exclude.
  - `cfg` (`FLOAT`, default 8.0) - the CFG scale; same tradeoff as `KSampler.cfg` (prompt adherence vs freedom), and the same warning that distilled / turbo / lightning / LCM models want it near 1.
- **outputs:**
  - `GUIDER` (`GUIDER`) - feeds `SamplerCustomAdvanced.guider`.
- **how it works:** builds the same CFG guider `KSampler` uses internally, but as a standalone `GUIDER` object for the modular sampler. Runs a conditional and an unconditional pass per step and combines them at scale `cfg`.
- **strengths:** lets you use the modular `SamplerCustomAdvanced` while keeping ordinary CFG behavior; exactly what `KSampler` does, exposed as a node.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** for guidance-distilled models (Flux) that should not get CFG, use `BasicGuider`. High `cfg` on a turbo / lightning / LCM model burns the image, same as everywhere CFG appears.
- **placement:** on the guider line into `SamplerCustomAdvanced`, fed by a `MODEL` and two `CLIPTextEncode` outputs. The CFG counterpart of `BasicGuider`.

### DualCFGGuider  (display: "Dual CFG Guider")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_custom_sampler`) | **category:** `model/sampling/guiders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** a two-conditioning CFG guider: blend two positive conditionings against a shared negative with two separate CFG scales. The classic use is the InstructPix2Pix-style setup where one conditioning is the image/instruction and one is the text, each needing its own guidance weight.
- **inputs:**
  - `model` (`MODEL`) - the diffusion model.
  - `cond1` (`CONDITIONING`) - the first conditioning.
  - `cond2` (`CONDITIONING`) - the second conditioning.
  - `negative` (`CONDITIONING`) - the shared unconditional / negative.
  - `cfg_conds` (`FLOAT`, default 8.0) - the guidance scale on the combined conditionings.
  - `cfg_cond2_negative` (`FLOAT`, default 8.0) - the guidance scale governing `cond2` against the negative.
  - `style` (`COMBO`) - how the two are combined: `regular` or `nested` (the two ways the two guidance terms are layered). Confirmed via get_node_info 2026-06-30: options are `regular` and `nested`.
- **outputs:**
  - `GUIDER` (`GUIDER`) - feeds `SamplerCustomAdvanced.guider`.
- **how it works:** runs the model against two conditionings and the shared negative, applying the two CFG scales (one for the combined conditioning, one for `cond2`-vs-negative) and combining them per `style`. It generalizes single-prompt CFG to a two-prompt blend.
- **strengths:** the right guider for workflows that genuinely have two conditioning signals at different weights (image + text instruction). More expressive than `CFGGuider` for those.
- **bugs / lags + fixes:** none known in the node. The two cfg values interact, so tuning is less intuitive than a single CFG; change one at a time.
- **anti-patterns:** using it for an ordinary single-prompt generation (`CFGGuider` is simpler and correct there). Feeding three unrelated prompts and expecting a clean blend; it is built for the two-conditioning-plus-negative shape, not arbitrary prompt mixing.
- **placement:** on the guider line into `SamplerCustomAdvanced`, fed by a `MODEL` and the relevant conditionings. A specialized sibling of `CFGGuider`.

### RandomNoise  (display: "RandomNoise")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_custom_sampler`) | **category:** `model/sampling/noise` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** produce the seeded initial noise for the custom-sampling path as a `NOISE` object.
- **inputs:**
  - `noise_seed` (`INT`, default 0) - the seed for the noise (`control_after_generate` is on, so it randomizes per run like a `KSampler` seed).
- **outputs:**
  - `NOISE` (`NOISE`) - feeds `SamplerCustomAdvanced.noise`.
- **how it works:** holds a seed and generates the starting noise tensor lazily when the sampler asks for it, shaped to the latent it is sampling. Splitting noise into its own node is what lets `SamplerCustomAdvanced` keep the seed separate from the guider and sampler.
- **strengths:** the standard noise source for `SamplerCustomAdvanced`; one seed widget, one output, reproducible per seed.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** wiring it into a continuation pass that should not re-noise (use `DisableNoise` there). It only feeds the modular `SamplerCustomAdvanced`; `KSampler` and `SamplerCustom` carry their own seed widget and do not take a `NOISE` input.
- **placement:** a leaf on the noise line into `SamplerCustomAdvanced`. Parallel to the guider, sampler, and scheduler.

### DisableNoise  (display: "DisableNoise")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_custom_sampler`) | **category:** `model/sampling/noise` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** supply a zero-noise `NOISE` object, for a sampling pass that must not add fresh noise (a continuation / second stage that should denoise an already-noised latent without re-seeding it).
- **inputs:** none (it is a constant source).
- **outputs:**
  - `NOISE` (`NOISE`) - a zero-noise source; feeds `SamplerCustomAdvanced.noise`.
- **how it works:** returns a `NOISE` that adds nothing, so the sampler starts from the latent as given rather than from added noise.
- **strengths:** the clean way to do the second half of a split-sigma / two-stage sample where the first stage already noised the latent; avoids double-noising.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** using it for a from-scratch txt2img (there is nothing to denoise without noise, so the output is degenerate). It is for continuation passes only.
- **placement:** a leaf on the noise line into `SamplerCustomAdvanced`, in the second stage of a staged sample (typically after a `SplitSigmas`). The zero-noise counterpart of `RandomNoise`.

### KSamplerAdvanced  (display: "KSamplerAdvanced")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/sampling` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** the `KSampler` with the step-range and noise controls exposed, for staged base-plus-refiner sampling without leaving the single-node form.
- **inputs:**
  - `model` (`MODEL`), `positive` / `negative` (`CONDITIONING`), `latent_image` (`LATENT`) - the usual sampler wiring.
  - `add_noise` (`COMBO`, values `enable` / `disable`) - whether to add initial noise. Disable on a stage that continues from a previous stage's noisy latent.
  - `noise_seed` (`INT`, default 0) - the noise seed.
  - `steps` (`INT`, default 20) - the total step count the schedule is built for.
  - `cfg` (`FLOAT`, default 8.0) - CFG scale; the usual distilled-model caveat applies.
  - `sampler_name` (`COMBO`) - the algorithm (`euler`, `dpmpp_2m`, `dpmpp_2m_sde`, `lcm`, and the rest, as on `KSampler`).
  - `scheduler` (`COMBO`) - the curve (`simple`, `karras`, `sgm_uniform`, `exponential`, `beta`, and the rest).
  - `start_at_step` (`INT`, default 0) - the step this pass begins on.
  - `end_at_step` (`INT`, default 10000) - the step this pass stops on (10000 effectively means "to the end").
  - `return_with_leftover_noise` (`COMBO`, values `disable` / `enable`) - whether to leave the latent noisy for a following stage instead of finishing it.
- **outputs:**
  - `LATENT` (`LATENT`) - the (possibly partially) denoised latent; feeds `VAEDecode` or the next stage.
- **how it works:** the same denoiser as `KSampler`, but it runs only the `start_at_step`..`end_at_step` slice of a `steps`-long schedule and can hand off a still-noisy latent. Two of these in series (one ending early with leftover noise, one starting where the first stopped with `add_noise` disabled) is the classic SDXL base-then-refiner.
- **strengths:** staged sampling (base + refiner, or any partial-then-finish split) in the familiar one-node form, without building the custom-sampling graph.
- **bugs / lags + fixes:** none in the node. The `start_at_step` / `end_at_step` / `return_with_leftover_noise` / `add_noise` settings on the two stages have to line up; a mismatch gives a seam or a double-noised result. This is a wiring/config issue, not a node bug.
- **anti-patterns:** using it for a plain single-stage generation where `KSampler` is simpler. Setting `start_at_step` and `end_at_step` so the second stage re-noises (forgetting to disable `add_noise` on the continuation). High `cfg` on a turbo / lightning model.
- **placement:** the engine, like `KSampler`, but typically two in series for base + refiner. For full modularity (separate guider / sampler / sigmas) use `SamplerCustomAdvanced` instead.

### SDTurboScheduler  (display: "SDTurboScheduler")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_custom_sampler`) | **category:** `model/sampling/schedulers` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** the sigma schedule for SD-Turbo / SDXL-Turbo style models, which finish in very few steps (often 1 to 4).
- **inputs:**
  - `model` (`MODEL`) - the turbo model, read for its sigma range.
  - `steps` (`INT`, default 1) - the (small) step count; turbo models are built for 1 to 4 steps.
  - `denoise` (`FLOAT`, default 1.0) - full denoise at 1.0; below 1.0 for a partial pass.
- **outputs:**
  - `SIGMAS` (`SIGMAS`) - the turbo schedule; feeds the custom sampler's `sigmas`.
- **how it works:** builds the short, turbo-appropriate sigma sequence from the model, defaulting to a single step. The default `steps` of 1 (versus 20 on `BasicScheduler`) is the tell that this is a few-step scheduler.
- **strengths:** the correct schedule for SD-Turbo families; pairs with a low-or-zero CFG guider for the intended fast generation.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** using it for a normal 20-to-30-step model (the schedule is built for very few steps). Pairing it with high CFG; turbo models want cfg near 1. Using it on a non-turbo checkpoint and expecting good results in one step.
- **placement:** a leaf on the sigma line into `SamplerCustom` / `SamplerCustomAdvanced`, in a turbo workflow. The few-step counterpart of `BasicScheduler`.

### LTXVScheduler  (display: "LTXVScheduler")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_lt`, the LTX-Video extras) | **category:** `model/sampling/schedulers` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** the sigma schedule for LTX-Video, with the shift and terminal-stretch controls that family's sampling expects.
- **inputs:**
  - `steps` (`INT`, default 20) - the step count.
  - `max_shift` (`FLOAT`, default 2.05) - the upper sigma-shift bound for the LTXV schedule.
  - `base_shift` (`FLOAT`, default 0.95) - the lower / base sigma-shift.
  - `stretch` (`BOOLEAN`) - "Stretch the sigmas to be in the range [terminal, 1]." (tooltip confirmed via get_node_info 2026-06-30).
  - `terminal` (`FLOAT`) - "The terminal value of the sigmas after stretching." (tooltip confirmed via get_node_info 2026-06-30).
  - `latent` (`LATENT`, optional) - the video latent; when provided the schedule can be shaped to it.
- **outputs:**
  - `SIGMAS` (`SIGMAS`) - the LTXV schedule; feeds the custom sampler's `sigmas`.
- **how it works:** builds a shifted sigma schedule tuned for LTX-Video and, if `stretch` is on, rescales the sigmas down to the `terminal` value at the low end. Unlike `BasicScheduler` it takes no `model` input; the shift is set by the shift widgets (and optionally the latent), not read from a model.
- **strengths:** the model-correct scheduler for LTX-Video; the shift / stretch controls are what that family needs and a generic scheduler does not provide.
- **bugs / lags + fixes:** none known in the node. Belongs to the LTX-Video extras module, so it is present on a standard ComfyUI install but is meaningful only in an LTXV graph.
- **anti-patterns:** using it for a non-LTXV model (the shift behavior is specific to that family). Wiring its `SIGMAS` into a sampler running a different model and expecting correct timing.
- **placement:** a leaf on the sigma line into the LTXV custom-sampling chain. The LTX-Video counterpart of `BasicScheduler`.

### Flux2Scheduler  (display: "Flux2Scheduler")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_flux`) | **category:** `model/sampling/schedulers` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** the sigma schedule for the Flux-2 family, where the schedule depends on the target resolution (the sigma shift scales with image size).
- **inputs:**
  - `steps` (`INT`, default 20) - the step count.
  - `width` (`INT`, default 1024) - the target width; feeds the resolution-dependent shift.
  - `height` (`INT`, default 1024) - the target height; same role.
- **outputs:**
  - `SIGMAS` (`SIGMAS`) - the Flux-2 schedule; feeds the custom sampler's `sigmas`.
- **how it works:** computes a resolution-aware sigma schedule from the step count and the width/height, so larger images get the larger shift Flux-2 expects. It takes width/height instead of a `model` input precisely because the schedule is a function of size, not of a model's stored sigma range.
- **strengths:** the model-correct scheduler for Flux-2; folding resolution into the schedule is what that family needs.
- **bugs / lags + fixes:** none known in the node. Keep `width` / `height` equal to the actual latent size, or the shift is computed for the wrong resolution.
- **anti-patterns:** setting width/height here to something other than the real output size (the schedule then targets the wrong resolution). Using it for a non-Flux-2 model. Confusing it with a node that sizes the latent; this only schedules sigmas, it does not create the latent.
- **placement:** a leaf on the sigma line into the Flux-2 custom-sampling chain, with width/height matching the latent. The Flux-2 counterpart of `BasicScheduler`.

### SamplerLCM  (display: "SamplerLCM")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_advanced_samplers`) | **category:** `model/sampling/samplers` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** build an LCM (Latent Consistency Model) sampler as a `SAMPLER`, with the per-step noise knobs the plain `lcm` selection does not expose. Node description (confirmed via get_node_info 2026-06-30): "LCM sampler with tunable per-step noise. s_noise is a multiplier on the model's training noise scale".
- **inputs:**
  - `s_noise` (`FLOAT`, default 1.0) - "Per-step noise multiplier at the first step (1.0 = match training)." (tooltip confirmed 2026-06-30).
  - `s_noise_end` (`FLOAT`, default 1.0) - "Per-step noise multiplier at the last step. Set equal to s_noise for a constant schedule." (tooltip confirmed 2026-06-30).
  - `noise_clip_std` (`FLOAT`, default 0.0) - "Clamp per-step noise to +/- N*std. 0 disables." (tooltip confirmed 2026-06-30).
- **outputs:**
  - `SAMPLER` (`SAMPLER`) - the LCM sampler; feeds `SamplerCustom.sampler` or `SamplerCustomAdvanced.sampler`.
- **how it works:** returns ComfyUI's LCM sampler configured with the given first/last per-step noise multipliers (interpolated across the run) and an optional clamp on the per-step noise. It is the `lcm` algorithm plus the noise controls surfaced as widgets.
- **strengths:** the way to run LCM in the custom-sampling path with control over the per-step noise, which can clean up LCM's tendency to over- or under-noise; pairs with a low step count and cfg near 1.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** running it at high CFG or many steps; LCM is a few-step, low-CFG method. Using it on a model that is not LCM-distilled (the consistency assumption does not hold, so output degrades). When you do not need the noise knobs, selecting `lcm` in `KSamplerSelect` is simpler.
- **placement:** a leaf feeding the custom sampler's `sampler` input, in an LCM workflow paired with a few-step schedule and a near-1 CFG (or a CFG-free guider).

### SplitSigmas  (display: "SplitSigmas")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_custom_sampler`) | **category:** `model/sampling/sigmas` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** cut one sigma schedule into two at a given step, for two-stage sampling (high-noise stage then low-noise stage).
- **inputs:**
  - `sigmas` (`SIGMAS`) - the full schedule, from a scheduler node.
  - `step` (`INT`, default 0) - the index to split at; the first part runs up to it, the second from it.
- **outputs:**
  - `high_sigmas` (`SIGMAS`) - the early, high-noise portion; feeds the first sampling stage.
  - `low_sigmas` (`SIGMAS`) - the later, low-noise portion; feeds the second stage.
- **how it works:** slices the sigma array at `step` and returns the two halves, so two custom-sampler passes can each run a portion of the schedule. The split point sets how much work each stage does.
- **strengths:** the clean way to stage a custom-sampling run (a base pass then a refiner / detail pass) without two separate full schedules; pairs with `DisableNoise` on the second stage so it continues rather than re-noises.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** a `step` of 0 or at/over the schedule length puts everything in one half and leaves the other empty (a degenerate split). Re-noising the second stage with `RandomNoise` instead of `DisableNoise` (double-noises the handoff). Note this splits by step index; the sibling `SplitSigmasDenoise` (confirmed present 2026-06-30, same module) splits by a `denoise` fraction instead, if that is the cut you want.
- **placement:** on the sigma line between a scheduler and two custom-sampler stages; the second stage typically takes `low_sigmas` with `DisableNoise`.

### VideoLinearCFGGuidance  (display: "Video Linear CFG Guidance")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_video_model`) | **category:** `model/sampling/guiders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** patch a video diffusion model so CFG ramps linearly across the frame batch instead of being constant, easing CFG on some frames. Built for video models such as Stable Video Diffusion.
- **inputs:**
  - `model` (`MODEL`) - the video diffusion model to patch.
  - `min_cfg` (`FLOAT`, default 1.0) - the low end of the CFG ramp; the per-frame CFG runs from `min_cfg` up to the CFG set on the sampler, linearly across the batch.
- **outputs:**
  - `MODEL` (`MODEL`) - the patched model. This is the important distinction: despite living in `model/sampling/guiders`, it outputs a `MODEL`, not a `GUIDER`. It does NOT plug into `SamplerCustomAdvanced.guider`; it goes back onto the model line into a sampler.
- **how it works:** wraps the model so that during sampling the CFG scale is interpolated from `min_cfg` to the sampler's cfg across the frames, rather than held flat. It is a model patch in the spirit of the `model/sampling` patch nodes, not a guider object.
- **strengths:** smooths CFG over a video batch (helps with the over-guided look on later frames in SVD-style generation); a single inline patch on the model line.
- **bugs / lags + fixes:** none known in the node. The naming and menu placement invite wiring it as a guider, which is wrong; it is a `MODEL` patch.
- **anti-patterns:** treating its output as a `GUIDER` (type mismatch into `SamplerCustomAdvanced.guider`; wire the patched `MODEL` into the sampler or into a `BasicGuider` / `CFGGuider` instead). Using it on a still-image model (it is a video-batch CFG ramp; with a single frame there is nothing to ramp across).
- **placement:** in series on the MODEL line, between the model source and the sampler (or the guider you build for `SamplerCustomAdvanced`). An inline patch, not a leaf.

---

### KSampler  (display: "KSampler")
- See the full entry in `core.md`. The all-in-one denoiser (`model` + `positive` / `negative` + `latent_image`, with `seed` / `steps` / `cfg` / `sampler_name` / `scheduler` / `denoise` as widgets), outputs a denoised `LATENT` into `VAEDecode`. For staged base+refiner use `KSamplerAdvanced` above; for a fully modular noise / guider / sampler / sigmas split use `SamplerCustomAdvanced`.

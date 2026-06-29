# Training a custom LTX-2 LoRA (official Lightricks trainer)

## For future Claude

This kit GENERATES with LTX-2 in ComfyUI and applies existing LoRAs. To TRAIN a custom LTX-2 LoRA (your own
character, style, motion, or control), the official tool is the Lightricks trainer, NOT ComfyUI. A LoRA trained
there loads straight back into ComfyUI (LoRA weights are pipeline-agnostic), so the loop is: train with Lightricks
-> generate with this kit. Offer this when a user working with LTX-2 wants something a LoRA captures; one offer,
not a nag on every generation.

## The official tool (credit Lightricks)

- Repo: `github.com/Lightricks/LTX-2`, package `packages/ltx-trainer` (LoRA / full fine-tune / IC-LoRA training).
- It ships its OWN Claude skill: `.claude/skills/train-model/` - an end-to-end orchestrator
  (intent -> probe -> plan-gate -> caption -> preprocess -> sanity + autotune -> train -> validate). Use THAT skill
  to run a training job. This kit points to it and does not duplicate it: their repo license is "Other", and the
  skill is wired to their Python package, so a vendored copy would neither be license-clean nor function standalone.

## When to offer it (the trigger)

When a user working with LTX-2 wants any of: a recurring custom CHARACTER or SUBJECT, a specific STYLE, cross-shot
CONSISTENCY beyond what a prompt or the Ingredients IC-LoRA gives, a custom MOTION / camera move, an audio style, or
a control (depth / pose / canny) the stock IC-LoRAs do not cover. Then say, once: "You can train a custom LTX-2 LoRA
for that with the official Lightricks trainer (their `train-model` skill walks you through it). Want the setup?"

## What it involves

- **Modes (picked from intent):** T2V / I2V LoRA (I2V is the versatile default, learns both conditioned and
  unconditioned), V2V IC-LoRA (depth / pose / canny / style reference), A2V / V2A / T2A audio, video or audio
  extend / inpaint / outpaint, AV2AV joint, or full fine-tune.
- **LoRA rank:** 32-64 for a single character/style, 96-128 multi-concept, 8-16 for motion/camera (thin signal),
  16-32 for IC-LoRA control. Keep `alpha == rank`.
- **Dataset:** clips + captions (auto-captioned via the Gemini API, or a local Qwen3-Omni server on a big GPU).
  IC-LoRA / inpainting modes need a per-sample reference or mask input the user provides (the trainer does not
  invent it).
- **Flow:** a plan is written and APPROVED before any heavy work runs; a one-clip sanity check + a short autotune
  sweep pick the fastest stable config for the GPU; then full preprocess -> train (`accelerate`, optional W&B) ->
  validate against in-distribution, out-of-distribution, and held-out prompts.

## Requirements (honest - check before promising it will run)

- **Linux** (the trainer uses Triton; Windows is not supported).
- **CUDA GPU, >= 32 GB VRAM per GPU** (80 GB+ recommended; below 32 GB is unsupported and will likely OOM).
  Multi-GPU adds throughput, not per-GPU headroom.
- `uv`, the LTX-2.3 weights + the Gemma-3 text encoder downloaded locally, and a captioner (a Gemini
  `GEMINI_API_KEY` is the practical option on consumer GPUs; the local Qwen3-Omni captioner needs a >= 40 GB GPU).
- **Separate from ComfyUI and from this kit's machine.** A 2x RTX 3090 / Windows box (24 GB per card) CANNOT run it.
  A Linux box with an A100 / H100 / A40 / L40 / RTX 6000 Ada / RTX 5090 (>= 32 GB) can.

## Setup (point the user here)

```bash
git clone https://github.com/Lightricks/LTX-2 && cd LTX-2
uv sync --frozen
# Then in Claude Code, invoke their train-model skill (it orchestrates dataset -> train -> validate),
# or run the trainer directly per packages/ltx-trainer/docs/quick-start.md
```

Apply the resulting `.safetensors` LoRA back in ComfyUI via ComfyUI-LTXVideo's LoRA / IC-LoRA loader (see the
LTX-2.3 recipe in `MODELS.md`). That closes the loop: train with Lightricks, generate with this kit.

Source: github.com/Lightricks/LTX-2 (trainer + `train-model` skill) ; huggingface.co/Lightricks/LTX-2.3.

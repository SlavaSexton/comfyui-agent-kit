# Example and shared workflows

The named template library (cloned by the installer) is the source of truth. Beyond it, these notable
community-shared ComfyHub workflows are worth grabbing on demand. Fetch any of them by hash:

```
python shared/tools/fetch_workflow.py <hash> <outdir>
# equivalently: GET https://comfy.org/workflows/download/<hash>.json
```

## Model shootouts (pick the best model before scaling up)

- **Image-edit comparison grid** — already IN the template library as `templates-all_in_one-image_edit_models`
  ("1 input and multiple editing model comparison"): one input image fans through 7 image-edit models side by side
  (Flux.2 Dev/Klein, GPT-Image-1.5, Grok, Nano Banana Pro, Qwen-Image-Edit, Seedream). No fetch needed.
- **Video backend comparison** — "Adjustment Frame" by doughogan, hash **`7dca0438edf4`**. Blocks a still, controls
  the camera angle, then rolls takes across **Grok / Kling / Veo / Seedance / Wan 2.2 / LTX-2** to compare side by
  side. `python shared/tools/fetch_workflow.py 7dca0438edf4 <outdir>`.

## Restoration / VFX

- **MotionDeblur** (LTX-2.3 IC-LoRA, by oumoumad) — KEY for restoration: reduces/removes motion blur and
  reconstructs sharper frames. Weights `ltx-2.3-22b-ic-lora-motiondeblur.safetensors` ->`models/loras`, run via the
  LTX-2.3 `ic_lora` workflow (needs the `ComfyUI-LTXVideo` pack). Source: huggingface.co/oumoumad/LTX-2.3-22b-IC-LoRA-MotionDeblur.
  Chain with the in-library `restore_archival_footage` / `remove_watermark` templates + SeedVR2 / SUPIR upscalers
  for a full restoration pass.
- **Sky Replacement** (WanVideo) — hash `537cf7f1f745`.
- **Face Swap** (WanVideo + pose) — hash `93f286fbc2c8`.
- **VFX Utilities** (SAM3 video segmentation / roto / masking) — hash `be0889296f65`.

## In-graph LLM

- **OpenRouter LLM** — already IN the template library as `api_openrouter_llm`. Any model
  (GPT / Claude / Gemini / GLM / Llama / Qwen) via one OpenRouter key, for in-graph prompt enrichment. See
  [NODES.md](NODES.md).

## Not fetchable (Comfy Cloud only)

`cloud.comfy.org/?share=<hash>` and `cloud.comfy.org/#<uuid>` are Comfy Cloud workspaces tied to an account; the
`comfy.org/workflows/download/<hash>.json` pattern returns **404** for them (verified). To get the JSON, open the
link in Comfy Cloud while logged in and export from the canvas (Workflow -> Export).

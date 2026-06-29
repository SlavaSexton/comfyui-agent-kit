# kijai ecosystem (ComfyUI mega-brain)

kijai is the most prolific ComfyUI wrapper/node author. This is a dated map of his repos, read live from github.com/kijai on 2026-06-24. Tools are split active vs legacy by last-commit date, with a supersede map for the old ones and a per-task picker. 62 repos covered (12 flagship deep cards, 22 active deep cards, 28 legacy light cards).

When a card marked a claim inferred (not read from code/runtime), it stays marked inferred here. "Runs on current ComfyUI" without a runtime note means "no open issue reports a core break," not a live boot.

## Pick a tool by task

Active tools only. Pick the current path first; the wrappers exist mainly for models not yet in ComfyUI core.

| Task | Best current kijai tool(s) | Why |
| --- | --- | --- |
| text-to-video | ComfyUI-WanVideoWrapper (or ComfyUI core Wan) | Wan 2.1/2.2 plus ~30 model families; author says use core for vanilla Wan, wrapper for new models (VACE, FlashVSR, WanAnimate, Ovi) |
| image-to-video | ComfyUI-WanVideoWrapper, ComfyUI-FramePackWrapper | Wan I2V via clip-vision + VAE encode; FramePack does anti-drift long I2V on a HunyuanVideo transformer |
| video-to-video | ComfyUI-WanVideoWrapper | feed encoded latents into the sampler with denoise_strength < 1 |
| upscale / restore | ComfyUI-SUPIR (legacy, but the maintained route is ComfyUI core SUPIR, PR #13250) | SDXL img2img + ControlNet photo restoration; modular v2 node chain |
| caption / VLM | ComfyUI-Florence2 | Florence-2 captioning, detection, OCR, segmentation; native model rewrite removed the transformers-version breakage |
| depth | ComfyUI-DepthAnythingV2, ComfyUI-Marigold, ComfyUI-MoGe | DAv2 fast monocular depth; Marigold diffusion depth + normals + intrinsics; MoGe depth plus a 3D mesh |
| normals / geometry | ComfyUI-Marigold, ComfyUI-StableXWrapper, ComfyUI-MoGe, ComfyUI-Sapiens2 | Marigold/StableX normals; MoGe pointmap mesh; Sapiens2 human normals + 3D pointmap GLB |
| segmentation | ComfyUI-segment-anything-2 | SAM2 / SAM2.1 point, bbox, Florence2, and automatic-mask image + video segmentation |
| 3D | ComfyUI-Hunyuan3DWrapper, ComfyUI-MoGe, ComfyUI-Sapiens2 | image-to-textured-mesh (Hunyuan3D 2.0/2.1); MoGe single-image mesh; Sapiens2 human pointmap GLB |
| relighting | ComfyUI-IC-Light (SD1.5), ComfyUI-LBMWrapper (experimental) | IC-Light relights SD1.5 by a light source or background; LBM flow-matching relight |
| frame interpolation | ComfyUI-GIMM-VFI (experimental) | implicit-motion interpolation; note hard cupy-cuda12x dep blocks CUDA 13 / RTX 5090 |
| audio | ComfyUI-MMAudio (experimental), ComfyUI-MelBandRoFormer | MMAudio video-to-audio / text-to-audio; MelBand splits vocals vs instruments |
| LoRA training | ComfyUI-FluxTrainer (legacy, broken on current ComfyUI) | FLUX/SDXL/SD3 LoRA + finetune via kohya in a node graph; see "disable or avoid" |
| pose / character animation | ComfyUI-WanAnimatePreprocess, ComfyUI-SCAIL-Pose, ComfyUI-Sapiens2 | ViTPose wholebody keypoints for WanAnimate; SCAIL 3D NLF pose; Sapiens2 308-keypoint pose |
| prompt / utility | ComfyUI-KJNodes, ComfyUI-PromptRelay, ComfyUI-MemoryVisualization | KJNodes is the ~244-node utility pack; PromptRelay does temporal per-segment prompts; MemoryVisualization is a VRAM panel |

## Supersede map (old to better)

Every legacy/superseded card with a known replacement. "(inferred)" marks ecosystem inference, not a repo statement.

| Legacy tool | Use instead | Why |
| --- | --- | --- |
| ComfyUI-HunyuanVideoWrapper | ComfyUI native HunyuanVideo (+ HunyuanLoom, Comfy-WaveSpeed, KJNodes) | author sunset the wrapper once native landed; redirects in its README |
| ComfyUI-SUPIR | ComfyUI core SUPIR (PR #13250) | README marks "FINAL update," bugfixes only |
| ComfyUI-CogVideoXWrapper | ComfyUI-WanVideoWrapper, HunyuanVideo, LTX-Video (inferred) | CogVideoX overtaken; kijai's video work moved to Wan |
| ComfyUI-FluxTrainer | standalone kohya sd-scripts, ai-toolkit, SimpleTuner (inferred) | stale ~14 months, import break on current transformers |
| ComfyUI-DynamiCrafterWrapper | ComfyUI-WanVideoWrapper, ComfyUI-HunyuanVideoWrapper (inferred) | DynamiCrafter models are 2023-era; no in-repo deprecation note |
| ComfyUI-MimicMotionWrapper | (no drop-in; Champ / AnimateAnyone wrappers cover similar use) | dormant since 2025-01-12 |
| ComfyUI-LLaVA-OneVision | ComfyUI-Florence2, ComfyUI-LLM-Party (inferred) | fails to load on current ComfyUI |
| ComfyUI-Lotus | ComfyUI-DepthAnythingV2, ComfyUI-Marigold (different models, inferred) | breaks on ComfyUI 0.3.65+ (get_full_path_or_raise) |
| ComfyUI-LivePortraitKJ | KwaiVGI/LivePortrait or ComfyUI Manager face-animation nodes | dormant since 2024-08 |
| ComfyUI-MochiWrapper | LTX, CogVideoX, Hunyuan, or newer video models | dormant since 2024-11 |
| ComfyUI-KwaiKolorsWrapper | native Kolors integration via ComfyUI Manager | standalone diffusers wrapper no longer needed |
| ComfyUI-ADMotionDirector | ComfyUI-AnimateDiff-Evolved (inference); modern AnimateDiff for training | stale since 2024-11 |
| ComfyUI-LVCDWrapper | LTX-Video, I2V wrappers, AnimateAnyone, Wan | legacy |
| ComfyUI-EasyAnimateWrapper | (no named replacement) | stale |
| ComfyUI-LuminaWrapper | FLUX or SD 3.5 integrations | abandoned since 2024-06 |
| ComfyUI-OpenDiTWrapper | LTX-Video, HunyuanVideo, or upstream OpenDiT | legacy/incomplete |
| ComfyUI-DiffSynthWrapper | modelscope/DiffSynth-Studio upstream (no active wrapper) | stalled since 2024-06 |
| ComfyUI-BrushNet-Wrapper | nullquant/ComfyUI-BrushNet (native) | maintainer recommends the native pack |
| ComfyUI-DiffusersSD3Wrapper | diffusers native controlnet_sd3 pipeline | integrated upstream |
| ComfyUI-SVD | ComfyUI built-in video/SVD support | superseded by core |
| ComfyUI-IC-Light-Wrapper | ComfyUI-IC-Light (kijai, native) | native implementation replaced the wrapper |
| ComfyUI-LaVi-Bridge-Wrapper | LTX-Video, Mochi, newer text-to-video | legacy |
| ComfyUI-ELLA-wrapper | TencentQQGYLab/ComfyUI-ELLA | explicitly superseded |
| ComfyUI-DiffusionLight | (no named replacement) | stale since 2024-04 |
| ComfyUI-APISR-KJ | Real-ESRGAN, BSRGAN, or diffusion upscalers | unmaintained since 2024-04 |
| ComfyUI-DDColor | grayscale colorization via the maintained fork hay86/ComfyUI_DDColor | art-venture does color-grading, not ML colorization |
| ComfyUI-llama-cpp | modern ComfyUI LLM nodes / comfyui-agent-kit | legacy |
| ComfyUI-DiffusersStableCascade | native ComfyUI StableCascade nodes | built into core as of 2024 |

## Active tools (2025-2026)

### Video

#### ComfyUI-WanVideoWrapper  -  last commit 2026-05-24, Apache-2.0, active
- Sandbox wrapper running Wan 2.1/2.2 plus ~30 model families (VACE, Fun, SkyReels, Phantom, MultiTalk, WanAnimate, Ovi, FlashVSR) for T2V/I2V/V2V, with heavy VRAM management. ~57 registered nodes; many specialized embeds nodes are inferred from the mapping, not read class-by-class.
- **Nodes:** `WanVideoModelLoader` loads the transformer (fp8 quant, block swap, compile) -> WANVIDEOMODEL; `WanVideoVAELoader` -> WANVAE; `LoadWanVideoT5TextEncoder` -> WANTEXTENCODER; `WanVideoTextEncode` (pos+neg) -> WANVIDEOTEXTEMBEDS; `WanVideoTextEmbedBridge` brings native conditioning in; `WanVideoEmptyEmbeds` (w/h/frames) -> image_embeds for T2V; `WanVideoClipVisionEncode` + `WanVideoImageToVideoEncode` build I2V image_embeds; `WanVideoEncode` -> LATENT for V2V; `WanVideoSampler` (model + image_embeds + text_embeds) -> LATENT; `WanVideoDecode` (+ tiled VAE) -> IMAGE; `WanVideoBlockSwap` -> BLOCKSWAPARGS; `WanVideoTorchCompileSettings` -> WANCOMPILEARGS; `WanVideoLoraSelect` (chainable) -> WANVIDLORA; `WanVideoContextOptions` for long video; plus VACE/Phantom/Animate/Fun *Embeds and an Add* latent chain (+30 more nodes, mostly inferred).
- **Use:** T2V: ModelLoader -> Sampler, text via T5 encoder -> TextEncode -> text_embeds, frame size via EmptyEmbeds -> image_embeds, Sampler -> Decode -> VHS_VideoCombine. I2V: image_embeds come from ClipVisionEncode -> ImageToVideoEncode. V2V: WanVideoEncode latents into the sampler's samples with denoise_strength < 1. VRAM args (BlockSwap/Compile/VRAMManagement) wire into the loader; fp8 chosen on the loader.
- **Compat / watch out:** deps ftfy, accelerate, diffusers>=0.33, peft>=0.17, sentencepiece, gguf, opencv, scipy. fp8 _fast modes need CUDA cc >= 8.9 (RTX 4000+). Open breakage: merge_lora crash in WanVideoLoraSelectMulti on ComfyUI >= 0.16.0 (2026-06-14); I2V fails on AMD ROCm "Boolean value of Tensor" on v1.4.7 + HEAD (2026-06-23). Windows torch.compile first-run VRAM spikes from stale Triton caches.

#### ComfyUI-FramePackWrapper  -  last commit 2026-01-13, Apache-2.0, active
- Wrapper for lllyasviel FramePack: anti-drift long image-to-video on a HunyuanVideo-based packed transformer, driven by native ComfyUI text encoders / VAE / sigCLIP. README marks "WORK IN PROGRESS."
- **Nodes:** `DownloadAndLoadFramePackModel` / `LoadFramePackModel` (fp8, LoRA fuse) -> FramePackMODEL; `FramePackLoraSelect` (chainable) -> FPLORA; `FramePackTorchCompileSettings` -> FRAMEPACKCOMPILEARGS; `FramePackFindNearestBucket` (image -> w/h); `FramePackSampler` (model + pos/neg + start_latent, optional end_latent + image_embeds) -> LATENT; `FramePackSingleFrameSampler` (Kisekaeichi style-transfer, single frame).
- **Use:** native nodes supply conditioning (DualCLIPLoader -> CLIPTextEncode, ConditioningZeroOut for negative), VAEEncode -> start_latent, CLIPVisionEncode -> image_embeds; all feed FramePackSampler -> LATENT -> VAEDecodeTiled -> VHS_VideoCombine. Provides no text/VAE/clip-vision nodes of its own.
- **Compat / watch out:** deps accelerate>=1.6, diffusers>=0.33.1, transformers>=4.46.2, einops, safetensors; opencv-python is used but missing from requirements (open PR). fp8 needs Ada/Hopper. No open issue reports a current-ComfyUI break; open items are F1-support and Hunyuan-LoRA PRs (F1 not in main).

#### ComfyUI-WanAnimatePreprocess  -  last commit 2026-05-27, Apache-2.0, active
- Preprocessing for Wan 2.2 Animate: ViTPose (ONNX) + YOLOv10 wholebody keypoints and face crops -> POSEDATA for the WanAnimate-14B pipeline.
- **Nodes:** `OnnxDetectionModelLoader` (vitpose + yolo ONNX) -> POSEMODEL; `PoseAndFaceDetection` -> POSEDATA, face_images, keypoint JSON, bboxes; `DrawViTPose` (POSEDATA -> stick-figure IMAGE); `PoseRetargetPromptHelper` (POSEDATA -> two prompts for Flux Kontext retargeting); `PoseDetectionOneToAllAnimation` (DWPose-format, ref alignment).
- **Use:** OnnxDetectionModelLoader -> PoseAndFaceDetection (video frames + target w/h) -> POSEDATA -> DrawViTPose -> pose_images, fed downstream to WanAnimate-14B sampler nodes (not in this repo).
- **Compat / watch out:** deps onnxruntime-gpu, onnx, opencv-python; ONNX models go to models/detection. Open breakage: NumPy 2.x fails ONNX load ("built for NumPy 1.x"); ONNX files not in dropdown on ComfyUI 0.22.0; 720p fails on RTX 5090.

#### ComfyUI-PromptRelay  -  last commit 2026-05-20, no license, experimental
- Temporal prompt segmentation for Wan and LTX: assigns different prompts to different time segments of a latent video and patches cross-attention to enforce the boundaries.
- **Nodes:** `PromptRelayEncode` (model + clip + latent + global/local prompts + segment_lengths) -> patched MODEL + CONDITIONING; `PromptRelayEncodeTimeline` (same, with a JS timeline editor); `PromptRelaySmartEncode` (inline `[start-end]` / block-header syntax); `PromptRelaySmartEncodeTest` (dry-run debug string); `PromptRelayAdvancedOptions` -> RELAY_OPTIONS (per-stream video/audio tuning).
- **Use:** build an empty latent video -> PromptRelayEncode (global anchor prompt + pipe-separated local prompts) -> patched model + positive into KSampler -> VAE decode. Timeline variant auto-populates segments from the UI.
- **Compat / watch out:** dep word2number (optional). Uses comfy_api.latest, so needs recent ComfyUI (not the legacy comfy_extras era). Open breakage: sampling hangs at 0/N with LTX-2.3 on ComfyUI v0.23.0 / Windows (works on 0.22.0). No LTX 2.1 or Wan 2.2 support yet.

#### ComfyUI-GIMM-VFI  -  last commit 2025-07-31, NOASSERTION, experimental
- Frame interpolation via GIMM-VFI implicit motion model with RAFT or FlowFormer flow guidance.
- **Nodes:** `DownloadAndLoadGIMMVFIModel` (_r=RAFT, _f=FlowFormer) -> GIMMVIF_MODEL; `GIMMVFI_interpolate` (image batch + interpolation_factor) -> interpolated IMAGE sequence (+ optional flow visualizations).
- **Use:** loader -> GIMMVFI_interpolate (interpolation_factor=8 for slow-mo) -> video encoder. No example workflow ships.
- **Compat / watch out:** hard dep cupy-cuda12x>=13.3.0 (CUDA 12 only; CUDA 13 / RTX 5090 cannot install without a workaround). CUDA GPU mandatory, no CPU path. Open: timm import break (2026-03-15), cupy.memoize AttributeError; both are active blockers on current installs.

#### ComfyUI-VideoColorGrading  -  last commit 2026-04-08, no license, experimental
- AI-generated 3D color LUTs for video: learns color style from a reference image and applies it (ICCV 2025 "Video Color Grading via LUT Generation" paper).
- **Nodes:** `VCGLoadModel` (combined CLIP + VAE + ReferenceNet + L-Diffuser ckpt) -> VCG_PIPELINE; `VCGGenerateLUT` (reference + source frames, DDIM) -> preprocessed_frames IMAGE + VCG_LUT; `VCGApplyLUT` (trilinear grid_sample, strength blend) -> IMAGE.
- **Use:** VHS_LoadVideo + LoadImage (reference) -> VCGLoadModel -> VCGGenerateLUT -> VCGApplyLUT (feed the preprocessed_frames, not raw source) -> VHS_VideoCombine. Drop strength to 0.7-0.9 if oversaturated.
- **Compat / watch out:** uses comfy_api.latest (recent ComfyUI only). Checkpoint from Kijai/VCG_comfy. VHS is a soft dep for video I/O. No open compat-break issues; only a color-intensity feature request.

#### ComfyUI-VideoNoiseWarp  -  last commit 2025-03-30, no license, experimental
- Motion-consistent warped noise from a video via RAFT optical flow, shaped for video diffusion (CogVideoX, HunyuanVideo, AnimateDiff). README marks "WORK IN PROGRESS."
- **Nodes:** `GetWarpedNoiseFromVideo` (general, all latent shapes) -> noise LATENT + visualization + flow IMAGE; `GetWarpedNoiseFromVideoAnimateDiff` (4ch BCHW); `GetWarpedNoiseFromVideoCogVideoX` (16ch BCTHW); `GetWarpedNoiseFromVideoHunyuan` (16ch BTCHW).
- **Use:** load reference video frames -> the matching variant (set num_frames, tune degradation 0..1) -> noise LATENT fed into a CogVideoX or AnimateDiff sampler as the initial noise. Visualization and flow outputs are diagnostic.
- **Compat / watch out:** dep einops; uses comfy built-ins + RAFT (auto-downloaded). No crash reports in open issues; feature requests for SkyReels/Cosmos suggest no updates for newer models since mid-2025.

#### ComfyUI-FollowYourEmojiWrapper  -  last commit 2025-04-18, no license, experimental
- FollowYourEmoji: animate a reference portrait from a source video's facial motion via MediaPipe landmarks and a SD1.5-based video diffusion pipeline. README marks "WORK IN PROGRESS."
- **Nodes:** `DownloadAndLoadFYEModel` -> FYEPIPE + CLIP_VISION; `FYECLIPEncode` -> FYECLIPEMBED; `FYEClipEmbedToComfy` / `FYELandmarkToComfy` (use native KSampler instead of FYESampler); `FYELandmarkEncode` -> LMKFEAT; `FYEMediaPipe` (landmark mesh + FACERESULTS); `FYESampler` / `FYESamplerLong` -> LATENT.
- **Use:** ref portrait -> VAEEncode -> ref_latent; driving video -> FYEMediaPipe -> FYELandmarkEncode -> LMKFEAT; DownloadAndLoadFYEModel + FYECLIPEncode -> FYESampler -> LATENT -> VAEDecode -> VHS_VideoCombine. Cross-identity: run FYEMediaPipe on the portrait first for FACERESULTS, pass as align_to_face_results.
- **Compat / watch out:** deps huggingface_hub, pillow, opencv, mediapipe, transformers, einops, omegaconf. Open breakage: `is_accelerate_available is not defined` scoping bug; `loadmodel() got unexpected kwarg motion_model` (API break). Not updated since 2025-04-18; likely needs manual fixes on current ComfyUI.

### Image / upscale

#### ComfyUI-SUPIR  -  last commit 2026-04-29, NOASSERTION (non-commercial), legacy
- SUPIR photo-realistic restoration/upscaler (SDXL img2img + custom ControlNet) as modular nodes. Superseded by ComfyUI core SUPIR (PR #13250); README is "FINAL update, bugfixes only." License is non-commercial (XPixel / Dr. Jinjin Gu).
- **Nodes:** `SUPIR_model_loader_v2` (SDXL MODEL+CLIP+VAE + SUPIR ckpt, LoRA-capable) -> SUPIRMODEL + SUPIRVAE; `SUPIR_model_loader_v2_clip` (separate clip_l/clip_g); `SUPIR_model_loader` (legacy, no LoRA); `SUPIR_encode` (image -> latent); `SUPIR_first_stage` (denoise-encoder preprocess); `SUPIR_conditioner` (model + latent + prompts, optional captions) -> pos/neg; `SUPIR_sample` (EDM/DPM++ restore samplers, tiled) -> latent; `SUPIR_decode` -> IMAGE; `SUPIR_Upscale` (legacy all-in-one).
- **Use:** CheckpointLoaderSimple (SDXL) + SUPIR ckpt -> SUPIR_model_loader_v2 -> SUPIR_encode -> [SUPIR_first_stage] -> SUPIR_conditioner -> SUPIR_sample -> SUPIR_decode -> image. Size the input image before encode (scale_by lives in the legacy node only).
- **Compat / watch out:** deps transformers, open-clip-torch, pytorch-lightning, omegaconf, accelerate. Needs a SUPIR ckpt (v0Q/v0F) + an SDXL ckpt in models/checkpoints. VRAM scales with resolution; fp8 on the VAE causes artifacts (use tiled_vae). Open: meta-tensor copy error, v2 loader fails to pull CLIP from some SDXL ckpts, and Blackwell (RTX 50-series) memory_efficient_attention op missing.

#### ComfyUI-IC-Light  -  last commit 2025-05-30, Apache-2.0, active
- Native SD1.5 relighting: patches the UNet with IC-Light delta weights, relights from a text prompt plus a light source (FC) or background (FBC). SD1.5 only (hard-raises otherwise).
- **Nodes:** `LoadAndApplyICLightUnet` (patches SD1.5 MODEL with the IC-Light UNet) -> MODEL; `ICLightConditioning` (pos/neg + vae + foreground[+background] latent) -> pos/neg/empty_latent; `LightSource` (8 gradient light positions) -> IMAGE; `CalculateNormalsFromImages` (multi-light -> normal map); `LoadHDRImage`; `BackgroundScaler`; `DetailTransfer` (restore texture post-relight).
- **Use:** Load SD1.5 -> LoadAndApplyICLightUnet (iclight_sd15_fc UNet in models/unet) -> VAE-encode subject to foreground; LightSource -> VAE encode -> ICLightConditioning -> KSampler with the patched model -> VAE Decode. FBC mode uses iclight_sd15_fbc with the background latent in opt_background.
- **Compat / watch out:** single dep opencv-python. Models not bundled (download lllyasviel SD15 IC-Light into models/unet). Some examples need ComfyUI-KJNodes. No maintainer-acknowledged core regression; recurring real failures are a non-SD1.5 base model or channel-count mismatch (mat1/mat2, 9-vs-8 channels). Runtime patch path on today's ComfyUI is inferred, not re-run.

#### ComfyUI-StableXWrapper  -  last commit 2025-01-31, license unconfirmed, experimental
- Stable-X normal-map estimation (StableNormal) and image delighting (StableDelight) via YOSO diffusion.
- **Nodes:** `DownloadAndLoadStableXModel` (yoso-normal-v1-8-1 or yoso-delight-v0-4-base) -> YOSOPIPE; `StableXProcessImage` (pipeline + image, processing_resolution, controlnet_strength) -> IMAGE; `DifferenceExtractorNode` (original vs processed -> amplified diff mask).
- **Use:** DownloadAndLoadStableXModel -> StableXProcessImage (normal map or delighted image); optionally DifferenceExtractorNode to isolate what delight removed. Example runs normal + delight pipes in parallel.
- **Compat / watch out:** deps accelerate, diffusers>=0.28, Pillow. Models auto-download to models/diffusers. No open issues as of 2026-06-24 (one closed install-cache "missing node"). DifferenceExtractorNode CATEGORY has a cosmetic typo.

#### ComfyUI-LBMWrapper  -  last commit 2025-05-14, CC-BY-NC-4.0, experimental
- Latent Bridge Matching relighting (single image) via a UNet flow-matching model (jasperai/LBM_relighting).
- **Nodes:** `LoadLBMModel` (from models/diffusion_models, precision/device) -> LBM_MODEL; `LBMSampler` (model + image, steps) -> relit IMAGE.
- **Use:** place model.safetensors (the only weight at jasperai/LBM_relighting) in models/diffusion_models -> LoadLBMModel -> LBMSampler (steps ~20) -> Preview/Save. Example composites foreground on a new background before relighting.
- **Compat / watch out:** deps diffusers, accelerate. Open breakage: import fails on ComfyUI 0.3.39; `set_timesteps() got unexpected kwarg sigmas` on newer diffusers (2025-06-20); bf16 mismatch on cards without native bf16 (2080 Ti); sampler stuck for some. Not updated since 2025-05-14; likely fails on current ComfyUI + recent diffusers.

#### ComfyUI-HFRemoteVae  -  last commit 2026-05-08, no license, experimental
- Routes latent decoding to HuggingFace-hosted remote VAE endpoints (SD / SDXL / Flux / HunyuanVideo) so you decode without a local VAE.
- **Nodes:** `HFRemoteVAEDecode` (LATENT + VAE_type) -> IMAGE; `HFRemoteVAE` (VAE_type -> a decode-only VAE proxy socket).
- **Use:** sampler LATENT -> HFRemoteVAEDecode (pick matching VAE_type) -> SaveImage. No local VAE loaded; the latent is POSTed to a hardcoded HF endpoint.
- **Compat / watch out:** dep diffusers. Works only while the HF endpoints are live; open issue reports 503s ("HFRemoteVae down?"). No Wan 2.1 support. No license (cannot legally redistribute/modify). Python 3.10 support unconfirmed.

#### ComfyUI-TexturePacker  -  last commit 2025-02-03, no license, legacy
- Packs a batch of IMAGE tensors into a single texture atlas via PyTexturePacker (bundled).
- **Nodes:** `PackImagesToAtlas` (image batch, max_rects/guillotine, padding/rotation options, optional mask) -> atlas IMAGE + MASK.
- **Use:** Load Image (batch) -> PackImagesToAtlas -> Save Image. No example workflows.
- **Compat / watch out:** no requirements.txt; runtime deps torch/torchvision/Pillow are standard. Zero open issues, but a single-commit repo (2025-02-03) with no maintenance, so forward compatibility is unverified.

### Vision / caption

#### ComfyUI-Florence2  -  last commit 2026-05-06, MIT, active
- Microsoft Florence-2 for captioning, detection, region/dense captioning, referring-expression segmentation, OCR, DocVQA, and PromptGen tags.
- **Nodes:** `DownloadAndLoadFlorence2Model` (14 baked-in repos incl. base/large, DocVQA, CogFlorence, PromptGen) -> FL2MODEL; `DownloadAndLoadFlorence2Lora` -> PEFTLORA; `Florence2ModelLoader` (load from models/LLM, no download) -> FL2MODEL; `Florence2Run` (image + FL2MODEL + one of 15 tasks) -> annotated IMAGE, MASK, caption STRING, JSON data.
- **Use:** loader -> FL2MODEL -> Florence2Run with image + task -> caption / mask / bbox JSON. text_input is valid only for referring_expression_segmentation, caption_to_phrase_grounding, docvqa. No example workflow ships (wiring inferred from port types).
- **Compat / watch out:** deps tokenizers, matplotlib, pillow. A native-model rewrite removed the HF transformers dependency, so the model no longer needs a specific transformers version (most older transformers-version open issues should be obsoleted by it; not re-tested here). README's "transformers 4.38 minimum" line is stale.

#### ComfyUI-Sapiens2  -  last commit 2026-04-29, no SPDX (models under Sapiens2 License), active
- Meta Sapiens2 for human body-part segmentation, surface normals, 3D pointmap-to-GLB, and 308-keypoint pose.
- **Nodes:** `Sapiens2Loader` (typed by task tag) -> SAPIENS2_MODEL; `Sapiens2Normal` -> normal IMAGE; `Sapiens2Seg` -> class_id_mask + colored IMAGE; `Sapiens2SegExtract` (named body-part -> MASK); `Sapiens2Pointmap` -> GLB; `Sapiens2Pose` (openpose or raw_308) -> POSE_KEYPOINT; `Sapiens2DrawPose` -> IMAGE.
- **Use:** Loader (task ckpt) -> the matching inference node. Pose openpose output feeds ControlNet OpenPose directly; for 3D mesh, build a foreground mask via Sapiens2Seg + Sapiens2SegExtract(Background, invert) before Sapiens2Pointmap.
- **Compat / watch out:** no declared Python deps (uses ComfyUI's torch/numpy; opencv optional). Uses comfy_api.latest + ComfyExtension async registration, so it will NOT load on legacy ComfyUI builds. Open: no license file; pointmap GLB head mesh is incomplete.

#### ComfyUI-SCAIL-Pose  -  last commit 2026-04-15, no license, experimental
- SCAIL-Pose: 3D NLF pose estimation from images/video with optional VitPose face/hand detection, producing DWPose-format keypoints for WanVideoWrapper / SCAIL video gen.
- **Nodes:** `NLFModelLoader` (from models/nlf) -> NLF_MODEL; `NLFPredictPoses` -> NLFPRED + BBOX; `RenderNLFPoses` (taichi or torch backend) -> IMAGE + MASK; `PoseDetectionVitPoseToDWPose` (needs POSEMODEL from WanAnimatePreprocess) -> DWPOSES; `ConvertOpenPoseKeypointsToDWPose`; `SaveNLFPosesAs3D` (-> GLB).
- **Use:** VHS_LoadVideo -> NLFModelLoader -> NLFPredictPoses -> RenderNLFPoses -> pose IMAGE into WanVideoWrapper SCAIL pipeline. Optional VitPose path adds face/hand detail.
- **Compat / watch out:** deps taichi>=1.7.4, opencv-python, pillow, safetensors. Needs ComfyUI-WanAnimatePreprocess (POSEMODEL type) and the NLF checkpoint in models/nlf. Open breakage: Taichi crashes the ComfyUI process (workaround render_backend='torch'); IndexError when only one hand is visible. Partially supersedes WanVideoWrapper's NLF nodes with local model loading (inferred, no explicit deprecation).

### Depth / geometry

#### ComfyUI-DepthAnythingV2  -  last commit 2026-03-06, no license (missing LICENSE file), active
- Two-node Depth Anything V2 monocular depth: load a DAv2 ckpt, run an IMAGE batch, get a normalized grayscale depth-map IMAGE.
- **Nodes:** `DownloadAndLoadDepthAnythingV2Model` (9 fixed filenames, vits/vitb/vitl/vitg, relative + metric variants) -> DAMODEL; `DepthAnything_V2` (DAMODEL + image batch) -> 3-channel grayscale depth IMAGE (0..1, near=bright; metric models are inverted).
- **Use:** Load Image -> DownloadAndLoadDepthAnythingV2Model -> DepthAnything_V2 -> depth map -> Preview or ControlNet (depth). Pick vitl_fp32 for quality (node warns fp16 hurts quality a lot). Batches/video loop frame-by-frame.
- **Compat / watch out:** deps huggingface_hub, accelerate; relies on torchvision + current comfy.utils. Known limitation: download path is hardcoded, so extra_model_paths.yaml is ignored (open issue). Apple Silicon fp16 variants unstable (use fp32). No hard core break reported.

#### ComfyUI-Marigold  -  last commit 2025-05-16, GPL-3.0, active
- Marigold diffusion depth and normals, with a legacy custom-pipeline path (v1) and a modern diffusers-native path (v2) that adds normals and intrinsic decomposition.
- **Nodes:** `MarigoldModelLoader` (11 prs-eth/GonzaloMG depth/normals/intrinsics repos) -> MARIGOLDMODEL; `MarigoldDepthEstimation_v2` (+ TAESD VAE) -> depth/normals IMAGE; `MarigoldDepthEstimation_v2_video` (temporal blend); `MarigoldDepthEstimation` (legacy v1); `MarigoldDepthEstimationVideo` (legacy v1 + optical flow); `ColorizeDepthmap`; `RemapDepth`; `SaveImageOpenEXR`.
- **Use:** LoadImage -> MarigoldModelLoader (pick marigold-depth-lcm for speed) -> MarigoldDepthEstimation_v2 -> depth IMAGE -> ColorizeDepthmap / RemapDepth / SaveImageOpenEXR. Video uses the _v2_video node with blend_factor.
- **Compat / watch out:** deps accelerate, diffusers>=0.33 (v2 raises if <0.28), torch>=2.0.1, transformers, matplotlib, scipy, huggingface-hub. No core API breakage in open issues; the protobuf-import issue is a user-env conflict, not a repo bug. v1 nodes still work but v2 is the recommended path.

#### ComfyUI-MoGe  -  last commit 2025-02-07, license unknown, active
- Microsoft MoGe monocular geometry: single image -> colorized depth map + textured 3D mesh (GLB/PLY) via a ViT-L model.
- **Nodes:** `DownloadAndLoadMoGeModel` (MoGe_ViT_L fp16/fp32) -> MOGEMODEL; `MoGeProcess` (image + model) -> depth IMAGE + GLB path STRING + TRIMESH.
- **Use:** loader -> MoGeProcess -> depth IMAGE + GLB path + TRIMESH for downstream 3D nodes. save_format='none' skips disk write and uses only the in-graph TRIMESH.
- **Compat / watch out:** deps trimesh, pillow, scipy, numpy, huggingface_hub, opencv-python (accelerate optional). No open breakage on current ComfyUI; open items are MoGe-2 support and panorama inference, plus a misnamed output socket. Not yet on the Comfy Registry.

### Segmentation

#### ComfyUI-segment-anything-2  -  last commit 2025-09-28, Apache-2.0, active
- Meta SAM2 / SAM2.1 for point, bbox, Florence2, and automatic-mask image and video segmentation.
- **Nodes:** `DownloadAndLoadSAM2Model` (sam2/sam2.1 hiera tiny..large; segmentor single_image/video/automaskgenerator) -> SAM2MODEL; `Sam2Segmentation` (points/bboxes/mask -> MASK); `Florence2toCoordinates` (Florence2 JSON -> coords + BBOX); `Sam2AutoSegmentation` (grid-prompt, full AMG surface) -> MASK + colored IMAGE + BBOX; `Sam2VideoSegmentationAddPoints` (stateful, chainable) -> SAM2INFERENCESTATE; `Sam2VideoSegmentation` (propagate) -> MASK stack.
- **Use:** Florence2-driven: LoadImage -> Florence2Run -> Florence2toCoordinates -> Sam2Segmentation (single_image) -> MASK. Video: load model with segmentor=video, chain Sam2VideoSegmentationAddPoints per object/frame -> Sam2VideoSegmentation. The load-time segmentor MUST match the node (each raises ValueError on mismatch).
- **Compat / watch out:** no requirements.txt, dependencies=[] (uses ComfyUI torch + PyYAML + huggingface_hub); SAM2 lib vendored, mask post-processing disabled to avoid the CUDA build. Auto-downloads to models/sam2. Open: AMD/ROCm segfaults, no offline fallback merged, bbox-branch UnboundLocalError, "no device attribute" inside Wan2.2 animate. No blanket break on a standard CUDA install.

### 3D

#### ComfyUI-Hunyuan3DWrapper  -  last commit 2026-03-16, NOASSERTION (Tencent community license, excludes EU/UK/South Korea), active
- Tencent Hunyuan3D-2 (and 2.1): single image -> textured 3D mesh (image -> shape latents -> VAE-decoded mesh, then optional multiview paint/delight/bake for PBR), plus mesh post-processing and GLB/OBJ export. ~36 nodes; ~22 have class+RETURN confirmed but full inputs summarized.
- **Nodes:** `Hy3DModelLoader` -> HY3DMODEL + HY3DVAE; `Hy3D_2_1SimpleMeshGen` (one-node 2.1 shape); `Hy3DGenerateMesh` -> HY3DLATENT; `Hy3DVAEDecode` (marching cubes) -> TRIMESH; `Hy3DMeshUVWrap`; `Hy3DRenderMultiView` -> normal/position maps + MESHRENDER; `DownloadAndLoadHy3DPaintModel` + `Hy3DSampleMultiView` -> multiview color; `Hy3DBakeFromMultiview` -> texture; `Hy3DApplyTexture`; `Hy3DPostprocessMesh`; `Hy3DExportMesh` (glb/obj/ply/stl); `TrimeshToMESH` / `MESHToTrimesh` (bridge to native MESH) (+ many mesh/PBR/render helpers).
- **Use:** shape-only: LoadImage -> remove bg -> Hy3DModelLoader -> Hy3DGenerateMesh -> Hy3DVAEDecode -> Hy3DPostprocessMesh -> Hy3DExportMesh. Textured: add Hy3DMeshUVWrap -> Hy3DRenderMultiView -> Hy3DSampleMultiView (paint model + delighted ref + camera config) -> Hy3DBakeFromMultiview -> Hy3DApplyTexture -> export. The MESHRENDER and camera config must be shared across render/sample/bake/apply.
- **Compat / watch out:** targets Win 11 + Python 3.12 + CUDA 12.6, torch 2.5-2.6; texture gen REQUIRES compiling custom_rasterizer (wheel for win/py3.12) plus a mesh_processor .pyd. Open breakage is almost all native-compile: custom_rasterizer fails on torch 2.9.1+cu130, no wheel for Blackwell RTX 50-series or ROCm RDNA4, utils3d API drift. Python node logic is fine; the C++/CUDA build is the friction.

### Audio

#### ComfyUI-MMAudio  -  last commit 2026-02-01, MIT, experimental
- MMAudio (hkchengrex) generating synchronized audio from video frames and/or text via flow-matching.
- **Nodes:** `MMAudioModelLoader` (small/large) -> MMAUDIO_MODEL; `MMAudioFeatureUtilsLoader` (VAE + Synchformer + CLIP, 16k/44k) -> MMAUDIO_FEATUREUTILS; `MMAudioSampler` (optional IMAGE frames + prompt) -> AUDIO; `MMAudioVoCoderLoader` (16k mode; returns a path string, looks like a broken stub).
- **Use:** VHS_LoadVideo -> MMAudioModelLoader + MMAudioFeatureUtilsLoader -> MMAudioSampler (+ frames + prompt) -> AUDIO -> PreviewAudio or mux via VHS_VideoCombine. Text-only works by omitting images.
- **Compat / watch out:** deps librosa, torchdiffeq, einops, timm, omegaconf, open_clip_torch, accelerate, ftfy; pyproject pins numpy<=1.26.4 (NumPy 2.x breaks it, confirmed open issue). Needs VHS for the standard workflow. Apple Silicon unsupported. 7+ open breakage issues unaddressed; effectively unmaintained.

#### ComfyUI-MelBandRoFormer  -  last commit 2026-01-30, no license, active
- Mel-Band RoFormer audio source separation: split a track into a vocals stem and an instruments stem.
- **Nodes:** `MelBandRoFormerModelLoader` (from models/diffusion_models; config hardcoded) -> MELROFORMERMODEL; `MelBandRoFormerSampler` (model + AUDIO, chunked overlap-add) -> vocals AUDIO + instruments AUDIO.
- **Use:** LoadAudio -> MelBandRoFormerSampler.audio, MelBandRoFormerModelLoader.model -> sampler -> vocals + instruments to PreviewAudio/SaveAudio. Model goes in models/diffusion_models.
- **Compat / watch out:** deps rotary_embedding_torch, einops; needs torchaudio; flash_attn=True is hardcoded (no CPU/older-CUDA fallback, may error). Open: cuFFT and cuBLAS init errors (CUDA/driver sensitivity), Manager-install "missing node", no license, node re-runs every queue (no caching). pyproject description wrongly says "WanVideo" (copy-paste artifact).

### Training

#### ComfyUI-FluxTrainer  -  last commit 2025-04-02, Apache-2.0, legacy (broken on current ComfyUI)
- Node wrapper over a kohya-ss/sd-scripts fork running LoRA / LyCORIS / full finetune for FLUX (also SDXL, SD3) as a node graph. ~33 nodes. README marks it experimental; full finetune untested.
- **Nodes:** `FluxTrainModelSelect` -> TRAIN_FLUX_MODELS; `TrainDatasetGeneralConfig` + `TrainDatasetAdd` (chainable) -> dataset JSON; `OptimizerConfig` (+ Adafactor/Prodigy presets) -> ARGS; `InitFluxLoRATraining` -> NETWORKTRAINER; `FluxTrainLoop` (run N steps); `FluxTrainSave`; `FluxTrainValidate` + `FluxTrainValidationSettings`; `FluxTrainEnd`; `VisualizeLoss`; `UploadToHuggingFace`; `ExtractFluxLoRA`; plus SD3 and SDXL init/validate variants.
- **Use:** ModelSelect + dataset (GeneralConfig -> DatasetAdd) + OptimizerConfig -> InitFluxLoRATraining -> NETWORKTRAINER threaded through a repeated FluxTrainLoop -> FluxTrainSave -> FluxTrainValidate ladder -> FluxTrainEnd. ComfyUI-KJNodes is effectively a co-requirement for the shipped example.
- **Compat / watch out:** deps include a HARD numpy<=1.26.4 pin (conflicts with numpy 2.x cores) plus bitsandbytes, prodigyopt, schedulefree, came_pytorch. Confirmed current break: import fails at node-load with `ImportError: cannot import name 'CLIPFeatureExtractor' from 'transformers'` (removed in newer transformers), so on current ComfyUI the nodes never register. 151 open issues; stale ~14 months. Do not wire on a current stack without pinning transformers down.

### Utility

#### ComfyUI-KJNodes  -  last commit 2026-06-24, GPL-3.0, active
- ~244-node utility grab-bag (image/mask/latent batching, color matching, torch.compile + attention patchers for Wan/Hunyuan/Flux/LTX, curve/spline editors, JS Set/Get reroute nodes), kept low-dependency. Representative subset below; the rest exist by name in `__init__.py` but were not all read line-by-line.
- **Nodes:** `SetNode` / `GetNode` (JS reroute pair, works across subgraphs); `ImageResizeKJv2` (proportion/crop/pad) -> IMAGE + size + mask; `ColorMatch` / `ColorMatchV2`; `GetImageSizeAndCount`; `GrowMaskWithBlur` -> mask + inverse; `CreateShapeMask` (+ many Create*Mask generators); `ConditioningSetMaskAndCombine` (regional prompting); `VRAM_Debug`; `INTConstant` / FloatConstant / BOOLConstant / StringConstant; `PathchSageAttentionKJ` (note the misspelling) and `PatchFlashAttentionKJ`; `TorchCompileModelWanVideoV2` / TorchCompileModelFluxAdvancedV2 / TorchCompileVAE; Wan/Hunyuan/LTX patches (`WanVideoTeaCacheKJ`, `WanVideoNAG`, `SkipLayerGuidanceWanVideo`, RifleX RoPE); `SplineEditor` / `PointsEditor` / `PlotCoordinates`; loaders/savers (`CheckpointLoaderKJ`, `GGUFLoaderKJ`, `LoraExtractKJ`) (+~220 more nodes).
- **Use:** splice as helpers into a normal graph. Idioms: image -> GetImageSizeAndCount drives sizing; mask -> GrowMaskWithBlur for feathered masks; (pos_N, neg_N, mask_N) -> ConditioningSetMaskAndCombine for regional prompts; model -> TorchCompile*/PathchSageAttentionKJ/WanVideoTeaCacheKJ -> patched MODEL -> sampler; SetNode/GetNode declutter big graphs.
- **Compat / watch out:** deps pillow, color-matcher, matplotlib, mss, opencv-python-headless; SageAttention/FlashAttention are optional and NOT installed by the pack (the patchers need those libs separately). Targets modern ComfyUI ("Nodes 2.0" + subgraphs), so very old frontends miss the Set/Get and editor JS. Open node-specific issues: PathchSageAttentionKJ "Fatal Python error: Aborted" on Qwen Image Edit and Flux 2 Klein (native --use-sage-attention works), Ideogram-4 builder breaks subgraph input, BBox nodes incompatible with native SAM3 Detect.

#### ComfyUI-MemoryVisualization  -  last commit 2026-06-05, no license, active
- Frontend-only sidebar panel showing real-time VRAM, RAM, GPU util, power draw, and (with comfy-aimdo) per-model residency heatmaps. No workflow nodes.
- **Nodes:** none. Adds a sidebar panel (web/aimdo_viz.js polls GET /aimdo/vram ~1s); control buttons POST to /aimdo/unload_all or /aimdo/unload_model to free VRAM without stopping execution.
- **Use:** install into custom_nodes, launch ComfyUI; the panel appears in the sidebar. No graph wiring.
- **Compat / watch out:** single optional dep nvidia-ml-py (falls back to torch.cuda). Works on Windows/Linux/macOS. Open: multi-GPU shows only cuda:0; scale setting ignored when docked in the top bar.

#### ComfyUI-NativeLooping_testing  -  last commit 2026-06-15, no license, experimental
- Native loop nodes that accumulate IMAGE/MASK/LATENT across iterations without third-party loop extensions, built on comfy_api.latest. Self-described as a temporary testing repo and a candidate for ComfyUI core.
- **Nodes:** `TensorLoopOpen` (iterations or total_frames mode) -> FlowControl + previous_value + counts; `TensorLoopClose` (accumulate, overlap trim / crossfade, optional early stop) -> accumulated batch.
- **Use:** TensorLoopOpen -> generation nodes -> TensorLoopClose. Wire flow_control between them, feed previous_value into the generator, feed the generator output into processed. For video-continuation models set overlap='start' with overlap_frames = context frames to drop duplicates.
- **Compat / watch out:** needs comfy_api.latest + comfy.nested_tensor (recent ComfyUI). No extra requirements.txt. The bundled example uses stale class names `TensorForLoopOpen`/`TensorForLoopClose` (renamed; workflow will not load without a fix). Likely abandoned once the upstream core PR merges.

## Legacy / archived (one line each)

Deep cards marked legacy:
- `ComfyUI-HunyuanVideoWrapper` (last commit 2025-08-20) - first ComfyUI HunyuanVideo integration - use ComfyUI native HunyuanVideo (+ HunyuanLoom, Comfy-WaveSpeed, KJNodes for extras) instead.
- `ComfyUI-SUPIR` (last commit 2026-04-29) - SUPIR restoration/upscale wrapper - use ComfyUI core SUPIR (PR #13250) instead; wrapper is bugfix-only.
- `ComfyUI-CogVideoXWrapper` (last commit 2025-08-07) - CogVideoX video wrapper (Fun, Tora, ControlNet) - use WanVideoWrapper / HunyuanVideo / LTX-Video instead (inferred).
- `ComfyUI-FluxTrainer` (last commit 2025-04-02) - FLUX/SDXL/SD3 LoRA training - broken on current ComfyUI; use standalone kohya / ai-toolkit / SimpleTuner (inferred).
- `ComfyUI-DynamiCrafterWrapper` (last commit 2025-06-02) - DynamiCrafter / ToonCrafter I2V and interpolation - use WanVideoWrapper / HunyuanVideoWrapper for modern video (inferred).
- `ComfyUI-MimicMotionWrapper` (last commit 2025-01-12) - MimicMotion pose-driven human animation on SVD - no drop-in; Champ / AnimateAnyone cover similar use.
- `ComfyUI-LLaVA-OneVision` (last commit 2026-01-12) - LLaVA-OneVision captioning/VQA - fails to load on current ComfyUI; use Florence2 / LLM-Party (inferred).

Light (wave3) cards:
- `ComfyUI-LivePortraitKJ` (last commit 2024-08-04) - portrait/face animation - use KwaiVGI/LivePortrait or Manager face-animation nodes instead.
- `ComfyUI-MochiWrapper` (last commit 2024-11-11) - Mochi video generation - use LTX / CogVideoX / Hunyuan / newer video models instead.
- `ComfyUI-KwaiKolorsWrapper` (last commit 2024-10-18) - Kwai Kolors diffusers wrapper - use native Kolors via ComfyUI Manager instead.
- `ComfyUI-PyramidFlowWrapper` (last commit 2024-11-15, stale) - PyramidFlow video - no named replacement.
- `ComfyUI-ADMotionDirector` (last commit 2024-11-07, stale) - AnimateDiff motion LoRA training - use AnimateDiff-Evolved (inference) / modern AnimateDiff (training) instead.
- `ComfyUI-FramerWrapper` (last commit 2024-12-20, stale) - Framer keyframe interpolation - no named replacement.
- `ComfyUI-Geowizard` (last commit 2024-12-16) - GeoWizard depth/normals - no named replacement (upstream model still active).
- `ComfyUI-VEnhancer` (last commit 2024-11-02) - VEnhancer video enhancement/upscale - no named replacement.
- `ComfyUI-LVCDWrapper` (last commit 2024-09-30) - LVCD line-art video colorization - use LTX-Video / I2V wrappers / AnimateAnyone / Wan instead.
- `ComfyUI-ControlNeXt-SVD` (last commit 2024-08-15, dormant) - ControlNeXt-SVD video control - no modern replacement named (see dvlab-research/ControlNeXt upstream).
- `ComfyUI-EasyAnimateWrapper` (last commit 2024-08-14, stale) - EasyAnimate video - no named replacement.
- `ComfyUI-LuminaWrapper` (last commit 2024-06-28, abandoned) - Lumina text-to-image - use FLUX or SD 3.5 instead.
- `ComfyUI-OpenDiTWrapper` (last commit 2024-06-29, incomplete) - OpenDiT acceleration - use LTX-Video / HunyuanVideo / upstream OpenDiT instead.
- `ComfyUI-DiffSynthWrapper` (last commit 2024-06-22, stalled) - DiffSynth-Studio wrapper - use modelscope/DiffSynth-Studio upstream (no active wrapper).
- `ComfyUI-BrushNet-Wrapper` (last commit 2024-06-20) - BrushNet inpainting - use nullquant/ComfyUI-BrushNet (native) instead, per maintainer.
- `ComfyUI-DiffusersSD3Wrapper` (last commit 2024-06-17) - early SD3 + ControlNet via diffusers - use the diffusers native controlnet_sd3 pipeline instead.
- `ComfyUI-CV-VAE` (last commit 2024-06-03, dormant) - CV-VAE proof-of-concept - no named replacement.
- `ComfyUI-SVD` (last commit 2023-11-25, archived) - Stable Video Diffusion - use ComfyUI built-in video/SVD support instead.
- `ComfyUI-IC-Light-Wrapper` (last commit 2024-05-09) - early IC-Light wrapper - use ComfyUI-IC-Light (kijai, native) instead.
- `ComfyUI-DeepSeek-VL` (last commit 2024-04-23) - DeepSeek-VL vision-language - no named replacement.
- `ComfyUI-LaVi-Bridge-Wrapper` (last commit 2024-04-11) - LaVi-Bridge text encoder bridge - use LTX-Video / Mochi / newer text-to-video instead.
- `ComfyUI-ELLA-wrapper` (last commit 2024-05-09) - ELLA prompt enhancement - use TencentQQGYLab/ComfyUI-ELLA instead (explicitly superseded).
- `ComfyUI-MuseTalk-KJ` (last commit 2024-04-05) - MuseTalk lip-sync - no named replacement.
- `ComfyUI-DiffusionLight` (last commit 2024-04-02, stale) - DiffusionLight HDR/light estimation - no named replacement.
- `ComfyUI-APISR-KJ` (last commit 2024-04-19) - APISR anime upscaling - use Real-ESRGAN / BSRGAN / diffusion upscalers instead.
- `ComfyUI-DDColor` (last commit 2024-01-18) - DDColor colorization - use the maintained fork `hay86/ComfyUI_DDColor` (ComfyUI Manager, Apache-2.0); comfyui-art-venture only does color-grading/blending, not ML colorization.
- `ComfyUI-llama-cpp` (last commit 2024-04-19) - llama.cpp LLM nodes - use modern ComfyUI LLM nodes / comfyui-agent-kit instead.
- `ComfyUI-DiffusersStableCascade` (last commit 2024-02-17) - Stable Cascade via diffusers - use native ComfyUI StableCascade nodes instead.

## What to disable or avoid now

Actionable "do not wire this / turn this off" list, from open "broken on current ComfyUI" issues and explicit supersession.

- ComfyUI-FluxTrainer: import fails at node-load on current transformers (CLIPFeatureExtractor removed) plus a hard numpy<=1.26.4 pin. Nodes never register on a current stack. Avoid unless you pin transformers and numpy.
- ComfyUI-Lotus: breaks on ComfyUI 0.3.65+ (folder_paths.get_full_path_or_raise no longer exists); module fails to import. Use DepthAnythingV2 or Marigold.
- ComfyUI-LLaVA-OneVision: "Doesn't work in latest ComfyUI / not loading at all" (open, unresolved). Use Florence2.
- ComfyUI-LBMWrapper: import fails on ComfyUI 0.3.39 and `set_timesteps(sigmas=)` errors on newer diffusers. Not updated since 2025-05-14.
- ComfyUI-HunyuanVideoWrapper: transformers 4.54+/4.57+ break the LLaVA text-encoder path (startup ImportError, Qwen-VL conflict). Use native HunyuanVideo; the wrapper is sunset.
- ComfyUI-SUPIR: superseded by ComfyUI core SUPIR (PR #13250), bugfix-only; also Blackwell RTX 50-series hits a missing memory_efficient_attention op. Prefer core SUPIR.
- ComfyUI-WanAnimatePreprocess: ONNX load fails on NumPy 2.x and files do not list in the dropdown on ComfyUI 0.22.0. Pin NumPy 1.x until patched.
- ComfyUI-MMAudio: NumPy 2.x breaks it (pyproject pins numpy<=1.26.4); MMAudioVoCoderLoader returns a path string (broken 16k stub); 7+ unaddressed breakage issues. Treat as unmaintained.
- ComfyUI-PromptRelay: sampling hangs at 0/N with LTX-2.3 on ComfyUI v0.23.0 / Windows (works on 0.22.0). Avoid that combo.
- ComfyUI-GIMM-VFI: hard cupy-cuda12x>=13.3.0 dep cannot install on CUDA 13 / RTX 5090; timm import break on current installs. Blocked for newest GPUs.
- ComfyUI-SCAIL-Pose: Taichi backend crashes the whole ComfyUI process; set render_backend='torch'.
- ComfyUI-Hunyuan3DWrapper: texture gen requires native custom_rasterizer / mesh_processor compile that fails on torch 2.9.1+cu130, Blackwell, and ROCm RDNA4. Shape-only path is fine; expect build pain for texturing on the newest stacks.
- ComfyUI-WanVideoWrapper: WanVideoLoraSelectMulti merge_lora crashes on ComfyUI >= 0.16.0; I2V broken on AMD ROCm. Avoid those specific paths.
- ComfyUI-HFRemoteVae: depends on HF-operated endpoints that return 503 when HF takes them down; no license. Do not depend on it in a pipeline.
- ComfyUI-MelBandRoFormer: cuFFT / cuBLAS init errors on some CUDA/driver setups; flash_attn hardcoded with no fallback.
- ComfyUI-NativeLooping_testing: bundled example uses renamed classes (TensorForLoopOpen/Close) and will not load as-is; the repo is temporary and likely abandoned once the core PR lands.
- All wave3 legacy/archived repos above: dormant, mostly 2024-era models, several superseded by ComfyUI core or newer wrappers. Do not start new work on them; use the replacement in the supersede map.

---
Sources: read live from github.com/kijai on 2026-06-24 via the kit's deep-research workflow (62 repos). Node lists and I/O are from each repo's real code (NODE_CLASS_MAPPINGS / node_list.json); compat notes include open issues at time of reading.
